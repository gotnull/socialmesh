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

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/delivery_progress_card.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../services/haptic_service.dart';
import '../../../services/protocol/sip/mrrp_constants.dart';
import '../../../services/protocol/sip/mrrp_frame.dart';
import '../../../services/protocol/sip/mrrp_types.dart';
import '../../../utils/snackbar.dart';
import '../models/mesh_service_localization.dart';
import '../models/mesh_service_template.dart';
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
  final String title;
  final String description;
  final DateTime? expiresAt;

  const _RemoteInstanceDetail({
    required this.instanceId,
    required this.canonicalType,
    required this.presetId,
    required this.title,
    required this.description,
    this.expiresAt,
  });
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

/// Service detail screen.
///
/// Displays either a template-specific UI for known services or the
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

  @override
  void initState() {
    super.initState();
    _loadServiceData();
  }

  @override
  void dispose() {
    _deliverySub?.cancel();
    super.dispose();
  }

  void _loadServiceData() {
    if (widget.serviceId == kMeshServicesInstanceServiceId) {
      // User-created service — check cache before hitting the mesh.
      final key = _cacheKey(widget.nodeId, widget.serviceId);
      final cached = _instanceCache[key];
      if (cached != null && cached.instances.isNotEmpty) {
        // Show cached data instantly — no loading spinner.
        setState(() {
          _remoteInstances = cached.instances;
          _loading = false;
        });

        // Refresh in background if stale.
        final age = DateTime.now().difference(cached.fetchedAt);
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
    }

    return _RemoteInstanceDetail(
      instanceId: instanceId,
      canonicalType: canonicalType,
      presetId: presetId,
      title: title,
      description: description,
      expiresAt: expiresAt,
    );
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
          icon: widget.icon,
          title: widget.serviceTitle,
          serviceType: widget.serviceType,
          accentColor: widget.accentColor,
          nodeId: widget.nodeId,
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
          for (final inst in _remoteInstances) ...[
            _RemoteInstanceCard(instance: inst),
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
  final IconData icon;
  final String title;
  final String serviceType;
  final Color accentColor;
  final int nodeId;

  const _ServiceHeaderCard({
    required this.icon,
    required this.title,
    required this.serviceType,
    required this.accentColor,
    required this.nodeId,
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
      child: Row(
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
                  title,
                  style: context.titleStyle?.copyWith(
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing2),
                Text(
                  // lint-allow: hardcoded-string
                  '$serviceType · Node 0x${nodeId.toRadixString(16)}',
                  style: context.captionStyle?.copyWith(
                    color: context.textTertiary,
                  ),
                ),
              ],
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

  const _RemoteInstanceCard({required this.instance});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final resolved = instance.canonicalType == null
        ? null
        : MeshServiceCatalog.resolve(
            canonicalType: instance.canonicalType!,
            presetId: instance.presetId,
          );
    final icon = resolved?.icon ?? Icons.miscellaneous_services_outlined;
    final accentColor = resolved?.accentColor ?? context.accentColor;
    final typeLabel = instance.canonicalType == null
        ? null
        : meshServiceTypeName(l10n, instance.canonicalType!);
    final presetLabel = instance.presetId == null
        ? null
        : meshServicePresetName(l10n, instance.presetId!);

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
                    Text(
                      instance.title,
                      style: context.bodyStyle?.copyWith(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (typeLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppTheme.spacing2),
                        child: Row(
                          children: [
                            Text(
                              typeLabel,
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
          if (instance.description.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacing12),
            Text(
              instance.description,
              style: context.bodySmallStyle?.copyWith(
                color: context.textSecondary,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
