// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logging.dart';
import '../services/mesh_beacon_notice_store.dart';
import '../services/protocol/protocol_service.dart';
import 'app_providers.dart';
import 'radio_scope_providers.dart';

final meshBeaconNoticeStoreProvider = FutureProvider<MeshBeaconNoticeStore>((
  ref,
) async {
  final scope = ref.watch(radioScopeProvider);
  final prefs = await SharedPreferences.getInstance();
  return MeshBeaconNoticeStore(prefs, radioScope: scope);
});

/// Unreviewed, distinct offers from the active Meshtastic session.
class MeshBeaconNoticesNotifier extends Notifier<List<MeshBeaconEvent>> {
  @override
  List<MeshBeaconEvent> build() {
    final store = ref.watch(meshBeaconNoticeStoreProvider).value;
    final protocol = ref.watch(protocolServiceProvider);
    final subscription = protocol.meshBeaconEventStream.listen(
      (_) {
        state = store?.pending(protocol.recentMeshBeacons) ?? const [];
      },
      onError: (Object error) {
        AppLogging.protocol('Mesh Beacon notice stream failed: $error');
      },
    );
    ref.onDispose(subscription.cancel);
    return store?.pending(protocol.recentMeshBeacons) ?? const [];
  }

  Future<void> dismiss(List<MeshBeaconEvent> displayed) async {
    final store = ref.read(meshBeaconNoticeStoreProvider).value;
    if (store == null) return;
    final saved = store.dismiss(displayed);
    state = store.pending(ref.read(protocolServiceProvider).recentMeshBeacons);
    await saved;
  }
}

final meshBeaconNoticesProvider =
    NotifierProvider<MeshBeaconNoticesNotifier, List<MeshBeaconEvent>>(
      MeshBeaconNoticesNotifier.new,
    );
