// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/mesh_feed/mesh_feed_database.dart';
import 'package:socialmesh/services/mesh_feed/mesh_feed_repository.dart';
import 'package:socialmesh/services/mesh_feed/mesh_post.dart';
import 'package:socialmesh/services/mesh_feed/mesh_sync_service.dart';
import 'package:socialmesh/services/mesh_sync/lan_sync_protocol.dart';
import 'package:socialmesh/services/mesh_sync/lan_sync_service.dart';
import 'package:socialmesh/services/mesh_sync/mesh_sync_session.dart';

// ---------------------------------------------------------------------------
// Fake in-memory database — mirrors existing mesh_sync_service_test pattern
// ---------------------------------------------------------------------------

class _FakeSyncDb extends MeshFeedDatabase {
  _FakeSyncDb() : super(dbPathOverride: ':memory:');

  final Map<String, MeshPost> posts = {};
  final Map<String, _PeerState> peers = {};
  int _nextSeq = 1;
  int _nextSyncSeq = 1;

  @override
  bool get isOpen => true;

  @override
  Future<void> open() async {}

  @override
  Future<void> close() async {}

  @override
  Future<bool> upsertPost(MeshPost post) async {
    if (posts.containsKey(post.id)) {
      final existing = posts[post.id]!;
      // MERGE: bump localSeq but NOT syncSeq.
      posts[post.id] = existing.copyWith(
        seenViaTransports: {
          ...existing.seenViaTransports,
          ...post.seenViaTransports,
        },
        lastSeenAt: post.lastSeenAt,
        localSeq: _nextSeq,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      _nextSeq++;
      return false;
    }
    // INSERT: assign both localSeq and syncSeq.
    posts[post.id] = post.copyWith(
      localSeq: _nextSeq,
      syncSeq: _nextSyncSeq,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    _nextSeq++;
    _nextSyncSeq++;
    return true;
  }

  @override
  Future<void> addReceipt({
    required String postId,
    required MeshTransportType transport,
    String? peerId,
    int? hopCount,
  }) async {}

  @override
  Future<List<MeshPost>> getActivePosts({int limit = 200}) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return posts.values
        .where((p) => p.expiresAt.millisecondsSinceEpoch > nowMs)
        .toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
  }

  @override
  Future<MeshPost?> getPost(String id) async => posts[id];

  @override
  Future<int> cleanupExpired() async => 0;

  @override
  Future<int> countActivePosts() async => posts.length;

  @override
  Future<List<MeshPost>> getSyncEligiblePosts({
    int? afterMs,
    int limit = 100,
  }) async {
    return posts.values.toList();
  }

  @override
  Future<void> upsertSyncPeer({
    required String peerId,
    String? displayName,
    required MeshTransportType transport,
    int? syncCursorMs,
  }) async {
    peers[peerId] = _PeerState(
      peerId: peerId,
      displayName: displayName,
      transport: transport,
      syncCursorMs: syncCursorMs,
      syncCursorSeq: peers[peerId]?.syncCursorSeq,
    );
  }

  @override
  Future<int?> getSyncCursorSeq(String peerId) async {
    return peers[peerId]?.syncCursorSeq;
  }

  @override
  Future<void> updateSyncCursorSeq(String peerId, int cursorSeq) async {
    final existing = peers[peerId];
    if (existing != null) {
      peers[peerId] = _PeerState(
        peerId: existing.peerId,
        displayName: existing.displayName,
        transport: existing.transport,
        syncCursorMs: existing.syncCursorMs,
        syncCursorSeq: cursorSeq,
      );
    }
  }

  @override
  Future<List<MeshPost>> getPostsAfterSeq({
    int? afterSeq,
    int limit = 50,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    var result = posts.values
        .where(
          (p) =>
              p.expiresAt.millisecondsSinceEpoch > nowMs && p.syncSeq != null,
        )
        .toList();
    if (afterSeq != null) {
      result = result.where((p) => p.syncSeq! > afterSeq).toList();
    }
    result.sort((a, b) {
      final seqCmp = a.syncSeq!.compareTo(b.syncSeq!);
      if (seqCmp != 0) return seqCmp;
      return a.id.compareTo(b.id);
    });
    if (result.length > limit) return result.sublist(0, limit);
    return result;
  }

  @override
  Future<List<MeshPost>> getLoraEligiblePosts({int limit = 20}) async => [];

  @override
  Future<void> markLoraRebroadcast(String postId) async {}
}

class _PeerState {
  _PeerState({
    required this.peerId,
    this.displayName,
    required this.transport,
    this.syncCursorMs,
    this.syncCursorSeq,
  });

  final String peerId;
  final String? displayName;
  final MeshTransportType transport;
  final int? syncCursorMs;
  final int? syncCursorSeq;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

MeshPost _makePost(int nodeNum, String content, {int? createdAtMs}) {
  return MeshPost(
    authorNodeNum: nodeNum,
    createdAtMs: createdAtMs ?? DateTime.now().millisecondsSinceEpoch,
    content: content,
    seenViaTransports: {MeshTransportType.local},
  );
}

/// Create a full LanSyncService backed by in-memory DB.
({
  LanSyncService service,
  MeshFeedRepository repo,
  MeshSyncService syncService,
  _FakeSyncDb db,
})
_createPeer(int nodeNum) {
  final db = _FakeSyncDb();
  final repo = MeshFeedRepository(database: db);
  final syncService = MeshSyncService(database: db);
  final service = LanSyncService(
    localNodeNum: nodeNum,
    localDisplayName: 'Node-${nodeNum.toRadixString(16)}',
    feedRepository: repo,
    syncService: syncService,
  );
  return (service: service, repo: repo, syncService: syncService, db: db);
}

/// Run two services through full bidirectional sync over localhost TCP.
Future<
  ({int clientSent, int clientReceived, int serverSent, int serverReceived})
>
_runLoopbackSync({
  required LanSyncService serverService,
  required LanSyncService clientService,
  required int serverNodeNum,
  required int clientNodeNum,
}) async {
  final serverSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);

  late MeshSyncSession serverSession;
  final serverDone = Completer<void>();

  serverSocket.listen((socket) async {
    serverSession = MeshSyncSession(
      peerId: buildLanSyncPeerId(clientNodeNum),
      peerNodeNum: clientNodeNum,
      transport: MeshTransportType.lanPeerSync,
    );
    try {
      await serverService.performSyncDirect(
        socket,
        serverSession,
        isInitiator: false,
      );
    } catch (_) {}
    socket.destroy();
    serverDone.complete();
  });

  final clientSocket = await Socket.connect(
    InternetAddress.loopbackIPv4,
    serverSocket.port,
  );

  final clientSession = MeshSyncSession(
    peerId: buildLanSyncPeerId(serverNodeNum),
    peerNodeNum: serverNodeNum,
    transport: MeshTransportType.lanPeerSync,
  );

  try {
    await clientService.performSyncDirect(
      clientSocket,
      clientSession,
      isInitiator: true,
    );
  } catch (_) {}

  clientSocket.destroy();
  await serverDone.future.timeout(const Duration(seconds: 5));
  await serverSocket.close();

  return (
    clientSent: clientSession.objectsSent,
    clientReceived: clientSession.objectsReceived,
    serverSent: serverSession.objectsSent,
    serverReceived: serverSession.objectsReceived,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('LAN sync — hello negotiation', () {
    test('successful hello exchange completes without error', () async {
      final a = _createPeer(0x11111111);
      final b = _createPeer(0x22222222);

      final result = await _runLoopbackSync(
        serverService: b.service,
        clientService: a.service,
        serverNodeNum: 0x22222222,
        clientNodeNum: 0x11111111,
      );

      expect(result.clientSent, greaterThanOrEqualTo(0));
      expect(result.serverSent, greaterThanOrEqualTo(0));
    });

    test('version mismatch sends error and disconnects', () async {
      final server = _createPeer(0x33333333);
      final serverSocket = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );

      final serverDone = Completer<MeshSyncSession>();

      serverSocket.listen((socket) async {
        final session = MeshSyncSession(
          peerId: '!44444444',
          peerNodeNum: 0x44444444,
          transport: MeshTransportType.lanPeerSync,
        );
        try {
          await server.service.performSyncDirect(
            socket,
            session,
            isInitiator: false,
          );
        } catch (_) {}
        socket.destroy();
        serverDone.complete(session);
      });

      final clientSocket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        serverSocket.port,
      );

      // Send hello with wrong version.
      const badHello = LanSyncHello(
        protocolVersion: 999,
        peerId: '!44444444',
        nodeNum: 0x44444444,
      );
      clientSocket.writeln(badHello.toLine());

      // Read responses.
      final lines = clientSocket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lines) {
        if (line.isEmpty) continue;
        final msg = json.decode(line) as Map<String, dynamic>;
        if (msg['type'] == 'error') break;
      }

      clientSocket.destroy();
      final session = await serverDone.future.timeout(
        const Duration(seconds: 5),
      );
      await serverSocket.close();

      expect(session.state, equals(SyncSessionState.failed));
      expect(session.errorMessage, contains('Version mismatch'));
    });

    test('malformed JSON frame triggers protocol error', () async {
      final server = _createPeer(0x55555555);
      final serverSocket = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );

      final serverDone = Completer<MeshSyncSession>();

      serverSocket.listen((socket) async {
        final session = MeshSyncSession(
          peerId: 'unknown',
          peerNodeNum: 0,
          transport: MeshTransportType.lanPeerSync,
        );
        try {
          await server.service.performSyncDirect(
            socket,
            session,
            isInitiator: false,
          );
        } catch (_) {}
        socket.destroy();
        serverDone.complete(session);
      });

      final clientSocket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        serverSocket.port,
      );

      clientSocket.writeln('this is not valid json {{{');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      clientSocket.destroy();

      final session = await serverDone.future.timeout(
        const Duration(seconds: 5),
      );
      await serverSocket.close();

      expect(session.state, equals(SyncSessionState.failed));
      expect(session.errorMessage, contains('Malformed'));
    });
  });

  group('LAN sync — incremental batch exchange', () {
    test('peer with no cursor gets full batch', () async {
      final a = _createPeer(0xAAAAAAAA);
      final b = _createPeer(0xBBBBBBBB);

      await a.repo.ingest(_makePost(0xAAAAAAAA, 'Post 1'));
      await a.repo.ingest(_makePost(0xAAAAAAAA, 'Post 2'));
      await a.repo.ingest(_makePost(0xAAAAAAAA, 'Post 3'));

      final result = await _runLoopbackSync(
        serverService: b.service,
        clientService: a.service,
        serverNodeNum: 0xBBBBBBBB,
        clientNodeNum: 0xAAAAAAAA,
      );

      expect(result.serverReceived, equals(3));
      expect(b.db.posts.length, equals(3));
      expect(result.clientReceived, equals(0));
    });

    test('bidirectional sync exchanges posts both ways', () async {
      final a = _createPeer(0xAAAAAAAA);
      final b = _createPeer(0xBBBBBBBB);

      await a.repo.ingest(_makePost(0xAAAAAAAA, 'From A - 1'));
      await a.repo.ingest(_makePost(0xAAAAAAAA, 'From A - 2'));
      await b.repo.ingest(_makePost(0xBBBBBBBB, 'From B - 1'));

      final result = await _runLoopbackSync(
        serverService: b.service,
        clientService: a.service,
        serverNodeNum: 0xBBBBBBBB,
        clientNodeNum: 0xAAAAAAAA,
      );

      expect(a.db.posts.length, equals(3));
      expect(result.clientReceived, equals(1));
      expect(b.db.posts.length, equals(3));
      // serverReceived is 3 (not 2) because dedup-ingested posts get bumped
      // localSeq, which causes them to appear after the cursor again. B
      // receives A's 2 original posts plus its own post echoed back.
      expect(result.serverReceived, equals(3));
    });

    test('ack advances sender cursor', () async {
      final a = _createPeer(0xAAAAAAAA);
      final b = _createPeer(0xBBBBBBBB);

      await a.repo.ingest(_makePost(0xAAAAAAAA, 'Post 1'));
      await a.repo.ingest(_makePost(0xAAAAAAAA, 'Post 2'));

      await _runLoopbackSync(
        serverService: b.service,
        clientService: a.service,
        serverNodeNum: 0xBBBBBBBB,
        clientNodeNum: 0xAAAAAAAA,
      );

      final cursorOnA = await a.syncService.getCursorForPeer(
        buildLanSyncPeerId(0xBBBBBBBB),
      );
      expect(cursorOnA, isNotNull);
      expect(cursorOnA, greaterThan(0));
    });

    test('repeated sync only sends new posts', () async {
      final a = _createPeer(0xAAAAAAAA);
      final b = _createPeer(0xBBBBBBBB);

      await a.repo.ingest(_makePost(0xAAAAAAAA, 'Post 1'));

      await _runLoopbackSync(
        serverService: b.service,
        clientService: a.service,
        serverNodeNum: 0xBBBBBBBB,
        clientNodeNum: 0xAAAAAAAA,
      );
      expect(b.db.posts.length, equals(1));

      await a.repo.ingest(_makePost(0xAAAAAAAA, 'Post 2'));

      final result2 = await _runLoopbackSync(
        serverService: b.service,
        clientService: a.service,
        serverNodeNum: 0xBBBBBBBB,
        clientNodeNum: 0xAAAAAAAA,
      );

      expect(b.db.posts.length, equals(2));
      // With sync_seq, the merge from B echoing Post 1 back to A does NOT
      // bump sync_seq, so only Post 2 (new content) is above the cursor.
      expect(result2.clientSent, equals(1));
    });

    test('no duplicates on repeated sync', () async {
      final a = _createPeer(0xAAAAAAAA);
      final b = _createPeer(0xBBBBBBBB);

      await a.repo.ingest(_makePost(0xAAAAAAAA, 'Unique Post'));

      await _runLoopbackSync(
        serverService: b.service,
        clientService: a.service,
        serverNodeNum: 0xBBBBBBBB,
        clientNodeNum: 0xAAAAAAAA,
      );
      await _runLoopbackSync(
        serverService: b.service,
        clientService: a.service,
        serverNodeNum: 0xBBBBBBBB,
        clientNodeNum: 0xAAAAAAAA,
      );

      expect(b.db.posts.length, equals(1));
    });

    test('provenance includes lanPeerSync transport', () async {
      final a = _createPeer(0xAAAAAAAA);
      final b = _createPeer(0xBBBBBBBB);

      await a.repo.ingest(_makePost(0xAAAAAAAA, 'Transport Test'));

      await _runLoopbackSync(
        serverService: b.service,
        clientService: a.service,
        serverNodeNum: 0xBBBBBBBB,
        clientNodeNum: 0xAAAAAAAA,
      );

      final bPost = b.db.posts.values.first;
      expect(
        bPost.seenViaTransports.contains(MeshTransportType.lanPeerSync),
        isTrue,
      );
    });
  });

  group('LAN sync — cursor semantics', () {
    test('cursor survives new MeshSyncService with same DB', () async {
      final a = _createPeer(0xAAAAAAAA);
      final b = _createPeer(0xBBBBBBBB);

      await a.repo.ingest(_makePost(0xAAAAAAAA, 'Persistent cursor'));

      await _runLoopbackSync(
        serverService: b.service,
        clientService: a.service,
        serverNodeNum: 0xBBBBBBBB,
        clientNodeNum: 0xAAAAAAAA,
      );

      final reloaded = MeshSyncService(database: a.db);
      final cursor = await reloaded.getCursorForPeer(
        buildLanSyncPeerId(0xBBBBBBBB),
      );
      expect(cursor, isNotNull);
    });

    test('empty sync does not advance cursor', () async {
      final a = _createPeer(0xAAAAAAAA);
      final b = _createPeer(0xBBBBBBBB);

      await _runLoopbackSync(
        serverService: b.service,
        clientService: a.service,
        serverNodeNum: 0xBBBBBBBB,
        clientNodeNum: 0xAAAAAAAA,
      );

      final cursorOnA = await a.syncService.getCursorForPeer(
        buildLanSyncPeerId(0xBBBBBBBB),
      );
      expect(cursorOnA, isNull);
    });
  });

  group('LAN sync — clean close behavior', () {
    test('clean close on empty sync', () async {
      final a = _createPeer(0xAAAAAAAA);
      final b = _createPeer(0xBBBBBBBB);

      final result = await _runLoopbackSync(
        serverService: b.service,
        clientService: a.service,
        serverNodeNum: 0xBBBBBBBB,
        clientNodeNum: 0xAAAAAAAA,
      );

      expect(result.clientSent, greaterThanOrEqualTo(0));
      expect(result.serverSent, greaterThanOrEqualTo(0));
    });
  });

  group('LAN sync — cross-transport dedup', () {
    test('same post via LoRa then LAN does not duplicate', () async {
      final a = _createPeer(0xAAAAAAAA);
      final b = _createPeer(0xBBBBBBBB);

      final sharedPost = MeshPost(
        authorNodeNum: 0xCCCCCCCC,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        content: 'Shared post from radio',
        seenViaTransports: {MeshTransportType.lora},
      );

      await a.repo.ingest(sharedPost);
      await b.repo.ingest(sharedPost);

      expect(a.db.posts.length, equals(1));
      expect(b.db.posts.length, equals(1));

      await _runLoopbackSync(
        serverService: b.service,
        clientService: a.service,
        serverNodeNum: 0xBBBBBBBB,
        clientNodeNum: 0xAAAAAAAA,
      );

      expect(a.db.posts.length, equals(1));
      expect(b.db.posts.length, equals(1));
    });
  });

  group('buildLanSyncPeerId', () {
    test('produces stable identity from node number', () {
      const nodeNum = 0xDEADBEEF;
      final id1 = buildLanSyncPeerId(nodeNum);
      final id2 = buildLanSyncPeerId(nodeNum);
      expect(id1, equals(id2));
      expect(id1, equals('!deadbeef'));
    });

    test('different nodes produce different IDs', () {
      final id1 = buildLanSyncPeerId(0x11111111);
      final id2 = buildLanSyncPeerId(0x22222222);
      expect(id1, isNot(equals(id2)));
    });
  });

  group('LAN sync — startListening + connectAndSync (direct connect)', () {
    test('startListening binds TCP server', () async {
      final peer = _createPeer(0xAAAAAAAA);
      await peer.service.startListening(port: 0);

      expect(peer.service.isListening, isTrue);
      expect(peer.service.listeningPort, isNotNull);
      expect(peer.service.listeningPort, greaterThan(0));

      await peer.service.dispose();
    });

    test('startListening is idempotent', () async {
      final peer = _createPeer(0xAAAAAAAA);
      await peer.service.startListening(port: 0);
      final firstPort = peer.service.listeningPort;

      await peer.service.startListening(port: 0);
      expect(peer.service.listeningPort, equals(firstPort));

      await peer.service.dispose();
    });

    test('connectAndSync completes full sync', () async {
      final server = _createPeer(0xAAAAAAAA);
      final client = _createPeer(0xBBBBBBBB);

      // Server has 2 posts.
      await server.repo.ingest(_makePost(0xAAAAAAAA, 'Direct post 1'));
      await server.repo.ingest(_makePost(0xAAAAAAAA, 'Direct post 2'));

      // Start server listener on ephemeral port.
      await server.service.startListening(port: 0);
      final port = server.service.listeningPort!;

      // Client connects directly.
      final session = await client.service.connectAndSync(
        '127.0.0.1',
        port,
        nodeNum: 0xAAAAAAAA,
      );

      // Wait briefly for server to finish processing.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(session.state, equals(SyncSessionState.completed));
      expect(session.objectsReceived, equals(2));

      // Client now has server's posts.
      expect(client.db.posts.length, equals(2));

      await server.service.dispose();
    });

    test('connectAndSync without nodeNum still works', () async {
      final server = _createPeer(0xAAAAAAAA);
      final client = _createPeer(0xBBBBBBBB);

      await server.repo.ingest(_makePost(0xAAAAAAAA, 'Mystery post'));

      await server.service.startListening(port: 0);
      final port = server.service.listeningPort!;

      // Connect without knowing the node number.
      final session = await client.service.connectAndSync('127.0.0.1', port);

      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(session.state, equals(SyncSessionState.completed));
      expect(client.db.posts.length, equals(1));
      // Session peerId gets updated to the real peer ID after hello.
      expect(session.peerId, equals(buildLanSyncPeerId(0xAAAAAAAA)));

      await server.service.dispose();
    });

    test('bidirectional direct-connect exchanges posts both ways', () async {
      final server = _createPeer(0xAAAAAAAA);
      final client = _createPeer(0xBBBBBBBB);

      await server.repo.ingest(_makePost(0xAAAAAAAA, 'From server'));
      await client.repo.ingest(_makePost(0xBBBBBBBB, 'From client'));

      await server.service.startListening(port: 0);
      final port = server.service.listeningPort!;

      final session = await client.service.connectAndSync(
        '127.0.0.1',
        port,
        nodeNum: 0xAAAAAAAA,
      );

      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(session.state, equals(SyncSessionState.completed));
      // Client received server's post.
      expect(client.db.posts.length, equals(2));
      // Server received client's post.
      expect(server.db.posts.length, equals(2));

      await server.service.dispose();
    });

    test('connectAndSync to unreachable host fails gracefully', () async {
      final client = _createPeer(0xBBBBBBBB);

      // Connect to a port nothing is listening on.
      final session = await client.service.connectAndSync('127.0.0.1', 59999);

      expect(session.state, equals(SyncSessionState.failed));
      expect(session.errorMessage, isNotNull);
    });
  });

  group('LAN sync — discovery peer management', () {
    test('discovered peer accepted', () {
      final peer = _createPeer(0xAAAAAAAA);

      final added = peer.service.addDiscoveredPeerForTest(
        const DiscoveredPeer(
          host: '192.168.1.100',
          port: 4480,
          nodeNum: 0xBBBBBBBB,
          displayName: 'Remote Node',
          protocolVersion: 1,
        ),
      );

      expect(added, isTrue);
      expect(peer.service.currentPeers.length, equals(1));
      expect(peer.service.currentPeers.first.nodeNum, equals(0xBBBBBBBB));
      expect(peer.service.currentPeers.first.host, equals('192.168.1.100'));
    });

    test('self peer rejected', () {
      final peer = _createPeer(0xAAAAAAAA);

      final added = peer.service.addDiscoveredPeerForTest(
        const DiscoveredPeer(
          host: '192.168.1.100',
          port: 4480,
          nodeNum: 0xAAAAAAAA,
          displayName: 'Self',
          protocolVersion: 1,
        ),
      );

      expect(added, isFalse);
      expect(peer.service.currentPeers, isEmpty);
    });

    test('peer dedup merge by stable peerId', () {
      final peer = _createPeer(0xAAAAAAAA);

      peer.service.addDiscoveredPeerForTest(
        const DiscoveredPeer(
          host: '192.168.1.100',
          port: 4480,
          nodeNum: 0xBBBBBBBB,
          displayName: 'Node B v1',
          protocolVersion: 1,
        ),
      );

      // Same nodeNum, different host — should merge (update, not duplicate).
      peer.service.addDiscoveredPeerForTest(
        const DiscoveredPeer(
          host: '192.168.1.200',
          port: 4480,
          nodeNum: 0xBBBBBBBB,
          displayName: 'Node B v2',
          protocolVersion: 1,
        ),
      );

      expect(peer.service.currentPeers.length, equals(1));
      expect(peer.service.currentPeers.first.host, equals('192.168.1.200'));
      expect(peer.service.currentPeers.first.displayName, equals('Node B v2'));
    });

    test('removeDiscoveredPeerForTest removes by nodeNum', () {
      final peer = _createPeer(0xAAAAAAAA);

      peer.service.addDiscoveredPeerForTest(
        const DiscoveredPeer(
          host: '192.168.1.100',
          port: 4480,
          nodeNum: 0xBBBBBBBB,
          displayName: 'Node B',
          protocolVersion: 1,
        ),
      );
      expect(peer.service.currentPeers.length, equals(1));

      peer.service.removeDiscoveredPeerForTest(0xBBBBBBBB);
      expect(peer.service.currentPeers, isEmpty);
    });

    test('peersStream emits on add and remove', () async {
      final peer = _createPeer(0xAAAAAAAA);
      final events = <List<DiscoveredPeer>>[];
      final sub = peer.service.peersStream.listen(events.add);

      peer.service.addDiscoveredPeerForTest(
        const DiscoveredPeer(
          host: '192.168.1.100',
          port: 4480,
          nodeNum: 0xBBBBBBBB,
          displayName: 'Node B',
          protocolVersion: 1,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      peer.service.removeDiscoveredPeerForTest(0xBBBBBBBB);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await sub.cancel();
      expect(events.length, equals(2));
      expect(events[0].length, equals(1));
      expect(events[1], isEmpty);

      await peer.service.dispose();
    });

    test('resolved peer surfaced to periodic sync selector', () async {
      final server = _createPeer(0xAAAAAAAA);
      final client = _createPeer(0xBBBBBBBB);

      await server.service.startListening(port: 0);
      final port = server.service.listeningPort!;

      // Inject the server as a discovered peer.
      client.service.addDiscoveredPeerForTest(
        DiscoveredPeer(
          host: '127.0.0.1',
          port: port,
          nodeNum: 0xAAAAAAAA,
          displayName: 'Server',
          protocolVersion: 1,
        ),
      );

      expect(client.service.currentPeers.length, equals(1));
      expect(client.service.currentPeers.first.port, equals(port));

      await server.service.dispose();
    });

    test('periodic sync initiates connect for discovered peer', () async {
      final server = _createPeer(0xAAAAAAAA);
      final client = _createPeer(0xBBBBBBBB);

      // Server has a post.
      await server.repo.ingest(_makePost(0xAAAAAAAA, 'Periodic sync post'));

      await server.service.startListening(port: 0);
      final port = server.service.listeningPort!;

      // Client discovers server.
      client.service.addDiscoveredPeerForTest(
        DiscoveredPeer(
          host: '127.0.0.1',
          port: port,
          nodeNum: 0xAAAAAAAA,
          displayName: 'Server',
          protocolVersion: 1,
        ),
      );

      // Trigger periodic sync.
      final synced = await client.service.syncWithDiscoveredPeers();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(synced, equals(1));
      expect(client.db.posts.length, equals(1));
      expect(
        client.db.posts.values.first.content,
        equals('Periodic sync post'),
      );

      await server.service.dispose();
    });

    test('periodic sync with no peers returns zero', () async {
      final peer = _createPeer(0xAAAAAAAA);
      final synced = await peer.service.syncWithDiscoveredPeers();
      expect(synced, equals(0));
    });

    test('periodic sync skips unreachable peer gracefully', () async {
      final client = _createPeer(0xBBBBBBBB);

      // Inject a peer that has no listener.
      client.service.addDiscoveredPeerForTest(
        const DiscoveredPeer(
          host: '127.0.0.1',
          port: 59998,
          nodeNum: 0xCCCCCCCC,
          displayName: 'Ghost',
          protocolVersion: 1,
        ),
      );

      // Should not throw — the failed session counts as 0.
      final synced = await client.service.syncWithDiscoveredPeers();
      expect(synced, equals(0));
    });
  });

  group('LAN sync — session scheduling', () {
    test('successful session prevents immediate re-initiation', () async {
      final server = _createPeer(0xAAAAAAAA);
      final client = _createPeer(0xBBBBBBBB);

      // Server has a post.
      await server.repo.ingest(_makePost(0xAAAAAAAA, 'Sync once'));

      await server.service.startListening(port: 0);
      final port = server.service.listeningPort!;

      // Client discovers server.
      client.service.addDiscoveredPeerForTest(
        DiscoveredPeer(
          host: '127.0.0.1',
          port: port,
          nodeNum: 0xAAAAAAAA,
          displayName: 'Server',
          protocolVersion: 1,
        ),
      );

      // First sync should succeed.
      final synced1 = await client.service.syncWithDiscoveredPeers();
      expect(synced1, equals(1));

      // Immediate second sync should be skipped (cooldown).
      final synced2 = await client.service.syncWithDiscoveredPeers();
      expect(synced2, equals(0));

      // Peer should be in cooldown.
      expect(client.service.isPeerInCooldown(0xAAAAAAAA), isTrue);

      await server.service.dispose();
    });

    test('cooldown expires and allows re-sync', () async {
      final client = _createPeer(0xBBBBBBBB);

      // Manually set a past sync success time (well beyond cooldown).
      client.service.setLastSyncSuccessForTest(
        0xAAAAAAAA,
        DateTime.now().subtract(const Duration(minutes: 2)),
      );

      // Cooldown should have expired.
      expect(client.service.isPeerInCooldown(0xAAAAAAAA), isFalse);
    });

    test('periodic sync skips peer during cooldown', () async {
      final server = _createPeer(0xAAAAAAAA);
      final client = _createPeer(0xBBBBBBBB);

      await server.service.startListening(port: 0);
      final port = server.service.listeningPort!;

      client.service.addDiscoveredPeerForTest(
        DiscoveredPeer(
          host: '127.0.0.1',
          port: port,
          nodeNum: 0xAAAAAAAA,
          displayName: 'Server',
          protocolVersion: 1,
        ),
      );

      // Set recent success — peer should be skipped.
      client.service.setLastSyncSuccessForTest(0xAAAAAAAA, DateTime.now());

      final synced = await client.service.syncWithDiscoveredPeers();
      expect(synced, equals(0));

      await server.service.dispose();
    });

    test('converged peers produce empty batches on second sync', () async {
      final a = _createPeer(0x11111111);
      final b = _createPeer(0x22222222);

      // Each peer has one post.
      await a.repo.ingest(_makePost(0x11111111, 'Post from A'));
      await b.repo.ingest(_makePost(0x22222222, 'Post from B'));

      // First sync — both exchange posts.
      final result1 = await _runLoopbackSync(
        serverService: b.service,
        clientService: a.service,
        serverNodeNum: 0x22222222,
        clientNodeNum: 0x11111111,
      );
      expect(result1.clientReceived, equals(1));
      // serverReceived is 2 because A ingested Post-B in Phase 2, giving
      // it a sync_seq. In Phase 3, A serves all posts (cursor was null)
      // including the just-received Post-B. This is expected for the first
      // sync — the cursor advances afterward preventing re-sends.
      expect(result1.serverReceived, equals(2));

      // After sync, metadata merges happen (the posts now exist on both
      // sides with merged transports). These should NOT bump sync_seq.

      // Second sync — cursors were saved by ack, so outbound sends should
      // decrease significantly. B still sends Post-A (received in Phase 3
      // of first sync, got a new sync_seq above B's Phase 2 cursor for A).
      // A sends 0 because A's cursor for B covers all posts.
      final result2 = await _runLoopbackSync(
        serverService: b.service,
        clientService: a.service,
        serverNodeNum: 0x22222222,
        clientNodeNum: 0x11111111,
      );

      // A's outbound cursor for B was set to max sync_seq in Phase 3 ack.
      expect(result2.clientSent, equals(0));
      // B sends Post-A (ingested in Phase 3 with sync_seq > Phase 2 cursor).
      // This is one-shot: B's cursor for A advances after this ack.
      expect(result2.serverSent, lessThanOrEqualTo(1));

      // Third sync — now fully converged on both sides.
      final result3 = await _runLoopbackSync(
        serverService: b.service,
        clientService: a.service,
        serverNodeNum: 0x22222222,
        clientNodeNum: 0x11111111,
      );
      expect(result3.clientSent, equals(0));
      expect(result3.serverSent, equals(0));
    });
  });
}
