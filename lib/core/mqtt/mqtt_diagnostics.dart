// SPDX-License-Identifier: GPL-3.0-or-later

/// Diagnostics model for the Global Layer (MQTT) feature.
///
/// This module defines the diagnostic checks that the "Why isn't it
/// working?" flow runs. Each check is a discrete, testable step that
/// verifies one aspect of the broker connection. Results are surfaced
/// in the diagnostics UI with actionable suggestions.
///
/// The diagnostics engine is designed to be run against a
/// [GlobalLayerConfig] without requiring an active connection,
/// making it useful for both pre-connection setup validation and
/// post-failure troubleshooting.
library;

import 'dart:convert';

import 'mqtt_config.dart';
import 'mqtt_connection_state.dart';
import 'mqtt_metrics.dart';

/// The outcome of a single diagnostic check.
enum DiagnosticStatus {
  /// The check has not been run yet.
  pending,

  /// The check is currently executing.
  running,

  /// The check completed successfully.
  passed,

  /// The check completed with a warning (non-blocking).
  warning,

  /// The check failed (blocking — likely cause of the problem).
  failed,

  /// The check was skipped because a prerequisite failed.
  skipped;

  /// Human-readable label for the status badge.
  String get displayLabel => switch (this) {
    pending => 'Pending',
    running => 'Running',
    passed => 'Passed',
    warning => 'Warning',
    failed => 'Failed',
    skipped => 'Skipped',
  };

  /// Whether this status represents a completed check (success or failure).
  bool get isComplete => switch (this) {
    passed || warning || failed || skipped => true,
    _ => false,
  };

  /// Whether this status indicates a problem.
  bool get isProblem => this == failed || this == warning;
}

/// Identifies which diagnostic check is being described.
///
/// The order of these values matches the recommended execution order
/// in the diagnostics flow. Each check depends on the previous one
/// passing — if DNS fails, TCP/TLS/Auth checks are skipped.
enum DiagnosticCheckType {
  /// Validates that the config fields are well-formed before
  /// attempting any network operations.
  configValidation,

  /// Resolves the broker hostname to an IP address.
  dnsResolution,

  /// Establishes a raw TCP connection to the broker host and port.
  tcpConnection,

  /// Performs the TLS handshake (only if TLS is enabled in config).
  tlsHandshake,

  /// Authenticates with the broker using configured credentials.
  authentication,

  /// Subscribes to a test topic to verify subscribe permissions.
  subscribeTest,

  /// Publishes a test message to verify publish permissions.
  publishTest;

  /// Human-readable title for the check.
  String get title => switch (this) {
    configValidation => 'Configuration',
    dnsResolution => 'DNS Resolution',
    tcpConnection => 'TCP Connection',
    tlsHandshake => 'TLS Handshake',
    authentication => 'Authentication',
    subscribeTest => 'Subscribe Test',
    publishTest => 'Publish Test',
  };

  /// Longer description of what this check verifies.
  String get description => switch (this) {
    configValidation =>
      'Verifying that the broker address, port, and topic root '
          'are correctly formatted.',
    dnsResolution =>
      'Looking up the broker hostname to find its network address.',
    tcpConnection => 'Establishing a network connection to the broker.',
    tlsHandshake =>
      'Negotiating a secure (encrypted) connection with the broker.',
    authentication => 'Verifying your username and password with the broker.',
    subscribeTest => 'Subscribing to a test topic to verify read access.',
    publishTest => 'Publishing a test message to verify write access.',
  };

  /// Icon name (Material Icons) for the check.
  String get iconName => switch (this) {
    configValidation => 'checklist_outlined',
    dnsResolution => 'dns_outlined',
    tcpConnection => 'cable_outlined',
    tlsHandshake => 'lock_outlined',
    authentication => 'badge_outlined',
    subscribeTest => 'download_outlined',
    publishTest => 'upload_outlined',
  };

  /// Whether this check is a prerequisite for subsequent checks.
  ///
  /// If a prerequisite check fails, all subsequent checks are skipped.
  bool get isPrerequisite => switch (this) {
    configValidation || dnsResolution || tcpConnection => true,
    tlsHandshake => true, // Only prerequisite when TLS is enabled
    authentication => true,
    subscribeTest || publishTest => false,
  };

  /// The check that must pass before this one can run.
  /// Returns `null` for the first check in the chain.
  DiagnosticCheckType? get prerequisite => switch (this) {
    configValidation => null,
    dnsResolution => configValidation,
    tcpConnection => dnsResolution,
    tlsHandshake => tcpConnection,
    authentication => tlsHandshake, // Skips to tcpConnection if TLS is off
    subscribeTest => authentication,
    publishTest => authentication,
  };

  /// Returns the effective prerequisite, accounting for TLS being
  /// disabled (in which case [tlsHandshake] is skipped and
  /// [authentication] depends directly on [tcpConnection]).
  DiagnosticCheckType? effectivePrerequisite({required bool tlsEnabled}) {
    if (this == authentication && !tlsEnabled) {
      return tcpConnection;
    }
    if (this == tlsHandshake && !tlsEnabled) {
      return null; // Will be skipped entirely
    }
    return prerequisite;
  }
}

/// The result of a single diagnostic check.
class DiagnosticCheckResult {
  /// Which check this result is for.
  final DiagnosticCheckType type;

  /// The outcome status.
  final DiagnosticStatus status;

  /// Human-readable message describing the result.
  ///
  /// For passed checks, this is a brief confirmation.
  /// For failed checks, this describes what went wrong.
  final String message;

  /// Detailed suggestion for how to fix a failure or warning.
  /// Only populated when [status] is [DiagnosticStatus.failed]
  /// or [DiagnosticStatus.warning].
  final String? suggestion;

  /// Optional list of config field names that are relevant to this
  /// result. Used by the UI to highlight the offending fields.
  final List<String> relatedFields;

  /// How long the check took to execute, if measured.
  final Duration? duration;

  /// Timestamp when this check completed.
  final DateTime? completedAt;

  const DiagnosticCheckResult({
    required this.type,
    required this.status,
    required this.message,
    this.suggestion,
    this.relatedFields = const [],
    this.duration,
    this.completedAt,
  });

  /// Convenience constructor for a pending check.
  const DiagnosticCheckResult.pending(this.type)
    : status = DiagnosticStatus.pending,
      message = '',
      suggestion = null,
      relatedFields = const [],
      duration = null,
      completedAt = null;

  /// Convenience constructor for a running check.
  const DiagnosticCheckResult.running(this.type)
    : status = DiagnosticStatus.running,
      message = '',
      suggestion = null,
      relatedFields = const [],
      duration = null,
      completedAt = null;

  /// Convenience constructor for a skipped check.
  DiagnosticCheckResult.skipped(this.type, {String? reason})
    : status = DiagnosticStatus.skipped,
      message = reason ?? 'Skipped because a previous check failed.',
      suggestion = null,
      relatedFields = const [],
      duration = null,
      completedAt = DateTime.now();

  /// Convenience constructor for a passed check.
  DiagnosticCheckResult.passed(this.type, this.message, {this.duration})
    : status = DiagnosticStatus.passed,
      suggestion = null,
      relatedFields = const [],
      completedAt = DateTime.now();

  /// Convenience constructor for a failed check.
  DiagnosticCheckResult.failed(
    this.type, {
    required this.message,
    this.suggestion,
    this.relatedFields = const [],
    this.duration,
  }) : status = DiagnosticStatus.failed,
       completedAt = DateTime.now();

  /// Convenience constructor for a warning check.
  DiagnosticCheckResult.warning(
    this.type, {
    required this.message,
    this.suggestion,
    this.relatedFields = const [],
    this.duration,
  }) : status = DiagnosticStatus.warning,
       completedAt = DateTime.now();

  /// Returns a copy with an updated status and optional new message.
  DiagnosticCheckResult copyWith({
    DiagnosticStatus? status,
    String? message,
    String? suggestion,
    List<String>? relatedFields,
    Duration? duration,
    DateTime? completedAt,
  }) {
    return DiagnosticCheckResult(
      type: type,
      status: status ?? this.status,
      message: message ?? this.message,
      suggestion: suggestion ?? this.suggestion,
      relatedFields: relatedFields ?? this.relatedFields,
      duration: duration ?? this.duration,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'status': status.name,
    'message': message,
    if (suggestion != null) 'suggestion': suggestion,
    if (relatedFields.isNotEmpty) 'relatedFields': relatedFields,
    if (duration != null) 'durationMs': duration!.inMilliseconds,
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
  };

  @override
  String toString() =>
      'DiagnosticCheckResult(${type.name}: ${status.name}'
      '${message.isNotEmpty ? " — $message" : ""})';
}

/// The complete result of a diagnostics run.
///
/// Contains the result of every check, the overall verdict, and
/// a summary suitable for clipboard export.
class DiagnosticReport {
  /// Individual check results, in execution order.
  final List<DiagnosticCheckResult> results;

  /// When the diagnostics run started.
  final DateTime startedAt;

  /// When the diagnostics run completed (all checks done or aborted).
  final DateTime? completedAt;

  /// The connection state at the time diagnostics were run.
  final GlobalLayerConnectionState connectionState;

  /// Redacted config snapshot taken at the start of the run.
  final Map<String, dynamic>? configSnapshot;

  const DiagnosticReport({
    required this.results,
    required this.startedAt,
    this.completedAt,
    this.connectionState = GlobalLayerConnectionState.disconnected,
    this.configSnapshot,
  });

  /// Creates an empty report with all checks in pending state.
  factory DiagnosticReport.initial({
    required bool tlsEnabled,
    GlobalLayerConnectionState connectionState =
        GlobalLayerConnectionState.disconnected,
    Map<String, dynamic>? configSnapshot,
  }) {
    final checks = <DiagnosticCheckResult>[];
    for (final type in DiagnosticCheckType.values) {
      // Skip TLS check if TLS is not enabled
      if (type == DiagnosticCheckType.tlsHandshake && !tlsEnabled) {
        continue;
      }
      checks.add(DiagnosticCheckResult.pending(type));
    }
    return DiagnosticReport(
      results: checks,
      startedAt: DateTime.now(),
      connectionState: connectionState,
      configSnapshot: configSnapshot,
    );
  }

  // ---------------------------------------------------------------------------
  // Derived properties
  // ---------------------------------------------------------------------------

  /// Whether all checks have completed (or been skipped).
  bool get isComplete => results.every((r) => r.status.isComplete);

  /// Whether the diagnostics run is currently in progress.
  bool get isRunning =>
      results.any((r) => r.status == DiagnosticStatus.running);

  /// Overall pass/fail verdict.
  DiagnosticStatus get overallStatus {
    if (!isComplete) return DiagnosticStatus.running;
    if (results.any((r) => r.status == DiagnosticStatus.failed)) {
      return DiagnosticStatus.failed;
    }
    if (results.any((r) => r.status == DiagnosticStatus.warning)) {
      return DiagnosticStatus.warning;
    }
    return DiagnosticStatus.passed;
  }

  /// The first failed check, if any. This is typically the root cause.
  DiagnosticCheckResult? get firstFailure {
    for (final result in results) {
      if (result.status == DiagnosticStatus.failed) {
        return result;
      }
    }
    return null;
  }

  /// All checks that failed or warned.
  List<DiagnosticCheckResult> get problems =>
      results.where((r) => r.status.isProblem).toList(growable: false);

  /// Number of checks that passed.
  int get passedCount =>
      results.where((r) => r.status == DiagnosticStatus.passed).length;

  /// Number of checks that failed.
  int get failedCount =>
      results.where((r) => r.status == DiagnosticStatus.failed).length;

  /// Total number of checks (excluding skipped).
  int get activeCheckCount =>
      results.where((r) => r.status != DiagnosticStatus.skipped).length;

  /// Progress as a value between 0.0 and 1.0.
  double get progress {
    if (results.isEmpty) return 0;
    final completed = results.where((r) => r.status.isComplete).length;
    return completed / results.length;
  }

  /// Duration of the entire diagnostics run.
  Duration? get totalDuration {
    if (completedAt == null) return null;
    return completedAt!.difference(startedAt);
  }

  // ---------------------------------------------------------------------------
  // Mutation (returns new instance)
  // ---------------------------------------------------------------------------

  /// Returns a new report with the result for [type] updated.
  DiagnosticReport updateResult(DiagnosticCheckResult result) {
    final updated = results
        .map((r) {
          if (r.type == result.type) return result;
          return r;
        })
        .toList(growable: false);

    // Check if all are now complete
    final allComplete = updated.every((r) => r.status.isComplete);

    return DiagnosticReport(
      results: updated,
      startedAt: startedAt,
      completedAt: allComplete ? DateTime.now() : completedAt,
      connectionState: connectionState,
      configSnapshot: configSnapshot,
    );
  }

  /// Marks the report as complete with the current timestamp.
  DiagnosticReport markComplete() {
    return DiagnosticReport(
      results: results,
      startedAt: startedAt,
      completedAt: DateTime.now(),
      connectionState: connectionState,
      configSnapshot: configSnapshot,
    );
  }

  /// Returns the result for a specific check type, or `null` if not present.
  DiagnosticCheckResult? resultFor(DiagnosticCheckType type) {
    for (final result in results) {
      if (result.type == type) return result;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  /// Produces a clipboard-safe diagnostics summary.
  ///
  /// All sensitive data is redacted. This output is designed to be
  /// pasted into support channels or bug reports.
  String toClipboardSummary() {
    final buffer = StringBuffer();
    buffer.writeln('Global Layer Diagnostics Report');
    buffer.writeln('=' * 40);
    buffer.writeln('Date: ${startedAt.toIso8601String()}');
    buffer.writeln('Connection state: ${connectionState.displayLabel}');
    buffer.writeln('Overall: ${overallStatus.displayLabel}');
    if (totalDuration != null) {
      buffer.writeln('Duration: ${totalDuration!.inMilliseconds}ms');
    }
    buffer.writeln();

    for (final result in results) {
      final icon = switch (result.status) {
        DiagnosticStatus.passed => '[OK]',
        DiagnosticStatus.warning => '[!!]',
        DiagnosticStatus.failed => '[XX]',
        DiagnosticStatus.skipped => '[--]',
        DiagnosticStatus.running => '[..]',
        DiagnosticStatus.pending => '[  ]',
      };
      buffer.writeln('$icon ${result.type.title}');
      if (result.message.isNotEmpty) {
        buffer.writeln('    ${result.message}');
      }
      if (result.suggestion != null) {
        buffer.writeln('    Fix: ${result.suggestion}');
      }
      if (result.duration != null) {
        buffer.writeln('    (${result.duration!.inMilliseconds}ms)');
      }
    }

    if (configSnapshot != null) {
      buffer.writeln();
      buffer.writeln('Configuration (redacted):');
      const encoder = JsonEncoder.withIndent('  ');
      buffer.writeln(encoder.convert(configSnapshot));
    }

    return buffer.toString();
  }

  /// Produces a JSON representation of the full report.
  Map<String, dynamic> toJson() => {
    'startedAt': startedAt.toIso8601String(),
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
    'connectionState': connectionState.name,
    'overallStatus': overallStatus.name,
    'results': results.map((r) => r.toJson()).toList(growable: false),
    if (configSnapshot != null) 'config': configSnapshot,
  };

  @override
  String toString() =>
      'DiagnosticReport(${overallStatus.displayLabel}, '
      '$passedCount/$activeCheckCount passed, '
      '$failedCount failed)';
}

/// Static helper methods for running config-level validation checks
/// without requiring network access.
///
/// These are used by [DiagnosticCheckType.configValidation] and can
/// also be called independently from the setup wizard for real-time
/// field validation.
class ConfigDiagnostics {
  ConfigDiagnostics._();

  /// Validates the broker configuration fields and returns a
  /// diagnostic result.
  ///
  /// This check does not make any network calls. It only validates
  /// that the config values are syntactically correct.
  static DiagnosticCheckResult validateConfig(GlobalLayerConfig config) {
    final stopwatch = Stopwatch()..start();
    final issues = <String>[];
    final fields = <String>[];

    // Host validation
    if (config.host.trim().isEmpty) {
      issues.add('Broker address is empty.');
      fields.add('host');
    } else if (config.host.contains(' ')) {
      issues.add('Broker address contains spaces.');
      fields.add('host');
    } else if (config.host.contains('://')) {
      issues.add(
        'Broker address should not include a protocol prefix '
        '(e.g. remove "mqtt://" or "mqtts://").',
      );
      fields.add('host');
    }

    // Port validation
    if (config.port <= 0 || config.port > 65535) {
      issues.add('Port must be between 1 and 65535.');
      fields.add('port');
    }

    // TLS + port sanity check
    if (config.useTls && config.port == 1883) {
      issues.add(
        'TLS is enabled but the port is 1883 (standard non-TLS port). '
        'Consider using port 8883 for TLS connections.',
      );
      // This is a warning, not a hard failure — some brokers do TLS on 1883
    }

    // Topic root validation
    if (config.topicRoot.trim().isEmpty) {
      issues.add('Topic root is empty.');
      fields.add('topicRoot');
    } else if (config.topicRoot.startsWith('/') ||
        config.topicRoot.endsWith('/')) {
      issues.add('Topic root should not start or end with a separator.');
      fields.add('topicRoot');
    } else if (config.topicRoot.contains('//')) {
      issues.add('Topic root contains consecutive separators.');
      fields.add('topicRoot');
    }

    // Client ID validation (optional but warn on suspicious values)
    if (config.clientId.isNotEmpty && config.clientId.length > 128) {
      issues.add(
        'Client ID is unusually long (${config.clientId.length} chars). '
        'Some brokers limit client IDs to 23-128 characters.',
      );
      fields.add('clientId');
    }

    stopwatch.stop();

    if (issues.isEmpty) {
      return DiagnosticCheckResult.passed(
        DiagnosticCheckType.configValidation,
        'All configuration fields are valid.',
        duration: stopwatch.elapsed,
      );
    }

    // Determine severity: if host or port is bad, it is a hard failure.
    // If only TLS/port mismatch or long client ID, it is a warning.
    final hasHardFailure =
        fields.contains('host') ||
        fields.contains('topicRoot') ||
        (fields.contains('port') && (config.port <= 0 || config.port > 65535));

    if (hasHardFailure) {
      return DiagnosticCheckResult.failed(
        DiagnosticCheckType.configValidation,
        message: issues.join(' '),
        suggestion: 'Correct the highlighted fields and try again.',
        relatedFields: fields,
        duration: stopwatch.elapsed,
      );
    }

    return DiagnosticCheckResult.warning(
      DiagnosticCheckType.configValidation,
      message: issues.join(' '),
      suggestion:
          'These issues may not prevent connection but could cause '
          'unexpected behavior.',
      relatedFields: fields,
      duration: stopwatch.elapsed,
    );
  }

  /// Checks whether the error history suggests a specific root cause.
  ///
  /// This is used by the guided fault tree to prioritize which
  /// diagnostic branch to explore first based on past failures.
  static DiagnosticCheckType? suggestCheckFromErrors(
    List<ConnectionErrorRecord> errors,
  ) {
    if (errors.isEmpty) return null;

    // Count error types and find the most frequent
    final counts = <ConnectionErrorType, int>{};
    for (final error in errors) {
      counts[error.type] = (counts[error.type] ?? 0) + 1;
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final mostFrequent = sorted.first.key;

    return switch (mostFrequent) {
      ConnectionErrorType.dnsFailure => DiagnosticCheckType.dnsResolution,
      ConnectionErrorType.tcpFailure => DiagnosticCheckType.tcpConnection,
      ConnectionErrorType.tlsFailure => DiagnosticCheckType.tlsHandshake,
      ConnectionErrorType.authFailure => DiagnosticCheckType.authentication,
      ConnectionErrorType.subscribeFailure => DiagnosticCheckType.subscribeTest,
      ConnectionErrorType.publishFailure => DiagnosticCheckType.publishTest,
      ConnectionErrorType.brokerDisconnect =>
        DiagnosticCheckType.authentication,
      ConnectionErrorType.networkLoss => DiagnosticCheckType.tcpConnection,
      ConnectionErrorType.timeout => DiagnosticCheckType.tcpConnection,
      ConnectionErrorType.pingTimeout => DiagnosticCheckType.tcpConnection,
      ConnectionErrorType.unknown => DiagnosticCheckType.configValidation,
    };
  }

  /// Generates a human-readable "plain English" diagnosis from a
  /// completed [DiagnosticReport].
  ///
  /// This is shown at the top of the diagnostics screen to give users
  /// an immediate, non-technical understanding of the problem.
  static String plainEnglishDiagnosis(DiagnosticReport report) {
    if (!report.isComplete) {
      return 'Diagnostics are still running\u2026';
    }

    if (report.overallStatus == DiagnosticStatus.passed) {
      return 'Everything looks good. Your Global Layer connection '
          'should work correctly.';
    }

    final failure = report.firstFailure;
    if (failure == null) {
      if (report.overallStatus == DiagnosticStatus.warning) {
        return 'The connection may work but there are potential issues '
            'to review.';
      }
      return 'Diagnostics completed with no clear issues found.';
    }

    return switch (failure.type) {
      DiagnosticCheckType.configValidation =>
        'There is a problem with your settings. Check the broker '
            'address and topic root for errors.',
      DiagnosticCheckType.dnsResolution =>
        'The broker hostname could not be found. This usually means '
            'the address is misspelled, or your device does not have '
            'internet access.',
      DiagnosticCheckType.tcpConnection =>
        'Could not connect to the broker. It may be offline, or '
            'the port number may be wrong. A firewall could also be '
            'blocking the connection.',
      DiagnosticCheckType.tlsHandshake =>
        'The secure connection failed. The broker may not support '
            'TLS on this port, or its security certificate may be '
            'invalid.',
      DiagnosticCheckType.authentication =>
        'The broker rejected your credentials. Double-check your '
            'username and password.',
      DiagnosticCheckType.subscribeTest =>
        'Connected to the broker, but it would not allow subscribing '
            'to topics. Your account may not have the right permissions.',
      DiagnosticCheckType.publishTest =>
        'Connected to the broker, but it would not allow publishing '
            'messages. Your account may not have write permissions.',
    };
  }
}
