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

  group('detectCoordinates', () {
    test('finds a high-precision SOS coordinate pair', () {
      final matches = detectCoordinates(
        'Location: 52.51208018193974, 13.459232576466599',
      );
      expect(matches, hasLength(1));
      expect(matches.first.latitude, closeTo(52.51208, 0.00001));
      expect(matches.first.longitude, closeTo(13.45923, 0.00001));
    });

    test('reports start and end indices that slice back to the pair', () {
      const input = 'here 52.51208, 13.45923 ok';
      final match = detectCoordinates(input).first;
      expect(input.substring(match.start, match.end), '52.51208, 13.45923');
    });

    test('handles a negative longitude', () {
      final matches = detectCoordinates('37.77493, -122.41942');
      expect(matches, hasLength(1));
      expect(matches.first.longitude, closeTo(-122.41942, 0.00001));
    });

    test('tolerates no space after the comma', () {
      expect(detectCoordinates('52.51208,13.45923'), hasLength(1));
    });

    test('rejects low-precision casual decimal pairs', () {
      expect(detectCoordinates('rated 4.5, 3.2 stars'), isEmpty);
    });

    test('rejects out-of-range latitude', () {
      expect(detectCoordinates('99.12345, 13.45923'), isEmpty);
    });

    test('rejects out-of-range longitude', () {
      expect(detectCoordinates('52.51208, 200.45923'), isEmpty);
    });

    test('ignores plain prose with no coordinates', () {
      expect(detectCoordinates('meeting at the zoo tomorrow'), isEmpty);
    });

    test('accepts a pair where only one number is high precision', () {
      expect(detectCoordinates('52.51208018, 13.4'), hasLength(1));
    });
  });

  group('formatCoordinatePair', () {
    test('rounds to five decimal places', () {
      expect(
        formatCoordinatePair(52.51208018193974, 13.459232576466599),
        '52.51208, 13.45923',
      );
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

    testWidgets('renders a tappable span for a GPS coordinate', (tester) async {
      await tester.pumpWidget(
        wrap(const LinkifiedText(text: 'Location: 52.51208, 13.45923')),
      );
      final richFinder = find.byWidgetPredicate(
        (w) => w is Text && w.textSpan != null,
      );
      expect(richFinder, findsOneWidget);
      final text = tester.widget<Text>(richFinder);
      final root = text.textSpan! as TextSpan;
      final coordSpan =
          root.children!.firstWhere(
                (s) => s is TextSpan && s.text == '52.51208, 13.45923',
              )
              as TextSpan;
      expect(coordSpan.recognizer, isNotNull);
    });
  });
}
