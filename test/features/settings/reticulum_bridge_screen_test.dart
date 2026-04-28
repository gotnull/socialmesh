// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/settings/reticulum_bridge_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/providers/reticulum_bridge_provider.dart';
import 'package:socialmesh/services/protocol/reticulum/reticulum_frame.dart';
import 'package:socialmesh/services/reticulum/reticulum_bridge_service.dart';

final _l10n = AppLocalizationsEn();

class _NoopBridgeSocket implements BridgeSocket {
  final Completer<void> _done = Completer<void>();
  @override
  Future<void> write(List<int> bytes) async {}
  @override
  Future<void> close() async {
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> get done => _done.future;
}

Future<BridgeSocket> _noopFactory(String host, int port) async {
  return _NoopBridgeSocket();
}

Widget _wrap({Stream<ReticulumFrame>? frames}) {
  final ctrl = frames == null
      ? StreamController<ReticulumFrame>.broadcast()
      : null;
  addTearDown(() => ctrl?.close());
  return ProviderScope(
    overrides: [
      reticulumBridgeSocketFactoryProvider.overrideWithValue(_noopFactory),
      reticulumBridgeFrameSourceProvider.overrideWithValue(
        frames ?? ctrl!.stream,
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: const ReticulumBridgeScreen(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('renders title, sections, and bottom action', (tester) async {
    // Tall viewport so the lazy sliver list builds every section.
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap());
    // Pump a couple of frames so the AsyncNotifier resolves.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(_l10n.reticulumBridgeTitle), findsWidgets);
    expect(find.text(_l10n.reticulumBridgeSectionConnection), findsOneWidget);
    expect(find.text(_l10n.reticulumBridgeSectionEndpoint), findsOneWidget);
    expect(find.text(_l10n.reticulumBridgeSectionCounters), findsOneWidget);
    expect(find.text(_l10n.reticulumBridgeSectionUptime), findsOneWidget);
    expect(find.text(_l10n.reticulumBridgeSaveAndConnect), findsOneWidget);
  });

  testWidgets(
    'host field maxLength is 253 and port field maxLength is 5 with numeric input',
    (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      final hostField = tester.widget<TextField>(
        find.widgetWithText(TextField, _l10n.reticulumBridgeHostHint).first,
      );
      expect(hostField.maxLength, 253);

      final portField = tester.widget<TextField>(
        find.widgetWithText(TextField, _l10n.reticulumBridgePortHint).first,
      );
      expect(portField.maxLength, 5);
      expect(portField.keyboardType, TextInputType.number);
    },
  );

  testWidgets('reassembly-required banner shows when reassembly is off', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    // Default flag state has reassemblyEnabled = false → banner visible.
    expect(find.text(_l10n.reticulumBridgeRequiresReassembly), findsOneWidget);
  });
}
