// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/tak/providers/tak_bridge_providers.dart';

void main() {
  group('TakBridgeProviders', () {
    test('isTakMeshBridgeEnabledProvider defaults to false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Without .env setup, feature flag defaults to false.
      final enabled = container.read(isTakMeshBridgeEnabledProvider);
      expect(enabled, isFalse);
    });

    test('takCertManagerProvider creates instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final manager = container.read(takCertManagerProvider);
      expect(manager, isNotNull);
    });

    test('takIdentityRegistryProvider creates instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final registry = container.read(takIdentityRegistryProvider);
      expect(registry, isNotNull);
    });

    test('takServerProvider creates server', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final server = container.read(takServerProvider);
      expect(server, isNotNull);
      expect(server.isRunning, isFalse);
    });

    test('takMeshBridgeProvider creates bridge', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final bridge = container.read(takMeshBridgeProvider);
      expect(bridge, isNotNull);
      expect(bridge.isRunning, isFalse);
    });

    test('takBridgeStatusProvider returns initial status', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final status = container.read(takBridgeStatusProvider);
      expect(status.isRunning, isFalse);
      expect(status.connectedClientCount, 0);
      expect(status.packetsInbound, 0);
      expect(status.packetsOutbound, 0);
    });

    test('TakBridgeStatus default constructor', () {
      const status = TakBridgeStatus();
      expect(status.isRunning, isFalse);
      expect(status.connectedClientCount, 0);
      expect(status.packetsInbound, 0);
      expect(status.packetsOutbound, 0);
      expect(status.lastActivity, isNull);
    });
  });
}
