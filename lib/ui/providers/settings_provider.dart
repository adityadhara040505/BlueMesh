import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../core/constants.dart';
import '../../data/local/hive_boxes.dart';

/// User and mesh configuration settings state.
class SettingsState {
  final String displayName;
  final int deviceId;
  final int meshTtl;
  final bool isDarkMode;
  final bool notificationsEnabled;
  final bool isFirstLaunch;

  const SettingsState({
    required this.displayName,
    required this.deviceId,
    required this.meshTtl,
    required this.isDarkMode,
    required this.notificationsEnabled,
    required this.isFirstLaunch,
  });

  String get shortHexId => deviceId.toRadixString(16).padLeft(8, '0').substring(0, 6);

  SettingsState copyWith({
    String? displayName,
    int? deviceId,
    int? meshTtl,
    bool? isDarkMode,
    bool? notificationsEnabled,
    bool? isFirstLaunch,
  }) {
    return SettingsState(
      displayName: displayName ?? this.displayName,
      deviceId: deviceId ?? this.deviceId,
      meshTtl: meshTtl ?? this.meshTtl,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      isFirstLaunch: isFirstLaunch ?? this.isFirstLaunch,
    );
  }
}

/// Settings state notifier backed by Hive key-value persistence.
class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier()
      : super(
          const SettingsState(
            displayName: 'Peer',
            deviceId: 0,
            meshTtl: MeshConstants.defaultTtl,
            isDarkMode: true,
            notificationsEnabled: true,
            isFirstLaunch: true,
          ),
        ) {
    _loadSettings();
  }

  void _loadSettings() {
    try {
      if (!Hive.isBoxOpen(HiveBoxKeys.settingsBox)) {
        return;
      }
      final box = HiveBoxes.settingsBox;
      final savedName = box.get('displayName') as String?;
      var savedId = box.get('deviceId') as int?;
      final savedTtl = box.get('meshTtl') as int? ?? MeshConstants.defaultTtl;
      final savedDark = box.get('isDarkMode') as bool? ?? true;
      final savedNotifs = box.get('notificationsEnabled') as bool? ?? true;
      final isFirst = box.get('isFirstLaunch') as bool? ?? (savedName == null);

      // If no device ID exists yet, generate random 32-bit positive integer
      if (savedId == null || savedId == 0) {
        final rng = Random.secure();
        savedId = (rng.nextInt(0x7FFFFFFF) + 1); // 31-bit positive int
        box.put('deviceId', savedId);
      }

      state = SettingsState(
        displayName: savedName ?? 'BlueMesh Node',
        deviceId: savedId,
        meshTtl: savedTtl,
        isDarkMode: savedDark,
        notificationsEnabled: savedNotifs,
        isFirstLaunch: isFirst,
      );
    } catch (_) {
      // Box not initialized yet; default initial state is retained
    }
  }

  /// Re-sync settings once Hive boxes are ready.
  void reloadSettings() {
    _loadSettings();
  }

  Future<void> setDisplayName(String name) async {
    state = state.copyWith(displayName: name, isFirstLaunch: false);
    if (Hive.isBoxOpen(HiveBoxKeys.settingsBox)) {
      await HiveBoxes.settingsBox.put('displayName', name);
      await HiveBoxes.settingsBox.put('isFirstLaunch', false);
    }
  }

  Future<void> setMeshTtl(int ttl) async {
    final clamped = ttl.clamp(MeshConstants.minTtl, MeshConstants.maxTtl);
    state = state.copyWith(meshTtl: clamped);
    if (Hive.isBoxOpen(HiveBoxKeys.settingsBox)) {
      await HiveBoxes.settingsBox.put('meshTtl', clamped);
    }
  }

  Future<void> toggleDarkMode(bool isDark) async {
    state = state.copyWith(isDarkMode: isDark);
    if (Hive.isBoxOpen(HiveBoxKeys.settingsBox)) {
      await HiveBoxes.settingsBox.put('isDarkMode', isDark);
    }
  }

  Future<void> toggleNotifications(bool enabled) async {
    state = state.copyWith(notificationsEnabled: enabled);
    if (Hive.isBoxOpen(HiveBoxKeys.settingsBox)) {
      await HiveBoxes.settingsBox.put('notificationsEnabled', enabled);
    }
  }

  Future<void> completeOnboarding(String name) async {
    await setDisplayName(name);
  }

  ThemeMode get themeMode => state.isDarkMode ? ThemeMode.dark : ThemeMode.light;
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
