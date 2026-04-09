// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/status_banner.dart';
import '../../providers/app_providers.dart';
import '../../providers/firmware_providers.dart';
import '../../services/firmware/firmware_models.dart';
import '../../services/firmware/hardware_architecture.dart';
import '../../services/haptic_service.dart';

class FirmwareUpdateScreen extends ConsumerStatefulWidget {
  const FirmwareUpdateScreen({super.key});

  @override
  ConsumerState<FirmwareUpdateScreen> createState() =>
      _FirmwareUpdateScreenState();
}

class _FirmwareUpdateScreenState extends ConsumerState<FirmwareUpdateScreen>
    with LifecycleSafeMixin {
  @override
  Widget build(BuildContext context) {
    final myNodeNum = ref.watch(myNodeNumProvider);
    final nodes = ref.watch(nodesProvider);
    final myNode = myNodeNum != null ? nodes[myNodeNum] : null;
    final firmwareAsync = ref.watch(firmwareReleaseProvider);
    final dfuState = ref.watch(dfuStateProvider);

    final currentVersion =
        myNode?.firmwareVersion ?? context.l10n.firmwareUpdateUnknown;
    final architecture = architectureFromHwModel(myNode?.hwModelId);

    return GlassScaffold(
      title: context.l10n.firmwareUpdateTitle,
      actions: [
        IconButton(
          icon: Icon(Icons.refresh, color: context.textPrimary),
          onPressed: () {
            ref.haptics.toggle();
            ref.read(firmwareReleaseProvider.notifier).refresh();
          },
        ),
      ],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Current Version Card
              _buildSectionHeader(
                context,
                context.l10n.firmwareUpdateSectionCurrentVersion,
              ),
              _buildCurrentVersionCard(context, currentVersion),
              const SizedBox(height: AppTheme.spacing16),

              // Device Info
              _buildDeviceInfoCard(context, myNode, architecture),
              const SizedBox(height: AppTheme.spacing24),

              // DFU Progress (shown when update is in progress)
              if (dfuState is! DfuIdle) ...[
                _buildDfuProgressCard(context, dfuState),
                const SizedBox(height: AppTheme.spacing24),
              ],

              // Update Check
              _buildSectionHeader(
                context,
                context.l10n.firmwareUpdateSectionAvailableUpdate,
              ),
              _buildUpdateCheckSection(
                context,
                firmwareAsync,
                currentVersion,
                architecture,
                myNode?.hwModelId,
                dfuState,
              ),

              const SizedBox(height: AppTheme.spacing24),

              // Update Instructions
              _buildSectionHeader(
                context,
                context.l10n.firmwareUpdateSectionHowToUpdate,
              ),
              _buildInstructionsCard(context),

              const SizedBox(height: AppTheme.spacing16),

              // Web Flasher Link
              OutlinedButton.icon(
                onPressed: () {
                  ref.haptics.toggle();
                  _openWebFlasher();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.accentColor,
                  side: BorderSide(color: context.accentColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius10),
                  ),
                ),
                icon: const Icon(Icons.open_in_browser),
                label: Text(context.l10n.firmwareUpdateOpenWebFlasher),
              ),

              const SizedBox(height: AppTheme.spacing32),

              // Warning
              StatusBanner.warning(
                title: context.l10n.firmwareUpdateBackupWarningTitle,
                subtitle: context.l10n.firmwareUpdateBackupWarningSubtitle,
                margin: EdgeInsets.zero,
              ),

              const SizedBox(height: AppTheme.spacing32),
            ]),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Section builders
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: context.textSecondary,
        ),
      ),
    );
  }

  Widget _buildCurrentVersionCard(BuildContext context, String currentVersion) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            child: Icon(Icons.memory, color: context.accentColor, size: 24),
          ),
          SizedBox(width: AppTheme.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.firmwareUpdateInstalledFirmware,
                  style: TextStyle(fontSize: 13, color: context.textSecondary),
                ),
                SizedBox(height: AppTheme.spacing4),
                Text(
                  currentVersion,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoCard(
    BuildContext context,
    dynamic myNode,
    DeviceArchitecture architecture,
  ) {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.developer_board,
            label: l10n.firmwareUpdateHardware,
            value: myNode?.hardwareModel ?? l10n.firmwareUpdateUnknown,
            context: context,
          ),
          _buildDivider(context),
          _buildInfoRow(
            icon: Icons.memory,
            label: l10n.firmwareArchitecture,
            value: _architectureDisplayName(context, architecture),
            context: context,
          ),
          _buildDivider(context),
          _buildInfoRow(
            icon: Icons.system_update,
            label: l10n.firmwareUpdateMethod,
            value: architecture.supportsNordicDfu
                ? l10n.firmwareUpdateMethodInApp
                : l10n.firmwareUpdateMethodWebFlasher,
            context: context,
          ),
          _buildDivider(context),
          _buildInfoRow(
            icon: Icons.tag,
            label: l10n.firmwareUpdateNodeId,
            value: myNode?.nodeNum.toString() ?? l10n.firmwareUpdateUnknown,
            context: context,
          ),
          _buildDivider(context),
          _buildInfoRow(
            icon: Icons.schedule,
            label: l10n.firmwareUpdateUptime,
            value: myNode?.uptimeSeconds != null
                ? _formatUptime(myNode!.uptimeSeconds!)
                : l10n.firmwareUpdateUnknown,
            context: context,
          ),
          if (myNode?.hasWifi == true) ...[
            _buildDivider(context),
            _buildInfoRow(
              icon: Icons.wifi,
              label: l10n.firmwareUpdateWifi,
              value: l10n.firmwareUpdateSupported,
              context: context,
            ),
          ],
          if (myNode?.hasBluetooth == true) ...[
            _buildDivider(context),
            _buildInfoRow(
              icon: Icons.bluetooth,
              label: l10n.firmwareUpdateBluetooth,
              value: l10n.firmwareUpdateSupported,
              context: context,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUpdateCheckSection(
    BuildContext context,
    AsyncValue<FirmwareRelease?> firmwareAsync,
    String currentVersion,
    DeviceArchitecture architecture,
    int? hwModelId,
    DfuState dfuState,
  ) {
    return firmwareAsync.when(
      data: (release) {
        if (release == null) return _buildNoUpdateCard(context);

        final isNewer = _isNewerVersion(currentVersion, release.version);

        return Column(
          children: [
            // Update Status Card
            _buildUpdateStatusCard(context, release, isNewer, architecture),
            if (isNewer) ...[
              const SizedBox(height: AppTheme.spacing16),

              // In-app DFU button for nRF52 devices
              if (architecture.supportsNordicDfu &&
                  hwModelId != null &&
                  dfuState is DfuIdle) ...[
                _buildDfuButton(context, release, hwModelId),
                const SizedBox(height: AppTheme.spacing12),
              ],

              // Release Notes
              _buildReleaseNotesCard(context, release),
            ],
          ],
        );
      },
      loading: () => _buildLoadingCard(context),
      error: (error, _) => StatusBanner.error(
        title: context.l10n.firmwareUpdateCheckFailed,
        subtitle: error.toString(),
        margin: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildUpdateStatusCard(
    BuildContext context,
    FirmwareRelease release,
    bool isNewer,
    DeviceArchitecture architecture,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isNewer
            ? AppTheme.successGreen.withValues(alpha: 0.1)
            : context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(
          color: isNewer
              ? AppTheme.successGreen.withValues(alpha: 0.3)
              : context.border,
        ),
      ),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color:
                      (isNewer ? AppTheme.successGreen : context.textTertiary)
                          .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: Icon(
                  isNewer ? Icons.system_update : Icons.check_circle,
                  color: isNewer ? AppTheme.successGreen : context.textTertiary,
                  size: 24,
                ),
              ),
              SizedBox(width: AppTheme.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isNewer
                          ? context.l10n.firmwareUpdateAvailable
                          : context.l10n.firmwareUpdateUpToDate,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isNewer
                            ? AppTheme.successGreen
                            : context.textSecondary,
                      ),
                    ),
                    SizedBox(height: AppTheme.spacing2),
                    Text(
                      context.l10n.firmwareUpdateLatestVersion(release.version),
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isNewer) ...[
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen,
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                      ),
                      child: Text(
                        context.l10n.firmwareUpdateNewBadge,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (architecture.supportsNordicDfu) ...[
                      SizedBox(height: AppTheme.spacing4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppTheme.radius8),
                        ),
                        child: Text(
                          context.l10n.firmwareDfuInAppSupported,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: context.accentColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
          if (isNewer && !architecture.supportsNordicDfu) ...[
            SizedBox(height: AppTheme.spacing16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  ref.haptics.toggle();
                  _openDownloadPage(release.pageUrl);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.successGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius10),
                  ),
                ),
                icon: const Icon(Icons.download),
                label: Text(
                  context.l10n.firmwareUpdateDownload,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDfuButton(
    BuildContext context,
    FirmwareRelease release,
    int hwModelId,
  ) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () {
          ref.haptics.toggle();
          _showDfuConfirmation(context, release, hwModelId);
        },
        style: FilledButton.styleFrom(
          backgroundColor: context.accentColor,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius10),
          ),
        ),
        icon: const Icon(Icons.system_update),
        label: Text(
          context.l10n.firmwareDfuStartUpdate,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildDfuProgressCard(BuildContext context, DfuState dfuState) {
    final l10n = context.l10n;

    String statusText;
    double? progressValue;
    Color statusColor;
    IconData statusIcon;
    bool showWarning = false;

    switch (dfuState) {
      case DfuDownloading(:final progress):
        statusText = l10n.firmwareDfuDownloadProgress(
          (progress * 100).toStringAsFixed(0),
        );
        progressValue = progress;
        statusColor = context.accentColor;
        statusIcon = Icons.cloud_download;
        showWarning = true;
      case DfuReady():
        statusText = l10n.firmwareDfuDownloading;
        progressValue = 1.0;
        statusColor = context.accentColor;
        statusIcon = Icons.check_circle;
      case DfuEnteringBootloader():
        statusText = l10n.firmwareDfuEnteringBootloader;
        progressValue = null;
        statusColor = AppTheme.warningYellow;
        statusIcon = Icons.restart_alt;
        showWarning = true;
      case DfuTransferring(:final percent, :final speed):
        statusText = l10n.firmwareDfuProgress(percent);
        progressValue = percent / 100.0;
        statusColor = context.accentColor;
        statusIcon = Icons.bluetooth;
        showWarning = true;
        if (speed > 0) {
          statusText += ' • ${l10n.firmwareDfuSpeed(speed.toStringAsFixed(1))}';
        }
      case DfuComplete():
        statusText = l10n.firmwareDfuComplete;
        progressValue = 1.0;
        statusColor = AppTheme.successGreen;
        statusIcon = Icons.check_circle;
      case DfuFailed(:final error):
        statusText = '${l10n.firmwareDfuFailed}: $error';
        progressValue = null;
        statusColor = AppTheme.errorRed;
        statusIcon = Icons.error;
      case DfuIdle():
        return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 24),
              SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Text(
                  dfuState is DfuTransferring
                      ? l10n.firmwareDfuTransferring
                      : dfuState is DfuDownloading
                      ? l10n.firmwareDfuDownloading
                      : statusText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
              if (dfuState is DfuFailed || dfuState is DfuComplete)
                IconButton(
                  icon: Icon(Icons.close, color: context.textTertiary),
                  onPressed: () {
                    ref.haptics.toggle();
                    ref.read(dfuStateProvider.notifier).reset();
                  },
                ),
            ],
          ),
          if (progressValue != null) ...[
            SizedBox(height: AppTheme.spacing12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radius4),
              child: LinearProgressIndicator(
                value: progressValue,
                backgroundColor: statusColor.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                minHeight: 6,
              ),
            ),
          ] else if (dfuState is DfuEnteringBootloader) ...[
            SizedBox(height: AppTheme.spacing12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radius4),
              child: LinearProgressIndicator(
                backgroundColor: statusColor.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                minHeight: 6,
              ),
            ),
          ],
          if (dfuState is DfuTransferring || dfuState is DfuDownloading) ...[
            SizedBox(height: AppTheme.spacing8),
            Text(
              statusText,
              style: TextStyle(fontSize: 13, color: context.textSecondary),
            ),
          ],
          if (showWarning) ...[
            SizedBox(height: AppTheme.spacing12),
            Text(
              l10n.firmwareDfuDoNotDisconnect,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: context.textTertiary,
              ),
            ),
          ],
          if (dfuState is DfuComplete) ...[
            SizedBox(height: AppTheme.spacing8),
            Text(
              l10n.firmwareDfuDeviceWillRestart,
              style: TextStyle(fontSize: 13, color: context.textSecondary),
            ),
          ],
          if (dfuState is DfuFailed) ...[
            SizedBox(height: AppTheme.spacing12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.haptics.toggle();
                  ref.read(dfuStateProvider.notifier).reset();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: statusColor,
                  side: BorderSide(color: statusColor),
                ),
                icon: const Icon(Icons.refresh),
                label: Text(l10n.firmwareDfuRetry),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReleaseNotesCard(BuildContext context, FirmwareRelease release) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes, color: context.accentColor, size: 20),
              SizedBox(width: AppTheme.spacing8),
              Text(
                context.l10n.firmwareUpdateReleaseNotes,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(release.releaseDate),
                style: TextStyle(fontSize: 12, color: context.textTertiary),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacing12),
          Text(
            release.releaseNotes,
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        children: [
          _buildStep(1, context.l10n.firmwareUpdateStep1, context),
          SizedBox(height: AppTheme.spacing12),
          _buildStep(2, context.l10n.firmwareUpdateStep2, context),
          const SizedBox(height: AppTheme.spacing12),
          _buildStep(3, context.l10n.firmwareUpdateStep3, context),
          const SizedBox(height: AppTheme.spacing12),
          _buildStep(4, context.l10n.firmwareUpdateStep4, context),
        ],
      ),
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      padding: const EdgeInsets.all(AppTheme.spacing32),
      child: Column(
        children: [
          LoadingIndicator(size: 32),
          SizedBox(height: AppTheme.spacing16),
          Text(
            context.l10n.firmwareUpdateChecking,
            style: TextStyle(fontSize: 14, color: context.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildNoUpdateCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      padding: const EdgeInsets.all(AppTheme.spacing24),
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 48,
            color: context.textTertiary.withValues(alpha: 0.5),
          ),
          SizedBox(height: AppTheme.spacing16),
          Text(
            context.l10n.firmwareUpdateUnableToCheck,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            context.l10n.firmwareUpdateVisitWebsite,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.textSecondary),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared widgets
  // ---------------------------------------------------------------------------

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required BuildContext context,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: context.accentColor, size: 20),
          SizedBox(width: AppTheme.spacing12),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.textSecondary),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: context.border.withValues(alpha: 0.3),
    );
  }

  Widget _buildStep(int number, String text, BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: context.accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppTheme.radius8),
          ),
          child: Center(
            child: Text(
              number.toString(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.accentColor,
              ),
            ),
          ),
        ),
        SizedBox(width: AppTheme.spacing12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.textSecondary),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // DFU confirmation bottom sheet
  // ---------------------------------------------------------------------------

  void _showDfuConfirmation(
    BuildContext context,
    FirmwareRelease release,
    int hwModelId,
  ) {
    final l10n = context.l10n;
    final connectedDevice = ref.read(connectedDeviceProvider);
    final deviceAddress = connectedDevice?.id;

    if (deviceAddress == null) {
      AppLogging.firmware('Cannot start DFU: no connected device');
      return;
    }

    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.firmwareDfuConfirmTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
          SizedBox(height: AppTheme.spacing16),
          Text(
            l10n.firmwareDfuConfirmBody(release.version),
            style: TextStyle(
              fontSize: 15,
              color: context.textSecondary,
              height: 1.5,
            ),
          ),
          SizedBox(height: AppTheme.spacing24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).pop();
                _startDfu(release, hwModelId, deviceAddress);
              },
              style: FilledButton.styleFrom(
                backgroundColor: context.accentColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius10),
                ),
              ),
              icon: const Icon(Icons.system_update),
              label: Text(
                l10n.firmwareDfuConfirmStart,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startDfu(FirmwareRelease release, int hwModelId, String deviceAddress) {
    ref
        .read(dfuStateProvider.notifier)
        .startDfu(
          release: release,
          hwModelId: hwModelId,
          deviceAddress: deviceAddress,
        );
  }

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------

  String _architectureDisplayName(
    BuildContext context,
    DeviceArchitecture arch,
  ) {
    switch (arch) {
      case DeviceArchitecture.nrf52840:
        return context.l10n.firmwareArchitectureNrf52;
      case DeviceArchitecture.esp32:
      case DeviceArchitecture.esp32s3:
      case DeviceArchitecture.esp32c6:
        return context.l10n.firmwareArchitectureEsp32;
      case DeviceArchitecture.rp2040:
      case DeviceArchitecture.rp2350:
      case DeviceArchitecture.stm32:
      case DeviceArchitecture.unknown:
        return context.l10n.firmwareArchitectureUnknown;
    }
  }

  bool _isNewerVersion(String current, String latest) {
    final currentParts = current.replaceAll(RegExp(r'[^0-9.]'), '').split('.');
    final latestParts = latest.replaceAll(RegExp(r'[^0-9.]'), '').split('.');

    for (int i = 0; i < latestParts.length; i++) {
      final currentNum = i < currentParts.length
          ? int.tryParse(currentParts[i]) ?? 0
          : 0;
      final latestNum = int.tryParse(latestParts[i]) ?? 0;

      if (latestNum > currentNum) return true;
      if (latestNum < currentNum) return false;
    }

    return false;
  }

  String _formatUptime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m';
    if (seconds < 86400) {
      return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';
    }
    return '${seconds ~/ 86400}d ${(seconds % 86400) ~/ 3600}h';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _openDownloadPage(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openWebFlasher() async {
    final uri = Uri.parse('https://flasher.meshtastic.org/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
