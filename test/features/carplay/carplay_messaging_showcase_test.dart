// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/theme.dart';
import 'package:socialmesh/core/whats_new/whats_new_registry.dart';
import 'package:socialmesh/features/carplay/carplay_messaging_showcase_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

// Wraps a child so animations are disabled (the showcase loops an ambient
// controller; without this pumpAndSettle would never converge) and so
// localizations + Riverpod + theme are available.
Widget _app({required Widget home}) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.darkTheme(AccentColors.magenta),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: home,
        ),
      ),
    ),
  );
}

// The showcase is a long lazy CustomScrollView; a tall window forces every
// sliver (cards, CTA) to build so finders can see them without scrolling.
void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('WhatsNewRegistry CarPlay entry', () {
    final carplay = WhatsNewRegistry.allPayloads
        .where((p) => p.version == '1.45.0')
        .toList();

    test('a v1.45.0 payload exists', () {
      expect(carplay, hasLength(1));
    });

    test('contains the CarPlay messaging item with the showcase route', () {
      final item = carplay.single.items.single;
      expect(item.id, 'carplay_messaging_intro');
      expect(item.deepLinkRoute, '/carplay');
      expect(item.title, 'CarPlay Mesh Messaging');
      expect(item.ctaLabel, 'Explore CarPlay');
      expect(item.icon, Icons.directions_car_filled_outlined);
      expect(item.iconColor, isNotNull);
    });

    test('CarPlay entry is the newest payload', () {
      expect(WhatsNewRegistry.allPayloads.last.version, '1.45.0');
    });
  });

  group('CarPlayMessagingShowcaseScreen', () {
    testWidgets('renders hero, a feature card, the reality check and the CTA', (
      tester,
    ) async {
      _tallView(tester);
      await tester.pumpWidget(
        _app(home: const CarPlayMessagingShowcaseScreen()),
      );
      await tester.pumpAndSettle();

      // Hero title + subtitle.
      expect(find.text('CarPlay Mesh Messaging'), findsOneWidget);
      expect(
        find.text('Hands-free mesh messages, designed for the road.'),
        findsOneWidget,
      );
      // A feature card.
      expect(find.text('Send short mesh messages'), findsOneWidget);
      // The browse-UI card (the real CarPlay list capability).
      expect(find.text('Glance at channels and DMs'), findsOneWidget);
      // The accuracy "what this is not" section.
      expect(find.text('Focused, not distracting'), findsOneWidget);
      // The SiriKit technical chips render verbatim.
      expect(find.text('INSendMessageIntent'), findsOneWidget);
      // CTA.
      expect(find.text('Got it'), findsOneWidget);
    });

    testWidgets('CTA dismisses the screen', (tester) async {
      _tallView(tester);
      await tester.pumpWidget(
        _app(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MediaQuery(
                        data: MediaQuery.of(
                          context,
                        ).copyWith(disableAnimations: true),
                        child: const CarPlayMessagingShowcaseScreen(),
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('CarPlay Mesh Messaging'), findsOneWidget);

      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(find.text('CarPlay Mesh Messaging'), findsNothing);
    });

    testWidgets('handles large text scale without throwing', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _app(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: true,
                textScaler: const TextScaler.linear(1.6),
              ),
              child: const CarPlayMessagingShowcaseScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No RenderFlex overflow at large text scale (the CTA may scroll out of
      // the lazily-built sliver viewport, so we only assert no layout error).
      expect(tester.takeException(), isNull);
      expect(find.text('CarPlay Mesh Messaging'), findsOneWidget);
    });
  });
}
