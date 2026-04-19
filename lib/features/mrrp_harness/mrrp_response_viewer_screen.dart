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
              // REQUEST section header
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
                child: Text(
                  l10n.mrrpHarnessResponseSectionRequest,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: context.textTertiary,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  border: Border.all(
                    color: context.border.withValues(alpha: 0.5),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  children: [
                    _InfoRow(label: l10n.mrrpHarnessSelectPeer, value: nodeHex),
                    _InfoRow(
                      label: l10n.mrrpHarnessSelectService,
                      value: serviceName,
                    ),
                    _InfoRow(
                      label: l10n.mrrpHarnessSelectAction,
                      value:
                          '0x${widget.actionId.toRadixString(16).padLeft(4, '0')}',
                    ),
                  ],
                ),
              ),
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
                // RESULT section header
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
                  child: Text(
                    l10n.mrrpHarnessResponseSectionResult,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: context.textTertiary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                    border: Border.all(
                      color: context.border.withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                  ),
                  child: _buildResultSection(context),
                ),
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
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing8,
                vertical: AppTheme.spacing4,
              ),
              decoration: BoxDecoration(
                color: SemanticColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                border: Border.all(
                  color: SemanticColors.warning.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_off,
                    size: 14,
                    color: SemanticColors.warning,
                  ),
                  const SizedBox(width: AppTheme.spacing4),
                  Text(
                    l10n.mrrpHarnessResponseTimeout,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: SemanticColors.warning,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Response payload
        if (result.response != null && result.response!.payload.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacing16),
          Row(
            children: [
              Text(
                l10n.mrrpHarnessPayloadRawHex.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: context.textTertiary,
                  letterSpacing: 1.2,
                ),
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
            padding: const EdgeInsets.all(AppTheme.spacing12),
            decoration: BoxDecoration(
              color: context.textPrimary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(AppTheme.radius8),
              border: Border.all(
                color: context.border.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Text(
              result.response!.payload
                  .map((b) => b.toRadixString(16).padLeft(2, '0'))
                  .join(' ')
                  .toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontFamily: AppTheme.fontFamily,
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
    final dotColor = valueColor ?? context.accentColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing4),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
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
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: AppTheme.fontFamily,
                color: valueColor ?? context.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
