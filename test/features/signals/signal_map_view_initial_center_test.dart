// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Belt-and-braces regression for `SignalMapView`.
//
// `signal_card.dart` is the primary fix for the production NaN-LatLng
// crash that tripped `TileRangeCalculator._calculatePixelBounds`.
// `SignalMapView` is the receiving boundary: even if some other
// caller in the future passes a non-finite `initialCenter`, the
// widget must not let it reach `FlutterMap.options.initialCenter`.
//
// The `_center` getter already filters via `isFiniteLatLng`. This
// test pins that contract: passing `LatLng(NaN, NaN)` as
// initialCenter with no signals renders the "no location" empty
// state instead of throwing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/theme.dart';
import 'package:socialmesh/features/signals/widgets/signal_map_view.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/storage/storage_service.dart';

Future<Widget> _wrap(Widget child) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final settings = SettingsService();
  await settings.init();
  return ProviderScope(
    overrides: [
      settingsServiceProvider.overrideWith(
        (ref) => Future<SettingsService>.value(settings),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme(AccentColors.magenta),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('SignalMapView with non-finite initialCenter and no signals '
      'renders the empty placeholder without throwing', (tester) async {
    await tester.pumpWidget(
      await _wrap(
        SignalMapView(
          signals: const [],
          onSignalTap: (_) {},
          initialCenter: LatLng(double.nan, double.nan),
        ),
      ),
    );

    // Settle the post-frame microtask that loads map style.
    await tester.pump();

    // The build path must not throw — verified implicitly by reaching
    // this line. The visible UI should be the "no location" empty
    // state, not a FlutterMap.
    expect(find.byIcon(Icons.location_off), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'SignalMapView with infinite-coordinate initialCenter and no signals '
    'falls back to the empty placeholder without throwing',
    (tester) async {
      await tester.pumpWidget(
        await _wrap(
          SignalMapView(
            signals: const [],
            onSignalTap: (_) {},
            initialCenter: LatLng(double.infinity, 0),
          ),
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.location_off), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
