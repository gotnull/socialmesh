// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';
import 'dart:typed_data';

import '../../core/logging.dart';
import '../../generated/meshtastic/atak.pb.dart';
import 'cot_compressor.dart';
import 'cot_serializer.dart';
import 'tak_server.dart';

/// Direction of bridge traffic for monitoring.
enum TakBridgeDirection {
  /// Meshtastic mesh -> TAK client.
  meshToTak,

  /// TAK client -> Meshtastic mesh.
  takToMesh,
}

/// A bridge event for monitoring and statistics.
class TakBridgeEvent {
  final TakBridgeDirection direction;
  final int payloadBytes;
  final DateTime timestamp;
  final String? error;

  TakBridgeEvent({
    required this.direction,
    required this.payloadBytes,
    DateTime? timestamp,
    this.error,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Callback for sending a TAKPacket to the Meshtastic mesh.
typedef MeshSendCallback =
    Future<void> Function(
      Uint8List payload, {
      required int portnum,
      int? destination,
    });

/// Bidirectional bridge between Meshtastic mesh and TAK clients.
///
/// Inbound: ATAK_PLUGIN packets from mesh -> CoT XML -> TAK clients.
/// Outbound: CoT from TAK clients -> TAKPacket proto -> mesh.
class TakMeshBridge {
  /// Maximum mesh payload size.
  static const int maxMeshPayload = 237;

  /// ATAK_PLUGIN port number.
  static const int atakPortnum = 72;

  /// Minimum interval between outbound mesh packets per TAK client UID.
  static const Duration outboundRateLimit = Duration(seconds: 5);

  /// Maximum outbound mesh packets per minute (aggregate).
  static const int maxOutboundPerMinute = 4;

  /// Duplicate suppression window.
  static const Duration dedupeWindow = Duration(seconds: 30);

  /// Default stale time for position CoT events.
  static const Duration positionStaleTime = Duration(minutes: 5);

  final TakServer _server;
  final MeshSendCallback _meshSend;
  final _eventController = StreamController<TakBridgeEvent>.broadcast();
  final _recentHashes = <int, DateTime>{};
  final _lastOutboundByUid = <String, DateTime>{};
  final _outboundTimestamps = <DateTime>[];
  StreamSubscription<TakServerEvent>? _serverSubscription;
  bool _running = false;

  int _packetsInbound = 0;
  int _packetsOutbound = 0;

  TakMeshBridge({required TakServer server, required MeshSendCallback meshSend})
    : _server = server,
      _meshSend = meshSend;

  /// Stream of bridge events for monitoring.
  Stream<TakBridgeEvent> get events => _eventController.stream;

  /// Whether the bridge is running.
  bool get isRunning => _running;

  /// Total inbound packets processed.
  int get packetsInbound => _packetsInbound;

  /// Total outbound packets sent.
  int get packetsOutbound => _packetsOutbound;

  /// Starts the bridge. Subscribes to server events for outbound path.
  void start() {
    if (_running) return;
    _running = true;

    _serverSubscription = _server.events.listen((event) {
      if (event is TakCotReceived) {
        _handleOutbound(event);
      }
    });

    AppLogging.tak('Bridge started');
  }

  /// Stops the bridge.
  void stop() {
    if (!_running) return;
    _running = false;
    _serverSubscription?.cancel();
    _serverSubscription = null;
    AppLogging.tak('Bridge stopped');
  }

  /// Handles an inbound ATAK_PLUGIN packet from the mesh.
  ///
  /// Called by the ProtocolService when a packet with portnum 72 arrives.
  void handleMeshPacket({
    required Uint8List payload,
    required int fromNodeNum,
    required String callsign,
  }) {
    if (!_running) return;

    // Duplicate suppression.
    final hash = _hashPayload(payload);
    _cleanExpiredHashes();
    if (_recentHashes.containsKey(hash)) {
      AppLogging.tak(
        'Bridge: duplicate ATAK_PLUGIN packet from 0x${fromNodeNum.toRadixString(16).toUpperCase()}, suppressed',
      );
      return;
    }
    _recentHashes[hash] = DateTime.now();

    // Parse TAKPacket.
    TAKPacket packet;
    try {
      packet = TAKPacket.fromBuffer(payload);
    } on Exception catch (e) {
      AppLogging.tak('Bridge: failed to parse ATAK_PLUGIN packet: $e');
      _emitEvent(
        TakBridgeDirection.meshToTak,
        payload.length,
        error: e.toString(),
      );
      return;
    }

    // Decompress if needed.
    if (packet.isCompressed &&
        packet.whichPayloadVariant() == TAKPacket_PayloadVariant.detail) {
      try {
        final decompressed = CotCompressor.decompress(
          Uint8List.fromList(packet.detail),
        );
        packet.detail = decompressed;
        packet.isCompressed = false;
      } on Exception catch (e) {
        AppLogging.tak('Bridge: decompression failed: $e');
      }
    }

    // Convert to CoT XML.
    final cotXml = CotSerializer.takPacketToCotXml(
      packet,
      nodeNum: fromNodeNum,
      callsign: callsign,
    );

    // Broadcast to all TAK clients.
    _server.broadcastCot(cotXml);

    final variant = packet.whichPayloadVariant().name;
    AppLogging.tak(
      'Bridge: mesh->TAK ATAK_PLUGIN packet from 0x${fromNodeNum.toRadixString(16).toUpperCase()} ($variant, ${payload.length} bytes)',
    );
    AppLogging.tak(
      'Bridge: converted to CoT XML, broadcast to ${_server.clientCount} TAK clients',
    );

    _packetsInbound++;
    _emitEvent(TakBridgeDirection.meshToTak, payload.length);
  }

  /// Disposes the bridge and releases resources.
  Future<void> dispose() async {
    stop();
    await _eventController.close();
  }

  // --- Outbound: TAK -> Mesh ---

  void _handleOutbound(TakCotReceived event) {
    final session = event.session;
    final uid = session.uid.isNotEmpty ? session.uid : session.remoteAddress;

    // Per-client rate limiting.
    final lastSend = _lastOutboundByUid[uid];
    if (lastSend != null &&
        DateTime.now().difference(lastSend) < outboundRateLimit) {
      AppLogging.tak(
        'Bridge: TAK->mesh rate-limited $uid (last send ${DateTime.now().difference(lastSend).inSeconds}s ago)',
      );
      return;
    }

    // Aggregate rate limiting.
    _cleanOutboundTimestamps();
    if (_outboundTimestamps.length >= maxOutboundPerMinute) {
      AppLogging.tak(
        'Bridge: TAK->mesh aggregate rate limit reached ($maxOutboundPerMinute/min)',
      );
      return;
    }

    // Parse CoT XML to TAKPacket.
    TAKPacket packet;
    try {
      packet = CotSerializer.cotXmlToTakPacket(event.cotXml);
    } on Exception catch (e) {
      AppLogging.tak('Bridge: failed to parse CoT XML: $e');
      return;
    }

    // Serialize to protobuf.
    final meshPayload = Uint8List.fromList(packet.writeToBuffer());

    // Size validation.
    if (meshPayload.length > maxMeshPayload) {
      AppLogging.tak(
        'Bridge: TAK->mesh CoT rejected: payload ${meshPayload.length} bytes exceeds $maxMeshPayload byte mesh limit',
      );
      _emitEvent(
        TakBridgeDirection.takToMesh,
        meshPayload.length,
        error: 'oversized',
      );
      return;
    }

    // Send to mesh.
    final callsign = session.callsign.isNotEmpty ? session.callsign : uid;
    AppLogging.tak(
      'Bridge: TAK->mesh CoT from $callsign (${meshPayload.length} bytes), sending on portnum $atakPortnum',
    );

    _meshSend(meshPayload, portnum: atakPortnum);
    _lastOutboundByUid[uid] = DateTime.now();
    _outboundTimestamps.add(DateTime.now());
    _packetsOutbound++;
    _emitEvent(TakBridgeDirection.takToMesh, meshPayload.length);
  }

  // --- Helpers ---

  int _hashPayload(Uint8List data) {
    // Simple hash for dedup (not cryptographic).
    var hash = 0x811c9dc5;
    for (final b in data) {
      hash ^= b;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  void _cleanExpiredHashes() {
    final cutoff = DateTime.now().subtract(dedupeWindow);
    _recentHashes.removeWhere((_, ts) => ts.isBefore(cutoff));
  }

  void _cleanOutboundTimestamps() {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 1));
    _outboundTimestamps.removeWhere((ts) => ts.isBefore(cutoff));
  }

  void _emitEvent(TakBridgeDirection direction, int bytes, {String? error}) {
    _eventController.add(
      TakBridgeEvent(direction: direction, payloadBytes: bytes, error: error),
    );
  }
}
