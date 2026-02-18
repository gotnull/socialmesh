// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../providers/auth_providers.dart';
import '../models/tak_event.dart';
import '../services/tak_database.dart';
import '../services/tak_gateway_client.dart';

/// Whether the TAK Gateway feature is enabled.
final isTakEnabledProvider = Provider<bool>((ref) {
  return AppFeatureFlags.isTakGatewayEnabled;
});

/// TAK event database instance (singleton).
final takDatabaseProvider = Provider<TakDatabase>((ref) {
  final db = TakDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// TAK Gateway WebSocket client.
final takGatewayClientProvider = Provider<TakGatewayClient>((ref) {
  final authService = ref.watch(authServiceProvider);
  final client = TakGatewayClient(
    gatewayUrl: AppUrls.takGatewayUrl,
    getAuthToken: () => authService.getIdToken(),
  );
  ref.onDispose(client.dispose);
  return client;
});

/// Stream of connection state changes.
final takConnectionStateProvider = StreamProvider<TakConnectionState>((ref) {
  final client = ref.watch(takGatewayClientProvider);
  return client.stateStream;
});

/// Stream of individual TAK events.
final takEventStreamProvider = StreamProvider<TakEvent>((ref) {
  final client = ref.watch(takGatewayClientProvider);
  return client.eventStream;
});

/// Stream of snapshot backfills.
final takSnapshotStreamProvider = StreamProvider<List<TakEvent>>((ref) {
  final client = ref.watch(takGatewayClientProvider);
  return client.snapshotStream;
});
