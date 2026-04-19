// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/providers/mrrp_providers.dart';
import 'package:socialmesh/providers/sip_hub_services_providers.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_advert_engine.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_messages_advert.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';

MrrpCachedService _svc({
  required int nodeId,
  required int serviceId,
  int versionMajor = 1,
  int versionMinor = 0,
  int flags = MrrpServiceFlags.userVisible,
  DateTime? cachedAt,
}) {
  return MrrpCachedService(
    nodeId: nodeId,
    descriptor: MrrpAdvertDescriptor(
      serviceId: serviceId,
      serviceType: MrrpServiceType.app,
      versionMajor: versionMajor,
      versionMinor: versionMinor,
      serviceFlags: flags,
      metadata: Uint8List(0),
    ),
    cachedAt: cachedAt ?? DateTime.now(),
  );
}

void main() {
  group('sip_hub_services_providers / peer services projection', () {
    test('empty cache → empty preview + empty full + zero count', () {
      final container = ProviderContainer(
        overrides: [mrrpCachedServicesProvider.overrideWith((_) => const {})],
      );
      addTearDown(container.dispose);

      expect(container.read(peerServicesPreviewProvider(42)), isEmpty);
      expect(container.read(peerServicesFullProvider(42)), isEmpty);
      expect(container.read(peerServicesCountProvider(42)), 0);
    });

    test('single user-visible service → 1 preview, count=1', () {
      final container = ProviderContainer(
        overrides: [
          mrrpCachedServicesProvider.overrideWith(
            (_) => {
              42: [_svc(nodeId: 42, serviceId: 0x1001)],
            },
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(peerServicesPreviewProvider(42)).length, 1);
      expect(container.read(peerServicesCountProvider(42)), 1);
    });

    test('5 services → preview capped at peerServicePreviewMax, full=5', () {
      final container = ProviderContainer(
        overrides: [
          mrrpCachedServicesProvider.overrideWith(
            (_) => {
              42: [
                for (var i = 0; i < 5; i++)
                  _svc(nodeId: 42, serviceId: 0x1000 + i),
              ],
            },
          ),
        ],
      );
      addTearDown(container.dispose);

      final preview = container.read(peerServicesPreviewProvider(42));
      final full = container.read(peerServicesFullProvider(42));
      final total = container.read(peerServicesCountProvider(42));

      expect(preview.length, peerServicePreviewMax);
      expect(preview.length, 3);
      expect(full.length, 5);
      expect(total, 5);
      expect(total - preview.length, 2);
    });

    test('non-user-visible services are filtered out', () {
      final container = ProviderContainer(
        overrides: [
          mrrpCachedServicesProvider.overrideWith(
            (_) => {
              42: [
                _svc(nodeId: 42, serviceId: 0x1001, flags: 0),
                _svc(
                  nodeId: 42,
                  serviceId: 0x1002,
                  flags: MrrpServiceFlags.userVisible,
                ),
              ],
            },
          ),
        ],
      );
      addTearDown(container.dispose);

      final full = container.read(peerServicesFullProvider(42));
      expect(full.length, 1);
      expect(full.first.descriptor.serviceId, 0x1002);
    });

    test('duplicate service_id+version entries are deduplicated', () {
      final container = ProviderContainer(
        overrides: [
          mrrpCachedServicesProvider.overrideWith(
            (_) => {
              42: [
                _svc(nodeId: 42, serviceId: 0x1001),
                _svc(nodeId: 42, serviceId: 0x1001),
                _svc(nodeId: 42, serviceId: 0x1001, versionMinor: 1),
              ],
            },
          ),
        ],
      );
      addTearDown(container.dispose);

      final full = container.read(peerServicesFullProvider(42));
      expect(full.length, 2);
    });

    test('expired entries are filtered out', () {
      final longAgo = DateTime.now().subtract(const Duration(hours: 2));
      final container = ProviderContainer(
        overrides: [
          mrrpCachedServicesProvider.overrideWith(
            (_) => {
              42: [
                _svc(nodeId: 42, serviceId: 0x1001, cachedAt: longAgo),
                _svc(nodeId: 42, serviceId: 0x1002),
              ],
            },
          ),
        ],
      );
      addTearDown(container.dispose);

      final full = container.read(peerServicesFullProvider(42));
      expect(full.length, 1);
      expect(full.first.descriptor.serviceId, 0x1002);
    });

    test('peer with no cached entry returns empty', () {
      final container = ProviderContainer(
        overrides: [
          mrrpCachedServicesProvider.overrideWith(
            (_) => {
              99: [_svc(nodeId: 99, serviceId: 0x1001)],
            },
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(peerServicesFullProvider(42)), isEmpty);
      expect(container.read(peerServicesCountProvider(42)), 0);
    });
  });
}
