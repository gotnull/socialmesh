// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/safety/lifecycle_mixin.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../providers/glyph_provider.dart';
import '../../services/glyph_matrix_service.dart';

/// Nothing Phone 3 Glyph Matrix Test Screen
/// Features a live on-screen preview of the 25x25 LED matrix with circular mask
class GlyphTestScreen extends ConsumerStatefulWidget {
  const GlyphTestScreen({super.key});

  @override
  ConsumerState<GlyphTestScreen> createState() => _GlyphTestScreenState();
}

class _GlyphTestScreenState extends ConsumerState<GlyphTestScreen>
    with TickerProviderStateMixin, LifecycleSafeMixin<GlyphTestScreen> {
  final GlyphMatrixService _matrixService = GlyphMatrixService();

  // Current pattern state - 25x25 grid of brightness values (0.0 to 1.0)
  List<List<double>> _matrixState = List.generate(
    25,
    (_) => List.filled(25, 0.0),
  );

  int _selectedPatternIndex = 0;
  bool _isExecuting = false;
  Timer? _autoOffTimer;
  Timer? _animationTimer;

  // Animation controllers
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  // Pattern definitions
  final List<_PatternDef> _patterns = [
    _PatternDef(
      name: 'PULSE',
      icon: Icons.radio_button_checked,
      color: const Color(0xFF00D4FF),
      generate: _generatePulse,
    ),
    _PatternDef(
      name: 'BORDER',
      icon: Icons.crop_square,
      color: const Color(0xFF00FF88),
      generate: _generateBorder,
    ),
    _PatternDef(
      name: 'CROSS',
      icon: Icons.close,
      color: const Color(0xFFFF3366),
      generate: _generateCross,
    ),
    _PatternDef(
      name: 'DOTS',
      icon: Icons.grid_on,
      color: const Color(0xFFAA66FF),
      generate: _generateDots,
    ),
    _PatternDef(
      name: 'FULL',
      icon: Icons.brightness_7,
      color: const Color(0xFFFFAA00),
      generate: _generateFull,
    ),
    _PatternDef(
      name: 'SPIRAL',
      icon: Icons.radar,
      color: const Color(0xFFFF66AA),
      generate: _generateSpiral,
    ),
    _PatternDef(
      name: 'WAVE',
      icon: Icons.waves,
      color: const Color(0xFF66FFAA),
      generate: _generateWave,
    ),
    _PatternDef(
      name: 'HEART',
      icon: Icons.favorite,
      color: const Color(0xFFFF4466),
      generate: _generateHeart,
    ),
    _PatternDef(
      name: 'MESH',
      icon: Icons.hub,
      color: const Color(0xFF4488FF),
      generate: _generateMesh,
    ),
  ];

  late PageController _pageController;

  @override
  void initState() {
    super.initState();

    _pageController = PageController(viewportFraction: 0.35, initialPage: 0);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Show initial pattern preview (without executing on launch)
    final pattern = _patterns[_selectedPatternIndex];
    safeSetState(() {
      _matrixState = pattern.generate();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _glowController.dispose();
    _autoOffTimer?.cancel();
    _animationTimer?.cancel();
    _matrixService.turnOff();
    super.dispose();
  }

  void _updatePreview(int index) {
    final pattern = _patterns[index];
    safeSetState(() {
      _matrixState = pattern.generate();
      _selectedPatternIndex = index;
    });
    // Immediately execute the pattern when selected
    _executePattern();
  }

  Future<void> _executePattern() async {
    if (_isExecuting) return;

    safeSetState(() => _isExecuting = true);
    HapticFeedback.mediumImpact();

    _autoOffTimer?.cancel();

    try {
      final pattern = _patterns[_selectedPatternIndex];

      // Map pattern name to native method
      switch (pattern.name) {
        case 'PULSE':
          await _matrixService.showPattern('pulse');
        case 'BORDER':
          await _matrixService.showPattern('border');
        case 'CROSS':
          await _matrixService.showPattern('cross');
        case 'DOTS':
          await _matrixService.showPattern('dots');
        case 'FULL':
          await _matrixService.showPattern('full');
        case 'SPIRAL':
          await _executeCustomPattern(_generateSpiral());
        case 'WAVE':
          await _executeCustomPattern(_generateWave());
        case 'HEART':
          await _executeCustomPattern(_generateHeart());
        case 'MESH':
          await _executeCustomPattern(_generateMesh());
      }

      // Auto-off after 3 seconds
      _autoOffTimer = Timer(const Duration(seconds: 3), () async {
        await _matrixService.turnOff();
        safeSetState(() {
          _matrixState = List.generate(25, (_) => List.filled(25, 0.0));
        });
      });
    } finally {
      safeSetState(() => _isExecuting = false);
    }
  }

  Future<void> _executeCustomPattern(List<List<double>> pattern) async {
    // Convert to flat brightness array for native
    final pixels = <int>[];
    for (var y = 0; y < 25; y++) {
      for (var x = 0; x < 25; x++) {
        pixels.add((pattern[y][x] * 255).round().clamp(0, 255));
      }
    }
    await _matrixService.setMatrix(pixels);
  }

  Future<void> _turnOff() async {
    _autoOffTimer?.cancel();
    _animationTimer?.cancel();
    await _matrixService.turnOff();
    if (!mounted) return;
    HapticFeedback.lightImpact();
    safeSetState(() {
      _matrixState = List.generate(25, (_) => List.filled(25, 0.0));
    });
  }

  // ============== Pattern Generators ==============

  static List<List<double>> _generatePulse() {
    final matrix = List.generate(25, (_) => List.filled(25, 0.0));
    const center = 12.0;
    const maxDist = 12.0;

    for (var y = 0; y < 25; y++) {
      for (var x = 0; x < 25; x++) {
        final dx = x - center;
        final dy = y - center;
        final dist = math.sqrt(dx * dx + dy * dy);
        matrix[y][x] = (1.0 - (dist / maxDist)).clamp(0.0, 1.0);
      }
    }
    return matrix;
  }

  static List<List<double>> _generateBorder() {
    final matrix = List.generate(25, (_) => List.filled(25, 0.0));
    for (var i = 0; i < 25; i++) {
      matrix[0][i] = 1.0;
      matrix[24][i] = 1.0;
      matrix[i][0] = 1.0;
      matrix[i][24] = 1.0;
    }
    return matrix;
  }

  static List<List<double>> _generateCross() {
    final matrix = List.generate(25, (_) => List.filled(25, 0.0));
    for (var i = 0; i < 25; i++) {
      matrix[i][i] = 1.0;
      matrix[i][24 - i] = 1.0;
    }
    return matrix;
  }

  static List<List<double>> _generateDots() {
    final matrix = List.generate(25, (_) => List.filled(25, 0.0));
    for (var y = 0; y < 25; y += 4) {
      for (var x = 0; x < 25; x += 4) {
        matrix[y][x] = 1.0;
      }
    }
    return matrix;
  }

  static List<List<double>> _generateFull() {
    return List.generate(25, (_) => List.filled(25, 1.0));
  }

  static List<List<double>> _generateSpiral() {
    final matrix = List.generate(25, (_) => List.filled(25, 0.0));
    const center = 12.0;

    for (var y = 0; y < 25; y++) {
      for (var x = 0; x < 25; x++) {
        final dx = x - center;
        final dy = y - center;
        final angle = math.atan2(dy, dx);
        final dist = math.sqrt(dx * dx + dy * dy);
        final spiralPhase = (angle + dist * 0.5) % (2 * math.pi);
        if (spiralPhase < math.pi * 0.3 && dist < 12) {
          matrix[y][x] = 1.0 - (dist / 12);
        }
      }
    }
    return matrix;
  }

  static List<List<double>> _generateWave() {
    final matrix = List.generate(25, (_) => List.filled(25, 0.0));
    for (var y = 0; y < 25; y++) {
      for (var x = 0; x < 25; x++) {
        final wave = math.sin(x * 0.5) * 0.5 + 0.5;
        final yPos = (12 + wave * 5).round();
        if ((y - yPos).abs() <= 2) {
          matrix[y][x] = 1.0 - ((y - yPos).abs() * 0.3);
        }
      }
    }
    return matrix;
  }

  static List<List<double>> _generateHeart() {
    final matrix = List.generate(25, (_) => List.filled(25, 0.0));
    const center = 12.0;

    for (var y = 0; y < 25; y++) {
      for (var x = 0; x < 25; x++) {
        final nx = (x - center) / 8;
        final ny = (y - center) / 8;
        // Heart equation: (x^2 + y^2 - 1)^3 - x^2 * y^3 = 0
        final val = math.pow(nx * nx + ny * ny - 1, 3) - nx * nx * ny * ny * ny;
        if (val <= 0) {
          matrix[y][x] = 1.0;
        }
      }
    }
    return matrix;
  }

  static List<List<double>> _generateMesh() {
    final matrix = List.generate(25, (_) => List.filled(25, 0.0));
    final random = math.Random(42); // Fixed seed for consistent pattern

    // Create nodes
    final nodes = <(int, int)>[];
    for (var i = 0; i < 8; i++) {
      nodes.add((random.nextInt(21) + 2, random.nextInt(21) + 2));
    }

    // Draw nodes
    for (final node in nodes) {
      final (x, y) = node;
      if (x >= 0 && x < 25 && y >= 0 && y < 25) {
        matrix[y][x] = 1.0;
        // Glow around node
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            final nx = x + dx;
            final ny = y + dy;
            if (nx >= 0 && nx < 25 && ny >= 0 && ny < 25) {
              matrix[ny][nx] = math.max(matrix[ny][nx], 0.5);
            }
          }
        }
      }
    }

    // Draw connections (simplified)
    for (var i = 0; i < nodes.length - 1; i++) {
      final (x1, y1) = nodes[i];
      final (x2, y2) = nodes[i + 1];
      _drawLine(matrix, x1, y1, x2, y2, 0.3);
    }

    return matrix;
  }

  static void _drawLine(
    List<List<double>> matrix,
    int x1,
    int y1,
    int x2,
    int y2,
    double brightness,
  ) {
    final dx = (x2 - x1).abs();
    final dy = (y2 - y1).abs();
    final sx = x1 < x2 ? 1 : -1;
    final sy = y1 < y2 ? 1 : -1;
    var err = dx - dy;
    var x = x1;
    var y = y1;

    while (true) {
      if (x >= 0 && x < 25 && y >= 0 && y < 25) {
        matrix[y][x] = math.max(matrix[y][x], brightness);
      }
      if (x == x2 && y == y2) break;
      final e2 = 2 * err;
      if (e2 > -dy) {
        err -= dy;
        x += sx;
      }
      if (e2 < dx) {
        err += dx;
        y += sy;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final glyphService = ref.watch(glyphServiceProvider);
    final initState = ref.watch(glyphServiceInitProvider);
    final isSupported = ref.watch(glyphSupportedProvider);

    return GlassScaffold.body(
      titleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GLYPH MATRIX',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: 2,
            ),
          ),
          Text(
            glyphService.deviceModel.toUpperCase(),
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.power_settings_new,
            color: _matrixState.any((row) => row.any((v) => v > 0))
                ? Colors.redAccent
                : Colors.white30,
          ),
          onPressed: _turnOff,
          tooltip: 'Turn off',
        ),
      ],
      body: initState.when(
        loading: () => _buildLoadingState(),
        error: (error, _) => _buildErrorState(error),
        data: (_) => isSupported
            ? _buildMainContent(context)
            : _buildNotSupportedState(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.white30),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'INITIALIZING GLYPH MATRIX...',
            style: TextStyle(
              color: Colors.white30,
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            SizedBox(height: 16),
            Text(
              'INIT FAILED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotSupportedState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phonelink_off, size: 64, color: Colors.white30),
            SizedBox(height: 24),
            Text(
              'DEVICE NOT SUPPORTED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Glyph Matrix requires\nNothing Phone (3)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    final currentPattern = _patterns[_selectedPatternIndex];

    return Column(
      children: [
        // Matrix Preview
        Expanded(
          flex: 3,
          child: Center(
            child: AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: currentPattern.color.withValues(
                          alpha: _glowAnimation.value * 0.5,
                        ),
                        blurRadius: 60,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: _GlyphMatrixPreview(
                matrix: _matrixState,
                accentColor: currentPattern.color,
                isExecuting: _isExecuting,
              ),
            ),
          ),
        ),

        // Pattern name with executing indicator
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isExecuting)
                Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(currentPattern.color),
                    ),
                  ),
                ),
              Text(
                currentPattern.name,
                style: TextStyle(
                  color: currentPattern.color,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 8),

        // Swipe hint
        Text(
          '← SWIPE TO EXECUTE →',
          style: TextStyle(
            color: Colors.white30,
            fontSize: 12,
            letterSpacing: 2,
          ),
        ),

        SizedBox(height: 24),

        // Swipeable pattern selector - swipe executes immediately
        SizedBox(
          height: 120,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              HapticFeedback.selectionClick();
              _updatePreview(index);
            },
            itemCount: _patterns.length,
            itemBuilder: (context, index) {
              final pattern = _patterns[index];
              final isSelected = index == _selectedPatternIndex;

              return AnimatedScale(
                scale: isSelected ? 1.0 : 0.8,
                duration: Duration(milliseconds: 200),
                child: AnimatedOpacity(
                  opacity: isSelected ? 1.0 : 0.5,
                  duration: Duration(milliseconds: 200),
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? pattern.color.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? pattern.color
                            : Colors.white.withValues(alpha: 0.1),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: pattern.color.withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          pattern.icon,
                          color: isSelected ? pattern.color : Colors.white54,
                          size: 36,
                        ),
                        SizedBox(height: 8),
                        Text(
                          pattern.name,
                          style: TextStyle(
                            color: isSelected ? pattern.color : Colors.white54,
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        SizedBox(height: 24),
      ],
    );
  }
}

/// Pattern definition
class _PatternDef {
  final String name;
  final IconData icon;
  final Color color;
  final List<List<double>> Function() generate;

  const _PatternDef({
    required this.name,
    required this.icon,
    required this.color,
    required this.generate,
  });
}

/// Visual preview of the 25x25 LED matrix with circular mask
/// Matches the actual Nothing Phone 3 glyph layout
class _GlyphMatrixPreview extends StatelessWidget {
  final List<List<double>> matrix;
  final Color accentColor;
  final bool isExecuting;

  const _GlyphMatrixPreview({
    required this.matrix,
    required this.accentColor,
    this.isExecuting = false,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.maxWidth;
            return SizedBox(
              width: size,
              height: size,
              child: CustomPaint(
                size: Size(size, size),
                painter: _GlyphMatrixPainter(
                  matrix: matrix,
                  accentColor: accentColor,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Custom painter for the glyph matrix
/// Draws LEDs with proper circular boundary matching Phone 3 specs
class _GlyphMatrixPainter extends CustomPainter {
  final List<List<double>> matrix;
  final Color accentColor;

  static const int gridSize = 25;

  _GlyphMatrixPainter({required this.matrix, required this.accentColor});

  // Pre-computed mask matching the actual Phone 3 LED layout
  // true = LED exists at this position, false = outside circular boundary
  static const List<List<bool>> _ledMask = [
    // Row 0  (y=0)
    [
      false,
      false,
      false,
      false,
      false,
      false,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    // Row 1
    [
      false,
      false,
      false,
      false,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
    ],
    // Row 2
    [
      false,
      false,
      false,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
    ],
    // Row 3
    [
      false,
      false,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
    ],
    // Row 4
    [
      false,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      false,
    ],
    // Row 5
    [
      false,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      false,
    ],
    // Row 6
    [
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
    ],
    // Row 7
    [
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
    ],
    // Row 8
    [
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
    ],
    // Row 9
    [
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
    ],
    // Row 10
    [
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
    ],
    // Row 11
    [
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
    ],
    // Row 12 (center)
    [
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
    ],
    // Row 13
    [
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
    ],
    // Row 14
    [
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
    ],
    // Row 15
    [
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
    ],
    // Row 16
    [
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
    ],
    // Row 17
    [
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
    ],
    // Row 18
    [
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
    ],
    // Row 19
    [
      false,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      false,
    ],
    // Row 20
    [
      false,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      false,
    ],
    // Row 21
    [
      false,
      false,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
    ],
    // Row 22
    [
      false,
      false,
      false,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
    ],
    // Row 23
    [
      false,
      false,
      false,
      false,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
    ],
    // Row 24 (y=24)
    [
      false,
      false,
      false,
      false,
      false,
      false,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / gridSize;
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.5;

    // Background circle
    final bgPaint = Paint()
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, maxRadius, bgPaint);

    // Outer ring glow
    final ringPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, maxRadius - 2, ringPaint);

    // Draw LEDs using exact mask
    for (var y = 0; y < gridSize; y++) {
      for (var x = 0; x < gridSize; x++) {
        // Skip LEDs outside the circular boundary
        if (!_ledMask[y][x]) continue;

        final ledCenter = Offset((x + 0.5) * cellSize, (y + 0.5) * cellSize);
        final brightness = matrix[y][x].clamp(0.0, 1.0);
        final ledRadius = cellSize * 0.4;

        if (brightness > 0) {
          // LED glow
          final glowPaint = Paint()
            ..color = accentColor.withValues(alpha: brightness * 0.3)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, cellSize * 0.4);
          canvas.drawCircle(ledCenter, ledRadius * 1.3, glowPaint);

          // LED body - white when on
          final ledPaint = Paint()
            ..color = Color.lerp(
              const Color(0xFF1C1C1C),
              const Color(0xFFFFFFFF),
              brightness,
            )!;
          canvas.drawCircle(ledCenter, ledRadius, ledPaint);
        } else {
          // Off LED (dim gray per spec: #1C1C1C)
          final offPaint = Paint()..color = const Color(0xFF1C1C1C);
          canvas.drawCircle(ledCenter, ledRadius, offPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_GlyphMatrixPainter oldDelegate) {
    return oldDelegate.matrix != matrix ||
        oldDelegate.accentColor != accentColor;
  }
}
