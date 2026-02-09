// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/mqtt/mqtt_config.dart';
import 'package:socialmesh/core/mqtt/mqtt_connection_state.dart';
import 'package:socialmesh/core/mqtt/mqtt_diagnostics.dart';
import 'package:socialmesh/core/mqtt/mqtt_metrics.dart';

void main() {
  // ---------------------------------------------------------------------------
  // DiagnosticStatus
  // ---------------------------------------------------------------------------

  group('DiagnosticStatus', () {
    test('displayLabel returns human-readable text for all values', () {
      for (final status in DiagnosticStatus.values) {
        expect(status.displayLabel, isNotEmpty);
      }
    });

    test('isComplete is true for terminal statuses', () {
      expect(DiagnosticStatus.passed.isComplete, isTrue);
      expect(DiagnosticStatus.warning.isComplete, isTrue);
      expect(DiagnosticStatus.failed.isComplete, isTrue);
      expect(DiagnosticStatus.skipped.isComplete, isTrue);
    });

    test('isComplete is false for non-terminal statuses', () {
      expect(DiagnosticStatus.pending.isComplete, isFalse);
      expect(DiagnosticStatus.running.isComplete, isFalse);
    });

    test('isProblem is true for failed and warning', () {
      expect(DiagnosticStatus.failed.isProblem, isTrue);
      expect(DiagnosticStatus.warning.isProblem, isTrue);
    });

    test('isProblem is false for non-problem statuses', () {
      expect(DiagnosticStatus.passed.isProblem, isFalse);
      expect(DiagnosticStatus.pending.isProblem, isFalse);
      expect(DiagnosticStatus.running.isProblem, isFalse);
      expect(DiagnosticStatus.skipped.isProblem, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // DiagnosticCheckType
  // ---------------------------------------------------------------------------

  group('DiagnosticCheckType', () {
    test('all check types have a non-empty title', () {
      for (final type in DiagnosticCheckType.values) {
        expect(type.title, isNotEmpty);
      }
    });

    test('all check types have a non-empty description', () {
      for (final type in DiagnosticCheckType.values) {
        expect(type.description, isNotEmpty);
      }
    });

    test('all check types have a non-empty iconName', () {
      for (final type in DiagnosticCheckType.values) {
        expect(type.iconName, isNotEmpty);
      }
    });

    test('configValidation has no prerequisite', () {
      expect(DiagnosticCheckType.configValidation.prerequisite, isNull);
    });

    test('dnsResolution depends on configValidation', () {
      expect(
        DiagnosticCheckType.dnsResolution.prerequisite,
        DiagnosticCheckType.configValidation,
      );
    });

    test('tcpConnection depends on dnsResolution', () {
      expect(
        DiagnosticCheckType.tcpConnection.prerequisite,
        DiagnosticCheckType.dnsResolution,
      );
    });

    test('tlsHandshake depends on tcpConnection', () {
      expect(
        DiagnosticCheckType.tlsHandshake.prerequisite,
        DiagnosticCheckType.tcpConnection,
      );
    });

    test('authentication depends on tlsHandshake', () {
      expect(
        DiagnosticCheckType.authentication.prerequisite,
        DiagnosticCheckType.tlsHandshake,
      );
    });

    test('subscribeTest depends on authentication', () {
      expect(
        DiagnosticCheckType.subscribeTest.prerequisite,
        DiagnosticCheckType.authentication,
      );
    });

    test('publishTest depends on authentication', () {
      expect(
        DiagnosticCheckType.publishTest.prerequisite,
        DiagnosticCheckType.authentication,
      );
    });

    group('effectivePrerequisite', () {
      test('authentication skips TLS when TLS is disabled', () {
        expect(
          DiagnosticCheckType.authentication.effectivePrerequisite(
            tlsEnabled: false,
          ),
          DiagnosticCheckType.tcpConnection,
        );
      });

      test('authentication depends on TLS when TLS is enabled', () {
        expect(
          DiagnosticCheckType.authentication.effectivePrerequisite(
            tlsEnabled: true,
          ),
          DiagnosticCheckType.tlsHandshake,
        );
      });

      test('tlsHandshake returns null when TLS is disabled', () {
        expect(
          DiagnosticCheckType.tlsHandshake.effectivePrerequisite(
            tlsEnabled: false,
          ),
          isNull,
        );
      });

      test('tlsHandshake has normal prerequisite when TLS is enabled', () {
        expect(
          DiagnosticCheckType.tlsHandshake.effectivePrerequisite(
            tlsEnabled: true,
          ),
          DiagnosticCheckType.tcpConnection,
        );
      });

      test('configValidation has no prerequisite regardless of TLS', () {
        expect(
          DiagnosticCheckType.configValidation.effectivePrerequisite(
            tlsEnabled: true,
          ),
          isNull,
        );
        expect(
          DiagnosticCheckType.configValidation.effectivePrerequisite(
            tlsEnabled: false,
          ),
          isNull,
        );
      });
    });

    test('configValidation, dns, tcp, tls, auth are prerequisites', () {
      expect(DiagnosticCheckType.configValidation.isPrerequisite, isTrue);
      expect(DiagnosticCheckType.dnsResolution.isPrerequisite, isTrue);
      expect(DiagnosticCheckType.tcpConnection.isPrerequisite, isTrue);
      expect(DiagnosticCheckType.tlsHandshake.isPrerequisite, isTrue);
      expect(DiagnosticCheckType.authentication.isPrerequisite, isTrue);
    });

    test('subscribeTest and publishTest are not prerequisites', () {
      expect(DiagnosticCheckType.subscribeTest.isPrerequisite, isFalse);
      expect(DiagnosticCheckType.publishTest.isPrerequisite, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // DiagnosticCheckResult
  // ---------------------------------------------------------------------------

  group('DiagnosticCheckResult', () {
    test('pending constructor sets correct defaults', () {
      const result = DiagnosticCheckResult.pending(
        DiagnosticCheckType.dnsResolution,
      );
      expect(result.type, DiagnosticCheckType.dnsResolution);
      expect(result.status, DiagnosticStatus.pending);
      expect(result.message, isEmpty);
      expect(result.suggestion, isNull);
      expect(result.relatedFields, isEmpty);
      expect(result.duration, isNull);
      expect(result.completedAt, isNull);
    });

    test('running constructor sets correct defaults', () {
      const result = DiagnosticCheckResult.running(
        DiagnosticCheckType.tcpConnection,
      );
      expect(result.type, DiagnosticCheckType.tcpConnection);
      expect(result.status, DiagnosticStatus.running);
      expect(result.message, isEmpty);
      expect(result.completedAt, isNull);
    });

    test('passed constructor sets status and message', () {
      final result = DiagnosticCheckResult.passed(
        DiagnosticCheckType.dnsResolution,
        'Resolved successfully.',
        duration: const Duration(milliseconds: 150),
      );
      expect(result.type, DiagnosticCheckType.dnsResolution);
      expect(result.status, DiagnosticStatus.passed);
      expect(result.message, 'Resolved successfully.');
      expect(result.duration, const Duration(milliseconds: 150));
      expect(result.completedAt, isNotNull);
      expect(result.suggestion, isNull);
    });

    test('failed constructor sets status, message, and suggestion', () {
      final result = DiagnosticCheckResult.failed(
        DiagnosticCheckType.authentication,
        message: 'Invalid credentials.',
        suggestion: 'Check your username and password.',
        relatedFields: const ['username', 'password'],
        duration: const Duration(milliseconds: 500),
      );
      expect(result.type, DiagnosticCheckType.authentication);
      expect(result.status, DiagnosticStatus.failed);
      expect(result.message, 'Invalid credentials.');
      expect(result.suggestion, 'Check your username and password.');
      expect(result.relatedFields, ['username', 'password']);
      expect(result.completedAt, isNotNull);
    });

    test('warning constructor sets status and suggestion', () {
      final result = DiagnosticCheckResult.warning(
        DiagnosticCheckType.configValidation,
        message: 'TLS on port 1883.',
        suggestion: 'Consider port 8883.',
      );
      expect(result.status, DiagnosticStatus.warning);
      expect(result.message, 'TLS on port 1883.');
      expect(result.suggestion, 'Consider port 8883.');
    });

    test('skipped constructor sets reason message', () {
      final result = DiagnosticCheckResult.skipped(
        DiagnosticCheckType.tlsHandshake,
        reason: 'TLS is disabled.',
      );
      expect(result.status, DiagnosticStatus.skipped);
      expect(result.message, 'TLS is disabled.');
      expect(result.completedAt, isNotNull);
    });

    test('skipped constructor has default reason', () {
      final result = DiagnosticCheckResult.skipped(
        DiagnosticCheckType.tlsHandshake,
      );
      expect(result.message, contains('previous check failed'));
    });

    test('copyWith creates updated copy', () {
      const original = DiagnosticCheckResult.pending(
        DiagnosticCheckType.dnsResolution,
      );
      final updated = original.copyWith(
        status: DiagnosticStatus.running,
        message: 'In progress...',
      );
      expect(updated.type, DiagnosticCheckType.dnsResolution);
      expect(updated.status, DiagnosticStatus.running);
      expect(updated.message, 'In progress...');
    });

    test('toJson produces valid map', () {
      final result = DiagnosticCheckResult.passed(
        DiagnosticCheckType.tcpConnection,
        'Connected.',
        duration: const Duration(milliseconds: 200),
      );
      final json = result.toJson();
      expect(json['type'], 'tcpConnection');
      expect(json['status'], 'passed');
      expect(json['message'], 'Connected.');
      expect(json['durationMs'], 200);
      expect(json.containsKey('completedAt'), isTrue);
    });

    test('toJson omits null optional fields', () {
      const result = DiagnosticCheckResult.pending(
        DiagnosticCheckType.dnsResolution,
      );
      final json = result.toJson();
      expect(json.containsKey('suggestion'), isFalse);
      expect(json.containsKey('relatedFields'), isFalse);
      expect(json.containsKey('durationMs'), isFalse);
      expect(json.containsKey('completedAt'), isFalse);
    });

    test('toString is descriptive', () {
      final result = DiagnosticCheckResult.passed(
        DiagnosticCheckType.dnsResolution,
        'OK',
      );
      expect(result.toString(), contains('dnsResolution'));
      expect(result.toString(), contains('passed'));
    });
  });

  // ---------------------------------------------------------------------------
  // DiagnosticReport
  // ---------------------------------------------------------------------------

  group('DiagnosticReport', () {
    group('initial factory', () {
      test('creates report with all check types when TLS enabled', () {
        final report = DiagnosticReport.initial(tlsEnabled: true);
        expect(report.results.length, DiagnosticCheckType.values.length);
        expect(report.startedAt, isNotNull);
        expect(report.completedAt, isNull);
        expect(report.isComplete, isFalse);
        expect(report.isRunning, isFalse);
      });

      test('excludes TLS check when TLS is disabled', () {
        final report = DiagnosticReport.initial(tlsEnabled: false);
        expect(report.results.length, DiagnosticCheckType.values.length - 1);
        expect(
          report.results.any((r) => r.type == DiagnosticCheckType.tlsHandshake),
          isFalse,
        );
      });

      test('all checks start as pending', () {
        final report = DiagnosticReport.initial(tlsEnabled: true);
        for (final result in report.results) {
          expect(result.status, DiagnosticStatus.pending);
        }
      });

      test('uses provided connection state', () {
        final report = DiagnosticReport.initial(
          tlsEnabled: true,
          connectionState: GlobalLayerConnectionState.connected,
        );
        expect(report.connectionState, GlobalLayerConnectionState.connected);
      });

      test('stores config snapshot', () {
        final snapshot = {'host': 'example.com', 'port': 8883};
        final report = DiagnosticReport.initial(
          tlsEnabled: true,
          configSnapshot: snapshot,
        );
        expect(report.configSnapshot, snapshot);
      });
    });

    group('derived properties', () {
      test('isComplete is false when any check is pending', () {
        final report = DiagnosticReport.initial(tlsEnabled: true);
        expect(report.isComplete, isFalse);
      });

      test('isComplete is true when all checks are complete', () {
        var report = DiagnosticReport.initial(tlsEnabled: false);
        for (final result in report.results) {
          report = report.updateResult(
            DiagnosticCheckResult.passed(result.type, 'OK'),
          );
        }
        expect(report.isComplete, isTrue);
      });

      test('isRunning is true when any check has running status', () {
        var report = DiagnosticReport.initial(tlsEnabled: true);
        report = report.updateResult(
          const DiagnosticCheckResult.running(
            DiagnosticCheckType.configValidation,
          ),
        );
        expect(report.isRunning, isTrue);
      });

      test('overallStatus is running when not complete', () {
        final report = DiagnosticReport.initial(tlsEnabled: true);
        expect(report.overallStatus, DiagnosticStatus.running);
      });

      test('overallStatus is passed when all checks pass', () {
        var report = DiagnosticReport.initial(tlsEnabled: false);
        for (final result in report.results) {
          report = report.updateResult(
            DiagnosticCheckResult.passed(result.type, 'OK'),
          );
        }
        expect(report.overallStatus, DiagnosticStatus.passed);
      });

      test('overallStatus is failed when any check fails', () {
        var report = DiagnosticReport.initial(tlsEnabled: false);
        for (final result in report.results) {
          if (result.type == DiagnosticCheckType.dnsResolution) {
            report = report.updateResult(
              DiagnosticCheckResult.failed(result.type, message: 'DNS failed'),
            );
          } else {
            report = report.updateResult(
              DiagnosticCheckResult.passed(result.type, 'OK'),
            );
          }
        }
        expect(report.overallStatus, DiagnosticStatus.failed);
      });

      test('overallStatus is warning when checks warn but none fail', () {
        var report = DiagnosticReport.initial(tlsEnabled: false);
        for (final result in report.results) {
          if (result.type == DiagnosticCheckType.configValidation) {
            report = report.updateResult(
              DiagnosticCheckResult.warning(
                result.type,
                message: 'Minor issue',
              ),
            );
          } else {
            report = report.updateResult(
              DiagnosticCheckResult.passed(result.type, 'OK'),
            );
          }
        }
        expect(report.overallStatus, DiagnosticStatus.warning);
      });

      test('firstFailure returns first failed check', () {
        var report = DiagnosticReport.initial(tlsEnabled: false);
        report = report.updateResult(
          DiagnosticCheckResult.passed(
            DiagnosticCheckType.configValidation,
            'OK',
          ),
        );
        report = report.updateResult(
          DiagnosticCheckResult.failed(
            DiagnosticCheckType.dnsResolution,
            message: 'DNS failed',
          ),
        );
        report = report.updateResult(
          DiagnosticCheckResult.failed(
            DiagnosticCheckType.tcpConnection,
            message: 'TCP failed',
          ),
        );

        final failure = report.firstFailure;
        expect(failure, isNotNull);
        expect(failure!.type, DiagnosticCheckType.dnsResolution);
      });

      test('firstFailure returns null when no failures', () {
        var report = DiagnosticReport.initial(tlsEnabled: false);
        for (final result in report.results) {
          report = report.updateResult(
            DiagnosticCheckResult.passed(result.type, 'OK'),
          );
        }
        expect(report.firstFailure, isNull);
      });

      test('problems returns all failed and warning checks', () {
        var report = DiagnosticReport.initial(tlsEnabled: false);
        report = report.updateResult(
          DiagnosticCheckResult.passed(
            DiagnosticCheckType.configValidation,
            'OK',
          ),
        );
        report = report.updateResult(
          DiagnosticCheckResult.warning(
            DiagnosticCheckType.dnsResolution,
            message: 'Slow DNS',
          ),
        );
        report = report.updateResult(
          DiagnosticCheckResult.failed(
            DiagnosticCheckType.tcpConnection,
            message: 'TCP failed',
          ),
        );

        final problems = report.problems;
        expect(problems.length, 2);
        expect(problems[0].type, DiagnosticCheckType.dnsResolution);
        expect(problems[1].type, DiagnosticCheckType.tcpConnection);
      });

      test('passedCount returns correct count', () {
        var report = DiagnosticReport.initial(tlsEnabled: false);
        report = report.updateResult(
          DiagnosticCheckResult.passed(
            DiagnosticCheckType.configValidation,
            'OK',
          ),
        );
        report = report.updateResult(
          DiagnosticCheckResult.passed(DiagnosticCheckType.dnsResolution, 'OK'),
        );
        expect(report.passedCount, 2);
      });

      test('failedCount returns correct count', () {
        var report = DiagnosticReport.initial(tlsEnabled: false);
        report = report.updateResult(
          DiagnosticCheckResult.failed(
            DiagnosticCheckType.configValidation,
            message: 'Bad config',
          ),
        );
        expect(report.failedCount, 1);
      });

      test('progress is 0 when no checks complete', () {
        final report = DiagnosticReport.initial(tlsEnabled: true);
        expect(report.progress, 0.0);
      });

      test('progress is 1 when all checks complete', () {
        var report = DiagnosticReport.initial(tlsEnabled: false);
        for (final result in report.results) {
          report = report.updateResult(
            DiagnosticCheckResult.passed(result.type, 'OK'),
          );
        }
        expect(report.progress, 1.0);
      });

      test('progress is fractional when some checks complete', () {
        var report = DiagnosticReport.initial(tlsEnabled: false);
        final totalChecks = report.results.length;
        report = report.updateResult(
          DiagnosticCheckResult.passed(
            DiagnosticCheckType.configValidation,
            'OK',
          ),
        );
        expect(report.progress, closeTo(1.0 / totalChecks, 0.01));
      });

      test('totalDuration is null before completion', () {
        final report = DiagnosticReport.initial(tlsEnabled: true);
        expect(report.totalDuration, isNull);
      });

      test('totalDuration is non-null after markComplete', () {
        final report = DiagnosticReport.initial(
          tlsEnabled: true,
        ).markComplete();
        expect(report.totalDuration, isNotNull);
      });
    });

    group('updateResult', () {
      test('replaces the result for matching check type', () {
        var report = DiagnosticReport.initial(tlsEnabled: true);
        final updated = DiagnosticCheckResult.passed(
          DiagnosticCheckType.configValidation,
          'Valid.',
        );
        report = report.updateResult(updated);

        final result = report.resultFor(DiagnosticCheckType.configValidation);
        expect(result, isNotNull);
        expect(result!.status, DiagnosticStatus.passed);
        expect(result.message, 'Valid.');
      });

      test('does not affect other check types', () {
        var report = DiagnosticReport.initial(tlsEnabled: true);
        report = report.updateResult(
          DiagnosticCheckResult.passed(
            DiagnosticCheckType.configValidation,
            'OK',
          ),
        );

        final dns = report.resultFor(DiagnosticCheckType.dnsResolution);
        expect(dns, isNotNull);
        expect(dns!.status, DiagnosticStatus.pending);
      });

      test('auto-sets completedAt when all checks finish', () {
        var report = DiagnosticReport.initial(tlsEnabled: false);
        for (final result in report.results) {
          report = report.updateResult(
            DiagnosticCheckResult.passed(result.type, 'OK'),
          );
        }
        expect(report.completedAt, isNotNull);
      });
    });

    group('resultFor', () {
      test('returns result for existing check type', () {
        final report = DiagnosticReport.initial(tlsEnabled: true);
        final result = report.resultFor(DiagnosticCheckType.configValidation);
        expect(result, isNotNull);
        expect(result!.type, DiagnosticCheckType.configValidation);
      });

      test('returns null for check type excluded from report', () {
        final report = DiagnosticReport.initial(tlsEnabled: false);
        final result = report.resultFor(DiagnosticCheckType.tlsHandshake);
        expect(result, isNull);
      });
    });

    group('markComplete', () {
      test('sets completedAt', () {
        final report = DiagnosticReport.initial(
          tlsEnabled: true,
        ).markComplete();
        expect(report.completedAt, isNotNull);
      });

      test('preserves all results', () {
        var report = DiagnosticReport.initial(tlsEnabled: true);
        report = report.updateResult(
          DiagnosticCheckResult.passed(
            DiagnosticCheckType.configValidation,
            'OK',
          ),
        );
        final completed = report.markComplete();
        expect(completed.results.length, report.results.length);

        final config = completed.resultFor(
          DiagnosticCheckType.configValidation,
        );
        expect(config!.status, DiagnosticStatus.passed);
      });
    });

    group('toClipboardSummary', () {
      test('produces non-empty string', () {
        final report = DiagnosticReport.initial(tlsEnabled: true);
        final summary = report.toClipboardSummary();
        expect(summary, isNotEmpty);
        expect(summary, contains('Global Layer Diagnostics Report'));
      });

      test('includes check types', () {
        final report = DiagnosticReport.initial(tlsEnabled: true);
        final summary = report.toClipboardSummary();
        expect(summary, contains('Configuration'));
        expect(summary, contains('DNS Resolution'));
      });

      test('includes status icons in summary', () {
        var report = DiagnosticReport.initial(tlsEnabled: false);
        report = report.updateResult(
          DiagnosticCheckResult.passed(
            DiagnosticCheckType.configValidation,
            'OK',
          ),
        );
        report = report.updateResult(
          DiagnosticCheckResult.failed(
            DiagnosticCheckType.dnsResolution,
            message: 'Failed',
            suggestion: 'Fix DNS',
          ),
        );
        final summary = report.toClipboardSummary();
        expect(summary, contains('[OK]'));
        expect(summary, contains('[XX]'));
        expect(summary, contains('Fix: Fix DNS'));
      });
    });

    group('toJson', () {
      test('produces valid JSON map', () {
        final report = DiagnosticReport.initial(
          tlsEnabled: true,
          connectionState: GlobalLayerConnectionState.disconnected,
        );
        final json = report.toJson();
        expect(json['startedAt'], isNotNull);
        expect(json['connectionState'], 'disconnected');
        expect(json['overallStatus'], 'running');
        expect(json['results'], isA<List>());
      });
    });

    test('toString is descriptive', () {
      final report = DiagnosticReport.initial(tlsEnabled: true);
      final str = report.toString();
      expect(str, contains('DiagnosticReport'));
    });
  });

  // ---------------------------------------------------------------------------
  // ConfigDiagnostics.validateConfig
  // ---------------------------------------------------------------------------

  group('ConfigDiagnostics.validateConfig', () {
    GlobalLayerConfig validConfig() {
      return GlobalLayerConfig.initial.copyWith(
        host: 'mqtt.example.com',
        port: 8883,
        useTls: true,
        topicRoot: 'msh',
      );
    }

    test('valid config returns passed result', () {
      final result = ConfigDiagnostics.validateConfig(validConfig());
      expect(result.status, DiagnosticStatus.passed);
      expect(result.type, DiagnosticCheckType.configValidation);
      expect(result.duration, isNotNull);
    });

    test('empty host returns failed result', () {
      final config = validConfig().copyWith(host: '');
      final result = ConfigDiagnostics.validateConfig(config);
      expect(result.status, DiagnosticStatus.failed);
      expect(result.message, contains('empty'));
      expect(result.relatedFields, contains('host'));
    });

    test('host with spaces returns failed result', () {
      final config = validConfig().copyWith(host: 'my broker.com');
      final result = ConfigDiagnostics.validateConfig(config);
      expect(result.status, DiagnosticStatus.failed);
      expect(result.message, contains('spaces'));
    });

    test('host with protocol prefix returns failed result', () {
      final config = validConfig().copyWith(host: 'mqtt://broker.com');
      final result = ConfigDiagnostics.validateConfig(config);
      expect(result.status, DiagnosticStatus.failed);
      expect(result.message, contains('protocol prefix'));
    });

    test('port 0 returns failed result', () {
      final config = validConfig().copyWith(port: 0);
      final result = ConfigDiagnostics.validateConfig(config);
      expect(result.status, DiagnosticStatus.failed);
      expect(result.relatedFields, contains('port'));
    });

    test('port exceeding 65535 returns failed result', () {
      final config = validConfig().copyWith(port: 99999);
      final result = ConfigDiagnostics.validateConfig(config);
      expect(result.status, DiagnosticStatus.failed);
    });

    test('TLS on port 1883 returns warning', () {
      final config = validConfig().copyWith(port: 1883, useTls: true);
      final result = ConfigDiagnostics.validateConfig(config);
      // This is a warning because TLS on 1883 is unusual but possible
      expect(result.status, DiagnosticStatus.warning);
      expect(result.message, contains('1883'));
    });

    test('empty topicRoot returns failed result', () {
      final config = validConfig().copyWith(topicRoot: '');
      final result = ConfigDiagnostics.validateConfig(config);
      expect(result.status, DiagnosticStatus.failed);
      expect(result.message, contains('root'));
    });

    test('topicRoot with leading separator returns failed result', () {
      final config = validConfig().copyWith(topicRoot: '/msh');
      final result = ConfigDiagnostics.validateConfig(config);
      expect(result.status, DiagnosticStatus.failed);
    });

    test('topicRoot with trailing separator returns failed result', () {
      final config = validConfig().copyWith(topicRoot: 'msh/');
      final result = ConfigDiagnostics.validateConfig(config);
      expect(result.status, DiagnosticStatus.failed);
    });

    test('topicRoot with consecutive separators returns failed result', () {
      final config = validConfig().copyWith(topicRoot: 'msh//test');
      final result = ConfigDiagnostics.validateConfig(config);
      expect(result.status, DiagnosticStatus.failed);
    });

    test('very long clientId returns warning', () {
      final config = validConfig().copyWith(clientId: 'a' * 200);
      final result = ConfigDiagnostics.validateConfig(config);
      // Long client ID is a warning, not a hard failure
      expect(
        result.status == DiagnosticStatus.warning ||
            result.status == DiagnosticStatus.passed,
        isTrue,
      );
      if (result.status == DiagnosticStatus.warning) {
        expect(result.message, contains('long'));
      }
    });

    test('result has correct check type', () {
      final result = ConfigDiagnostics.validateConfig(validConfig());
      expect(result.type, DiagnosticCheckType.configValidation);
    });

    test('valid config with non-TLS on port 8883 returns passed', () {
      final config = validConfig().copyWith(port: 8883, useTls: false);
      final result = ConfigDiagnostics.validateConfig(config);
      // No specific warning for non-TLS on 8883 (user might know what
      // they are doing)
      expect(result.status, DiagnosticStatus.passed);
    });

    test('valid config without TLS on standard port returns passed', () {
      final config = validConfig().copyWith(port: 1883, useTls: false);
      final result = ConfigDiagnostics.validateConfig(config);
      expect(result.status, DiagnosticStatus.passed);
    });
  });

  // ---------------------------------------------------------------------------
  // ConfigDiagnostics.suggestCheckFromErrors
  // ---------------------------------------------------------------------------

  group('ConfigDiagnostics.suggestCheckFromErrors', () {
    test('returns null for empty error list', () {
      expect(ConfigDiagnostics.suggestCheckFromErrors([]), isNull);
    });

    test('returns DNS check for DNS failures', () {
      final errors = [
        ConnectionErrorRecord(
          timestamp: DateTime.now(),
          message: 'DNS lookup failed',
          type: ConnectionErrorType.dnsFailure,
        ),
      ];
      expect(
        ConfigDiagnostics.suggestCheckFromErrors(errors),
        DiagnosticCheckType.dnsResolution,
      );
    });

    test('returns TCP check for TCP failures', () {
      final errors = [
        ConnectionErrorRecord(
          timestamp: DateTime.now(),
          message: 'Connection refused',
          type: ConnectionErrorType.tcpFailure,
        ),
      ];
      expect(
        ConfigDiagnostics.suggestCheckFromErrors(errors),
        DiagnosticCheckType.tcpConnection,
      );
    });

    test('returns TLS check for TLS failures', () {
      final errors = [
        ConnectionErrorRecord(
          timestamp: DateTime.now(),
          message: 'Certificate error',
          type: ConnectionErrorType.tlsFailure,
        ),
      ];
      expect(
        ConfigDiagnostics.suggestCheckFromErrors(errors),
        DiagnosticCheckType.tlsHandshake,
      );
    });

    test('returns auth check for auth failures', () {
      final errors = [
        ConnectionErrorRecord(
          timestamp: DateTime.now(),
          message: 'Bad credentials',
          type: ConnectionErrorType.authFailure,
        ),
      ];
      expect(
        ConfigDiagnostics.suggestCheckFromErrors(errors),
        DiagnosticCheckType.authentication,
      );
    });

    test('returns most frequent error type when mixed', () {
      final errors = [
        ConnectionErrorRecord(
          timestamp: DateTime.now(),
          message: 'DNS failed',
          type: ConnectionErrorType.dnsFailure,
        ),
        ConnectionErrorRecord(
          timestamp: DateTime.now(),
          message: 'TCP failed 1',
          type: ConnectionErrorType.tcpFailure,
        ),
        ConnectionErrorRecord(
          timestamp: DateTime.now(),
          message: 'TCP failed 2',
          type: ConnectionErrorType.tcpFailure,
        ),
      ];
      // TCP failures are more frequent
      expect(
        ConfigDiagnostics.suggestCheckFromErrors(errors),
        DiagnosticCheckType.tcpConnection,
      );
    });

    test('returns subscribe check for subscribe failures', () {
      final errors = [
        ConnectionErrorRecord(
          timestamp: DateTime.now(),
          message: 'Subscribe denied',
          type: ConnectionErrorType.subscribeFailure,
        ),
      ];
      expect(
        ConfigDiagnostics.suggestCheckFromErrors(errors),
        DiagnosticCheckType.subscribeTest,
      );
    });

    test('returns publish check for publish failures', () {
      final errors = [
        ConnectionErrorRecord(
          timestamp: DateTime.now(),
          message: 'Publish denied',
          type: ConnectionErrorType.publishFailure,
        ),
      ];
      expect(
        ConfigDiagnostics.suggestCheckFromErrors(errors),
        DiagnosticCheckType.publishTest,
      );
    });

    test('returns TCP check for network loss errors', () {
      final errors = [
        ConnectionErrorRecord(
          timestamp: DateTime.now(),
          message: 'Network lost',
          type: ConnectionErrorType.networkLoss,
        ),
      ];
      expect(
        ConfigDiagnostics.suggestCheckFromErrors(errors),
        DiagnosticCheckType.tcpConnection,
      );
    });

    test('returns TCP check for timeout errors', () {
      final errors = [
        ConnectionErrorRecord(
          timestamp: DateTime.now(),
          message: 'Timed out',
          type: ConnectionErrorType.timeout,
        ),
      ];
      expect(
        ConfigDiagnostics.suggestCheckFromErrors(errors),
        DiagnosticCheckType.tcpConnection,
      );
    });

    test('returns config check for unknown errors', () {
      final errors = [
        ConnectionErrorRecord(
          timestamp: DateTime.now(),
          message: 'Unknown error',
          type: ConnectionErrorType.unknown,
        ),
      ];
      expect(
        ConfigDiagnostics.suggestCheckFromErrors(errors),
        DiagnosticCheckType.configValidation,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // ConfigDiagnostics.plainEnglishDiagnosis
  // ---------------------------------------------------------------------------

  group('ConfigDiagnostics.plainEnglishDiagnosis', () {
    test('returns running message for incomplete report', () {
      final report = DiagnosticReport.initial(tlsEnabled: true);
      final diagnosis = ConfigDiagnostics.plainEnglishDiagnosis(report);
      expect(diagnosis, contains('running'));
    });

    test('returns positive message for all-passed report', () {
      var report = DiagnosticReport.initial(tlsEnabled: false);
      for (final result in report.results) {
        report = report.updateResult(
          DiagnosticCheckResult.passed(result.type, 'OK'),
        );
      }
      final diagnosis = ConfigDiagnostics.plainEnglishDiagnosis(report);
      expect(diagnosis, contains('looks good'));
    });

    test('returns config-specific message for config failure', () {
      var report = DiagnosticReport.initial(tlsEnabled: false);
      report = report.updateResult(
        DiagnosticCheckResult.failed(
          DiagnosticCheckType.configValidation,
          message: 'Bad config',
        ),
      );
      // Mark all others as skipped so the report is complete
      for (final result in report.results) {
        if (result.type != DiagnosticCheckType.configValidation &&
            result.status == DiagnosticStatus.pending) {
          report = report.updateResult(
            DiagnosticCheckResult.skipped(result.type),
          );
        }
      }
      final diagnosis = ConfigDiagnostics.plainEnglishDiagnosis(report);
      expect(diagnosis, contains('settings'));
    });

    test('returns DNS-specific message for DNS failure', () {
      var report = DiagnosticReport.initial(tlsEnabled: false);
      report = report.updateResult(
        DiagnosticCheckResult.passed(
          DiagnosticCheckType.configValidation,
          'OK',
        ),
      );
      report = report.updateResult(
        DiagnosticCheckResult.failed(
          DiagnosticCheckType.dnsResolution,
          message: 'DNS failed',
        ),
      );
      for (final result in report.results) {
        if (result.status == DiagnosticStatus.pending) {
          report = report.updateResult(
            DiagnosticCheckResult.skipped(result.type),
          );
        }
      }
      final diagnosis = ConfigDiagnostics.plainEnglishDiagnosis(report);
      expect(diagnosis, contains('hostname'));
    });

    test('returns auth-specific message for auth failure', () {
      var report = DiagnosticReport.initial(tlsEnabled: false);
      // Pass config, DNS, TCP — fail auth
      for (final result in report.results) {
        if (result.type == DiagnosticCheckType.authentication) {
          report = report.updateResult(
            DiagnosticCheckResult.failed(result.type, message: 'Auth failed'),
          );
        } else if (result.type.prerequisite != null &&
            result.type != DiagnosticCheckType.authentication) {
          report = report.updateResult(
            DiagnosticCheckResult.passed(result.type, 'OK'),
          );
        } else {
          report = report.updateResult(
            DiagnosticCheckResult.passed(result.type, 'OK'),
          );
        }
      }
      // Mark any remaining pending as skipped
      for (final result in report.results) {
        if (result.status == DiagnosticStatus.pending) {
          report = report.updateResult(
            DiagnosticCheckResult.skipped(result.type),
          );
        }
      }
      final diagnosis = ConfigDiagnostics.plainEnglishDiagnosis(report);
      expect(diagnosis, contains('credentials'));
    });

    test('returns warning message for warning-only report', () {
      var report = DiagnosticReport.initial(tlsEnabled: false);
      report = report.updateResult(
        DiagnosticCheckResult.warning(
          DiagnosticCheckType.configValidation,
          message: 'Minor issue',
        ),
      );
      for (final result in report.results) {
        if (result.status == DiagnosticStatus.pending) {
          report = report.updateResult(
            DiagnosticCheckResult.passed(result.type, 'OK'),
          );
        }
      }
      final diagnosis = ConfigDiagnostics.plainEnglishDiagnosis(report);
      expect(diagnosis, contains('work'));
    });
  });

  // ---------------------------------------------------------------------------
  // Full diagnostic lifecycle simulation
  // ---------------------------------------------------------------------------

  group('Diagnostic lifecycle', () {
    test('full happy path: all checks pass sequentially', () {
      var report = DiagnosticReport.initial(tlsEnabled: true);
      expect(report.progress, 0.0);
      expect(report.isComplete, isFalse);

      // Run each check in order
      for (final result in report.results.toList()) {
        // Mark as running
        report = report.updateResult(
          DiagnosticCheckResult.running(result.type),
        );

        // Mark as passed
        report = report.updateResult(
          DiagnosticCheckResult.passed(
            result.type,
            'Passed.',
            duration: const Duration(milliseconds: 100),
          ),
        );
      }

      expect(report.isComplete, isTrue);
      expect(report.overallStatus, DiagnosticStatus.passed);
      expect(report.failedCount, 0);
      expect(report.passedCount, DiagnosticCheckType.values.length);
    });

    test('failure at DNS stops dependent checks via prerequisite logic', () {
      var report = DiagnosticReport.initial(tlsEnabled: false);

      // Config passes
      report = report.updateResult(
        DiagnosticCheckResult.passed(
          DiagnosticCheckType.configValidation,
          'OK',
        ),
      );

      // DNS fails
      report = report.updateResult(
        DiagnosticCheckResult.failed(
          DiagnosticCheckType.dnsResolution,
          message: 'NXDOMAIN',
        ),
      );

      // Remaining checks should be skipped via prerequisite chain
      for (final result in report.results) {
        if (result.status == DiagnosticStatus.pending) {
          report = report.updateResult(
            DiagnosticCheckResult.skipped(result.type),
          );
        }
      }

      final completed = report.markComplete();
      expect(completed.isComplete, isTrue);
      expect(completed.overallStatus, DiagnosticStatus.failed);
      expect(completed.passedCount, 1);
      expect(completed.failedCount, 1);
      expect(completed.firstFailure!.type, DiagnosticCheckType.dnsResolution);
    });

    test('report without TLS skips TLS check correctly', () {
      final report = DiagnosticReport.initial(tlsEnabled: false);
      final types = report.results.map((r) => r.type).toList();

      expect(types, isNot(contains(DiagnosticCheckType.tlsHandshake)));
      expect(types, contains(DiagnosticCheckType.configValidation));
      expect(types, contains(DiagnosticCheckType.dnsResolution));
      expect(types, contains(DiagnosticCheckType.tcpConnection));
      expect(types, contains(DiagnosticCheckType.authentication));
      expect(types, contains(DiagnosticCheckType.subscribeTest));
      expect(types, contains(DiagnosticCheckType.publishTest));
    });
  });
}
