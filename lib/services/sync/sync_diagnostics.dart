// SPDX-License-Identifier: GPL-3.0-or-later

// Sync Diagnostics — observability for Cloud Sync operations.
//
// Provides structured logging and state tracking for sync operations.
// All output is gated behind the SYNC_DIAGNOSTICS_ENABLED env flag
// so production logs are not noisy.
//
// Usage:
//   final diag = SyncDiagnostics.instance;
//   diag.recordEnqueue(SyncType.nodedexEntry);
//   diag.recordUploadSuccess(SyncType.nodedexEntry, count: 3);
//   diag.recordPullApplied(SyncType.nodedexEntry, count: 5);
//   diag.recordError(SyncType.nodedexEntry, 'Network timeout');
//   print(diag.snapshot);

import '../../core/logging.dart';
import 'sync_contract.dart';

/// Whether sync diagnostics logging is enabled.
///
/// Controlled via the `SYNC_DIAGNOSTICS_ENABLED` environment variable.
/// Defaults to false in production to avoid log noise.
bool _diagnosticsEnabled = const bool.fromEnvironment(
  'SYNC_DIAGNOSTICS_ENABLED',
  defaultValue: false,
);

/// A point-in-time snapshot of sync diagnostics state.
///
/// Returned by [SyncDiagnostics.snapshot] for display in debug panels.
class SyncDiagnosticsSnapshot {
  /// Whether the Cloud Sync entitlement is currently active.
  final bool entitlementActive;

  /// Timestamp of the last successful sync cycle completion.
  final DateTime? lastSyncTime;

  /// Number of queued outbox items per sync type.
  final Map<SyncType, int> queuedItemsByType;

  /// Last error message per sync type.
  final Map<SyncType, SyncErrorRecord> lastErrorByType;

  /// Cumulative upload success count per sync type.
  final Map<SyncType, int> uploadSuccessByType;

  /// Cumulative pull applied count per sync type.
  final Map<SyncType, int> pullAppliedByType;

  /// Cumulative conflict count per sync type.
  final Map<SyncType, int> conflictsByType;

  const SyncDiagnosticsSnapshot({
    required this.entitlementActive,
    required this.lastSyncTime,
    required this.queuedItemsByType,
    required this.lastErrorByType,
    required this.uploadSuccessByType,
    required this.pullAppliedByType,
    required this.conflictsByType,
  });

  @override
  String toString() {
    final buf = StringBuffer();
    buf.writeln('=== Sync Diagnostics ===');
    buf.writeln('Entitlement: ${entitlementActive ? "ACTIVE" : "INACTIVE"}');
    buf.writeln('Last sync: ${lastSyncTime?.toIso8601String() ?? "never"}');

    buf.writeln('--- Queued ---');
    for (final entry in queuedItemsByType.entries) {
      buf.writeln('  ${entry.key.name}: ${entry.value}');
    }

    buf.writeln('--- Uploads (cumulative) ---');
    for (final entry in uploadSuccessByType.entries) {
      buf.writeln('  ${entry.key.name}: ${entry.value}');
    }

    buf.writeln('--- Pulls applied (cumulative) ---');
    for (final entry in pullAppliedByType.entries) {
      buf.writeln('  ${entry.key.name}: ${entry.value}');
    }

    buf.writeln('--- Conflicts (cumulative) ---');
    for (final entry in conflictsByType.entries) {
      buf.writeln('  ${entry.key.name}: ${entry.value}');
    }

    if (lastErrorByType.isNotEmpty) {
      buf.writeln('--- Last Errors ---');
      for (final entry in lastErrorByType.entries) {
        buf.writeln(
          '  ${entry.key.name}: ${entry.value.message} '
          '(${entry.value.timestamp.toIso8601String()})',
        );
      }
    }

    return buf.toString();
  }
}

/// Record of the last error for a sync type.
class SyncErrorRecord {
  /// Human-readable error message.
  final String message;

  /// When the error occurred.
  final DateTime timestamp;

  /// Optional stack trace string.
  final String? stackTrace;

  const SyncErrorRecord({
    required this.message,
    required this.timestamp,
    this.stackTrace,
  });

  @override
  String toString() => '$message (${timestamp.toIso8601String()})';
}

/// Singleton diagnostics tracker for Cloud Sync operations.
///
/// Collects metrics about sync activity for debug observability.
/// All logging is gated behind [_diagnosticsEnabled] to avoid
/// production log noise.
class SyncDiagnostics {
  SyncDiagnostics._();

  /// Singleton instance.
  static final SyncDiagnostics instance = SyncDiagnostics._();

  // --- State ---

  bool _entitlementActive = false;
  DateTime? _lastSyncTime;

  final Map<SyncType, int> _queuedItems = {};
  final Map<SyncType, SyncErrorRecord> _lastErrors = {};
  final Map<SyncType, int> _uploadSuccesses = {};
  final Map<SyncType, int> _pullApplied = {};
  final Map<SyncType, int> _conflicts = {};

  // --- Public API ---

  /// Whether diagnostics logging is currently enabled.
  bool get isEnabled => _diagnosticsEnabled;

  /// Enable or disable diagnostics at runtime (for debug panels).
  // ignore: use_setters_to_change_properties
  void setEnabled(bool enabled) {
    _diagnosticsEnabled = enabled;
  }

  /// Record that the entitlement state changed.
  void recordEntitlementState(bool active) {
    _entitlementActive = active;
    _log('Entitlement: ${active ? "ACTIVE" : "INACTIVE"}');
  }

  /// Record that items were enqueued to the outbox.
  void recordEnqueue(SyncType type, {int count = 1}) {
    _queuedItems[type] = (_queuedItems[type] ?? 0) + count;
    _log('Enqueue ${type.name}: +$count (total: ${_queuedItems[type]})');
  }

  /// Record that items were successfully uploaded (drained from outbox).
  void recordUploadSuccess(SyncType type, {int count = 1}) {
    _uploadSuccesses[type] = (_uploadSuccesses[type] ?? 0) + count;
    final queued = _queuedItems[type] ?? 0;
    _queuedItems[type] = (queued - count).clamp(0, queued);
    _log(
      'Upload success ${type.name}: $count items '
      '(queued: ${_queuedItems[type]})',
    );
  }

  /// Record that items were pulled and applied from the remote.
  void recordPullApplied(SyncType type, {int count = 1}) {
    _pullApplied[type] = (_pullApplied[type] ?? 0) + count;
    _log('Pull applied ${type.name}: $count items');
  }

  /// Record a sync conflict that was detected and preserved.
  void recordConflict(SyncType type, {String? details}) {
    _conflicts[type] = (_conflicts[type] ?? 0) + 1;
    _log(
      'Conflict ${type.name}: ${details ?? "detected"} '
      '(total: ${_conflicts[type]})',
    );
  }

  /// Record that a sync cycle completed successfully.
  void recordSyncCycleComplete() {
    _lastSyncTime = DateTime.now();
    _log('Sync cycle complete at ${_lastSyncTime!.toIso8601String()}');
  }

  /// Record an error during sync for a specific type.
  void recordError(SyncType type, String message, [StackTrace? stackTrace]) {
    _lastErrors[type] = SyncErrorRecord(
      message: message,
      timestamp: DateTime.now(),
      stackTrace: stackTrace?.toString(),
    );
    _log('Error ${type.name}: $message');
    if (stackTrace != null && _diagnosticsEnabled) {
      AppLogging.debug('SyncDiag stack: $stackTrace');
    }
  }

  /// Clear the error record for a specific type (after recovery).
  void clearError(SyncType type) {
    _lastErrors.remove(type);
  }

  /// Get a point-in-time snapshot of all diagnostics state.
  SyncDiagnosticsSnapshot get snapshot => SyncDiagnosticsSnapshot(
    entitlementActive: _entitlementActive,
    lastSyncTime: _lastSyncTime,
    queuedItemsByType: Map.unmodifiable(_queuedItems),
    lastErrorByType: Map.unmodifiable(_lastErrors),
    uploadSuccessByType: Map.unmodifiable(_uploadSuccesses),
    pullAppliedByType: Map.unmodifiable(_pullApplied),
    conflictsByType: Map.unmodifiable(_conflicts),
  );

  /// Reset all diagnostics state.
  ///
  /// Useful for testing or when the user signs out.
  void reset() {
    _entitlementActive = false;
    _lastSyncTime = null;
    _queuedItems.clear();
    _lastErrors.clear();
    _uploadSuccesses.clear();
    _pullApplied.clear();
    _conflicts.clear();
    _log('Diagnostics reset');
  }

  // --- Internal ---

  void _log(String message) {
    if (_diagnosticsEnabled) {
      AppLogging.debug('SyncDiag: $message');
    }
  }
}
