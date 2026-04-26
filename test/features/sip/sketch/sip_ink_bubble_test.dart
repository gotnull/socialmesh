// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/sip/sketch/sip_ink_bubble.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/services/protocol/sip/sip_ink_constants.dart';
import 'package:socialmesh/services/protocol/sip/sip_ink_encoder.dart';
import 'package:socialmesh/services/protocol/sip/sip_ink_payload.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('SipInkBubble renders a valid sketch payload without errors', (
    tester,
  ) async {
    final sketch = SipInkSketch(
      canvasSize: SipInkConstants.canvas64,
      strokes: [
        SipInkStroke(
          width: 2,
          points: const [
            SipInkPoint(10, 10),
            SipInkPoint(13, 12),
            SipInkPoint(15, 15),
          ],
        ),
      ],
    );
    final bytes = SipInkEncoder.encode(sketch).bytes!;

    await tester.pumpWidget(
      _wrap(SipInkBubble(payload: bytes, isOutbound: true)),
    );
    await tester.pump();

    expect(find.byType(SipInkBubble), findsOneWidget);
    // No fallback shown when decoding succeeds.
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
  });

  testWidgets(
    'SipInkBubble shows "Unsupported sketch" fallback for malformed payload',
    (tester) async {
      // Random bytes that fail to decode as a v1 sketch.
      final junk = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);

      await tester.pumpWidget(
        _wrap(SipInkBubble(payload: junk, isOutbound: false)),
      );
      await tester.pump();

      expect(find.byType(SipInkBubble), findsOneWidget);
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      // Localised string from app_en.arb -> sipInkUnsupportedSketch.
      expect(find.text('Unsupported sketch'), findsOneWidget);
    },
  );

  testWidgets('SipInkBubble does not throw on truncated header', (
    tester,
  ) async {
    final tiny = Uint8List.fromList([0x11, 0x00]);

    await tester.pumpWidget(
      _wrap(SipInkBubble(payload: tiny, isOutbound: false)),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Unsupported sketch'), findsOneWidget);
  });
}
