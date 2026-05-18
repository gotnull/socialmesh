// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/core/logging.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/navigation.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/info_table.dart';
import '../../../core/widgets/qr_share_sheet.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../utils/snackbar.dart';
import '../../navigation/meshcore_shell.dart';
import '../screens/meshcore_qr_scanner_screen.dart';
import '../screens/meshcore_settings_screen.dart';

class MeshCoreDeviceSheetContent extends ConsumerStatefulWidget {
  final ScrollController scrollController;

  const MeshCoreDeviceSheetContent({super.key, required this.scrollController});

  @override
  ConsumerState<MeshCoreDeviceSheetContent> createState() =>
      _MeshCoreDeviceSheetContentState();
}

class _MeshCoreDeviceSheetContentState
    extends ConsumerState<MeshCoreDeviceSheetContent>
    with LifecycleSafeMixin<MeshCoreDeviceSheetContent> {
  bool _disconnecting = false;

  @override
  Widget build(BuildContext context) {
    final linkStatus = ref.watch(linkStatusProvider);
    final selfInfo = ref.watch(meshCoreSelfInfoProvider);
    final isConnected = linkStatus.isConnected;
    final isConnecting = linkStatus.isConnecting;

    final nodeName = selfInfo.selfInfo?.nodeName.isNotEmpty == true
        ? selfInfo.selfInfo!.nodeName
        : linkStatus.deviceName ??
              context.l10n.meshcoreShellDefaultDeviceNameFull;

    final nodeId = selfInfo.selfInfo != null
        ? selfInfo.selfInfo!.pubKey
              .take(4)
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join()
              .toUpperCase()
        : '';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppTheme.spacing20, 8, 20, 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isConnected
                      ? context.accentColor.withValues(alpha: 0.15)
                      : context.background,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: Icon(
                  Icons.router,
                  color: isConnected
                      ? context.accentColor
                      : context.textTertiary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nodeName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppTheme.spacing4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isConnected
                                ? context.accentColor
                                : isConnecting
                                ? AppTheme.warningYellow
                                : context.textTertiary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing6),
                        Text(
                          isConnected
                              ? context.l10n.meshcoreShellStatusConnected
                              : isConnecting
                              ? context.l10n.meshcoreShellStatusConnecting
                              : context.l10n.meshcoreShellStatusDisconnected,
                          style: TextStyle(
                            fontSize: 14,
                            color: isConnected
                                ? context.accentColor
                                : isConnecting
                                ? AppTheme.warningYellow
                                : context.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: context.textTertiary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Divider(color: context.border, height: 1),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(AppTheme.spacing20),
            children: [
              _buildSectionTitle(
                context,
                context.l10n.meshcoreShellSectionDeviceInfo,
              ),
              const SizedBox(height: AppTheme.spacing12),
              _buildDeviceInfoCard(context, selfInfo, nodeId, isConnected),
              const SizedBox(height: AppTheme.spacing24),
              _buildSectionTitle(
                context,
                context.l10n.meshcoreShellSectionQuickActions,
              ),
              const SizedBox(height: AppTheme.spacing12),
              MeshCoreActionTile(
                icon: Icons.person_add_rounded,
                title: context.l10n.meshcoreShellDrawerAddContact,
                subtitle: context.l10n.meshcoreShellAddContactSubtitle,
                enabled: isConnected && !_disconnecting,
                onTap: () {
                  Navigator.pop(context);
                  ref.read(meshCoreShellIndexProvider.notifier).setIndex(0);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MeshCoreQrScannerScreen(
                        mode: MeshCoreScanMode.contact,
                      ),
                    ),
                  );
                },
              ),
              MeshCoreActionTile(
                icon: Icons.add_rounded,
                title: context.l10n.meshcoreShellJoinChannel,
                subtitle: context.l10n.meshcoreShellJoinChannelSubtitle,
                enabled: isConnected && !_disconnecting,
                onTap: () {
                  Navigator.pop(context);
                  ref.read(meshCoreShellIndexProvider.notifier).setIndex(1);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MeshCoreQrScannerScreen(
                        mode: MeshCoreScanMode.channel,
                      ),
                    ),
                  );
                },
              ),
              MeshCoreActionTile(
                icon: Icons.qr_code_rounded,
                title: context.l10n.meshcoreShellDrawerMyContactCode,
                subtitle: context.l10n.meshcoreShellShareContactSubtitle,
                enabled: isConnected && !_disconnecting,
                onTap: () {
                  Navigator.pop(context);
                  _showMyContactCode();
                },
              ),
              MeshCoreActionTile(
                icon: Icons.radar_rounded,
                title: context.l10n.meshcoreShellDrawerDiscoverContacts,
                subtitle: context.l10n.meshcoreShellDiscoverSubtitle,
                enabled: isConnected && !_disconnecting,
                onTap: () {
                  Navigator.pop(context);
                  _discoverContacts();
                },
              ),
              MeshCoreActionTile(
                icon: Icons.settings_outlined,
                title: context.l10n.meshcoreShellAppSettings,
                subtitle: context.l10n.meshcoreShellAppSettingsSubtitle,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const MeshCoreSettingsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppTheme.spacing24),
            ],
          ),
        ),
        if (isConnected && !_disconnecting) ...[
          Divider(color: context.border.withValues(alpha: 0.2), height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppTheme.spacing20,
              AppTheme.spacing12,
              AppTheme.spacing20,
              AppTheme.spacing12 + MediaQuery.of(context).padding.bottom,
            ),
            child: _buildDisconnectButton(context),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: context.textTertiary,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildDeviceInfoCard(
    BuildContext context,
    MeshCoreSelfInfoState selfInfoState,
    String nodeId,
    bool isConnected,
  ) {
    final info = selfInfoState.selfInfo;

    return Container(
      decoration: BoxDecoration(
        color: context.background,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(color: context.border),
      ),
      child: InfoTable(
        rows: [
          InfoTableRow(
            label: context.l10n.meshcoreShellInfoProtocol,
            value: context.l10n.meshcoreShellInfoProtocolValue,
            icon: Icons.hub_rounded,
            iconColor: AccentColors.cyan,
          ),
          if (info != null) ...[
            InfoTableRow(
              label: context.l10n.meshcoreShellInfoNodeName,
              value: info.nodeName.isNotEmpty
                  ? info.nodeName
                  : context.l10n.meshcoreShellUnknown,
              icon: Icons.label_rounded,
            ),
            if (nodeId.isNotEmpty)
              InfoTableRow(
                label: context.l10n.meshcoreShellInfoNodeId,
                value: nodeId,
                icon: Icons.tag_rounded,
              ),
            InfoTableRow(
              label: context.l10n.meshcoreShellInfoPublicKey,
              value: info.pubKey
                  .take(8)
                  .map((b) => b.toRadixString(16).padLeft(2, '0'))
                  .join()
                  .toUpperCase(),
              icon: Icons.key_rounded,
            ),
          ],
          InfoTableRow(
            label: context.l10n.meshcoreShellInfoStatus,
            value: isConnected
                ? context.l10n.meshcoreShellStatusOnline
                : context.l10n.meshcoreShellStatusOffline,
            icon: Icons.circle,
            iconColor: isConnected ? AppTheme.successGreen : AppTheme.errorRed,
          ),
        ],
      ),
    );
  }

  Widget _buildDisconnectButton(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _disconnecting ? null : () => _disconnect(context),
          icon: _disconnecting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.errorRed,
                  ),
                )
              : const Icon(Icons.link_off, size: 20),
          label: Text(
            _disconnecting
                ? context.l10n.meshcoreShellDisconnecting
                : context.l10n.meshcoreShellDisconnect,
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.errorRed,
            side: BorderSide(
              color: _disconnecting
                  ? AppTheme.errorRed.withValues(alpha: 0.5)
                  : AppTheme.errorRed,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius16),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _disconnect(BuildContext context) async {
    final coordinator = ref.read(connectionCoordinatorProvider);
    final userDisconnectedNotifier = ref.read(
      userDisconnectedProvider.notifier,
    );
    final autoReconnectNotifier = ref.read(autoReconnectStateProvider.notifier);
    final appInitNotifier = ref.read(appInitProvider.notifier);

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.meshcoreShellDisconnect,
      message: context.l10n.meshcoreShellDisconnectConfirmMessage,
      confirmLabel: context.l10n.meshcoreShellDisconnect,
      isDestructive: true,
    );

    if (!mounted) return;
    if (confirmed != true) return;

    safeSetState(() => _disconnecting = true);

    AppLogging.connection(
      'event=shell.device_sheet.disconnect protocol=meshcore',
    );
    userDisconnectedNotifier.setUserDisconnected(true);
    autoReconnectNotifier.setState(AutoReconnectState.idle);

    appInitNotifier.setNeedsScanner();
    final rootNav = navigatorKey.currentState;
    if (rootNav != null) {
      AppLogging.connection(
        'MESHCORE_DISCONNECT_ROUTE_REPLACE_SCANNER source=device_sheet '
        'method=pushNamedAndRemoveUntil dest=/app',
      );
      rootNav.pushNamedAndRemoveUntil('/app', (route) => false);
    } else if (context.mounted) {
      AppLogging.connection(
        'MESHCORE_DISCONNECT_ROUTE_REPLACE_SCANNER source=device_sheet '
        'method=local_fallback (navigatorKey.currentState=null)',
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/app', (route) => false);
    }

    await coordinator.disconnect();
  }

  void _showMyContactCode() {
    final selfInfo = ref.read(meshCoreSelfInfoProvider);
    final info = selfInfo.selfInfo;
    if (info == null) {
      showErrorSnackBar(
        context,
        context.l10n.meshcoreShellDeviceInfoNotAvailable,
      );
      return;
    }

    final pubKeyHex = info.pubKey
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final shareCode = '${info.nodeName}:$pubKeyHex';

    QrShareSheet.show(
      context: context,
      title: info.nodeName.isNotEmpty
          ? info.nodeName
          : context.l10n.meshcoreShellUnnamedNode,
      subtitle: context.l10n.meshcoreShellScanToAddContact,
      qrData: shareCode,
      infoText: context.l10n.meshcoreShellShareContactInfo,
    );
  }

  Future<void> _discoverContacts() async {
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      showErrorSnackBar(context, context.l10n.meshcoreShellNotConnected);
      return;
    }
    try {
      await session.sendCommand(0x07);
      if (mounted) {
        showSuccessSnackBar(
          context,
          context.l10n.meshcoreShellAdvertisementSentListening,
        );
      }
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, context.l10n.meshcoreShellNotConnected);
      }
    }
  }
}

class MeshCoreActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  const MeshCoreActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppTheme.radius16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                  child: Icon(icon, color: context.accentColor, size: 22),
                ),
                const SizedBox(width: AppTheme.spacing14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppTheme.spacing2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textTertiary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: context.textTertiary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
