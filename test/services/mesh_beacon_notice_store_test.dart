// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/generated/meshtastic/config.pbenum.dart' as config;
import 'package:socialmesh/services/mesh_beacon_notice_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

MeshBeaconEvent beacon(
  int sender, {
  List<int>? psk = const [1],
  String message = 'Join us',
}) => MeshBeaconEvent(
  senderNodeId: sender,
  message: message,
  receivedAt: DateTime.now(),
  offerChannelName: psk == null ? null : 'Local',
  offerChannelPsk: psk,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late MeshBeaconNoticeStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = MeshBeaconNoticeStore(prefs, radioScope: 'radio-a');
  });

  test(
    'deduplicates repeated offers and omits announcements without offers',
    () {
      final first = beacon(1);
      expect(
        store.pending([
          first,
          beacon(1, message: 'Still here'),
          beacon(2, psk: null),
        ]),
        [first],
      );
    },
  );

  test('includes radio-only offers', () {
    final offer = MeshBeaconEvent(
      senderNodeId: 1,
      message: '',
      receivedAt: DateTime.now(),
      offerPreset: config.Config_LoRaConfig_ModemPreset.MEDIUM_FAST,
    );
    expect(store.pending([offer]), [offer]);
  });

  test(
    'dismisses only the displayed snapshot, keeping later arrivals',
    () async {
      final displayed = [beacon(1), beacon(2)];
      final later = beacon(3);
      await store.dismiss(displayed);
      expect(store.pending([later, ...displayed, beacon(1)]), [later]);
    },
  );

  test(
    'remembers dismissal after restart but accepts changed offers',
    () async {
      await store.dismiss([beacon(1)]);
      final restored = MeshBeaconNoticeStore(prefs, radioScope: 'radio-a');
      final changed = beacon(1, psk: [2]);
      expect(restored.pending([beacon(1), changed]), [changed]);
      final persisted = prefs.getStringList('mesh_beacon_reviewed_radio-a')!;
      expect(persisted.single, matches(RegExp(r'^[0-9a-f]{64}$')));
    },
  );

  test('keeps different radios and different senders independent', () async {
    await store.dismiss([beacon(1)]);
    final otherSender = beacon(2);
    expect(store.pending([otherSender]), [otherSender]);
    final otherRadio = MeshBeaconNoticeStore(prefs, radioScope: 'radio-b');
    expect(otherRadio.pending([beacon(1)]), hasLength(1));
  });

  test(
    'serializes overlapping dismissals without losing reviewed offers',
    () async {
      await Future.wait([
        store.dismiss([beacon(1)]),
        store.dismiss([beacon(2)]),
      ]);
      final restored = MeshBeaconNoticeStore(prefs, radioScope: 'radio-a');
      expect(restored.pending([beacon(1), beacon(2)]), isEmpty);
    },
  );
}
