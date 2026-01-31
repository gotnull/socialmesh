// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../providers/splash_mesh_provider.dart';
import '../widgets/mesh_node_brain.dart';

/// A test screen to preview all of Ico's emotional states
class MeshBrainEmotionTestScreen extends ConsumerStatefulWidget {
  const MeshBrainEmotionTestScreen({super.key});

  @override
  ConsumerState<MeshBrainEmotionTestScreen> createState() =>
      _MeshBrainEmotionTestScreenState();
}

class _MeshBrainEmotionTestScreenState
    extends ConsumerState<MeshBrainEmotionTestScreen> {
  MeshBrainMood _selectedMood = MeshBrainMood.idle;
  String _selectedCategory = 'All';
  double _brainSize = 160;
  double _glowIntensity = 0.8;
  bool _showParticles = true;
  bool _showExpression = true;

  final List<String> _categories = [
    'All',
    'Positive',
    'Neutral',
    'Alert',
    'Negative',
    'Special',
  ];

  List<MeshBrainMood> get _filteredMoods {
    if (_selectedCategory == 'All') {
      return MeshBrainMood.values;
    }
    return MeshBrainMood.values
        .where((mood) => mood.category == _selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final meshConfigAsync = ref.watch(splashMeshConfigProvider);
    final meshConfig = meshConfigAsync.when(
      data: (config) => config,
      loading: () => SplashMeshConfig.defaultConfig,
      error: (_, _) => SplashMeshConfig.defaultConfig,
    );

    return GlassScaffold(
      title: 'Emotion Configurator',
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: _showSettingsSheet,
          tooltip: 'Settings',
        ),
      ],
      slivers: [
        // Fixed brain preview at top
        SliverToBoxAdapter(child: _buildFixedBrainPreview(isDark, meshConfig)),

        // Category filter
        SliverToBoxAdapter(child: _buildCategoryFilter(theme)),

        // Scrollable emotion grid
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final mood = _filteredMoods[index];
              return _buildEmotionCard(mood, theme, isDark);
            }, childCount: _filteredMoods.length),
          ),
        ),
      ],
    );
  }

  Widget _buildFixedBrainPreview(bool isDark, SplashMeshConfig meshConfig) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF1A1A2E), const Color(0xFF0A0A0F)]
              : [Colors.blue.shade50, Colors.grey.shade100],
        ),
      ),
      child: Stack(
        children: [
          // Background grid pattern
          _buildGridPattern(isDark),

          // Main content
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Brain preview
              SizedBox(
                height: 180,
                child: Center(
                  child: MeshNodeBrain(
                    size: _brainSize * 0.85,
                    mood: _selectedMood,
                    glowIntensity: _glowIntensity,
                    lineThickness: meshConfig.lineThickness,
                    nodeSize: meshConfig.nodeSize,
                    showThoughtParticles: _showParticles,
                    showExpression: _showExpression,
                    onTap: _cycleMood,
                  ),
                ),
              ),

              // Current mood info
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _selectedMood.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedMood.displayName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(
                        _selectedMood.category,
                      ).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _getCategoryColor(
                          _selectedMood.category,
                        ).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      _selectedMood.category,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getCategoryColor(_selectedMood.category),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridPattern(bool isDark) {
    return Opacity(
      opacity: isDark ? 0.1 : 0.05,
      child: CustomPaint(
        size: const Size(double.infinity, 400),
        painter: _GridPatternPainter(color: isDark ? Colors.cyan : Colors.blue),
      ),
    );
  }

  Widget _buildCategoryFilter(ThemeData theme) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = category;
                });
              },
              backgroundColor: _getCategoryColor(
                category,
              ).withValues(alpha: 0.1),
              selectedColor: _getCategoryColor(category).withValues(alpha: 0.3),
              labelStyle: TextStyle(
                color: isSelected
                    ? _getCategoryColor(category)
                    : theme.textTheme.bodyMedium?.color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected
                    ? _getCategoryColor(category)
                    : Colors.transparent,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmotionCard(MeshBrainMood mood, ThemeData theme, bool isDark) {
    final isSelected = mood == _selectedMood;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMood = mood;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isDark
              ? (isSelected ? const Color(0xFF1A1A2E) : const Color(0xFF12121A))
              : (isSelected ? Colors.white : Colors.grey[200]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? _getCategoryColor(mood.category)
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _getCategoryColor(
                      mood.category,
                    ).withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Static mood indicator (no animations for performance)
            _buildStaticMoodIndicator(mood, isSelected),

            const SizedBox(height: 4),

            // Emoji
            Text(mood.emoji, style: const TextStyle(fontSize: 18)),

            const SizedBox(height: 2),

            // Name
            Text(
              mood.displayName,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Static mood indicator - simple colored glow without animations
  Widget _buildStaticMoodIndicator(MeshBrainMood mood, bool isSelected) {
    final colors = _getMoodColors(mood);
    final baseColor = colors[1];

    return SizedBox(
      height: 60,
      width: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  baseColor.withValues(alpha: isSelected ? 0.4 : 0.2),
                  baseColor.withValues(alpha: isSelected ? 0.15 : 0.05),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),
          // Core icosahedron representation (simple diamond shape)
          CustomPaint(
            size: const Size(28, 28),
            painter: _SimpleMeshPainter(
              color: baseColor,
              glowIntensity: isSelected ? 0.8 : 0.5,
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getMoodColors(MeshBrainMood mood) {
    switch (mood) {
      case MeshBrainMood.love:
        return const [Color(0xFFFF69B4), Color(0xFFFF1493), Color(0xFFFF69B4)];
      case MeshBrainMood.angry:
        return const [Color(0xFFFF4444), Color(0xFFCC0000), Color(0xFFFF6666)];
      case MeshBrainMood.sad:
        return const [Color(0xFF6699CC), Color(0xFF336699), Color(0xFF99CCFF)];
      case MeshBrainMood.scared:
        return const [Color(0xFF9966CC), Color(0xFF663399), Color(0xFFCC99FF)];
      case MeshBrainMood.error:
        return const [Color(0xFFFF0000), Color(0xFFCC0000), Color(0xFFFF3333)];
      case MeshBrainMood.success:
        return const [Color(0xFF00FF00), Color(0xFF00CC00), Color(0xFF66FF66)];
      case MeshBrainMood.energized:
        return const [Color(0xFFFFFF00), Color(0xFFFFCC00), Color(0xFFFFFF66)];
      case MeshBrainMood.zen:
        return const [Color(0xFF00FFFF), Color(0xFF00CCCC), Color(0xFF66FFFF)];
      case MeshBrainMood.glitching:
        return const [Color(0xFF00FF00), Color(0xFFFF00FF), Color(0xFF00FFFF)];
      case MeshBrainMood.embarrassed:
        return const [Color(0xFFFF9999), Color(0xFFFF6666), Color(0xFFFFCCCC)];
      default:
        return const [Color(0xFFFF6B4A), Color(0xFFE91E8C), Color(0xFF4F6AF6)];
    }
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildSettingsSheet(),
    );
  }

  Widget _buildSettingsSheet() {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Brain Settings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),

              const SizedBox(height: 24),

              // Size slider
              _buildSliderRow('Size', _brainSize, 80, 240, (value) {
                setSheetState(() => _brainSize = value);
                setState(() => _brainSize = value);
              }, isDark),

              const SizedBox(height: 16),

              // Glow intensity slider
              _buildSliderRow('Glow Intensity', _glowIntensity, 0, 2, (value) {
                setSheetState(() => _glowIntensity = value);
                setState(() => _glowIntensity = value);
              }, isDark),

              const SizedBox(height: 24),

              // Toggle switches
              _buildToggleRow('Show Particles', _showParticles, (value) {
                setSheetState(() => _showParticles = value);
                setState(() => _showParticles = value);
              }, isDark),

              const SizedBox(height: 12),

              _buildToggleRow('Show Expression Effects', _showExpression, (
                value,
              ) {
                setSheetState(() => _showExpression = value);
                setState(() => _showExpression = value);
              }, isDark),

              const SizedBox(height: 32),

              // Reset button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setSheetState(() {
                      _brainSize = 160;
                      _glowIntensity = 0.8;
                      _showParticles = true;
                      _showExpression = true;
                    });
                    setState(() {
                      _brainSize = 160;
                      _glowIntensity = 0.8;
                      _showParticles = true;
                      _showExpression = true;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset to Defaults'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            Text(
              value.toStringAsFixed(1),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.cyan : Colors.blue,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
          activeColor: isDark ? Colors.cyan : Colors.blue,
        ),
      ],
    );
  }

  Widget _buildToggleRow(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
    bool isDark,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: (isDark ? Colors.cyan : Colors.blue).withValues(
            alpha: 0.5,
          ),
          activeThumbColor: isDark ? Colors.cyan : Colors.blue,
        ),
      ],
    );
  }

  void _cycleMood() {
    final currentIndex = MeshBrainMood.values.indexOf(_selectedMood);
    final nextIndex = (currentIndex + 1) % MeshBrainMood.values.length;
    setState(() {
      _selectedMood = MeshBrainMood.values[nextIndex];
    });
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Positive':
        return const Color(0xFF4CAF50);
      case 'Neutral':
        return const Color(0xFF2196F3);
      case 'Alert':
        return const Color(0xFFFF9800);
      case 'Negative':
        return const Color(0xFFF44336);
      case 'Special':
        return const Color(0xFF9C27B0);
      case 'All':
      default:
        return const Color(0xFF607D8B);
    }
  }
}

/// Grid pattern painter for background
class _GridPatternPainter extends CustomPainter {
  final Color color;

  _GridPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const spacing = 30.0;

    // Vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Simple static mesh painter for grid items (no animations)
class _SimpleMeshPainter extends CustomPainter {
  final Color color;
  final double glowIntensity;

  _SimpleMeshPainter({required this.color, required this.glowIntensity});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw a simple diamond/icosahedron shape
    final path = Path();

    // Top point
    path.moveTo(center.dx, center.dy - radius);
    // Right point
    path.lineTo(center.dx + radius * 0.9, center.dy);
    // Bottom point
    path.lineTo(center.dx, center.dy + radius);
    // Left point
    path.lineTo(center.dx - radius * 0.9, center.dy);
    path.close();

    // Outer glow
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3 * glowIntensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path, glowPaint);

    // Fill
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.15 * glowIntensity);
    canvas.drawPath(path, fillPaint);

    // Stroke
    final strokePaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, strokePaint);

    // Inner lines for mesh effect
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Cross lines
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      linePaint,
    );
    canvas.drawLine(
      Offset(center.dx - radius * 0.9, center.dy),
      Offset(center.dx + radius * 0.9, center.dy),
      linePaint,
    );

    // Center node
    final nodePaint = Paint()..color = color;
    canvas.drawCircle(center, 3, nodePaint);

    final nodeGlowPaint = Paint()..color = Colors.white.withValues(alpha: 0.7);
    canvas.drawCircle(center, 1.5, nodeGlowPaint);
  }

  @override
  bool shouldRepaint(_SimpleMeshPainter oldDelegate) =>
      color != oldDelegate.color || glowIntensity != oldDelegate.glowIntensity;
}
