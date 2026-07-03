// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/widgets/node_avatar.dart';

Widget _wrap(Widget child, {TextScaler? textScaler}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: textScaler ?? TextScaler.noScaling),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('NodeAvatar', () {
    testWidgets('renders the full 4-character short name', (tester) async {
      await tester.pumpWidget(
        _wrap(const NodeAvatar(text: 'MGrW', color: Colors.purple, size: 56)),
      );

      expect(find.text('MGrW'), findsOneWidget);
    });

    testWidgets('glyph stays inside the circle at any text scale', (
      tester,
    ) async {
      // Wide-glyph name (W is the widest Latin capital) plus an aggressive
      // accessibility scale factor: the failure mode is the trailing
      // character clipping off the circle's right edge.
      for (final scale in [1.0, 1.15, 1.5, 2.0]) {
        await tester.pumpWidget(
          _wrap(
            const NodeAvatar(text: 'MGrW', color: Colors.purple, size: 56),
            textScaler: TextScaler.linear(scale),
          ),
        );

        final avatarRect = tester.getRect(find.byType(NodeAvatar));
        final textRect = tester.getRect(find.text('MGrW'));

        expect(
          textRect.width,
          lessThanOrEqualTo(avatarRect.width),
          reason: 'text overflows the avatar at scale $scale',
        );
        expect(
          textRect.height,
          lessThanOrEqualTo(avatarRect.height),
          reason: 'text overflows the avatar at scale $scale',
        );
      }
    });

    testWidgets('glyph size is independent of the ambient text scaler', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const NodeAvatar(text: 'MGrW', color: Colors.purple, size: 56)),
      );
      final unscaled = tester.getRect(find.text('MGrW'));

      await tester.pumpWidget(
        _wrap(
          const NodeAvatar(text: 'MGrW', color: Colors.purple, size: 56),
          textScaler: const TextScaler.linear(2.0),
        ),
      );
      final scaled = tester.getRect(find.text('MGrW'));

      expect(scaled.width, moreOrLessEquals(unscaled.width, epsilon: 0.01));
      expect(scaled.height, moreOrLessEquals(unscaled.height, epsilon: 0.01));
    });

    testWidgets('long hex ids shorten to 5 lowercased characters', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const NodeAvatar(text: 'ABCDEF12', color: Colors.purple, size: 56),
        ),
      );

      expect(find.text('abcde'), findsOneWidget);
    });
  });
}
