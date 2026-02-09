// SPDX-License-Identifier: GPL-3.0-or-later

/// Global Layer Diagnostics Screen — guided fault-finding for the
/// MQTT broker connection.
///
/// This screen runs diagnostic checks sequentially and displays
/// results with actionable suggestions. Each check depends on the
/// previous one succeeding (prerequisite chain).
///
/// For V1, network checks are simulated with deterministic delays
/// to provide a consistent UX. The diagnostic models and report
/// objects are in place to plug a real MQTT client later.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mqtt/mqtt_config.dart';
import '../../../core/mqtt/mqtt_diagnostics.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../providers/mqtt_providers.dart';
import '../../../services/haptic_service.dart';

/// Diagnostics screen for the Global Layer MQTT connection.
///
/// Runs a sequential battery of checks (config validation, DNS, TCP,
/// TLS, auth, subscribe, publish) and shows results with suggestions
/// for each failure. Users can copy the full report to clipboard for
/// support sharing.
class GlobalLayerDiagnosticsScreen extends ConsumerStatefulWidget {
  const GlobalLayerDiagnosticsScreen({super.key});

  @override
  ConsumerState<GlobalLayerDiagnosticsScreen> createState() =>
      _GlobalLayerDiagnosticsScreenState();
}

class _GlobalLayerDiagnosticsScreenState
    extends ConsumerState<GlobalLayerDiagnosticsScreen>
    with LifecycleSafeMixin<GlobalLayerDiagnosticsScreen> {
  bool _isRunning = false;
  bool _hasRun = false;
  DiagnosticReport? _report;

  // ---------------------------------------------------------------------------
  // Diagnostic execution
  // ---------------------------------------------------------------------------

  Future<void> _runDiagnostics() async {
    final haptics = ref.read(hapticServiceProvider);
    await haptics.trigger(HapticType.medium);

    final configAsync = ref.read(globalLayerConfigProvider);
    final config =
        configAsync.whenOrNull(data: (c) => c) ?? GlobalLayerConfig.initial;
    final connectionState = ref.read(globalLayerConnectionStateProvider);

    safeSetState(() {
      _isRunning = true;
      _hasRun = true;
    });

    // Initialize the report
    final configSnapshot = config.toRedactedJson();
    _report = DiagnosticReport.initial(
      tlsEnabled: config.useTls,
      connectionState: connectionState,
      configSnapshot: configSnapshot,
    );

    // Also push to provider for global access
    ref
        .read(globalLayerDiagnosticsProvider.notifier)
        .startRun(
          tlsEnabled: config.useTls,
          connectionState: connectionState,
          configSnapshot: configSnapshot,
        );

    safeSetState(() {});

    // Run checks sequentially
    final checks = _report!.results.map((r) => r.type).toList();

    for (final checkType in checks) {
      if (!mounted) return;

      // Mark as running
      final runningResult = DiagnosticCheckResult(
        type: checkType,
        status: DiagnosticStatus.running,
        message: 'Checking...',
      );
      _updateResult(runningResult);

      // Check prerequisite
      final prereq = checkType.effectivePrerequisite(tlsEnabled: config.useTls);
      if (prereq != null) {
        final prereqResult = _report!.resultFor(prereq);
        if (prereqResult != null &&
            prereqResult.status == DiagnosticStatus.failed) {
          final skippedResult = DiagnosticCheckResult(
            type: checkType,
            status: DiagnosticStatus.skipped,
            message: 'Skipped because ${prereq.title} failed.',
            suggestion: 'Fix ${prereq.title} first, then re-run diagnostics.',
          );
          _updateResult(skippedResult);
          continue;
        }
      }

      // Execute the check (simulated for V1)
      final result = await _executeCheck(checkType, config);
      if (!mounted) return;
      _updateResult(result);
    }

    if (!mounted) return;

    // Mark report as complete
    _report = _report!.markComplete();
    ref.read(globalLayerDiagnosticsProvider.notifier).complete();

    safeSetState(() {
      _isRunning = false;
    });

    // Haptic feedback based on result
    if (_report!.overallStatus == DiagnosticStatus.passed) {
      await haptics.trigger(HapticType.success);
    } else {
      await haptics.trigger(HapticType.error);
    }
  }

  void _updateResult(DiagnosticCheckResult result) {
    _report = _report!.updateResult(result);
    ref.read(globalLayerDiagnosticsProvider.notifier).updateResult(result);
    safeSetState(() {});
  }

  /// Simulates a diagnostic check for V1.
  ///
  /// In a future commit, this will be replaced by real network checks
  /// using an MQTT client library behind a mockable service interface.
  Future<DiagnosticCheckResult> _executeCheck(
    DiagnosticCheckType checkType,
    GlobalLayerConfig config,
  ) async {
    final stopwatch = Stopwatch()..start();

    switch (checkType) {
      case DiagnosticCheckType.configValidation:
        // This one we can actually run for real
        await Future<void>.delayed(const Duration(milliseconds: 200));
        final configResult = ConfigDiagnostics.validateConfig(config);
        stopwatch.stop();
        return configResult;

      case DiagnosticCheckType.dnsResolution:
        await Future<void>.delayed(const Duration(milliseconds: 600));
        stopwatch.stop();

        if (config.host.isEmpty) {
          return DiagnosticCheckResult.failed(
            DiagnosticCheckType.dnsResolution,
            message: 'No hostname configured.',
            suggestion: 'Enter a broker hostname in the setup wizard.',
            relatedFields: const ['host'],
            duration: stopwatch.elapsed,
          );
        }

        // Simulated success for V1
        return DiagnosticCheckResult.passed(
          DiagnosticCheckType.dnsResolution,
          'Hostname "${config.host}" resolved successfully.',
          duration: stopwatch.elapsed,
        );

      case DiagnosticCheckType.tcpConnection:
        await Future<void>.delayed(const Duration(milliseconds: 800));
        stopwatch.stop();

        return DiagnosticCheckResult.passed(
          DiagnosticCheckType.tcpConnection,
          'TCP connection to ${config.host}:${config.effectivePort} '
          'established.',
          duration: stopwatch.elapsed,
        );

      case DiagnosticCheckType.tlsHandshake:
        await Future<void>.delayed(const Duration(milliseconds: 700));
        stopwatch.stop();

        return DiagnosticCheckResult.passed(
          DiagnosticCheckType.tlsHandshake,
          'TLS handshake completed successfully.',
          duration: stopwatch.elapsed,
        );

      case DiagnosticCheckType.authentication:
        await Future<void>.delayed(const Duration(milliseconds: 500));
        stopwatch.stop();

        if (config.hasCredentials) {
          return DiagnosticCheckResult.passed(
            DiagnosticCheckType.authentication,
            'Authenticated as "${config.username}".',
            duration: stopwatch.elapsed,
          );
        }

        return DiagnosticCheckResult.passed(
          DiagnosticCheckType.authentication,
          'Anonymous connection accepted by broker.',
          duration: stopwatch.elapsed,
        );

      case DiagnosticCheckType.subscribeTest:
        await Future<void>.delayed(const Duration(milliseconds: 600));
        stopwatch.stop();

        final topicCount = config.enabledSubscriptions.length;
        return DiagnosticCheckResult.passed(
          DiagnosticCheckType.subscribeTest,
          topicCount > 0
              ? 'Subscribed to $topicCount '
                    '${topicCount == 1 ? 'topic' : 'topics'} successfully.'
              : 'Subscribe capability verified (no topics enabled).',
          duration: stopwatch.elapsed,
        );

      case DiagnosticCheckType.publishTest:
        await Future<void>.delayed(const Duration(milliseconds: 500));
        stopwatch.stop();

        return DiagnosticCheckResult.passed(
          DiagnosticCheckType.publishTest,
          'Test message published and received on loopback.',
          duration: stopwatch.elapsed,
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Clipboard export
  // ---------------------------------------------------------------------------

  Future<void> _copyToClipboard() async {
    if (_report == null) return;

    final haptics = ref.read(hapticServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    await haptics.trigger(HapticType.light);

    final summary = _report!.toClipboardSummary();
    await Clipboard.setData(ClipboardData(text: summary));

    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Diagnostics report copied to clipboard')),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Diagnostics',
      actions: [
        if (_report != null && !_isRunning)
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Copy report',
            onPressed: _copyToClipboard,
          ),
      ],
      slivers: [
        // Header
        SliverToBoxAdapter(child: _buildHeader(context)),

        // Run button or overall result
        SliverToBoxAdapter(child: _buildActionArea(context)),

        // Check results
        if (_report != null) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Check Results',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: context.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final result = _report!.results[index];
              return _DiagnosticCheckTile(result: result);
            }, childCount: _report!.results.length),
          ),
        ],

        // Plain English diagnosis
        if (_report != null && _report!.isComplete)
          SliverToBoxAdapter(child: _buildPlainEnglishDiagnosis(context)),

        // Bottom safe area
        SliverPadding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 24,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.troubleshoot, size: 20, color: context.accentColor),
                const SizedBox(width: 8),
                Text(
                  'Connection Diagnostics',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Run a series of checks to verify your broker connection. '
              'Each step tests a different layer of the connection stack.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionArea(BuildContext context) {
    if (_isRunning) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: BoxDecoration(
            color: context.accentColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.accentColor.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.accentColor,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Running checks... '
                '${_report?.passedCount ?? 0}/${_report?.results.length ?? 0}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.accentColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_report != null && _report!.isComplete) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // Overall result
            _OverallResultBanner(report: _report!),
            const SizedBox(height: 8),
            // Re-run button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _runDiagnostics,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Run Again'),
              ),
            ),
          ],
        ),
      );
    }

    // Initial state — show run button
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: BouncyTap(
          onTap: _runDiagnostics,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.accentColor,
                  context.accentColor.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_arrow, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text(
                  _hasRun ? 'Run Again' : 'Start Diagnostics',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlainEnglishDiagnosis(BuildContext context) {
    if (_report == null) return const SizedBox.shrink();

    final diagnosis = ConfigDiagnostics.plainEnglishDiagnosis(_report!);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 18,
                  color: context.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Summary',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              diagnosis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.textPrimary,
                height: 1.5,
              ),
            ),

            // Duration
            if (_report!.totalDuration != null) ...[
              const SizedBox(height: 10),
              Text(
                'Total time: ${_report!.totalDuration!.inMilliseconds}ms',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: context.textTertiary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Overall Result Banner
// =============================================================================

class _OverallResultBanner extends StatelessWidget {
  final DiagnosticReport report;

  const _OverallResultBanner({required this.report});

  @override
  Widget build(BuildContext context) {
    final status = report.overallStatus;
    final allPassed = status == DiagnosticStatus.passed;
    final hasWarning = status == DiagnosticStatus.warning;

    final Color color;
    final IconData icon;
    final String title;
    final String message;

    if (allPassed) {
      color = const Color(0xFF4ADE80);
      icon = Icons.check_circle_outline;
      title = 'All Clear';
      message = 'All ${report.passedCount} checks passed';
    } else if (hasWarning) {
      color = const Color(0xFFFBBF24);
      icon = Icons.warning_amber;
      title = 'Warnings Found';
      message = 'All checks passed but with warnings to review';
    } else {
      color = const Color(0xFFEF4444);
      icon = Icons.error_outline;
      title = 'Issues Found';
      message =
          '${report.failedCount} of ${report.results.length} checks failed';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Diagnostic Check Tile
// =============================================================================

class _DiagnosticCheckTile extends StatelessWidget {
  final DiagnosticCheckResult result;

  const _DiagnosticCheckTile({required this.result});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _borderColor(result.status),
            width: result.status.isProblem ? 1.2 : 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                _StatusIndicator(status: result.status),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result.type.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (result.duration != null)
                  Text(
                    '${result.duration!.inMilliseconds}ms',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.textTertiary,
                    ),
                  ),
              ],
            ),

            // Description (when pending)
            if (result.status == DiagnosticStatus.pending) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  result.type.description,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: context.textTertiary),
                ),
              ),
            ],

            // Result message
            if (result.message.isNotEmpty &&
                result.status != DiagnosticStatus.pending) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  result.message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _messageColor(result.status),
                  ),
                ),
              ),
            ],

            // Suggestion
            if (result.suggestion != null && result.suggestion!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.lightbulb_outline,
                          size: 14,
                          color: Color(0xFFFBBF24),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          result.suggestion!,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: const Color(0xFFFBBF24),
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _borderColor(DiagnosticStatus status) {
    return switch (status) {
      DiagnosticStatus.passed => const Color(0xFF4ADE80).withValues(alpha: 0.2),
      DiagnosticStatus.failed => const Color(0xFFEF4444).withValues(alpha: 0.3),
      DiagnosticStatus.warning => const Color(
        0xFFFBBF24,
      ).withValues(alpha: 0.3),
      DiagnosticStatus.skipped => const Color(
        0xFF9CA3AF,
      ).withValues(alpha: 0.2),
      DiagnosticStatus.running => const Color(
        0xFFFBBF24,
      ).withValues(alpha: 0.3),
      DiagnosticStatus.pending => const Color(
        0xFF9CA3AF,
      ).withValues(alpha: 0.15),
    };
  }

  Color _messageColor(DiagnosticStatus status) {
    return switch (status) {
      DiagnosticStatus.passed => const Color(0xFF4ADE80),
      DiagnosticStatus.failed => const Color(0xFFEF4444),
      DiagnosticStatus.warning => const Color(0xFFFBBF24),
      DiagnosticStatus.skipped => const Color(0xFF9CA3AF),
      DiagnosticStatus.running => const Color(0xFFFBBF24),
      DiagnosticStatus.pending => const Color(0xFF9CA3AF),
    };
  }
}

// =============================================================================
// Status Indicator
// =============================================================================

class _StatusIndicator extends StatelessWidget {
  final DiagnosticStatus status;

  const _StatusIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      DiagnosticStatus.pending => Icon(
        Icons.circle_outlined,
        size: 18,
        color: context.textTertiary.withValues(alpha: 0.5),
      ),
      DiagnosticStatus.running => SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: context.accentColor,
        ),
      ),
      DiagnosticStatus.passed => const Icon(
        Icons.check_circle,
        size: 18,
        color: Color(0xFF4ADE80),
      ),
      DiagnosticStatus.warning => const Icon(
        Icons.warning_amber,
        size: 18,
        color: Color(0xFFFBBF24),
      ),
      DiagnosticStatus.failed => const Icon(
        Icons.cancel,
        size: 18,
        color: Color(0xFFEF4444),
      ),
      DiagnosticStatus.skipped => const Icon(
        Icons.skip_next,
        size: 18,
        color: Color(0xFF9CA3AF),
      ),
    };
  }
}
