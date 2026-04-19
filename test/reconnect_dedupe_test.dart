// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Regression tests for the duplicate-message-on-reconnect bug.
///
/// Root cause: foreground (ProtocolService) and background
/// (BackgroundMessageProcessor) ingest paths could both process the same BLE
/// packet during app lifecycle transitions.  Each generated a random UUID as
/// Message.id, so different primary keys → two DB rows for one logical message.
///
/// Fix: deterministic Message.id derived from protocol identity (packetId +
/// fromNode), plus a DB unique index on (packet_id, from_node).
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/services/storage/message_database.dart';

// ---------------------------------------------------------------------------
// Fakes (following existing test conventions — per-file copies)
// ---------------------------------------------------------------------------

class _FakeTransport extends DeviceTransport {
  @override
  TransportType get type => TransportType.ble;

  @override
  bool get requiresFraming => false;

  @override
  DeviceConnectionState get state => DeviceConnectionState.disconnected;

  final StreamController<DeviceConnectionState> _stateCtrl =
      StreamController<DeviceConnectionState>.broadcast();

  @override
  Stream<DeviceConnectionState> get stateStream => _stateCtrl.stream;

  @override
  Stream<List<int>> get dataStream => const Stream.empty();

  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) =>
      const Stream.empty();

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
  Future<void> dispose() async {
    await _stateCtrl.close();
  }
}

class _TestProtocolService extends ProtocolService {
  final StreamController<Message> controller =
      StreamController<Message>.broadcast();

  _TestProtocolService() : super(_FakeTransport());

  @override
  Stream<Message> get messageStream => controller.stream;

  void emit(Message m) => controller.add(m);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

int _testDbSeq = 0;
final _testPid = pid;

String _uniqueTestDbPath() {
  final dir = Directory.systemTemp.path;
  return p.join(dir, 'reconnect_dedupe_${_testPid}_${_testDbSeq++}.db');
}

Future<
  ({
    ProviderContainer container,
    _TestProtocolService protocol,
    MessageDatabase storage,
  })
>
_createTestHarness({int myNodeNum = 20}) async {
  SharedPreferences.setMockInitialValues({});

  final storage = MessageDatabase(testDbPath: _uniqueTestDbPath());
  await storage.init();

  final testProtocol = _TestProtocolService();

  final container = ProviderContainer(
    overrides: [
      messageStorageProvider.overrideWithValue(AsyncValue.data(storage)),
      protocolServiceProvider.overrideWithValue(testProtocol),
    ],
  );

  final notifier = container.read(messagesProvider.notifier);
  await notifier.storageReady;
  notifier.state = [];
  container.read(myNodeNumProvider.notifier).state = myNodeNum;

  return (container: container, protocol: testProtocol, storage: storage);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
  });

  // =========================================================================
  // 1. Deterministic identity
  // =========================================================================

  group('deterministic identity', () {
    test('same packetId + fromNode always produces the same id', () {
      final idA = Message.deterministicId(packetId: 42, fromNode: 100);
      final idB = Message.deterministicId(packetId: 42, fromNode: 100);
      expect(idA, equals(idB));
    });

    test('different packetId produces different id', () {
      final idA = Message.deterministicId(packetId: 42, fromNode: 100);
      final idB = Message.deterministicId(packetId: 43, fromNode: 100);
      expect(idA, isNot(equals(idB)));
    });

    test('different fromNode produces different id', () {
      final idA = Message.deterministicId(packetId: 42, fromNode: 100);
      final idB = Message.deterministicId(packetId: 42, fromNode: 200);
      expect(idA, isNot(equals(idB)));
    });

    test('id format is pkt-<fromHex>-<packetIdHex>', () {
      // fromNode=255 → ff, packetId=256 → 100
      final id = Message.deterministicId(packetId: 256, fromNode: 255);
      expect(id, equals('pkt-ff-100'));
    });

    test('foreground and background paths produce identical id', () {
      // Simulate what both paths do: construct Message with deterministicId
      const packetId = 999;
      const fromNode = 12345;

      final foregroundMsg = Message(
        id: Message.deterministicId(packetId: packetId, fromNode: fromNode),
        from: fromNode,
        to: 0xFFFFFFFF,
        text: 'test',
        timestamp: DateTime.now(),
        channel: 0,
        received: true,
        packetId: packetId,
      );

      final backgroundMsg = Message(
        id: Message.deterministicId(packetId: packetId, fromNode: fromNode),
        from: fromNode,
        to: 0xFFFFFFFF,
        text: 'test',
        timestamp: DateTime.now(),
        channel: 0,
        received: true,
        packetId: packetId,
      );

      expect(foregroundMsg.id, equals(backgroundMsg.id));
    });

    test('message without explicit id still gets random UUID', () {
      final msg = Message(
        from: 10,
        to: 20,
        text: 'sent msg',
        timestamp: DateTime.now(),
        channel: 0,
        received: false,
      );
      // UUID v4 format: 8-4-4-4-12 hex chars
      expect(msg.id, matches(RegExp(r'^[0-9a-f-]{36}$')));
    });
  });

  // =========================================================================
  // 2. Persistence idempotency
  // =========================================================================

  group('persistence idempotency', () {
    test(
      'saving same received packet twice results in one persisted row',
      () async {
        final storage = MessageDatabase(testDbPath: _uniqueTestDbPath());
        await storage.init();

        const packetId = 42;
        const fromNode = 10;
        final now = DateTime.now();
        final detId = Message.deterministicId(
          packetId: packetId,
          fromNode: fromNode,
        );

        final msgA = Message(
          id: detId,
          from: fromNode,
          to: 0xFFFFFFFF,
          text: 'Hello',
          timestamp: now,
          channel: 0,
          received: true,
          packetId: packetId,
        );

        final msgB = Message(
          id: detId,
          from: fromNode,
          to: 0xFFFFFFFF,
          text: 'Hello',
          timestamp: now,
          channel: 0,
          received: true,
          packetId: packetId,
        );

        await storage.saveMessage(msgA);
        await storage.saveMessage(msgB);

        final all = await storage.loadMessages();
        final matching = all.where((m) => m.packetId == packetId).toList();
        expect(matching.length, 1, reason: 'INSERT OR REPLACE on same id');
      },
    );

    test('same text but different packet identity produces two rows', () async {
      final storage = MessageDatabase(testDbPath: _uniqueTestDbPath());
      await storage.init();

      final now = DateTime.now();

      final msg1 = Message(
        id: Message.deterministicId(packetId: 100, fromNode: 10),
        from: 10,
        to: 0xFFFFFFFF,
        text: 'Same text',
        timestamp: now,
        channel: 0,
        received: true,
        packetId: 100,
      );

      final msg2 = Message(
        id: Message.deterministicId(packetId: 101, fromNode: 10),
        from: 10,
        to: 0xFFFFFFFF,
        text: 'Same text',
        timestamp: now,
        channel: 0,
        received: true,
        packetId: 101,
      );

      await storage.saveMessage(msg1);
      await storage.saveMessage(msg2);

      final all = await storage.loadMessages();
      expect(all.length, 2);
    });

    test(
      'messages with null packetId are not affected by unique index',
      () async {
        final storage = MessageDatabase(testDbPath: _uniqueTestDbPath());
        await storage.init();

        final now = DateTime.now();

        // Two sent messages without packetId — each gets a random UUID
        final sent1 = Message(
          from: 20,
          to: 10,
          text: 'Sent msg 1',
          timestamp: now,
          channel: 0,
          received: false,
        );

        final sent2 = Message(
          from: 20,
          to: 10,
          text: 'Sent msg 2',
          timestamp: now,
          channel: 0,
          received: false,
        );

        await storage.saveMessage(sent1);
        await storage.saveMessage(sent2);

        final all = await storage.loadMessages();
        expect(all.length, 2);
      },
    );
  });

  // =========================================================================
  // 3. Migration coverage
  // =========================================================================

  group('v8 migration', () {
    test(
      'old DB with duplicate rows is cleaned up and unique index created',
      () async {
        // Manually create a v7 DB with duplicate rows, then open with v8
        // migration to verify cleanup.
        final dbPath = _uniqueTestDbPath();

        // Step 1: Create a v7-style DB manually with duplicates.
        final rawDb = await databaseFactoryFfi.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(
            version: 7,
            onCreate: (db, version) async {
              await db.execute('''
                CREATE TABLE messages (
                  id TEXT PRIMARY KEY,
                  from_node INTEGER NOT NULL,
                  to_node INTEGER NOT NULL,
                  text TEXT NOT NULL,
                  timestamp INTEGER NOT NULL,
                  channel INTEGER,
                  sent INTEGER NOT NULL DEFAULT 0,
                  received INTEGER NOT NULL DEFAULT 0,
                  acked INTEGER NOT NULL DEFAULT 0,
                  status TEXT NOT NULL DEFAULT 'sent',
                  error_message TEXT,
                  routing_error TEXT,
                  packet_id INTEGER,
                  source TEXT NOT NULL DEFAULT 'unknown',
                  read INTEGER NOT NULL DEFAULT 0,
                  sender_long_name TEXT,
                  sender_short_name TEXT,
                  sender_avatar_color INTEGER,
                  conversation_key TEXT NOT NULL,
                  reply_id INTEGER,
                  is_emoji INTEGER NOT NULL DEFAULT 0,
                  hop_count INTEGER,
                  rx_snr REAL,
                  rx_rssi INTEGER,
                  sent_at INTEGER,
                  last_attempt_at INTEGER,
                  retry_count INTEGER NOT NULL DEFAULT 0,
                  auto_retry_enabled INTEGER NOT NULL DEFAULT 0
                )
              ''');
              await db.execute('''
                CREATE INDEX idx_messages_packet_id
                ON messages (packet_id)
              ''');
            },
          ),
        );

        // Insert duplicate rows with different random UUIDs but same
        // (packet_id, from_node) — the pre-fix scenario.
        final ts = DateTime.now().millisecondsSinceEpoch;
        await rawDb.insert('messages', {
          'id': 'uuid-aaa-111',
          'from_node': 10,
          'to_node': 4294967295,
          'text': 'Hello',
          'timestamp': ts,
          'channel': 0,
          'conversation_key': 'channel:0',
          'packet_id': 42,
        });
        await rawDb.insert('messages', {
          'id': 'uuid-bbb-222',
          'from_node': 10,
          'to_node': 4294967295,
          'text': 'Hello',
          'timestamp': ts,
          'channel': 0,
          'conversation_key': 'channel:0',
          'packet_id': 42,
        });

        // Also insert a legitimate distinct message
        await rawDb.insert('messages', {
          'id': 'uuid-ccc-333',
          'from_node': 10,
          'to_node': 4294967295,
          'text': 'Different',
          'timestamp': ts + 1000,
          'channel': 0,
          'conversation_key': 'channel:0',
          'packet_id': 99,
        });

        // Verify 3 rows exist pre-migration
        final preMigration = await rawDb.query('messages');
        expect(preMigration.length, 3);

        await rawDb.close();

        // Step 2: Re-open via MessageDatabase (which bumps to v8 + migrates)
        final storage = MessageDatabase(testDbPath: dbPath);
        await storage.init();

        final all = await storage.loadMessages();
        // One duplicate removed, legitimate row kept → 2 rows total
        expect(all.length, 2);

        // Verify the distinct message survived
        expect(all.any((m) => m.packetId == 99), isTrue);

        // Verify exactly one row for packetId 42
        final pkt42 = all.where((m) => m.packetId == 42).toList();
        expect(pkt42.length, 1);
      },
    );

    test(
      'post-migration: unique index prevents duplicate received packets',
      () async {
        final storage = MessageDatabase(testDbPath: _uniqueTestDbPath());
        await storage.init();

        final now = DateTime.now();

        // First insert succeeds
        final msg1 = Message(
          id: Message.deterministicId(packetId: 50, fromNode: 10),
          from: 10,
          to: 0xFFFFFFFF,
          text: 'First',
          timestamp: now,
          channel: 0,
          received: true,
          packetId: 50,
        );
        await storage.saveMessage(msg1);

        // Second insert with same deterministic id → replaces (idempotent)
        final msg2 = Message(
          id: Message.deterministicId(packetId: 50, fromNode: 10),
          from: 10,
          to: 0xFFFFFFFF,
          text: 'Updated',
          timestamp: now,
          channel: 0,
          received: true,
          packetId: 50,
        );
        await storage.saveMessage(msg2);

        final all = await storage.loadMessages();
        final matching = all.where((m) => m.packetId == 50).toList();
        expect(matching.length, 1);
        // INSERT OR REPLACE → second write wins
        expect(matching.first.text, 'Updated');
      },
    );
  });

  // =========================================================================
  // 4. Reconnect / replay scenario (end-to-end with provider)
  // =========================================================================

  group('reconnect replay dedup', () {
    test(
      'foreground + background ingest of same packet → one message',
      () async {
        final h = await _createTestHarness();
        addTearDown(h.container.dispose);

        const packetId = 777;
        const fromNode = 10;
        final now = DateTime.now();
        final detId = Message.deterministicId(
          packetId: packetId,
          fromNode: fromNode,
        );

        // Simulate background processor saving to DB (what happens
        // when the app is paused and BLE data arrives).
        final bgMsg = Message(
          id: detId,
          from: fromNode,
          to: 20,
          text: 'Mesh message',
          timestamp: now,
          channel: 0,
          received: true,
          packetId: packetId,
        );
        await h.storage.saveMessage(bgMsg);

        // Simulate foreground protocol emitting the same message
        // (ProtocolService processes same BLE packet after resume).
        final fgMsg = Message(
          id: detId,
          from: fromNode,
          to: 20,
          text: 'Mesh message',
          timestamp: now,
          channel: 0,
          received: true,
          packetId: packetId,
        );
        h.protocol.emit(fgMsg);

        // Allow stream handler to process
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Provider state should have exactly one copy
        final msgs = h.container
            .read(messagesProvider)
            .where((m) => m.packetId == packetId)
            .toList();
        expect(msgs.length, 1, reason: 'provider has one copy');

        // DB should have exactly one row
        final dbMsgs = await h.storage.loadMessages();
        final dbMatching = dbMsgs.where((m) => m.packetId == packetId).toList();
        expect(dbMatching.length, 1, reason: 'DB has one row');
      },
    );

    test('mergeBackgroundMessages does not surface duplicate', () async {
      final h = await _createTestHarness();
      addTearDown(h.container.dispose);

      const packetId = 888;
      const fromNode = 10;
      final now = DateTime.now();
      final detId = Message.deterministicId(
        packetId: packetId,
        fromNode: fromNode,
      );

      // Foreground receives message first
      final fgMsg = Message(
        id: detId,
        from: fromNode,
        to: 20,
        text: 'Before background',
        timestamp: now,
        channel: 0,
        received: true,
        packetId: packetId,
      );
      h.protocol.emit(fgMsg);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Verify foreground message is in state
      expect(
        h.container
            .read(messagesProvider)
            .where((m) => m.packetId == packetId)
            .length,
        1,
      );

      // Background processor also saved same message to DB
      final bgMsg = Message(
        id: detId,
        from: fromNode,
        to: 20,
        text: 'Before background',
        timestamp: now,
        channel: 0,
        received: true,
        packetId: packetId,
      );
      await h.storage.saveMessage(bgMsg);

      // Simulate resume → mergeBackgroundMessages with the bg id
      final notifier = h.container.read(messagesProvider.notifier);
      await notifier.mergeBackgroundMessages({detId});

      // Still exactly one
      final msgs = h.container
          .read(messagesProvider)
          .where((m) => m.packetId == packetId)
          .toList();
      expect(msgs.length, 1, reason: 'merge did not duplicate');
    });

    test(
      'reconcileFromStorageForNode does not duplicate on reconnect',
      () async {
        final h = await _createTestHarness();
        addTearDown(h.container.dispose);

        const packetId = 555;
        const fromNode = 10;
        final now = DateTime.now();
        final detId = Message.deterministicId(
          packetId: packetId,
          fromNode: fromNode,
        );

        // Message already in provider state
        final msg = Message(
          id: detId,
          from: fromNode,
          to: 20,
          text: 'Already here',
          timestamp: now,
          channel: 0,
          received: true,
          packetId: packetId,
        );
        h.protocol.emit(msg);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Also persisted to DB (normal flow saves to DB too)
        // Already saved by the stream handler, but save again to be sure
        await h.storage.saveMessage(msg);

        // Reconnect canary triggers reconcile
        final notifier = h.container.read(messagesProvider.notifier);
        await notifier.reconcileFromStorageForNode(fromNode);

        final msgs = h.container
            .read(messagesProvider)
            .where((m) => m.packetId == packetId)
            .toList();
        expect(msgs.length, 1, reason: 'reconcile did not duplicate');
      },
    );
  });

  // =========================================================================
  // 5. Regression coverage
  // =========================================================================

  group('regression coverage', () {
    test('DMs with deterministic id are preserved correctly', () async {
      final storage = MessageDatabase(testDbPath: _uniqueTestDbPath());
      await storage.init();

      final now = DateTime.now();
      final msg = Message(
        id: Message.deterministicId(packetId: 200, fromNode: 10),
        from: 10,
        to: 20,
        text: 'DM text',
        timestamp: now,
        received: true,
        packetId: 200,
      );

      await storage.saveMessage(msg);
      final all = await storage.loadMessages();
      expect(all.length, 1);
      expect(all.first.from, 10);
      expect(all.first.to, 20);
      expect(all.first.text, 'DM text');
    });

    test('channel messages with deterministic id are preserved', () async {
      final storage = MessageDatabase(testDbPath: _uniqueTestDbPath());
      await storage.init();

      final now = DateTime.now();
      final msg = Message(
        id: Message.deterministicId(packetId: 300, fromNode: 10),
        from: 10,
        to: 0xFFFFFFFF,
        text: 'Channel text',
        timestamp: now,
        channel: 3,
        received: true,
        packetId: 300,
      );

      await storage.saveMessage(msg);
      final all = await storage.loadMessages();
      expect(all.length, 1);
      expect(all.first.channel, 3);
    });

    test('broadcast messages with deterministic id are preserved', () async {
      final storage = MessageDatabase(testDbPath: _uniqueTestDbPath());
      await storage.init();

      final now = DateTime.now();
      final msg = Message(
        id: Message.deterministicId(packetId: 400, fromNode: 10),
        from: 10,
        to: 0xFFFFFFFF,
        text: 'Broadcast',
        timestamp: now,
        channel: 0,
        received: true,
        packetId: 400,
      );

      await storage.saveMessage(msg);
      final all = await storage.loadMessages();
      expect(all.length, 1);
      expect(all.first.isBroadcast, isTrue);
    });

    test('message ordering is preserved after dedup', () async {
      final storage = MessageDatabase(testDbPath: _uniqueTestDbPath());
      await storage.init();

      final base = DateTime.now();
      for (var i = 0; i < 5; i++) {
        final msg = Message(
          id: Message.deterministicId(packetId: 500 + i, fromNode: 10),
          from: 10,
          to: 0xFFFFFFFF,
          text: 'Message $i',
          timestamp: base.add(Duration(seconds: i)),
          channel: 0,
          received: true,
          packetId: 500 + i,
        );
        await storage.saveMessage(msg);
      }

      final all = await storage.loadMessages();
      expect(all.length, 5);
      for (var i = 0; i < 4; i++) {
        expect(
          all[i].timestamp.isBefore(all[i + 1].timestamp),
          isTrue,
          reason: 'message $i should be before message ${i + 1}',
        );
      }
    });
  });
}
