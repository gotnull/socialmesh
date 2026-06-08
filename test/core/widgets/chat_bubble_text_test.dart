// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/widgets/chat_bubble_text.dart';

void main() {
  group('chatBubbleBodyStyle', () {
    // The user's accessibility text-size preference is applied app-wide via
    // MediaQuery.textScaler (see main.dart). This helper therefore returns
    // the unscaled baseline size; multiplying here would double-scale.
    test('returns the unscaled base font size', () {
      final style = chatBubbleBodyStyle(baseFontSize: 14);
      expect(style.fontSize, 14);
    });

    test('forwards color and fontWeight unchanged', () {
      final style = chatBubbleBodyStyle(
        baseFontSize: 15,
        color: const Color(0xFF112233),
        fontWeight: FontWeight.w600,
      );

      expect(style.fontSize, 15);
      expect(style.color, const Color(0xFF112233));
      expect(style.fontWeight, FontWeight.w600);
    });

    test('incoming and outgoing with same base resolve to the same size', () {
      final outgoing = chatBubbleBodyStyle(
        baseFontSize: 14,
        color: Colors.white,
      );
      final incoming = chatBubbleBodyStyle(
        baseFontSize: 14,
        color: const Color(0xFF111111),
      );

      expect(outgoing.fontSize, incoming.fontSize);
      expect(outgoing.color, Colors.white);
      expect(incoming.color, const Color(0xFF111111));
    });
  });
}
