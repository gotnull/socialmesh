import 'package:flutter/material.dart';
import '../widgets/mesh_node_brain.dart';

/// A test screen to preview all MeshNodeBrain emotional states
class MeshBrainEmotionTestScreen extends StatefulWidget {
  const MeshBrainEmotionTestScreen({super.key});

  @override
  State<MeshBrainEmotionTestScreen> createState() =>
      _MeshBrainEmotionTestScreenState();
}

class _MeshBrainEmotionTestScreenState
    extends State<MeshBrainEmotionTestScreen> {
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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0F) : Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          // Collapsing header with large brain preview
          SliverAppBar(
            expandedHeight: 380,
            pinned: true,
            backgroundColor: isDark
                ? const Color(0xFF0A0A0F)
                : Colors.grey[100],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeroPreview(isDark),
            ),
            title: const Text('Emotion Configurator'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: _showSettingsSheet,
                tooltip: 'Settings',
              ),
            ],
          ),

          // Category filter
          SliverToBoxAdapter(child: _buildCategoryFilter(theme)),

          // Emotion grid
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

          // Bottom padding
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }

  Widget _buildHeroPreview(bool isDark) {
    return Container(
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
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),
                // Brain preview
                SizedBox(
                  height: 200,
                  child: Center(
                    child: MeshNodeBrain(
                      size: _brainSize,
                      mood: _selectedMood,
                      glowIntensity: _glowIntensity,
                      showThoughtParticles: _showParticles,
                      showExpression: _showExpression,
                      onTap: _cycleMood,
                    ),
                  ),
                ),

                // Current mood info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _selectedMood.emoji,
                            style: const TextStyle(fontSize: 28),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _selectedMood.displayName,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(
                            _selectedMood.category,
                          ).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getCategoryColor(
                              _selectedMood.category,
                            ).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          _selectedMood.category,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _getCategoryColor(_selectedMood.category),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
            // Mini brain preview
            SizedBox(
              height: 70,
              width: 70,
              child: MeshNodeBrain(
                size: 45,
                mood: mood,
                glowIntensity: 0.6,
                showThoughtParticles: false,
                showExpression: false,
                interactive: false,
              ),
            ),

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
