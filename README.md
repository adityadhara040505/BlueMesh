# BlueMesh 📱🕸️

**BlueMesh** is an offline, peer-to-peer, decentralized mesh text messaging application built with Flutter. BlueMesh operates exclusively over Bluetooth Low Energy (BLE) without requiring an internet connection, Wi-Fi router, or cellular network.

Every device functions as both a **BLE Peripheral** (GATT server) and a **BLE Central** (GATT client) simultaneously (where supported by OS hardware/drivers), constructing a multi-hop, self-organizing, self-healing mesh cluster.

---

## 🏗️ Architecture Overview

```
 +-----------------------------------------------------------------------+
 |                             BlueMesh UI                               |
 |   [Chats Screen]     [Cluster Topology View]     [Diagnostics View]   |
 +-----------------------------------+-----------------------------------+
                                     | Riverpod 2.x
 +-----------------------------------v-----------------------------------+
 |                          Mesh Application Layer                       |
 |  - ChatRepository         - ContactRepository      - MessageRepository|
 |  - StoreAndForward        - HeartbeatService       - PeerDiscovery    |
 +-----------------------------------+-----------------------------------+
                                     |
 +-----------------------------------v-----------------------------------+
 |                            Mesh Router Layer                          |
 |  - TTL Flooding Engine (Max Hops: 5)               - LRU Deduplicator |
 |  - Routing Table Management (60s Expire)           - Signature / TOFU |
 +-----------------------------------+-----------------------------------+
                                     |
 +-----------------------------------v-----------------------------------+
 |                        Security & Cryptography                        |
 |  - ECDH (P-256) Key Agreement                      - AES-256-GCM      |
 |  - ECDSA Message Signing                           - HKDF-SHA256      |
 +-----------------------------------+-----------------------------------+
                                     |
 +-----------------------------------v-----------------------------------+
 |                        Wire Protocol & Framing                        |
 |  - 24-Byte Binary Frame Header                     - Fragmentation    |
 |  - MTU Chunking (Seq / Total)                      - 30s Reassembly   |
 +-----------------------------------+-----------------------------------+
                                     |
 +-----------------------------------v-----------------------------------+
 |                    BLE Dual-Role Orchestrator (Pool)                  |
 |  +-----------------------------+     +-----------------------------+  |
 |  |    BLE Central (Scanner)    |     |   BLE Peripheral (Server)   |  |
 |  | - 3s Scan / 2s Rest Cycle   |     | - BlueMesh Service 0xFFFF   |  |
 |  | - Max 4 Outbound Conns      |     | - TX/RX/CONTACT/HEARTBEAT   |  |
 |  | - Exponential Backoff       |     | - Max 7 Inbound Conns       |  |
 |  +-----------------------------+     +-----------------------------+  |
 +-----------------------------------------------------------------------+
```

---

## 📡 Platform Support Matrix

| Platform | Min Version | Role Support | Mechanism / API | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Android** | 6.0+ (API 23+) | **Central + Peripheral** | Android BluetoothGatt & BluetoothLeAdvertiser | Full dual-role mesh node. Foreground Service supported. |
| **iOS** | 13.0+ | **Central + Peripheral** | CoreBluetooth (`CBCentralManager` + `CBPeripheralManager`) | Full dual-role. Background Bluetooth execution enabled. |
| **macOS** | 10.15+ (Catalina) | **Central only** (Peripheral limited) | CoreBluetooth Central | Relies on connecting to mobile or Linux peers. |
| **Windows** | 10/11 | **Central only** | Windows Runtime (WinRT) BLE APIs | Connects to advertising peers; no inbound GATT server. |
| **Linux** | BlueZ 5.43+ | **Central + Peripheral** | BlueZ D-Bus APIs | Requires BLE adapter (Bluetooth 4.2/5.0+). |

> **Fallback Strategy**: On platforms lacking Peripheral/advertising support (Windows, macOS), BlueMesh automatically switches to **Central-Only Mode**. It scans and connects to nearby advertising peers, joining the mesh as a leaf or bridge Central node without advertising itself.

---

## 📦 Wire Protocol Specifications

### Service & Characteristic UUIDs
- **Mesh Service UUID**: `0000FFFF-0000-1000-8000-00805F9B34FB`
- **TX Characteristic** (`0000FF01-0000-1000-8000-00805F9B34FB`): Write Without Response (Inbound messages from Central).
- **RX Characteristic** (`0000FF02-0000-1000-8000-00805F9B34FB`): Notify (Outbound messages pushed to connected Centrals).
- **CONTACT Characteristic** (`0000FF03-0000-1000-8000-00805F9B34FB`): Read/Write (JSON Contact Card exchange).
- **HEARTBEAT Characteristic** (`0000FF04-0000-1000-8000-00805F9B34FB`): Notify (Periodic presence ping).
- **ROUTING Characteristic** (`0000FF05-0000-1000-8000-00805F9B34FB`): Read/Write (Mesh routing exchange).

### Binary Message Frame (Little Endian, 24-byte Header)
```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                       Message ID (uint32)                     |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|   Type (u8)   |    TTL (u8)   | HopCount (u8) |   Flags (u8)  |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                       Sender ID (uint32)                      |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                      Recipient ID (uint32)                    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                     Timestamp Unix Sec (u32)                  |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                     Payload Length (uint32)                   |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                     Payload Data (N bytes)                    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

- **Types**: `0 = Text`, `1 = Ping`, `2 = Ack`, `3 = ContactSync`, `4 = Heartbeat`, `5 = RoutingUpdate`, `6 = KeyExchange`.
- **Flags**: `Bit 0 = Encrypted`, `Bit 1 = Broadcast`, `Bit 2 = AckRequired`.

### Fragmentation Header (6 bytes)
```
[Message ID: uint32 (4 bytes)] [Sequence: uint8 (1 byte)] [Total: uint8 (1 byte)]
```
Effective chunk payload = `Negotiated MTU - 3 (ATT overhead) - 6 (Frag header)`. Incomplete assemblies expire after 30 seconds.

---

## 🔐 Security Architecture

1. **Identity & Key Generation**:
   - ECDH NIST P-256 keypair generated on first launch.
   - Private key securely kept in platform keychain / encrypted storage.
   - Public key distributed during peer contact handshake.
   - 8-character hex fingerprint derived from SHA-256 of public key for visual verification.
2. **Message Authentication**:
   - Every frame payload is signed using sender's private key (ECDSA).
   - Recipient verifies signatures before passing messages up to UI or relaying.
3. **End-to-End Encryption**:
   - Point-to-point ECDH shared secret derivation + HKDF-SHA256 to produce 256-bit AES-GCM keys.
   - 12-byte random IV/nonce per encrypted message frame.
4. **Trust on First Use (TOFU)**:
   - First contact public key is saved.
   - If public key fingerprint changes, user is warned of a possible impersonation or MITM attack.

---

## ⚙️ Setup and Installation

### Prerequisites
- Flutter SDK 3.19.0 or newer.
- Dart SDK 3.3.0 or newer.
- Android Studio / Xcode / Visual Studio (depending on target platform).
- Linux: BlueZ 5.43+, `libbluetooth-dev`, and D-Bus development headers.

### Getting Started
```bash
# Clone the repository
cd BlueMesh

# Fetch dependencies
flutter pub get

# Run tests
flutter test

# Run application on connected device
flutter run
```

---

## 🛠️ Troubleshooting

- **Bluetooth permissions denied**: On Android 12+, ensure `BLUETOOTH_SCAN`, `BLUETOOTH_ADVERTISE`, and `BLUETOOTH_CONNECT` are granted. On Android 6–11, ensure Location permission is granted and Location Services are toggled ON.
- **Advertising fails on Android**: Check if device hardware supports BLE Advertising (`BluetoothAdapter.isMultipleAdvertisementSupported()`). Older budget chips might lack BLE multi-advertising.
- **Peers not showing up**: Ensure both devices have Bluetooth turned on and are within 10–30 meters line of sight. Duty-cycled scanning searches for 3 seconds every 5 seconds.
- **Linux BLE Permission**: Ensure user is part of the `bluetooth` group or add appropriate udev rules for BlueZ.

---

## ⚠️ Known Limitations

- **Throughput**: BLE is designed for low energy, not bandwidth. Text messages and small metadata cards transmit cleanly; high-resolution images and audio streams are intentionally out of scope.
- **Desktop Peripheral Support**: macOS and Windows standard APIs do not reliably support custom GATT Peripheral advertising through cross-platform plugins, so desktop nodes operate in Central-only mode.
- **Physical Range**: Typical BLE range is 10 to 30 meters indoors without physical obstacles. Multi-hop relay allows extending range across daisy-chained nodes.
