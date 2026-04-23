// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/widgets/linkified_text.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

void main() {
  group('detectUrls', () {
    test('finds a plain https URL', () {
      final matches = detectUrls('hello https://example.com world');
      expect(matches, hasLength(1));
      expect(matches.first.url, 'https://example.com');
    });

    test('finds a plain http URL', () {
      final matches = detectUrls('see http://example.com for details');
      expect(matches, hasLength(1));
      expect(matches.first.url, 'http://example.com');
    });

    test('finds multiple URLs in one string', () {
      final matches = detectUrls(
        'first https://a.example.com then https://b.example.com/path',
      );
      expect(matches, hasLength(2));
      expect(matches[0].url, 'https://a.example.com');
      expect(matches[1].url, 'https://b.example.com/path');
    });

    test('preserves path and query string', () {
      final matches = detectUrls(
        'open https://example.com/foo?bar=1&baz=2 please',
      );
      expect(matches.first.url, 'https://example.com/foo?bar=1&baz=2');
    });

    test('trims trailing sentence punctuation', () {
      final matches = detectUrls('Check https://example.com/foo.');
      expect(matches.first.url, 'https://example.com/foo');
    });

    test('trims trailing comma', () {
      final matches = detectUrls('See https://example.com/foo, then reply');
      expect(matches.first.url, 'https://example.com/foo');
    });

    test('trims trailing question mark and exclamation', () {
      expect(
        detectUrls('Is it https://example.com?').first.url,
        'https://example.com',
      );
      expect(
        detectUrls('Go to https://example.com!').first.url,
        'https://example.com',
      );
    });

    test('strips unmatched trailing close paren', () {
      final matches = detectUrls('(see https://example.com/foo)');
      expect(matches.first.url, 'https://example.com/foo');
    });

    test('keeps balanced parens in the URL', () {
      final matches = detectUrls(
        'https://en.wikipedia.org/wiki/Foo_(bar) is neat',
      );
      expect(matches.first.url, 'https://en.wikipedia.org/wiki/Foo_(bar)');
    });

    test('ignores plain text with no URL', () {
      expect(detectUrls('no links here, just words.'), isEmpty);
    });

    test('does not match bare www domains (scheme required)', () {
      expect(detectUrls('visit www.example.com today'), isEmpty);
    });

    test('does not match bare email addresses', () {
      expect(detectUrls('email me at dev@example.com'), isEmpty);
    });

    test('drops URLs that shrink to scheme only after trimming', () {
      expect(detectUrls('https://.'), isEmpty);
    });

    test('reports start and end indices that slice back to the URL', () {
      const input = 'prefix https://example.com/foo. suffix';
      final match = detectUrls(input).first;
      expect(input.substring(match.start, match.end), match.url);
    });
  });

  group('LinkifiedText widget', () {
    Widget wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

    testWidgets('renders plain Text when no URL is present', (tester) async {
      await tester.pumpWidget(wrap(const LinkifiedText(text: 'just text')));
      expect(find.text('just text'), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('renders a Text.rich when a URL is present', (tester) async {
      await tester.pumpWidget(
        wrap(const LinkifiedText(text: 'open https://example.com now')),
      );
      final richFinder = find.byWidgetPredicate(
        (w) => w is Text && w.textSpan != null,
      );
      expect(richFinder, findsOneWidget);
      final text = tester.widget<Text>(richFinder);
      final root = text.textSpan! as TextSpan;
      expect(root.children, isNotNull);
      expect(root.children!.length, 3);
      expect((root.children![1] as TextSpan).text, 'https://example.com');
      expect((root.children![1] as TextSpan).recognizer, isNotNull);
    });
  });
}
