import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/gradient_border_container.dart';

/// Animated banner showing active signal count with pulsing indicator.
class ActiveSignalsBanner extends StatefulWidget {
  const ActiveSignalsBanner({super.key, required this.count});

  final int count;

  @override
  State<ActiveSignalsBanner> createState() => _ActiveSignalsBannerState();
}

class _ActiveSignalsBannerState extends State<ActiveSignalsBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = context.accentColor;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: GradientBorderContainer(
        borderRadius: 12,
        borderWidth: 2,
        accentOpacity: 0.3,
        backgroundColor: context.card,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Pulsing indicator
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(
                        alpha: _pulseAnimation.value * 0.6,
                      ),
                      blurRadius: 8 * _pulseAnimation.value,
                      spreadRadius: 2 * _pulseAnimation.value,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          Text(
            '${widget.count} ${widget.count == 1 ? "signal" : "signals"} active',
            style: TextStyle(
              color: accentColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        ),
      ),
    );
  }
}
