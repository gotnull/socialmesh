import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../providers/app_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../scanner/widgets/connecting_animation.dart';
import '../scanner/scanner_screen.dart';
import 'widgets/mesh_node_brain.dart';
import 'widgets/advisor_speech_bubble.dart';

/// Onboarding screen with mesh brain advisor guide
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

  // Pulse animation for page content
  late final AnimationController _pulseController;

  // Brain mood state
  MeshBrainMood _brainMood = MeshBrainMood.inviting;

  // Onboarding pages with advisor dialogue
  final List<_OnboardingPage> _pages = [
    _OnboardingPage(
      title: 'The Mesh',
      description:
          'A decentralized network where every device\nbecomes a node. No towers. No subscriptions.',
      advisorText:
          "Hey there! I'm Ico, your mesh network guide. I exist in the space between your devices. Connecting, relaying, surviving. Let me show you something incredible...",
      mood: MeshBrainMood.excited,
      accentColor: AppTheme.primaryMagenta,
    ),
    _OnboardingPage(
      title: 'Connect Any Way',
      description:
          'Bluetooth or USB. Wireless or wired.\nYour radio, your choice.',
      advisorText:
          "See that radio? Connect it however you like! Bluetooth for wireless freedom, USB for rock-solid reliability. I speak both languages fluently.",
      mood: MeshBrainMood.speaking,
      accentColor: AccentColors.cyan,
    ),
    _OnboardingPage(
      title: 'Broadcast Your Signal',
      description:
          'Share your presence with the mesh.\nPhotos, status, location. All off-grid.',
      advisorText:
          "Signals are your digital flare! Broadcast photos, your mood, or your location to nearby nodes. It all stays in the mesh. No internet, no problem.",
      mood: MeshBrainMood.approving,
      accentColor: AccentColors.pink,
    ),
    _OnboardingPage(
      title: 'See the World',
      description:
          'Explore the global mesh map in real-time.\nDownload maps for offline adventures.',
      advisorText:
          "Look at all those nodes! The World Map shows every node reporting in. Download regions for offline use. The mesh doesn't need WiFi, and neither do you.",
      mood: MeshBrainMood.excited,
      accentColor: AppTheme.graphBlue,
    ),
    _OnboardingPage(
      title: 'Zero Knowledge',
      description:
          'No accounts. No tracking. No cloud.\nYour messages never touch the internet.',
      advisorText:
          "I don't know who you are. I don't want to know. Your secrets stay encrypted, bouncing through the mesh. Even I can't read them. That's the beauty of it.",
      mood: MeshBrainMood.sassy,
      accentColor: AccentColors.green,
    ),
    _OnboardingPage(
      title: 'Automate Everything',
      description:
          'Battery alerts. Geofence triggers. Auto-replies.\nYour mesh, your rules.',
      advisorText:
          "I love a good automation! Set triggers for low battery, node offline alerts, or geofence events. I'll execute your commands while you sleep.",
      mood: MeshBrainMood.idle,
      accentColor: AccentColors.yellow,
    ),
    _OnboardingPage(
      title: 'Your Command Center',
      description:
          'Customizable dashboard widgets.\nHome screen widgets. Real-time telemetry.',
      advisorText:
          "This is mission control! Build your perfect dashboard with drag-and-drop widgets. Add them to your home screen too. I'll keep you informed of every pulse.",
      mood: MeshBrainMood.approving,
      isWidgetShowcase: true,
      accentColor: AccentColors.orange,
    ),
    _OnboardingPage(
      title: 'Go Live',
      description:
          'Connect your radio and join the mesh.\nYour voice. Your network. Your rules.',
      advisorText:
          "Ready to join the mesh? Connect your radio and become part of something unstoppable. I'll be here, inside every node, waiting to relay your first message!",
      mood: MeshBrainMood.celebrating,
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

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    // Initial mood
    _brainMood = _pages[0].mood;
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
      final settings = await ref.read(settingsServiceProvider.future);
      await settings.setOnboardingComplete(true);

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/main');
      }
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
      _brainMood = _pages[index].mood;
    });
  }

  void _onSpeechComplete() {
    // Speech complete - could trigger UI changes in the future
  }

  void _onBrainTap() {
    // Make the brain react to taps
    setState(() {
      _brainMood = MeshBrainMood.excited;
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _brainMood = _pages[_currentPage].mood;
        });
      }
    });
  }

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
    final meshConfigAsync = ref.watch(splashMeshConfigProvider);
    final meshConfig = meshConfigAsync.when(
      data: (config) => config,
      loading: () => SplashMeshConfig.defaultConfig,
      error: (_, _) => SplashMeshConfig.defaultConfig,
    );

    return Scaffold(
      backgroundColor: context.background,
      body: Stack(
        children: [
          // Animated background
          const Positioned.fill(child: ConnectingAnimationBackground()),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16, top: 8),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _currentPage < _pages.length - 1 ? 1.0 : 0.0,
                      child: TextButton(
                        onPressed: _currentPage < _pages.length - 1
                            ? _skip
                            : null,
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Main scrollable content area
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return _buildFullPage(index, accentColor, meshConfig);
                    },
                  ),
                ),

                // Page indicators
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: _buildPageIndicators(accentColor),
                ),

                // Action button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: _buildActionButton(accentColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullPage(
    int index,
    Color accentColor,
    SplashMeshConfig meshConfig,
  ) {
    final page = _pages[index];

    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        double value = 0.0;
        if (_pageController.position.haveDimensions) {
          value = index - (_pageController.page ?? 0);
          value = (value * 0.5).clamp(-1.0, 1.0);
        }

        final translateX = value * 100;
        final scaleValue = (1.0 - (value.abs() * 0.2)).clamp(0.8, 1.0);
        final opacity = 1.0 - (value.abs() * 0.5);

        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..setTranslationRaw(translateX, 0, 0)
              ..scaleByDouble(scaleValue, scaleValue, 1.0, 1.0),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: page.isWidgetShowcase
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                // Extra top spacing for non-widget pages to push content down
                if (!page.isWidgetShowcase) const SizedBox(height: 20),

                // Mesh Brain Advisor - uses global config for line/node sizes
                MeshNodeBrain(
                  size: page.isWidgetShowcase ? 80 : 100,
                  mood: _brainMood,
                  colors: [
                    accentColor,
                    Color.lerp(accentColor, AppTheme.primaryMagenta, 0.5)!,
                    Color.lerp(accentColor, AppTheme.graphBlue, 0.5)!,
                  ],
                  glowIntensity: meshConfig.glowIntensity,
                  lineThickness: meshConfig.lineThickness,
                  nodeSize: meshConfig.nodeSize,
                  onTap: _onBrainTap,
                ),

                // Advisor speech bubble
                AdvisorSpeechBubble(
                  key: ValueKey('speech_$index'),
                  text: page.advisorText,
                  accentColor: accentColor,
                  typewriterEffect: index == _currentPage,
                  typingSpeed: 25,
                  onTypingComplete: _onSpeechComplete,
                ),

                SizedBox(height: page.isWidgetShowcase ? 12 : 24),

                // Widget showcase (if applicable)
                if (page.isWidgetShowcase) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildWidgetShowcase(page),
                  ),
                  const SizedBox(height: 12),
                ],

                // Title and description
                _buildTitleSection(page),

                // Extra bottom spacing for non-widget pages
                if (!page.isWidgetShowcase) const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTitleSection(_OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          // Title
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
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),

          // Description
          Text(
            page.description,
            style: TextStyle(
              fontSize: 15,
              color: context.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicators(Color accentColor) {
    return Row(
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
                color: isActive ? null : context.border,
                borderRadius: BorderRadius.circular(5),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.4),
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
    );
  }

  Widget _buildActionButton(Color accentColor) {
    final isLastPage = _pages[_currentPage].isLastPage;

    return SizedBox(
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
              Color.lerp(accentColor, AppTheme.primaryPurple, 0.5) ??
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
                isLastPage ? 'Connect Device' : 'Continue',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isLastPage) ...[
                const SizedBox(width: 8),
                const Icon(Icons.bluetooth, size: 20),
              ],
            ],
          ),
        ),
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
          height: 130,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: page.accentColor.withValues(alpha: glowIntensity),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [context.card, context.surface],
                ),
                border: Border.all(
                  color: page.accentColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.dashboard_rounded,
                          color: page.accentColor,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Dashboard',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: page.accentColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'LIVE',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: page.accentColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Widgets
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
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
                  ),
                ],
              ),
            ),
          ),
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
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 9, color: context.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Data class for onboarding pages
class _OnboardingPage {
  final String title;
  final String description;
  final String advisorText;
  final MeshBrainMood mood;
  final bool isLastPage;
  final bool isWidgetShowcase;
  final Color accentColor;

  const _OnboardingPage({
    required this.title,
    required this.description,
    required this.advisorText,
    required this.mood,
    this.isLastPage = false,
    this.isWidgetShowcase = false,
    this.accentColor = AppTheme.primaryMagenta,
  });
}
