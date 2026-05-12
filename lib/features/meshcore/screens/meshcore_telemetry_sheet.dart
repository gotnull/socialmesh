// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D41-A: MeshCore per-contact telemetry sheet.
//
// Opens from the Telemetry tile on the contact detail screen. Sends
// one Cayenne LPP telemetry request (`CMD_SEND_BINARY_REQ 0x32`
// with `req_type=0x03`) via `meshCoreTelemetryProvider`, waits for
// the `PUSH_CODE_TELEMETRY_RESPONSE 0x8B` push, and renders the
// parsed readings grouped by Cayenne LPP channel.
//
// Privacy: the sheet NEVER renders full pubkeys, raw payload bytes,
// or message/envelope content. Hop labels / channel labels are
// short integer identifiers ("Device" for channel 1, "Aux N" for
// other channels).
//
// Airtime safety: manual refresh only; 10 s per-contact cooldown
// enforced inside the provider. No automatic polling, no fan-out.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/info_table.dart';
import '../../../core/widgets/section_header.dart';
import '../../../models/meshcore_contact.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../services/meshcore/protocol/meshcore_cayenne_lpp.dart';

Future<void> showMeshCoreTelemetrySheet(
  BuildContext context, {
  required MeshCoreContact contact,
}) {
  return AppBottomSheet.showScrollable<void>(
    context: context,
    initialChildSize: 0.85,
    minChildSize: 0.5,
    maxChildSize: 0.95,
    builder: (controller) =>
        _TelemetrySheet(contact: contact, scrollController: controller),
  );
}

class _TelemetrySheet extends ConsumerStatefulWidget {
  final MeshCoreContact contact;
  final ScrollController scrollController;

  const _TelemetrySheet({
    required this.contact,
    required this.scrollController,
  });

  @override
  ConsumerState<_TelemetrySheet> createState() => _TelemetrySheetState();
}

class _TelemetrySheetState extends ConsumerState<_TelemetrySheet>
    with LifecycleSafeMixin {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(meshCoreTelemetryProvider(widget.contact.publicKeyHex).notifier)
          .requestRefresh();
    });
  }

  Future<void> _refresh() async {
    await ref
        .read(meshCoreTelemetryProvider(widget.contact.publicKeyHex).notifier)
        .requestRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(
      meshCoreTelemetryProvider(widget.contact.publicKeyHex),
    );
    final visibleStatus = ref
        .read(meshCoreTelemetryProvider(widget.contact.publicKeyHex).notifier)
        .visibleStatus(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            AppTheme.spacing16,
            AppTheme.spacing16,
            AppTheme.spacing8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: SectionTitle(
                  title: l10n.meshcoreTelemetrySheetTitle(
                    widget.contact.displayName.isNotEmpty
                        ? widget.contact.displayName
                        : l10n.meshcoreContactUnknownName,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('meshcore-telemetry-refresh'),
                icon: const Icon(Icons.refresh_rounded),
                tooltip: l10n.meshcoreTelemetryRefresh,
                onPressed: _refresh,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.symmetric(
              vertical: AppTheme.spacing12,
              horizontal: AppTheme.spacing16,
            ),
            children: _buildBody(context, state, visibleStatus),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildBody(
    BuildContext context,
    MeshCoreTelemetryState state,
    MeshCoreTelemetryStatus visibleStatus,
  ) {
    final l10n = context.l10n;
    switch (visibleStatus) {
      case MeshCoreTelemetryStatus.idle:
      case MeshCoreTelemetryStatus.requesting:
        return [_CenteredHint(label: l10n.meshcoreTelemetryRequesting)];
      case MeshCoreTelemetryStatus.cooling:
        final until = state.cooldownUntil;
        final secs = until == null
            ? 0
            : (until.difference(DateTime.now()).inSeconds + 1).clamp(0, 60);
        return [
          _CenteredHint(label: l10n.meshcoreTelemetryCoolingSeconds(secs)),
        ];
      case MeshCoreTelemetryStatus.failure:
        return [_CenteredHint(label: l10n.meshcoreTelemetryTimeout)];
      case MeshCoreTelemetryStatus.success:
        final response = state.lastResponse;
        if (response == null || response.readings.isEmpty) {
          return [_CenteredHint(label: l10n.meshcoreTelemetryEmpty)];
        }
        return _buildReadingsByChannel(context, response.readings);
    }
  }

  List<Widget> _buildReadingsByChannel(
    BuildContext context,
    List<MeshCoreTelemetryReading> readings,
  ) {
    final l10n = context.l10n;
    // Preserve channel insertion order while grouping rows.
    final grouped = <int, List<MeshCoreTelemetryReading>>{};
    for (final r in readings) {
      grouped.putIfAbsent(r.channel, () => []).add(r);
    }
    final blocks = <Widget>[];
    grouped.forEach((channel, rs) {
      blocks.add(
        SectionTitle(
          title: channel == 1
              ? l10n.meshcoreTelemetryChannelDevice
              : l10n.meshcoreTelemetryChannelAux(channel),
        ),
      );
      blocks.add(
        InfoTable(rows: rs.map((r) => _readingRow(context, r)).toList()),
      );
      blocks.add(const SizedBox(height: AppTheme.spacing12));
    });
    return blocks;
  }

  InfoTableRow _readingRow(
    BuildContext context,
    MeshCoreTelemetryReading reading,
  ) {
    final l10n = context.l10n;
    switch (reading) {
      case MeshCoreTelemetryVoltage v:
        return InfoTableRow(
          label: l10n.meshcoreTelemetryRowBatteryLabel,
          value: l10n.meshcoreTelemetryRowBatteryValue(
            v.volts.toStringAsFixed(2),
          ),
        );
      case MeshCoreTelemetryTemperature t:
        return InfoTableRow(
          label: l10n.meshcoreTelemetryRowTemperatureLabel,
          value: l10n.meshcoreTelemetryRowTemperatureValue(
            t.celsius.toStringAsFixed(1),
          ),
        );
      case MeshCoreTelemetryHumidity h:
        return InfoTableRow(
          label: l10n.meshcoreTelemetryRowHumidityLabel,
          value: l10n.meshcoreTelemetryRowHumidityValue(
            h.percent.toStringAsFixed(1),
          ),
        );
      case MeshCoreTelemetryPressure p:
        return InfoTableRow(
          label: l10n.meshcoreTelemetryRowPressureLabel,
          value: l10n.meshcoreTelemetryRowPressureValue(
            p.hPa.toStringAsFixed(1),
          ),
        );
      case MeshCoreTelemetryGps g:
        return InfoTableRow(
          label: l10n.meshcoreTelemetryRowLocationLabel,
          value: l10n.meshcoreTelemetryRowLocationValue(
            g.latitude.toStringAsFixed(4),
            g.longitude.toStringAsFixed(4),
            g.altitudeMetres.round(),
          ),
        );
    }
  }
}

class _CenteredHint extends StatelessWidget {
  final String label;
  const _CenteredHint({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing24),
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.textTertiary),
        ),
      ),
    );
  }
}
