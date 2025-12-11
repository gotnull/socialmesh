import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../core/widgets/demoscene_background.dart';
import '../../providers/app_providers.dart';
import '../scanner/scanner_screen.dart';

/// Onboarding screen for first-time users
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  double _pageOffset = 0.0;

  // Animation controller for page content
  late final AnimationController _pulseController;

  final List<_OnboardingPage> _pages = [
    _OnboardingPage(
      icon: null,
      lottieAsset: 'assets/lottie/onboard_mesh.json',
      title: 'The Mesh',
      description:
          'A decentralized network where every device\nbecomes a node. No towers. No subscriptions.',
      accentColor: AppTheme.primaryMagenta,
    ),
    _OnboardingPage(
      icon: Icons.chat_bubble_outline,
      lottieAsset: 'assets/lottie/onboard_chat.json',
      title: 'Off-Grid Comms',
      description:
          'Send messages through the mesh.\nDevice to device. Mile after mile.',
      accentColor: AccentColors.cyan,
    ),
    _OnboardingPage(
      icon: Icons.shield_outlined,
      lottieAsset: 'assets/lottie/onboard_shield.json',
      title: 'Zero Knowledge',
      description:
          'No accounts. No tracking. No cloud.\nYour messages never touch the internet.',
      accentColor: AccentColors.green,
    ),
    _OnboardingPage(
      icon: Icons.hub_outlined,
      lottieAsset: 'assets/lottie/onboard_connect.json',
      title: 'Grow the Network',
      description:
          'Every device extends the reach.\nBuild infrastructure that belongs to everyone.',
      accentColor: AppTheme.graphBlue,
    ),
    _OnboardingPage(
      icon: Icons.dashboard_customize,
      lottieAsset: null,
      title: 'Your Command Center',
      description:
          'Monitor signal strength, battery, node count,\nmessages, range and more. All in real-time.',
      accentColor: AccentColors.orange,
      isWidgetShowcase: true,
    ),
    _OnboardingPage(
      icon: Icons.rocket_launch_outlined,
      lottieAsset: 'assets/lottie/onboard_launch.json',
      title: 'Go Live',
      description:
          'Connect your radio and join the mesh.\nYour voice. Your network. Your rules.',
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

    // Initialize animation controller for page content
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
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
    final accentColor = _getInterpolatedAccentColor();

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Stack(
        children: [
          // Amiga demoscene-inspired animated background
          Positioned.fill(
            child: DemosceneBackground(
              pageOffset: _pageOffset,
              accentColor: accentColor,
            ),
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
          // Widget showcase or animated icon
          if (page.isWidgetShowcase)
            _buildWidgetShowcase(page)
          else
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final glowIntensity = 0.3 + (_pulseController.value * 0.2);

                // Use Lottie animation if available
                if (page.lottieAsset != null) {
                  return Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: page.accentColor.withValues(
                            alpha: glowIntensity,
                          ),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Lottie.asset(
                      page.lottieAsset!,
                      width: 220,
                      height: 220,
                      fit: BoxFit.contain,
                      repeat: true,
                    ),
                  );
                }

                // Fallback to icon
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
                        color: page.accentColor.withValues(
                          alpha: glowIntensity,
                        ),
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

  Widget _buildWidgetShowcase(_OnboardingPage page) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glowIntensity = 0.2 + (_pulseController.value * 0.15);

        return Container(
          width: double.infinity,
          height: 340,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: page.accentColor.withValues(alpha: glowIntensity),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.darkCard, AppTheme.darkSurface],
                ),
                border: Border.all(
                  color: page.accentColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  // Header with "Dashboard" title
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.dashboard_rounded,
                          color: page.accentColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Dashboard',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: page.accentColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'LIVE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: page.accentColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Signal strength chart (larger)
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildMiniSignalChart(page.accentColor),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Top row of widgets
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildMiniWidget(
                            Icons.hub,
                            '12',
                            'Nodes',
                            AccentColors.cyan,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildMiniWidget(
                            Icons.battery_5_bar,
                            '87%',
                            'Battery',
                            AccentColors.green,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildMiniWidget(
                            Icons.signal_cellular_alt,
                            '-68',
                            'dBm',
                            page.accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Bottom row of widgets
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildMiniWidget(
                            Icons.message,
                            '47',
                            'Messages',
                            AppTheme.primaryMagenta,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildMiniWidget(
                            Icons.map,
                            '3.2',
                            'km range',
                            AppTheme.graphBlue,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildMiniWidget(
                            Icons.schedule,
                            '2h',
                            'Uptime',
                            AccentColors.purple,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniSignalChart(Color accentColor) {
    // Animated bar chart simulation
    return LayoutBuilder(
      builder: (context, constraints) {
        final barCount = 20;
        final barWidth = (constraints.maxWidth - (barCount - 1) * 3) / barCount;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(barCount, (index) {
            // Simulate varying signal strength bars
            final baseHeight = 0.3 + (index / barCount) * 0.4;
            final variation = (index % 3 == 0
                ? 0.2
                : index % 2 == 0
                ? 0.1
                : 0.0);
            final animatedOffset =
                _pulseController.value * 0.15 * (index.isEven ? 1 : -1);
            final height = (baseHeight + variation + animatedOffset).clamp(
              0.2,
              1.0,
            );

            return Container(
              width: barWidth,
              height: constraints.maxHeight * height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [accentColor.withValues(alpha: 0.6), accentColor],
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildMiniWidget(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final IconData? icon;
  final String? lottieAsset;
  final String title;
  final String description;
  final bool isLastPage;
  final bool isWidgetShowcase;
  final Color accentColor;

  const _OnboardingPage({
    this.icon,
    this.lottieAsset,
    required this.title,
    required this.description,
    this.isLastPage = false,
    this.isWidgetShowcase = false,
    this.accentColor = AppTheme.primaryMagenta,
  });
}
