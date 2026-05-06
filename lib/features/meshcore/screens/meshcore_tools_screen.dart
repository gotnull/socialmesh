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
import '../../navigation/meshcore_shell.dart';

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
            Opacity(
              opacity: 0.4,
              child: IgnorePointer(
                child: SettingsTile(
                  icon: Icons.route_rounded,
                  iconColor: AccentColors.purple,
                  title: context.l10n.meshcoreTracePath,
                  subtitle: context.l10n.meshcoreTracePacketRoutes,
                  trailing: _chevron(context),
                ),
              ),
            ),
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

            // Discovery Section
            SettingsSectionHeader(title: context.l10n.meshcoreDiscovery),
            SettingsTile(
              icon: Icons.radar_rounded,
              iconColor: AccentColors.orange,
              title: context.l10n.meshcoreSendAdvertisementTool,
              subtitle: context.l10n.meshcoreBroadcastPresenceToMesh,
              trailing: _chevron(context),
              onTap: _sendAdvertisement,
            ),
            const SizedBox(height: AppTheme.spacing16),

            // Analysis Section
            SettingsSectionHeader(title: context.l10n.meshcoreAnalysis),
            SettingsTile(
              icon: Icons.settings_input_antenna_rounded,
              iconColor: AccentColors.pink,
              title: context.l10n.meshcoreRadioSettingsTool,
              subtitle: context.l10n.meshcoreViewLoRaConfig,
              trailing: _chevron(context),
              onTap: () => _showRadioSettings(selfInfoState),
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

  void _showRadioSettings(MeshCoreSelfInfoState selfInfoState) {
    final info = selfInfoState.selfInfo;
    if (info == null) {
      showErrorSnackBar(
        context,
        context.l10n.meshcoreRadioSettingsNotAvailable,
      );
      return;
    }

    AppBottomSheet.show<void>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: context.l10n.meshcoreRadioSettingsTitle),
          InfoTable(
            rows: [
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
            ],
          ),
          SizedBox(height: AppTheme.spacing16),
          StatusBanner(
            type: StatusBannerType.accent,
            title: context.l10n.meshcoreRadioConfiguredOnFirmware,
            icon: Icons.info_outline_rounded,
          ),
        ],
      ),
    );
  }
}
