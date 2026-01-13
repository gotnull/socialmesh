import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../providers/glyph_provider.dart';
import '../../services/glyph_matrix_service.dart';

/// Pattern definition for swipable demo
class _GlyphPattern {
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final Future<void> Function(GlyphMatrixService service) execute;

  const _GlyphPattern({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.execute,
  });
}

/// Screen for testing Nothing Phone 3 GlyphMatrix patterns
/// Features swipable pattern cards that execute when swiped
class GlyphTestScreen extends ConsumerStatefulWidget {
  const GlyphTestScreen({super.key});

  @override
  ConsumerState<GlyphTestScreen> createState() => _GlyphTestScreenState();
}

class _GlyphTestScreenState extends ConsumerState<GlyphTestScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.85);
  final GlyphMatrixService _matrixService = GlyphMatrixService();
  int _currentIndex = 0;
  bool _isExecuting = false;
  Timer? _autoOffTimer;

  final List<_GlyphPattern> _patterns = [
    _GlyphPattern(
      name: 'Pulse',
      description: 'Radial gradient emanating from center',
      icon: Icons.radio_button_checked,
      color: Colors.blue,
      execute: (s) async {
        await s.showPattern('pulse');
      },
    ),
    _GlyphPattern(
      name: 'Border',
      description: 'Illuminated frame around the edge',
      icon: Icons.crop_square,
      color: Colors.green,
      execute: (s) async {
        await s.showPattern('border');
      },
    ),
    _GlyphPattern(
      name: 'Cross',
      description: 'Diagonal X pattern across the matrix',
      icon: Icons.close,
      color: Colors.red,
      execute: (s) async {
        await s.showPattern('cross');
      },
    ),
    _GlyphPattern(
      name: 'Dots',
      description: 'Scattered dot grid pattern',
      icon: Icons.grid_on,
      color: Colors.purple,
      execute: (s) async {
        await s.showPattern('dots');
      },
    ),
    _GlyphPattern(
      name: 'Full',
      description: 'All 625 LEDs at maximum brightness',
      icon: Icons.brightness_7,
      color: Colors.orange,
      execute: (s) async {
        await s.showPattern('full');
      },
    ),
    _GlyphPattern(
      name: 'Progress 25%',
      description: 'Quarter filled progress bar',
      icon: Icons.battery_1_bar,
      color: Colors.teal,
      execute: (s) async {
        await s.showProgress(25);
      },
    ),
    _GlyphPattern(
      name: 'Progress 50%',
      description: 'Half filled progress bar',
      icon: Icons.battery_3_bar,
      color: Colors.teal,
      execute: (s) async {
        await s.showProgress(50);
      },
    ),
    _GlyphPattern(
      name: 'Progress 75%',
      description: 'Three-quarter filled progress bar',
      icon: Icons.battery_5_bar,
      color: Colors.teal,
      execute: (s) async {
        await s.showProgress(75);
      },
    ),
    _GlyphPattern(
      name: 'Progress 100%',
      description: 'Fully filled progress bar',
      icon: Icons.battery_full,
      color: Colors.teal,
      execute: (s) async {
        await s.showProgress(100);
      },
    ),
    _GlyphPattern(
      name: 'Text: M',
      description: 'Display the letter M for Mesh',
      icon: Icons.text_fields,
      color: Colors.indigo,
      execute: (s) async {
        await s.showText('M');
      },
    ),
    _GlyphPattern(
      name: 'Connected',
      description: 'Quick pulse for connection established',
      icon: Icons.bluetooth_connected,
      color: Colors.lightBlue,
      execute: (s) async {
        await s.showConnected();
      },
    ),
    _GlyphPattern(
      name: 'Disconnected',
      description: 'Border flash for disconnection',
      icon: Icons.bluetooth_disabled,
      color: Colors.grey,
      execute: (s) async {
        await s.showDisconnected();
      },
    ),
    _GlyphPattern(
      name: 'Message',
      description: 'Cross pattern for message received',
      icon: Icons.message,
      color: Colors.amber,
      execute: (s) async {
        await s.showMessageReceived();
      },
    ),
    _GlyphPattern(
      name: 'Node Online',
      description: 'Dots pattern when a node comes online',
      icon: Icons.sensors,
      color: Colors.lime,
      execute: (s) async {
        await s.showNodeOnline();
      },
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _autoOffTimer?.cancel();
    _matrixService.turnOff();
    super.dispose();
  }

  Future<void> _executePattern(_GlyphPattern pattern) async {
    if (_isExecuting) return;

    setState(() => _isExecuting = true);
    _autoOffTimer?.cancel();

    try {
      await pattern.execute(_matrixService);

      // Auto-off after 3 seconds
      _autoOffTimer = Timer(const Duration(seconds: 3), () async {
        await _matrixService.turnOff();
      });
    } finally {
      if (mounted) {
        setState(() => _isExecuting = false);
      }
    }
  }

  Future<void> _turnOff() async {
    _autoOffTimer?.cancel();
    await _matrixService.turnOff();
  }

  @override
  Widget build(BuildContext context) {
    final glyphService = ref.watch(glyphServiceProvider);
    final initState = ref.watch(glyphServiceInitProvider);
    final isSupported = ref.watch(glyphSupportedProvider);

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Glyph Matrix Test',
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            Text(
              glyphService.deviceModel,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.lightbulb_outline, color: context.textSecondary),
            onPressed: _turnOff,
            tooltip: 'Turn off',
          ),
        ],
      ),
      body: initState.when(
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Initializing Glyph Matrix...',
                style: TextStyle(color: context.textSecondary),
              ),
            ],
          ),
        ),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Glyph init failed',
                style: TextStyle(color: context.textPrimary, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  error.toString(),
                  style: TextStyle(color: context.textSecondary, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        data: (_) => isSupported
            ? _buildPatternCarousel(context)
            : _buildNotSupportedMessage(context),
      ),
    );
  }

  Widget _buildPatternCarousel(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Swipe to preview patterns',
            style: TextStyle(color: context.textSecondary, fontSize: 16),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Tap card to execute on your Phone 3',
            style: TextStyle(color: context.textTertiary, fontSize: 14),
          ),
        ),

        const SizedBox(height: 32),

        // Pattern cards carousel
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _patterns.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              // Execute pattern when swiped
              _executePattern(_patterns[index]);
            },
            itemBuilder: (context, index) {
              final pattern = _patterns[index];
              final isActive = index == _currentIndex;

              return AnimatedScale(
                scale: isActive ? 1.0 : 0.9,
                duration: const Duration(milliseconds: 200),
                child: AnimatedOpacity(
                  opacity: isActive ? 1.0 : 0.6,
                  duration: const Duration(milliseconds: 200),
                  child: BouncyTap(
                    onTap: () => _executePattern(pattern),
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            pattern.color.withValues(alpha: 0.8),
                            pattern.color.withValues(alpha: 0.4),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: pattern.color.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Icon
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              pattern.icon,
                              size: 64,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Pattern name
                          Text(
                            pattern.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Description
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              pattern.description,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 16,
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Executing indicator
                          if (_isExecuting && isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Executing...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Page indicator
        Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _patterns.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: index == _currentIndex ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: index == _currentIndex
                      ? _patterns[_currentIndex].color
                      : context.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),

        // Turn off button
        Padding(
          padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _turnOff,
              icon: const Icon(Icons.lightbulb_outline),
              label: const Text('Turn Off All LEDs'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.textSecondary,
                side: BorderSide(color: context.border),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotSupportedMessage(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lightbulb_outline, size: 80, color: context.textTertiary),
          const SizedBox(height: 24),
          Text(
            'Glyph Matrix Not Available',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'This feature requires a Nothing Phone (3) with GlyphMatrix SDK support.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textSecondary, fontSize: 15),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 48),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.phone_android, color: context.textSecondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Detected Device',
                        style: TextStyle(color: context.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  ref.watch(glyphServiceProvider).deviceModel,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
