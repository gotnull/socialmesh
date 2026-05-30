// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Interactive Morse visual for the onboarding flow (screen 7).
//
// The user taps to emit pulses. Each tap sends a ripple across the field and
// adds a dot/dash to a short sequence, hinting that the mesh carries more than
// modern messaging - lightweight signals work too. Tapping it themselves makes
// the idea land.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme.dart';

/// Tap-to-emit Morse ripple field.
class MorseDash extends StatefulWidget {
  const MorseDash({
    super.key,
    required this.accent,
    this.active = true,
    this.onPulse,
    this.hint = '',
  });

  final Color accent;
  final bool active;

  /// Fires on each tap (for haptics).
  final VoidCallback? onPulse;

  /// Faint prompt shown while the field is untouched.
  final String hint;

  @override
  State<MorseDash> createState() => _MorseDashState();
}

class _MorseDashState extends State<MorseDash>
    with SingleTickerProviderStateMixin {
  static const double _rippleLifetime = 1.6; // seconds

  final ValueNotifier<double> _clock = ValueNotifier(0);
  final List<double> _ripples = []; // birth times
  final List<bool> _symbols = []; // true = dash, false = dot
  late final Ticker _ticker;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _clock.value = elapsed.inMicroseconds / 1e6;
      // Drop ripples past their lifetime so the list stays bounded.
      _ripples.removeWhere((b) => _clock.value - b > _rippleLifetime);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _syncMotion();
  }

  @override
  void didUpdateWidget(MorseDash old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _syncMotion();
  }

  void _syncMotion() {
    if (widget.active && !_reduceMotion) {
      if (!_ticker.isActive) _ticker.start();
    } else {
      _ticker.stop();
    }
  }

  void _tap() {
    setState(() {
      _symbols.add(_symbols.length.isOdd);
      if (_symbols.length > 9) _symbols.removeAt(0);
    });
    _ripples.add(_clock.value);
    if (_ripples.length > 12) _ripples.removeAt(0);
    widget.onPulse?.call();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            _tap();
          },
          child: SizedBox(
            height: 130,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _clock,
                      builder: (context, clock, _) {
                        return CustomPaint(
                          painter: _MorsePainter(
                            clock: clock,
                            ripples: _ripples,
                            accent: accent,
                            lifetime: _rippleLifetime,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (_symbols.isEmpty)
                  Text(
                    widget.hint,
                    style: TextStyle(color: context.textTertiary, fontSize: 13),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),
        // Emitted sequence of dots and dashes.
        SizedBox(
          height: 10,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final dash in _symbols)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing3,
                  ),
                  child: Container(
                    width: dash ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(AppTheme.radius3),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MorsePainter extends CustomPainter {
  _MorsePainter({
    required this.clock,
    required this.ripples,
    required this.accent,
    required this.lifetime,
  });

  final double clock;
  final List<double> ripples;
  final Color accent;
  final double lifetime;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.shortestSide * 0.7;

    // A few node dots the ripples wash over.
    final nodes = <Offset>[
      Offset(size.width * 0.2, size.height * 0.35),
      Offset(size.width * 0.8, size.height * 0.4),
      Offset(size.width * 0.35, size.height * 0.75),
      Offset(size.width * 0.7, size.height * 0.7),
    ];

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final birth in ripples) {
      final age = clock - birth;
      if (age < 0 || age > lifetime) continue;
      final progress = age / lifetime;
      ringPaint.color = accent.withValues(alpha: (1 - progress) * 0.4);
      canvas.drawCircle(centre, maxRadius * progress, ringPaint);
    }

    // Nodes brighten when a ripple front is near them.
    for (final node in nodes) {
      var brightness = 0.18;
      final dist = (node - centre).distance;
      for (final birth in ripples) {
        final age = clock - birth;
        if (age < 0 || age > lifetime) continue;
        final front = maxRadius * (age / lifetime);
        if ((front - dist).abs() < 14) brightness = 0.8;
      }
      canvas.drawCircle(
        node,
        3.2,
        Paint()..color = accent.withValues(alpha: brightness),
      );
    }

    canvas.drawCircle(
      centre,
      4,
      Paint()..color = accent.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_MorsePainter old) => true;
}
