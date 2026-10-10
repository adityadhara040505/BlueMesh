import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'ui/providers/settings_provider.dart';
import 'ui/screens/chat_screen.dart';
import 'ui/screens/contacts_screen.dart';
import 'ui/screens/diagnostics_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/theme/app_theme.dart';

/// BlueMesh routing configuration with go_router.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/contacts',
        builder: (context, state) => const ContactsScreen(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) {
          final peerIdStr = state.uri.queryParameters['peerId'] ?? '0';
          final peerName = state.uri.queryParameters['peerName'] ?? 'Peer';
          final peerId = int.tryParse(peerIdStr) ?? 0;
          return ChatScreen(peerId: peerId, peerName: peerName);
        },
      ),
      GoRoute(
        path: '/diagnostics',
        builder: (context, state) => const DiagnosticsScreen(),
      ),
    ],
  );
});

/// Root BlueMesh Application Widget.
class BlueMeshApp extends ConsumerWidget {
  const BlueMeshApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: 'BlueMesh',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }
}
