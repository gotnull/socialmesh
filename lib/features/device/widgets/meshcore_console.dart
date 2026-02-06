// SPDX-License-Identifier: GPL-3.0-or-later

// MeshCore Debug Console Widget
//
// Dev-only UI for inspecting MeshCore protocol traffic.
// Shows captured TX/RX frames with metadata and provides
// copy/clear actions. Only visible in debug builds when
// connected to a MeshCore device.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../models/mesh_device.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../services/meshcore/protocol/meshcore_capture.dart';
import '../../../utils/snackbar.dart';

/// Dev-only MeshCore console for protocol inspection.
///
/// Shows captured TX/RX frames and provides clipboard/clear actions.
/// Only visible when:
/// - Connected protocol == MeshCore
/// - kDebugMode == true (debug build)
class MeshCoreConsole extends ConsumerStatefulWidget {
  const MeshCoreConsole({super.key});

  /// Whether the console should be visible for the current state.
  static bool shouldShow(MeshProtocolType? protocolType) {
    // Only show for MeshCore in debug builds
    return kDebugMode && protocolType == MeshProtocolType.meshcore;
  }

  @override
  ConsumerState<MeshCoreConsole> createState() => _MeshCoreConsoleState();
}

class _MeshCoreConsoleState extends ConsumerState<MeshCoreConsole> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final captureSnapshot = ref.watch(meshCoreCaptureSnapshotProvider);

    return Container(
      decoration: BoxDecoration(
        color: context.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AccentColors.purple.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (always visible)
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AccentColors.purple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.terminal,
                      color: AccentColors.purple,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'MeshCore Console',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AccentColors.purple.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'DEV',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AccentColors.purple,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${captureSnapshot.totalCount} frames captured',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: context.textTertiary,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          // Expanded content
          if (_expanded) ...[
            Divider(color: context.border, height: 1),
            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _onRefresh(),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AccentColors.purple,
                        side: BorderSide(
                          color: AccentColors.purple.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: captureSnapshot.hasFrames
                          ? _onCopyHexLog
                          : null,
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy Hex'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AccentColors.purple,
                        side: BorderSide(
                          color: AccentColors.purple.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: captureSnapshot.hasFrames ? _onClear : null,
                      icon: const Icon(Icons.delete_sweep, size: 18),
                      label: const Text('Clear'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorRed,
                        side: BorderSide(
                          color: AppTheme.errorRed.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Frame list
            if (captureSnapshot.hasFrames)
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: captureSnapshot.frames.length,
                  itemBuilder: (context, index) {
                    final frame = captureSnapshot.frames[index];
                    return _FrameItem(frame: frame, index: index);
                  },
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.cardAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      'No frames captured yet',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textTertiary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _onRefresh() {
    ref.read(meshCoreCaptureSnapshotProvider.notifier).refresh();
  }

  void _onCopyHexLog() {
    final hexLog = ref
        .read(meshCoreCaptureSnapshotProvider.notifier)
        .getHexLog();
    Clipboard.setData(ClipboardData(text: hexLog));
    if (mounted) {
      showSuccessSnackBar(context, 'Hex log copied to clipboard');
    }
  }

  void _onClear() {
    ref.read(meshCoreCaptureSnapshotProvider.notifier).clear();
    if (mounted) {
      showSuccessSnackBar(context, 'Capture cleared');
    }
  }
}

/// Individual frame item in the console list.
class _FrameItem extends StatelessWidget {
  final CapturedFrame frame;
  final int index;

  const _FrameItem({required this.frame, required this.index});

  @override
  Widget build(BuildContext context) {
    final isRx = frame.direction == CaptureDirection.rx;
    final dirColor = isRx ? AppTheme.primaryGreen : AccentColors.cyan;
    final dirLabel = isRx ? 'RX' : 'TX';

    // Format code as hex
    final codeHex =
        '0x${frame.code.toRadixString(16).padLeft(2, '0').toUpperCase()}';

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.cardAlt,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          // Direction badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: dirColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              dirLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: dirColor,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Timestamp
          Text(
            '@${frame.timestampMs}ms',
            style: TextStyle(
              fontSize: 11,
              color: context.textTertiary,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 12),
          // Code
          Text(
            codeHex,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          // Payload length
          Text(
            '${frame.payload.length}B',
            style: TextStyle(
              fontSize: 11,
              color: context.textSecondary,
              fontFamily: 'monospace',
            ),
          ),
          const Spacer(),
          // Index
          Text(
            '#$index',
            style: context.captionStyle?.copyWith(color: context.textTertiary),
          ),
        ],
      ),
    );
  }
}
