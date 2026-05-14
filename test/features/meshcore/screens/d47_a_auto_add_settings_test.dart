// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D47-A: auto-add settings section rendering pins.
//
// We stub `meshCoreAutoAddConfigProvider` directly so the section can
// be driven into specific states (loaded / loading / error) without
// exercising the session or transport. This file pins:
//   - All 5 toggle tiles render with the canonical ARB labels +
//     subtitles, in the expected order (chat, repeater, room,
//     sensor, overwrite-oldest).
//   - The toggle state mirrors the loaded config bits.
//   - Tapping a toggle drives `update` on the notifier with the
//     corresponding bit flipped.
//   - Error state shows the warning banner with
//     `meshcoreAutoAddLoadFailed` copy.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/widgets/animations.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_settings_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/models/meshcore_auto_add_config.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';

final _l10n = AppLocalizationsEn();

/// Stub notifier that overrides `build()` to return a fixed state
/// and records `update()` calls. `refresh` is a no-op so the lazy
/// first-load path doesn't fire during tests.
class _StubAutoAddNotifier extends MeshCoreAutoAddConfigNotifier {
  _StubAutoAddNotifier(this._initial);
  final MeshCoreAutoAddConfigState _initial;
  final List<MeshCoreAutoAddConfig> updateCalls = [];
  bool updateResult = true;

  @override
  MeshCoreAutoAddConfigState build() => _initial;

  @override
  Future<void> refresh() async {
    // No-op — the lazy first-load fires `refresh` and we don't want
    // it to mutate the stubbed state.
  }

  @override
  Future<bool> update(MeshCoreAutoAddConfig next) async {
    updateCalls.add(next);
    return updateResult;
  }
}

Widget _wrap({
  required _StubAutoAddNotifier Function() factory,
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
      meshCoreAutoAddConfigProvider.overrideWith(factory),
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

  testWidgets('all 5 auto-add toggle rows render with canonical labels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(
        factory: () => _StubAutoAddNotifier(
          const MeshCoreAutoAddConfigState(loaded: MeshCoreAutoAddConfig.off()),
        ),
      ),
    );
    await _settle(tester);

    expect(find.text(_l10n.meshcoreAutoAddSectionTitle), findsOneWidget);
    expect(find.text(_l10n.meshcoreAutoAddChat), findsOneWidget);
    expect(find.text(_l10n.meshcoreAutoAddRepeater), findsOneWidget);
    expect(find.text(_l10n.meshcoreAutoAddRoomServer), findsOneWidget);
    expect(find.text(_l10n.meshcoreAutoAddSensor), findsOneWidget);
    expect(find.text(_l10n.meshcoreAutoAddOverwriteOldest), findsOneWidget);

    // Subtitles also render.
    expect(find.text(_l10n.meshcoreAutoAddChatSubtitle), findsOneWidget);
    expect(find.text(_l10n.meshcoreAutoAddRepeaterSubtitle), findsOneWidget);

    // Each row is reachable by its ValueKey.
    expect(
      find.byKey(const ValueKey('meshcore-auto-add-chat')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meshcore-auto-add-repeater')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meshcore-auto-add-room')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meshcore-auto-add-sensor')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meshcore-auto-add-overwrite-oldest')),
      findsOneWidget,
    );
  });

  testWidgets('toggle state mirrors loaded config bits', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(
        factory: () => _StubAutoAddNotifier(
          const MeshCoreAutoAddConfigState(
            loaded: MeshCoreAutoAddConfig(
              autoAddChat: true,
              autoAddRepeater: false,
              autoAddRoomServer: true,
              autoAddSensor: false,
              overwriteOldest: true,
            ),
          ),
        ),
      ),
    );
    await _settle(tester);

    // Scope the assertion to the 5 auto-add switches by walking the
    // canonical ValueKeys; D48-A1 added a 6th `ThemedSwitch` for the
    // auto-route master toggle further down the screen.
    bool readSwitch(String keyId) {
      final s = tester.widget<ThemedSwitch>(
        find.descendant(
          of: find.byKey(ValueKey(keyId)),
          matching: find.byType(ThemedSwitch),
        ),
      );
      return s.value;
    }

    expect(
      [
        readSwitch('meshcore-auto-add-chat'),
        readSwitch('meshcore-auto-add-repeater'),
        readSwitch('meshcore-auto-add-room'),
        readSwitch('meshcore-auto-add-sensor'),
        readSwitch('meshcore-auto-add-overwrite-oldest'),
      ],
      [true, false, true, false, true],
    );
  });

  testWidgets(
    'tapping a toggle drives update with the corresponding bit flipped',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late _StubAutoAddNotifier stub;
      await tester.pumpWidget(
        _wrap(
          factory: () {
            stub = _StubAutoAddNotifier(
              const MeshCoreAutoAddConfigState(
                loaded: MeshCoreAutoAddConfig.off(),
              ),
            );
            return stub;
          },
        ),
      );
      await _settle(tester);

      // Tap the repeater row tile.
      await tester.tap(
        find.byKey(const ValueKey('meshcore-auto-add-repeater')),
      );
      await _settle(tester);

      expect(stub.updateCalls, hasLength(1));
      expect(stub.updateCalls.single.autoAddRepeater, isTrue);
      expect(stub.updateCalls.single.autoAddChat, isFalse);
    },
  );

  testWidgets(
    'load-failed state renders the warning banner with the canonical copy',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          factory: () => _StubAutoAddNotifier(
            const MeshCoreAutoAddConfigState(lastError: 'load_failed'),
          ),
        ),
      );
      await _settle(tester);

      expect(find.text(_l10n.meshcoreAutoAddLoadFailed), findsOneWidget);
    },
  );
}
