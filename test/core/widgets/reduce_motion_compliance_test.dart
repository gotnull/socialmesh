// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/widgets/animated_tagline.dart';
import 'package:socialmesh/core/widgets/animations.dart';
import 'package:socialmesh/features/onboarding/widgets/advisor_speech_bubble.dart';

void main() {
  Widget wrapWithMediaQuery(Widget child, {required bool disableAnimations}) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Theme(
          data: ThemeData(),
          child: Material(child: Center(child: child)),
        ),
      ),
    );
  }

  group('Reduce Motion shared widgets', () {
    testWidgets('TypewriterText renders full text immediately', (tester) async {
      await tester.pumpWidget(
        wrapWithMediaQuery(
          const TypewriterText(text: 'Reduce Motion'),
          disableAnimations: true,
        ),
      );

      expect(find.text('Reduce Motion'), findsOneWidget);
    });

    testWidgets('AnimatedTagline stays on the first tagline', (tester) async {
      await tester.pumpWidget(
        wrapWithMediaQuery(
          const AnimatedTagline(taglines: ['First tagline', 'Second tagline']),
          disableAnimations: true,
        ),
      );

      expect(find.text('First tagline'), findsOneWidget);

      await tester.pump(
        AnimatedTagline.displayDuration +
            AnimatedTagline.animationDuration +
            const Duration(seconds: 1),
      );

      expect(find.text('First tagline'), findsOneWidget);
      expect(find.text('Second tagline'), findsNothing);
    });

    testWidgets('BouncyTap removes press-scale animation', (tester) async {
      await tester.pumpWidget(
        wrapWithMediaQuery(
          BouncyTap(onTap: () {}, child: const Text('Tap target')),
          disableAnimations: true,
        ),
      );

      expect(find.text('Tap target'), findsOneWidget);
      expect(find.byType(ScaleTransition), findsNothing);
    });

    testWidgets('AdvisorSpeechBubble shows full text immediately', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithMediaQuery(
          const AdvisorSpeechBubble(text: 'Motionless copy'),
          disableAnimations: true,
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains('Motionless copy'),
        ),
        findsOneWidget,
      );
    });
  });
}
