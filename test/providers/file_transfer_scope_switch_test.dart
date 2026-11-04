// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/radio_scope.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/file_transfer_providers.dart';
import 'package:socialmesh/services/file_transfer/file_transfer_database.dart';
import 'package:socialmesh/services/file_transfer/file_transfer_engine.dart';
import 'package:socialmesh/services/mesh_packet_dedupe_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Each radio keeps its own file transfers. A radio switch replaces the
// store, so the engine and the transfer list have to move to the new one;
// an engine left on the closed store drops every later write silently.

class _SilentTransport extends DeviceTransport {
  @override
  TransportType get type => TransportType.ble;
  @override
  bool get requiresFraming => false;
  @override
  bool get requiresWakeSequence => false;
  @override
  TransportReconnectMode get reconnectMode => TransportReconnectMode.scanBased;
  @override
  DeviceConnectionState get state => DeviceConnectionState.disconnected;
  @override
  Stream<DeviceConnectionState> get stateStream =>
      const Stream<DeviceConnectionState>.empty();
  @override
  Stream<List<int>> get dataStream => const Stream<List<int>>.empty();
  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) =>
      const Stream<DeviceInfo>.empty();
  @override
  Future<void> connect(DeviceInfo device) async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> enableNotifications() async {}
  @override
  Future<void> pollOnce() async {}
  @override
  Future<void> send(List<int> data) async {}
  @override
  Future<int?> readRssi() async => null;
  @override
  Future<void> dispose() async {}
}

FileTransferState _completedTransfer(String idHex) {
  final now = DateTime.now();
  return FileTransferState(
    fileIdHex: idHex,
    fileId: Uint8List.fromList(List.filled(8, 1)),
    direction: TransferDirection.outbound,
    state: TransferState.complete,
    filename: 'notes.txt',
    mimeType: 'text/plain',
    totalBytes: 10,
    chunkSize: 10,
    chunkCount: 1,
    sha256Hash: Uint8List(32),
    completedChunks: const {0},
    nackRounds: 0,
    createdAt: now,
    expiresAt: now.add(const Duration(hours: 1)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('switching radios moves the engine and the transfer list to the new '
      'radio\'s store', () async {
    SharedPreferences.setMockInitialValues({});
    final tempDir = await Directory.systemTemp.createTemp('ft_scope');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => tempDir.path,
        );
    RadioScope.instance.debugSetRoot(Directory(p.join(tempDir.path, 'root')));
    await RadioScope.instance.init();
    await RadioScope.instance.useNodeNum(0xaaaa);

    final firstRadio = FileTransferDatabase();
    await firstRadio.init();
    await firstRadio.saveTransfer(_completedTransfer('aaaa0001'));
    await firstRadio.close();

    final dedupeStore = MeshPacketDedupeStore(
      dbPathOverride: p.join(tempDir.path, 'dedupe.db'),
    );
    await dedupeStore.init();
    final protocol = ProtocolService(
      _SilentTransport(),
      dedupeStore: dedupeStore,
    );
    final container = ProviderContainer(
      overrides: [protocolServiceProvider.overrideWithValue(protocol)],
    );

    Future<List<String>> loadedIds() async {
      for (var i = 0; i < 50; i++) {
        final state = container.read(fileTransferStateProvider);
        if (!state.isLoading) return state.transfers.keys.toList();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      fail('transfer list never finished loading');
    }

    try {
      container.listen(fileTransferStateProvider, (_, _) {});
      expect(await loadedIds(), ['aaaa0001']);
      final firstEngine = container.read(fileTransferEngineProvider);

      await RadioScope.instance.useNodeNum(0xbbbb);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(container.read(fileTransferEngineProvider), isNot(firstEngine));
      expect(await loadedIds(), isEmpty);
    } finally {
      container.dispose();
      protocol.stop();
      await dedupeStore.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          );
      RadioScope.instance.debugSetRoot(null);
      await tempDir.delete(recursive: true);
    }
  });
}
