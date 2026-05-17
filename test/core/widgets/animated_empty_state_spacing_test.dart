// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins the boundary-whitespace contract for AnimatedEmptyState title
// rendering. The widget composes three runs (plain prefix + gradient
// keyword + plain suffix) into a RichText with adjacent spans; if a
// caller or locale string omits the trailing/leading space, the spans
// render concatenated ("Nodiscoverednodes yet"). The widget normalises
// at the boundary so every caller is safe.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/widgets/animated_empty_state.dart';

void main() {
  group('AnimatedEmptyState title boundary whitespace', () {
    testWidgets('inserts a space when prefix lacks a trailing space', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedEmptyState(
              config: const AnimatedEmptyStateConfig(
                icons: [Icons.radar_rounded],
                taglines: ['tag'],
                titlePrefix: 'No',
                titleKeyword: 'discovered',
                titleSuffix: ' nodes yet',
              ),
            ),
          ),
        ),
      );

      final richText = tester.widget<RichText>(
        find.byWidgetPredicate((w) {
          if (w is! RichText) return false;
          final span = w.text;
          if (span is! TextSpan) return false;
          final children = span.children;
          if (children == null) return false;
          return children.any(
            (c) => c is TextSpan && c.text != null && c.text!.contains('No'),
          );
        }),
      );
      final spans = (richText.text as TextSpan).children!;
      final prefixSpan = spans.first as TextSpan;
      expect(
        prefixSpan.text,
        equals('No '),
        reason:
            'Prefix "No" must render as "No " so the gradient keyword '
            'is visually separated from the plain prefix.',
      );
    });

    testWidgets('inserts a space when suffix lacks a leading space', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedEmptyState(
              config: const AnimatedEmptyStateConfig(
                icons: [Icons.radar_rounded],
                taglines: ['tag'],
                titlePrefix: 'No ',
                titleKeyword: 'discovered',
                titleSuffix: 'nodes yet',
              ),
            ),
          ),
        ),
      );

      final richText = tester.widget<RichText>(
        find.byWidgetPredicate((w) {
          if (w is! RichText) return false;
          final span = w.text;
          if (span is! TextSpan) return false;
          final children = span.children;
          if (children == null) return false;
          return children.any(
            (c) => c is TextSpan && c.text != null && c.text!.contains('nodes'),
          );
        }),
      );
      final spans = (richText.text as TextSpan).children!;
      final suffixSpan = spans.last as TextSpan;
      expect(
        suffixSpan.text,
        equals(' nodes yet'),
        reason:
            'Suffix "nodes yet" must render as " nodes yet" so the '
            'gradient keyword is visually separated from the plain '
            'suffix.',
      );
    });

    testWidgets('does NOT double-space when prefix already ends with space', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedEmptyState(
              config: const AnimatedEmptyStateConfig(
                icons: [Icons.radar_rounded],
                taglines: ['tag'],
                titlePrefix: 'No ',
                titleKeyword: 'discovered',
                titleSuffix: ' nodes yet',
              ),
            ),
          ),
        ),
      );

      final richText = tester.widget<RichText>(
        find.byWidgetPredicate((w) {
          if (w is! RichText) return false;
          final span = w.text;
          if (span is! TextSpan) return false;
          final children = span.children;
          if (children == null) return false;
          return children.any(
            (c) => c is TextSpan && c.text != null && c.text!.contains('No'),
          );
        }),
      );
      final spans = (richText.text as TextSpan).children!;
      final prefixSpan = spans.first as TextSpan;
      final suffixSpan = spans.last as TextSpan;
      expect(prefixSpan.text, equals('No '));
      expect(suffixSpan.text, equals(' nodes yet'));
    });

    testWidgets('empty prefix and suffix are left untouched', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedEmptyState(
              config: const AnimatedEmptyStateConfig(
                icons: [Icons.radar_rounded],
                taglines: ['tag'],
                titlePrefix: '',
                titleKeyword: 'Empty',
                titleSuffix: '',
              ),
            ),
          ),
        ),
      );

      // Only the keyword should render; no leading/trailing TextSpan.
      final richText = tester.widget<RichText>(
        find.byWidgetPredicate((w) {
          if (w is! RichText) return false;
          final span = w.text;
          if (span is! TextSpan) return false;
          final children = span.children;
          if (children == null) return false;
          return children.any((c) => c is WidgetSpan);
        }),
      );
      final spans = (richText.text as TextSpan).children!;
      // Only the WidgetSpan (the gradient keyword) should be present.
      final textSpans = spans.whereType<TextSpan>().toList();
      expect(
        textSpans,
        isEmpty,
        reason:
            'Empty prefix/suffix should produce no plain TextSpans, '
            'just the gradient keyword WidgetSpan.',
      );
    });
  });
}
