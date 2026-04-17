// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Service detail screen — shows a specific service from a remote peer.
///
/// Known template types get custom rendering; unknown services fall back
/// to the schema-driven generic renderer. Handles data fetching via MRRP
/// and caches schemas locally.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/delivery_progress_card.dart';
import '../../../core/widgets/expert_details_expander.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../services/haptic_service.dart';
import '../../../services/protocol/sip/mrrp_constants.dart';
import '../../../services/protocol/sip/mrrp_frame.dart';
import '../../../services/protocol/sip/mrrp_types.dart';
import '../../../utils/snackbar.dart';
import '../models/mesh_service_detail_payload.dart';
import '../models/mesh_service_localization.dart';
import '../models/mesh_service_signal_kind.dart';
import '../models/mesh_service_template.dart';
import '../presentation/mesh_service_presentation.dart';
import '../models/service_schema.dart';
import '../models/template_schemas.dart';
import '../providers/mesh_service_providers.dart';
import '../services/mesh_service_engine.dart';
import '../services/mrrp_delivery_tracker.dart';
import '../widgets/generic_service_renderer.dart';

/// A remote service instance parsed from a LIST_INSTANCES response.
class _RemoteInstance {
  final String instanceId;
  final MeshServiceType? canonicalType;
  final MeshServicePresetId? presetId;
  final String title;

  const _RemoteInstance({
    required this.instanceId,
    required this.canonicalType,
    required this.presetId,
    required this.title,
  });
}

/// A remote instance with its full detail from GET_INSTANCE response.
class _RemoteInstanceDetail {
  final String instanceId;
  final MeshServiceType? canonicalType;
  final MeshServicePresetId? presetId;
  final bool hasFetchedDetail;
  final String title;
  final String description;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final List<String> pollOptions;
  final List<int> pollVoteCounts;
  final int pollTotalOptions;
  final int? selectedPollOption;
  final List<String> listItems;
  final List<bool> listItemStates;
  final int listTotalItems;
  final String? sensorValue;
  final String? sensorUnit;
  final String? sensorSource;
  final DateTime? sensorCapturedAt;
  final MeshServiceSignalKind? signalKind;

  const _RemoteInstanceDetail({
    required this.instanceId,
    required this.canonicalType,
    required this.presetId,
    this.hasFetchedDetail = false,
    required this.title,
    required this.description,
    this.expiresAt,
    this.createdAt,
    this.pollOptions = const [],
    this.pollVoteCounts = const [],
    this.pollTotalOptions = 0,
    this.selectedPollOption,
    this.listItems = const [],
    this.listItemStates = const [],
    this.listTotalItems = 0,
    this.sensorValue,
    this.sensorUnit,
    this.sensorSource,
    this.sensorCapturedAt,
    this.signalKind,
  });

  _RemoteInstanceDetail copyWith({
    bool? hasFetchedDetail,
    String? description,
    DateTime? expiresAt,
    DateTime? createdAt,
    List<String>? pollOptions,
    List<int>? pollVoteCounts,
    int? pollTotalOptions,
    int? selectedPollOption,
    List<String>? listItems,
    List<bool>? listItemStates,
    int? listTotalItems,
    String? sensorValue,
    String? sensorUnit,
    String? sensorSource,
    DateTime? sensorCapturedAt,
    MeshServiceSignalKind? signalKind,
  }) {
    return _RemoteInstanceDetail(
      instanceId: instanceId,
      canonicalType: canonicalType,
      presetId: presetId,
      hasFetchedDetail: hasFetchedDetail ?? this.hasFetchedDetail,
      title: title,
      description: description ?? this.description,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      pollOptions: pollOptions ?? this.pollOptions,
      pollVoteCounts: pollVoteCounts ?? this.pollVoteCounts,
      pollTotalOptions: pollTotalOptions ?? this.pollTotalOptions,
      selectedPollOption: selectedPollOption ?? this.selectedPollOption,
      listItems: listItems ?? this.listItems,
      listItemStates: listItemStates ?? this.listItemStates,
      listTotalItems: listTotalItems ?? this.listTotalItems,
      sensorValue: sensorValue ?? this.sensorValue,
      sensorUnit: sensorUnit ?? this.sensorUnit,
      sensorSource: sensorSource ?? this.sensorSource,
      sensorCapturedAt: sensorCapturedAt ?? this.sensorCapturedAt,
      signalKind: signalKind ?? this.signalKind,
    );
  }
}

// ---------------------------------------------------------------------------
// Instance cache — survives screen navigation, avoids redundant MRRP fetches.
//
// LoRa round-trips for LIST_INSTANCES + GET_INSTANCE take 13–21 seconds.
// Without caching, every tap on the same service card forces the user to
// wait through this again. The cache stores fetched instance details keyed
// by (nodeId, serviceId) so repeat visits render instantly.
//
// Stale-while-revalidate: cached data is shown immediately; a background
// refresh fires if the data is older than [_cacheStaleDuration].
// ---------------------------------------------------------------------------

class _CachedInstances {
  final List<_RemoteInstanceDetail> instances;
  final DateTime fetchedAt;
  const _CachedInstances({required this.instances, required this.fetchedAt});
}

/// Module-level cache for fetched instance details.
final _instanceCache = <String, _CachedInstances>{};

/// Cache entries older than this are refreshed in the background.
const _cacheStaleDuration = Duration(seconds: 120);

String _cacheKey(int nodeId, int serviceId) => '$nodeId:$serviceId';

bool _cacheHasCompleteDetails(List<_RemoteInstanceDetail> instances) {
  return instances.every((instance) {
    if (!instance.hasFetchedDetail) return false;

    return switch (instance.canonicalType) {
      MeshServiceType.list => instance.listItems.isNotEmpty,
      MeshServiceType.poll => instance.pollOptions.isNotEmpty,
      MeshServiceType.sensor =>
        (instance.sensorValue?.isNotEmpty ?? false) ||
            (instance.sensorUnit?.isNotEmpty ?? false) ||
            (instance.sensorSource?.isNotEmpty ?? false) ||
            instance.sensorCapturedAt != null,
      MeshServiceType.signal => instance.signalKind != null,
      MeshServiceType.feed => true,
      // Games fetch full state over STATE_REQ and do not flow through
      // the generic detail cache; treat them as always complete here.
      MeshServiceType.game => true,
      null => true,
    };
  });
}

String _hexPreview(Uint8List bytes, {int maxBytes = 32}) {
  final limit = bytes.length < maxBytes ? bytes.length : maxBytes;
  return bytes
      .sublist(0, limit)
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

/// Service detail screen.
///
/// Displays either a capability-aware UI for known services or the
/// generic schema-driven renderer for unknown services.
class ServiceDetailScreen extends ConsumerStatefulWidget {
  /// The remote peer's node ID.
  final int nodeId;

  /// Numeric MRRP service ID from the remote peer's advert.
  final int serviceId;

  /// Service type string (e.g., "weather.v1").
  final String serviceType;

  /// Human-readable title from the service advert.
  final String serviceTitle;

  /// Service icon.
  final IconData icon;

  /// Accent color.
  final Color accentColor;

  const ServiceDetailScreen({
    super.key,
    required this.nodeId,
    required this.serviceId,
    required this.serviceType,
    required this.serviceTitle,
    required this.icon,
    required this.accentColor,
  });

  @override
  ConsumerState<ServiceDetailScreen> createState() =>
      _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends ConsumerState<ServiceDetailScreen>
    with LifecycleSafeMixin {
  ServiceSchema? _schema;
  final Map<int, dynamic> _data = {};
  bool _loading = true;
  String? _error;

  /// Remote instances fetched via MRRP LIST_INSTANCES.
  List<_RemoteInstanceDetail> _remoteInstances = const [];

  /// Active delivery state (shown via DeliveryProgressCard).
  MrrpDeliveryState? _activeDelivery;
  StreamSubscription<MrrpDeliveryState>? _deliverySub;
  String? _pendingListInstanceId;
  int? _pendingListItemIndex;

  @override
  void initState() {
    super.initState();
    _loadServiceData();
  }

  @override
  void dispose() {
    _deliverySub?.cancel();
    _deliverySub = null;
    super.dispose();
  }

  void _loadServiceData() {
    if (widget.serviceId == kMeshServicesInstanceServiceId) {
      // User-created service — check cache before hitting the mesh.
      final key = _cacheKey(widget.nodeId, widget.serviceId);
      final cached = _instanceCache[key];
      if (cached != null && cached.instances.isNotEmpty) {
        final cacheHasCompleteDetails = _cacheHasCompleteDetails(
          cached.instances,
        );
        final age = DateTime.now().difference(cached.fetchedAt);
        if (cacheHasCompleteDetails) {
          // Show cached data instantly — no loading spinner.
          setState(() {
            _remoteInstances = cached.instances;
            _loading = false;
          });
        }

        // Refresh in background if the cache is stale or still contains
        // semantically incomplete detail from older or partial GET_INSTANCE
        // responses. Incomplete cache is not rendered as source of truth.
        if (!cacheHasCompleteDetails) {
          _fetchRemoteInstances();
          return;
        }

        if (age > _cacheStaleDuration) {
          _fetchRemoteInstances(silent: true);
        }
        return;
      }

      // No cache — fetch with loading indicator.
      _fetchRemoteInstances();
    } else {
      // Built-in service — try local template schema match.
      _loadSchema();
    }
  }

  void _loadSchema() {
    // Try to resolve schema from built-in canonical types first.
    for (final type in MeshServiceType.values) {
      final templateSchema = MeshServiceSchemas.forType(type);
      if (templateSchema != null &&
          templateSchema.serviceType == widget.serviceType) {
        setState(() {
          _schema = templateSchema;
          _loading = false;
        });
        return;
      }
    }

    // Unknown service type — show empty schema state.
    setState(() {
      _loading = false;
    });
  }

  /// Fetch the remote peer's active instances via MRRP LIST_INSTANCES,
  /// then progressively fetch detail for each.
  ///
  /// **Progressive rendering**: Instance cards appear as soon as
  /// LIST_INSTANCES returns (with titles). Descriptions and expiry
  /// are backfilled as each GET_INSTANCE response arrives, avoiding
  /// a 15-20s blank screen on slow meshes.
  ///
  /// When [silent] is true, the fetch runs in the background without
  /// showing a loading indicator — used for stale-while-revalidate.
  Future<void> _fetchRemoteInstances({bool silent = false}) async {
    final tracker = ref.read(mrrpDeliveryTrackerProvider);
    if (tracker == null) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _error = context.l10n.serviceDetailMeshUnavailable;
          _loading = false;
        });
      }
      return;
    }

    // Subscribe to delivery state for UI feedback (skip in silent mode).
    if (!silent) {
      _deliverySub?.cancel();
      _deliverySub = null;
      _deliverySub = tracker.stateChanges.listen((state) {
        if (mounted) setState(() => _activeDelivery = state);
      });
    }

    // Send LIST_INSTANCES request.
    final listRequest = MrrpFrame(
      versionMajor: MrrpConstants.mrrpVersionMajor,
      versionMinor: MrrpConstants.mrrpVersionMinor,
      msgType: MrrpMessageType.request,
      flags: MrrpFlags.ackRequired,
      headerLen: MrrpConstants.mrrpHeaderMin,
      requestId: 0,
      serviceId: widget.serviceId,
      actionId: MeshServicesAction.listInstances,
      payloadLen: 0,
      payload: Uint8List(0),
    );

    final result = await tracker.trackRequest(
      listRequest,
      retryPolicy: MrrpRetryPolicy.idempotent,
    );
    if (!mounted) return;

    if (result.phase != DeliveryPhase.delivered || result.response == null) {
      if (!silent) {
        setState(() {
          _error = result.attemptsMade > 1
              ? context.l10n.serviceDetailFetchFailedRetried(
                  result.attemptsMade,
                )
              : context.l10n.serviceDetailFetchFailed;
          _loading = false;
          _activeDelivery = null;
        });
      }
      return;
    }

    // Parse LIST_INSTANCES response:
    // [0]      count
    // For each: instanceId(16) + canonicalType(1) + presetId(1) +
    // titleLen(1) + title(N)
    final payload = result.response!.payload;
    final instances = _parseListInstancesResponse(payload);
    if (instances.isEmpty) {
      final key = _cacheKey(widget.nodeId, widget.serviceId);
      _instanceCache[key] = _CachedInstances(
        instances: const [],
        fetchedAt: DateTime.now(),
      );
      if (!silent) {
        setState(() {
          _remoteInstances = const [];
          _loading = false;
          _activeDelivery = null;
        });
      }
      return;
    }

    // --- Progressive rendering: show cards immediately with titles ---
    final details = <_RemoteInstanceDetail>[
      for (final inst in instances)
        _RemoteInstanceDetail(
          instanceId: inst.instanceId,
          canonicalType: inst.canonicalType,
          presetId: inst.presetId,
          title: inst.title,
          description: '',
          pollTotalOptions: 0,
          listTotalItems: 0,
        ),
    ];

    if (mounted) {
      setState(() {
        _remoteInstances = List.of(details);
        _loading = false;
        _activeDelivery = null;
      });
    }

    // --- Backfill descriptions from GET_INSTANCE (fire-and-forget per instance) ---
    for (var i = 0; i < instances.length; i++) {
      if (!mounted) return;
      final detail = await _fetchInstanceDetail(tracker, instances[i]);
      if (detail != null) {
        details[i] = detail;
      }
      // Update UI after each successful GET_INSTANCE response.
      if (mounted) {
        setState(() {
          _remoteInstances = List.of(details);
        });
      }
    }

    // Cache the final set with full details.
    if (!mounted) return;
    final key = _cacheKey(widget.nodeId, widget.serviceId);
    _instanceCache[key] = _CachedInstances(
      instances: List.of(details),
      fetchedAt: DateTime.now(),
    );
  }

  List<_RemoteInstance> _parseListInstancesResponse(Uint8List payload) {
    if (payload.isEmpty) return const [];
    final count = payload[0];
    if (count == 0) return const [];

    final instances = <_RemoteInstance>[];
    var offset = 1;

    for (var i = 0; i < count; i++) {
      if (offset + 19 > payload.length) break;

      final instanceId = MeshServicesHandler.decodeInstanceId(
        Uint8List.sublistView(payload, offset, offset + 16),
      );
      offset += 16;

      final canonicalType = MeshServiceType.fromCode(payload[offset++]);
      final presetCode = payload[offset++];
      final presetId = presetCode == MeshServiceAdvertMetadata.noPresetCode
          ? null
          : MeshServicePresetId.fromCode(presetCode);

      final titleLen = payload[offset++];
      if (offset + titleLen > payload.length) break;

      final title = titleLen > 0
          ? utf8.decode(
              payload.sublist(offset, offset + titleLen),
              allowMalformed: true,
            )
          : '';
      offset += titleLen;

      instances.add(
        _RemoteInstance(
          instanceId: instanceId,
          canonicalType: canonicalType,
          presetId: presetId,
          title: title,
        ),
      );
    }

    return instances;
  }

  Future<_RemoteInstanceDetail?> _fetchInstanceDetail(
    MrrpDeliveryTracker tracker,
    _RemoteInstance instance,
  ) async {
    final idBytes = MeshServicesHandler.encodeInstanceId(instance.instanceId);
    final getRequest = MrrpFrame(
      versionMajor: MrrpConstants.mrrpVersionMajor,
      versionMinor: MrrpConstants.mrrpVersionMinor,
      msgType: MrrpMessageType.request,
      flags: MrrpFlags.ackRequired,
      headerLen: MrrpConstants.mrrpHeaderMin,
      requestId: 0,
      serviceId: widget.serviceId,
      actionId: MeshServicesAction.getInstance,
      payloadLen: idBytes.length,
      payload: idBytes,
    );

    final result = await tracker.trackRequest(
      getRequest,
      retryPolicy: MrrpRetryPolicy.idempotent,
    );
    if (result.phase != DeliveryPhase.delivered || result.response == null) {
      return null;
    }

    // Parse GET_INSTANCE response:
    // canonicalType(1) + presetId(1) + status(1) + titleLen(1) + title(N) +
    // descLen(1) + desc(N) + expiresAt(4)
    final payload = result.response!.payload;
    return _parseGetInstanceResponse(payload, instance.instanceId);
  }

  _RemoteInstanceDetail? _parseGetInstanceResponse(
    Uint8List payload,
    String instanceId,
  ) {
    if (payload.length < 8) return null;

    var offset = 0;
    final canonicalType = MeshServiceType.fromCode(payload[offset++]);
    final presetCode = payload[offset++];
    final presetId = presetCode == MeshServiceAdvertMetadata.noPresetCode
        ? null
        : MeshServicePresetId.fromCode(presetCode);

    offset++; // status — skip for display purposes

    final titleLen = payload[offset++];
    if (offset + titleLen > payload.length) return null;
    final title = titleLen > 0
        ? utf8.decode(
            payload.sublist(offset, offset + titleLen),
            allowMalformed: true,
          )
        : '';
    offset += titleLen;

    if (offset >= payload.length) return null;
    final descLen = payload[offset++];
    if (offset + descLen > payload.length) return null;
    final description = descLen > 0
        ? utf8.decode(
            payload.sublist(offset, offset + descLen),
            allowMalformed: true,
          )
        : '';
    offset += descLen;

    DateTime? expiresAt;
    if (offset + 4 <= payload.length) {
      final ts = ByteData.sublistView(
        payload,
        offset,
      ).getUint32(0, Endian.little);
      if (ts > 0) {
        expiresAt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
      }
      offset += 4;
    }

    final extension = MeshServiceDetailPayloadCodec.decode(
      canonicalType,
      offset < payload.length
          ? Uint8List.sublistView(payload, offset)
          : Uint8List(0),
    );
    final detailPayload = offset < payload.length
        ? Uint8List.sublistView(payload, offset)
        : Uint8List(0);

    if (canonicalType == MeshServiceType.list) {
      AppLogging.mrrp(
        'MESH_SERVICE_DETAIL_PARSE '
        'instance=$instanceId '
        'type=${canonicalType?.name ?? 'unknown'} '
        'payload=${payload.length}B '
        'detail=${detailPayload.length}B '
        'items=${extension.listItems.length}/${extension.listTotalItems}',
      );
      if (extension.listItems.isEmpty) {
        AppLogging.mrrp(
          'MESH_SERVICE_DETAIL_PARSE_EMPTY '
          'instance=$instanceId '
          'detailHex=${_hexPreview(detailPayload)}',
        );
      }
    }

    return _RemoteInstanceDetail(
      instanceId: instanceId,
      canonicalType: canonicalType,
      presetId: presetId,
      hasFetchedDetail: true,
      title: title,
      description: description,
      expiresAt: expiresAt,
      createdAt: extension.createdAt,
      pollOptions: extension.pollOptions,
      pollVoteCounts: extension.pollVoteCounts,
      pollTotalOptions: extension.pollTotalOptions,
      selectedPollOption: extension.selectedPollOption,
      listItems: extension.listItems,
      listItemStates: extension.listItemStates,
      listTotalItems: extension.listTotalItems,
      sensorValue: extension.sensorValue,
      sensorUnit: extension.sensorUnit,
      sensorSource: extension.sensorSource,
      sensorCapturedAt: extension.sensorCapturedAt,
      signalKind: extension.signalKind,
    );
  }

  bool get _interactionBusy {
    if (_pendingListItemIndex != null) return true;
    final delivery = _activeDelivery;
    if (delivery == null) return false;
    return !delivery.phase.isTerminal;
  }

  int? _pendingListItemIndexFor(_RemoteInstanceDetail instance) {
    if (_pendingListInstanceId != instance.instanceId) return null;
    return _pendingListItemIndex;
  }

  Future<Uint8List?> _sendInteractionRequest(
    _RemoteInstanceDetail instance,
    Uint8List interactionPayload,
  ) async {
    final tracker = ref.read(mrrpDeliveryTrackerProvider);
    if (tracker == null) return null;

    _deliverySub?.cancel();
    _deliverySub = null;
    _deliverySub = tracker.stateChanges.listen((state) {
      if (mounted) setState(() => _activeDelivery = state);
    });

    final idBytes = MeshServicesHandler.encodeInstanceId(instance.instanceId);
    final payload = Uint8List(idBytes.length + interactionPayload.length)
      ..setAll(0, idBytes)
      ..setAll(idBytes.length, interactionPayload);

    final request = MrrpFrame(
      versionMajor: MrrpConstants.mrrpVersionMajor,
      versionMinor: MrrpConstants.mrrpVersionMinor,
      msgType: MrrpMessageType.request,
      flags: MrrpFlags.ackRequired,
      headerLen: MrrpConstants.mrrpHeaderMin,
      requestId: 0,
      serviceId: widget.serviceId,
      actionId: MeshServicesAction.interact,
      payloadLen: payload.length,
      payload: payload,
    );

    final result = await tracker.trackRequest(
      request,
      retryPolicy: MrrpRetryPolicy.idempotent,
    );

    if (!mounted) return null;
    if (result.phase != DeliveryPhase.delivered || result.response == null) {
      showErrorSnackBar(context, context.l10n.meshServicesInteractionFailed);
      return null;
    }

    return result.response!.payload;
  }

  void _replaceRemoteInstance(_RemoteInstanceDetail updated) {
    setState(() {
      _remoteInstances = [
        for (final instance in _remoteInstances)
          if (instance.instanceId == updated.instanceId) updated else instance,
      ];
    });
  }

  Future<void> _voteOnPoll(
    _RemoteInstanceDetail instance,
    int optionIndex,
  ) async {
    final haptics = ref.read(hapticServiceProvider);
    await haptics.trigger(HapticType.light);
    final payload = await _sendInteractionRequest(
      instance,
      Uint8List.fromList([optionIndex]),
    );
    if (payload == null || payload.isEmpty) return;

    final optionCount = payload[0];
    final counts = <int>[];
    var offset = 1;
    for (var index = 0; index < optionCount; index++) {
      if (offset + 2 > payload.length) break;
      counts.add(
        ByteData.sublistView(
          payload,
          offset,
          offset + 2,
        ).getUint16(0, Endian.little),
      );
      offset += 2;
    }

    _replaceRemoteInstance(
      instance.copyWith(
        pollVoteCounts: counts,
        selectedPollOption: optionIndex,
      ),
    );
  }

  Future<void> _toggleListItem(
    _RemoteInstanceDetail instance,
    int itemIndex,
    bool checked,
  ) async {
    if (_pendingListItemIndex != null) return;
    final haptics = ref.read(hapticServiceProvider);
    setState(() {
      _pendingListInstanceId = instance.instanceId;
      _pendingListItemIndex = itemIndex;
    });
    try {
      await haptics.trigger(HapticType.light);
      final payload = await _sendInteractionRequest(
        instance,
        Uint8List.fromList([itemIndex, checked ? 1 : 0]),
      );
      if (payload == null || payload.isEmpty) return;

      final itemCount = payload[0];
      final states = <bool>[];
      for (
        var index = 0;
        index < itemCount && index + 1 < payload.length;
        index++
      ) {
        states.add(payload[index + 1] != 0);
      }

      _replaceRemoteInstance(instance.copyWith(listItemStates: states));
    } finally {
      if (mounted &&
          _pendingListInstanceId == instance.instanceId &&
          _pendingListItemIndex == itemIndex) {
        setState(() {
          _pendingListInstanceId = null;
          _pendingListItemIndex = null;
        });
      }
    }
  }

  Future<void> _onAction(SchemaAction action) async {
    final localL10n = context.l10n;
    final haptics = ref.read(hapticServiceProvider);
    haptics.trigger(HapticType.light);

    final tracker = ref.read(mrrpDeliveryTrackerProvider);
    if (tracker == null) {
      if (!mounted) return;
      showErrorSnackBar(context, localL10n.serviceDetailMeshUnavailable);
      return;
    }

    _deliverySub?.cancel();
    _deliverySub = null;
    _deliverySub = tracker.stateChanges.listen((state) {
      if (mounted) setState(() => _activeDelivery = state);
    });

    final request = MrrpFrame(
      versionMajor: MrrpConstants.mrrpVersionMajor,
      versionMinor: MrrpConstants.mrrpVersionMinor,
      msgType: MrrpMessageType.request,
      flags: MrrpFlags.ackRequired,
      headerLen: MrrpConstants.mrrpHeaderMin,
      requestId: 0,
      serviceId: widget.serviceId,
      actionId: action.id,
      payloadLen: 0,
      payload: Uint8List(0),
    );

    final successMsg = localL10n.serviceDetailActionSuccess(action.name);
    final failureMsg = localL10n.serviceDetailActionFailed(action.name);

    final result = await tracker.trackRequest(request);
    if (!mounted) return;
    if (result.phase == DeliveryPhase.delivered && result.response != null) {
      showSuccessSnackBar(context, successMsg);
    } else if (result.phase == DeliveryPhase.failed) {
      showErrorSnackBar(context, failureMsg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return GlassScaffold(
      title: widget.serviceTitle,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: _buildContent(context, l10n),
          ),
        ),
        // Delivery progress card — shown during active MRRP request.
        if (_activeDelivery != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing16,
              ),
              child: _buildDeliveryCard(context, l10n),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacing48)),
      ],
    );
  }

  Widget _buildDeliveryCard(BuildContext context, dynamic l10n) {
    final delivery = _activeDelivery!;
    final (label, desc) = _deliveryPhaseStrings(l10n, delivery.phase);
    return DeliveryProgressCard(
      phase: delivery.phase,
      label: label,
      description: desc,
      safeToLeaveHint: delivery.phase.isSafeToLeave
          ? l10n.deliverySafeToLeave as String
          : null,
      showExpertDetails: delivery.statusCode != null,
      expertToggleLabel: l10n.deliveryExpertToggle as String,
      expertDetails: [
        if (delivery.statusCode != null)
          'Status: ${delivery.statusCode!.name}', // lint-allow: hardcoded-string
        if (delivery.latency != null)
          'Latency: ${delivery.latency!.inMilliseconds}ms', // lint-allow: hardcoded-string
      ],
    );
  }

  (String, String) _deliveryPhaseStrings(dynamic l10n, DeliveryPhase phase) {
    return switch (phase) {
      DeliveryPhase.preparing => (
        l10n.deliveryPhasePreparing as String,
        l10n.deliveryPhasePreparingDesc as String,
      ),
      DeliveryPhase.sending => (
        l10n.deliveryPhaseSending as String,
        l10n.deliveryPhaseSendingDesc as String,
      ),
      DeliveryPhase.sentToMesh => (
        l10n.deliveryPhaseSentToMesh as String,
        l10n.deliveryPhaseSentToMeshDesc as String,
      ),
      DeliveryPhase.waitingForPath => (
        l10n.deliveryPhaseWaitingForPath as String,
        l10n.deliveryPhaseWaitingForPathDesc as String,
      ),
      DeliveryPhase.delivering => (
        l10n.deliveryPhaseDelivering as String,
        l10n.deliveryPhaseDeliveringDesc as String,
      ),
      DeliveryPhase.partiallyDelivered => (
        l10n.deliveryPhasePartiallyDelivered as String,
        l10n.deliveryPhasePartiallyDeliveredDesc as String,
      ),
      DeliveryPhase.retrying => (
        l10n.deliveryPhaseRetrying as String,
        l10n.deliveryPhaseRetryingDesc as String,
      ),
      DeliveryPhase.resuming => (
        l10n.deliveryPhaseResuming as String,
        l10n.deliveryPhaseResumingDesc as String,
      ),
      DeliveryPhase.delivered => (
        l10n.deliveryPhaseDelivered as String,
        l10n.deliveryPhaseDeliveredDesc as String,
      ),
      DeliveryPhase.verified => (
        l10n.deliveryPhaseVerified as String,
        l10n.deliveryPhaseVerifiedDesc as String,
      ),
      DeliveryPhase.needsAttention => (
        l10n.deliveryPhaseNeedsAttention as String,
        l10n.deliveryPhaseNeedsAttentionDesc as String,
      ),
      DeliveryPhase.failed => (
        l10n.deliveryPhaseFailed as String,
        (_activeDelivery?.attemptsMade ?? 1) > 1
            ? l10n.deliveryPhaseFailedDescRetried(_activeDelivery!.attemptsMade)
                  as String
            : l10n.deliveryPhaseFailedDesc as String,
      ),
    };
  }

  Widget _buildContent(BuildContext context, dynamic l10n) {
    // Always show the header card immediately — we already have
    // title, icon, service type, and node ID from the SERVICE_ADVERT.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ServiceHeaderCard(
          l10n: l10n,
          icon: widget.icon,
          title: widget.serviceTitle,
          serviceType: widget.serviceType,
          accentColor: widget.accentColor,
          nodeId: widget.nodeId,
          serviceId: widget.serviceId,
        ),
        const SizedBox(height: AppTheme.spacing16),
        _buildInstancesSection(context, l10n),
      ],
    );
  }

  /// Builds the instances / schema section below the header card.
  ///
  /// Shows a loading indicator while fetching, then the actual content.
  Widget _buildInstancesSection(BuildContext context, dynamic l10n) {
    if (_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator.adaptive(),
              const SizedBox(height: AppTheme.spacing16),
              Text(
                l10n.serviceDetailFetchingInstances,
                style: context.bodySecondaryStyle?.copyWith(
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _loadServiceData);
    }

    // Remote instances from MRRP fetch.
    if (_remoteInstances.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.serviceDetailSectionLiveNow,
            style: context.labelStyle?.copyWith(
              color: context.textTertiary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppTheme.spacing10),
          for (final inst in _remoteInstances) ...[
            _RemoteInstanceCard(
              instance: inst,
              interactionsBusy: _interactionBusy,
              pendingListItemIndex: _pendingListItemIndexFor(inst),
              onVote: inst.canonicalType == MeshServiceType.poll
                  ? (optionIndex) => _voteOnPoll(inst, optionIndex)
                  : null,
              onToggleItem: inst.canonicalType == MeshServiceType.list
                  ? (itemIndex, checked) =>
                        _toggleListItem(inst, itemIndex, checked)
                  : null,
            ),
            const SizedBox(height: AppTheme.spacing8),
          ],
        ],
      );
    }

    if (_schema != null) {
      return GenericServiceRenderer(
        schema: _schema!,
        data: _data,
        onAction: _onAction,
      );
    }

    // No instances and no schema — show empty state.
    if (widget.serviceId == kMeshServicesInstanceServiceId) {
      return _NoInstancesState(l10n: l10n);
    }

    return _UnknownServiceState(serviceType: widget.serviceType, l10n: l10n);
  }
}

/// Header card showing service icon, title, and node info.
class _ServiceHeaderCard extends StatelessWidget {
  final dynamic l10n;
  final IconData icon;
  final String title;
  final String serviceType;
  final Color accentColor;
  final int nodeId;
  final int serviceId;

  const _ServiceHeaderCard({
    required this.l10n,
    required this.icon,
    required this.title,
    required this.serviceType,
    required this.accentColor,
    required this.nodeId,
    required this.serviceId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.spacing12),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.spacing12),
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.serviceDetailHeaderEyebrow as String,
                      style: context.bodySmallStyle?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing2),
                    Text(
                      title,
                      style: context.titleStyle?.copyWith(
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing8,
                        vertical: AppTheme.spacing4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                      ),
                      child: Text(
                        serviceType,
                        style: context.bodySmallStyle?.copyWith(
                          color: context.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            l10n.serviceDetailHeaderBody as String,
            style: context.bodySecondaryStyle?.copyWith(
              color: context.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          ExpertDetailsExpander(
            label: l10n.meshServicesNetworkDetails as String,
            icon: Icons.router_outlined,
            expandedBuilder: (context) => Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing16,
                0,
                AppTheme.spacing16,
                AppTheme.spacing8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.meshServicesNetworkNode(
                          '0x${nodeId.toRadixString(16)}',
                        )
                        as String,
                    style: context.bodySmallStyle?.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing6),
                  Text(
                    l10n.meshServicesNetworkServiceType(serviceType) as String,
                    style: context.bodySmallStyle?.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing6),
                  Text(
                    l10n.meshServicesNetworkServiceId(
                          '0x${serviceId.toRadixString(16)}',
                        )
                        as String,
                    style: context.bodySmallStyle?.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state for unknown services without schema.
class _UnknownServiceState extends StatelessWidget {
  final String serviceType;
  final dynamic l10n;

  const _UnknownServiceState({required this.serviceType, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.extension_outlined,
              size: 48,
              color: context.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              l10n.serviceDetailUnknownTitle,
              style: context.titleStyle?.copyWith(color: context.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              l10n.serviceDetailUnknownBody(serviceType),
              style: context.bodySecondaryStyle?.copyWith(
                color: context.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Error state with retry.
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: AccentColors.coral.withValues(alpha: 0.7),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              message,
              style: context.bodySecondaryStyle?.copyWith(
                color: context.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing16),
            FilledButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
          ],
        ),
      ),
    );
  }
}

/// Card displaying a remote service instance fetched via MRRP.
class _RemoteInstanceCard extends StatelessWidget {
  final _RemoteInstanceDetail instance;
  final bool interactionsBusy;
  final int? pendingListItemIndex;
  final Future<void> Function(int optionIndex)? onVote;
  final Future<void> Function(int itemIndex, bool checked)? onToggleItem;

  const _RemoteInstanceCard({
    required this.instance,
    required this.interactionsBusy,
    this.pendingListItemIndex,
    this.onVote,
    this.onToggleItem,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canonicalType = instance.canonicalType;
    final resolved = canonicalType == null
        ? null
        : MeshServiceCatalog.resolve(
            canonicalType: canonicalType,
            presetId: instance.presetId,
          );
    final icon = resolved?.icon ?? Icons.miscellaneous_services_outlined;
    final accentColor = resolved?.accentColor ?? context.accentColor;
    final presetLabel = instance.presetId == null
        ? null
        : meshServicePresetName(l10n, instance.presetId!);
    final spec = canonicalType == null
        ? null
        : MeshServicePresentationRegistry.forType(canonicalType);
    final eyebrow = spec?.discoveryEyebrow(l10n);
    final detailData = MeshServiceRemoteDetailViewData(
      title: instance.title,
      description: instance.description,
      expiresAt: instance.expiresAt,
      createdAt: instance.createdAt,
      pollOptions: instance.pollOptions,
      pollVoteCounts: instance.pollVoteCounts,
      pollTotalOptions: instance.pollTotalOptions,
      selectedPollOption: instance.selectedPollOption,
      listItems: instance.listItems,
      listItemStates: instance.listItemStates,
      listTotalItems: instance.listTotalItems,
      signalKind: instance.signalKind,
      sensorValue: instance.sensorValue,
      sensorUnit: instance.sensorUnit,
      sensorSource: instance.sensorSource,
      sensorCapturedAt: instance.sensorCapturedAt,
      isInteractionBusy: interactionsBusy,
      pendingListItemIndex: pendingListItemIndex,
      onVote: onVote,
      onToggleItem: onToggleItem,
    );

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                child: Icon(icon, size: 22, color: accentColor),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (eyebrow != null)
                      Text(
                        eyebrow,
                        style: context.bodySmallStyle?.copyWith(
                          color: accentColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (eyebrow != null)
                      const SizedBox(height: AppTheme.spacing2),
                    Text(
                      instance.title,
                      style: context.bodyStyle?.copyWith(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (canonicalType != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppTheme.spacing2),
                        child: Row(
                          children: [
                            Text(
                              meshServiceTypeName(l10n, canonicalType),
                              style: context.captionStyle?.copyWith(
                                color: context.textTertiary,
                              ),
                            ),
                            if (presetLabel != null) ...[
                              const SizedBox(width: AppTheme.spacing6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacing6,
                                  vertical: AppTheme.spacing2,
                                ),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radius8,
                                  ),
                                ),
                                child: Text(
                                  presetLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          if (spec != null)
            spec.buildRemoteDetailContent(context, l10n, detailData)
          else
            Text(
              instance.description,
              style: context.bodySmallStyle?.copyWith(
                color: context.textSecondary,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            _expiryText(l10n, instance.expiresAt),
            style: context.captionStyle?.copyWith(color: context.textTertiary),
          ),
        ],
      ),
    );
  }

  String _expiryText(dynamic l10n, DateTime? expiresAt) {
    if (expiresAt == null) {
      return l10n.serviceDetailInstanceNoExpiry as String;
    }
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) {
      return l10n.serviceDetailInstanceExpired as String;
    }
    final formatted = remaining.inHours > 0
        ? '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m' // lint-allow: hardcoded-string
        : '${remaining.inMinutes}m'; // lint-allow: hardcoded-string
    return l10n.serviceDetailInstanceExpires(formatted) as String;
  }
}

/// Empty state when no active instances.
class _NoInstancesState extends StatelessWidget {
  final dynamic l10n;

  const _NoInstancesState({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: context.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              l10n.serviceDetailNoInstances,
              style: context.titleStyle?.copyWith(color: context.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              l10n.serviceDetailNoInstancesBody,
              style: context.bodySecondaryStyle?.copyWith(
                color: context.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
