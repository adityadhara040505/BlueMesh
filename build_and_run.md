# BlueMesh Build and Execution Guide 🚀

This document outlines the prerequisites and commands required to build, test, and run **BlueMesh** across all supported platforms (Android, iOS, Windows, macOS, and Linux).

---

## 📋 General Prerequisites

- **Flutter SDK**: 3.19.0 or higher (`flutter --version`)
- **Dart SDK**: 3.3.0 or higher
- Bluetooth hardware support (Bluetooth 4.2 / 5.0+ with BLE support)

---

## 🧪 Running Automated Tests

Run unit tests and widget tests with coverage target (>70%):
```bash
# Run all test suites
flutter test

# Run tests with code coverage output
flutter test --coverage
```

---

## 📱 Android Build (API 23+ / Android 6.0+)

Full **dual-role** node (BLE Central + BLE Peripheral).

### Prerequisites
- Android Studio with Android SDK Platform 34 installed.
- Android NDK.

### Build Commands
```bash
# 1. Fetch dependencies
flutter pub get

# 2. Build Release APK
flutter build apk --release

# Output path: build/app/outputs/flutter-apk/app-release.apk

# 3. Build Android App Bundle (AAB) for Google Play (if needed)
flutter build appbundle --release

# 4. Run directly on connected Android device
flutter run -d <device-id> --release
```

---

## 🍎 iOS Build (iOS 13.0+)

Full **dual-role** node (BLE Central + BLE Peripheral).

### Prerequisites
- macOS host with Xcode 15+ installed.
- CocoaPods (`sudo gem install cocoapods`).

### Build Commands
```bash
# 1. Install iOS CocoaPods dependencies
cd ios && pod install && cd ..

# 2. Build Release iOS app bundle
flutter build ios --release --no-codesign

# 3. Run on connected iPhone
flutter run -d <iphone-device-id> --release
```

---

## 🖥️ Linux Desktop Build (BlueZ 5.43+)

Runs as Central + Peripheral (depending on BlueZ driver and adapter capabilities).

### Prerequisites (Ubuntu / Debian)
```bash
sudo apt-get update
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev libbluetooth-dev libsqlite3-dev
```

### Build Commands
```bash
# 1. Enable Linux desktop in Flutter
flutter config --enable-linux-desktop

# 2. Build Release Linux executable
flutter build linux --release

# Output path: build/linux/x64/release/bundle/blue_mesh

# 3. Run directly on Linux
flutter run -d linux --release
```

---

## 🍏 macOS Desktop Build (macOS 10.15+ Catalina)

Runs in **Central-Only mode** (scans and connects to advertising mobile/Linux mesh nodes).

### Prerequisites
- Xcode with macOS developer tools.

### Build Commands
```bash
# 1. Enable macOS desktop in Flutter
flutter config --enable-macos-desktop

# 2. Build Release macOS App
flutter build macos --release

# Output path: build/macos/Build/Products/Release/blue_mesh.app

# 3. Run on macOS
flutter run -d macos --release
```

---

## 🪟 Windows Desktop Build (Windows 10/11)

Runs in **Central-Only mode** via Windows Runtime (WinRT) Bluetooth APIs.

### Prerequisites
- Visual Studio 2022 with "Desktop development with C++" workload installed.

### Build Commands
```bash
# 1. Enable Windows desktop in Flutter
flutter config --enable-windows-desktop

# 2. Build Release Windows executable
flutter build windows --release

# Output path: build/windows/x64/runner/Release/blue_mesh.exe

# 3. Run on Windows
flutter run -d windows --release
```

---

## 📡 Physical Multi-Device Test Plan

1. **Direct Point-to-Point Connection (2 Devices)**:
   - Launch BlueMesh on Phone A and Phone B.
   - Confirm both show in each other's "Cluster" tab within 5 seconds.
   - Send a message from Phone A to Phone B.
   - Verify status transitions: `sending` ➔ `sent (✓)` ➔ `delivered (✓✓)`.

2. **Store-and-Forward Out-of-Range Test**:
   - Turn off Bluetooth on Phone B.
   - Send a message from Phone A to Phone B.
   - Verify Phone A displays message with clock/queue icon and "Waiting for peer..." banner.
   - Re-enable Bluetooth on Phone B.
   - Within 30 seconds, verify queued message automatically flushes and delivers (`✓✓`).

3. **Multi-Hop Relay Test (3 Devices in Line)**:
   - Place Device A, Device B, and Device C in a line where A and C are out of Bluetooth range from each other, but both are within range of B.
   - Device B acts as a relay node.
   - Send a message from Device A to Device C.
   - Device B silently decrements TTL and relays the frame.
   - Device C receives message showing `hopCount = 2`.
