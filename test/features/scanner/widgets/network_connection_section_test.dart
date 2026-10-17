// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/theme.dart';
import 'package:socialmesh/features/scanner/widgets/network_connection_section.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/network_endpoint.dart';

Future<AppLocalizations> _pumpSection(
  WidgetTester tester, {
  required Locale locale,
  required double width,
  double textScale = 1.0,
  bool withEndpoint = false,
}) async {
  SharedPreferences.setMockInitialValues({
    if (withEndpoint)
      'network_endpoints_v1': NetworkEndpoint.encodeList([
        NetworkEndpoint.create(host: 'radio.example'),
      ]),
  });
  tester.view.physicalSize = Size(width * 3, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  late AppLocalizations l10n;
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.darkTheme(AccentColors.magenta),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              // Same horizontal inset the scanner gives this section.
              return const Material(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: NetworkConnectionSection(compact: true),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  // Let the endpoints notifier finish its async SharedPreferences load.
  await tester.pumpAndSettle();
  return l10n;
}

void main() {
  // The header used to be an unflexed title + Spacer + filled button,
  // which overflowed on a 360dp phone in German. Overflow raises a
  // FlutterError in the test binding, so a clean pump proves the header
  // now wraps.
  group('NetworkConnectionSection header layout', () {
    for (final locale in AppLocalizations.supportedLocales) {
      for (final width in [320.0, 360.0]) {
        for (final textScale in [1.0, 1.5]) {
          for (final withEndpoint in [false, true]) {
            testWidgets(
              'no overflow: ${locale.languageCode} ${width.toInt()}dp '
              '${textScale}x ${withEndpoint ? 'one endpoint' : 'empty'}',
              (tester) async {
                final l10n = await _pumpSection(
                  tester,
                  locale: locale,
                  width: width,
                  textScale: textScale,
                  withEndpoint: withEndpoint,
                );
                expect(tester.takeException(), isNull);
                expect(find.text(l10n.networkSavedEndpoints), findsOneWidget);
                expect(find.text(l10n.networkAddEndpoint), findsOneWidget);
              },
            );
          }
        }
      }
    }
  });

  testWidgets('the add action stays fully on screen in German at 360dp', (
    tester,
  ) async {
    final l10n = await _pumpSection(
      tester,
      locale: const Locale('de'),
      width: 360,
    );
    final button = tester.getRect(
      find.ancestor(
        of: find.text(l10n.networkAddEndpoint),
        matching: find.byType(TextButton),
      ),
    );
    expect(button.left, greaterThanOrEqualTo(0));
    expect(button.right, lessThanOrEqualTo(360));
  });

  testWidgets('the endpoint count shows beside the title', (tester) async {
    await _pumpSection(
      tester,
      locale: const Locale('en'),
      width: 360,
      withEndpoint: true,
    );
    expect(find.text('1'), findsOneWidget);
  });
}
