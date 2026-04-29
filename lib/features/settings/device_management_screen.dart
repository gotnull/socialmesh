// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../providers/connection_providers.dart' as conn;
import '../../providers/countdown_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../services/protocol/admin_target.dart';
import '../../utils/snackbar.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/glass_scaffold.dart';

/// Screen for device management actions like reboot, shutdown, factory reset
class DeviceManagementScreen extends ConsumerStatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  ConsumerState<DeviceManagementScreen> createState() =>
      _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends ConsumerState<DeviceManagementScreen>
    with LifecycleSafeMixin {
  bool _isProcessing = false;

  Future<void> _executeAction(
    String actionName,
    Future<void> Function() action, {
    bool requiresConfirmation = true,
    String? warningMessage,
    bool causesDisconnect = false,
  }) async {
    AppLogging.connection(
      '🔧 DeviceManagement: $actionName started'
      '${causesDisconnect ? " (causes disconnect)" : ""}',
    );

    if (!mounted) return;

    final l10n = context.l10n;

    if (requiresConfirmation) {
      final confirmed = await AppBottomSheet.show<bool>(
        context: context,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  causesDisconnect
                      ? Icons.warning_amber_rounded
                      : Icons.info_outline,
                  color: causesDisconnect
                      ? AppTheme.warningYellow
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Text(
                    actionName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing12),
            Text(
              warningMessage ?? l10n.deviceMgmtDefaultWarning(actionName),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.spacing24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: SemanticColors.divider),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                      ),
                    ),
                    child: Text(
                      l10n.accountSubCancel,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: causesDisconnect
                          ? AppTheme.warningYellow
                          : Theme.of(context).colorScheme.primary,
                      foregroundColor: causesDisconnect
                          ? Colors.black
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                      ),
                    ),
                    child: Text(l10n.accountSubConfirm),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      if (confirmed != true) {
        AppLogging.connection(
          '🔧 DeviceManagement: $actionName cancelled by user',
        );
        return;
      }
    }

    if (!mounted) return;

    safeSetState(() => _isProcessing = true);

    try {
      AppLogging.connection('🔧 DeviceManagement: Executing $actionName...');
      await action();

      if (mounted) {
        final message = causesDisconnect
            ? l10n.deviceMgmtSuccessDisconnect(actionName)
            : l10n.deviceMgmtSuccessCommandSent(actionName);
        showSuccessSnackBar(context, message);

        // Pop the screen after triggering actions that cause disconnect
        if (causesDisconnect) {
          AppLogging.connection(
            '🔧 DeviceManagement: $actionName complete — popping screen, '
            'expect disconnect shortly',
          );
          Future.delayed(const Duration(milliseconds: 500), () {
            safeNavigatorPop();
          });
        }
      }
    } catch (e) {
      AppLogging.connection('🔧 DeviceManagement: $actionName FAILED: $e');
      if (mounted) {
        showErrorSnackBar(context, l10n.deviceMgmtFailed(e.toString()));
      }
    } finally {
      safeSetState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final protocol = ref.watch(protocolServiceProvider);
    final isConnected = protocol.isConnected;

    return GlassScaffold(
      title: context.l10n.deviceMgmtTitle,
      slivers: [
        if (_isProcessing)
          const SliverFillRemaining(child: ScreenLoadingIndicator())
        else
          SliverPadding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            sliver: SliverList.list(
              children: [
                if (!isConnected)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Card(
                      color: theme.colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacing16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_rounded,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: AppTheme.spacing12),
                            Expanded(
                              child: Text(
                                context.l10n.deviceMgmtNotConnected,
                                style: TextStyle(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                _SectionHeader(title: context.l10n.deviceMgmtSectionPower),
                const SizedBox(height: AppTheme.spacing8),
                _ActionCard(
                  icon: Icons.refresh,
                  iconColor: theme.colorScheme.primary,
                  title: context.l10n.deviceMgmtRebootTitle,
                  subtitle: context.l10n.deviceMgmtRebootSubtitle,
                  enabled: isConnected,
                  onTap: () => _executeAction(
                    context.l10n.deviceMgmtRebootTitle,
                    () async {
                      final target = AdminTarget.fromNullable(
                        ref.read(remoteAdminTargetProvider),
                      );
                      if (target.isLocal) {
                        final autoReconnectNotifier = ref.read(
                          autoReconnectStateProvider.notifier,
                        );
                        AppLogging.connection(
                          '🔧 DeviceManagement: Sending reboot command '
                          '(delay=2s) — device will restart and BLE will drop',
                        );
                        await protocol.reboot(delaySeconds: 2, target: target);
                        // Clear stale manualConnecting so auto-reconnect
                        // manager can handle the reboot/reconnect cycle
                        if (!mounted) return;
                        autoReconnectNotifier.setState(AutoReconnectState.idle);
                        AppLogging.connection(
                          '🔧 DeviceManagement: Reboot command sent — '
                          'expecting disconnect in ~2s, '
                          'autoReconnectState set to idle for reconnect',
                        );
                        ref
                            .read(countdownProvider.notifier)
                            .startDeviceRebootCountdown(reason: 'reboot');
                      } else {
                        AppLogging.connection(
                          '🔧 Remote Admin: Sending reboot to remote device',
                        );
                        await protocol.reboot(delaySeconds: 2, target: target);
                      }
                    },
                    warningMessage: context.l10n.deviceMgmtRebootWarning,
                    causesDisconnect: true,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing8),
                _ActionCard(
                  icon: Icons.power_settings_new,
                  iconColor: theme.colorScheme.secondary,
                  title: context.l10n.deviceMgmtShutdownTitle,
                  subtitle: context.l10n.deviceMgmtShutdownSubtitle,
                  enabled: isConnected,
                  onTap: () => _executeAction(
                    context.l10n.deviceMgmtShutdownTitle,
                    () async {
                      final target = AdminTarget.fromNullable(
                        ref.read(remoteAdminTargetProvider),
                      );
                      if (target.isLocal) {
                        final autoReconnectNotifier = ref.read(
                          autoReconnectStateProvider.notifier,
                        );
                        AppLogging.connection(
                          '🔧 DeviceManagement: Sending shutdown command '
                          '(delay=2s) — device will power off and BLE will drop',
                        );
                        await protocol.shutdown(
                          delaySeconds: 2,
                          target: target,
                        );
                        // Clear stale manualConnecting so if user powers
                        // device back on, auto-reconnect isn't blocked
                        if (!mounted) return;
                        autoReconnectNotifier.setState(AutoReconnectState.idle);
                        AppLogging.connection(
                          '🔧 DeviceManagement: Shutdown command sent — '
                          'expecting disconnect in ~2s, '
                          'autoReconnectState set to idle',
                        );
                      } else {
                        AppLogging.connection(
                          '🔧 Remote Admin: Sending shutdown to remote device',
                        );
                        await protocol.shutdown(
                          delaySeconds: 2,
                          target: target,
                        );
                      }
                    },
                    warningMessage: context.l10n.deviceMgmtShutdownWarning,
                    causesDisconnect: true,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing24),
                _SectionHeader(title: context.l10n.deviceMgmtSectionTime),
                const SizedBox(height: AppTheme.spacing8),
                _ActionCard(
                  icon: Icons.access_time,
                  iconColor: theme.colorScheme.tertiary,
                  title: context.l10n.deviceMgmtSyncTimeTitle,
                  subtitle: context.l10n.deviceMgmtSyncTimeSubtitle,
                  enabled: isConnected,
                  onTap: () => _executeAction(
                    context.l10n.deviceMgmtSyncTimeTitle,
                    () => protocol.syncTime(),
                    requiresConfirmation: false,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing24),
                _SectionHeader(title: context.l10n.deviceMgmtSectionReset),
                const SizedBox(height: AppTheme.spacing8),
                _ActionCard(
                  icon: Icons.cleaning_services,
                  iconColor: AccentColors.orange,
                  title: context.l10n.deviceMgmtResetNodeDbTitle,
                  subtitle: context.l10n.deviceMgmtResetNodeDbSubtitle,
                  enabled: isConnected,
                  onTap: () => _executeAction(
                    context.l10n.deviceMgmtResetNodeDbTitle,
                    () async {
                      final target = AdminTarget.fromNullable(
                        ref.read(remoteAdminTargetProvider),
                      );
                      AppLogging.connection(
                        '🔧 DeviceManagement: Sending nodeDbReset — '
                        'will clear all discovered nodes from device',
                      );
                      await protocol.nodeDbReset(target: target);
                      if (!mounted) return;
                      AppLogging.connection(
                        '🔧 DeviceManagement: nodeDbReset sent',
                      );
                      // Only clear local app state for local device
                      if (target.isLocal) {
                        final nodesNotifier = ref.read(nodesProvider.notifier);
                        AppLogging.connection(
                          '🔧 DeviceManagement: clearing local nodes cache',
                        );
                        nodesNotifier.clearNodes();
                        // Restart the discovery-cooldown window so the
                        // Nodes screen's "Discovering" shimmer is
                        // bounded (default 3 min) instead of rendering
                        // forever — the TCP-connected radio's link
                        // stays up across this reset, so the cooldown
                        // would otherwise never re-arm via the
                        // disconnect→connect listener.
                        ref
                            .read(nodeDiscoveryCooldownProvider.notifier)
                            .restartCooldown();
                        ref
                            .read(countdownProvider.notifier)
                            .startDeviceRebootCountdown(
                              reason: 'node database reset',
                            );
                      }
                    },
                    warningMessage: context.l10n.deviceMgmtResetNodeDbWarning,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing8),
                _ActionCard(
                  icon: Icons.settings_backup_restore,
                  iconColor: AccentColors.coral,
                  title: context.l10n.deviceMgmtFactoryResetConfigTitle,
                  subtitle: context.l10n.deviceMgmtFactoryResetConfigSubtitle,
                  enabled: isConnected,
                  onTap: () => _executeAction(
                    context.l10n.deviceMgmtFactoryResetConfigTitle,
                    () async {
                      final target = AdminTarget.fromNullable(
                        ref.read(remoteAdminTargetProvider),
                      );
                      AppLogging.connection(
                        '🔧 DeviceManagement: Sending factoryResetConfig — '
                        'will wipe channels, region, all config but keep nodedb. '
                        'Device will reboot in ~5s',
                      );
                      await protocol.factoryResetConfig(target: target);
                      if (!mounted) return;
                      AppLogging.connection(
                        '🔧 DeviceManagement: factoryResetConfig command sent',
                      );
                      // Only clear local state for local device
                      if (target.isLocal) {
                        final settingsAsync = ref.read(settingsServiceProvider);
                        final channelsNotifier = ref.read(
                          channelsProvider.notifier,
                        );
                        final autoReconnectNotifier = ref.read(
                          autoReconnectStateProvider.notifier,
                        );
                        AppLogging.connection(
                          '🔧 DeviceManagement: clearing local region '
                          '+ channels state',
                        );
                        if (settingsAsync.hasValue) {
                          await settingsAsync.requireValue.setRegionConfigured(
                            false,
                          );
                          AppLogging.connection(
                            '🔧 DeviceManagement: regionConfigured cleared — '
                            'region selection will be required on next '
                            'connection',
                          );
                        }
                        channelsNotifier.clearChannels();
                        AppLogging.connection(
                          '🔧 DeviceManagement: Local channels cleared — '
                          'expecting device disconnect shortly',
                        );
                        if (!mounted) return;
                        autoReconnectNotifier.setState(AutoReconnectState.idle);
                        AppLogging.connection(
                          '🔧 DeviceManagement: autoReconnectState set '
                          'to idle (cleared stale manualConnecting '
                          'for reconnect)',
                        );
                        ref
                            .read(countdownProvider.notifier)
                            .startDeviceRebootCountdown(
                              reason: 'factory reset config',
                            );
                      }
                    },
                    warningMessage:
                        context.l10n.deviceMgmtFactoryResetConfigWarning,
                    causesDisconnect: true,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing8),
                _ActionCard(
                  icon: Icons.delete_forever,
                  iconColor: theme.colorScheme.error,
                  title: context.l10n.deviceMgmtFullFactoryResetTitle,
                  subtitle: context.l10n.deviceMgmtFullFactoryResetSubtitle,
                  enabled: isConnected,
                  onTap: () => _executeAction(
                    context.l10n.deviceMgmtFullFactoryResetTitle,
                    () async {
                      final target = AdminTarget.fromNullable(
                        ref.read(remoteAdminTargetProvider),
                      );
                      // Capture navigator before any await
                      final navigator = Navigator.of(context);

                      AppLogging.connection(
                        '🔧 DeviceManagement: Sending factoryResetDevice — '
                        'will WIPE EVERYTHING (config, channels, nodes, '
                        'identity). Device will reboot in ~5s',
                      );
                      await protocol.factoryResetDevice(target: target);
                      AppLogging.connection(
                        '🔧 DeviceManagement: factoryResetDevice command sent',
                      );

                      // Only clear local state and navigate when targeting
                      // the local device. Remote factory reset should not
                      // disconnect us or wipe local state.
                      if (!target.isLocal) return;

                      // Capture ALL providers before any more awaits
                      if (!mounted) return;
                      final settingsAsync = ref.read(settingsServiceProvider);
                      final nodesNotifier = ref.read(nodesProvider.notifier);
                      final channelsNotifier = ref.read(
                        channelsProvider.notifier,
                      );
                      final appInitNotifier = ref.read(
                        appInitProvider.notifier,
                      );
                      final deviceConnectionNotifier = ref.read(
                        conn.deviceConnectionProvider.notifier,
                      );
                      final userDisconnectedNotifier = ref.read(
                        userDisconnectedProvider.notifier,
                      );
                      final autoReconnectNotifier = ref.read(
                        autoReconnectStateProvider.notifier,
                      );

                      // CRITICAL: Follow the same disconnect-first pattern as
                      // manual disconnect (device_sheet.dart). If we navigate
                      // to Scanner while transport is still connected,
                      // Scanner's _tryAutoReconnect sees connected state,
                      // thinks "why am I here?", calls setReady() → router
                      // shows MainShell → user stranded on empty Nodes screen.

                      // 1. Set userDisconnected to prevent auto-reconnect to
                      //    the wiped device during/after disconnect
                      AppLogging.connection(
                        '🔧 DeviceManagement: Setting userDisconnected=true '
                        'to prevent auto-reconnect to wiped device',
                      );
                      userDisconnectedNotifier.setUserDisconnected(true);

                      // 2. Clear manualConnecting (stale from initial
                      //    Scanner connection) so it doesn't block anything
                      AppLogging.connection(
                        '🔧 DeviceManagement: Setting autoReconnectState '
                        'to idle (clearing stale manualConnecting)',
                      );
                      autoReconnectNotifier.setState(AutoReconnectState.idle);

                      // 3. Disconnect transport and wait for it to complete
                      AppLogging.connection(
                        '🔧 DeviceManagement: Disconnecting transport '
                        'before navigating to Scanner...',
                      );
                      await deviceConnectionNotifier.disconnect();
                      AppLogging.connection(
                        '🔧 DeviceManagement: Transport disconnected',
                      );

                      // 4. Stop protocol service
                      protocol.stop();

                      // 5. Clear ALL local state
                      AppLogging.connection(
                        '🔧 DeviceManagement: Clearing ALL local state '
                        '(region, lastDevice, nodes, channels)',
                      );
                      if (settingsAsync.hasValue) {
                        await settingsAsync.requireValue.setRegionConfigured(
                          false,
                        );
                        await settingsAsync.requireValue.clearLastDevice();
                        AppLogging.connection(
                          '🔧 DeviceManagement: regionConfigured + '
                          'lastDevice cleared',
                        );
                      }
                      nodesNotifier.clearNodes();
                      channelsNotifier.clearChannels();
                      AppLogging.connection(
                        '🔧 DeviceManagement: Local nodes + channels cleared',
                      );

                      // 6. Set app state and navigate
                      appInitNotifier.setNeedsScanner();
                      AppLogging.connection(
                        '🔧 DeviceManagement: appInit set to needsScanner — '
                        'navigating to /app for fresh _AppRouter rebuild',
                      );

                      if (mounted) {
                        navigator.pushNamedAndRemoveUntil(
                          '/app',
                          (route) => false,
                        );
                      }
                    },
                    warningMessage:
                        context.l10n.deviceMgmtFullFactoryResetWarning,
                    causesDisconnect: false, // Navigation handled in action
                  ),
                ),
                const SizedBox(height: AppTheme.spacing24),
                _SectionHeader(title: context.l10n.deviceMgmtSectionFirmware),
                const SizedBox(height: AppTheme.spacing8),
                _ActionCard(
                  icon: Icons.system_update,
                  iconColor: AccentColors.indigo,
                  title: context.l10n.deviceMgmtEnterDfuTitle,
                  subtitle: context.l10n.deviceMgmtEnterDfuSubtitle,
                  enabled: isConnected,
                  onTap: () => _executeAction(
                    context.l10n.deviceMgmtEnterDfuTitle,
                    () async {
                      final target = AdminTarget.fromNullable(
                        ref.read(remoteAdminTargetProvider),
                      );
                      AppLogging.connection(
                        '🔧 DeviceManagement: Sending enterDfuMode — '
                        'device will boot into firmware update mode, '
                        'BLE will drop',
                      );
                      await protocol.enterDfuMode(target: target);
                      AppLogging.connection(
                        '🔧 DeviceManagement: enterDfuMode sent — '
                        'expecting disconnect shortly',
                      );
                    },
                    warningMessage: context.l10n.deviceMgmtEnterDfuWarning,
                    causesDisconnect: true,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing32),
              ],
            ),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor = enabled ? iconColor : theme.disabledColor;
    final effectiveTextColor = enabled ? null : theme.disabledColor;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: effectiveIconColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                  child: Icon(icon, color: effectiveIconColor),
                ),
                const SizedBox(width: AppTheme.spacing16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: effectiveTextColor,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: enabled
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.disabledColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: enabled
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.disabledColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
