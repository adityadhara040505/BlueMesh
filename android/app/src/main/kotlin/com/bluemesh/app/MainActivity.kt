package com.bluemesh.app

import android.bluetooth.*
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.*

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.bluemesh.app/gatt_server"
    private var methodChannel: MethodChannel? = null
    private var gattServer: BluetoothGattServer? = null
    private var bluetoothManager: BluetoothManager? = null
    private val connectedCentrals = Collections.synchronizedSet(mutableSetOf<BluetoothDevice>())

    companion object {
        val SERVICE_UUID: UUID = UUID.fromString("0000ffff-0000-1000-8000-00805f9b34fb")
        val TX_CHAR_UUID: UUID = UUID.fromString("0000ff01-0000-1000-8000-00805f9b34fb")
        val RX_CHAR_UUID: UUID = UUID.fromString("0000ff02-0000-1000-8000-00805f9b34fb")
        val HEARTBEAT_CHAR_UUID: UUID = UUID.fromString("0000ff04-0000-1000-8000-00805f9b34fb")
        val CCCD_UUID: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startServer" -> {
                    startGattServer()
                    result.success(true)
                }
                "stopServer" -> {
                    stopGattServer()
                    result.success(true)
                }
                "notifyMessage" -> {
                    val data = call.argument<ByteArray>("data")
                    if (data != null) {
                        notifyCharacteristic(RX_CHAR_UUID, data)
                        result.success(true)
                    } else {
                        result.error("INVALID_DATA", "Data was null", null)
                    }
                }
                "notifyHeartbeat" -> {
                    val data = call.argument<ByteArray>("data")
                    if (data != null) {
                        notifyCharacteristic(HEARTBEAT_CHAR_UUID, data)
                        result.success(true)
                    } else {
                        result.error("INVALID_DATA", "Data was null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startGattServer() {
        bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        if (bluetoothManager == null) return

        val serverCallback = object : BluetoothGattServerCallback() {
            override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    connectedCentrals.add(device)
                    Handler(Looper.getMainLooper()).post {
                        methodChannel?.invokeMethod("onCentralConnected", mapOf("address" to device.address))
                    }
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    connectedCentrals.remove(device)
                    Handler(Looper.getMainLooper()).post {
                        methodChannel?.invokeMethod("onCentralDisconnected", mapOf("address" to device.address))
                    }
                }
            }

            override fun onCharacteristicWriteRequest(
                device: BluetoothDevice,
                requestId: Int,
                characteristic: BluetoothGattCharacteristic,
                preparedWrite: Boolean,
                responseNeeded: Boolean,
                offset: Int,
                value: ByteArray?
            ) {
                if (responseNeeded) {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
                }
                if (value != null && value.isNotEmpty()) {
                    Handler(Looper.getMainLooper()).post {
                        methodChannel?.invokeMethod("onPacketReceived", mapOf(
                            "address" to device.address,
                            "packet" to value
                        ))
                    }
                }
            }

            override fun onDescriptorWriteRequest(
                device: BluetoothDevice,
                requestId: Int,
                descriptor: BluetoothGattDescriptor,
                preparedWrite: Boolean,
                responseNeeded: Boolean,
                offset: Int,
                value: ByteArray?
            ) {
                if (responseNeeded) {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
                }
            }

            override fun onNotificationSent(device: BluetoothDevice, status: Int) {}
            override fun onMtuChanged(device: BluetoothDevice, mtu: Int) {}
        }

        gattServer = bluetoothManager?.openGattServer(this, serverCallback) ?: return

        val service = BluetoothGattService(SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)

        // TX Characteristic: Centrals write packets here without response
        val txChar = BluetoothGattCharacteristic(
            TX_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
            BluetoothGattCharacteristic.PERMISSION_WRITE
        )
        service.addCharacteristic(txChar)

        // RX Characteristic: Peripheral notifies packets to Centrals
        val rxChar = BluetoothGattCharacteristic(
            RX_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_NOTIFY or BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_READ
        )
        val rxCccd = BluetoothGattDescriptor(CCCD_UUID, BluetoothGattDescriptor.PERMISSION_WRITE or BluetoothGattDescriptor.PERMISSION_READ)
        rxChar.addDescriptor(rxCccd)
        service.addCharacteristic(rxChar)

        // Heartbeat Characteristic: Peripheral notifies periodic presence beacons
        val heartbeatChar = BluetoothGattCharacteristic(
            HEARTBEAT_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_NOTIFY or BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_READ
        )
        val hbCccd = BluetoothGattDescriptor(CCCD_UUID, BluetoothGattDescriptor.PERMISSION_WRITE or BluetoothGattDescriptor.PERMISSION_READ)
        heartbeatChar.addDescriptor(hbCccd)
        service.addCharacteristic(heartbeatChar)

        gattServer?.addService(service)
    }

    private fun notifyCharacteristic(charUuid: UUID, data: ByteArray) {
        val server = gattServer ?: return
        val service = server.getService(SERVICE_UUID) ?: return
        val characteristic = service.getCharacteristic(charUuid) ?: return

        characteristic.value = data
        synchronized(connectedCentrals) {
            for (device in connectedCentrals) {
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        server.notifyCharacteristicChanged(device, characteristic, false, data)
                    } else {
                        server.notifyCharacteristicChanged(device, characteristic, false)
                    }
                } catch (e: Exception) {
                    // Ignore transient per-device notify error
                }
            }
        }
    }

    private fun stopGattServer() {
        try {
            gattServer?.close()
            gattServer = null
            connectedCentrals.clear()
        } catch (e: Exception) {
            // Ignore close error
        }
    }

    override fun onDestroy() {
        stopGattServer()
        super.onDestroy()
    }
}
