import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../providers/app_providers.dart';
import '../scanner/scanner_screen.dart';

/// Onboarding screen for first-time users
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  double _pageOffset = 0.0;

  // Animation controllers for the beautiful background
  late final AnimationController _floatController;
  late final AnimationController _pulseController;
  late final AnimationController _rotateController;
  late final List<_FloatingIcon> _icons;

  final List<_OnboardingPage> _pages = [
    _OnboardingPage(
      icon: null, // Uses app icon instead
      title: 'Welcome to Protofluff',
      description:
          'Privacy-first mesh messaging.\nCommunicate off-grid with your community.',
      useAppIcon: true,
      accentColor: AppTheme.primaryMagenta,
    ),
    _OnboardingPage(
      icon: Icons.wifi_tethering,
      title: 'Mesh Network',
      description:
          'Messages hop between devices,\nextending range without internet.',
      accentColor: AppTheme.primaryGreen,
    ),
    _OnboardingPage(
      icon: Icons.lock_outline,
      title: 'End-to-End Encrypted',
      description:
          'Your conversations are secured\nwith strong encryption by default.',
      accentColor: AppTheme.graphBlue,
    ),
    _OnboardingPage(
      icon: Icons.bluetooth,
      title: 'Connect Your Device',
      description: 'Pair your Meshtastic radio\nto start communicating.',
      isLastPage: true,
      accentColor: AppTheme.primaryPurple,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _pageController.addListener(() {
      setState(() {
        _pageOffset = _pageController.page ?? 0.0;
      });
    });

    // Initialize animation controllers
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();

    // Initialize floating icons
    _icons = [
      _FloatingIcon(
        icon: Icons.router,
        color: AppTheme.primaryGreen,
        size: 44,
        startX: 0.08,
        startY: 0.12,
        parallaxFactor: 0.8,
        floatAmplitude: 18,
        floatSpeed: 1.2,
      ),
      _FloatingIcon(
        icon: Icons.wifi_tethering,
        color: AppTheme.primaryMagenta,
        size: 38,
        startX: 0.88,
        startY: 0.1,
        parallaxFactor: 1.2,
        floatAmplitude: 22,
        floatSpeed: 0.9,
      ),
      _FloatingIcon(
        icon: Icons.cell_tower,
        color: AppTheme.graphBlue,
        size: 48,
        startX: 0.78,
        startY: 0.78,
        parallaxFactor: 0.6,
        floatAmplitude: 16,
        floatSpeed: 1.4,
      ),
      _FloatingIcon(
        icon: Icons.bluetooth,
        color: AppTheme.graphBlue.withValues(alpha: 0.8),
        size: 34,
        startX: 0.12,
        startY: 0.72,
        parallaxFactor: 1.0,
        floatAmplitude: 20,
        floatSpeed: 1.1,
      ),
      _FloatingIcon(
        icon: Icons.signal_cellular_alt,
        color: AppTheme.primaryGreen.withValues(alpha: 0.7),
        size: 30,
        startX: 0.92,
        startY: 0.42,
        parallaxFactor: 1.4,
        floatAmplitude: 14,
        floatSpeed: 1.3,
      ),
      _FloatingIcon(
        icon: Icons.sensors,
        color: AppTheme.warningYellow,
        size: 40,
        startX: 0.04,
        startY: 0.42,
        parallaxFactor: 0.7,
        floatAmplitude: 24,
        floatSpeed: 0.8,
      ),
      _FloatingIcon(
        icon: Icons.radio,
        color: AppTheme.primaryMagenta.withValues(alpha: 0.6),
        size: 36,
        startX: 0.65,
        startY: 0.06,
        parallaxFactor: 1.1,
        floatAmplitude: 18,
        floatSpeed: 1.0,
      ),
      _FloatingIcon(
        icon: Icons.hub,
        color: AppTheme.textSecondary,
        size: 32,
        startX: 0.28,
        startY: 0.88,
        parallaxFactor: 0.9,
        floatAmplitude: 22,
        floatSpeed: 1.2,
      ),
      _FloatingIcon(
        icon: Icons.device_hub,
        color: AppTheme.primaryGreen.withValues(alpha: 0.5),
        size: 28,
        startX: 0.48,
        startY: 0.18,
        parallaxFactor: 1.3,
        floatAmplitude: 14,
        floatSpeed: 0.95,
      ),
      _FloatingIcon(
        icon: Icons.podcasts,
        color: AppTheme.graphBlue.withValues(alpha: 0.6),
        size: 38,
        startX: 0.18,
        startY: 0.32,
        parallaxFactor: 0.5,
        floatAmplitude: 26,
        floatSpeed: 0.7,
      ),
      _FloatingIcon(
        icon: Icons.lan,
        color: AppTheme.primaryPurple.withValues(alpha: 0.5),
        size: 32,
        startX: 0.82,
        startY: 0.58,
        parallaxFactor: 0.85,
        floatAmplitude: 20,
        floatSpeed: 1.15,
      ),
      _FloatingIcon(
        icon: Icons.satellite_alt,
        color: AppTheme.warningYellow.withValues(alpha: 0.5),
        size: 36,
        startX: 0.38,
        startY: 0.68,
        parallaxFactor: 1.05,
        floatAmplitude: 18,
        floatSpeed: 0.85,
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    _floatController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    } else {
      _connectDevice();
    }
  }

  void _skip() {
    _pageController.animateToPage(
      _pages.length - 1,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _connectDevice() async {
    final result = await Navigator.of(context).push<DeviceInfo>(
      MaterialPageRoute(
        builder: (context) => const ScannerScreen(isOnboarding: true),
      ),
    );

    if (result != null && mounted) {
      // Device connected successfully - mark onboarding complete
      final settings = await ref.read(settingsServiceProvider.future);
      await settings.setOnboardingComplete(true);

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/main');
      }
    }
  }

  // Get interpolated accent color based on page scroll
  Color _getInterpolatedAccentColor() {
    final currentIndex = _pageOffset.floor();
    final nextIndex = (currentIndex + 1).clamp(0, _pages.length - 1);
    final t = _pageOffset - currentIndex;

    return Color.lerp(
          _pages[currentIndex].accentColor,
          _pages[nextIndex].accentColor,
          t,
        ) ??
        _pages[currentIndex].accentColor;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final accentColor = _getInterpolatedAccentColor();

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Stack(
        children: [
          // Animated gradient background that shifts with pages
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(
                      -0.5 + (_pageOffset * 0.3),
                      -0.3 + (_pageOffset * 0.1),
                    ),
                    radius: 1.5 + (_pulseController.value * 0.2),
                    colors: [
                      accentColor.withValues(alpha: 0.12),
                      AppTheme.darkBackground.withValues(alpha: 0.98),
                      AppTheme.darkBackground,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              );
            },
          ),

          // Floating icons with parallax - move based on page scroll
          ..._icons.map((iconData) => _buildFloatingIcon(iconData, size)),

          // Radiating lines animation
          AnimatedBuilder(
            animation: _rotateController,
            builder: (context, child) {
              return CustomPaint(
                size: size,
                painter: _RadiatingLinesPainter(
                  progress: _rotateController.value,
                  color: accentColor.withValues(alpha: 0.1),
                  pageOffset: _pageOffset,
                ),
              );
            },
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _currentPage < _pages.length - 1 ? 1.0 : 0.0,
                      child: TextButton(
                        onPressed: _currentPage < _pages.length - 1
                            ? _skip
                            : null,
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Page content with custom transitions
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return _buildAnimatedPage(index);
                    },
                  ),
                ),

                // Animated page indicators
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (index) {
                      final isActive = _currentPage == index;
                      final distance = (index - _pageOffset).abs();
                      final scale = (1.0 - distance * 0.3).clamp(0.5, 1.0);

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 28 : 10,
                        height: 10,
                        child: Transform.scale(
                          scale: scale,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: isActive
                                  ? LinearGradient(
                                      colors: [
                                        accentColor,
                                        accentColor.withValues(alpha: 0.7),
                                      ],
                                    )
                                  : null,
                              color: isActive ? null : AppTheme.darkBorder,
                              borderRadius: BorderRadius.circular(5),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: accentColor.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // Action button with animated gradient
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            accentColor,
                            Color.lerp(
                                  accentColor,
                                  AppTheme.primaryPurple,
                                  0.5,
                                ) ??
                                accentColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _pages[_currentPage].isLastPage
                                  ? 'Connect Device'
                                  : 'Continue',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_pages[_currentPage].isLastPage) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.bluetooth, size: 20),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedPage(int index) {
    final page = _pages[index];

    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        double value = 0.0;
        if (_pageController.position.haveDimensions) {
          value = index - (_pageController.page ?? 0);
          value = (value * 0.5).clamp(-1.0, 1.0);
        }

        // Calculate transforms for parallax effect
        final translateX = value * 100;
        final scaleValue = (1.0 - (value.abs() * 0.2)).clamp(0.8, 1.0);
        final opacity = 1.0 - (value.abs() * 0.5);

        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // perspective
              ..setTranslationRaw(translateX, 0, 0)
              ..scaleByDouble(scaleValue, scaleValue, 1.0, 1.0),
            alignment: Alignment.center,
            child: _buildPageContent(page, index),
          ),
        );
      },
    );
  }

  Widget _buildPageContent(_OnboardingPage page, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated icon/image with glow
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final glowIntensity = 0.3 + (_pulseController.value * 0.2);

              if (page.useAppIcon) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: page.accentColor.withValues(
                          alpha: glowIntensity,
                        ),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Image.asset(
                      'assets/app_icons/source/protofluff_icon_1024.png',
                      width: 140,
                      height: 140,
                    ),
                  ),
                );
              }

              return Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      page.accentColor.withValues(alpha: 0.3),
                      page.accentColor.withValues(alpha: 0.1),
                      Colors.transparent,
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: page.accentColor.withValues(alpha: glowIntensity),
                      blurRadius: 25,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: Container(
                  margin: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: page.accentColor.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: Icon(page.icon, size: 48, color: page.accentColor),
                ),
              );
            },
          ),
          const SizedBox(height: 48),

          // Title with shimmer-like gradient
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                Colors.white,
                Colors.white.withValues(alpha: 0.9),
                Colors.white,
              ],
            ).createShader(bounds),
            child: Text(
              page.title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            page.description,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingIcon(_FloatingIcon iconData, Size screenSize) {
    return AnimatedBuilder(
      animation: Listenable.merge([_floatController, _pulseController]),
      builder: (context, child) {
        // Calculate floating position with parallax
        final time = _floatController.value * 2 * math.pi * iconData.floatSpeed;
        final floatX =
            math.sin(time) * iconData.floatAmplitude * iconData.parallaxFactor;
        final floatY =
            math.cos(time * 0.7) *
            iconData.floatAmplitude *
            iconData.parallaxFactor;

        // Add page-based parallax movement
        final pageParallaxX = _pageOffset * 30 * iconData.parallaxFactor;

        // Subtle rotation
        final rotation = math.sin(time * 0.5) * 0.1;

        // Opacity pulse
        final opacity = 0.3 + (_pulseController.value * 0.25);

        return Positioned(
          left:
              screenSize.width * iconData.startX +
              floatX -
              pageParallaxX -
              iconData.size / 2,
          top: screenSize.height * iconData.startY + floatY - iconData.size / 2,
          child: Transform.rotate(
            angle: rotation,
            child: Icon(
              iconData.icon,
              size: iconData.size,
              color: iconData.color.withValues(alpha: opacity),
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingPage {
  final IconData? icon;
  final String title;
  final String description;
  final bool isLastPage;
  final bool useAppIcon;
  final Color accentColor;

  const _OnboardingPage({
    this.icon,
    required this.title,
    required this.description,
    this.isLastPage = false,
    this.useAppIcon = false,
    this.accentColor = AppTheme.primaryMagenta,
  });
}

class _FloatingIcon {
  final IconData icon;
  final Color color;
  final double size;
  final double startX;
  final double startY;
  final double parallaxFactor;
  final double floatAmplitude;
  final double floatSpeed;

  const _FloatingIcon({
    required this.icon,
    required this.color,
    required this.size,
    required this.startX,
    required this.startY,
    required this.parallaxFactor,
    required this.floatAmplitude,
    required this.floatSpeed,
  });
}

class _RadiatingLinesPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double pageOffset;

  _RadiatingLinesPainter({
    required this.progress,
    required this.color,
    required this.pageOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Center shifts based on page
    final centerX = size.width * (0.5 - pageOffset * 0.05);
    final centerY = size.height * 0.4;
    final center = Offset(centerX, centerY);
    final maxRadius = size.width * 0.7;

    // Draw subtle expanding circles
    for (var i = 0; i < 3; i++) {
      final circleProgress = (progress + i * 0.33) % 1.0;
      final radius = maxRadius * circleProgress;
      final opacity = (1.0 - circleProgress) * 0.3;

      paint.color = color.withValues(alpha: opacity);
      canvas.drawCircle(center, radius, paint);
    }

    // Draw radiating lines
    final numLines = 12;
    for (var i = 0; i < numLines; i++) {
      final angle = (i / numLines) * 2 * math.pi + (progress * math.pi * 0.5);
      final lineLength = maxRadius * 0.6;
      final startOffset = 80.0;

      final start = Offset(
        center.dx + math.cos(angle) * startOffset,
        center.dy + math.sin(angle) * startOffset,
      );
      final end = Offset(
        center.dx + math.cos(angle) * lineLength,
        center.dy + math.sin(angle) * lineLength,
      );

      final lineProgress = (progress * 2 + i / numLines) % 1.0;
      paint.color = color.withValues(alpha: 0.05 + lineProgress * 0.1);

      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadiatingLinesPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.pageOffset != pageOffset;
}
