// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/node_color.dart';

void main() {
  group('nodeColorFromId', () {
    test(
      'uses the low three bytes of the node id as RGB (Meshtastic parity)',
      () {
        final color = nodeColorFromId(0x12345678);
        // Low three bytes 0x345678 -> R=0x34, G=0x56, B=0x78, fully opaque.
        expect((color.a * 255).round(), 0xFF);
        expect((color.r * 255).round(), 0x34);
        expect((color.g * 255).round(), 0x56);
        expect((color.b * 255).round(), 0x78);
      },
    );

    test('ignores bytes above the low three', () {
      // The high byte differs but the low three bytes are identical.
      expect(nodeColorFromId(0xAA112233), nodeColorFromId(0x00112233));
    });

    test('is deterministic for the same node id', () {
      expect(nodeColorFromId(0x29A9), nodeColorFromId(0x29A9));
    });

    test('all-zero low bytes map to opaque black', () {
      final color = nodeColorFromId(0xFF000000);
      expect((color.r * 255).round(), 0);
      expect((color.g * 255).round(), 0);
      expect((color.b * 255).round(), 0);
      expect((color.a * 255).round(), 0xFF);
    });
  });

  group('resolveNodeColor', () {
    test('prefers an explicit avatar color override', () {
      final color = resolveNodeColor(
        nodeNum: 0x112233,
        avatarColor: 0xFFABCDEF,
      );
      expect(color, const Color(0xFFABCDEF));
    });

    test('derives from the node id when there is no override', () {
      expect(resolveNodeColor(nodeNum: 0x112233), nodeColorFromId(0x112233));
    });
  });

  group('contrast', () {
    test('dark node colors get a white foreground', () {
      expect(
        nodeContrastColor(const Color(0xFF101010)),
        const Color(0xFFFFFFFF),
      );
      expect(isLightNodeColor(const Color(0xFF101010)), isFalse);
    });

    test('light node colors get a black foreground', () {
      expect(
        nodeContrastColor(const Color(0xFFF0F0F0)),
        const Color(0xFF000000),
      );
      expect(isLightNodeColor(const Color(0xFFF0F0F0)), isTrue);
    });
  });
}
