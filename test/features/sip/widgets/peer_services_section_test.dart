// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/sip/widgets/peer_services_section.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/providers/sip_hub_services_providers.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_advert_engine.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_messages_advert.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';

MrrpCachedService _svc({
  required int serviceId,
  int nodeId = 42,
  int versionMajor = 1,
  int versionMinor = 0,
  int metaLen = 0,
}) {
  return MrrpCachedService(
    nodeId: nodeId,
    descriptor: MrrpAdvertDescriptor(
      serviceId: serviceId,
      serviceType: MrrpServiceType.app,
      versionMajor: versionMajor,
      versionMinor: versionMinor,
      serviceFlags: MrrpServiceFlags.userVisible,
      metadata: Uint8List(metaLen),
    ),
    cachedAt: DateTime.now(),
  );
}

MaterialApp _app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('PeerServicesSection', () {
    testWidgets('renders nothing when peer has no services', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            peerServicesFullProvider(
              42,
            ).overrideWith((_) => const <MrrpCachedService>[]),
          ],
          child: _app(const PeerServicesSection(peerNodeId: 42)),
        ),
      );
      await tester.pump();

      expect(find.text('Services'), findsNothing);
    });

    testWidgets('renders header + one tile per advertised service', (
      tester,
    ) async {
      final services = [
        _svc(serviceId: MrrpServiceId.profileV1, metaLen: 24),
        _svc(serviceId: MrrpServiceId.boardV1, versionMinor: 2, metaLen: 8),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            peerServicesFullProvider(42).overrideWith((_) => services),
          ],
          child: _app(const PeerServicesSection(peerNodeId: 42)),
        ),
      );
      await tester.pump();

      expect(find.text('Services'), findsOneWidget);
      expect(find.text('profile.v1'), findsOneWidget);
      expect(find.text('board.v1'), findsOneWidget);
    });

    testWidgets('renders localized version line with version + metadata size', (
      tester,
    ) async {
      final services = [
        _svc(
          serviceId: MrrpServiceId.profileV1,
          versionMajor: 1,
          versionMinor: 2,
          metaLen: 24,
        ),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            peerServicesFullProvider(42).overrideWith((_) => services),
          ],
          child: _app(const PeerServicesSection(peerNodeId: 42)),
        ),
      );
      await tester.pump();

      expect(find.textContaining('v1.2'), findsOneWidget);
      expect(find.textContaining('24'), findsOneWidget);
    });
  });
}
