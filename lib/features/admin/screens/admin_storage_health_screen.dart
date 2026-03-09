// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Admin Storage Health screen.
///
/// Verifies that every SQLite database is open in WAL mode by querying
/// `PRAGMA journal_mode` on a short-lived read-only connection, and reports
/// the actual mode returned, the file size, and whether the WAL/SHM sidecar
/// files are present.
///
/// This screen is read-only and produces no side effects on any database.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../utils/snackbar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Database manifest
// ─────────────────────────────────────────────────────────────────────────────

/// All databases that should be in WAL mode, keyed by display label.
/// Path is relative to `getApplicationDocumentsDirectory()` unless
/// [isSubdir] is true.
class _DbEntry {
  const _DbEntry(this.label, this.relativePath);

  final String label;

  /// Path relative to the application documents directory.
  final String relativePath;
}

const List<_DbEntry> _databases = [
  _DbEntry('messages', 'messages.db'),
  _DbEntry('signals', 'signals.db'),
  _DbEntry('telemetry', 'telemetry.db'),
  _DbEntry('routes', 'routes.db'),
  _DbEntry('nodedex', 'nodedex.db'),
  _DbEntry('traceroute', 'traceroute_history.db'),
  _DbEntry('automations', 'automations.db'),
  _DbEntry('widgets', 'widgets.db'),
  _DbEntry('tak_events', 'tak_events.db'),
  _DbEntry('incidents', 'incidents.db'),
  _DbEntry('tasks', 'tasks.db'),
  _DbEntry('file_transfers', 'file_transfers.db'),
  _DbEntry('mesh_services', 'mesh_services.db'),
  _DbEntry('packet_dedupe', 'cache/mesh_seen_packets.db'),
];

// ─────────────────────────────────────────────────────────────────────────────
// Result model
// ─────────────────────────────────────────────────────────────────────────────

enum _WalStatus { wal, other, missing, error }

class _DbResult {
  const _DbResult({
    required this.label,
    required this.path,
    required this.status,
    this.actualMode,
    this.fileSizeBytes,
    this.hasWalFile = false,
    this.hasShmFile = false,
    this.error,
    required this.durationMs,
  });

  final String label;
  final String path;
  final _WalStatus status;
  final String? actualMode;
  final int? fileSizeBytes;
  final bool hasWalFile;
  final bool hasShmFile;
  final String? error;
  final int durationMs;

  bool get passed => status == _WalStatus.wal;
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class AdminStorageHealthScreen extends StatefulWidget {
  const AdminStorageHealthScreen({super.key});

  @override
  State<AdminStorageHealthScreen> createState() =>
      _AdminStorageHealthScreenState();
}

class _AdminStorageHealthScreenState extends State<AdminStorageHealthScreen> {
  bool _isRunning = false;
  List<_DbResult>? _results;
  String? _docsDir;

  int get _passCount => _results?.where((r) => r.passed).length ?? 0;
  int get _failCount => _results?.where((r) => !r.passed).length ?? 0;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _results = null;
    });

    final dir = await getApplicationDocumentsDirectory();
    _docsDir = dir.path;
    final results = <_DbResult>[];

    for (final entry in _databases) {
      results.add(await _checkDatabase(entry, dir.path));
    }

    if (mounted) {
      setState(() {
        _results = results;
        _isRunning = false;
      });
    }
  }

  Future<_DbResult> _checkDatabase(_DbEntry entry, String docsDir) async {
    final sw = Stopwatch()..start();
    final fullPath = p.join(docsDir, entry.relativePath);
    final dbFile = File(fullPath);

    // If the file doesn't exist yet the database has never been opened.
    if (!await dbFile.exists()) {
      return _DbResult(
        label: entry.label,
        path: fullPath,
        status: _WalStatus.missing,
        durationMs: sw.elapsedMilliseconds,
      );
    }

    final fileSizeBytes = await dbFile.length();
    final hasWal = await File('$fullPath-wal').exists();
    final hasShm = await File('$fullPath-shm').exists();

    Database? db;
    try {
      // Open read-only — no migrations, no schema changes.
      db = await openReadOnlyDatabase(fullPath);

      final rows = await db.rawQuery('PRAGMA journal_mode');
      final mode = rows.isNotEmpty
          ? (rows.first['journal_mode'] as String?)?.toLowerCase()
          : null;

      return _DbResult(
        label: entry.label,
        path: fullPath,
        status: mode == 'wal' ? _WalStatus.wal : _WalStatus.other,
        actualMode: mode ?? 'unknown', // lint-allow: hardcoded-string
        fileSizeBytes: fileSizeBytes,
        hasWalFile: hasWal,
        hasShmFile: hasShm,
        durationMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      return _DbResult(
        label: entry.label,
        path: fullPath,
        status: _WalStatus.error,
        fileSizeBytes: fileSizeBytes,
        hasWalFile: hasWal,
        hasShmFile: hasShm,
        error: e.toString(),
        durationMs: sw.elapsedMilliseconds,
      );
    } finally {
      await db?.close();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: context.l10n.adminStorageHealthTitle,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: context.l10n.adminStorageHealthRefresh,
          onPressed: _isRunning ? null : _run,
        ),
      ],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildSummaryCard(context),
              const SizedBox(height: AppTheme.spacing16),
              if (_isRunning) _buildSpinner(context),
              if (_results != null) ...[
                for (final result in _results!) ...[
                  _DbResultTile(result: result, docsDir: _docsDir ?? ''),
                  const SizedBox(height: AppTheme.spacing8),
                ],
              ],
              SizedBox(
                height:
                    MediaQuery.of(context).padding.bottom + AppTheme.spacing16,
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final results = _results;

    if (_isRunning || results == null) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spacing12),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(color: context.border.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.storage_rounded, color: context.accentColor, size: 20),
            const SizedBox(width: AppTheme.spacing10),
            Text(
              context.l10n.adminStorageHealthChecking,
              style: TextStyle(color: context.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final allPass = _failCount == 0;
    final statusColor = allPass ? AccentColors.green : AppTheme.errorRed;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            allPass ? Icons.check_circle_outline : Icons.warning_amber_rounded,
            color: statusColor,
            size: 24,
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allPass
                      ? context.l10n.adminStorageHealthAllPass
                      : context.l10n.adminStorageHealthSomeFail,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing2),
                Text(
                  context.l10n.adminStorageHealthSummary(
                    _passCount,
                    _failCount,
                    _databases.length,
                  ),
                  style: TextStyle(color: context.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpinner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing32),
      child: Center(
        child: Column(
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: context.accentColor,
              ),
            ),
            const SizedBox(height: AppTheme.spacing12),
            Text(
              context.l10n.adminStorageHealthChecking,
              style: TextStyle(color: context.textTertiary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-database tile
// ─────────────────────────────────────────────────────────────────────────────

class _DbResultTile extends StatelessWidget {
  const _DbResultTile({required this.result, required this.docsDir});

  final _DbResult result;
  final String docsDir;

  Color _statusColor(BuildContext context) => switch (result.status) {
    _WalStatus.wal => AccentColors.green,
    _WalStatus.other => AppTheme.warningYellow,
    _WalStatus.missing => context.textTertiary,
    _WalStatus.error => AppTheme.errorRed,
  };

  IconData get _statusIcon => switch (result.status) {
    _WalStatus.wal => Icons.check_circle_outline,
    _WalStatus.other => Icons.warning_amber_rounded,
    _WalStatus.missing => Icons.hourglass_empty,
    _WalStatus.error => Icons.error_outline,
  };

  String _statusLabel(BuildContext context) => switch (result.status) {
    _WalStatus.wal => context.l10n.adminStorageStatusWal,
    _WalStatus.other =>
      result.actualMode?.toUpperCase() ??
          context.l10n.adminStorageStatusUnknown,
    _WalStatus.missing => context.l10n.adminStorageStatusMissing,
    _WalStatus.error => context.l10n.adminStorageStatusError,
  };

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context);
    final relPath = result.path.replaceFirst('$docsDir/', '');

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        Clipboard.setData(ClipboardData(text: result.path));
        showInfoSnackBar(context, context.l10n.adminStoragePathCopied);
      },
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing12),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(
            color: result.passed
                ? context.border.withValues(alpha: 0.2)
                : color.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(_statusIcon, color: color, size: 18),
                const SizedBox(width: AppTheme.spacing8),
                Expanded(
                  child: Text(
                    result.label,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                // Mode badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radius6),
                  ),
                  child: Text(
                    _statusLabel(context),
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing8),
                Text(
                  '${result.durationMs}ms',
                  style: TextStyle(color: context.textTertiary, fontSize: 11),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacing6),

            // Path
            Text(
              relPath,
              style: TextStyle(
                color: context.textTertiary,
                fontSize: 11,
                fontFamily: AppTheme.fontFamily,
              ),
              overflow: TextOverflow.ellipsis,
            ),

            // Details row
            if (result.status != _WalStatus.missing) ...[
              const SizedBox(height: AppTheme.spacing6),
              Wrap(
                spacing: AppTheme.spacing8,
                runSpacing: 4,
                children: [
                  if (result.fileSizeBytes != null)
                    _Chip(
                      icon: Icons.storage,
                      label: _formatBytes(result.fileSizeBytes!),
                      color: context.textTertiary,
                    ),
                  _Chip(
                    icon: Icons.edit_document,
                    label: result.hasWalFile
                        ? context.l10n.adminStorageWalPresent
                        : context.l10n.adminStorageWalAbsent,
                    color: result.hasWalFile
                        ? AccentColors.green
                        : context.textTertiary,
                  ),
                  _Chip(
                    icon: Icons.memory,
                    label: result.hasShmFile
                        ? context.l10n.adminStorageShmPresent
                        : context.l10n.adminStorageShmAbsent,
                    color: result.hasShmFile
                        ? AccentColors.green
                        : context.textTertiary,
                  ),
                ],
              ),
            ],

            // Error
            if (result.error != null) ...[
              const SizedBox(height: AppTheme.spacing6),
              Text(
                result.error!,
                style: TextStyle(color: AppTheme.errorRed, fontSize: 11),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared chip widget
// ─────────────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: AppTheme.spacing3),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
