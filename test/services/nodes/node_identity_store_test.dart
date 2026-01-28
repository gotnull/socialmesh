import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/services/nodes/node_identity_store.dart';

void main() {
  test('NodeIdentityStore persists identities', () async {
    SharedPreferences.setMockInitialValues({});

    final store = NodeIdentityStore();
    await store.init();

    var current = <int, NodeIdentity>{};
    current = await store.upsert(
      current: current,
      nodeNum: 0x1A2B,
      longName: 'Wismesh Relay',
      shortName: 'WISM',
      updatedAtMs: 1710000000000,
      lastSeenAtMs: 1710000001000,
    );

    expect(current[0x1A2B]?.longName, 'Wismesh Relay');
    expect(current[0x1A2B]?.shortName, 'WISM');

    final reloadedStore = NodeIdentityStore();
    await reloadedStore.init();

    final reloaded = await reloadedStore.getAllIdentities();
    final identity = reloaded[0x1A2B];

    expect(identity, isNotNull);
    expect(identity?.longName, 'Wismesh Relay');
    expect(identity?.shortName, 'WISM');
    expect(identity?.lastUpdatedAt, 1710000000000);
    expect(identity?.lastSeenAt, 1710000001000);
  });

  test('NodeIdentityStore blocks BLE default names', () async {
    SharedPreferences.setMockInitialValues({});

    final store = NodeIdentityStore();
    await store.init();

    var current = <int, NodeIdentity>{};
    current = await store.upsert(
      current: current,
      nodeNum: 0x5ed6,
      longName: 'Meshtastic_5ed6',
      shortName: 'Meshtastic_5ed6',
      updatedAtMs: 1710000002000,
    );

    final identity = current[0x5ed6];
    expect(identity, isNull);
  });
}
