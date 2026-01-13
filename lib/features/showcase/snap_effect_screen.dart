import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/snappable.dart';

/// Demo screen to test the Thanos snap disintegration effect
class SnapEffectScreen extends StatefulWidget {
  const SnapEffectScreen({super.key});

  @override
  State<SnapEffectScreen> createState() => _SnapEffectScreenState();
}

class _SnapEffectScreenState extends State<SnapEffectScreen> {
  final List<GlobalKey<SnappableState>> _keys = [];
  final List<_DemoCard> _cards = [];

  @override
  void initState() {
    super.initState();
    _generateCards();
  }

  void _generateCards() {
    _cards.clear();
    _keys.clear();

    _cards.addAll([
      _DemoCard(
        id: 0,
        title: 'MESH NETWORK',
        subtitle: 'Off-grid communication',
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        icon: Icons.hub,
      ),
      _DemoCard(
        id: 1,
        title: 'SIGNAL BOOST',
        subtitle: 'Amplify your reach',
        gradient: const LinearGradient(
          colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        icon: Icons.signal_cellular_alt,
      ),
      _DemoCard(
        id: 2,
        title: 'NODE ONLINE',
        subtitle: 'Connected to network',
        gradient: const LinearGradient(
          colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        icon: Icons.sensors,
      ),
      _DemoCard(
        id: 3,
        title: 'SECURE CHANNEL',
        subtitle: 'End-to-end encrypted',
        gradient: const LinearGradient(
          colors: [Color(0xFFFC466B), Color(0xFF3F5EFB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        icon: Icons.lock,
      ),
      _DemoCard(
        id: 4,
        title: 'BROADCAST',
        subtitle: 'Reach everyone',
        gradient: const LinearGradient(
          colors: [Color(0xFFff9a9e), Color(0xFFfecfef)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        icon: Icons.cell_tower,
      ),
    ]);

    // Create keys for each card
    for (int i = 0; i < _cards.length; i++) {
      _keys.add(GlobalKey<SnappableState>());
    }
  }

  void _snapCard(int index) {
    HapticFeedback.heavyImpact();
    final key = _keys[index];
    final state = key.currentState;
    if (state != null) {
      if (state.isGone) {
        state.reset();
      } else {
        state.snap();
      }
    }
  }

  void _resetAll() {
    HapticFeedback.mediumImpact();
    for (final key in _keys) {
      key.currentState?.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Snap Effect',
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontWeight: FontWeight.w300,
            letterSpacing: 2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset all cards',
            onPressed: _resetAll,
          ),
        ],
      ),
      body: Column(
        children: [
          // Instructions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.touch_app,
                    color: Colors.white.withValues(alpha: 0.6),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tap a card to snap it away (Thanos style)',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                        fontFamily: 'JetBrains Mono',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Cards list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _cards.length,
              itemBuilder: (context, index) {
                final card = _cards[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildSnapCard(card, index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSnapCard(_DemoCard card, int index) {
    return Snappable(
      key: _keys[index],
      duration: const Duration(milliseconds: 3000),
      offset: const Offset(100, -50),
      randomDislocationOffset: const Offset(40, 20),
      numberOfBuckets: 24,
      onSnapped: () {
        debugPrint('Card ${card.title} snapped!');
      },
      child: GestureDetector(
        onTap: () => _snapCard(index),
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            gradient: card.gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (card.gradient.colors.first).withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Background pattern
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CustomPaint(
                    painter: _PatternPainter(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(card.icon, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),

                    // Text
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'JetBrains Mono',
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            card.subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontFamily: 'JetBrains Mono',
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Snap hint
                    Icon(
                      Icons.auto_awesome,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoCard {
  final int id;
  final String title;
  final String subtitle;
  final LinearGradient gradient;
  final IconData icon;

  _DemoCard({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.icon,
  });
}

class _PatternPainter extends CustomPainter {
  final Color color;

  _PatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw subtle grid pattern
    const spacing = 30.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_PatternPainter oldDelegate) => color != oldDelegate.color;
}
