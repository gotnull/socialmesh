// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/widgets/status_banner.dart';
import 'package:socialmesh/features/channels/widgets/mesh_beacon_notice.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/providers/mesh_beacon_providers.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

class _Notices extends MeshBeaconNoticesNotifier {
  final List<MeshBeaconEvent> initial;
  List<MeshBeaconEvent>? dismissed;
  _Notices(this.initial);

  @override
  List<MeshBeaconEvent> build() => initial;

  @override
  Future<void> dismiss(List<MeshBeaconEvent> displayed) async {
    dismissed = displayed;
    state = state.where((beacon) => !displayed.contains(beacon)).toList();
  }
}

void main() {
  final offer = MeshBeaconEvent(
    senderNodeId: 1,
    message: '',
    receivedAt: DateTime(2026),
    offerChannelPsk: [1],
  );

  Widget app(
    _Notices notices, {
    Locale locale = const Locale('en'),
    double scale = 1,
  }) => ProviderScope(
    overrides: [meshBeaconNoticesProvider.overrideWith(() => notices)],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routes: {
        '/mesh-beacon': (_) =>
            const Material(child: Text('Beacon settings destination')),
      },
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: const Material(
            child: Align(
              alignment: Alignment.topCenter,
              child: MeshBeaconNotice(),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('hides when there are no new offers', (tester) async {
    await tester.pumpWidget(app(_Notices([])));
    expect(find.byType(StatusBanner), findsNothing);
  });

  testWidgets('dismisses the displayed offers without opening settings', (
    tester,
  ) async {
    final notices = _Notices([offer]);
    await tester.pumpWidget(app(notices));
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(notices.dismissed, [offer]);
    expect(find.byType(StatusBanner), findsNothing);
    expect(find.text('Beacon settings destination'), findsNothing);
  });

  testWidgets('opens Mesh Beacon settings and marks the snapshot reviewed', (
    tester,
  ) async {
    final notices = _Notices([offer]);
    await tester.pumpWidget(app(notices));
    await tester.tap(find.text('New Mesh Beacon offer'));
    await tester.pumpAndSettle();
    expect(notices.dismissed, [offer]);
    expect(find.text('Beacon settings destination'), findsOneWidget);
  });

  testWidgets(
    'wraps long translations at large text sizes on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        app(_Notices([offer]), locale: const Locale('de'), scale: 1.5),
      );
      expect(tester.takeException(), isNull);
      final title = tester.getRect(find.text('Neues Mesh-Beacon-Angebot'));
      final dismiss = tester.getRect(find.byType(IconButton));
      expect(title.right, lessThanOrEqualTo(dismiss.left));
      expect(dismiss.right, lessThan(375));
    },
  );
}
