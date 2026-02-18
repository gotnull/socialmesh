// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/logging.dart';
import '../../../providers/auth_providers.dart';
import '../models/tak_event.dart';
import '../services/tak_database.dart';
import '../services/tak_gateway_client.dart';

/// Whether the TAK Gateway feature is enabled.
final isTakEnabledProvider = Provider<bool>((ref) {
  final enabled = AppFeatureFlags.isTakGatewayEnabled;
  AppLogging.tak('isTakEnabledProvider: $enabled');
  return enabled;
});

/// TAK event database instance (singleton).
final takDatabaseProvider = Provider<TakDatabase>((ref) {
  AppLogging.tak('Creating TakDatabase provider');
  final db = TakDatabase();
  ref.onDispose(() {
    AppLogging.tak('Disposing TakDatabase provider');
    db.close();
  });
  return db;
});

/// TAK Gateway WebSocket client.
final takGatewayClientProvider = Provider<TakGatewayClient>((ref) {
  final authService = ref.watch(authServiceProvider);
  AppLogging.tak(
    'Creating TakGatewayClient provider: url=${AppUrls.takGatewayUrl}',
  );
  final client = TakGatewayClient(
    gatewayUrl: AppUrls.takGatewayUrl,
    getAuthToken: () => authService.getIdToken(),
  );
  ref.onDispose(() {
    AppLogging.tak('Disposing TakGatewayClient provider');
    client.dispose();
  });
  return client;
});

/// Stream of connection state changes.
final takConnectionStateProvider = StreamProvider<TakConnectionState>((ref) {
  final client = ref.watch(takGatewayClientProvider);
  AppLogging.tak('takConnectionStateProvider subscribed');
  return client.stateStream;
});

/// Stream of individual TAK events.
final takEventStreamProvider = StreamProvider<TakEvent>((ref) {
  final client = ref.watch(takGatewayClientProvider);
  AppLogging.tak('takEventStreamProvider subscribed');
  return client.eventStream;
});

/// Stream of snapshot backfills.
final takSnapshotStreamProvider = StreamProvider<List<TakEvent>>((ref) {
  final client = ref.watch(takGatewayClientProvider);
  AppLogging.tak('takSnapshotStreamProvider subscribed');
  return client.snapshotStream;
});
