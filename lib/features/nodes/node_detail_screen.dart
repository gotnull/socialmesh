// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../utils/time_format.dart';
import '../../utils/timestamp_validation.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/units/distance_format.dart';
import '../../core/node_color.dart';
import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/auto_scroll_text.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/info_table.dart';
import '../../core/widgets/node_avatar.dart';
import '../../core/widgets/qr_share_sheet.dart';
import '../../models/mesh_models.dart';
import '../../models/telemetry_log.dart';
import '../../providers/app_providers.dart';
import '../../providers/countdown_providers.dart';
import '../../providers/telemetry_providers.dart';
import '../../services/protocol/admin_target.dart';
import '../../utils/snackbar.dart';
import '../../utils/uptime_formatter.dart';

import '../device/device_config_screen.dart';
import '../map/map_screen.dart';
import '../messaging/messaging_screen.dart';
import '../nodedex/models/nodedex_entry.dart';
import '../nodedex/providers/nodedex_providers.dart';
import '../nodedex/screens/nodedex_detail_screen.dart';
import '../nodedex/services/sigil_generator.dart';
import '../nodedex/services/trait_engine.dart';
import '../nodedex/widgets/node_groups_card.dart';
import '../nodedex/widgets/node_note_edit_sheet.dart';
import '../nodedex/widgets/section_info_button.dart';
import '../nodedex/widgets/sigil_card_sheet.dart';
import '../nodedex/widgets/trait_badge.dart';
import '../telemetry/air_quality_log_screen.dart';
import '../telemetry/detection_sensor_log_screen.dart';
import '../telemetry/device_metrics_log_screen.dart';
import '../telemetry/environment_metrics_log_screen.dart';
import '../telemetry/pax_counter_log_screen.dart';
import '../telemetry/position_log_screen.dart';
import '../telemetry/power_metrics_log_screen.dart';
import '../telemetry/traceroute_log_screen.dart';
import 'node_actions.dart';
import 'widgets/fixed_position_sheet.dart';
import 'widgets/node_health_badge.dart';

/// Navigates to the node detail screen. Can be called from any screen.
void showNodeDetails(BuildContext context, MeshNode node, bool isMyNode) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => NodeDetailScreen(node: node, isMyNode: isMyNode),
    ),
  );
}

/// Full-screen node detail view with glass scaffold.
///
/// Replaces the old bottom sheet approach, providing proper scrolling,
/// app bar actions, and room for all data sections.
class NodeDetailScreen extends ConsumerStatefulWidget {
  final MeshNode node;
  final bool isMyNode;

  const NodeDetailScreen({
    super.key,
    required this.node,
    required this.isMyNode,
  });

  @override
  ConsumerState<NodeDetailScreen> createState() => _NodeDetailScreenState();
}

class _NodeDetailScreenState extends ConsumerState<NodeDetailScreen>
    with LifecycleSafeMixin<NodeDetailScreen> {
  bool _isTogglingFavorite = false;
  bool _isTogglingMute = false;
  bool _isSendingTraceroute = false;

  /// Tracks the ID of the last traceroute result shown in the summary snackbar.
  /// Prevents duplicate popups for the same result across rebuilds.
  String? _lastShownTracerouteId;

  /// Timestamp of the most recent traceroute request sent from this screen.
  /// Used to ignore late-arriving responses from previous requests that
  /// predate the current one (the mesh has no request-response correlation).
  DateTime? _lastTracerouteSentAt;

  final ScrollController _scrollController = ScrollController();
  bool _showAppBarIdentity = false;
  static const double _identityScrollThreshold = 80.0;

  MeshNode get _initialNode => widget.node;
  bool get isMyNode => widget.isMyNode;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final shouldShow =
        _scrollController.hasClients &&
        _scrollController.offset > _identityScrollThreshold;
    if (shouldShow != _showAppBarIdentity) {
      setState(() => _showAppBarIdentity = shouldShow);
    }
  }

  // ─────────────────────── helpers ───────────────────────

  Color _getAvatarColor(MeshNode node) =>
      resolveNodeColor(nodeNum: node.nodeNum, avatarColor: node.avatarColor);

  IconData _getBatteryIcon(int level) {
    if (level > 100) return Icons.battery_charging_full;
    if (level >= 95) return Icons.battery_full;
    if (level >= 80) return Icons.battery_6_bar;
    if (level >= 60) return Icons.battery_5_bar;
    if (level >= 40) return Icons.battery_4_bar;
    if (level >= 20) return Icons.battery_2_bar;
    if (level >= 10) return Icons.battery_1_bar;
    return Icons.battery_alert;
  }

  Color _getBatteryColor(int level) {
    if (level > 100) return AccentColors.green;
    if (level >= 50) return AccentColors.green;
    if (level >= 20) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }

  // ─────────────────────── actions ───────────────────────

  void _shareSigilCard(BuildContext context, MeshNode node) {
    final entries = ref.read(nodeDexProvider);
    final entry =
        entries[node.nodeNum] ??
        NodeDexEntry.discovered(
          nodeNum: node.nodeNum,
          sigil: SigilGenerator.generate(node.nodeNum),
        );

    final traitResult = TraitEngine.infer(entry: entry);

    showSigilCardSheet(
      context: context,
      entry: entry,
      traitResult: traitResult,
      node: node,
    );
  }

  void _showNodeQrCode(BuildContext context, MeshNode node) {
    final nodeInfo = {
      'nodeNum': node.nodeNum,
      'longName': node.longName ?? node.displayName,
      'shortName': node.avatarName,
      if (node.userId != null) 'userId': node.userId,
      if (node.hasPosition) 'lat': node.latitude,
      if (node.hasPosition) 'lon': node.longitude,
    };
    final nodeJson = jsonEncode(nodeInfo);
    final nodeUrl = 'socialmesh://node/${base64Encode(utf8.encode(nodeJson))}';

    QrShareSheet.show(
      context: context,
      title: node.displayName,
      subtitle: context.l10n.nodeDetailQrSubtitle,
      qrData: nodeUrl,
      infoText: context.l10n.nodeDetailQrInfoText(
        node.nodeNum.toRadixString(16).toUpperCase(),
      ),
    );
  }

  void _sendDirectMessage(BuildContext context, MeshNode node) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          type: ConversationType.directMessage,
          nodeNum: node.nodeNum,
          title: node.displayName,
          avatarColor: node.avatarColor,
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(BuildContext context, MeshNode node) async {
    if (_isTogglingFavorite) return;
    safeSetState(() => _isTogglingFavorite = true);
    try {
      await toggleNodeFavorite(context, ref, node);
    } finally {
      if (mounted) safeSetState(() => _isTogglingFavorite = false);
    }
  }

  Future<void> _toggleIgnored(BuildContext context, MeshNode node) async {
    if (_isTogglingMute) return;
    safeSetState(() => _isTogglingMute = true);
    try {
      await toggleNodeMute(context, ref, node);
    } finally {
      if (mounted) safeSetState(() => _isTogglingMute = false);
    }
  }

  Future<void> _sendTraceroute(BuildContext context, MeshNode node) async {
    if (_isSendingTraceroute) return;
    safeSetState(() => _isSendingTraceroute = true);
    _lastTracerouteSentAt = DateTime.now();
    try {
      await sendNodeTraceroute(context, ref, node);
    } finally {
      if (mounted) safeSetState(() => _isSendingTraceroute = false);
    }
  }

  void _showTracerouteHistory(BuildContext context, MeshNode node) {
    if (!mounted) return;
    TraceRouteLogScreen.open(context, nodeNum: node.nodeNum);
  }

  /// Requests on-demand telemetry of [type] from [node]. The reload control's
  /// cooldown ring is the busy indicator, so no local busy flag is needed.
  Future<void> _requestTelemetry(
    BuildContext context,
    MeshNode node,
    TelemetryRequestType type,
  ) async {
    await requestNodeTelemetry(context, ref, node, type);
  }

  /// Formats a one-line traceroute summary: transport + hops + SNR.
  String _formatTracerouteSummary(BuildContext context, TraceRouteLog log) {
    final l10n = context.l10n;
    final hops = log.hopsTowards;
    final snr = log.snr;
    final mqtt = log.viaMqtt ?? false;
    final isDirect = hops == 0;

    if (mqtt) {
      if (isDirect && snr != null) {
        return l10n.nodeDetailTracerouteSummaryMqttDirect(
          snr.toStringAsFixed(1),
        );
      }
      if (!isDirect && snr != null) {
        return l10n.nodeDetailTracerouteSummaryMqtt(
          hops,
          snr.toStringAsFixed(1),
        );
      }
    } else {
      if (isDirect && snr != null) {
        return l10n.nodeDetailTracerouteSummaryRfDirect(snr.toStringAsFixed(1));
      }
      if (!isDirect && snr != null) {
        return l10n.nodeDetailTracerouteSummaryRf(hops, snr.toStringAsFixed(1));
      }
    }

    // Fallback: no SNR available
    if (isDirect) return l10n.nodeDetailTracerouteSummaryDirectNoSnr;
    return l10n.nodeDetailTracerouteSummaryHopsOnly(hops);
  }

  Future<void> _showRebootConfirmation(
    BuildContext context,
    MeshNode node,
  ) async {
    final connectionState = ref.read(connectionStateProvider);
    final isConnected = connectionState.maybeWhen(
      data: (state) => state == DeviceConnectionState.connected,
      orElse: () => false,
    );

    if (!isConnected) {
      showErrorSnackBar(context, context.l10n.nodeDetailRebootNotConnected);
      return;
    }

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.nodeDetailRebootTitle,
      message: context.l10n.nodeDetailRebootMessage,
      confirmLabel: context.l10n.nodeDetailRebootConfirm,
      isDestructive: true,
    );

    if (confirmed != true || !mounted) return;

    final protocol = ref.read(protocolServiceProvider);

    try {
      await protocol.reboot();
      if (!mounted) return;
      ref
          .read(countdownProvider.notifier)
          .startDeviceRebootCountdown(reason: 'reboot');
      if (context.mounted) {
        Navigator.pop(context);
        showInfoSnackBar(context, context.l10n.nodeDetailRebootingSnackbar);
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(
          context,
          context.l10n.nodeDetailRebootError(e.toString()),
        );
      }
    }
  }

  Future<void> _showShutdownConfirmation(
    BuildContext context,
    MeshNode node,
  ) async {
    final connectionState = ref.read(connectionStateProvider);
    final isConnected = connectionState.maybeWhen(
      data: (state) => state == DeviceConnectionState.connected,
      orElse: () => false,
    );

    if (!isConnected) {
      showErrorSnackBar(context, context.l10n.nodeDetailShutdownNotConnected);
      return;
    }

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.nodeDetailShutdownTitle,
      message: context.l10n.nodeDetailShutdownMessage,
      confirmLabel: context.l10n.nodeDetailShutdownConfirm,
      isDestructive: true,
    );

    if (confirmed != true || !mounted) return;

    final protocol = ref.read(protocolServiceProvider);

    try {
      await protocol.shutdown();
      if (!mounted) return;
      if (context.mounted) {
        Navigator.pop(context);
        showInfoSnackBar(context, context.l10n.nodeDetailShuttingDownSnackbar);
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(
          context,
          context.l10n.nodeDetailShutdownError(e.toString()),
        );
      }
    }
  }

  Future<void> _removeNode(BuildContext context, MeshNode node) async {
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.nodeDetailRemoveTitle,
      message: context.l10n.nodeDetailRemoveMessage(node.displayName),
      confirmLabel: context.l10n.nodeDetailRemoveConfirm,
      isDestructive: true,
    );

    if (confirmed != true || !mounted) return;

    final protocol = ref.read(protocolServiceProvider);
    final nodesNotifier = ref.read(nodesProvider.notifier);

    try {
      await protocol.removeNode(node.nodeNum);
      if (!mounted) return;
      nodesNotifier.removeNode(node.nodeNum);
      if (context.mounted) {
        Navigator.pop(context);
        showSuccessSnackBar(
          context,
          context.l10n.nodeDetailRemovedSnackbar(node.displayName),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(
          context,
          context.l10n.nodeDetailRemoveError(e.toString()),
        );
      }
    }
  }

  Future<void> _setFixedPosition(BuildContext context, MeshNode node) async {
    final protocol = ref.read(protocolServiceProvider);

    // Remote fixed-position is a PKC admin SET: it needs an authenticated
    // session. If none is ready, prime it and surface a clear diagnostic
    // rather than silently sending a passkey-less admin the node would drop.
    if (!protocol.remoteAdminSessionReady(node.nodeNum)) {
      ref
          .read(remoteAdminProvider.notifier)
          .setTarget(node.nodeNum, node.displayName);
      showWarningSnackBar(
        context,
        context.l10n.nodeDetailRemoteAdminNoSession(node.displayName),
      );
      return;
    }

    final input = await FixedPositionSheet.show(
      context,
      nodeName: node.displayName,
      initialLatitude: node.hasPosition ? node.latitude : null,
      initialLongitude: node.hasPosition ? node.longitude : null,
      initialAltitude: node.altitude,
    );
    if (input == null || !mounted) return;

    try {
      await protocol.setFixedPosition(
        latitude: input.latitude,
        longitude: input.longitude,
        altitude: input.altitude,
        target: AdminTarget.remote(node.nodeNum),
      );
      if (!mounted) return;
      if (context.mounted) {
        showSuccessSnackBar(
          context,
          context.l10n.nodeDetailFixedPositionSet(node.displayName),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(
          context,
          context.l10n.nodeDetailFixedPositionError(e.toString()),
        );
      }
    }
  }

  Future<void> _removeFixedPosition(BuildContext context, MeshNode node) async {
    final protocol = ref.read(protocolServiceProvider);

    if (!protocol.remoteAdminSessionReady(node.nodeNum)) {
      ref
          .read(remoteAdminProvider.notifier)
          .setTarget(node.nodeNum, node.displayName);
      showWarningSnackBar(
        context,
        context.l10n.nodeDetailRemoteAdminNoSession(node.displayName),
      );
      return;
    }

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.nodeDetailRemoveFixedPositionTitle,
      message: context.l10n.nodeDetailRemoveFixedPositionMessage(
        node.displayName,
      ),
      confirmLabel: context.l10n.nodeDetailRemoveFixedPositionConfirm,
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;

    try {
      await protocol.removeFixedPosition(
        target: AdminTarget.remote(node.nodeNum),
      );
      if (!mounted) return;
      if (context.mounted) {
        showSuccessSnackBar(
          context,
          context.l10n.nodeDetailFixedPositionRemoved(node.displayName),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(
          context,
          context.l10n.nodeDetailFixedPositionRemoveError(e.toString()),
        );
      }
    }
  }

  Future<void> _requestUserInfo(BuildContext context, MeshNode node) async {
    final protocol = ref.read(protocolServiceProvider);

    try {
      await protocol.requestNodeInfo(node.nodeNum);
      if (!mounted) return;
      if (context.mounted) {
        showInfoSnackBar(
          context,
          context.l10n.nodeDetailUserInfoRequested(node.displayName),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(
          context,
          context.l10n.nodeDetailUserInfoError(e.toString()),
        );
      }
    }
  }

  void _configureRemotely(BuildContext context, MeshNode node) {
    ref
        .read(remoteAdminProvider.notifier)
        .setTarget(node.nodeNum, node.displayName);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DeviceConfigScreen()),
    );
  }

  void _configureLocally(BuildContext context) {
    ref.read(remoteAdminProvider.notifier).clearTarget();

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DeviceConfigScreen()),
    );
  }

  Future<void> _exchangePositions(BuildContext context, MeshNode node) async {
    final protocol = ref.read(protocolServiceProvider);

    try {
      await protocol.requestPosition(node.nodeNum);
      if (!mounted) return;
      if (context.mounted) {
        showInfoSnackBar(
          context,
          context.l10n.nodeDetailPositionRequested(node.displayName),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(
          context,
          context.l10n.nodeDetailPositionError(e.toString()),
        );
      }
    }
  }

  // ─────────────────────── build helpers ───────────────────────

  /// Whether a node was heard recently enough to be considered online.
  bool _isNodeOnline(MeshNode node) {
    final lastHeard = TimestampValidation.validated(node.lastHeard);
    if (lastHeard == null) return false;
    final age = DateTime.now().difference(lastHeard);
    if (age.isNegative) return false;
    return age.inMinutes < 30;
  }

  /// Human-friendly relative time string for last heard.
  String _relativeLastHeard(BuildContext context, DateTime? lastHeard) {
    final validated = TimestampValidation.validated(lastHeard);
    if (validated == null) return context.l10n.nodeDetailLastHeardNever;
    final diff = DateTime.now().difference(validated);
    if (diff.isNegative || diff.inSeconds < 60) {
      return context.l10n.nodeDetailLastHeardJustNow;
    }
    if (diff.inMinutes < 60) {
      return context.l10n.nodeDetailLastHeardMinutesAgo(diff.inMinutes);
    }
    if (diff.inHours < 24) {
      return context.l10n.nodeDetailLastHeardHoursAgo(diff.inHours);
    }
    if (diff.inDays < 7) {
      return context.l10n.nodeDetailLastHeardDaysAgo(diff.inDays);
    }
    return AppTimeFormat.monthDay(context).format(validated);
  }

  /// Signal quality label from SNR value.
  String _signalLabel(BuildContext context, int? snr) {
    if (snr == null) return context.l10n.nodeDetailSignalUnknown;
    if (snr >= 10) return context.l10n.nodeDetailSignalExcellent;
    if (snr >= 5) return context.l10n.nodeDetailSignalGood;
    if (snr >= 0) return context.l10n.nodeDetailSignalFair;
    if (snr >= -5) return context.l10n.nodeDetailSignalWeak;
    return context.l10n.nodeDetailSignalVeryWeak;
  }

  Color _signalColor(int? snr) {
    if (snr == null) return SemanticColors.disabled;
    if (snr >= 10) return AccentColors.green;
    if (snr >= 5) return AccentColors.green;
    if (snr >= 0) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }

  String _rssiQualityLabel(BuildContext context, int? rssi) {
    if (rssi == null) return context.l10n.nodeDetailSignalUnknown;
    if (rssi >= -50) return context.l10n.nodeDetailSignalExcellent;
    if (rssi >= -65) return context.l10n.nodeDetailSignalGood;
    if (rssi >= -80) return context.l10n.nodeDetailSignalFair;
    if (rssi >= -90) return context.l10n.nodeDetailSignalWeak;
    return context.l10n.nodeDetailSignalVeryWeak;
  }

  Color _rssiQualityColor(int? rssi) {
    if (rssi == null) return SemanticColors.disabled;
    if (rssi >= -65) return AccentColors.green;
    if (rssi >= -80) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }

  Widget _signalValueWithLabel(
    BuildContext context, {
    required String rawValue,
    required String qualityLabel,
    required Color qualityColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          rawValue,
          style: TextStyle(
            fontSize: 14,
            color: context.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: AppTheme.spacing4),
        Text(
          qualityLabel,
          style: TextStyle(
            fontSize: 12,
            color: qualityColor,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.right,
        ),
      ],
    );
  }

  /// Build the hero header with avatar, name, status and stat chips.
  Widget _buildHeroSection(BuildContext context, MeshNode node) {
    final isOnline = _isNodeOnline(node);
    final avatarColor = isMyNode ? context.accentColor : _getAvatarColor(node);

    return Container(
      margin: const EdgeInsets.fromLTRB(AppTheme.spacing16, 8, 16, 4),
      padding: const EdgeInsets.all(AppTheme.spacing20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.card, avatarColor.withValues(alpha: 0.04)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius20),
        border: Border.all(
          color: context.border.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          // Avatar with online indicator
          Stack(
            alignment: Alignment.center,
            children: [
              NodeAvatar(text: node.avatarName, color: avatarColor, size: 80),
              if (isOnline)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AccentColors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.card, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AccentColors.green.withValues(alpha: 0.5),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing14),

          // Name
          AutoScrollText(
            node.displayName,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing4),

          // Hex ID
          Text(
            '!${node.nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.textTertiary,
              fontFamily: AppTheme.fontFamily,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: AppTheme.spacing10),

          // Badges row
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              if (isMyNode)
                _BadgePill(
                  label: context.l10n.nodeDetailYouBadge,
                  color: context.accentColor,
                  filled: true,
                ),
              if (node.role != null && node.role!.isNotEmpty)
                _BadgePill(label: node.role!, color: context.textTertiary),
              _BadgePill(
                icon: node.hasPublicKey ? Icons.lock : Icons.lock_open,
                label: node.hasPublicKey
                    ? context.l10n.nodeDetailPkiBadge
                    : context.l10n.nodeDetailNoPkiBadge,
                color: node.hasPublicKey
                    ? AccentColors.green
                    : context.textTertiary,
              ),
              if (node.isIgnored)
                _BadgePill(
                  icon: Icons.volume_off,
                  label: context.l10n.nodeDetailMutedBadge,
                  color: AppTheme.errorRed,
                ),
              if (node.isFavorite)
                _BadgePill(
                  icon: Icons.star,
                  label: context.l10n.nodeDetailFavoriteBadge,
                  color: AppTheme.warningYellow,
                ),
              // SiteOps operational health (secondary; does not replace the
              // presence/online indicator).
              if (!isMyNode)
                _BadgePill(
                  label: NodeHealthBadge.labelFor(context, node.healthState),
                  color: NodeHealthBadge.colorFor(node.healthState),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing16),

          // Quick stat chips
          _buildStatChipsRow(context, node),
        ],
      ),
    );
  }

  /// Row of compact stat chips below the hero.
  String _formatDistance(BuildContext context, double meters) =>
      formatDistanceMeters(
        meters,
        ref.watch(measurementUnitsProvider),
        context.l10n,
      );

  Widget _buildStatChipsRow(BuildContext context, MeshNode node) {
    final chips = <Widget>[];

    // Last heard
    chips.add(
      _QuickStatChip(
        icon: Icons.access_time,
        value: _relativeLastHeard(context, node.lastHeard),
        color: _isNodeOnline(node) ? AccentColors.green : context.textTertiary,
      ),
    );

    // Battery
    if (node.batteryLevel != null) {
      chips.add(
        _QuickStatChip(
          icon: _getBatteryIcon(node.batteryLevel!),
          value: node.batteryLevel! > 100
              ? context.l10n.nodeDetailBatteryCharging
              : context.l10n.nodeDetailBatteryPercent(node.batteryLevel!),
          color: _getBatteryColor(node.batteryLevel!),
        ),
      );
    }

    // Signal
    if (node.snr != null) {
      chips.add(
        _QuickStatChip(
          icon: Icons.signal_cellular_alt,
          value: _signalLabel(context, node.snr),
          color: _signalColor(node.snr),
        ),
      );
    }

    // Distance
    if (node.distance != null) {
      chips.add(
        _QuickStatChip(
          icon: Icons.near_me,
          value: _formatDistance(context, node.distance!),
          color: context.accentColor,
          onTap: node.hasPosition
              ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MapScreen(initialNodeNum: node.nodeNum),
                  ),
                )
              : null,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: chips,
    );
  }

  /// Build a section with a title header and an InfoTable.
  Widget _buildInfoSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<InfoTableRow> rows,
  }) {
    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: context.accentColor),
              const SizedBox(width: AppTheme.spacing8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: context.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing10),
          InfoTable(rows: rows),
        ],
      ),
    );
  }

  /// Identity section: user ID, hardware, firmware.
  Widget _buildIdentityCard(BuildContext context, MeshNode node) {
    return _buildInfoSection(
      context,
      title: context.l10n.nodeDetailSectionIdentity,
      icon: Icons.badge_outlined,
      rows: [
        if (node.userId != null)
          InfoTableRow(
            icon: Icons.person_outline,
            label: context.l10n.nodeDetailLabelUserId,
            value: node.userId!,
          ),
        if (node.hardwareModel != null)
          InfoTableRow(
            icon: Icons.memory,
            label: context.l10n.nodeDetailLabelHardware,
            value: node.hardwareModel!,
          ),
        if (node.firmwareVersion != null)
          InfoTableRow(
            icon: Icons.system_update,
            label: context.l10n.nodeDetailLabelFirmware,
            value: node.firmwareVersion!,
          ),
        InfoTableRow(
          icon: node.hasPublicKey ? Icons.lock : Icons.lock_open,
          label: context.l10n.nodeDetailLabelEncryption,
          value: node.hasPublicKey
              ? context.l10n.nodeDetailValuePkiEnabled
              : context.l10n.nodeDetailValueNoPublicKey,
          iconColor: node.hasPublicKey
              ? AccentColors.green
              : context.textTertiary,
        ),
        if (node.nodeStatus != null && node.nodeStatus!.isNotEmpty)
          InfoTableRow(
            icon: Icons.info_outline,
            label: context.l10n.nodeDetailLabelStatus,
            value: node.nodeStatus!,
          ),
      ],
    );
  }

  /// NodeDex preview card.
  ///
  /// Surfaces the user's SocialMesh-specific node intelligence (social
  /// tag + free-form note) directly on Node Details so the user does not
  /// have to dig through Overflow > View in NodeDex. The card reads
  /// [nodeDexEntryProvider] — no parallel local state — and dispatches
  /// edits straight to [NodeDexNotifier.setSocialTag]. The full editor
  /// (notes, encounters, classification history) still lives on
  /// NodeDexDetailScreen, reachable via the prominent "Open" trailing
  /// CTA or by tapping anywhere on the card body.
  Widget _buildNodeDexPreviewCard(BuildContext context, MeshNode node) {
    final entry = ref.watch(nodeDexEntryProvider(node.nodeNum));

    void openFullNodeDex() {
      AppLogging.nodes(
        '[NodeDexPreview] open full NodeDex nodeNum=${node.nodeNum} '
        'hasEntry=${entry != null}',
      );
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => NodeDexDetailScreen(nodeNum: node.nodeNum),
        ),
      );
    }

    Future<void> openClassifySheet() async {
      if (entry == null) {
        AppLogging.nodes(
          '[NodeDexPreview] classify tap with no entry - routing to NodeDex '
          'nodeNum=${node.nodeNum}',
        );
        openFullNodeDex();
        return;
      }
      AppLogging.nodes(
        '[NodeDexPreview] classify sheet opened nodeNum=${node.nodeNum} '
        'currentTag=${entry.socialTag?.name ?? 'none'}',
      );
      // Pre-capture the notifier so the post-await callback does not
      // touch ref after the State's BuildContext could be stale, and
      // route the pop through a sheet-local context (Builder).
      final tagNotifier = ref.read(nodeDexProvider.notifier);
      await AppBottomSheet.show<void>(
        context: context,
        child: Builder(
          builder: (sheetContext) => SocialTagSelector(
            currentTag: entry.socialTag,
            onTagSelected: (tag) {
              Navigator.pop(sheetContext);
              tagNotifier.setSocialTag(node.nodeNum, tag);
              AppLogging.nodes(
                '[NodeDexPreview] tag applied nodeNum=${node.nodeNum} '
                'tag=${tag?.name ?? 'cleared'}',
              );
            },
          ),
        ),
      );
    }

    final socialTag = entry?.socialTag;
    final notePreview = entry?.userNote?.trim();
    final hasNote = notePreview != null && notePreview.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: openFullNodeDex,
            borderRadius: BorderRadius.circular(AppTheme.radius8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing4),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: context.accentColor,
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Text(
                    context.l10n.nodeDetailNodeDexSectionTitle.toUpperCase(),
                    style: TextStyle(
                      color: context.textTertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    context.l10n.nodeDetailNodeDexOpenCta.toUpperCase(),
                    style: TextStyle(
                      color: context.accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: context.accentColor,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacing10),
          // Classification + note share a single InfoTable so the
          // note's prose body visually connects to the classification
          // row above (same card outline, single border). Note uses
          // a full-width row variant because long-form text belongs
          // outside the 5:6 two-column layout.
          InfoTable(
            rows: [
              InfoTableRow(
                icon: Icons.label_outline,
                label: context.l10n.nodeDetailNodeDexClassificationLabel,
                value: socialTag != null
                    ? socialTag.displayLabel(context.l10n)
                    : context.l10n.nodeDetailNodeDexNotClassified,
                valueWidget: socialTag != null
                    ? SocialTagBadge(tag: socialTag)
                    : _NodeDexActionChip(
                        icon: Icons.add,
                        label: context.l10n.nodeDetailNodeDexClassifyCta,
                      ),
                onTap: openClassifySheet,
              ),
              InfoTableRow(
                icon: Icons.notes,
                label: context.l10n.nodeDetailNodeDexNoteLabel,
                value: notePreview ?? '',
                helpSheetBuilder: (ctx) =>
                    const NodeDexHelpSheetBody(helpKey: 'note'),
                headerTrailing: hasNote
                    ? _NoteSectionPencilButton(
                        onTap: () {
                          AppLogging.nodes(
                            '[NodeDexPreview] note editor opened '
                            'nodeNum=${node.nodeNum} hasNote=$hasNote',
                          );
                          NodeNoteEditSheet.show(
                            context: context,
                            nodeNum: node.nodeNum,
                            initialNote: entry?.userNote,
                          );
                        },
                      )
                    : null,
                fullWidthContent: hasNote
                    ? Text(
                        notePreview,
                        style: TextStyle(
                          fontSize: 14,
                          color: context.textPrimary,
                          height: 1.5,
                        ),
                      )
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            AppLogging.nodes(
                              '[NodeDexPreview] note editor opened '
                              'nodeNum=${node.nodeNum} hasNote=$hasNote',
                            );
                            NodeNoteEditSheet.show(
                              context: context,
                              nodeNum: node.nodeNum,
                              initialNote: entry?.userNote,
                            );
                          },
                          child: _NodeDexActionChip(
                            icon: Icons.add,
                            label: context.l10n.nodeDetailNodeDexAddNoteCta,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Radio / signal section: RSSI, SNR, noise floor, position.
  Widget _buildRadioCard(BuildContext context, MeshNode node) {
    return _buildInfoSection(
      context,
      title: context.l10n.nodeDetailSectionRadio,
      icon: Icons.cell_tower,
      rows: [
        if (node.rssi != null)
          InfoTableRow(
            icon: Icons.signal_cellular_alt,
            label: context.l10n.nodeDetailLabelRssi,
            value: context.l10n.nodeDetailValueRssi(node.rssi!),
            valueWidget: _signalValueWithLabel(
              context,
              rawValue: context.l10n.nodeDetailValueRssi(node.rssi!),
              qualityLabel: _rssiQualityLabel(context, node.rssi),
              qualityColor: _rssiQualityColor(node.rssi),
            ),
          ),
        if (node.snr != null)
          InfoTableRow(
            icon: Icons.wifi,
            label: context.l10n.nodeDetailLabelSnr,
            value: context.l10n.nodeDetailValueSnr(node.snr.toString()),
            valueWidget: _signalValueWithLabel(
              context,
              rawValue: context.l10n.nodeDetailValueSnr(node.snr.toString()),
              qualityLabel: _signalLabel(context, node.snr),
              qualityColor: _signalColor(node.snr),
            ),
          ),
        if (node.noiseFloor != null)
          InfoTableRow(
            icon: Icons.graphic_eq,
            label: context.l10n.nodeDetailLabelNoiseFloor,
            value: context.l10n.nodeDetailValueNoiseFloor(node.noiseFloor!),
          ),
        if (node.distance != null)
          InfoTableRow(
            icon: Icons.near_me,
            label: context.l10n.nodeDetailLabelDistance,
            value: _formatDistance(context, node.distance!),
            onTap: node.hasPosition
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MapScreen(initialNodeNum: node.nodeNum),
                    ),
                  )
                : null,
          ),
        if (node.hasPosition)
          InfoTableRow(
            icon: Icons.location_on,
            label: context.l10n.nodeDetailLabelPosition,
            value:
                '${node.latitude!.toStringAsFixed(5)}, ${node.longitude!.toStringAsFixed(5)}',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MapScreen(initialNodeNum: node.nodeNum),
              ),
            ),
          ),
        if (node.altitude != null)
          InfoTableRow(
            icon: Icons.height,
            label: context.l10n.nodeDetailLabelAltitude,
            value: context.l10n.nodeDetailValueAltitude(node.altitude!),
          ),
      ],
    );
  }

  /// Device metrics section: battery, voltage, channel util, air util, uptime.
  Widget _buildDeviceMetricsCard(BuildContext context, MeshNode node) {
    return _buildInfoSection(
      context,
      title: context.l10n.nodeDetailSectionDeviceMetrics,
      icon: Icons.developer_board,
      rows: [
        if (node.batteryLevel != null)
          InfoTableRow(
            icon: _getBatteryIcon(node.batteryLevel!),
            iconColor: _getBatteryColor(node.batteryLevel!),
            label: context.l10n.nodeDetailLabelBattery,
            value: node.batteryLevel! > 100
                ? context.l10n.nodeDetailBatteryCharging
                : context.l10n.nodeDetailBatteryPercent(node.batteryLevel!),
          ),
        if (node.voltage != null)
          InfoTableRow(
            icon: Icons.battery_charging_full,
            label: context.l10n.nodeDetailLabelVoltage,
            value: context.l10n.nodeDetailValueVoltage(
              node.voltage!.toStringAsFixed(2),
            ),
          ),
        if (node.channelUtilization != null)
          InfoTableRow(
            icon: Icons.wifi_tethering,
            label: context.l10n.nodeDetailLabelChannelUtil,
            value: context.l10n.nodeDetailValuePercent(
              node.channelUtilization!.toStringAsFixed(1),
            ),
          ),
        if (node.airUtilTx != null)
          InfoTableRow(
            icon: Icons.cell_tower,
            label: context.l10n.nodeDetailLabelAirUtilTx,
            value: context.l10n.nodeDetailValuePercent(
              node.airUtilTx!.toStringAsFixed(1),
            ),
          ),
        if (node.uptimeSeconds != null)
          InfoTableRow(
            icon: Icons.timer,
            label: context.l10n.nodeDetailLabelUptime,
            value: formatUptime(node.uptimeSeconds!),
          ),
      ],
    );
  }

  /// Telemetry history section: links to per-node log screens for every
  /// telemetry category that has recorded data for this node.
  ///
  /// Hides categories with no recorded data so the section stays compact —
  /// an empty air-quality entry on a battery-only node would be noise.
  /// Returns [SizedBox.shrink] when the node has no telemetry at all.
  Widget _buildTelemetrySection(BuildContext context, MeshNode node) {
    final l10n = context.l10n;
    final nodeNum = node.nodeNum;

    final hasDevice =
        ref.watch(nodeDeviceMetricsLogsProvider(nodeNum)).value?.isNotEmpty ??
        false;
    final hasEnv =
        ref
            .watch(nodeEnvironmentMetricsLogsProvider(nodeNum))
            .value
            ?.isNotEmpty ??
        false;
    final hasAir =
        ref
            .watch(nodeAirQualityMetricsLogsProvider(nodeNum))
            .value
            ?.isNotEmpty ??
        false;
    final hasPower =
        ref.watch(nodePowerMetricsLogsProvider(nodeNum)).value?.isNotEmpty ??
        false;
    final hasPosition =
        ref.watch(nodePositionLogsProvider(nodeNum)).value?.isNotEmpty ?? false;
    final hasTraceroute =
        ref.watch(nodeTraceRouteLogsProvider(nodeNum)).value?.isNotEmpty ??
        false;
    final hasPax =
        ref.watch(nodePaxCounterLogsProvider(nodeNum)).value?.isNotEmpty ??
        false;
    final hasDetection =
        ref.watch(nodeDetectionSensorLogsProvider(nodeNum)).value?.isNotEmpty ??
        false;

    final tiles = <Widget>[];

    // Device / Environment / Air Quality are requestable on demand. For a
    // remote node the row is always shown with a reload control so the user
    // can pull telemetry the node no longer broadcasts by default (firmware
    // 2.7.13+). For My Node the row only appears when data exists and has no
    // reload — you cannot request your own telemetry over the mesh.
    void addRequestable({
      required bool hasData,
      required IconData icon,
      required String label,
      required TelemetryRequestType type,
      required VoidCallback onOpen,
    }) {
      if (isMyNode) {
        if (hasData) {
          tiles.add(_TelemetryNavTile(icon: icon, label: label, onTap: onOpen));
        }
        return;
      }
      tiles.add(
        _RequestableTelemetryTile(
          icon: icon,
          label: label,
          nodeNum: nodeNum,
          type: type,
          hasData: hasData,
          onOpen: hasData ? onOpen : null,
          onRequest: () => _requestTelemetry(context, node, type),
        ),
      );
    }

    addRequestable(
      hasData: hasDevice,
      icon: Icons.battery_charging_full,
      label: l10n.settingsTileDeviceMetricsTitle,
      type: TelemetryRequestType.device,
      onOpen: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => DeviceMetricsLogScreen(nodeNum: nodeNum),
        ),
      ),
    );
    addRequestable(
      hasData: hasEnv,
      icon: Icons.thermostat,
      label: l10n.settingsTileEnvironmentMetricsTitle,
      type: TelemetryRequestType.environment,
      onOpen: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => EnvironmentMetricsLogScreen(nodeNum: nodeNum),
        ),
      ),
    );
    addRequestable(
      hasData: hasAir,
      icon: Icons.air,
      label: l10n.settingsTileAirQualityTitle,
      type: TelemetryRequestType.airQuality,
      onOpen: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => AirQualityLogScreen(nodeNum: nodeNum),
        ),
      ),
    );
    if (hasPower) {
      tiles.add(
        _TelemetryNavTile(
          icon: Icons.bolt,
          label: l10n.settingsTilePowerMetricsTitle,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => PowerMetricsLogScreen(nodeNum: nodeNum),
            ),
          ),
        ),
      );
    }

    // Position / Traceroute / PAX / Detection are not telemetry-module
    // requests — they keep their existing "shown only when data exists"
    // behavior (Position has Exchange Positions; Traceroute has its own
    // button).
    if (hasPosition) {
      tiles.add(
        _TelemetryNavTile(
          icon: Icons.location_on_outlined,
          label: l10n.settingsTilePositionHistoryTitle,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => PositionLogScreen(initialNodeNum: nodeNum),
            ),
          ),
        ),
      );
    }
    if (hasTraceroute) {
      tiles.add(
        _TelemetryNavTile(
          icon: Icons.timeline,
          label: l10n.settingsTileTracerouteHistoryTitle,
          onTap: () => TraceRouteLogScreen.open(context, nodeNum: nodeNum),
        ),
      );
    }
    if (hasPax) {
      tiles.add(
        _TelemetryNavTile(
          icon: Icons.people_alt_outlined,
          label: l10n.settingsTilePaxCounterLogsTitle,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => PaxCounterLogScreen(nodeNum: nodeNum),
            ),
          ),
        ),
      );
    }
    if (hasDetection) {
      tiles.add(
        _TelemetryNavTile(
          icon: Icons.sensors,
          label: l10n.settingsTileDetectionSensorLogsTitle,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => DetectionSensorLogScreen(nodeNum: nodeNum),
            ),
          ),
        ),
      );
    }

    if (tiles.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, size: 16, color: context.accentColor),
              const SizedBox(width: AppTheme.spacing8),
              Text(
                l10n.nodeDetailSectionTelemetry.toUpperCase(),
                style: TextStyle(
                  color: context.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing10),
          Container(
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: tiles),
          ),
        ],
      ),
    );
  }

  /// Network stats section: packets, node counts.
  Widget _buildNetworkStatsCard(BuildContext context, MeshNode node) {
    return _buildInfoSection(
      context,
      title: context.l10n.nodeDetailSectionNetwork,
      icon: Icons.bar_chart,
      rows: [
        if (node.numPacketsTx != null)
          InfoTableRow(
            icon: Icons.upload,
            label: context.l10n.nodeDetailLabelPacketsTx,
            value: '${node.numPacketsTx}',
          ),
        if (node.numPacketsRx != null)
          InfoTableRow(
            icon: Icons.download,
            label: context.l10n.nodeDetailLabelPacketsRx,
            value: '${node.numPacketsRx}',
          ),
        if (node.numPacketsRxBad != null)
          InfoTableRow(
            icon: Icons.error_outline,
            label: context.l10n.nodeDetailLabelBadPackets,
            value: '${node.numPacketsRxBad}',
          ),
        if (node.numOnlineNodes != null)
          InfoTableRow(
            icon: Icons.people,
            label: context.l10n.nodeDetailLabelOnlineNodes,
            value: '${node.numOnlineNodes}',
          ),
        if (node.numTotalNodes != null)
          InfoTableRow(
            icon: Icons.groups,
            label: context.l10n.nodeDetailLabelTotalNodes,
            value: '${node.numTotalNodes}',
          ),
        if (node.numTxDropped != null)
          InfoTableRow(
            icon: Icons.block,
            label: context.l10n.nodeDetailLabelTxDropped,
            value: '${node.numTxDropped}',
          ),
      ],
    );
  }

  /// Traffic management section.
  Widget _buildTrafficCard(BuildContext context, MeshNode node) {
    return _buildInfoSection(
      context,
      title: context.l10n.nodeDetailSectionTraffic,
      icon: Icons.traffic,
      rows: [
        if (node.tmPacketsInspected != null)
          InfoTableRow(
            icon: Icons.search,
            label: context.l10n.nodeDetailLabelInspected,
            value: '${node.tmPacketsInspected}',
          ),
        if (node.tmPositionDedupDrops != null)
          InfoTableRow(
            icon: Icons.filter_alt,
            label: context.l10n.nodeDetailLabelPositionDedup,
            value: '${node.tmPositionDedupDrops}',
          ),
        if (node.tmNodeinfoCacheHits != null)
          InfoTableRow(
            icon: Icons.cached,
            label: context.l10n.nodeDetailLabelCacheHits,
            value: '${node.tmNodeinfoCacheHits}',
          ),
        if (node.tmRateLimitDrops != null)
          InfoTableRow(
            icon: Icons.speed,
            label: context.l10n.nodeDetailLabelRateLimitDrops,
            value: '${node.tmRateLimitDrops}',
          ),
        if (node.tmUnknownPacketDrops != null)
          InfoTableRow(
            icon: Icons.help_outline,
            label: context.l10n.nodeDetailLabelUnknownDrops,
            value: '${node.tmUnknownPacketDrops}',
          ),
        if (node.tmHopExhaustedPackets != null)
          InfoTableRow(
            icon: Icons.do_not_disturb,
            label: context.l10n.nodeDetailLabelHopExhausted,
            value: '${node.tmHopExhaustedPackets}',
          ),
        if (node.tmRouterHopsPreserved != null)
          InfoTableRow(
            icon: Icons.route,
            label: context.l10n.nodeDetailLabelHopsPreserved,
            value: '${node.tmRouterHopsPreserved}',
          ),
      ],
    );
  }

  /// Bottom action bar buttons.
  Widget _buildActionButtons(BuildContext context, MeshNode node) {
    if (isMyNode) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showRebootConfirmation(context, node),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.warningYellow,
                side: BorderSide(
                  color: AppTheme.warningYellow.withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
              ),
              icon: const Icon(Icons.restart_alt, size: 20),
              label: Text(
                context.l10n.nodeDetailRebootButton,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showShutdownConfirmation(context, node),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorRed,
                side: BorderSide(
                  color: AppTheme.errorRed.withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
              ),
              icon: const Icon(Icons.power_settings_new, size: 20),
              label: Text(
                context.l10n.nodeDetailShutdownButton,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        // Favorite
        _ActionIconButton(
          isLoading: _isTogglingFavorite,
          loadingColor: AppTheme.warningYellow,
          onPressed: () => _toggleFavorite(context, node),
          icon: node.isFavorite ? Icons.star : Icons.star_border,
          iconColor: node.isFavorite
              ? AppTheme.warningYellow
              : context.textSecondary,
          tooltip: node.isFavorite
              ? context.l10n.nodeDetailRemoveFromFavoritesTooltip
              : context.l10n.nodeDetailAddToFavoritesTooltip,
        ),
        const SizedBox(width: AppTheme.spacing8),
        // Mute
        _ActionIconButton(
          isLoading: _isTogglingMute,
          loadingColor: AppTheme.errorRed,
          onPressed: () => _toggleIgnored(context, node),
          icon: node.isIgnored ? Icons.volume_off : Icons.volume_up,
          iconColor: node.isIgnored ? AppTheme.errorRed : context.textSecondary,
          tooltip: node.isIgnored
              ? context.l10n.nodeDetailUnmuteTooltip
              : context.l10n.nodeDetailMuteTooltip,
        ),
        const SizedBox(width: AppTheme.spacing8),
        // Traceroute
        _TracerouteButton(
          node: node,
          isSending: _isSendingTraceroute,
          onPressed: () => _sendTraceroute(context, node),
        ),
        const SizedBox(width: AppTheme.spacing8),
        // Message button
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _sendDirectMessage(context, node),
            icon: const Icon(Icons.message, size: 20),
            label: Text(context.l10n.nodeDetailMessageButton),
            style: FilledButton.styleFrom(
              backgroundColor: context.accentColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────── build ───────────────────────

  @override
  Widget build(BuildContext context) {
    // Watch the nodes provider to get latest state
    final nodesMap = ref.watch(nodesProvider);
    final node = nodesMap[_initialNode.nodeNum] ?? _initialNode;

    // Listen for new traceroute results and show a one-time summary popup.
    ref.listen<AsyncValue<List<TraceRouteLog>>>(
      nodeTraceRouteLogsProvider(node.nodeNum),
      (prev, next) {
        final logs = next.value;
        if (logs == null || logs.isEmpty) return;

        // Find the most recent completed result
        final latest = logs.firstWhere(
          (l) => l.response,
          orElse: () => logs.first,
        );
        if (!latest.response) return;

        // Ignore late-arriving responses from previous traceroute requests.
        // The mesh has no request-response correlation, so a response that
        // arrives after a new request was sent likely belongs to the old one.
        if (_lastTracerouteSentAt != null &&
            latest.timestamp.isBefore(_lastTracerouteSentAt!)) {
          return;
        }

        // On the initial data load — whether prev was null (provider not yet
        // observed) or prev had no value (AsyncLoading → AsyncData) — seed
        // the dedup ID so pre-existing DB entries never trigger a snackbar.
        if (prev == null || !prev.hasValue) {
          _lastShownTracerouteId = latest.id;
          return;
        }

        if (latest.id == _lastShownTracerouteId) return;

        _lastShownTracerouteId = latest.id;

        if (!mounted) return;
        final l10n = context.l10n;
        final summary = _formatTracerouteSummary(context, latest);
        showActionSnackBar(
          context,
          '${l10n.nodeDetailTracerouteComplete}\n$summary',
          actionLabel: l10n.nodeDetailTracerouteViewDetails,
          onAction: () => _showTracerouteHistory(context, node),
          type: SnackBarType.success,
          duration: const Duration(seconds: 6),
        );
        HapticFeedback.mediumImpact();
      },
    );

    return GlassScaffold(
      controller: _scrollController,
      titleWidget: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _showAppBarIdentity
            ? Row(
                key: const ValueKey('identity'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  NodeAvatar(
                    text: node.avatarName,
                    color: isMyNode
                        ? context.accentColor
                        : _getAvatarColor(node),
                    size: 28,
                  ),
                  const SizedBox(width: AppTheme.spacing10),
                  Flexible(
                    child: Text(
                      node.displayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            : Text(
                key: const ValueKey('title'),
                context.l10n.nodeDetailAppBarTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: context.background,
            border: Border(
              top: BorderSide(color: context.border.withValues(alpha: 0.2)),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 12, 16, 12),
          child: _buildActionButtons(context, node),
        ),
      ),
      actions: [
        // Sigil card button
        IconButton(
          onPressed: () => _shareSigilCard(context, node),
          icon: Icon(Icons.auto_awesome_outlined, color: context.textSecondary),
          tooltip: context.l10n.nodeDetailSigilCardTooltip,
        ),
        // Overflow menu
        AppBarOverflowMenu<String>(
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'qr',
              child: ListTile(
                leading: Icon(Icons.qr_code, color: context.accentColor),
                title: Text(context.l10n.nodeDetailMenuQrCode),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            if (node.hasPosition)
              PopupMenuItem(
                value: 'map',
                child: ListTile(
                  leading: Icon(Icons.map, color: context.accentColor),
                  title: Text(context.l10n.nodeDetailMenuShowOnMap),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            PopupMenuItem(
              value: 'nodedex',
              child: ListTile(
                leading: Icon(Icons.auto_awesome, color: context.accentColor),
                title: Text(context.l10n.nodeDetailMenuViewInNodeDex),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            if (isMyNode)
              PopupMenuItem(
                value: 'device_settings',
                child: ListTile(
                  leading: Icon(Icons.tune, color: context.accentColor),
                  title: Text(context.l10n.nodeDetailMenuDeviceSettings),
                  subtitle: Text(
                    context.l10n.nodeDetailMenuDeviceSettingsSubtitle,
                    style: TextStyle(fontSize: 11, color: context.textTertiary),
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            if (!isMyNode) ...[
              PopupMenuItem(
                value: 'traceroute_history',
                child: ListTile(
                  leading: Icon(Icons.timeline, color: context.accentColor),
                  title: Text(context.l10n.nodeDetailMenuTracerouteHistory),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'request_info',
                child: ListTile(
                  leading: Icon(Icons.refresh, color: context.accentColor),
                  title: Text(context.l10n.nodeDetailMenuRequestUserInfo),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'exchange_positions',
                child: ListTile(
                  leading: Icon(Icons.swap_horiz, color: context.accentColor),
                  title: Text(context.l10n.nodeDetailMenuExchangePositions),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (node.hasPublicKey) ...[
                PopupMenuItem(
                  value: 'fixed_position',
                  child: ListTile(
                    leading: Icon(
                      Icons.location_on,
                      color: context.accentColor,
                    ),
                    title: Text(context.l10n.nodeDetailMenuSetFixedPosition),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'remove_fixed_position',
                  child: ListTile(
                    leading: Icon(
                      Icons.location_off,
                      color: context.accentColor,
                    ),
                    title: Text(context.l10n.nodeDetailMenuRemoveFixedPosition),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
              if (node.hasPublicKey)
                PopupMenuItem(
                  value: 'admin_settings',
                  child: ListTile(
                    leading: Icon(
                      Icons.admin_panel_settings,
                      color: context.accentColor,
                    ),
                    title: Text(context.l10n.nodeDetailMenuAdminSettings),
                    subtitle: Text(
                      context.l10n.nodeDetailMenuAdminSubtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textTertiary,
                      ),
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'remove',
                child: ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: AppTheme.errorRed,
                  ),
                  title: Text(
                    context.l10n.nodeDetailMenuRemoveNode,
                    style: const TextStyle(color: AppTheme.errorRed),
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ],
          onSelected: (value) {
            HapticFeedback.selectionClick();
            switch (value) {
              case 'qr':
                _showNodeQrCode(context, node);
              case 'map':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MapScreen(initialNodeNum: node.nodeNum),
                  ),
                );
              case 'nodedex':
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => NodeDexDetailScreen(nodeNum: node.nodeNum),
                  ),
                );
              case 'device_settings':
                _configureLocally(context);
              case 'traceroute_history':
                _showTracerouteHistory(context, node);
              case 'request_info':
                _requestUserInfo(context, node);
              case 'exchange_positions':
                _exchangePositions(context, node);
              case 'fixed_position':
                _setFixedPosition(context, node);
              case 'remove_fixed_position':
                _removeFixedPosition(context, node);
              case 'admin_settings':
                _configureRemotely(context, node);
              case 'remove':
                _removeNode(context, node);
            }
          },
        ),
      ],
      slivers: [
        // ── Hero section ──
        SliverToBoxAdapter(child: _buildHeroSection(context, node)),

        // ── Identity card ──
        SliverToBoxAdapter(child: _buildIdentityCard(context, node)),

        // ── NodeDex preview (classification + note + open CTA) ──
        SliverToBoxAdapter(child: _buildNodeDexPreviewCard(context, node)),

        // ── Radio card ──
        SliverToBoxAdapter(child: _buildRadioCard(context, node)),

        // ── Node groups (user-defined organisation) ──
        SliverToBoxAdapter(
          child: NodeGroupsCard(
            nodeNum: node.nodeNum,
            nodeName: node.displayName,
          ),
        ),

        // ── Device metrics card ──
        SliverToBoxAdapter(child: _buildDeviceMetricsCard(context, node)),

        // ── Telemetry history links (per-node log screens) ──
        SliverToBoxAdapter(child: _buildTelemetrySection(context, node)),

        // ── Network stats card ──
        SliverToBoxAdapter(child: _buildNetworkStatsCard(context, node)),

        // ── Traffic management card ──
        SliverToBoxAdapter(child: _buildTrafficCard(context, node)),

        // Last heard timestamp at the bottom
        if (TimestampValidation.isPlausible(node.lastHeard))
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 12, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.access_time,
                    size: 12,
                    color: context.textTertiary,
                  ),
                  const SizedBox(width: AppTheme.spacing4),
                  Text(
                    context.l10n.nodeDetailLastHeardTimestamp(
                      AppTimeFormat.fullDateAndTime(
                        context,
                      ).format(node.lastHeard!),
                    ),
                    style: TextStyle(fontSize: 11, color: context.textTertiary),
                  ),
                ],
              ),
            ),
          ),

        // Bottom padding so content isn't hidden behind the fixed bottom bar
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ),
      ],
    );
  }
}

// ─────────────────────── small widgets ───────────────────────

class _TelemetryNavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TelemetryNavTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Wrap the InkWell in a transparent Material so the ripple paints
    // on a surface that lives INSIDE the parent Container's clip
    // region. Without this, the InkWell hunts up the tree for the
    // nearest Material — which is the Scaffold's root Material above
    // the clipped card — and the splash bleeds past the card's
    // rounded corners on long-press.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: 12,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: context.textSecondary),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.textPrimary,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: context.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// A telemetry tile that can be requested on demand. Mirrors
/// [_TelemetryNavTile] but adds a trailing reload control that pulls fresh
/// telemetry of [type] from the node. Tapping the row body opens the log
/// screen only when [onOpen] is non-null (i.e. data already exists);
/// otherwise the row is request-only.
class _RequestableTelemetryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int nodeNum;
  final TelemetryRequestType type;
  final bool hasData;
  final VoidCallback? onOpen;
  final VoidCallback onRequest;

  const _RequestableTelemetryTile({
    required this.icon,
    required this.label,
    required this.nodeNum,
    required this.type,
    required this.hasData,
    required this.onOpen,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing4,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: context.textSecondary),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.textPrimary,
                  ),
                ),
              ),
              _TelemetryReloadButton(
                nodeNum: nodeNum,
                type: type,
                tooltip: context.l10n.nodeDetailTelemetryRequestTooltip(label),
                onPressed: onRequest,
              ),
              if (hasData) ...[
                const SizedBox(width: AppTheme.spacing4),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: context.textTertiary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Trailing reload control for [_RequestableTelemetryTile]. Watches the
/// per-(node, type) telemetry request cooldown and renders either an idle
/// refresh icon or a countdown ring with the remaining seconds, mirroring
/// [_TracerouteButton]'s cooldown affordance.
class _TelemetryReloadButton extends ConsumerWidget {
  final int nodeNum;
  final TelemetryRequestType type;
  final String tooltip;
  final VoidCallback onPressed;

  const _TelemetryReloadButton({
    required this.nodeNum,
    required this.type,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cooldownId = CountdownNotifier.telemetryRequestId(nodeNum, type);
    final task = ref.watch(countdownProvider)[cooldownId];
    final cooldownRemaining = task?.remainingSeconds ?? 0;
    final cooldownTotal =
        task?.totalSeconds ?? CountdownNotifier.telemetryRequestSeconds;

    if (cooldownRemaining > 0) {
      return Tooltip(
        message: context.l10n.nodeDetailTelemetryRequestCooldownTooltip(
          cooldownRemaining,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing8),
          child: SizedBox(
            width: 20,
            height: 20,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    value: cooldownTotal > 0
                        ? cooldownRemaining / cooldownTotal
                        : 0,
                    strokeWidth: 2,
                    color: context.accentColor.withValues(alpha: 0.4),
                    backgroundColor: context.textTertiary.withValues(
                      alpha: 0.15,
                    ),
                  ),
                ),
                Text(
                  '$cooldownRemaining',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: context.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return IconButton(
      onPressed: onPressed,
      icon: Icon(Icons.refresh, color: context.textSecondary, size: 20),
      tooltip: tooltip,
      padding: const EdgeInsets.all(AppTheme.spacing8),
      constraints: const BoxConstraints(),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final bool isLoading;
  final Color loadingColor;
  final VoidCallback onPressed;
  final IconData icon;
  final Color iconColor;
  final String tooltip;

  const _ActionIconButton({
    required this.isLoading,
    required this.loadingColor,
    required this.onPressed,
    required this.icon,
    required this.iconColor,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.border),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: isLoading
          ? Padding(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: loadingColor,
                ),
              ),
            )
          : IconButton(
              onPressed: onPressed,
              icon: Icon(icon, color: iconColor, size: 22),
              tooltip: tooltip,
              padding: const EdgeInsets.all(AppTheme.spacing12),
              constraints: const BoxConstraints(),
            ),
    );
  }
}

class _TracerouteButton extends ConsumerWidget {
  final MeshNode node;
  final bool isSending;
  final VoidCallback onPressed;

  const _TracerouteButton({
    required this.node,
    required this.isSending,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cooldownTask = ref.watch(activeTracerouteProvider);
    final cooldownRemaining = cooldownTask?.remainingSeconds ?? 0;
    final cooldownTotal =
        cooldownTask?.totalSeconds ??
        CountdownNotifier.tracerouteCooldownSeconds;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.border),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: isSending
          ? Padding(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.accentColor,
                ),
              ),
            )
          : cooldownRemaining > 0
          ? Tooltip(
              message: context.l10n.nodeDetailTracerouteCooldownTooltip(
                cooldownRemaining,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing12),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          value: cooldownTotal > 0
                              ? cooldownRemaining / cooldownTotal
                              : 0,
                          strokeWidth: 2,
                          color: context.accentColor.withValues(alpha: 0.4),
                          backgroundColor: context.textTertiary.withValues(
                            alpha: 0.15,
                          ),
                        ),
                      ),
                      Text(
                        '$cooldownRemaining',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : IconButton(
              onPressed: onPressed,
              icon: Icon(Icons.route, color: context.textSecondary, size: 22),
              tooltip: context.l10n.nodeDetailTracerouteTooltip,
              padding: const EdgeInsets.all(AppTheme.spacing12),
              constraints: const BoxConstraints(),
            ),
    );
  }
}

/// Small pill badge for role, PKI status, favorite, muted, etc.
class _BadgePill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;

  const _BadgePill({
    required this.label,
    required this.color,
    this.icon,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: filled ? Colors.white : color),
            const SizedBox(width: AppTheme.spacing4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: filled ? Colors.white : color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact stat chip for the hero section quick-reference row.
class _QuickStatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _QuickStatChip({
    required this.icon,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: AppTheme.spacing5),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap!();
      },
      child: chip,
    );
  }
}

/// Inline pill rendered in the NodeDex preview row when no value is set yet
/// (no social tag, no note). Mirrors [SocialTagBadge]'s non-compact shape so
/// classified + unclassified rows stay in the same visual family. Tap is
/// handled by the enclosing [InfoTable] row's `onTap`.
class _NodeDexActionChip extends StatelessWidget {
  const _NodeDexActionChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = context.accentColor;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing10,
        vertical: AppTheme.spacing5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radius14),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: AppTheme.spacing5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small inline pencil button rendered on the Note SectionTitle row
/// in the Node Details preview when a note exists. Matches the
/// shape, size, and tinting of the standalone NodeDex note card's
/// pencil so the same affordance reads consistently across both
/// surfaces.
class _NoteSectionPencilButton extends StatelessWidget {
  final VoidCallback onTap;

  const _NoteSectionPencilButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.nodedexNoteEdit,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: context.accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.radius8),
          ),
          child: Icon(
            Icons.edit_outlined,
            size: 16,
            color: context.accentColor,
          ),
        ),
      ),
    );
  }
}
