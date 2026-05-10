// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: haptic-feedback — GestureDetector onTap delegates to parent callback

import '../../../core/l10n/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/logging.dart';
import '../../../core/meshcore_constants.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animated_empty_state.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/info_table.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/settings_primitives.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/meshcore_message_providers.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../services/meshcore/protocol/meshcore_messages.dart';
import '../../../utils/snackbar.dart';
import '../../../models/meshcore_contact.dart';
import '../../navigation/meshcore_shell.dart';
import '../contact_l10n.dart';
import '../widgets/meshcore_chat_traffic_card.dart';
import '../widgets/meshcore_radio_stats_card.dart';
import 'meshcore_discovery_screen.dart';
import 'meshcore_frame_log_screen.dart';

/// MeshCore Tools screen.
///
/// Provides access to MeshCore diagnostic and analysis tools.
class MeshCoreToolsScreen extends ConsumerStatefulWidget {
  const MeshCoreToolsScreen({super.key});

  @override
  ConsumerState<MeshCoreToolsScreen> createState() =>
      _MeshCoreToolsScreenState();
}

class _MeshCoreToolsScreenState extends ConsumerState<MeshCoreToolsScreen>
    with LifecycleSafeMixin {
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    AppLogging.meshcore('event=screen.opened name=tools');
  }

  @override
  Widget build(BuildContext context) {
    final linkStatus = ref.watch(linkStatusProvider);
    final isConnected = linkStatus.isConnected;
    final deviceName =
        linkStatus.deviceName ?? context.l10n.meshcoreMeshCoreDevice;
    final selfInfoState = ref.watch(meshCoreSelfInfoProvider);
    final battInfoState = ref.watch(meshCoreBatteryProvider);

    if (!isConnected) {
      return GlassScaffold.body(
        leading: const MeshCoreHamburgerMenuButton(),
        title: context.l10n.meshcoreToolsTitle,
        actions: const [MeshCoreDeviceStatusButton()],
        body: AnimatedEmptyState(
          config: AnimatedEmptyStateConfig(
            icons: const [
              Icons.link_off_rounded,
              Icons.build_outlined,
              Icons.router_outlined,
              Icons.info_outline_rounded,
              Icons.battery_unknown_rounded,
              Icons.settings_input_antenna_rounded,
            ],
            taglines: [
              context.l10n.meshcoreDisconnectedToolsDescription,
              context.l10n.meshcoreViewDeviceInfo,
              context.l10n.meshcoreMonitorPowerStorage,
            ],
            titlePrefix: '',
            titleKeyword: context.l10n.meshcoreDisconnectedToolsTitle,
            titleSuffix: '',
          ),
        ),
      );
    }

    return GlassScaffold.body(
      hasScrollBody: true,
      leading: const MeshCoreHamburgerMenuButton(),
      title: context.l10n.meshcoreToolsTitle,
      actions: const [MeshCoreDeviceStatusButton()],
      body: RefreshIndicator(
        onRefresh: _refreshDeviceInfo,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
          children: [
            // Device Status Card
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing16,
              ),
              child: _buildDeviceStatusCard(
                context,
                deviceName: deviceName,
                selfInfoState: selfInfoState,
                battInfoState: battInfoState,
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),

            // Diagnostics Section
            SettingsSectionHeader(title: context.l10n.meshcoreDiagnostics),
            SettingsTile(
              icon: Icons.info_rounded,
              iconColor: AccentColors.cyan,
              title: context.l10n.meshcoreDeviceInfoTool,
              subtitle: context.l10n.meshcoreViewDeviceInfo,
              trailing: _chevron(context),
              onTap: () => _showDeviceInfo(selfInfoState),
            ),
            SettingsTile(
              icon: Icons.battery_full_rounded,
              iconColor: AccentColors.green,
              title: context.l10n.meshcoreBatteryAndStorage,
              subtitle: context.l10n.meshcoreMonitorPowerStorage,
              trailing: _chevron(context),
              onTap: () => _showBatteryInfo(battInfoState),
            ),
            // D28: Trace Path — wire format observed in upstream and
            // pinned in `parseTraceData`. Tile opens a contact picker
            // sheet, sends `CMD_SEND_TRACE_PATH (0x24)`, and renders the
            // hop list with per-hop SNR after the firmware push arrives.
            SettingsTile(
              icon: Icons.route_rounded,
              iconColor: context.accentColor,
              title: context.l10n.meshcoreTracePath,
              subtitle: context.l10n.meshcoreTracePacketRoutes,
              trailing: _chevron(context),
              onTap: _openTracePath,
            ),
            // D34b-A1: Discovered Nodes — recent-heard feed populated
            // from 0x8A / 0x80 pushes. In-memory only; capped at 100;
            // no autoadd-config dependency.
            SettingsTile(
              key: const ValueKey('meshcore-tools-discovery-tile'),
              icon: Icons.podcasts_rounded,
              iconColor: context.accentColor,
              title: context.l10n.meshcoreToolsDiscoveryTitle,
              subtitle: context.l10n.meshcoreToolsDiscoverySubtitle,
              trailing: _chevron(context),
              onTap: () => openMeshCoreDiscoveryScreen(context),
            ),
            // D28 Part B: Frame Log viewer. Surfaces the in-memory
            // capture infrastructure that already records every TX/RX
            // frame in debug builds. Empty/unavailable empty state when
            // capture is not active.
            SettingsTile(
              icon: Icons.terminal_rounded,
              iconColor: AccentColors.blue,
              title: context.l10n.meshcoreFrameLogTool,
              subtitle: context.l10n.meshcoreFrameLogToolSubtitle,
              trailing: _chevron(context),
              onTap: _openFrameLog,
            ),
            // D28 Part D: queue status card (heartbeat + last-drain
            // outcome + in-progress badge). Sits above the manual
            // drain tile so the user can see the live state before
            // tapping drain.
            const _QueueStatusCard(),
            // D35-A: companion-radio stats card. Polls
            // CMD_GET_STATS / RESP_CODE_STATS / STATS_TYPE_RADIO at
            // 1 Hz while mounted. Bypasses the D34a chat rate
            // limiter; in-memory snapshot only.
            const MeshCoreRadioStatsCard(),
            // D34a: chat-traffic measurement card. Surfaces the
            // rolling 60-s send budget usage, per-kind counts, and
            // peak/last-rejection metadata. In-memory only; no
            // persistence, no remote export. Reactions row is
            // reserved (always 0) until D34b.
            const MeshCoreChatTrafficCard(),
            // D21.B: manual `CMD_SYNC_NEXT_MESSAGE` drain. Recovers a
            // missed `0x83` tickle (firmware queue has data but the
            // companion never got the push, e.g. transport blip).
            // Distinguishes "queue has data, tickle lost" vs "queue
            // has no data". Sends one drain per tap; user can tap
            // again if more messages are pending.
            SettingsTile(
              icon: Icons.cloud_download_rounded,
              iconColor: AccentColors.cyan,
              title: context.l10n.meshcoreDrainQueueTool,
              subtitle: context.l10n.meshcoreDrainQueueToolSubtitle,
              trailing: _chevron(context),
              onTap: _drainMessageQueue,
            ),
            const SizedBox(height: AppTheme.spacing16),

            // Discovery Section. D29 cleanup: the Tools surface owns
            // "do something now" actions. Persistent radio config
            // (region preset + freq/bw/SF/CR/TX power) lives only in
            // Settings → Radio Settings — the previous read-only
            // duplicate here was confusing because it had the same
            // label as the editable sheet but couldn't write.
            SettingsSectionHeader(title: context.l10n.meshcoreDiscovery),
            SettingsTile(
              icon: Icons.radar_rounded,
              iconColor: AccentColors.orange,
              title: context.l10n.meshcoreSendAdvertisementTool,
              subtitle: context.l10n.meshcoreBroadcastPresenceToMesh,
              trailing: _chevron(context),
              onTap: _sendAdvertisement,
            ),
            const SizedBox(height: AppTheme.spacing32),
          ],
        ),
      ),
    );
  }

  /// Right-chevron used as the trailing affordance on action/navigation
  /// tiles. Same shape as [MeshCoreSettingsScreen] so the two screens
  /// look structurally identical.
  Widget _chevron(BuildContext context) =>
      Icon(Icons.chevron_right, color: context.textTertiary);

  Widget _buildDeviceStatusCard(
    BuildContext context, {
    required String deviceName,
    required MeshCoreSelfInfoState selfInfoState,
    required MeshCoreBatteryState battInfoState,
  }) {
    final selfInfo = selfInfoState.selfInfo;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing10),
                decoration: BoxDecoration(
                  color: AccentColors.cyan.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: Icon(
                  Icons.developer_board_rounded,
                  color: AccentColors.cyan,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selfInfo?.nodeName ?? deviceName,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing2),
                    Text(
                      _getDeviceTypeLabel(context, selfInfo),
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isRefreshing || selfInfoState.isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: context.textTertiary,
                  ),
                  onPressed: _refreshDeviceInfo,
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing16),
          Divider(color: context.border),
          const SizedBox(height: AppTheme.spacing12),
          Row(
            children: [
              Expanded(
                child: _buildStatusItem(
                  icon: Icons.battery_charging_full_rounded,
                  label: context.l10n.meshcoreBatteryLabel,
                  value: _getBatteryDisplay(battInfoState),
                  color: _getBatteryColor(battInfoState),
                ),
              ),
              Expanded(
                child: _buildStatusItem(
                  icon: Icons.bolt_rounded,
                  label: context.l10n.meshcoreTxPowerStatusLabel,
                  value: _getTxPowerDisplay(selfInfo),
                  color: AccentColors.orange,
                ),
              ),
              Expanded(
                child: _buildStatusItem(
                  icon: Icons.signal_cellular_alt_rounded,
                  label: context.l10n.meshcoreSfCrLabel,
                  value: _getSfCrDisplay(selfInfo),
                  color: AccentColors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: AppTheme.spacing6),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: AppTheme.spacing2),
        Text(
          label,
          style: TextStyle(color: context.textTertiary, fontSize: 11),
        ),
      ],
    );
  }

  String _getDeviceTypeLabel(BuildContext context, MeshCoreSelfInfo? selfInfo) {
    if (selfInfo == null) return context.l10n.meshcoreMeshCoreDevice;
    switch (selfInfo.advType) {
      case 1:
        return context.l10n.meshcoreChatNode;
      case 2:
        return context.l10n.meshcoreRepeaterNode;
      case 3:
        return context.l10n.meshcoreRoomNode;
      case 4:
        return context.l10n.meshcoreSensorNode;
      default:
        return context.l10n.meshcoreMeshCoreDevice;
    }
  }

  String _getBatteryDisplay(MeshCoreBatteryState battInfo) {
    if (battInfo.isSuccess && battInfo.percentage != null) {
      return '${battInfo.percentage}%';
    }
    if (battInfo.isSuccess && battInfo.voltageMillivolts != null) {
      return '${battInfo.voltageMillivolts}mV';
    }
    return '--';
  }

  Color _getBatteryColor(MeshCoreBatteryState battInfo) {
    final pct = battInfo.percentage;
    if (pct == null) return AccentColors.green;
    if (pct < 20) return AppTheme.errorRed;
    if (pct < 50) return AccentColors.orange;
    return AccentColors.green;
  }

  String _getTxPowerDisplay(MeshCoreSelfInfo? selfInfo) {
    if (selfInfo == null) return '--';
    return '${selfInfo.txPowerDbm}dBm';
  }

  String _getSfCrDisplay(MeshCoreSelfInfo? selfInfo) {
    if (selfInfo == null) return '--';
    final sf = selfInfo.spreadingFactor;
    final cr = selfInfo.codingRate;
    if (sf != null && cr != null) {
      return 'SF$sf/4:$cr';
    }
    if (sf != null) return 'SF$sf';
    return '--';
  }

  Future<void> _refreshDeviceInfo() async {
    safeSetState(() => _isRefreshing = true);
    try {
      ref.invalidate(meshCoreSelfInfoProvider);
      ref.invalidate(meshCoreBatteryProvider);
      await Future.delayed(const Duration(milliseconds: 500));
    } finally {
      safeSetState(() => _isRefreshing = false);
    }
  }

  void _showDeviceInfo(MeshCoreSelfInfoState selfInfoState) {
    final info = selfInfoState.selfInfo;
    if (info == null) {
      showErrorSnackBar(context, context.l10n.meshcoreDeviceInfoNotAvailable);
      return;
    }

    AppBottomSheet.show<void>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: context.l10n.meshcoreDeviceInformation),
          InfoTable(
            rows: [
              InfoTableRow(
                label: context.l10n.meshcoreNameLabel,
                value: info.nodeName.isNotEmpty ? info.nodeName : '-',
                icon: Icons.badge_outlined,
              ),
              InfoTableRow(
                label: context.l10n.meshcoreTypeLabel,
                value: _getDeviceTypeLabel(context, info),
                icon: Icons.category_outlined,
              ),
              InfoTableRow(
                label: context.l10n.meshcoreTxPowerLabel,
                value: '${info.txPowerDbm} dBm',
                icon: Icons.bolt_outlined,
              ),
              InfoTableRow(
                label: context.l10n.meshcoreMaxTxPowerLabel,
                value: '${info.maxLoraTxPower} dBm',
                icon: Icons.power_outlined,
              ),
              if (info.spreadingFactor != null)
                InfoTableRow(
                  label: context.l10n.meshcoreSpreadingFactorLabel,
                  value: 'SF${info.spreadingFactor}',
                  icon: Icons.broadcast_on_personal_outlined,
                ),
              if (info.codingRate != null)
                InfoTableRow(
                  label: context.l10n.meshcoreCodingRateLabel,
                  value: '4/${info.codingRate}',
                  icon: Icons.speed_outlined,
                ),
              if (info.latitude != null && info.longitude != null)
                InfoTableRow(
                  label: context.l10n.meshcoreLocationInfoLabel,
                  value:
                      '${(info.latitude! / 1e7).toStringAsFixed(6)}, '
                      '${(info.longitude! / 1e7).toStringAsFixed(6)}',
                  icon: Icons.place_outlined,
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                final pubKeyHex = info.pubKey
                    .map((b) => b.toRadixString(16).padLeft(2, '0'))
                    .join();
                Clipboard.setData(
                  ClipboardData(
                    text:
                        'Name: ${info.nodeName}\n' // lint-allow: hardcoded-string
                        'TX Power: ${info.txPowerDbm} dBm\n' // lint-allow: hardcoded-string
                        'Public Key: $pubKeyHex', // lint-allow: hardcoded-string
                  ),
                );
                showSuccessSnackBar(
                  context,
                  context.l10n.meshcoreDeviceInfoCopied,
                );
              },
              icon: const Icon(Icons.copy_rounded),
              label: Text(context.l10n.meshcoreCopy),
            ),
          ),
        ],
      ),
    );
  }

  void _showBatteryInfo(MeshCoreBatteryState battInfo) {
    if (!battInfo.isSuccess) {
      showErrorSnackBar(context, context.l10n.meshcoreBatteryInfoNotAvailable);
      return;
    }

    final battPct = battInfo.percentage;
    final battColor = _getBatteryColor(battInfo);

    AppBottomSheet.show<void>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.meshcoreBatteryStatus,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          SizedBox(height: AppTheme.spacing20),

          Row(
            children: [
              Icon(Icons.battery_full_rounded, color: battColor, size: 32),
              SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      battPct != null
                          ? '$battPct%'
                          : '${battInfo.voltageMillivolts}mV',
                      style: TextStyle(
                        color: battColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${context.l10n.meshcoreBatteryStatusLabel} '
                      '${battPct != null && battInfo.voltageMillivolts != null ? '(${battInfo.voltageMillivolts}mV)' : ''}',
                      style: TextStyle(color: context.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (battPct != null) ...[
            SizedBox(height: AppTheme.spacing12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radius4),
              child: LinearProgressIndicator(
                value: battPct / 100,
                backgroundColor: context.background,
                valueColor: AlwaysStoppedAnimation(battColor),
                minHeight: 8,
              ),
            ),
          ],
          SizedBox(height: AppTheme.spacing16),
          StatusBanner.info(
            title: context.l10n.meshcoreBasedOnLiPoVoltage,
            icon: Icons.info_outline_rounded,
          ),
        ],
      ),
    );
  }

  Future<void> _sendAdvertisement() async {
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      showErrorSnackBar(context, context.l10n.meshcoreNotConnectedTools);
      return;
    }

    try {
      // Send self advertisement command
      await session.sendCommand(MeshCoreCommands.sendSelfAdvert);
      if (mounted) {
        showSuccessSnackBar(
          context,
          context.l10n.meshcoreAdvertisementSentTools,
        );
      }
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, context.l10n.meshcoreFailedToSendAdTools);
      }
    }
  }

  /// D21.B + D22: manual `CMD_SYNC_NEXT_MESSAGE` drain. The actual
  /// send / classify / non-overlap-guard logic lives on
  /// [MeshCoreConversationsNotifier.manualDrain] so the heartbeat,
  /// the 0x83 auto-tickle, and this tap all share one drain lock and
  /// one log shape. The tile only maps the classified outcome to a
  /// snackbar.
  Future<void> _drainMessageQueue() async {
    final l10n = context.l10n;
    final outcome = await ref
        .read(meshCoreConversationsProvider.notifier)
        .manualDrain();
    AppLogging.meshcore(
      'event=msg_waiting.drain.manual.result '
      'result=${_outcomeKindName(outcome.kind)}'
      '${outcome.code != null ? ' code=0x${outcome.code!.toRadixString(16).padLeft(2, '0')}' : ''}'
      '${outcome.size != null ? ' size=${outcome.size}' : ''}',
      error:
          outcome.kind == MeshCoreDrainOutcomeKind.timeout ||
          outcome.kind == MeshCoreDrainOutcomeKind.failed,
    );
    if (!mounted) return;
    switch (outcome.kind) {
      case MeshCoreDrainOutcomeKind.message:
        showSuccessSnackBar(context, l10n.meshcoreDrainQueueResultMessage);
        break;
      case MeshCoreDrainOutcomeKind.noMore:
        showSuccessSnackBar(context, l10n.meshcoreDrainQueueResultEmpty);
        break;
      case MeshCoreDrainOutcomeKind.timeout:
      case MeshCoreDrainOutcomeKind.failed:
      case MeshCoreDrainOutcomeKind.skipped:
        showErrorSnackBar(context, l10n.meshcoreDrainQueueFailed);
        break;
    }
  }

  String _outcomeKindName(MeshCoreDrainOutcomeKind k) {
    switch (k) {
      case MeshCoreDrainOutcomeKind.message:
        return 'message';
      case MeshCoreDrainOutcomeKind.noMore:
        return 'no_more';
      case MeshCoreDrainOutcomeKind.timeout:
        return 'timeout';
      case MeshCoreDrainOutcomeKind.skipped:
        return 'skipped';
      case MeshCoreDrainOutcomeKind.failed:
        return 'failed';
    }
  }

  /// D28 Part B: open the MeshCore Frame Log screen.
  void _openFrameLog() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MeshCoreFrameLogScreen()),
    );
  }

  /// D28 Part C: open the Trace Path picker bottom sheet.
  void _openTracePath() {
    HapticFeedback.lightImpact();
    showMeshCoreTracePathSheet(context);
  }
}

/// D28 Part C / D34c-A: top-level launcher for the Trace Path bottom
/// sheet, callable from the Tools tile, the Contact Detail screen, or
/// any future per-contact entry point.
Future<void> showMeshCoreTracePathSheet(BuildContext context) {
  return AppBottomSheet.showScrollable<void>(
    context: context,
    initialChildSize: 0.85,
    minChildSize: 0.5,
    maxChildSize: 0.95,
    builder: (scrollController) =>
        MeshCoreTracePathSheet(scrollController: scrollController),
  );
}

/// D28 Part D: queue-status diagnostic card.
///
/// Renders the drain heartbeat state, the in-flight drain source (if a
/// drain is currently running), and a one-line summary of the most
/// recent drain (`source -> outcome at HH:MM:SS`). Hidden / shown
/// adaptively based on whether anything has happened yet.
///
/// Does NOT claim firmware queue depth — the firmware does not expose
/// it. Copy uses "Last queue check" not "Queue depth" to avoid lying.
class _QueueStatusCard extends ConsumerWidget {
  const _QueueStatusCard();

  String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  String _outcomeLabel(BuildContext context, MeshCoreDrainOutcomeKind kind) {
    final l = context.l10n;
    switch (kind) {
      case MeshCoreDrainOutcomeKind.message:
        return l.meshcoreQueueOutcomeMessage;
      case MeshCoreDrainOutcomeKind.noMore:
        return l.meshcoreQueueOutcomeNoMore;
      case MeshCoreDrainOutcomeKind.timeout:
        return l.meshcoreQueueOutcomeTimeout;
      case MeshCoreDrainOutcomeKind.skipped:
        return l.meshcoreQueueOutcomeSkipped;
      case MeshCoreDrainOutcomeKind.failed:
        return l.meshcoreQueueOutcomeFailed;
    }
  }

  String _sourceLabel(BuildContext context, MeshCoreDrainSource src) {
    final l = context.l10n;
    switch (src) {
      case MeshCoreDrainSource.tickle:
        return l.meshcoreQueueSourceTickle;
      case MeshCoreDrainSource.manual:
        return l.meshcoreQueueSourceManual;
      case MeshCoreDrainSource.heartbeat:
        return l.meshcoreQueueSourceHeartbeat;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(meshCoreConversationsProvider);
    final l = context.l10n;
    final accent = state.heartbeatActive
        ? AccentColors.green
        : context.textTertiary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing8,
        AppTheme.spacing16,
        AppTheme.spacing4,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_sync_rounded, size: 18, color: accent),
                const SizedBox(width: AppTheme.spacing8),
                Expanded(
                  child: Text(
                    l.meshcoreQueueStatusTool,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                  child: Text(
                    state.heartbeatActive
                        ? l.meshcoreQueueStatusHeartbeatActive
                        : l.meshcoreQueueStatusHeartbeatIdle,
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
            if (state.activeDrainSource != null) ...[
              const SizedBox(height: AppTheme.spacing8),
              Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AccentColors.cyan,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Text(
                    l.meshcoreQueueStatusInProgress(
                      _sourceLabel(context, state.activeDrainSource!),
                    ),
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppTheme.spacing8),
            Text(
              l.meshcoreQueueStatusLastCheck,
              style: TextStyle(
                color: context.textTertiary,
                fontSize: 11,
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: AppTheme.spacing4),
            Text(
              state.lastDrainAt == null ||
                      state.lastDrainSource == null ||
                      state.lastDrainOutcome == null
                  ? l.meshcoreQueueStatusNoDrainYet
                  : '${_sourceLabel(context, state.lastDrainSource!)} '
                        '→ ' // arrow
                        '${_outcomeLabel(context, state.lastDrainOutcome!)} '
                        '@ ${_formatTime(state.lastDrainAt!)}',
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 13,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// D28 Part C: Trace Path picker + result bottom sheet.
///
/// Two phases inside one sheet:
/// 1. Picker — user taps a contact (chat or repeater). Sheet locks the
///    target and fires `session.sendTracePath(...)`.
/// 2. Result — once the firmware push arrives (or times out), the sheet
///    swaps to a hop list with per-hop SNR.
class MeshCoreTracePathSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  const MeshCoreTracePathSheet({super.key, required this.scrollController});

  @override
  ConsumerState<MeshCoreTracePathSheet> createState() =>
      _MeshCoreTracePathSheetState();
}

class _MeshCoreTracePathSheetState extends ConsumerState<MeshCoreTracePathSheet>
    with LifecycleSafeMixin<MeshCoreTracePathSheet> {
  MeshCoreContact? _selected;
  MeshCoreContact? _running;
  MeshCoreTraceResult? _result;
  bool _failed = false;
  bool _timedOut = false;

  Future<void> _runTrace() async {
    final target = _selected;
    if (target == null) return;
    safeSetState(() {
      _running = target;
      _result = null;
      _failed = false;
      _timedOut = false;
    });
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      safeSetState(() {
        _failed = true;
        _running = null;
      });
      return;
    }
    // Build path: single byte = first byte of target pubkey, matching
    // the firmware's expectation that the path payload identifies the
    // intermediate hops by their pubkey prefix. Empty path falls back
    // to firmware-default routing; we always pass the target prefix
    // here so the user gets a deterministic "trace to this contact"
    // semantic.
    final path = target.publicKey.isEmpty
        ? Uint8List(0)
        : Uint8List.fromList([target.publicKey[0]]);
    final tag = DateTime.now().millisecondsSinceEpoch & 0xFFFFFFFF;
    try {
      final result = await session.sendTracePath(tag: tag, path: path);
      if (!mounted) return;
      if (result == null) {
        safeSetState(() {
          _timedOut = true;
          _running = null;
        });
      } else {
        safeSetState(() {
          _result = result;
          _running = null;
        });
      }
    } catch (_) {
      if (!mounted) return;
      safeSetState(() {
        _failed = true;
        _running = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final contactsState = ref.watch(meshCoreContactsProvider);
    // Filter to actionable trace targets — chat + repeater. Sensors
    // and rooms aren't useful trace destinations.
    final eligible = contactsState.contacts
        .where((c) => c.isChat || c.isRepeater)
        .toList(growable: false);

    // D31c: shift the body's background to `context.background` so
    // the unselected contact rows (which use `context.card`) pop
    // against the page-like surface, with the same rhythm as
    // full-screen settings.
    return ColoredBox(
      color: context.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              AppTheme.spacing12,
              AppTheme.spacing16,
              AppTheme.spacing8,
            ),
            child: Row(
              children: [
                Icon(Icons.route_rounded, color: context.accentColor, size: 22),
                const SizedBox(width: AppTheme.spacing8),
                Expanded(
                  child: Text(
                    l.meshcoreTracePathTitle,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(AppTheme.spacing16),
              children: [
                if (_result != null)
                  _buildResult(context, _result!)
                else if (_running != null)
                  _buildRunning(context, _running!)
                else if (_failed)
                  StatusBanner.error(
                    title: l.meshcoreTracePathFailed,
                    icon: Icons.error_outline_rounded,
                  )
                else if (_timedOut)
                  StatusBanner.warning(
                    title: l.meshcoreTracePathTimeout,
                    icon: Icons.hourglass_empty_rounded,
                  )
                else
                  _buildPicker(context, eligible),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPicker(BuildContext context, List<MeshCoreContact> eligible) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.meshcoreTracePathPickContact,
          style: TextStyle(
            color: context.textSecondary,
            fontSize: 13,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),
        for (final c in eligible)
          Container(
            margin: const EdgeInsets.only(bottom: AppTheme.spacing4),
            decoration: BoxDecoration(
              color: identical(_selected, c)
                  ? context.accentColor.withValues(alpha: 0.15)
                  : context.card,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            child: ListTile(
              dense: true,
              leading: Icon(
                c.isRepeater ? Icons.cell_tower_rounded : Icons.person_rounded,
                color: identical(_selected, c)
                    ? context.accentColor
                    : context.textSecondary,
              ),
              title: Text(
                c.displayName.isNotEmpty
                    ? c.displayName
                    : l.meshcoreContactUnknownName,
                style: TextStyle(
                  color: context.textPrimary,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
              subtitle: Text(
                c.localizedPathLabel(l),
                style: TextStyle(
                  color: context.textTertiary,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                ),
              ),
              onTap: () => safeSetState(() => _selected = c),
            ),
          ),
        const SizedBox(height: AppTheme.spacing16),
        FilledButton.icon(
          onPressed: _selected == null ? null : _runTrace,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(l.meshcoreTracePathRunButton),
        ),
      ],
    );
  }

  Widget _buildRunning(BuildContext context, MeshCoreContact target) {
    final l = context.l10n;
    final name = target.displayName.isNotEmpty
        ? target.displayName
        : l.meshcoreContactUnknownName;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing24),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppTheme.spacing16),
          Text(
            l.meshcoreTracePathTracing(name),
            style: TextStyle(
              color: context.textSecondary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context, MeshCoreTraceResult result) {
    final l = context.l10n;
    final target = _selected;
    final name = target?.displayName.isNotEmpty == true
        ? target!.displayName
        : l.meshcoreContactUnknownName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.meshcoreTracePathResultHeadline(name),
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        const SizedBox(height: AppTheme.spacing4),
        Text(
          l.meshcoreTracePathHops(result.hops.length),
          style: TextStyle(
            color: context.textTertiary,
            fontSize: 12,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),
        for (var i = 0; i < result.hops.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: AppTheme.spacing4),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing12,
              vertical: AppTheme.spacing8,
            ),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: context.accentColor,
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Text(
                    '0x${result.hops[i].pathByte.toRadixString(16).padLeft(2, '0').toUpperCase()}',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  l.meshcoreSnrLabel(result.hops[i].snrDb.toStringAsFixed(1)),
                  style: TextStyle(
                    color: context.textSecondary,
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppTheme.spacing16),
        // D34c-A: only surface "Save as Contact Path" when the trace
        // returned at least one hop AND we have a target contact in
        // scope (the picker locks `_selected` before firing the trace).
        // Saved paths can become stale as the mesh re-routes; the
        // helper text reminds the user that this is a snapshot, not a
        // permanent route.
        if (target != null && result.hops.isNotEmpty) ...[
          Text(
            l.meshcoreTracePathSavePathHelper,
            style: TextStyle(
              color: context.textTertiary,
              fontSize: 12,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          FilledButton.icon(
            key: const ValueKey('meshcore-trace-save-as-contact-path'),
            onPressed: () => _saveAsContactPath(target, result),
            icon: const Icon(Icons.save_rounded),
            label: Text(l.meshcoreTracePathSaveAsContactPath),
          ),
          const SizedBox(height: AppTheme.spacing8),
        ],
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.meshcoreTracePathClose),
        ),
      ],
    );
  }

  /// D34c-A: write the freshly-traced hop bytes back to the target
  /// contact's stored path via `CMD_ADD_UPDATE_CONTACT (0x09)`.
  /// Routes through `meshCoreContactsProvider.setContactPathFromTrace`
  /// so all metadata is preserved and the contact list refreshes
  /// after the firmware ACK.
  Future<void> _saveAsContactPath(
    MeshCoreContact target,
    MeshCoreTraceResult result,
  ) async {
    final l = context.l10n;
    final hopBytes = Uint8List.fromList(
      result.hops.map((h) => h.pathByte).toList(growable: false),
    );
    final ok = await ref
        .read(meshCoreContactsProvider.notifier)
        .setContactPathFromTrace(
          publicKeyHex: target.publicKeyHex,
          hopBytes: hopBytes,
        );
    if (!mounted) return;
    final name = target.displayName.isNotEmpty
        ? target.displayName
        : l.meshcoreContactUnknownName;
    if (ok) {
      showSuccessSnackBar(
        context,
        l.meshcoreTracePathSaveAsContactPathSuccess(name),
      );
    } else {
      showErrorSnackBar(
        context,
        l.meshcoreTracePathSaveAsContactPathFailed(name),
      );
    }
  }
}
