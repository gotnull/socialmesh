// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/sip/widgets/peer_service_preview_row.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/providers/sip_hub_services_providers.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_advert_engine.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_messages_advert.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';

MrrpCachedService _svc(int serviceId, {int nodeId = 42}) => MrrpCachedService(
  nodeId: nodeId,
  descriptor: MrrpAdvertDescriptor(
    serviceId: serviceId,
    serviceType: MrrpServiceType.app,
    versionMajor: 1,
    versionMinor: 0,
    serviceFlags: MrrpServiceFlags.userVisible,
    metadata: Uint8List(0),
  ),
  cachedAt: DateTime.now(),
);

MaterialApp _app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  group('PeerServicePreviewRow', () {
    testWidgets('renders nothing when peer has no visible services', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            peerServicesPreviewProvider(
              42,
            ).overrideWith((_) => const <MrrpCachedService>[]),
            peerServicesCountProvider(42).overrideWith((_) => 0),
          ],
          child: _app(const PeerServicePreviewRow(peerNodeId: 42)),
        ),
      );
      await tester.pump();

      expect(find.byType(Wrap), findsNothing);
    });

    testWidgets('renders up to 3 preview chips without "+N more" tag', (
      tester,
    ) async {
      final services = [
        _svc(MrrpServiceId.profileV1),
        _svc(MrrpServiceId.meetupV1),
        _svc(MrrpServiceId.boardV1),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            peerServicesPreviewProvider(42).overrideWith((_) => services),
            peerServicesCountProvider(42).overrideWith((_) => 3),
          ],
          child: _app(const PeerServicePreviewRow(peerNodeId: 42)),
        ),
      );
      await tester.pump();

      expect(find.byType(Wrap), findsOneWidget);
      expect(find.text('profile.v1'), findsOneWidget);
      expect(find.text('meetup.v1'), findsOneWidget);
      expect(find.text('board.v1'), findsOneWidget);
      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('renders "+N more" tag when total > preview', (tester) async {
      final preview = [
        _svc(MrrpServiceId.profileV1),
        _svc(MrrpServiceId.meetupV1),
        _svc(MrrpServiceId.boardV1),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            peerServicesPreviewProvider(42).overrideWith((_) => preview),
            peerServicesCountProvider(42).overrideWith((_) => 5),
          ],
          child: _app(const PeerServicePreviewRow(peerNodeId: 42)),
        ),
      );
      await tester.pump();

      expect(find.text('+2'), findsOneWidget);
    });
  });
}
