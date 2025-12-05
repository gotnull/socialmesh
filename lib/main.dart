import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'core/theme.dart';
import 'core/transport.dart';
import 'providers/app_providers.dart';
import 'models/mesh_models.dart';
import 'features/scanner/scanner_screen.dart';
import 'features/scanner/widgets/connecting_animation.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/messaging/messaging_screen.dart';
import 'features/channels/channels_screen.dart';
import 'features/nodes/nodes_screen.dart';
import 'features/nodes/node_qr_scanner_screen.dart';
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

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Firebase in background - don't block app startup
  // This ensures the app works fully offline
  _initializeFirebaseInBackground();

  runApp(const ProviderScope(child: SocialmeshApp()));
}

/// Initialize Firebase without blocking the main app.
/// Firebase/Crashlytics are nice-to-have for error reporting but
/// should never prevent the app from working offline.
Future<void> _initializeFirebaseInBackground() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint('Firebase init timed out - continuing offline');
        throw TimeoutException('Firebase initialization timed out');
      },
    );

    // Configure Crashlytics only if Firebase initialized successfully
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // Set up async error handler
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (e) {
    // Firebase failed to initialize (no internet, timeout, etc.)
    // App continues working fully offline - this is expected behavior
    debugPrint('Firebase unavailable: $e - app running in offline mode');
  }
}

class SocialmeshApp extends ConsumerStatefulWidget {
  const SocialmeshApp({super.key});

  @override
  ConsumerState<SocialmeshApp> createState() => _SocialmeshAppState();
}

class _SocialmeshAppState extends ConsumerState<SocialmeshApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appInitProvider.notifier).initialize();
      // Load accent color from settings
      _loadAccentColor();
    });
  }

  Future<void> _loadAccentColor() async {
    final settings = await ref.read(settingsServiceProvider.future);
    final colorValue = settings.accentColor;
    ref.read(accentColorProvider.notifier).state = Color(colorValue);
  }

  @override
  Widget build(BuildContext context) {
    // Watch auto-reconnect and live activity managers at app level
    // so they stay active regardless of which screen is shown
    ref.watch(autoReconnectManagerProvider);
    ref.watch(liveActivityManagerProvider);

    // Watch accent color for dynamic theme
    final accentColor = ref.watch(accentColorProvider);

    return MaterialApp(
      title: 'Socialmesh',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme(accentColor),
      themeMode: ThemeMode.dark,
      home: const _AppRouter(),
      routes: {
        '/scanner': (context) => const ScannerScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/messages': (context) => const MessagingScreen(),
        '/channels': (context) => const ChannelsScreen(),
        '/nodes': (context) => const NodesScreen(),
        '/node-qr-scanner': (context) => const NodeQrScannerScreen(),
        '/map': (context) => const MapScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/qr-import': (context) => const QrImportScreen(),
        '/channel-qr-scanner': (context) => const QrImportScreen(),
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
class _SplashScreen extends ConsumerStatefulWidget {
  const _SplashScreen();

  @override
  ConsumerState<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Taglines to cycle through
  static const _taglines = [
    'Privacy-first mesh social',
    'Off-grid communication',
    'Decentralized by design',
    'No internet required',
    'Community-powered network',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final autoReconnectState = ref.watch(autoReconnectStateProvider);
    final connectionState = ref.watch(connectionStateProvider);
    final discoveredNodes = ref.watch(discoveredNodesQueueProvider);

    // Listen for new node discoveries during splash
    ref.listen<MeshNode?>(nodeDiscoveryNotifierProvider, (previous, next) {
      if (next != null) {
        ref.read(discoveredNodesQueueProvider.notifier).addNode(next);
      }
    });

    // Determine status info based on current state
    final statusInfo = _getStatusInfo(autoReconnectState, connectionState);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: SafeArea(
        child: Stack(
          children: [
            // Beautiful parallax floating icons background
            const Positioned.fill(child: ConnectingAnimationBackground()),
            // Main centered content - unaffected by node cards
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/app_icons/source/socialmesh_icon_1024.png',
                      width: 120,
                      height: 120,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Socialmesh',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _AnimatedTagline(taglines: _taglines),
                  const SizedBox(height: 48),
                  // Animated status indicator
                  _buildStatusIndicator(statusInfo),
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

  _StatusInfo _getStatusInfo(
    AutoReconnectState autoState,
    AsyncValue<DeviceConnectionState> connState,
  ) {
    switch (autoState) {
      case AutoReconnectState.idle:
        return _StatusInfo(
          text: 'Initializing',
          icon: Icons.hourglass_empty_rounded,
          color: AppTheme.textSecondary,
          showSpinner: true,
        );
      case AutoReconnectState.scanning:
        return _StatusInfo(
          text: 'Scanning for device',
          icon: Icons.bluetooth_searching_rounded,
          color: AppTheme.primaryBlue,
          showSpinner: true,
        );
      case AutoReconnectState.connecting:
        final isConnected =
            connState.whenOrNull(
              data: (state) => state == DeviceConnectionState.connected,
            ) ??
            false;
        if (isConnected) {
          return _StatusInfo(
            text: 'Configuring device',
            icon: Icons.settings_rounded,
            color: AppTheme.primaryGreen,
            showSpinner: true,
          );
        }
        return _StatusInfo(
          text: 'Connecting',
          icon: Icons.bluetooth_connected_rounded,
          color: AppTheme.primaryMagenta,
          showSpinner: true,
        );
      case AutoReconnectState.success:
        return _StatusInfo(
          text: 'Connected',
          icon: Icons.check_circle_rounded,
          color: AppTheme.primaryGreen,
          showSpinner: false,
        );
      case AutoReconnectState.failed:
        return _StatusInfo(
          text: 'Connection failed',
          icon: Icons.error_outline_rounded,
          color: Colors.redAccent,
          showSpinner: false,
        );
    }
  }

  Widget _buildStatusIndicator(_StatusInfo info) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with optional spinner ring
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Spinner ring behind icon
                  if (info.showSpinner)
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          info.color.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  // Pulsing icon
                  Transform.scale(
                    scale: info.showSpinner ? _pulseAnimation.value : 1.0,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        info.icon,
                        key: ValueKey(info.icon),
                        color: info.color,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Animated text with dots
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Row(
                key: ValueKey(info.text),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    info.text,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: info.color,

                      letterSpacing: 0.3,
                    ),
                  ),
                  if (info.showSpinner) _AnimatedDots(color: info.color),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatusInfo {
  final String text;
  final IconData icon;
  final Color color;
  final bool showSpinner;

  const _StatusInfo({
    required this.text,
    required this.icon,
    required this.color,
    required this.showSpinner,
  });
}

/// Animated dots that cycle through visibility
class _AnimatedDots extends StatefulWidget {
  final Color color;

  const _AnimatedDots({required this.color});

  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            // Stagger the animation for each dot
            final dotProgress = ((progress * 3) - index).clamp(0.0, 1.0);
            final opacity = dotProgress < 0.5
                ? dotProgress * 2
                : 2 - (dotProgress * 2);
            return Padding(
              padding: const EdgeInsets.only(left: 1),
              child: Text(
                '.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: widget.color.withValues(
                    alpha: opacity.clamp(0.3, 1.0),
                  ),
                ),
              ),
            );
          }),
        );
      },
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

/// Animated tagline that cycles through different phrases with fade+slide
class _AnimatedTagline extends StatefulWidget {
  final List<String> taglines;

  const _AnimatedTagline({required this.taglines});

  /// Duration each tagline is displayed
  static const displayDuration = Duration(seconds: 3);

  /// Duration of the fade/slide animation
  static const animationDuration = Duration(milliseconds: 400);

  @override
  State<_AnimatedTagline> createState() => _AnimatedTaglineState();
}

class _AnimatedTaglineState extends State<_AnimatedTagline>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: _AnimatedTagline.animationDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    // Start with the first tagline visible
    _controller.forward();

    // Start cycling
    _startCycling();
  }

  void _startCycling() {
    Future.delayed(_AnimatedTagline.displayDuration, () {
      if (!mounted) return;
      _cycleToNext();
    });
  }

  Future<void> _cycleToNext() async {
    // Fade out
    await _controller.reverse();
    if (!mounted) return;

    // Change text
    setState(() {
      _currentIndex = (_currentIndex + 1) % widget.taglines.length;
    });

    // Fade in
    await _controller.forward();
    if (!mounted) return;

    // Schedule next cycle
    _startCycling();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Text(
          widget.taglines[_currentIndex],
          style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}
