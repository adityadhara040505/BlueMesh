import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/local/hive_boxes.dart';
import '../../data/local/sqflite_database.dart';
import '../../services/background_service.dart';
import '../../services/notification_service.dart';
import '../providers/settings_provider.dart';
import '../theme/colors.dart';

/// Splash screen that initializes local storage, background daemons, and decides routing.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // 1. Initialize local persistent engines
    await HiveBoxes.init();
    ref.read(settingsProvider.notifier).reloadSettings();
    await AppDatabase.instance;
    await NotificationService.initialize();
    await AppBackgroundService.initialize();

    // 2. Short splash pause for smooth visual entry
    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;

    final settings = ref.read(settingsProvider);
    if (settings.isFirstLaunch) {
      context.go('/onboarding');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryBlue.withOpacity(0.4), width: 2),
              ),
              child: const Icon(
                Icons.bluetooth_searching_rounded,
                size: 64,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'BlueMesh',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Decentralized Bluetooth-Only Mesh Chat',
              style: TextStyle(
                color: AppColors.offlineGrey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
