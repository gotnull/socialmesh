// SPDX-License-Identifier: GPL-3.0-or-later

// Sync Probe Result — shared result type for deterministic end-to-end
// sync validation probes.
//
// Used by:
// - NodeDexSyncService.runSyncProbe()
// - AutomationSyncService.runSyncProbe()
// - WidgetSyncService.runSyncProbe()
//
// Each probe creates a test entity, pushes it through the outbox to
// Firestore, pulls it back, verifies the round-trip, and cleans up.
// The result captures per-stage status and detailed logs for diagnosis.

/// Result of a sync probe execution.
///
/// Captures the outcome of each stage (A through I) along with
/// detailed log lines for debugging sync pipeline issues.
///
/// Stages:
///   A — Entitlement check (is sync enabled?)
///   B — Firebase auth check (is user signed in?)
///   C — Create test entity locally (write to SQLite + outbox)
///   D — Verify outbox contains the entry
///   E — Drain outbox to Firestore (push)
///   F — Verify document exists in Firestore (read-back)
///   G — Reset watermark and pull from Firestore
///   H — Verify entity exists locally after pull (round-trip data match)
///   I — Clean up probe data (local + remote)
class SyncProbeResult {
  /// Whether all stages passed.
  final bool ok;

  /// The stage that failed (null if all passed).
  final String? failedStage;

  /// Status of each stage (A through I).
  ///
  /// Values are prefixed with 'OK:', 'FAIL:', or 'WARN:' followed
  /// by a human-readable description.
  final Map<String, String> stages;

  /// Detailed log lines from the probe execution.
  ///
  /// Each line is timestamped relative to probe start and prefixed
  /// with the stage letter for easy filtering.
  final List<String> logs;

  /// Which sync domain this probe was run against.
  ///
  /// e.g. 'NodeDex', 'Automations', 'Widgets'
  final String? domain;

  const SyncProbeResult({
    required this.ok,
    required this.failedStage,
    required this.stages,
    required this.logs,
    this.domain,
  });

  /// Create a failed result at a specific stage.
  ///
  /// Convenience factory for the common pattern of returning early
  /// when a stage fails.
  factory SyncProbeResult.failed({
    required String stage,
    required String reason,
    required Map<String, String> stages,
    required List<String> logs,
    String? domain,
  }) {
    return SyncProbeResult(
      ok: false,
      failedStage: stage,
      stages: stages,
      logs: logs,
      domain: domain,
    );
  }

  /// Create a successful result after all stages pass.
  factory SyncProbeResult.success({
    required Map<String, String> stages,
    required List<String> logs,
    String? domain,
  }) {
    return SyncProbeResult(
      ok: true,
      failedStage: null,
      stages: stages,
      logs: logs,
      domain: domain,
    );
  }

  /// A compact one-line summary suitable for log output.
  String get summary {
    final prefix = domain != null ? '[$domain] ' : '';
    if (ok) {
      return '${prefix}PROBE OK — ${stages.length} stages passed';
    }
    final failMsg = stages[failedStage] ?? 'unknown';
    return '${prefix}PROBE FAIL at stage $failedStage — $failMsg';
  }

  @override
  String toString() {
    final buf = StringBuffer();
    final prefix = domain != null ? ' ($domain)' : '';
    buf.writeln('SyncProbeResult$prefix(ok=$ok, failedStage=$failedStage)');
    for (final entry in stages.entries) {
      buf.writeln('  ${entry.key}: ${entry.value}');
    }
    return buf.toString();
  }
}
