// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D48-A1: auto-route settings section rendering pins.
//
// We stub `meshCoreAutoRouteSettingsProvider` so the section can be
// driven into specific states (enabled / disabled / mid-range
// values) without exercising SharedPreferences. This file pins:
//   - The section header renders with the canonical ARB title.
//   - The master toggle + 4 slider tiles render and are reachable
//     by their ValueKeys.
//   - The toggle reflects `settings.enabled`.
//   - Tapping the toggle drives `setEnabled` on the notifier.
//   - Moving a slider drives the matching setter.
//   - When the master toggle is OFF, the 4 slider tiles are wrapped
//     by an `IgnorePointer` (the `_maybeDisabled` greyed state).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/widgets/animations.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_settings_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/models/meshcore_auto_route_settings.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';

final _l10n = AppLocalizationsEn();

/// Stub notifier that overrides `build()` to return a fixed state
/// and records setter calls. The microtask hydration in the real
/// `build()` is bypassed so SharedPreferences never touches the
/// stubbed state.
class _StubAutoRouteNotifier extends MeshCoreAutoRouteSettingsNotifier {
  _StubAutoRouteNotifier(this._initial);
  final MeshCoreAutoRouteSettings _initial;

  bool? lastSetEnabled;
  double? lastSetMaxWeight;
  double? lastSetInitialWeight;
  double? lastSetSuccessIncrement;
  double? lastSetFailureDecrement;

  @override
  MeshCoreAutoRouteSettings build() => _initial;

  @override
  Future<void> setEnabled(bool value) async {
    lastSetEnabled = value;
    state = state.copyWith(enabled: value);
  }

  @override
  Future<void> setMaxRouteWeight(double value) async {
    lastSetMaxWeight = MeshCoreAutoRouteSettings.clampWeight(value);
    state = state.copyWith(maxRouteWeight: lastSetMaxWeight!);
  }

  @override
  Future<void> setInitialRouteWeight(double value) async {
    lastSetInitialWeight = MeshCoreAutoRouteSettings.clampWeight(value);
    state = state.copyWith(initialRouteWeight: lastSetInitialWeight!);
  }

  @override
  Future<void> setRouteWeightSuccessIncrement(double value) async {
    lastSetSuccessIncrement = MeshCoreAutoRouteSettings.clampIncrement(value);
    state = state.copyWith(
      routeWeightSuccessIncrement: lastSetSuccessIncrement!,
    );
  }

  @override
  Future<void> setRouteWeightFailureDecrement(double value) async {
    lastSetFailureDecrement = MeshCoreAutoRouteSettings.clampIncrement(value);
    state = state.copyWith(
      routeWeightFailureDecrement: lastSetFailureDecrement!,
    );
  }
}

Widget _wrap({
  required _StubAutoRouteNotifier Function() factory,
  bool connected = true,
}) {
  return ProviderScope(
    overrides: [
      linkStatusProvider.overrideWithValue(
        connected
            ? const LinkStatus(
                protocol: LinkProtocol.meshcore,
                status: LinkConnectionStatus.connected,
                deviceName: 'TestDevice',
              )
            : LinkStatus.disconnected,
      ),
      meshCoreAutoRouteSettingsProvider.overrideWith(factory),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: const MeshCoreSettingsScreen(),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'section header + all 5 control rows render with canonical keys',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          factory: () => _StubAutoRouteNotifier(
            const MeshCoreAutoRouteSettings.defaults().copyWith(enabled: true),
          ),
        ),
      );
      await _settle(tester);

      expect(find.text(_l10n.meshcoreAutoRouteSectionTitle), findsOneWidget);
      expect(find.text(_l10n.meshcoreAutoRouteEnabled), findsOneWidget);
      expect(find.text(_l10n.meshcoreAutoRouteMaxWeight), findsOneWidget);
      expect(find.text(_l10n.meshcoreAutoRouteInitialWeight), findsOneWidget);
      expect(
        find.text(_l10n.meshcoreAutoRouteSuccessIncrement),
        findsOneWidget,
      );
      expect(
        find.text(_l10n.meshcoreAutoRouteFailureDecrement),
        findsOneWidget,
      );

      expect(
        find.byKey(const ValueKey('meshcore-auto-route-enabled')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('meshcore-auto-route-max-weight')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('meshcore-auto-route-initial-weight')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('meshcore-auto-route-success-increment')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('meshcore-auto-route-failure-decrement')),
        findsOneWidget,
      );
    },
  );

  testWidgets('master toggle reflects settings.enabled', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(
        factory: () => _StubAutoRouteNotifier(
          const MeshCoreAutoRouteSettings.defaults().copyWith(enabled: true),
        ),
      ),
    );
    await _settle(tester);

    final enabledTile = find.byKey(
      const ValueKey('meshcore-auto-route-enabled'),
    );
    final toggle = find.descendant(
      of: enabledTile,
      matching: find.byType(ThemedSwitch),
    );
    expect(toggle, findsOneWidget);
    expect(tester.widget<ThemedSwitch>(toggle).value, isTrue);
  });

  testWidgets('tapping the master toggle drives setEnabled', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    late _StubAutoRouteNotifier stub;
    await tester.pumpWidget(
      _wrap(
        factory: () {
          stub = _StubAutoRouteNotifier(
            const MeshCoreAutoRouteSettings.defaults(),
          );
          return stub;
        },
      ),
    );
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('meshcore-auto-route-enabled')));
    await _settle(tester);

    expect(stub.lastSetEnabled, isTrue);
  });

  testWidgets(
    'when enabled is OFF dragging a slider does not fire its setter',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late _StubAutoRouteNotifier stub;
      await tester.pumpWidget(
        _wrap(
          factory: () {
            stub = _StubAutoRouteNotifier(
              const MeshCoreAutoRouteSettings.defaults(),
            );
            return stub;
          },
        ),
      );
      await _settle(tester);

      // The slider tiles are wrapped by an IgnorePointer (from
      // `_maybeDisabled`) when the master toggle is off, so a drag
      // should be a no-op.
      final slider = find.descendant(
        of: find.byKey(const ValueKey('meshcore-auto-route-max-weight')),
        matching: find.byType(Slider),
      );
      await tester.drag(slider, const Offset(500, 0));
      await _settle(tester);

      expect(stub.lastSetMaxWeight, isNull);
    },
  );

  testWidgets('slider value labels render in the canonical format', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(
        factory: () => _StubAutoRouteNotifier(
          const MeshCoreAutoRouteSettings(
            enabled: true,
            maxRouteWeight: 7.5,
            initialRouteWeight: 1.0,
            routeWeightSuccessIncrement: 0.75,
            routeWeightFailureDecrement: 0.20,
          ),
        ),
      ),
    );
    await _settle(tester);

    // Weights format with 1 decimal; increments with 2 decimals.
    expect(
      find.text(_l10n.meshcoreAutoRouteSliderValue('7.5')),
      findsOneWidget,
    );
    expect(
      find.text(_l10n.meshcoreAutoRouteSliderValue('1.0')),
      findsOneWidget,
    );
    expect(
      find.text(_l10n.meshcoreAutoRouteSliderValue('0.75')),
      findsOneWidget,
    );
    expect(
      find.text(_l10n.meshcoreAutoRouteSliderValue('0.20')),
      findsOneWidget,
    );
  });

  testWidgets('moving the max-weight slider drives setMaxRouteWeight', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    late _StubAutoRouteNotifier stub;
    await tester.pumpWidget(
      _wrap(
        factory: () {
          stub = _StubAutoRouteNotifier(
            const MeshCoreAutoRouteSettings.defaults().copyWith(enabled: true),
          );
          return stub;
        },
      ),
    );
    await _settle(tester);

    // Drag the max-weight slider far right; the exact target value
    // depends on hit geometry, but with `divisions: 20` it should
    // land at one of the discrete steps != the default 5.0.
    final slider = find.descendant(
      of: find.byKey(const ValueKey('meshcore-auto-route-max-weight')),
      matching: find.byType(Slider),
    );
    await tester.drag(slider, const Offset(500, 0));
    await _settle(tester);

    expect(stub.lastSetMaxWeight, isNotNull);
    expect(stub.lastSetMaxWeight, greaterThan(5.0));
  });
}
