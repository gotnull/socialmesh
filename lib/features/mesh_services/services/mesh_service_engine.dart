// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Mesh service engine — bridges user-created instances to MRRP runtime.
///
/// Responsible for:
/// - Loading active instances from the store on startup
/// - Registering dynamic MRRP service handlers for active instances
/// - Handling incoming requests routed to user-created instances
/// - Managing instance lifecycle (create, stop, expire, cleanup)
///
/// This does NOT bypass or redesign the MRRP service registry / dispatcher.
/// It registers instance-backed handlers alongside the built-in handlers.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../../core/logging.dart';
import '../../../services/protocol/sip/mrrp_frame.dart';
import '../../../services/protocol/sip/mrrp_service_handler.dart';
import '../../../services/protocol/sip/mrrp_types.dart';
import '../models/mesh_service_detail_payload.dart';
import '../models/mesh_service_instance.dart';
import '../models/mesh_service_template.dart';
import '../models/service_schema.dart';
import '../models/template_schemas.dart';
import 'mesh_service_store.dart';

/// Well-known MRRP service ID for user-created mesh service instances.
///
/// All user-created instances share a single service ID. The instance
/// is identified by a discriminator in the request payload. This avoids
/// consuming a unique MRRP service slot per user instance (max 8 per peer).
const int kMeshServicesInstanceServiceId = 0x00000010;

/// Action IDs for the mesh-services instance service.
abstract final class MeshServicesAction {
  /// List all active instances from this peer.
  static const int listInstances = 0x0001;

  /// Get details of a specific instance.
  static const int getInstance = 0x0002;

  /// Interact with an instance (service-specific: vote, check item, etc).
  static const int interact = 0x0003;

  /// Get the schema descriptor for a specific instance.
  static const int getSchema = 0x0004;
}

/// MRRP service handler for user-created mesh service instances.
///
/// Registered once in the MRRP service registry. Routes requests to
/// the appropriate instance by instance ID in the payload.
class MeshServicesHandler implements MrrpServiceHandler {
  final MeshServiceStore _store;
  final MeshServiceEngine _engine;

  MeshServicesHandler({required this._store, required this._engine});

  @override
  int get serviceId => kMeshServicesInstanceServiceId;

  @override
  Set<int> get supportedActions => const {
    MeshServicesAction.listInstances,
    MeshServicesAction.getInstance,
    MeshServicesAction.interact,
    MeshServicesAction.getSchema,
  };

  @override
  Future<MrrpFrame> handleRequest(MrrpFrame request, int senderNodeId) async {
    switch (request.actionId) {
      case MeshServicesAction.listInstances:
        return _handleListInstances(request);
      case MeshServicesAction.getInstance:
        return _handleGetInstance(request, senderNodeId);
      case MeshServicesAction.interact:
        return _handleInteract(request, senderNodeId);
      case MeshServicesAction.getSchema:
        return _handleGetSchema(request);
      default:
        return _buildError(request, MrrpStatusCode.unsupported);
    }
  }

  /// list_instances response: count(1) + [instanceId(16) +
  /// canonicalType(1) + presetId(1) + titleLen(1) + title(N)]...
  Future<MrrpFrame> _handleListInstances(MrrpFrame request) async {
    final instances = await _store.getActive();
    final builder = BytesBuilder(copy: false);
    final limited = instances.take(8).toList();
    builder.addByte(limited.length);

    for (final inst in limited) {
      // Instance ID as first 16 bytes of the string (truncated/padded).
      final idBytes = encodeInstanceId(inst.instanceId);
      builder.add(idBytes);
      builder.addByte(inst.canonicalType.code);
      builder.addByte(
        inst.presetId?.code ?? MeshServiceAdvertMetadata.noPresetCode,
      );
      // Title (length-prefixed, max 40 bytes).
      final titleBytes = truncateUtf8(inst.title, 40);
      builder.addByte(titleBytes.length);
      builder.add(titleBytes);
    }

    final payload = Uint8List.fromList(builder.toBytes());
    return _buildResponse(request, payload);
  }

  Future<MrrpFrame> _handleGetInstance(
    MrrpFrame request,
    int senderNodeId,
  ) async {
    if (request.payload.length < 16) {
      return _buildError(request, MrrpStatusCode.invalid);
    }
    final instanceId = decodeInstanceId(request.payload);
    final inst = await _store.get(instanceId);
    if (inst == null || !inst.isActive) {
      return _buildError(request, MrrpStatusCode.notFound);
    }

    // Response: canonicalType(1) + presetId(1) + status(1) +
    //           titleLen(1) + title(N) + descLen(1) + desc(N) + expiresAt(4)
    final builder = BytesBuilder(copy: false);
    builder.addByte(inst.canonicalType.code);
    builder.addByte(
      inst.presetId?.code ?? MeshServiceAdvertMetadata.noPresetCode,
    );
    builder.addByte(inst.effectiveStatus.index);

    final titleBytes = truncateUtf8(
      inst.title,
      MeshServiceDetailPayloadCodec.titleByteBudgetFor(inst.canonicalType),
    );
    builder.addByte(titleBytes.length);
    builder.add(titleBytes);

    final descBytes = truncateUtf8(
      inst.description,
      MeshServiceDetailPayloadCodec.descriptionByteBudgetFor(
        inst.canonicalType,
      ),
    );
    builder.addByte(descBytes.length);
    builder.add(descBytes);

    // Expires at: Unix timestamp as uint32 LE, 0 if no expiry.
    final expiresAtBytes = Uint8List(4);
    if (inst.expiresAt != null) {
      ByteData.sublistView(expiresAtBytes).setUint32(
        0,
        inst.expiresAt!.millisecondsSinceEpoch ~/ 1000,
        Endian.little,
      );
    }
    builder.add(expiresAtBytes);
    final detailExtension = MeshServiceDetailPayloadCodec.encodeExtension(
      instance: inst,
      pollVotes: _engine.pollVotesFor(inst.instanceId),
      checklistStates: _engine.checklistStatesFor(inst.instanceId),
      requesterNodeId: senderNodeId,
    );
    if (inst.canonicalType == MeshServiceType.list) {
      final items =
          (inst.config['items'] as List<dynamic>?)?.cast<String>() ?? const [];
      AppLogging.mrrp(
        'MESH_SERVICE_GET_INSTANCE_BUILD '
        'instance=${inst.instanceId} '
        'type=${inst.canonicalType.name} '
        'title=${titleBytes.length}B '
        'desc=${descBytes.length}B '
        'detail=${detailExtension.length}B '
        'items=${items.length}',
      );
    }
    builder.add(detailExtension);

    final payload = Uint8List.fromList(builder.toBytes());
    return _buildResponse(request, payload);
  }

  Future<MrrpFrame> _handleInteract(MrrpFrame request, int senderNodeId) async {
    if (request.payload.length < 17) {
      return _buildError(request, MrrpStatusCode.invalid);
    }
    final instanceId = decodeInstanceId(request.payload);
    final inst = await _store.get(instanceId);
    if (inst == null || !inst.isActive) {
      return _buildError(request, MrrpStatusCode.notFound);
    }

    // Delegate to engine for service-specific interaction.
    final result = await _engine.handleInteraction(
      inst,
      senderNodeId,
      Uint8List.sublistView(request.payload, 16),
    );
    if (result == null) {
      return _buildError(request, MrrpStatusCode.unsupported);
    }

    return _buildResponse(request, result);
  }

  Future<MrrpFrame> _handleGetSchema(MrrpFrame request) async {
    if (request.payload.length < 16) {
      return _buildError(request, MrrpStatusCode.invalid);
    }
    final instanceId = decodeInstanceId(request.payload);
    final inst = await _store.get(instanceId);
    if (inst == null || !inst.isActive) {
      return _buildError(request, MrrpStatusCode.notFound);
    }

    final schema = MeshServiceSchemas.forInstance(inst);
    if (schema == null) {
      return _buildError(request, MrrpStatusCode.notFound);
    }

    final encoded = ServiceSchemaCodec.encode(schema);
    if (encoded == null) {
      return _buildError(request, MrrpStatusCode.internal);
    }

    return _buildResponse(request, encoded);
  }

  MrrpFrame _buildResponse(MrrpFrame request, Uint8List payload) {
    return MrrpFrame(
      versionMajor: request.versionMajor,
      versionMinor: request.versionMinor,
      msgType: MrrpMessageType.response,
      flags: MrrpFlags.isResponse,
      headerLen: request.headerLen,
      requestId: request.requestId,
      serviceId: request.serviceId,
      actionId: request.actionId,
      payloadLen: payload.length,
      payload: payload,
    );
  }

  MrrpFrame _buildError(MrrpFrame request, MrrpStatusCode status) {
    final payload = Uint8List(1);
    payload[0] = status.code;
    return MrrpFrame(
      versionMajor: request.versionMajor,
      versionMinor: request.versionMinor,
      msgType: MrrpMessageType.error,
      flags: MrrpFlags.isResponse | MrrpFlags.isError,
      headerLen: request.headerLen,
      requestId: request.requestId,
      serviceId: request.serviceId,
      actionId: request.actionId,
      payloadLen: payload.length,
      payload: payload,
    );
  }

  /// Encode an instance ID string to exactly 16 bytes.
  static Uint8List encodeInstanceId(String id) {
    final bytes = Uint8List(16);
    final src = id.codeUnits;
    for (var i = 0; i < 16 && i < src.length; i++) {
      bytes[i] = src[i] & 0xFF;
    }
    return bytes;
  }

  /// Decode an instance ID from the first 16 bytes of payload.
  static String decodeInstanceId(Uint8List payload) {
    final end = payload.length < 16 ? payload.length : 16;
    final chars = <int>[];
    for (var i = 0; i < end; i++) {
      if (payload[i] == 0) break;
      chars.add(payload[i]);
    }
    // lint-allow: no-raw-from-char-codes — payload bytes (0-255), id key for matching not rendered text
    return String.fromCharCodes(chars);
  }

  /// Truncate a string to fit in [maxBytes] of UTF-8.
  @visibleForTesting
  static Uint8List truncateUtf8(String text, int maxBytes) {
    var encoded = utf8.encode(text);
    if (encoded.length > maxBytes) {
      encoded = encoded.sublist(0, maxBytes);
      while (encoded.isNotEmpty && (encoded.last & 0xC0) == 0x80) {
        encoded = encoded.sublist(0, encoded.length - 1);
      }
    }
    return Uint8List.fromList(encoded);
  }
}

/// Pluggable handler for `MeshServiceType.game` interactions.
///
/// The mesh-games feature registers one of these on the engine so that
/// inbound MRRP `interact` requests targeting a game instance are routed
/// into the dedicated router. Keeps the games feature out of the engine's
/// hard dependencies.
typedef MeshGameInteractionHandler =
    Future<Uint8List?> Function(
      MeshServiceInstance instance,
      int senderNodeId,
      Uint8List interactionPayload,
    );

/// Engine managing instance lifecycle and interaction routing.
class MeshServiceEngine {
  final MeshServiceStore _store;

  /// Callback fired when instances change (for provider invalidation).
  void Function()? onChanged;

  /// Optional dispatcher for `MeshServiceType.game` interactions.
  MeshGameInteractionHandler? gameInteractionHandler;

  /// Callback fired when a new instance is successfully published.
  ///
  /// Invoked after the instance is stored and [onChanged] fires.
  /// Used by the provider layer to trigger an immediate MRRP SERVICE_ADVERT
  /// broadcast so remote peers discover the service without waiting for the
  /// next scheduled advert cycle.
  Future<void> Function()? onInstancePublished;

  /// Timer for periodic expiry cleanup.
  Timer? _cleanupTimer;

  /// In-memory poll votes: instanceId -> (optionIndex -> voterNodeIds).
  final Map<String, Map<int, Set<int>>> _pollVotes = {};

  /// In-memory checklist state: instanceId -> (itemIndex -> checked).
  final Map<String, Map<int, bool>> _checkStates = {};

  MeshServiceEngine({required this._store});

  /// Start periodic expiry cleanup.
  void start() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _cleanupExpired(),
    );
  }

  /// Stop periodic cleanup.
  void stop() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }

  /// Dispose resources.
  void dispose() {
    stop();
    _pollVotes.clear();
    _checkStates.clear();
  }

  /// Create a new service instance and persist it.
  Future<MeshServiceInstance?> createInstance({
    required MeshServiceType canonicalType,
    MeshServicePresetId? presetId,
    required String title,
    String description = '',
    required int ttlMinutes,
    Map<String, dynamic> config = const {},
  }) async {
    final resolved = MeshServiceCatalog.resolve(
      canonicalType: canonicalType,
      presetId: presetId,
    );

    final now = DateTime.now();
    // Generate a short unique ID (first 16 chars of timestamp + hash).
    final instanceId = _generateInstanceId(now);

    final instance = MeshServiceInstance(
      instanceId: instanceId,
      canonicalType: canonicalType,
      presetId: resolved.presetId,
      title: title,
      description: description,
      createdAt: now,
      expiresAt: now.add(Duration(minutes: ttlMinutes)),
      status: MeshServiceStatus.active,
      config: config,
    );

    final ok = await _store.insert(instance);
    if (!ok) return null;

    AppLogging.mrrp(
      'MESH_SERVICE_ENGINE: created ${canonicalType.name} '
      'instance=$instanceId, ttl=${ttlMinutes}m', // lint-allow: hardcoded-string
    );

    onChanged?.call();
    await onInstancePublished?.call();
    return instance;
  }

  /// Stop an active instance.
  Future<void> stopInstance(String instanceId) async {
    final inst = await _store.get(instanceId);
    if (inst == null) return;

    await _store.update(inst.copyWith(status: MeshServiceStatus.stopped));
    _pollVotes.remove(instanceId);
    _checkStates.remove(instanceId);
    onChanged?.call();

    AppLogging.mrrp(
      'MESH_SERVICE_ENGINE: stopped $instanceId', // lint-allow: hardcoded-string
    );
  }

  /// Delete an instance permanently.
  Future<void> deleteInstance(String instanceId) async {
    await _store.delete(instanceId);
    _pollVotes.remove(instanceId);
    _checkStates.remove(instanceId);
    onChanged?.call();
  }

  /// Get all local instances.
  Future<List<MeshServiceInstance>> getAllInstances() => _store.getAll();

  /// Get active local instances.
  Future<List<MeshServiceInstance>> getActiveInstances() => _store.getActive();

  Map<int, Set<int>> pollVotesFor(String instanceId) {
    return _pollVotes[instanceId] ?? const <int, Set<int>>{};
  }

  Map<int, bool> checklistStatesFor(String instanceId) {
    return _checkStates[instanceId] ?? const <int, bool>{};
  }

  /// Handle a service-specific interaction from a remote peer.
  Future<Uint8List?> handleInteraction(
    MeshServiceInstance instance,
    int senderNodeId,
    Uint8List interactionPayload,
  ) async {
    switch (instance.canonicalType) {
      case MeshServiceType.poll:
        return _handlePollVote(instance, senderNodeId, interactionPayload);
      case MeshServiceType.list:
        return _handleChecklistToggle(
          instance,
          senderNodeId,
          interactionPayload,
        );
      case MeshServiceType.feed:
      case MeshServiceType.signal:
      case MeshServiceType.sensor:
        // Feed, signal, and sensor services currently expose read-only views.
        return null;
      case MeshServiceType.game:
        final handler = gameInteractionHandler;
        if (handler == null) return null;
        return handler(instance, senderNodeId, interactionPayload);
    }
  }

  /// Poll vote: payload byte 0 = option index.
  /// Response: optionCount(1) + [voteCount(2) LE]...
  Future<Uint8List?> _handlePollVote(
    MeshServiceInstance instance,
    int senderNodeId,
    Uint8List payload,
  ) async {
    if (payload.isEmpty) return null;
    final optionIndex = payload[0];

    final options =
        (instance.config['options'] as List<dynamic>?)?.cast<String>() ??
        const [];
    if (optionIndex >= options.length) return null;

    // Record vote (one vote per peer).
    final votes = _pollVotes.putIfAbsent(instance.instanceId, () => {});
    // Remove previous vote from this peer.
    for (final entry in votes.values) {
      entry.remove(senderNodeId);
    }
    votes.putIfAbsent(optionIndex, () => {}).add(senderNodeId);

    // Build response with vote counts.
    final resp = BytesBuilder(copy: false);
    resp.addByte(options.length);
    for (var i = 0; i < options.length; i++) {
      final count = votes[i]?.length ?? 0;
      final countBytes = Uint8List(2);
      ByteData.sublistView(countBytes).setUint16(0, count, Endian.little);
      resp.add(countBytes);
    }
    return Uint8List.fromList(resp.toBytes());
  }

  /// Checklist toggle: payload byte 0 = item index, byte 1 = checked (0/1).
  /// Response: itemCount(1) + [checked(1)]...
  Future<Uint8List?> _handleChecklistToggle(
    MeshServiceInstance instance,
    int senderNodeId,
    Uint8List payload,
  ) async {
    if (payload.length < 2) return null;
    final itemIndex = payload[0];
    final checked = payload[1] != 0;

    final items =
        (instance.config['items'] as List<dynamic>?)?.cast<String>() ??
        const [];
    if (itemIndex >= items.length) return null;

    final states = _checkStates.putIfAbsent(instance.instanceId, () => {});
    states[itemIndex] = checked;

    // Build response with all item states.
    final resp = BytesBuilder(copy: false);
    resp.addByte(items.length);
    for (var i = 0; i < items.length; i++) {
      resp.addByte(states[i] == true ? 1 : 0);
    }
    return Uint8List.fromList(resp.toBytes());
  }

  Future<void> _cleanupExpired() async {
    final count = await _store.markExpired();
    if (count > 0) {
      AppLogging.mrrp(
        'MESH_SERVICE_ENGINE: expired $count instances', // lint-allow: hardcoded-string
      );
      onChanged?.call();
    }
  }

  String _generateInstanceId(DateTime now) {
    // Use timestamp hex + hashCode for uniqueness within 16 chars.
    final ts = now.millisecondsSinceEpoch.toRadixString(16);
    final hash = now.microsecondsSinceEpoch.hashCode
        .abs()
        .toRadixString(16)
        .padLeft(4, '0');
    return '$ts$hash'.substring(0, 16);
  }
}
