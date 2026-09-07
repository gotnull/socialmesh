// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/mesh_beacon_providers.dart';
import 'package:socialmesh/services/mesh_beacon_notice_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

class _Protocol extends Mock implements ProtocolService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'hydrates, follows arrivals, and cancels its subscription on disposal',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = MeshBeaconNoticeStore(
        await SharedPreferences.getInstance(),
        radioScope: 'radio',
      );
      final first = MeshBeaconEvent(
        senderNodeId: 1,
        message: '',
        receivedAt: DateTime.now(),
        offerChannelPsk: [1],
      );
      final second = MeshBeaconEvent(
        senderNodeId: 2,
        message: '',
        receivedAt: DateTime.now(),
        offerChannelPsk: [2],
      );
      final recent = [first];
      final events = StreamController<MeshBeaconEvent>.broadcast();
      final protocol = _Protocol();
      when(() => protocol.recentMeshBeacons).thenAnswer((_) => List.of(recent));
      when(
        () => protocol.meshBeaconEventStream,
      ).thenAnswer((_) => events.stream);
      final container = ProviderContainer(
        overrides: [
          protocolServiceProvider.overrideWithValue(protocol),
          meshBeaconNoticeStoreProvider.overrideWithValue(AsyncData(store)),
        ],
      );
      container.listen(meshBeaconNoticesProvider, (previous, next) {});
      expect(container.read(meshBeaconNoticesProvider), [first]);
      final displayed = container.read(meshBeaconNoticesProvider);
      recent.insert(0, second);
      events.add(second);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(meshBeaconNoticesProvider), [second, first]);
      await container
          .read(meshBeaconNoticesProvider.notifier)
          .dismiss(displayed);
      expect(container.read(meshBeaconNoticesProvider), [second]);
      recent.insert(0, first);
      events.add(first);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(meshBeaconNoticesProvider), [second]);
      container.dispose();
      expect(events.hasListener, isFalse);
      await events.close();
    },
  );
}
