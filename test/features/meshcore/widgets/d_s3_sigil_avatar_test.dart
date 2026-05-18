// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-S3 MeshCoreSigilAvatar regression pins.
//
// The MeshCore sigil avatar reuses Meshtastic's `SigilGenerator` by
// feeding the first 4 bytes of the MeshCore pubkey through
// `generateFromPersonaId`. This test anchors:
//   - the determinism contract (same pubkey -> same sigil),
//   - the keying contract (first 4 bytes drive sigil identity; bytes
//     5+ do not affect the visual),
//   - the assert contract (< 4 byte pubkey is rejected at construction),
//   - the tap contract (no GestureDetector when onTap is null; haptic +
//     callback fire when present).

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/meshcore/widgets/meshcore_sigil_avatar.dart';
import 'package:socialmesh/features/nodedex/services/sigil_generator.dart';

void main() {
  group('D-S3 MeshCoreSigilAvatar', () {
    test('asserts when pubkey is shorter than 4 bytes', () {
      expect(
        () => MeshCoreSigilAvatar(pubKey: Uint8List.fromList([0x01, 0x02])),
        throwsA(isA<AssertionError>()),
      );
    });

    test('first 4 bytes seed the sigil; bytes 5+ do not change it', () {
      // Two pubkeys that share the leading 4 bytes but differ after.
      final keyA = Uint8List.fromList([
        0x79,
        0x42,
        0x6d,
        0x8d,
        0xbb,
        0x8f,
        0xd9,
        0x37,
      ]);
      final keyB = Uint8List.fromList([
        0x79,
        0x42,
        0x6d,
        0x8d,
        0x00,
        0x00,
        0x00,
        0x00,
      ]);
      final sigilA = SigilGenerator.generateFromPersonaId(keyA);
      final sigilB = SigilGenerator.generateFromPersonaId(keyB);
      expect(
        sigilA.primaryColor,
        equals(sigilB.primaryColor),
        reason:
            'sigils derived from pubkeys sharing the leading 4 bytes must '
            'match; trailing bytes do not affect sigil identity',
      );
    });

    test('different leading 4 bytes produce different sigils', () {
      final keyA = Uint8List.fromList([0x79, 0x42, 0x6d, 0x8d]);
      final keyB = Uint8List.fromList([0x12, 0x34, 0x56, 0x78]);
      final sigilA = SigilGenerator.generateFromPersonaId(keyA);
      final sigilB = SigilGenerator.generateFromPersonaId(keyB);
      // Compare a structural attribute so we don't hit a colour
      // collision by luck. Vertex count is one of the parameters the
      // mix-hash distributes across the parameter space.
      expect(
        sigilA.vertices != sigilB.vertices ||
            sigilA.primaryColor != sigilB.primaryColor,
        isTrue,
        reason:
            'two different pubkeys should not collapse to the same sigil; '
            'if both vertex count AND primary colour collide this anchors '
            'a hash regression worth investigating',
      );
    });

    testWidgets('renders a non-empty Widget with size matching the parameter', (
      tester,
    ) async {
      final key = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: MeshCoreSigilAvatar(pubKey: key, size: 56)),
          ),
        ),
      );
      final finder = find.byType(MeshCoreSigilAvatar);
      expect(finder, findsOneWidget);
      final renderBox = tester.renderObject<RenderBox>(finder);
      expect(renderBox.size.width, equals(56.0));
      expect(renderBox.size.height, equals(56.0));
    });

    testWidgets('non-tappable when onTap is null (no GestureDetector)', (
      tester,
    ) async {
      final key = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: MeshCoreSigilAvatar(pubKey: key)),
          ),
        ),
      );
      expect(find.byType(GestureDetector), findsNothing);
    });

    testWidgets('tap fires the provided callback', (tester) async {
      final key = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: MeshCoreSigilAvatar(pubKey: key, onTap: () => taps++),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(MeshCoreSigilAvatar));
      await tester.pump();
      expect(taps, equals(1));
    });
  });
}
