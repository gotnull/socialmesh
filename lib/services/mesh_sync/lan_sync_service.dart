// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// LAN peer sync service — direct TCP connect for mesh feed sync, with
/// optional mDNS discovery.
///
/// First-cut mode uses direct connect only: [startListening] + [connectAndSync].
/// mDNS discovery can be enabled later via [startAdvertising] + [startDiscovery]
/// without changing the sync protocol or provider graph.
///
/// Wire protocol over TCP is line-delimited JSON. Each line is a JSON
/// message with a `type` field. See [lan_sync_protocol.dart] for the
/// protocol v1 message definitions and flow.
///
/// Sync wiring:
///   - Outbound batches come from [MeshSyncService.getPostsForPeer]
///   - Inbound posts go through [MeshFeedRepository.ingest]
///   - Cursors advance only on [MeshSyncService.acknowledgeSyncBatch]
///   - Peer identity uses stable `!{nodeHex}` format (not `host:port`)
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../core/logging.dart';
import '../mesh_feed/mesh_feed_repository.dart';
import '../mesh_feed/mesh_post.dart';
import '../mesh_feed/mesh_sync_service.dart';
import 'lan_sync_protocol.dart';
import 'mesh_sync_session.dart';

/// LAN peer sync service — TCP direct-connect + optional mDNS discovery.
///
/// Two operating modes (not mutually exclusive):
///
///   **Direct connect** (first-cut, minimal risk):
///     1. [startListening] — bind TCP server for incoming sync connections
///     2. [connectAndSync] — connect to a known peer by host:port
///
///   **mDNS discovery** (optional, added later):
///     1. [startAdvertising] — mDNS broadcast + TCP listener
///     2. [startDiscovery]   — scan for peers via mDNS
///     3. [syncWithPeer]     — sync with a discovered [DiscoveredPeer]
///
/// All sync operations are wired through [MeshSyncService] for cursor
/// management and [MeshFeedRepository] for post ingest. This ensures
/// deterministic dedup, replay protection, and consistent cursor semantics.
///
/// Feature-flagged via `MESH_FEED_ENABLED` + `OPPORTUNISTIC_SYNC_ENABLED`.
class LanSyncService {
  LanSyncService({
    required this.localNodeNum,
    required this.localDisplayName,
    required MeshFeedRepository feedRepository,
    required this._syncService,
  }) : _feedRepo = feedRepository,
       _localPeerId = buildLanSyncPeerId(localNodeNum);

  /// Local mesh node number — identifies this peer.
  final int localNodeNum;

  /// Local display name for mDNS announcements.
  final String localDisplayName;

  final MeshFeedRepository _feedRepo;
  final MeshSyncService _syncService;

  /// Stable peer ID for this local node.
  final String _localPeerId;

  BonsoirBroadcast? _broadcast;
  StreamSubscription<BonsoirBroadcastEvent>? _broadcastSubscription;
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _discoverySubscription;
  ServerSocket? _server;

  final _peers = <String, DiscoveredPeer>{};
  final _peerController = StreamController<List<DiscoveredPeer>>.broadcast();
  final _sessionController = StreamController<MeshSyncSession>.broadcast();

  /// Tracks the last successful sync completion time per peer ID.
  /// Used to enforce cooldown between periodic sync attempts.
  final _lastSyncSuccess = <String, DateTime>{};

  /// Tracks peers with an active (in-progress) outbound sync session.
  /// Prevents overlapping sessions to the same peer.
  final _activeSessions = <String>{};

  /// Minimum interval between successful outbound syncs to the same peer.
  @visibleForTesting
  static const syncCooldown = Duration(seconds: 45);

  /// Stream of discovered sync peers.
  Stream<List<DiscoveredPeer>> get peersStream => _peerController.stream;

  /// Stream of sync session state changes.
  Stream<MeshSyncSession> get sessionStream => _sessionController.stream;

  /// Currently discovered peers.
  List<DiscoveredPeer> get currentPeers => _peers.values.toList();

  // -------------------------------------------------------------------------
  // Direct connect — TCP listener + outbound connect (no mDNS)
  // -------------------------------------------------------------------------

  /// Whether the TCP listener is active.
  bool get isListening => _server != null;

  /// The port the TCP listener is bound to, or `null` if not listening.
  int? get listeningPort => _server?.port;

  /// Start listening for incoming sync connections on [port].
  ///
  /// This binds a TCP server only — no mDNS advertisement. Peers must
  /// know the host:port to connect directly via [connectAndSync].
  ///
  /// Safe to call multiple times — subsequent calls are no-ops.
  Future<void> startListening({int port = lanSyncDefaultPort}) async {
    if (_server != null) return;

    _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    _server!.listen(_handleIncomingConnection);

    AppLogging.meshFeed(
      'LAN-SYNC: listening on port ${_server!.port} '
      '(node=$localNodeNum)',
    );
  }

  /// Connect directly to a peer at [host]:[port] and run a full sync.
  ///
  /// This is the preferred path for the first cut — no mDNS discovery
  /// needed. The peer must be listening via [startListening].
  ///
  /// [nodeNum] is optional — if unknown, the hello exchange will reveal
  /// the remote peer's identity. Providing it enables a stable initial
  /// session peer ID.
  Future<MeshSyncSession> connectAndSync(
    String host,
    int port, {
    int? nodeNum,
  }) async {
    final initialPeerId = nodeNum != null
        ? buildLanSyncPeerId(nodeNum)
        : '$host:$port';

    AppLogging.meshFeed(
      'LAN-SYNC: direct-connect to $host:$port '
      '(peerId=$initialPeerId)',
    );

    final session = MeshSyncSession(
      peerId: initialPeerId,
      peerNodeNum: nodeNum ?? 0,
      transport: MeshTransportType.lanPeerSync,
    );
    _emitSession(session);
    _activeSessions.add(initialPeerId);

    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: lanSyncSessionTimeout,
      );

      await _performSync(socket, session, isInitiator: true);
      socket.destroy();

      if (session.state == SyncSessionState.completed) {
        _lastSyncSuccess[session.peerId] = DateTime.now();
      }
    } catch (e) {
      if (session.state != SyncSessionState.failed) {
        session.state = SyncSessionState.failed;
        session.errorMessage = e.toString();
      }
      AppLogging.meshFeed(
        'LAN-SYNC: direct-connect FAILED with $host:$port \u2014 $e',
      );
    } finally {
      _activeSessions.remove(initialPeerId);
      // Also remove the resolved peerId if it changed during hello.
      if (session.peerId != initialPeerId) {
        _activeSessions.remove(session.peerId);
      }
    }

    _emitSession(session);
    return session;
  }

  // -------------------------------------------------------------------------
  // mDNS advertising + discovery (optional — adds Bonsoir dependency)
  // -------------------------------------------------------------------------

  /// Start advertising this device as available for sync via mDNS.
  ///
  /// Also starts the TCP listener if not already started.
  /// Peers discovered via mDNS can be synced with [syncWithPeer].
  Future<void> startAdvertising() async {
    if (_broadcast != null) return;

    // Ensure TCP listener is running.
    await startListening();

    final service = BonsoirService(
      name: 'sm-${localNodeNum.toRadixString(16)}',
      type: lanSyncServiceType,
      port: _server!.port,
      attributes: {
        'nodeNum': localNodeNum.toString(),
        'name': localDisplayName,
        'v': '$lanSyncProtocolVersion',
      },
    );

    _broadcast = BonsoirBroadcast(service: service);
    await _broadcast!.initialize();

    // Monitor broadcast registration events. onError catches native
    // DNSServiceRef failures (e.g. -65569 DefunctConnection on network
    // teardown) that would otherwise bubble to PlatformDispatcher.onError.
    // Crashlytics [F bonsoir-broadcast].
    _broadcastSubscription = _broadcast!.eventStream?.listen(
      (event) {
        switch (event) {
          case BonsoirBroadcastStartedEvent():
            AppLogging.meshFeed(
              'LAN-SYNC: broadcast REGISTERED on ${service.type} '
              'port=${service.port}',
            );
          case BonsoirBroadcastNameAlreadyExistsEvent():
            AppLogging.meshFeed(
              'LAN-SYNC: broadcast name collision: '
              'renamed to ${event.service.name}',
            );
          case BonsoirBroadcastStoppedEvent():
            AppLogging.meshFeed('LAN-SYNC: broadcast STOPPED');
          default:
            AppLogging.meshFeed(
              'LAN-SYNC: broadcast event: ${event.runtimeType}',
            );
        }
      },
      onError: (Object e, StackTrace st) {
        AppLogging.meshFeed(
          '[F bonsoir-broadcast] broadcast stream error '
          '(likely network change / DefunctConnection): $e',
        );
      },
    );

    await _broadcast!.start();

    AppLogging.meshFeed(
      'LAN-SYNC: advertising on port ${_server!.port} '
      'as ${service.name} (node=$localNodeNum)',
    );
  }

  /// Start discovering peers on the local network.
  Future<void> startDiscovery() async {
    if (_discovery != null) return;

    _discovery = BonsoirDiscovery(type: lanSyncServiceType);
    await _discovery!.initialize();
    await _discovery!.start();

    // onError catches native DNSServiceRef failures so they do not bubble
    // to PlatformDispatcher.onError. Crashlytics [F bonsoir-lansync].
    _discoverySubscription = _discovery!.eventStream?.listen(
      (event) {
        switch (event) {
          case BonsoirDiscoveryStartedEvent():
            AppLogging.meshFeed(
              'LAN-SYNC: discovery browse ACTIVE for $lanSyncServiceType',
            );
          case BonsoirDiscoveryServiceFoundEvent():
            _onPeerFound(event.service);
          case BonsoirDiscoveryServiceResolvedEvent():
            _onPeerResolved(event.service);
          case BonsoirDiscoveryServiceResolveFailedEvent():
            AppLogging.meshFeed('LAN-SYNC: service resolve FAILED');
          case BonsoirDiscoveryServiceLostEvent():
            _onPeerLost(event.service);
          case BonsoirDiscoveryStoppedEvent():
            AppLogging.meshFeed('LAN-SYNC: discovery STOPPED');
          default:
            AppLogging.meshFeed(
              'LAN-SYNC: discovery event: ${event.runtimeType}',
            );
        }
      },
      onError: (Object e, StackTrace st) {
        AppLogging.meshFeed(
          '[F bonsoir-lansync] discovery stream error '
          '(likely network change / DefunctConnection): $e',
        );
      },
    );

    AppLogging.meshFeed('LAN-SYNC: discovery started for $lanSyncServiceType');
  }

  void _onPeerFound(BonsoirService service) {
    AppLogging.meshFeed(
      'LAN-SYNC: service FOUND: ${service.name} '
      '(host=${service.hostAddress} port=${service.port})',
    );

    // Trigger resolution to obtain host/port/attributes.
    if (_discovery != null) {
      service.resolve(_discovery!.serviceResolver).catchError((Object e) {
        AppLogging.meshFeed(
          'LAN-SYNC: resolve request FAILED for ${service.name}: $e',
        );
      });
    }
  }

  void _onPeerResolved(BonsoirService service) {
    final host = service.hostAddress;
    final port = service.port;

    AppLogging.meshFeed(
      'LAN-SYNC: service RESOLVED: ${service.name} '
      'host=$host port=$port attrs=${service.attributes}',
    );

    if (host == null || host.isEmpty) {
      AppLogging.meshFeed('LAN-SYNC: REJECTED \u2014 no host');
      return;
    }

    final nodeNumStr = service.attributes['nodeNum'];
    if (nodeNumStr == null) {
      AppLogging.meshFeed('LAN-SYNC: REJECTED \u2014 no nodeNum attribute');
      return;
    }

    final nodeNum = int.tryParse(nodeNumStr);
    if (nodeNum == null) {
      AppLogging.meshFeed(
        'LAN-SYNC: REJECTED \u2014 invalid nodeNum: $nodeNumStr',
      );
      return;
    }

    if (nodeNum == localNodeNum) {
      AppLogging.meshFeed(
        'LAN-SYNC: REJECTED \u2014 self-peer (node=$nodeNum)',
      );
      return;
    }

    final peerId = buildLanSyncPeerId(nodeNum);
    _peers[peerId] = DiscoveredPeer(
      host: host,
      port: port,
      nodeNum: nodeNum,
      displayName: service.attributes['name'] ?? '',
      protocolVersion: int.tryParse(service.attributes['v'] ?? '1') ?? 1,
    );

    _emitPeers();
    AppLogging.meshFeed(
      'LAN-SYNC: peer ACCEPTED: $peerId at $host:$port '
      '(name=${service.attributes['name']} peers=${_peers.length})',
    );
  }

  void _onPeerLost(BonsoirService service) {
    // Prefer matching by nodeNum (stable key).
    final nodeNumStr = service.attributes['nodeNum'];
    if (nodeNumStr != null) {
      final nodeNum = int.tryParse(nodeNumStr);
      if (nodeNum != null) {
        final peerId = buildLanSyncPeerId(nodeNum);
        _peers.remove(peerId);
        _emitPeers();
        AppLogging.meshFeed(
          'LAN-SYNC: peer LOST: $peerId (${service.name}) '
          'peers=${_peers.length}',
        );
        return;
      }
    }

    // Fallback: match by service name in displayName.
    final removed = _peers.entries
        .where((e) => e.value.displayName == service.name)
        .map((e) => e.key)
        .toList();
    for (final key in removed) {
      _peers.remove(key);
    }
    if (removed.isNotEmpty) _emitPeers();
    AppLogging.meshFeed(
      'LAN-SYNC: peer LOST (fallback): ${service.name} '
      'peers=${_peers.length}',
    );
  }

  void _emitPeers() {
    if (!_peerController.isClosed) {
      _peerController.add(currentPeers);
    }
  }

  // -------------------------------------------------------------------------
  // Sync initiation + incoming connections
  // -------------------------------------------------------------------------

  /// Initiate a sync session with a discovered peer.
  Future<MeshSyncSession> syncWithPeer(DiscoveredPeer peer) async {
    final remotePeerId = buildLanSyncPeerId(peer.nodeNum);
    AppLogging.meshFeed(
      'LAN-SYNC: initiating sync with ${peer.host}:${peer.port} '
      '(peerId=$remotePeerId name=${peer.displayName})',
    );

    final session = MeshSyncSession(
      peerId: remotePeerId,
      peerNodeNum: peer.nodeNum,
      transport: MeshTransportType.lanPeerSync,
      peerDisplayName: peer.displayName,
    );
    _emitSession(session);

    try {
      final socket = await Socket.connect(
        peer.host,
        peer.port,
        timeout: lanSyncSessionTimeout,
      );

      await _performSync(socket, session, isInitiator: true);
      socket.destroy();
    } catch (e) {
      if (session.state != SyncSessionState.failed) {
        session.state = SyncSessionState.failed;
        session.errorMessage = e.toString();
      }
      AppLogging.meshFeed('LAN-SYNC: sync FAILED with $remotePeerId \u2014 $e');
    }

    _emitSession(session);
    return session;
  }

  Future<void> _handleIncomingConnection(Socket socket) async {
    final peerAddr = socket.remoteAddress.address;
    AppLogging.meshFeed('LAN-SYNC: incoming connection from $peerAddr');

    final session = MeshSyncSession(
      peerId: peerAddr,
      peerNodeNum: 0,
      transport: MeshTransportType.lanPeerSync,
    );
    _emitSession(session);

    try {
      await _performSync(socket, session, isInitiator: false);
    } catch (e) {
      if (session.state != SyncSessionState.failed) {
        session.state = SyncSessionState.failed;
        session.errorMessage = e.toString();
      }
    }

    socket.destroy();
    _emitSession(session);
  }

  // -------------------------------------------------------------------------
  // Sync protocol engine
  // -------------------------------------------------------------------------

  Future<void> _performSync(
    Socket socket,
    MeshSyncSession session, {
    required bool isInitiator,
  }) async {
    final role = isInitiator ? 'INITIATOR' : 'RESPONDER';
    AppLogging.meshFeed(
      'LAN-SYNC: [$role] starting sync with peer=${session.peerId}',
    );

    session.state = SyncSessionState.connecting;
    _emitSession(session);

    final channel = _SyncChannel(socket);

    try {
      // Phase 1: Hello exchange
      final remotePeerId = await _exchangeHello(
        channel,
        session,
        isInitiator: isInitiator,
      );

      session.state = SyncSessionState.transferring;
      _emitSession(session);

      // Phase 2: Initiator pulls from responder
      if (isInitiator) {
        await _pullFromPeer(channel, session, remotePeerId, role);
      } else {
        await _servePeer(channel, session, remotePeerId, role);
      }

      // Phase 3: Responder pulls from initiator
      if (isInitiator) {
        await _servePeer(channel, session, remotePeerId, role);
      } else {
        await _pullFromPeer(channel, session, remotePeerId, role);
      }

      // Phase 4: Close
      if (isInitiator) {
        channel.send(const LanSyncClose());
      } else {
        final msg = await channel.receive();
        if (msg is! LanSyncClose) {
          AppLogging.meshFeed(
            'LAN-SYNC: [$role] expected close, got ${msg?.type}',
          );
        }
      }

      session.state = SyncSessionState.completed;
      AppLogging.meshFeed(
        'LAN-SYNC: [$role] session complete \u2014 '
        'sent=${session.objectsSent} received=${session.objectsReceived}',
      );
    } on _SyncProtocolException catch (e) {
      session.state = SyncSessionState.failed;
      session.errorMessage = e.message;
      try {
        channel.send(LanSyncError(message: e.message, code: e.code));
      } catch (_) {}
      AppLogging.meshFeed('LAN-SYNC: [$role] protocol error: ${e.message}');
    } on TimeoutException {
      session.state = SyncSessionState.failed;
      session.errorMessage = 'Session timeout';
      AppLogging.meshFeed('LAN-SYNC: [$role] session timeout');
    } finally {
      await channel.cancel();
    }
  }

  /// Exchange hello messages, validate version, register peer, return remote
  /// peer ID.
  Future<String> _exchangeHello(
    _SyncChannel channel,
    MeshSyncSession session, {
    required bool isInitiator,
  }) async {
    final localHello = LanSyncHello(
      protocolVersion: lanSyncProtocolVersion,
      peerId: _localPeerId,
      nodeNum: localNodeNum,
      displayName: localDisplayName,
    );

    session.state = SyncSessionState.negotiating;
    _emitSession(session);

    LanSyncHello remoteHello;

    if (isInitiator) {
      channel.send(localHello);
      final msg = await channel.receive();
      if (msg is LanSyncError) {
        throw _SyncProtocolException(msg.message, code: msg.code);
      }
      if (msg is! LanSyncHello) {
        throw _SyncProtocolException(
          'Expected hello, got ${msg?.type}',
          code: 'unexpected_message',
        );
      }
      remoteHello = msg;
    } else {
      final msg = await channel.receive();
      if (msg is LanSyncError) {
        throw _SyncProtocolException(msg.message, code: msg.code);
      }
      if (msg is! LanSyncHello) {
        throw _SyncProtocolException(
          'Expected hello, got ${msg?.type}',
          code: 'unexpected_message',
        );
      }
      remoteHello = msg;
      channel.send(localHello);
    }

    // Validate protocol version.
    if (remoteHello.protocolVersion != lanSyncProtocolVersion) {
      throw _SyncProtocolException(
        'Version mismatch: local=$lanSyncProtocolVersion '
        'remote=${remoteHello.protocolVersion}',
        code: 'version_mismatch',
      );
    }

    // Validate peer identity.
    if (remoteHello.peerId.isEmpty || remoteHello.nodeNum == 0) {
      throw _SyncProtocolException(
        'Invalid peer identity',
        code: 'invalid_peer',
      );
    }

    // Update session with stable peer info.
    session
      ..peerId = remoteHello.peerId
      ..peerDisplayName = remoteHello.displayName;

    // Register peer for cursor tracking.
    await _syncService.registerPeer(
      peerId: remoteHello.peerId,
      transport: MeshTransportType.lanPeerSync,
      displayName: remoteHello.displayName,
    );

    AppLogging.meshFeed(
      'LAN-SYNC: hello OK \u2014 remote=${remoteHello.peerId} '
      'node=${remoteHello.nodeNum} name=${remoteHello.displayName}',
    );

    return remoteHello.peerId;
  }

  /// Pull posts from the remote peer: send syncRequest, receive batches,
  /// ingest, and send acks.
  Future<void> _pullFromPeer(
    _SyncChannel channel,
    MeshSyncSession session,
    String remotePeerId,
    String role,
  ) async {
    channel.send(
      LanSyncRequest(
        requesterPeerId: _localPeerId,
        maxBatchSize: LanSyncHello.defaultBatchSize,
      ),
    );

    for (var round = 0; round < maxSessionRounds; round++) {
      final msg = await channel.receive();

      if (msg is LanSyncError) {
        throw _SyncProtocolException(msg.message, code: msg.code);
      }
      if (msg is! LanSyncBatch) {
        throw _SyncProtocolException(
          'Expected syncBatch, got ${msg?.type}',
          code: 'unexpected_message',
        );
      }

      final batch = msg;
      AppLogging.meshFeed(
        'LAN-SYNC: [$role] received batch: ${batch.posts.length} posts '
        'lastSeq=${batch.lastSeqInBatch} hasMore=${batch.hasMore}',
      );

      // Ingest each post through the repository path.
      for (final postRow in batch.posts) {
        try {
          // Strip is_local from the wire — the sender's local flag must not
          // propagate to the receiver. Authorship is determined by
          // authorNodeNum at display time.
          postRow['is_local'] = 0;
          final post = MeshPost.fromRow(postRow).copyWith(
            seenViaTransports: {MeshTransportType.lanPeerSync},
            lastSeenAt: DateTime.now(),
          );
          await _feedRepo.ingest(post);
          session.objectsReceived++;
        } catch (e) {
          AppLogging.meshFeed('LAN-SYNC: [$role] failed to ingest post: $e');
        }
      }

      // Ack the batch (echo the sender's local_seq back).
      if (batch.lastSeqInBatch != null) {
        channel.send(LanSyncAck(ackedThroughSeq: batch.lastSeqInBatch!));
      }

      if (!batch.hasMore) break;
    }
  }

  /// Serve posts to the remote peer: receive syncRequest, fetch batches
  /// from MeshSyncService, send, receive acks, and advance cursor.
  Future<void> _servePeer(
    _SyncChannel channel,
    MeshSyncSession session,
    String remotePeerId,
    String role,
  ) async {
    final msg = await channel.receive();

    if (msg is LanSyncError) {
      throw _SyncProtocolException(msg.message, code: msg.code);
    }
    if (msg is! LanSyncRequest) {
      throw _SyncProtocolException(
        'Expected syncRequest, got ${msg?.type}',
        code: 'unexpected_message',
      );
    }

    final batchSize = msg.maxBatchSize.clamp(1, 50);

    for (var round = 0; round < maxSessionRounds; round++) {
      // Diagnostic: log cursor lookup before batch selection.
      final cursorBefore = await _syncService.getCursorForPeer(remotePeerId);
      AppLogging.meshFeed(
        'LAN-SYNC: [$role] outbound cursor lookup: '
        'peer=$remotePeerId cursor=${cursorBefore ?? 'none'}',
      );

      final batch = await _syncService.getPostsForPeer(
        remotePeerId,
        batchSize: batchSize,
      );

      final postRows = batch.posts.map((p) => p.toRow()).toList();

      channel.send(
        LanSyncBatch(
          posts: postRows,
          lastSeqInBatch: batch.cursorSeq,
          hasMore: batch.hasMore,
        ),
      );

      session.objectsSent += batch.posts.length;

      AppLogging.meshFeed(
        'LAN-SYNC: [$role] sent batch: ${batch.posts.length} posts '
        'lastSeq=${batch.cursorSeq} hasMore=${batch.hasMore}',
      );

      // Wait for ack before advancing cursor.
      if (batch.cursorSeq != null) {
        final ackMsg = await channel.receive();

        if (ackMsg is LanSyncError) {
          throw _SyncProtocolException(ackMsg.message, code: ackMsg.code);
        }
        if (ackMsg is! LanSyncAck) {
          throw _SyncProtocolException(
            'Expected syncAck, got ${ackMsg?.type}',
            code: 'unexpected_message',
          );
        }

        // Advance cursor only after confirmed ack.
        await _syncService.acknowledgeSyncBatch(
          remotePeerId,
          ackMsg.ackedThroughSeq,
        );

        AppLogging.meshFeed(
          'LAN-SYNC: [$role] cursor advanced for $remotePeerId '
          'to seq=${ackMsg.ackedThroughSeq}',
        );
      }

      if (!batch.hasMore) break;
    }
  }

  void _emitSession(MeshSyncSession session) {
    if (!_sessionController.isClosed) {
      _sessionController.add(session);
    }
  }

  // -------------------------------------------------------------------------
  // Periodic sync + test access
  // -------------------------------------------------------------------------

  /// Sync with all currently discovered peers via [connectAndSync].
  ///
  /// Returns the number of peers that completed sync successfully.
  /// Called by the periodic timer in the provider.
  ///
  /// Skips peers that:
  ///   - have an active outbound session already running
  ///   - completed a successful sync within [syncCooldown]
  Future<int> syncWithDiscoveredPeers() async {
    final peers = currentPeers;
    if (peers.isEmpty) {
      AppLogging.meshFeed('LAN-SYNC: periodic sync \u2014 no peers');
      return 0;
    }

    AppLogging.meshFeed(
      'LAN-SYNC: periodic sync \u2014 ${peers.length} peer(s)',
    );

    final now = DateTime.now();
    var synced = 0;
    for (final peer in peers) {
      final peerId = buildLanSyncPeerId(peer.nodeNum);

      // Skip if outbound session already running for this peer.
      if (_activeSessions.contains(peerId)) {
        AppLogging.meshFeed(
          'LAN-SYNC: skipping $peerId \u2014 session already active',
        );
        continue;
      }

      // Skip if recently synced successfully.
      final lastSuccess = _lastSyncSuccess[peerId];
      if (lastSuccess != null && now.difference(lastSuccess) < syncCooldown) {
        AppLogging.meshFeed(
          'LAN-SYNC: skipping $peerId \u2014 '
          'cooldown (${now.difference(lastSuccess).inSeconds}s ago)',
        );
        continue;
      }

      try {
        final session = await connectAndSync(
          peer.host,
          peer.port,
          nodeNum: peer.nodeNum,
        );
        if (session.state == SyncSessionState.completed) synced++;
      } catch (e) {
        AppLogging.meshFeed(
          'LAN-SYNC: periodic sync FAILED for ${peer.host}: $e',
        );
      }
    }
    return synced;
  }

  /// Add a discovered peer directly (for testing without mDNS).
  ///
  /// Returns `false` if the peer is rejected (e.g., self-peer).
  @visibleForTesting
  bool addDiscoveredPeerForTest(DiscoveredPeer peer) {
    if (peer.nodeNum == localNodeNum) return false;
    final peerId = buildLanSyncPeerId(peer.nodeNum);
    _peers[peerId] = peer;
    _emitPeers();
    return true;
  }

  /// Remove a discovered peer (for testing without mDNS).
  @visibleForTesting
  void removeDiscoveredPeerForTest(int nodeNum) {
    _peers.remove(buildLanSyncPeerId(nodeNum));
    _emitPeers();
  }

  /// Record a successful sync time for a peer (for testing cooldown).
  @visibleForTesting
  void setLastSyncSuccessForTest(int nodeNum, DateTime time) {
    _lastSyncSuccess[buildLanSyncPeerId(nodeNum)] = time;
  }

  /// Check whether a peer is currently in cooldown (for test assertions).
  @visibleForTesting
  bool isPeerInCooldown(int nodeNum) {
    final peerId = buildLanSyncPeerId(nodeNum);
    final lastSuccess = _lastSyncSuccess[peerId];
    if (lastSuccess == null) return false;
    return DateTime.now().difference(lastSuccess) < syncCooldown;
  }

  /// Run sync protocol over an already-connected socket (for testing).
  @visibleForTesting
  Future<void> performSyncDirect(
    Socket socket,
    MeshSyncSession session, {
    required bool isInitiator,
  }) => _performSync(socket, session, isInitiator: isInitiator);

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  /// Stop all services and release resources.
  Future<void> dispose() async {
    _discoverySubscription?.cancel();
    _discoverySubscription = null;
    await _discovery?.stop();
    _discovery = null;
    _broadcastSubscription?.cancel();
    _broadcastSubscription = null;
    await _broadcast?.stop();
    _broadcast = null;
    await _server?.close();
    _server = null;
    _peers.clear();
    await _peerController.close();
    await _sessionController.close();
  }
}

// ---------------------------------------------------------------------------
// Sync channel — structured I/O over line-delimited JSON
// ---------------------------------------------------------------------------

/// Wraps a [Socket] for typed message send/receive with timeout.
class _SyncChannel {
  _SyncChannel(this._socket) {
    _iterator = StreamIterator(
      _socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter()),
    );
  }

  final Socket _socket;
  late final StreamIterator<String> _iterator;

  /// Send a protocol message as a JSON line.
  void send(LanSyncMessage msg) {
    _socket.writeln(msg.toLine());
  }

  /// Receive the next protocol message with timeout.
  ///
  /// Returns `null` on unknown message types (forward compat).
  /// Throws [TimeoutException] if no message within [timeout].
  /// Throws [_SyncProtocolException] on malformed JSON.
  Future<LanSyncMessage?> receive({
    Duration timeout = lanSyncMessageTimeout,
  }) async {
    while (true) {
      final hasNext = await _iterator.moveNext().timeout(timeout);
      if (!hasNext) {
        throw _SyncProtocolException(
          'Connection closed',
          code: 'connection_closed',
        );
      }

      final line = _iterator.current;
      if (line.isEmpty) continue;

      Map<String, dynamic> parsed;
      try {
        parsed = json.decode(line) as Map<String, dynamic>;
      } catch (e) {
        throw _SyncProtocolException(
          'Malformed JSON frame',
          code: 'malformed_frame',
        );
      }

      final msg = LanSyncMessage.parse(parsed);
      if (msg == null) {
        AppLogging.meshFeed(
          'LAN-SYNC: unknown message type: ${parsed['type']}',
        );
        continue;
      }

      return msg;
    }
  }

  /// Cancel the underlying stream iterator.
  Future<void> cancel() async {
    try {
      await _iterator.cancel();
    } catch (_) {}
  }
}

// ---------------------------------------------------------------------------
// Protocol exception
// ---------------------------------------------------------------------------

class _SyncProtocolException implements Exception {
  _SyncProtocolException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'SyncProtocolException($code): $message';
}

// ---------------------------------------------------------------------------
// Discovered peer model
// ---------------------------------------------------------------------------

/// A discovered sync peer on the local network.
class DiscoveredPeer {
  const DiscoveredPeer({
    required this.host,
    required this.port,
    required this.nodeNum,
    required this.displayName,
    required this.protocolVersion,
  });

  final String host;
  final int port;
  final int nodeNum;
  final String displayName;
  final int protocolVersion;
}
