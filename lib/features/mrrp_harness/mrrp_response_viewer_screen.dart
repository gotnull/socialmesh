// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../services/protocol/sip/mrrp_dispatcher.dart';
import '../../services/protocol/sip/mrrp_types.dart';

/// Response viewer — shows the result of an MRRP request.
///
/// Receives a [Future<MrrpRequestResult>] and displays pending state,
/// then the resolved response with status, latency, payload hex, etc.
class MrrpResponseViewerScreen extends StatefulWidget {
  final int peerNodeId;
  final int serviceId;
  final int actionId;
  final DateTime sentAt;
  final Future<MrrpRequestResult> resultFuture;

  const MrrpResponseViewerScreen({
    required this.peerNodeId,
    required this.serviceId,
    required this.actionId,
    required this.sentAt,
    required this.resultFuture,
    super.key,
  });

  @override
  State<MrrpResponseViewerScreen> createState() =>
      _MrrpResponseViewerScreenState();
}

class _MrrpResponseViewerScreenState extends State<MrrpResponseViewerScreen> {
  MrrpRequestResult? _result;
  bool _pending = true;

  @override
  void initState() {
    super.initState();
    _awaitResult();
  }

  Future<void> _awaitResult() async {
    final result = await widget.resultFuture;
    if (!mounted) return;
    setState(() {
      _result = result;
      _pending = false;
    });

    final latencyMs = result.latency?.inMilliseconds;
    AppLogging.mrrpHarness(
      'MRRP_HARNESS: response viewer — '
      'status=${result.status.name} '
      '${latencyMs != null ? 'latency=${latencyMs}ms' : 'no-latency'}', // lint-allow: hardcoded-string
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final nodeHex =
        '0x${widget.peerNodeId.toRadixString(16).padLeft(8, '0').toUpperCase()}';
    final serviceName = MrrpServiceId.nameOf(widget.serviceId);

    return GlassScaffold(
      title: l10n.mrrpHarnessResponseTitle,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Request info
              _InfoRow(label: l10n.mrrpHarnessSelectPeer, value: nodeHex),
              _InfoRow(
                label: l10n.mrrpHarnessSelectService,
                value: serviceName,
              ),
              _InfoRow(
                label: l10n.mrrpHarnessSelectAction,
                value: '0x${widget.actionId.toRadixString(16).padLeft(4, '0')}',
              ),
              const SizedBox(height: AppTheme.spacing16),
              const Divider(height: 1),
              const SizedBox(height: AppTheme.spacing16),

              // Result section
              if (_pending) ...[
                Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: AppTheme.spacing12),
                      Text(
                        l10n.mrrpHarnessResponsePending,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                _buildResultSection(context),
              ],
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildResultSection(BuildContext context) {
    final l10n = context.l10n;
    final result = _result!;
    final isTimeout = result.status == MrrpStatusCode.timeout;
    final statusText =
        '${result.status.name} (${result.status.code})'; // lint-allow: hardcoded-string

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status
        _InfoRow(
          label: l10n.mrrpHarnessResponseStatus(''),
          value: statusText,
          valueColor: result.isSuccess
              ? SemanticColors.success
              : isTimeout
              ? SemanticColors.warning
              : SemanticColors.error,
        ),

        // Latency
        if (result.latency != null)
          _InfoRow(
            label: l10n.mrrpHarnessResponseLatency(0),
            value:
                '${result.latency!.inMilliseconds}ms', // lint-allow: hardcoded-string
          ),

        // Timeout marker
        if (isTimeout)
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.spacing8),
            child: Chip(
              avatar: Icon(
                Icons.timer_off,
                size: 16,
                color: SemanticColors.warning,
              ),
              label: Text(l10n.mrrpHarnessResponseTimeout),
              backgroundColor: SemanticColors.warning.withAlpha(25),
            ),
          ),

        // Response payload
        if (result.response != null && result.response!.payload.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacing16),
          Row(
            children: [
              Text(
                l10n.mrrpHarnessPayloadRawHex,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: l10n.mrrpHarnessTrafficCopy,
                onPressed: () {
                  final hex = result.response!.payload
                      .map((b) => b.toRadixString(16).padLeft(2, '0'))
                      .join(' ')
                      .toUpperCase();
                  Clipboard.setData(ClipboardData(text: hex));
                },
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spacing8),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(AppTheme.radius6),
            ),
            child: Text(
              result.response!.payload
                  .map((b) => b.toRadixString(16).padLeft(2, '0'))
                  .join(' ')
                  .toUpperCase(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace', // lint-allow: hardcoded-string
                color: context.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing4),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.textSecondary),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor ?? context.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
