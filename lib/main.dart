import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme.dart';
import 'providers/app_providers.dart';
import 'features/scanner/scanner_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/messaging/messaging_screen.dart';
import 'features/channels/channels_screen.dart';
import 'features/nodes/nodes_screen.dart';
import 'features/map/map_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/qr_import_screen.dart';
import 'features/device/device_config_screen.dart';
import 'features/device/region_selection_screen.dart';
import 'features/navigation/main_shell.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/timeline/timeline_screen.dart';
import 'features/presence/presence_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const ProviderScope(child: ProtofluffApp()));
}

class ProtofluffApp extends ConsumerStatefulWidget {
  const ProtofluffApp({super.key});

  @override
  ConsumerState<ProtofluffApp> createState() => _ProtofluffAppState();
}

class _ProtofluffAppState extends ConsumerState<ProtofluffApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appInitProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch auto-reconnect and live activity managers at app level
    // so they stay active regardless of which screen is shown
    ref.watch(autoReconnectManagerProvider);
    ref.watch(liveActivityManagerProvider);

    return MaterialApp(
      title: 'Protofluff',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const _AppRouter(),
      routes: {
        '/scanner': (context) => const ScannerScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/messages': (context) => const MessagingScreen(),
        '/channels': (context) => const ChannelsScreen(),
        '/nodes': (context) => const NodesScreen(),
        '/map': (context) => const MapScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/qr-import': (context) => const QrImportScreen(),
        '/device-config': (context) => const DeviceConfigScreen(),
        '/region-setup': (context) =>
            const RegionSelectionScreen(isInitialSetup: true),
        '/main': (context) => const MainShell(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/timeline': (context) => const TimelineScreen(),
        '/presence': (context) => const PresenceScreen(),
      },
    );
  }
}

/// App router handles initialization and navigation flow
class _AppRouter extends ConsumerWidget {
  const _AppRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initState = ref.watch(appInitProvider);

    switch (initState) {
      case AppInitState.uninitialized:
      case AppInitState.initializing:
        return const _SplashScreen();
      case AppInitState.error:
        return const _ErrorScreen();
      case AppInitState.needsOnboarding:
        return const OnboardingScreen();
      case AppInitState.needsScanner:
        return const ScannerScreen();
      case AppInitState.initialized:
        return const MainShell();
    }
  }
}

/// Splash screen shown during app initialization
class _SplashScreen extends ConsumerWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoReconnectState = ref.watch(autoReconnectStateProvider);

    String statusText;
    switch (autoReconnectState) {
      case AutoReconnectState.scanning:
        statusText = 'Scanning for device...';
        break;
      case AutoReconnectState.connecting:
        statusText = 'Connecting...';
        break;
      default:
        statusText = 'Initializing...';
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/app_icons/source/protofluff_icon_1024.png',
                width: 120,
                height: 120,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Protofluff',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Privacy-first mesh social',
              style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryMagenta,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              statusText,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error screen shown when initialization fails
class _ErrorScreen extends ConsumerWidget {
  const _ErrorScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 24),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Failed to initialize the app. Please try again.',
                style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  ref.read(appInitProvider.notifier).initialize();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
