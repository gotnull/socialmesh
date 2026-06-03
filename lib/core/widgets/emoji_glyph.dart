// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/widgets.dart';

import '../../utils/text_sanitizer.dart';

// A single emoji codepoint centred inside a circular badge (waypoint marker,
// icon tile). The line box is collapsed tight to the glyph and a small
// correction offsets the emoji baseline + side bearing so the ink sits
// dead-centre. The parent supplies the circle + centre alignment.
//
// Correction fractions are of the glyph size and were dialled in by eye on the
// iOS simulator (Apple Color Emoji): nudge right to cancel the glyph's left
// bias, down a touch to cancel the baseline lift.
class EmojiGlyph extends StatelessWidget {
  final int codePoint;
  final double size;

  const EmojiGlyph({super.key, required this.codePoint, required this.size});

  static const double _verticalCorrection = 0.02;
  static const double _horizontalCorrection = -0.07;

  @override
  Widget build(BuildContext context) {
    // Defensive last line of defence: an untrusted code point (e.g. a mesh
    // waypoint icon) that is a surrogate half or out of the Unicode range
    // would form malformed UTF-16 and crash the native paragraph builder
    // fatally during layout. Render nothing rather than crash; callers gate
    // on a valid scalar to show their own fallback (a pin, etc.).
    if (!isValidUnicodeScalar(codePoint)) return const SizedBox.shrink();

    return Transform.translate(
      offset: Offset(
        -size * _horizontalCorrection,
        -size * _verticalCorrection,
      ),
      child: Text(
        String.fromCharCodes([codePoint]),
        textAlign: TextAlign.center,
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
          leadingDistribution: TextLeadingDistribution.even,
        ),
        style: TextStyle(fontSize: size, height: 1.0),
      ),
    );
  }
}
