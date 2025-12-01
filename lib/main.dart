import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme.dart';
import 'core/transport.dart';
import 'providers/app_providers.dart';
import 'models/mesh_models.dart';
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
import 'features/discovery/node_discovery_overlay.dart';

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
    final connectionState = ref.watch(connectionStateProvider);
    final discoveredNodes = ref.watch(discoveredNodesQueueProvider);

    // Listen for new node discoveries during splash
    ref.listen<MeshNode?>(nodeDiscoveryNotifierProvider, (previous, next) {
      if (next != null) {
        ref.read(discoveredNodesQueueProvider.notifier).addNode(next);
      }
    });

    // Determine status text based on current state
    String statusText;
    switch (autoReconnectState) {
      case AutoReconnectState.idle:
        statusText = 'Initializing...';
        break;
      case AutoReconnectState.scanning:
        statusText = 'Scanning for device...';
        break;
      case AutoReconnectState.connecting:
        // Check if actually connected but still configuring
        final isConnected =
            connectionState.whenOrNull(
              data: (state) => state == DeviceConnectionState.connected,
            ) ??
            false;
        statusText = isConnected ? 'Configuring device...' : 'Connecting...';
        break;
      case AutoReconnectState.success:
        statusText = 'Connected!';
        break;
      case AutoReconnectState.failed:
        statusText = 'Connection failed';
        break;
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: SafeArea(
        child: Stack(
          children: [
            // Main centered content - unaffected by node cards
            Center(
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
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
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
            // Node discovery cards - absolutely positioned at bottom
            if (discoveredNodes.isNotEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: discoveredNodes.take(4).map((entry) {
                    return _SplashNodeCard(
                      key: ValueKey(entry.id),
                      entry: entry,
                      onDismiss: () {
                        ref
                            .read(discoveredNodesQueueProvider.notifier)
                            .removeNode(entry.id);
                      },
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Animated node card for splash screen
class _SplashNodeCard extends StatefulWidget {
  final DiscoveredNodeEntry entry;
  final VoidCallback onDismiss;

  const _SplashNodeCard({
    super.key,
    required this.entry,
    required this.onDismiss,
  });

  @override
  State<_SplashNodeCard> createState() => _SplashNodeCardState();
}

class _SplashNodeCardState extends State<_SplashNodeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 50,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    // Start fade out after delay
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.entry.node;
    final longName = node.longName ?? '';
    final shortName = node.shortName ?? '';
    final displayName = longName.isNotEmpty
        ? longName
        : shortName.isNotEmpty
        ? shortName
        : 'Unknown Node';
    final nodeId = node.nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0');

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(scale: _scaleAnimation.value, child: child),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.darkCard.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryGreen.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Node icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: shortName.isNotEmpty
                    ? Text(
                        shortName.substring(0, shortName.length.clamp(0, 2)),
                        style: const TextStyle(
                          color: AppTheme.primaryGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                      )
                    : const Icon(
                        Icons.person,
                        color: AppTheme.primaryGreen,
                        size: 18,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Node info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '!$nodeId',
                    style: const TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            // Discovered badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.radar, size: 12, color: AppTheme.primaryGreen),
                  const SizedBox(width: 4),
                  const Text(
                    'Found',
                    style: TextStyle(
                      color: AppTheme.primaryGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
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
