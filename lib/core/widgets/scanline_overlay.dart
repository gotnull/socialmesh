// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pocket-space scanline backdrop — faint horizontal grain painted behind
// the NodePet hero. Matches the OG PetCreature backdrop treatment
// (Colors.white @ alpha 0.035, 6px cadence, 1px stroke) so the "pocket
// space" ambience reads the same regardless of whether the creature is
// the bespoke painter or the mesh wireframe.
//
// Static — no animation, no shader. Safe to pin anywhere behind a hero.

import 'package:flutter/material.dart';

class ScanlineOverlay extends StatelessWidget {
  const ScanlineOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _ScanlineBackdropPainter(),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _ScanlineBackdropPainter extends CustomPainter {
  const _ScanlineBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1.0;
    const step = 6.0;
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanlineBackdropPainter old) => false;
}
