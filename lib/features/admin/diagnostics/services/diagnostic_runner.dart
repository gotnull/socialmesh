// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import '../../../../core/logging.dart';
import '../models/diagnostic_event.dart';
import '../models/diagnostic_summary.dart';
import 'diagnostic_capture_service.dart';
import 'diagnostic_probe.dart';

/// Callback for progress updates during a diagnostic run.
typedef DiagnosticProgressCallback =
    void Function(
      String probeName,
      int completed,
      int total,
      ProbeOutcome? lastOutcome,
    );

/// Orchestrates sequential execution of diagnostic probes.
///
/// Probes run in order, each with a fixed timeout.
/// The runner records start/end events and produces a summary.
class DiagnosticRunner {
  final DiagnosticCaptureService _capture;
  final DiagnosticContext _context;
  final List<DiagnosticProbe> _probes;
  final DiagnosticProgressCallback? onProgress;

  bool _cancelled = false;
  final List<ProbeSummaryEntry> _results = [];

  DiagnosticRunner({
    required this._capture,
    required this._context,
    required this._probes,
    this.onProgress,
  });

  /// Whether the run has been cancelled.
  bool get isCancelled => _cancelled;

  /// Results collected so far.
  List<ProbeSummaryEntry> get results => List.unmodifiable(_results);

  /// Cancel the remaining probes.
  void cancel() {
    _cancelled = true;
    AppLogging.adminDiag('Diagnostic run cancelled');
  }

  /// Execute all probes sequentially.
  ///
  /// Returns a [DiagnosticSummary] with results for each probe.
  /// If cancelled, returns partial results.
  Future<List<ProbeSummaryEntry>> run() async {
    AppLogging.adminDiag('Starting diagnostic run: ${_probes.length} probes');

    for (var i = 0; i < _probes.length; i++) {
      if (_cancelled) {
        AppLogging.adminDiag('Run cancelled at probe ${i + 1}');
        // Mark remaining as skipped
        for (var j = i; j < _probes.length; j++) {
          _results.add(
            ProbeSummaryEntry(
              name: _probes[j].name,
              status: 'skipped',
              durationMs: 0,
              errorExcerpt: 'Run cancelled',
            ),
          );
        }
        break;
      }

      final probe = _probes[i];
      onProgress?.call(probe.name, i, _probes.length, null);

      AppLogging.adminDiag('Probe ${i + 1}/${_probes.length}: ${probe.name}');
      _capture.recordInternal(
        phase: DiagnosticPhase.probe,
        probeName: probe.name,
        notes: 'start',
      );

      final stopwatch = Stopwatch()..start();
      ProbeResult result;

      try {
        // Use probe-specific maxDuration if provided (e.g. stress probes
        // that send multiple requests), otherwise fall back to the
        // context's per-request timeout.
        final outerTimeout = probe.maxDuration ?? _context.timeout;
        result = await probe
            .run(_context)
            .timeout(
              outerTimeout,
              onTimeout: () => ProbeResult(
                outcome: ProbeOutcome.fail,
                durationMs: stopwatch.elapsedMilliseconds,
                error: 'Timeout after ${outerTimeout.inSeconds}s',
              ),
            );
      } catch (e, stack) {
        AppLogging.adminDiag('Probe ${probe.name} threw: $e\n$stack');
        result = ProbeResult(
          outcome: ProbeOutcome.fail,
          durationMs: stopwatch.elapsedMilliseconds,
          error: e.toString(),
        );
      }
      stopwatch.stop();

      final entry = ProbeSummaryEntry(
        name: probe.name,
        status: result.outcome.name,
        durationMs: result.durationMs,
        errorExcerpt: result.error,
      );
      _results.add(entry);

      _capture.recordInternal(
        phase: DiagnosticPhase.probe,
        probeName: probe.name,
        notes:
            'end: ${result.outcome.name}'
            '${result.error != null ? " (${result.error})" : ""}',
      );

      onProgress?.call(probe.name, i + 1, _probes.length, result.outcome);

      AppLogging.adminDiag(
        'Probe ${probe.name}: ${result.outcome.name} '
        '(${result.durationMs}ms)'
        '${result.error != null ? " error=${result.error}" : ""}',
      );
    }

    AppLogging.adminDiag(
      'Diagnostic run complete: '
      '${_results.where((r) => r.status == "pass").length} pass, '
      '${_results.where((r) => r.status == "fail").length} fail, '
      '${_results.where((r) => r.status == "skipped").length} skipped',
    );

    return _results;
  }
}
