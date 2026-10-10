import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../bluetooth/bluetooth_permissions.dart';
import '../../utils/validators.dart';
import '../providers/ble_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/colors.dart';

/// Onboarding screen for nickname configuration, ECDH keypair generation, and BLE permissions.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isGeneratingKeys = false;
  String? _fingerprint;

  @override
  void initState() {
    super.initState();
    _loadIdentity();
  }

  Future<void> _loadIdentity() async {
    setState(() => _isGeneratingKeys = true);
    try {
      final bleNotifier = ref.read(bleProvider.notifier);
      await bleNotifier.whenReady;
      if (mounted) {
        setState(() {
          _fingerprint = bleNotifier.keyManager.fingerprint;
          _isGeneratingKeys = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isGeneratingKeys = false);
      }
    }
  }

  Future<void> _completeSetup() async {
    if (!_formKey.currentState!.validate()) return;

    // Request permissions
    await BluetoothPermissionsManager.requestPermissions();

    final name = _nameController.text.trim();
    await ref.read(settingsProvider.notifier).completeOnboarding(name);

    // Re-bootstrap mesh with granted permissions and user identity
    await ref.read(bleProvider.notifier).restartMeshEngine();

    if (mounted) {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.hub_rounded,
                      size: 48,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'Welcome to BlueMesh',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Private peer-to-peer chat over Bluetooth Low Energy.\nNo internet or cellular required.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.offlineGrey, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 40),

                // Name input field
                const Text(
                  'Your Display Name',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  validator: InputValidators.validateDisplayName,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Alice, Bob, Node-7',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 24),

                // Cryptographic Key Fingerprint Card
                const Text(
                  'Your Cryptographic Identity',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.shield_outlined, size: 18, color: AppColors.onlineGreen),
                            SizedBox(width: 8),
                            Text(
                              'ECDH P-256 Keypair Generated',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your device fingerprint allows peers to verify end-to-end security without any centralized servers.',
                          style: TextStyle(color: AppColors.offlineGrey, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        if (_isGeneratingKeys)
                          const LinearProgressIndicator()
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  'Fingerprint: ',
                                  style: TextStyle(fontSize: 12, color: AppColors.offlineGrey),
                                ),
                                Text(
                                  _fingerprint ?? 'DERIVING...',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.accentCyan,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _completeSetup,
                    child: const Text('Start Chatting Offline'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
