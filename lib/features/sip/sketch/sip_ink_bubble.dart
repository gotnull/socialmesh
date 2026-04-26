// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Inline message bubble that renders a SIP Ink sketch.
///
/// Decodes the stored binary payload on every build and falls back to
/// a localized "Unsupported sketch" label if decoding fails — never
/// crashes regardless of input.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../services/protocol/sip/sip_ink_constants.dart';
import '../../../services/protocol/sip/sip_ink_decoder.dart';
import 'sip_ink_painter.dart';

/// Renders a single SIP Ink message inline in the chat thread.
class SipInkBubble extends StatelessWidget {
  /// The encoded SIP Ink v1 payload as it travels on the wire and as
  /// it's stored on the [SipDmHistoryEntry]. Decoded on every build.
  final Uint8List payload;

  /// Whether this bubble is for an outbound (locally sent) message.
  /// Only affects color tint to match the existing bubble palette.
  final bool isOutbound;

  /// Pixel side length of the rendered bubble. Wire-level canvas
  /// coordinates are scaled to this size.
  final double size;

  const SipInkBubble({
    super.key,
    required this.payload,
    required this.isOutbound,
    this.size = 160,
  });

  @override
  Widget build(BuildContext context) {
    final result = SipInkDecoder.decode(payload);
    if (!result.isOk) {
      return _Fallback(size: size, isOutbound: isOutbound);
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isOutbound
            ? context.accentColor.withValues(alpha: 0.10)
            : context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border.withValues(alpha: 0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: CustomPaint(
          painter: SipInkPainter(
            sketch: result.sketch,
            canvasSize: result.sketch?.canvasSize ?? SipInkConstants.canvas64,
            color: isOutbound ? context.accentColor : context.textPrimary,
          ),
          size: Size(size, size),
        ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  final double size;
  final bool isOutbound;
  const _Fallback({required this.size, required this.isOutbound});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_outlined,
              color: context.textTertiary,
              size: 28,
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              context.l10n.sipInkUnsupportedSketch,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: context.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
