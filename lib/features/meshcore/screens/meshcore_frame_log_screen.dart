// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D28 Part B: MeshCore Frame Log viewer.
//
// Surfaces `MeshCoreFrameCapture` (already populated by ConnectionCoordinator
// in debug builds) so a developer / field user can inspect recent RX/TX
// frames without attaching a debugger or scraping os_log. Uses the
// existing `toCompactHex()` redaction format — no raw plaintext payloads
// beyond what the capture layer already emits to the structured log
// channel.
//
// Empty state when capture is unavailable (release build, MeshCore not
// connected, or no frames yet).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animated_empty_state.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../services/meshcore/diagnostics/meshcore_frame_decoder.dart';
import '../../../services/meshcore/protocol/meshcore_capture.dart';
import '../../../utils/snackbar.dart';
import '../../navigation/meshcore_shell.dart';

class MeshCoreFrameLogScreen extends ConsumerStatefulWidget {
  const MeshCoreFrameLogScreen({super.key});

  @override
  ConsumerState<MeshCoreFrameLogScreen> createState() =>
      _MeshCoreFrameLogScreenState();
}

class _MeshCoreFrameLogScreenState extends ConsumerState<MeshCoreFrameLogScreen>
    with LifecycleSafeMixin<MeshCoreFrameLogScreen> {
  // Local snapshot tick so the screen rebuilds on each refresh tap. The
  // capture object itself is mutable but the holding provider doesn't
  // notify on internal mutation, so we pull a fresh snapshot manually.
  int _refreshTick = 0;

  void _refresh() {
    setState(() => _refreshTick++);
  }

  Future<void> _copyAll(MeshCoreFrameCapture capture) async {
    final log = capture.toCompactHexLog();
    await Clipboard.setData(ClipboardData(text: log));
    if (!mounted) return;
    showSuccessSnackBar(
      context,
      context.l10n.meshcoreFrameLogCopied(capture.frameCount),
    );
  }

  @override
  Widget build(BuildContext context) {
    final capture = ref.watch(meshCoreCaptureProvider);
    final l10n = context.l10n;
    // Touch the tick so analyzer sees the field as live.
    _refreshTick;

    return GlassScaffold(
      leading: const MeshCoreHamburgerMenuButton(),
      title: l10n.meshcoreFrameLogTitle,
      actions: [
        if (capture != null)
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: l10n.meshcoreFrameLogRefresh,
            onPressed: _refresh,
          ),
        if (capture != null && capture.frameCount > 0)
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: l10n.meshcoreFrameLogCopy,
            onPressed: () => _copyAll(capture),
          ),
      ],
      slivers: [
        if (capture == null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AnimatedEmptyState(
              config: AnimatedEmptyStateConfig(
                icons: const [
                  Icons.bug_report_outlined,
                  Icons.terminal_outlined,
                ],
                taglines: [l10n.meshcoreFrameLogUnavailableDescription],
                titlePrefix: '',
                titleKeyword: l10n.meshcoreFrameLogUnavailableHeadline,
                titleSuffix: '',
              ),
            ),
          )
        else
          _buildFrameList(context, capture),
      ],
    );
  }

  Widget _buildFrameList(BuildContext context, MeshCoreFrameCapture capture) {
    final frames = capture.snapshot();
    final l10n = context.l10n;
    if (frames.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: AnimatedEmptyState(
          config: AnimatedEmptyStateConfig(
            icons: const [Icons.inbox_outlined, Icons.terminal_outlined],
            taglines: [l10n.meshcoreFrameLogEmptyDescription],
            titlePrefix: '',
            titleKeyword: l10n.meshcoreFrameLogEmptyHeadline,
            titleSuffix: '',
          ),
        ),
      );
    }
    // Newest first.
    final reversed = frames.reversed.toList(growable: false);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing12,
        AppTheme.spacing8,
        AppTheme.spacing12,
        AppTheme.spacing24,
      ),
      sliver: SliverList.separated(
        itemCount: reversed.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppTheme.spacing4),
        itemBuilder: (_, index) => _FrameLogRow(frame: reversed[index]),
      ),
    );
  }
}

class _FrameLogRow extends StatelessWidget {
  final CapturedFrame frame;
  const _FrameLogRow({required this.frame});

  @override
  Widget build(BuildContext context) {
    final isRx = frame.direction == CaptureDirection.rx;
    final accent = isRx ? AccentColors.cyan : AccentColors.purple;
    final codeHex =
        '0x${frame.code.toRadixString(16).padLeft(2, '0').toUpperCase()}';
    final hexBody = frame.toCompactHex();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing8,
      ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                child: Text(
                  isRx ? 'RX' : 'TX',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accent,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Text(
                codeHex,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '${frame.timestampMs}ms',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  color: context.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            hexBody,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              color: context.textSecondary,
              height: 1.3,
            ),
          ),
          // D-Q9 Row 51: decoded-field view. If the (direction,
          // opcode) pair has a registered decoder, render a small
          // table of labelled values below the raw hex. Privacy
          // invariants live in `meshcore_frame_decoder.dart`: no
          // chat bodies, no full pubkeys, no PSK bytes.
          ..._buildDecoded(context, isRx),
        ],
      ),
    );
  }

  List<Widget> _buildDecoded(BuildContext context, bool isRx) {
    final fields = decodeMeshCoreFrame(
      direction: isRx ? MeshCoreFrameDirection.rx : MeshCoreFrameDirection.tx,
      opcode: frame.code,
      payload: frame.payload,
    );
    if (fields.isEmpty) return const [];
    return [
      const SizedBox(height: AppTheme.spacing4),
      Container(
        margin: const EdgeInsets.only(top: AppTheme.spacing4),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing8,
          vertical: AppTheme.spacing4,
        ),
        decoration: BoxDecoration(
          color: context.background.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppTheme.radius8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final field in fields)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(
                        '${field.label}:',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 10,
                          color: context.textTertiary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        field.value,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 10,
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ];
  }
}
