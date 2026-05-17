// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D49-D3: optional admin binary-RPC trio.
//
// Three on-demand pull operations layered over the existing
// `CMD_SEND_BINARY_REQ 0x32` envelope (D36-A neighbours uses the
// same plumbing):
//
//   - Keep-alive (REQ_TYPE 0x02): proactively extend the
//     firmware-side admin session timeout. Distinct from D49-D2's
//     auto-re-login which is the REACTIVE path after the session
//     has already dropped.
//   - Status (REQ_TYPE 0x01): pull a one-shot status snapshot.
//     D49-A's PUSH_CODE_STATUS 0x87 is the periodic push path;
//     this is the pull path.
//   - Access list (REQ_TYPE 0x05): read the repeater's admin
//     allow-list. Read-only; mutation lives on a separate slice.
//
// All three are admin-mode only: the screen is only reachable from
// the repeater hub, which is itself only opened after a successful
// admin login. Each operation renders the raw response bytes as
// uppercase hex inside a copyable card; parsing into structured
// fields is deferred until a UX-driven sub-slice asks for it.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../models/meshcore_contact.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../services/meshcore/protocol/meshcore_session.dart';
import '../../../utils/snackbar.dart';

enum _BinaryRpcOp { status, keepAlive, accessList }

class MeshCoreRepeaterBinaryRpcScreen extends ConsumerStatefulWidget {
  final MeshCoreContact contact;
  const MeshCoreRepeaterBinaryRpcScreen({super.key, required this.contact});

  @override
  ConsumerState<MeshCoreRepeaterBinaryRpcScreen> createState() =>
      _MeshCoreRepeaterBinaryRpcScreenState();
}

class _MeshCoreRepeaterBinaryRpcScreenState
    extends ConsumerState<MeshCoreRepeaterBinaryRpcScreen>
    with LifecycleSafeMixin {
  _BinaryRpcOp? _busyOp;
  _Result? _lastResult;

  Future<void> _run(_BinaryRpcOp op) async {
    final l10n = context.l10n;
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      showErrorSnackBar(context, l10n.meshcoreRepeaterBinaryRpcNoSession);
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _busyOp = op;
      _lastResult = null;
    });
    Uint8List? response;
    try {
      response = await _dispatch(session, op);
    } catch (_) {
      response = null;
    }
    if (!mounted) return;
    setState(() {
      _busyOp = null;
      _lastResult = _Result(op: op, bytes: response);
    });
    if (response == null) {
      showErrorSnackBar(context, l10n.meshcoreRepeaterBinaryRpcFailed);
    } else {
      showSuccessSnackBar(context, l10n.meshcoreRepeaterBinaryRpcDone);
    }
  }

  Future<Uint8List?> _dispatch(MeshCoreSession session, _BinaryRpcOp op) {
    switch (op) {
      case _BinaryRpcOp.status:
        return session.requestRepeaterStatus(
          recipientPubKey: widget.contact.publicKey,
        );
      case _BinaryRpcOp.keepAlive:
        return session.requestRepeaterKeepAlive(
          recipientPubKey: widget.contact.publicKey,
        );
      case _BinaryRpcOp.accessList:
        return session.requestRepeaterAccessList(
          recipientPubKey: widget.contact.publicKey,
        );
    }
  }

  String _opTitle(BuildContext context, _BinaryRpcOp op) {
    final l10n = context.l10n;
    switch (op) {
      case _BinaryRpcOp.status:
        return l10n.meshcoreRepeaterBinaryRpcStatus;
      case _BinaryRpcOp.keepAlive:
        return l10n.meshcoreRepeaterBinaryRpcKeepAlive;
      case _BinaryRpcOp.accessList:
        return l10n.meshcoreRepeaterBinaryRpcAccessList;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GlassScaffold(
      title: l10n.meshcoreRepeaterBinaryRpcTitle,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing16,
                  vertical: AppTheme.spacing4,
                ),
                child: Text(
                  l10n.meshcoreRepeaterBinaryRpcSubtitle,
                  style: TextStyle(color: context.textTertiary, fontSize: 13),
                ),
              ),
              const SizedBox(height: AppTheme.spacing12),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing16,
                ),
                child: SectionTitle(
                  title: l10n.meshcoreRepeaterBinaryRpcOperationsSection,
                ),
              ),
              _opButton(
                context,
                op: _BinaryRpcOp.status,
                icon: Icons.assessment_outlined,
                label: l10n.meshcoreRepeaterBinaryRpcStatus,
              ),
              const SizedBox(height: AppTheme.spacing8),
              _opButton(
                context,
                op: _BinaryRpcOp.keepAlive,
                icon: Icons.favorite_border_rounded,
                label: l10n.meshcoreRepeaterBinaryRpcKeepAlive,
              ),
              const SizedBox(height: AppTheme.spacing8),
              _opButton(
                context,
                op: _BinaryRpcOp.accessList,
                icon: Icons.shield_outlined,
                label: l10n.meshcoreRepeaterBinaryRpcAccessList,
              ),
              const SizedBox(height: AppTheme.spacing24),
              if (_lastResult != null) _resultCard(context, _lastResult!),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _opButton(
    BuildContext context, {
    required _BinaryRpcOp op,
    required IconData icon,
    required String label,
  }) {
    final isBusy = _busyOp == op;
    final disabled = _busyOp != null && _busyOp != op;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: PrimaryGradientButton(
        label: isBusy ? context.l10n.meshcoreRepeaterBinaryRpcSending : label,
        icon: icon,
        isLoading: isBusy,
        onPressed: disabled ? null : () => _run(op),
      ),
    );
  }

  Widget _resultCard(BuildContext context, _Result result) {
    final l10n = context.l10n;
    final hex = result.bytes == null
        ? l10n.meshcoreRepeaterBinaryRpcEmptyResponse
        : _toHex(result.bytes!);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: l10n.meshcoreRepeaterBinaryRpcLastResultSection),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spacing12),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _opTitle(context, result.op),
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    if (result.bytes != null)
                      IconButton(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: hex));
                          if (!context.mounted) return;
                          showSuccessSnackBar(
                            context,
                            l10n.meshcoreRepeaterBinaryRpcCopied,
                          );
                        },
                        icon: const Icon(Icons.copy_rounded),
                        color: context.textSecondary,
                        tooltip: l10n.meshcoreRepeaterBinaryRpcCopyResult,
                      ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing4),
                SelectableText(
                  hex,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 12,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                if (result.bytes != null) ...[
                  const SizedBox(height: AppTheme.spacing4),
                  Text(
                    l10n.meshcoreRepeaterBinaryRpcResponseLength(
                      result.bytes!.length,
                    ),
                    style: TextStyle(
                      color: context.textTertiary,
                      fontSize: 11,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _toHex(Uint8List bytes) {
    final buf = StringBuffer();
    for (var i = 0; i < bytes.length; i++) {
      if (i > 0 && i % 16 == 0) {
        buf.write('\n');
      } else if (i > 0) {
        buf.write(' ');
      }
      buf.write(bytes[i].toRadixString(16).padLeft(2, '0').toUpperCase());
    }
    return buf.toString();
  }
}

class _Result {
  final _BinaryRpcOp op;
  final Uint8List? bytes;
  _Result({required this.op, required this.bytes});
}
