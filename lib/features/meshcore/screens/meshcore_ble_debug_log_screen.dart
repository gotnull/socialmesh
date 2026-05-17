// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q5: BLE debug log viewer. Renders the in-memory ring buffer
// fed by `MeshCoreBleTransport` (see
// `lib/services/meshcore/diagnostics/meshcore_ble_debug_log_store.dart`).
// Distinct from D44's app-wide log viewer and D28's frame log; this
// is transport-only.
//
// In-memory only. No persistence, no export-to-file path — the
// D-Q6 diagnostics bundle remains the canonical export surface.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../providers/meshcore_ble_debug_log_provider.dart';
import '../../../services/meshcore/diagnostics/meshcore_ble_debug_log_store.dart';
import '../../../utils/snackbar.dart';

class MeshCoreBleDebugLogScreen extends ConsumerStatefulWidget {
  const MeshCoreBleDebugLogScreen({super.key});

  @override
  ConsumerState<MeshCoreBleDebugLogScreen> createState() =>
      _MeshCoreBleDebugLogScreenState();
}

class _MeshCoreBleDebugLogScreenState
    extends ConsumerState<MeshCoreBleDebugLogScreen>
    with LifecycleSafeMixin {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final snapshotAsync = ref.watch(meshCoreBleDebugLogSnapshotProvider);
    final store = ref.watch(meshCoreBleDebugLogStoreProvider);

    return GlassScaffold.body(
      hasScrollBody: true,
      title: l10n.meshcoreBleDebugLogTitle,
      body: snapshotAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing24),
            child: Text(
              '$error',
              style: TextStyle(color: context.textSecondary),
            ),
          ),
        ),
        data: (snapshot) => _buildBody(context, snapshot, store),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    MeshCoreBleDebugLogSnapshot snapshot,
    MeshCoreBleDebugLogStore store,
  ) {
    final l10n = context.l10n;
    final entries = snapshot.entries.reversed.toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          entryCount: snapshot.entries.length,
          paused: snapshot.paused,
          onTogglePaused: () {
            if (snapshot.paused) {
              store.resume();
            } else {
              store.pause();
            }
          },
          onClear: snapshot.entries.isEmpty
              ? null
              : () {
                  store.clear();
                  showSuccessSnackBar(context, l10n.meshcoreBleDebugLogCleared);
                },
          onCopyAll: snapshot.entries.isEmpty
              ? null
              : () => _copyAll(context, snapshot.entries),
        ),
        const Divider(height: 1),
        Expanded(
          child: entries.isEmpty
              ? _EmptyState(paused: snapshot.paused)
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing16,
                    vertical: AppTheme.spacing12,
                  ),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppTheme.spacing8),
                  itemBuilder: (context, index) {
                    return _EntryTile(entry: entries[index]);
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _copyAll(
    BuildContext context,
    List<MeshCoreBleDebugLogEntry> entries,
  ) async {
    final l10n = context.l10n;
    final text = entries.map(_formatEntry).join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    showSuccessSnackBar(context, l10n.meshcoreBleDebugLogCopied);
  }

  static String _formatEntry(MeshCoreBleDebugLogEntry e) {
    final ts = e.timestamp.toIso8601String();
    final sev = e.severity.name.toUpperCase();
    final cat = e.category.name;
    return '$ts [$sev][$cat] ${e.message}';
  }
}

class _Header extends StatelessWidget {
  final int entryCount;
  final bool paused;
  final VoidCallback onTogglePaused;
  final VoidCallback? onClear;
  final VoidCallback? onCopyAll;

  const _Header({
    required this.entryCount,
    required this.paused,
    required this.onTogglePaused,
    this.onClear,
    this.onCopyAll,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing12,
      ),
      child: Row(
        children: [
          Text(
            l10n.meshcoreBleDebugLogEntryCount(entryCount),
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 13,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          InkWell(
            onTap: onTogglePaused,
            borderRadius: BorderRadius.circular(AppTheme.radius8),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing8,
                vertical: AppTheme.spacing4,
              ),
              decoration: BoxDecoration(
                color: paused
                    ? AppTheme.warningYellow.withValues(alpha: 0.15)
                    : context.card,
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    paused
                        ? Icons.pause_circle_outline_rounded
                        : Icons.play_circle_outline_rounded,
                    size: 14,
                    color: paused
                        ? AppTheme.warningYellow
                        : context.textSecondary,
                  ),
                  const SizedBox(width: AppTheme.spacing4),
                  Text(
                    paused
                        ? l10n.meshcoreBleDebugLogPaused
                        : l10n.meshcoreBleDebugLogLive,
                    style: TextStyle(
                      color: paused
                          ? AppTheme.warningYellow
                          : context.textSecondary,
                      fontSize: 12,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onCopyAll,
            icon: const Icon(Icons.copy_all_rounded),
            color: context.textSecondary,
            tooltip: l10n.meshcoreBleDebugLogCopyAll,
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.delete_outline_rounded),
            color: context.textSecondary,
            tooltip: l10n.meshcoreBleDebugLogClear,
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final MeshCoreBleDebugLogEntry entry;
  const _EntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(context, entry.severity);
    final timestamp = _formatTime(entry.timestamp);
    return InkWell(
      onTap: () async {
        await Clipboard.setData(
          ClipboardData(text: '${entry.category.name}: ${entry.message}'),
        );
        if (!context.mounted) return;
        showSuccessSnackBar(
          context,
          context.l10n.meshcoreBleDebugLogEntryCopied,
        );
      },
      borderRadius: BorderRadius.circular(AppTheme.radius8),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing12,
          vertical: AppTheme.spacing8,
        ),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius8),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  timestamp,
                  style: TextStyle(
                    color: context.textTertiary,
                    fontSize: 11,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radius4),
                  ),
                  child: Text(
                    entry.severity.name.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing6),
                Text(
                  '[${entry.category.name}]',
                  style: TextStyle(
                    color: context.textTertiary,
                    fontSize: 11,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing4),
            Text(
              entry.message,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 13,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    final ms = t.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  static Color _severityColor(
    BuildContext context,
    MeshCoreBleDebugLogSeverity s,
  ) {
    switch (s) {
      case MeshCoreBleDebugLogSeverity.info:
        return context.accentColor;
      case MeshCoreBleDebugLogSeverity.warn:
        return AppTheme.warningYellow;
      case MeshCoreBleDebugLogSeverity.error:
        return AppTheme.errorRed;
    }
  }
}

class _EmptyState extends StatelessWidget {
  final bool paused;
  const _EmptyState({required this.paused});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              paused
                  ? Icons.pause_circle_outline_rounded
                  : Icons.bluetooth_searching_rounded,
              size: 48,
              color: context.textTertiary,
            ),
            const SizedBox(height: AppTheme.spacing12),
            Text(
              paused
                  ? l10n.meshcoreBleDebugLogEmptyPaused
                  : l10n.meshcoreBleDebugLogEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
