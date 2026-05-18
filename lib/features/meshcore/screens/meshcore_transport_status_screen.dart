// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/transport.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/info_table.dart';
import '../../../core/widgets/section_header.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/meshcore_throughput_provider.dart';
import '../../../services/meshcore/connection_coordinator.dart';
import '../../../services/meshcore/meshcore_throughput_counter.dart';
import '../../navigation/meshcore_shell.dart';

/// Row 50: dedicated transport status screen for the active MeshCore
/// link. Surfaces transport type, connection state, endpoint info
/// (host+port for TCP, device path for USB, redacted device id for BLE),
/// and live throughput (Row 50.b: bytes RX/TX since current connect +
/// rolling 10-second rate).
class MeshCoreTransportStatusScreen extends ConsumerWidget {
  const MeshCoreTransportStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final linkStatus = ref.watch(linkStatusProvider);
    final transportType = ref.watch(transportTypeProvider);

    // `linkStatus.deviceId` is the radio's node id once connected (e.g.
    // "79426D8D"), not the transport-prefixed device identifier the
    // coordinator persists. The prefixed form lives in
    // `SettingsService.lastDeviceId`, so read it there to parse out
    // the TCP host / port or surface the USB serial path.
    final settingsAsync = ref.watch(settingsServiceProvider);
    final persistedDeviceId = settingsAsync.maybeWhen(
      data: (s) => s.lastDeviceId,
      orElse: () => null,
    );
    final tcpId = persistedDeviceId == null
        ? null
        : MeshCoreTcpDeviceId.tryParse(persistedDeviceId);

    return GlassScaffold(
      title: l10n.meshcoreTransportStatusTitle,
      leading: const MeshCoreHamburgerMenuButton(),
      actions: const [MeshCoreDeviceStatusButton()],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing16,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              SectionTitle(
                title: l10n.meshcoreTransportStatusConnectionSection,
              ),
              const SizedBox(height: AppTheme.spacing8),
              InfoTable(
                rows: [
                  InfoTableRow(
                    label: l10n.meshcoreTransportStatusFieldStatus,
                    value: _statusLabel(context, linkStatus),
                    icon: Icons.circle,
                    iconColor: linkStatus.isConnected
                        ? AppTheme.successGreen
                        : linkStatus.isConnecting
                        ? AppTheme.warningYellow
                        : AppTheme.errorRed,
                  ),
                  InfoTableRow(
                    label: l10n.meshcoreTransportStatusFieldTransport,
                    value: _transportLabel(transportType),
                    icon: _transportIcon(transportType),
                    iconColor: AccentColors.cyan,
                  ),
                  if (linkStatus.deviceName != null &&
                      linkStatus.deviceName!.isNotEmpty)
                    InfoTableRow(
                      label: l10n.meshcoreTransportStatusFieldDevice,
                      value: linkStatus.deviceName!,
                      icon: Icons.device_hub_rounded,
                    ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing20),
              SectionTitle(title: l10n.meshcoreTransportStatusEndpointSection),
              const SizedBox(height: AppTheme.spacing8),
              InfoTable(
                rows: _endpointRows(
                  context,
                  transportType,
                  persistedDeviceId,
                  tcpId,
                ),
              ),
              const SizedBox(height: AppTheme.spacing20),
              SectionTitle(
                title: l10n.meshcoreTransportStatusThroughputSection,
              ),
              const SizedBox(height: AppTheme.spacing8),
              _ThroughputCard(),
            ]),
          ),
        ),
      ],
    );
  }

  String _statusLabel(BuildContext context, LinkStatus s) {
    final l10n = context.l10n;
    if (s.isConnected) return l10n.meshcoreShellStatusConnected;
    if (s.isConnecting) return l10n.meshcoreShellStatusConnecting;
    return l10n.meshcoreShellStatusDisconnected;
  }

  String _transportLabel(TransportType t) {
    switch (t) {
      case TransportType.ble:
        return 'BLE';
      case TransportType.usb:
        return 'USB';
      case TransportType.network:
        return 'TCP';
    }
  }

  IconData _transportIcon(TransportType t) {
    switch (t) {
      case TransportType.ble:
        return Icons.bluetooth_rounded;
      case TransportType.usb:
        return Icons.usb_rounded;
      case TransportType.network:
        return Icons.wifi_rounded;
    }
  }

  List<InfoTableRow> _endpointRows(
    BuildContext context,
    TransportType t,
    String? persistedDeviceId,
    MeshCoreTcpDeviceId? tcpId,
  ) {
    final l10n = context.l10n;
    switch (t) {
      case TransportType.network:
        if (tcpId == null) {
          return [
            InfoTableRow(
              label: l10n.meshcoreTransportStatusFieldEndpoint,
              value: l10n.meshcoreTransportStatusEndpointUnknown,
              icon: Icons.help_outline_rounded,
            ),
          ];
        }
        return [
          InfoTableRow(
            label: l10n.meshcoreTransportStatusFieldHost,
            value: tcpId.host,
            icon: Icons.dns_rounded,
          ),
          InfoTableRow(
            label: l10n.meshcoreTransportStatusFieldPort,
            value: tcpId.port.toString(),
            icon: Icons.numbers_rounded,
          ),
        ];
      case TransportType.usb:
        return [
          InfoTableRow(
            label: l10n.meshcoreTransportStatusFieldSerialPort,
            value:
                persistedDeviceId ??
                l10n.meshcoreTransportStatusEndpointUnknown,
            icon: Icons.cable_rounded,
          ),
          InfoTableRow(
            label: l10n.meshcoreTransportStatusFieldBaud,
            value: '115200',
            icon: Icons.speed_rounded,
          ),
        ];
      case TransportType.ble:
        return [
          InfoTableRow(
            label: l10n.meshcoreTransportStatusFieldDeviceId,
            value: _redactBleId(persistedDeviceId),
            icon: Icons.fingerprint_rounded,
          ),
        ];
    }
  }

  /// Show only the last 4 hex chars of a BLE device id (MAC or UUID).
  /// The full identifier is privacy-sensitive (uniquely identifies the
  /// pairing) and unhelpful in a status surface; the suffix is enough
  /// for the user to recognise which radio they connected to.
  String _redactBleId(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    if (raw.length <= 4) return raw;
    return '…${raw.substring(raw.length - 4)}';
  }
}

/// Row 50.b: live throughput InfoTable. Watches the 1 Hz snapshot
/// stream and renders cumulative bytes + rolling 10-second rate.
/// Shows "Idle" when no bytes have flowed yet on the active session.
class _ThroughputCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final snapshotAsync = ref.watch(meshCoreThroughputSnapshotProvider);
    final snapshot = snapshotAsync.value ?? MeshCoreThroughputSnapshot.zero;

    return InfoTable(
      rows: [
        InfoTableRow(
          label: l10n.meshcoreTransportStatusFieldBytesTx,
          value: snapshot.hasActivity
              ? _formatBytes(snapshot.bytesTx)
              : l10n.meshcoreTransportStatusThroughputIdle,
          icon: Icons.upload_rounded,
          iconColor: AccentColors.cyan,
        ),
        InfoTableRow(
          label: l10n.meshcoreTransportStatusFieldBytesRx,
          value: snapshot.hasActivity
              ? _formatBytes(snapshot.bytesRx)
              : l10n.meshcoreTransportStatusThroughputIdle,
          icon: Icons.download_rounded,
          iconColor: AccentColors.cyan,
        ),
        InfoTableRow(
          label: l10n.meshcoreTransportStatusFieldRateTx,
          value: _formatRate(snapshot.txBytesPerSecond),
          icon: Icons.speed_rounded,
        ),
        InfoTableRow(
          label: l10n.meshcoreTransportStatusFieldRateRx,
          value: _formatRate(snapshot.rxBytesPerSecond),
          icon: Icons.speed_rounded,
        ),
        InfoTableRow(
          label: l10n.meshcoreTransportStatusFieldSessionDuration,
          value: _formatDuration(snapshot.sessionSeconds),
          icon: Icons.timer_outlined,
        ),
      ],
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KiB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MiB';
  }

  static String _formatRate(double bytesPerSecond) {
    if (bytesPerSecond < 1) return '0 B/s';
    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    }
    if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KiB/s';
    }
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)} MiB/s';
  }

  static String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m < 60) return '${m}m ${s.toString().padLeft(2, '0')}s';
    final h = m ~/ 60;
    final mm = m % 60;
    return '${h}h ${mm.toString().padLeft(2, '0')}m';
  }
}
