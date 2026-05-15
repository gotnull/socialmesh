// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D49-A: repeater admin status screen.
//
// Fetches `PUSH_CODE_STATUS_RESPONSE 0x87` via
// `MeshCoreSession.sendStatusRequest` and renders the 52-byte stats
// body as three canonical InfoTable cards: System, Radio, Packets.
//
// Async safety: ConsumerStatefulWidget + LifecycleSafeMixin. Every
// `await` is followed by a `mounted` guard. The refresh button
// re-issues the request without blocking the UI on the in-flight
// future.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/info_table.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../models/meshcore_contact.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../services/meshcore/protocol/meshcore_messages.dart';
import '../../../utils/snackbar.dart';

class MeshCoreRepeaterStatusScreen extends ConsumerStatefulWidget {
  final MeshCoreContact contact;
  const MeshCoreRepeaterStatusScreen({super.key, required this.contact});

  @override
  ConsumerState<MeshCoreRepeaterStatusScreen> createState() =>
      _MeshCoreRepeaterStatusScreenState();
}

class _MeshCoreRepeaterStatusScreenState
    extends ConsumerState<MeshCoreRepeaterStatusScreen>
    with LifecycleSafeMixin {
  MeshCoreRepeaterStatus? _status;
  bool _loading = false;
  bool _lastAttemptFailed = false;

  @override
  void initState() {
    super.initState();
    safePostFrame(_refresh);
  }

  Future<void> _refresh() async {
    if (_loading) return;
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      if (mounted) {
        showErrorSnackBar(context, context.l10n.meshcoreNotConnectedToDevice);
      }
      return;
    }
    setState(() {
      _loading = true;
      _lastAttemptFailed = false;
    });
    final result = await session.sendStatusRequest(
      pubKey: widget.contact.publicKey,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result == null) {
        _lastAttemptFailed = true;
      } else {
        _status = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GlassScaffold(
      title: l10n.meshcoreRepeaterStatusTitle(widget.contact.name),
      actions: [
        IconButton(
          key: const ValueKey('meshcore-repeater-status-refresh'),
          tooltip: l10n.meshcoreRepeaterStatusRefreshTooltip,
          onPressed: _loading ? null : _refresh,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
        ),
      ],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
          sliver: SliverList(
            delegate: SliverChildListDelegate(_buildBody(context, l10n)),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildBody(BuildContext context, dynamic l10n) {
    final status = _status;
    if (status == null) {
      if (_lastAttemptFailed) {
        return [
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: StatusBanner.error(
              title: l10n.meshcoreRepeaterStatusFailed as String,
            ),
          ),
        ];
      }
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppTheme.spacing24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    return [
      SectionTitle(title: l10n.meshcoreRepeaterStatusSectionSystem as String),
      InfoTable(
        rows: [
          InfoTableRow(
            label: l10n.meshcoreRepeaterStatusBatteryLabel as String,
            value: _formatBattery(status, l10n),
          ),
          InfoTableRow(
            label: l10n.meshcoreRepeaterStatusUptimeLabel as String,
            value: _formatDuration(status.uptime),
          ),
          InfoTableRow(
            label: l10n.meshcoreRepeaterStatusQueueLabel as String,
            value: status.queueLen.toString(),
          ),
          InfoTableRow(
            label: l10n.meshcoreRepeaterStatusErrorsLabel as String,
            value: status.errEvents.toString(),
          ),
        ],
      ),
      const SizedBox(height: AppTheme.spacing16),
      SectionTitle(title: l10n.meshcoreRepeaterStatusSectionRadio as String),
      InfoTable(
        rows: [
          InfoTableRow(
            label: l10n.meshcoreRepeaterStatusNoiseLabel as String,
            value: '${status.noiseFloorDbm} dBm',
          ),
          InfoTableRow(
            label: l10n.meshcoreRepeaterStatusRssiLabel as String,
            value: '${status.lastRssiDbm} dBm',
          ),
          InfoTableRow(
            label: l10n.meshcoreRepeaterStatusSnrLabel as String,
            value: '${status.lastSnrDb.toStringAsFixed(1)} dB',
          ),
          InfoTableRow(
            label: l10n.meshcoreRepeaterStatusTxAirtimeLabel as String,
            value: _formatDuration(status.txAirtime),
          ),
          InfoTableRow(
            label: l10n.meshcoreRepeaterStatusRxAirtimeLabel as String,
            value: _formatDuration(status.rxAirtime),
          ),
        ],
      ),
      const SizedBox(height: AppTheme.spacing16),
      SectionTitle(title: l10n.meshcoreRepeaterStatusSectionPackets as String),
      InfoTable(
        rows: [
          InfoTableRow(
            label: l10n.meshcoreRepeaterStatusPacketsRecvLabel as String,
            value: status.packetsRecv.toString(),
          ),
          InfoTableRow(
            label: l10n.meshcoreRepeaterStatusPacketsSentLabel as String,
            value: status.packetsSent.toString(),
          ),
          InfoTableRow(
            label: l10n.meshcoreRepeaterStatusFloodLabel as String,
            value: '${status.floodTx} / ${status.floodRx}',
          ),
          InfoTableRow(
            label: l10n.meshcoreRepeaterStatusDirectLabel as String,
            value: '${status.directTx} / ${status.directRx}',
          ),
          InfoTableRow(
            label: l10n.meshcoreRepeaterStatusDupsLabel as String,
            value: '${status.floodDups} / ${status.directDups}',
          ),
        ],
      ),
    ];
  }

  String _formatBattery(MeshCoreRepeaterStatus status, dynamic l10n) {
    final volts = status.batteryVolts;
    if (volts == null) {
      return l10n.meshcoreRepeaterStatusBatteryUnknown as String;
    }
    return '${volts.toStringAsFixed(2)} V (${status.batteryMv} mV)';
  }

  String _formatDuration(Duration d) {
    if (d.inDays > 0) {
      return '${d.inDays}d ${d.inHours % 24}h ${d.inMinutes % 60}m';
    }
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes % 60}m';
    }
    if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds % 60}s';
    }
    return '${d.inSeconds}s';
  }
}
