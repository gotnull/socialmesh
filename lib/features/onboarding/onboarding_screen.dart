import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../core/widgets/auto_scroll_text.dart';
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

  final List<_OnboardingPage> _pages = [
    _OnboardingPage(
      title: 'Welcome to Socialmesh',
      description:
          'The most advanced Meshtastic companion app.\nBuilt for professionals. Designed for everyone.',
      advisorText:
          "I'm Ico, your mesh intelligence. I'll guide you through a communication platform that works when nothing else does.",
      mood: MeshBrainMood.focused,
      accentColor: AppTheme.primaryMagenta,
    ),

    _OnboardingPage(
      title: 'Off-Grid by Design',
      description:
          'No cellular towers. No internet required.\nTrue peer-to-peer radio communication.',
      advisorText:
          "Every message hops through the mesh until it reaches its destination. Range measured in kilometers, not bars.",
      mood: MeshBrainMood.speaking,
      accentColor: AccentColors.cyan,
    ),

    _OnboardingPage(
      title: 'Compatible Hardware',
      description:
          'Works with all Meshtastic-compatible devices.\nFrom compact trackers to long-range stations.',
      advisorText:
          "Pick up a SenseCAP T1000-E for tracking, a Heltec V3 for range, or a RAK WisMesh for reliability. I'll work with any of them.",
      mood: MeshBrainMood.approving,
      showcaseType: ShowcaseType.devices,
      accentColor: AccentColors.green,
    ),

    _OnboardingPage(
      title: 'Signals',
      description:
          'Ephemeral broadcasts across the mesh.\nShare presence, photos, and location - then let them fade.',
      advisorText:
          "Signals are what set us apart. Broadcast to everyone in range, watch them ripple through the network, then disappear on your terms.",
      mood: MeshBrainMood.excited,
      showcaseType: ShowcaseType.signals,
      accentColor: AccentColors.pink,
    ),

    _OnboardingPage(
      title: 'Intelligent Automations',
      description:
          'Trigger actions based on mesh events.\nBattery alerts, geofences, keywords, and more.',
      advisorText:
          "Set up rules once, and I'll monitor everything. Low battery? I'll alert you. Node goes silent? I'll let you know. SOS received? I'll trigger your webhook.",
      mood: MeshBrainMood.focused,
      showcaseType: ShowcaseType.automations,
      accentColor: AccentColors.yellow,
    ),

    _OnboardingPage(
      title: 'Your Command Center',
      description:
          'Customizable dashboard with live telemetry.\nTrack nodes, monitor channels, visualize the network.',
      advisorText:
          "Widgets, maps, stats - arrange them however you work. Your mesh, your view, your control.",
      mood: MeshBrainMood.approving,
      showcaseType: ShowcaseType.widgets,
      accentColor: AccentColors.orange,
    ),

    _OnboardingPage(
      title: 'Privacy First',
      description:
          'No accounts required. No cloud by default.\nYour data stays on your device.',
      advisorText:
          "Everything is local unless you explicitly enable cloud sync. No tracking, no analytics, no compromise.",
      mood: MeshBrainMood.focused,
      accentColor: AppTheme.graphBlue,
    ),

    _OnboardingPage(
      title: 'Ready to Connect',
      description:
          'Pair your Meshtastic device to begin.\nBluetooth or USB - your choice.',
      advisorText:
          "Once connected, we operate completely offline. The mesh is waiting.",
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
    final hasShowcase = page.showcaseType != null;

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
              mainAxisAlignment: hasShowcase
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                // Extra top spacing for non-showcase pages to push content down
                if (!hasShowcase) const SizedBox(height: 20),

                // Mesh Brain Advisor - uses global config for line/node sizes
                MeshNodeBrain(
                  size: hasShowcase ? 80 : 100,
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

                SizedBox(height: hasShowcase ? 12 : 24),

                // Showcase section
                if (page.showcaseType != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildShowcase(page),
                  ),
                  const SizedBox(height: 12),
                ],

                // Title and description
                _buildTitleSection(page),

                // Extra bottom spacing for non-showcase pages
                if (!hasShowcase) const SizedBox(height: 40),
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

  Widget _buildDeviceShowcase(_OnboardingPage page) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glowIntensity = 0.25 + (_pulseController.value * 0.2);

        return SizedBox(
          height: 150,
          child: ShaderMask(
            shaderCallback: (Rect bounds) {
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: const [0.0, 0.05, 0.9, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _buildDeviceCard(
                  name: 'SenseCAP T1000-E',
                  category: 'Tracker',
                  description: 'Compact GPS tracker with long battery life',
                  icon: Icons.gps_fixed,
                  color: AccentColors.green,
                  glowIntensity: glowIntensity,
                  isPopular: true,
                ),
                const SizedBox(width: 12),
                _buildDeviceCard(
                  name: 'Heltec V3',
                  category: 'All-Purpose',
                  description: 'Versatile node with built-in display',
                  icon: Icons.memory,
                  color: AccentColors.cyan,
                  glowIntensity: glowIntensity,
                ),
                const SizedBox(width: 12),
                _buildDeviceCard(
                  name: 'RAK WisMesh',
                  category: 'Professional',
                  description: 'Industrial-grade reliability',
                  icon: Icons.router,
                  color: AccentColors.orange,
                  glowIntensity: glowIntensity,
                ),
                const SizedBox(width: 12),
                _buildDeviceCard(
                  name: 'LilyGo T-Beam',
                  category: 'Long Range',
                  description: 'Maximum range with external antenna',
                  icon: Icons.cell_tower,
                  color: AccentColors.pink,
                  glowIntensity: glowIntensity,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeviceCard({
    required String name,
    required String category,
    required String description,
    required IconData icon,
    required Color color,
    required double glowIntensity,
    bool isPopular = false,
  }) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPopular
              ? color.withValues(alpha: 0.5)
              : context.border.withValues(alpha: 0.3),
          width: isPopular ? 1.5 : 1,
        ),
        boxShadow: isPopular
            ? [
                BoxShadow(
                  color: color.withValues(alpha: glowIntensity * 0.5),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and popular badge
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.3),
                      color.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: color,
                ),
              ),
              const Spacer(),
              if (isPopular)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'POPULAR',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: color,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Category
          Text(
            category.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          // Name
          Text(
            name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          // Description
          Text(
            description,
            style: TextStyle(
              fontSize: 10,
              color: context.textTertiary,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildShowcase(_OnboardingPage page) {
    switch (page.showcaseType!) {
      case ShowcaseType.devices:
        return _buildDeviceShowcase(page);
      case ShowcaseType.signals:
        return _buildSignalsShowcase(page);
      case ShowcaseType.automations:
        return _buildAutomationsShowcase(page);
      case ShowcaseType.widgets:
        return _buildWidgetsShowcase(page);
    }
  }

  Widget _buildSignalsShowcase(_OnboardingPage page) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glowIntensity = 0.2 + (_pulseController.value * 0.15);

        return SizedBox(
          height: 180,
          child: ShaderMask(
            shaderCallback: (Rect bounds) {
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: const [0.0, 0.05, 0.9, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _buildSignalCard(
                  authorName: 'Sarah',
                  content: 'Just reached the summit! Signal is crystal clear up here.',
                  hasImage: true,
                  ttlMinutes: 23,
                  hopCount: 1,
                  color: AccentColors.pink,
                  glowIntensity: glowIntensity,
                  isLive: true,
                ),
                const SizedBox(width: 12),
                _buildSignalCard(
                  authorName: 'Mike',
                  content: 'Base camp is set. Ready when you are.',
                  hasLocation: true,
                  ttlMinutes: 45,
                  hopCount: 0,
                  color: AccentColors.cyan,
                  glowIntensity: glowIntensity,
                ),
                const SizedBox(width: 12),
                _buildSignalCard(
                  authorName: 'Alex',
                  content: 'On my way, ETA 15 min',
                  ttlMinutes: 8,
                  hopCount: 2,
                  color: AccentColors.yellow,
                  glowIntensity: glowIntensity,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSignalCard({
    required String authorName,
    required String content,
    required int ttlMinutes,
    required int hopCount,
    required Color color,
    required double glowIntensity,
    bool hasImage = false,
    bool hasLocation = false,
    bool isLive = false,
  }) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLive
              ? color.withValues(alpha: 0.4)
              : context.border.withValues(alpha: 0.5),
          width: isLive ? 1.5 : 1,
        ),
        boxShadow: isLive
            ? [
                BoxShadow(
                  color: color.withValues(alpha: glowIntensity * 0.4),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - matches real SignalCard
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.person,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                // Name and hop count
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Hop badge - matches ProximityBadge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: hopCount == 0
                              ? AccentColors.green.withValues(alpha: 0.2)
                              : context.surface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          hopCount == 0 ? 'Direct' : '$hopCount hop${hopCount > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: hopCount == 0
                                ? AccentColors.green
                                : context.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLive)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AccentColors.green,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AccentColors.green.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              content,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 13,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Image placeholder
          if (hasImage)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_rounded, color: color, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Photo',
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Location
          if (hasLocation)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: AccentColors.green, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Location shared',
                    style: TextStyle(
                      color: AccentColors.green,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          const Spacer(),
          // TTL Footer - matches SignalTTLFooter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: context.border.withValues(alpha: 0.3)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 14,
                  color: ttlMinutes < 10
                      ? AppTheme.errorRed
                      : context.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${ttlMinutes}m remaining',
                  style: TextStyle(
                    fontSize: 11,
                    color: ttlMinutes < 10
                        ? AppTheme.errorRed
                        : context.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutomationsShowcase(_OnboardingPage page) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glowIntensity = 0.2 + (_pulseController.value * 0.15);

        return SizedBox(
          height: 140,
          child: ShaderMask(
            shaderCallback: (Rect bounds) {
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: const [0.0, 0.05, 0.9, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _buildAutomationCard(
                  name: 'Low Battery Alert',
                  description: 'Battery drops below 20%',
                  icon: Icons.battery_alert,
                  color: AppTheme.errorRed,
                  glowIntensity: glowIntensity,
                  isEnabled: true,
                ),
                const SizedBox(width: 12),
                _buildAutomationCard(
                  name: 'Base Camp Geofence',
                  description: 'Enters designated area',
                  icon: Icons.location_searching,
                  color: AccentColors.green,
                  glowIntensity: glowIntensity,
                  isEnabled: true,
                ),
                const SizedBox(width: 12),
                _buildAutomationCard(
                  name: 'Node Silent Watch',
                  description: 'No contact for 30 min',
                  icon: Icons.timer_off,
                  color: AccentColors.orange,
                  glowIntensity: glowIntensity,
                  isEnabled: true,
                ),
                const SizedBox(width: 12),
                _buildAutomationCard(
                  name: 'SOS Keyword',
                  description: 'Message contains "SOS"',
                  icon: Icons.text_fields,
                  color: AccentColors.cyan,
                  glowIntensity: glowIntensity,
                  isEnabled: false,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAutomationCard({
    required String name,
    required String description,
    required IconData icon,
    required Color color,
    required double glowIntensity,
    required bool isEnabled,
  }) {
    // Matches actual AutomationCard styling
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEnabled
              ? color.withValues(alpha: 0.3)
              : context.border,
        ),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: color.withValues(alpha: glowIntensity * 0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Trigger icon - matches AutomationCard
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isEnabled
                      ? color.withValues(alpha: 0.2)
                      : context.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isEnabled ? color : Colors.grey,
                  size: 20,
                ),
              ),
              const Spacer(),
              // Toggle indicator
              Container(
                width: 36,
                height: 20,
                decoration: BoxDecoration(
                  color: isEnabled
                      ? AccentColors.green
                      : context.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Align(
                  alignment: isEnabled
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AutoScrollText(
            name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: isEnabled ? context.textPrimary : Colors.grey,
            ),
            maxLines: 1,
            velocity: 25,
            delayBefore: const Duration(seconds: 2),
          ),
          const SizedBox(height: 2),
          AutoScrollText(
            description,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
            maxLines: 1,
            velocity: 25,
            delayBefore: const Duration(seconds: 3),
          ),
        ],
      ),
    );
  }

  Widget _buildWidgetsShowcase(_OnboardingPage page) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glowIntensity = 0.2 + (_pulseController.value * 0.15);

        return Container(
          height: 140,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: page.accentColor.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: page.accentColor.withValues(alpha: glowIntensity * 0.3),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Row(
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
                      color: context.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AccentColors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AccentColors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AccentColors.green,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Widget grid
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildDashboardWidget(
                        icon: Icons.hub,
                        value: '12',
                        label: 'Nodes Online',
                        color: AccentColors.cyan,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDashboardWidget(
                        icon: Icons.battery_5_bar,
                        value: '87%',
                        label: 'Battery',
                        color: AccentColors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDashboardWidget(
                        icon: Icons.signal_cellular_alt,
                        value: '-68',
                        label: 'SNR dB',
                        color: page.accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDashboardWidget({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: context.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Types of showcases available in onboarding
enum ShowcaseType {
  devices,
  signals,
  automations,
  widgets,
}

/// Data class for onboarding pages
class _OnboardingPage {
  final String title;
  final String description;
  final String advisorText;
  final MeshBrainMood mood;
  final bool isLastPage;
  final ShowcaseType? showcaseType;
  final Color accentColor;

  const _OnboardingPage({
    required this.title,
    required this.description,
    required this.advisorText,
    required this.mood,
    this.isLastPage = false,
    this.showcaseType,
    this.accentColor = AppTheme.primaryMagenta,
  });
}
