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
  final MeshServiceTemplateId? templateId;
  final String title;

  const _RemoteInstance({
    required this.instanceId,
    required this.templateId,
    required this.title,
  });
}

/// A remote instance with its full detail from GET_INSTANCE response.
class _RemoteInstanceDetail {
  final String instanceId;
  final MeshServiceTemplateId? templateId;
  final String title;
  final String description;
  final DateTime? expiresAt;

  const _RemoteInstanceDetail({
    required this.instanceId,
    required this.templateId,
    required this.title,
    required this.description,
    this.expiresAt,
  });
}

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
      // User-created service — fetch instance list from remote peer.
      _fetchRemoteInstances();
    } else {
      // Built-in service — try local template schema match.
      _loadSchema();
    }
  }

  void _loadSchema() {
    // Try to resolve schema from built-in templates first.
    for (final id in MeshServiceTemplateId.values) {
      final templateSchema = TemplateSchemas.forTemplate(id);
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
  /// then fetch detail for each.
  Future<void> _fetchRemoteInstances() async {
    final tracker = ref.read(mrrpDeliveryTrackerProvider);
    if (tracker == null) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.serviceDetailMeshUnavailable;
        _loading = false;
      });
      return;
    }

    // Subscribe to delivery state for UI feedback.
    _deliverySub?.cancel();
    _deliverySub = tracker.stateChanges.listen((state) {
      if (mounted) setState(() => _activeDelivery = state);
    });

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

    final result = await tracker.trackRequest(listRequest);
    if (!mounted) return;

    if (result.phase != DeliveryPhase.delivered || result.response == null) {
      setState(() {
        _error = context.l10n.serviceDetailFetchFailed;
        _loading = false;
        _activeDelivery = null;
      });
      return;
    }

    // Parse LIST_INSTANCES response:
    // [0]      count
    // For each: instanceId(16) + templateId(1) + titleLen(1) + title(N)
    final payload = result.response!.payload;
    final instances = _parseListInstancesResponse(payload);
    if (instances.isEmpty) {
      setState(() {
        _remoteInstances = const [];
        _loading = false;
        _activeDelivery = null;
      });
      return;
    }

    // Fetch detail for each instance.
    final details = <_RemoteInstanceDetail>[];
    for (final inst in instances) {
      if (!mounted) return;
      final detail = await _fetchInstanceDetail(tracker, inst);
      if (detail != null) {
        details.add(detail);
      } else {
        // Fall back to basic info from the list response.
        details.add(
          _RemoteInstanceDetail(
            instanceId: inst.instanceId,
            templateId: inst.templateId,
            title: inst.title,
            description: '',
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _remoteInstances = details;
      _loading = false;
      _activeDelivery = null;
    });
  }

  List<_RemoteInstance> _parseListInstancesResponse(Uint8List payload) {
    if (payload.isEmpty) return const [];
    final count = payload[0];
    if (count == 0) return const [];

    final instances = <_RemoteInstance>[];
    var offset = 1;

    for (var i = 0; i < count; i++) {
      if (offset + 18 > payload.length) break; // 16 id + 1 template + 1 len

      final instanceId = MeshServicesHandler.decodeInstanceId(
        Uint8List.sublistView(payload, offset, offset + 16),
      );
      offset += 16;

      final templateIdx = payload[offset++];
      final templateId = templateIdx < MeshServiceTemplateId.values.length
          ? MeshServiceTemplateId.values[templateIdx]
          : null;

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
          templateId: templateId,
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

    final result = await tracker.trackRequest(getRequest);
    if (result.phase != DeliveryPhase.delivered || result.response == null) {
      return null;
    }

    // Parse GET_INSTANCE response:
    // templateId(1) + status(1) + titleLen(1) + title(N) +
    // descLen(1) + desc(N) + expiresAt(4)
    final payload = result.response!.payload;
    return _parseGetInstanceResponse(payload, instance.instanceId);
  }

  _RemoteInstanceDetail? _parseGetInstanceResponse(
    Uint8List payload,
    String instanceId,
  ) {
    if (payload.length < 7) return null; // min: 1+1+1+0+1+0+4

    var offset = 0;
    final templateIdx = payload[offset++];
    final templateId = templateIdx < MeshServiceTemplateId.values.length
        ? MeshServiceTemplateId.values[templateIdx]
        : null;

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
      templateId: templateId,
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

    // Subscribe to delivery state changes if not already subscribed.
    _deliverySub?.cancel();
    _deliverySub = tracker.stateChanges.listen((state) {
      if (mounted) setState(() => _activeDelivery = state);
    });

    // Build MRRP request frame for this action.
    final request = MrrpFrame(
      versionMajor: MrrpConstants.mrrpVersionMajor,
      versionMinor: MrrpConstants.mrrpVersionMinor,
      msgType: MrrpMessageType.request,
      flags: MrrpFlags.ackRequired,
      headerLen: MrrpConstants.mrrpHeaderMin,
      requestId: 0, // Dispatcher allocates the real ID
      serviceId: widget.serviceId,
      actionId: action.id,
      payloadLen: 0,
      payload: Uint8List(0),
    );

    // Pre-capture l10n strings before async gap.
    final successMsg = localL10n.serviceDetailActionSuccess(action.name);
    final failureMsg = localL10n.serviceDetailActionFailed(action.name);

    // Dispatch and track.
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
        l10n.deliveryPhaseFailedDesc as String,
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
    final template = instance.templateId != null
        ? MeshServiceTemplateCatalog.byId(instance.templateId!)
        : null;
    final icon = template?.icon ?? Icons.miscellaneous_services_outlined;
    final accentColor = template?.accentColor ?? context.accentColor;

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
                    if (instance.templateId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppTheme.spacing2),
                        child: Text(
                          instance.templateId!.name,
                          style: context.captionStyle?.copyWith(
                            color: context.textTertiary,
                          ),
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
          // Expiry info
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
