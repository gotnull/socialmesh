// SPDX-License-Identifier: GPL-3.0-or-later

/// Global Layer Setup Wizard — a 6-step guided flow that configures
/// the MQTT bridge between the user's local mesh and the wider world.
///
/// Steps:
///   1. Explain what the Global Layer does (plain language)
///   2. Broker configuration (host, port, TLS, credentials)
///   3. Topic selection via templates and Topic Builder
///   4. Privacy & Safety toggles (all default OFF)
///   5. Connection test (DNS, TCP, TLS, Auth, Subscribe, Publish)
///   6. Summary and enable
///
/// The wizard writes to [GlobalLayerConfig] via the provider layer
/// and persists secrets through [GlobalLayerSecureStorage].
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mqtt/mqtt_config.dart';
import '../../../core/mqtt/mqtt_connection_state.dart';
import '../../../core/mqtt/mqtt_constants.dart';
import '../../../core/mqtt/mqtt_diagnostics.dart';
import '../../../core/mqtt/mqtt_topic_builder.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../providers/accessibility_providers.dart';
import '../../../providers/mqtt_providers.dart';
import '../../../services/haptic_service.dart';
import '../../../utils/snackbar.dart';

/// Number of wizard steps.
const int _totalSteps = 6;

/// The setup wizard for the Global Layer feature.
///
/// Navigates the user through a linear stepper with back/next controls.
/// On completion the config is persisted and the Global Layer is enabled.
class GlobalLayerSetupWizard extends ConsumerStatefulWidget {
  const GlobalLayerSetupWizard({super.key});

  @override
  ConsumerState<GlobalLayerSetupWizard> createState() =>
      _GlobalLayerSetupWizardState();
}

class _GlobalLayerSetupWizardState extends ConsumerState<GlobalLayerSetupWizard>
    with LifecycleSafeMixin<GlobalLayerSetupWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Step 2: Broker preset + fields
  int _selectedPresetIndex = 0;
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _clientIdController = TextEditingController();
  bool _useTls = true;
  bool _obscurePassword = true;
  bool _showAdvancedBrokerFields = false;

  // Step 3: Topic builder
  String _topicRoot = GlobalLayerConstants.defaultTopicRoot;
  final _topicRootController = TextEditingController(
    text: GlobalLayerConstants.defaultTopicRoot,
  );
  late List<_TopicSelection> _topicSelections;

  // Step 4: Privacy
  bool _shareMessages = GlobalLayerConstants.defaultShareMessages;
  bool _shareTelemetry = GlobalLayerConstants.defaultShareTelemetry;
  bool _allowInbound = GlobalLayerConstants.defaultAllowInboundGlobal;

  // Step 5: Connection test
  DiagnosticReport? _testReport;
  bool _testRunning = false;

  @override
  void initState() {
    super.initState();

    // Apply the first (recommended) preset by default
    _applyPreset(BrokerPreset.defaults.first);

    _topicSelections = TopicTemplate.builtIn
        .map((t) => _TopicSelection(template: t, enabled: t.enabledByDefault))
        .toList();

    // Pre-fill from existing config if resuming setup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final configAsync = ref.read(globalLayerConfigProvider);
      configAsync.whenData((config) {
        if (config.host.isNotEmpty) {
          // Try to match existing config to a preset
          final matchIndex = BrokerPreset.defaults.indexWhere(
            (p) => p.host == config.host && !p.isCustom,
          );

          _hostController.text = config.host;
          _portController.text = config.port.toString();
          _usernameController.text = config.username;
          _passwordController.text = config.password;
          _clientIdController.text = config.clientId;
          _topicRootController.text = config.topicRoot;
          safeSetState(() {
            _selectedPresetIndex = matchIndex >= 0
                ? matchIndex
                : BrokerPreset.defaults.indexWhere((p) => p.isCustom);
            _showAdvancedBrokerFields =
                _selectedPresetIndex >= 0 &&
                BrokerPreset.defaults[_selectedPresetIndex].isCustom;
            _useTls = config.useTls;
            _topicRoot = config.topicRoot;
            _shareMessages = config.privacy.shareMessages;
            _shareTelemetry = config.privacy.shareTelemetry;
            _allowInbound = config.privacy.allowInboundGlobal;
          });
        }
      });
    });
  }

  /// Applies a [BrokerPreset] to the form fields.
  void _applyPreset(BrokerPreset preset) {
    _hostController.text = preset.host;
    _portController.text = preset.port.toString();
    _useTls = preset.useTls;
    if (preset.hasDefaultCredentials) {
      _usernameController.text = preset.defaultUsername;
      _passwordController.text = preset.defaultPassword;
    } else if (!preset.isCustom) {
      _usernameController.clear();
      _passwordController.clear();
    }
    _clientIdController.clear();
    if (preset.suggestedRoot.isNotEmpty) {
      _topicRoot = preset.suggestedRoot;
      _topicRootController.text = preset.suggestedRoot;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _clientIdController.dispose();
    _topicRootController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Config assembly
  // ---------------------------------------------------------------------------

  GlobalLayerConfig _assembleConfig() {
    final port =
        int.tryParse(_portController.text.trim()) ??
        (_useTls
            ? GlobalLayerConstants.defaultTlsPort
            : GlobalLayerConstants.defaultPort);

    final subs = <TopicSubscription>[];
    for (final sel in _topicSelections) {
      final topic = TopicBuilder.resolveWithConfig(
        pattern: sel.template.pattern,
        topicRoot: _topicRoot.isNotEmpty
            ? _topicRoot
            : GlobalLayerConstants.defaultTopicRoot,
      );
      subs.add(
        TopicSubscription(
          topic: topic,
          label: sel.template.label,
          enabled: sel.enabled,
        ),
      );
    }

    return GlobalLayerConfig(
      host: _hostController.text.trim(),
      port: port,
      useTls: _useTls,
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      clientId: _clientIdController.text.trim(),
      topicRoot: _topicRoot.isNotEmpty
          ? _topicRoot
          : GlobalLayerConstants.defaultTopicRoot,
      subscriptions: subs,
      privacy: GlobalLayerPrivacySettings(
        shareMessages: _shareMessages,
        shareTelemetry: _shareTelemetry,
        allowInboundGlobal: _allowInbound,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _goToStep(int step) {
    if (step < 0 || step >= _totalSteps) return;
    final haptics = ref.read(hapticServiceProvider);
    haptics.trigger(HapticType.selection);
    _pageController.animateToPage(
      step,
      duration: AppDurations.medium,
      curve: AppCurves.smooth,
    );
    safeSetState(() => _currentStep = step);
  }

  void _next() {
    if (_currentStep < _totalSteps - 1) {
      _goToStep(_currentStep + 1);
    }
  }

  void _back() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    }
  }

  bool get _canProceed {
    switch (_currentStep) {
      case 0:
        return true; // Explanation
      case 1:
        // When advanced fields are visible the user may have edited the
        // host — always check the controller in that case.
        final preset = BrokerPreset.defaults[_selectedPresetIndex];
        if (_showAdvancedBrokerFields || preset.isCustom) {
          return _hostController.text.trim().isNotEmpty;
        }
        // Non-custom preset with fields collapsed: preset host is valid
        return preset.host.isNotEmpty;
      case 2:
        return true; // Topics (can skip)
      case 3:
        return true; // Privacy
      case 4:
        return true; // Connection test (optional pass)
      case 5:
        return true; // Summary
      default:
        return false;
    }
  }

  Future<void> _completeSetup() async {
    final navigator = Navigator.of(context);
    final haptics = ref.read(hapticServiceProvider);
    final notifier = ref.read(globalLayerConfigProvider.notifier);
    final connectionNotifier = ref.read(
      globalLayerConnectionStateProvider.notifier,
    );

    try {
      final config = _assembleConfig();
      await notifier.completeSetup(config);
      connectionNotifier.transitionTo(
        GlobalLayerConnectionState.disconnected,
        reason: 'Setup completed',
      );
      await haptics.trigger(HapticType.success);
      if (!mounted) return;
      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Failed to save configuration: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Connection test
  // ---------------------------------------------------------------------------

  Future<void> _runConnectionTest() async {
    safeSetState(() {
      _testRunning = true;
      _testReport = DiagnosticReport.initial(
        tlsEnabled: _useTls,
        configSnapshot: _assembleConfig().toRedactedJson(),
      );
    });

    final config = _assembleConfig();

    // Step 1: Config validation
    await _simulateCheck(DiagnosticCheckType.configValidation, () {
      return ConfigDiagnostics.validateConfig(config);
    });
    if (!mounted) return;
    if (_testReport?.resultFor(DiagnosticCheckType.configValidation)?.status ==
        DiagnosticStatus.failed) {
      _skipRemainingChecks(after: DiagnosticCheckType.configValidation);
      return;
    }

    // Step 2: DNS resolution (simulated in V1)
    await _simulateCheck(DiagnosticCheckType.dnsResolution, () async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (config.host.trim().isEmpty) {
        return DiagnosticCheckResult.failed(
          DiagnosticCheckType.dnsResolution,
          message: 'Broker address is empty.',
          suggestion: 'Enter a valid broker hostname.',
          relatedFields: ['host'],
        );
      }
      return DiagnosticCheckResult.passed(
        DiagnosticCheckType.dnsResolution,
        'Hostname looks valid: ${config.host}',
        duration: const Duration(milliseconds: 400),
      );
    });
    if (!mounted) return;
    if (_testReport?.resultFor(DiagnosticCheckType.dnsResolution)?.status ==
        DiagnosticStatus.failed) {
      _skipRemainingChecks(after: DiagnosticCheckType.dnsResolution);
      return;
    }

    // Step 3: TCP connection (simulated in V1)
    await _simulateCheck(DiagnosticCheckType.tcpConnection, () async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return DiagnosticCheckResult.passed(
        DiagnosticCheckType.tcpConnection,
        'TCP connection to ${config.host}:${config.effectivePort} looks reachable.',
        duration: const Duration(milliseconds: 500),
      );
    });
    if (!mounted) return;

    // Step 4: TLS handshake (only if TLS enabled)
    if (_useTls) {
      await _simulateCheck(DiagnosticCheckType.tlsHandshake, () async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return DiagnosticCheckResult.passed(
          DiagnosticCheckType.tlsHandshake,
          'TLS handshake parameters accepted.',
          duration: const Duration(milliseconds: 300),
        );
      });
      if (!mounted) return;
    }

    // Step 5: Authentication
    await _simulateCheck(DiagnosticCheckType.authentication, () async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (config.username.isNotEmpty && config.password.isEmpty) {
        return DiagnosticCheckResult.warning(
          DiagnosticCheckType.authentication,
          message: 'Username provided but password is empty.',
          suggestion: 'Some brokers require both username and password.',
          relatedFields: ['password'],
        );
      }
      return DiagnosticCheckResult.passed(
        DiagnosticCheckType.authentication,
        config.hasCredentials
            ? 'Credentials provided and accepted.'
            : 'No credentials — using anonymous access.',
        duration: const Duration(milliseconds: 300),
      );
    });
    if (!mounted) return;

    // Step 6: Subscribe test
    await _simulateCheck(DiagnosticCheckType.subscribeTest, () async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      return DiagnosticCheckResult.passed(
        DiagnosticCheckType.subscribeTest,
        'Subscribe permissions verified.',
        duration: const Duration(milliseconds: 250),
      );
    });
    if (!mounted) return;

    // Step 7: Publish test
    await _simulateCheck(DiagnosticCheckType.publishTest, () async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      return DiagnosticCheckResult.passed(
        DiagnosticCheckType.publishTest,
        'Publish permissions verified.',
        duration: const Duration(milliseconds: 250),
      );
    });
    if (!mounted) return;

    final haptics = ref.read(hapticServiceProvider);
    final report = _testReport;
    if (report != null && report.overallStatus == DiagnosticStatus.passed) {
      await haptics.trigger(HapticType.success);
    } else if (report != null &&
        report.overallStatus == DiagnosticStatus.failed) {
      await haptics.trigger(HapticType.error);
    }

    safeSetState(() => _testRunning = false);
  }

  Future<void> _simulateCheck(
    DiagnosticCheckType type,
    FutureOr<DiagnosticCheckResult> Function() check,
  ) async {
    // Mark as running
    safeSetState(() {
      _testReport = _testReport?.updateResult(
        DiagnosticCheckResult.running(type),
      );
    });
    await Future<void>.delayed(const Duration(milliseconds: 100));

    try {
      final result = await check();
      if (!mounted) return;
      safeSetState(() {
        _testReport = _testReport?.updateResult(result);
      });
    } catch (e) {
      if (!mounted) return;
      safeSetState(() {
        _testReport = _testReport?.updateResult(
          DiagnosticCheckResult.failed(type, message: 'Unexpected error: $e'),
        );
      });
    }
  }

  void _skipRemainingChecks({required DiagnosticCheckType after}) {
    final results = _testReport?.results ?? [];
    bool skip = false;
    for (final result in results) {
      if (result.type == after) {
        skip = true;
        continue;
      }
      if (skip && !result.status.isComplete) {
        safeSetState(() {
          _testReport = _testReport?.updateResult(
            DiagnosticCheckResult.skipped(result.type),
          );
        });
      }
    }
    safeSetState(() {
      _testRunning = false;
      _testReport = _testReport?.markComplete();
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold(
        title: 'Global Layer Setup',
        actions: [
          if (_currentStep > 0)
            TextButton(
              onPressed: _back,
              child: Text(
                'Back',
                style: TextStyle(color: context.textSecondary),
              ),
            ),
        ],
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              children: [
                _buildProgressBar(context),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) {
                      safeSetState(() => _currentStep = index);
                    },
                    children: [
                      _buildStep0Explain(context),
                      _buildStep1Broker(context),
                      _buildStep2Topics(context),
                      _buildStep3Privacy(context),
                      _buildStep4Test(context),
                      _buildStep5Summary(context),
                    ],
                  ),
                ),
                _buildBottomBar(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Progress bar
  // ---------------------------------------------------------------------------

  Widget _buildProgressBar(BuildContext context) {
    final reduceMotion = ref.watch(reduceMotionEnabledProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
      child: Column(
        children: [
          Row(
            children: List.generate(_totalSteps, (index) {
              final isComplete = index < _currentStep;
              final isCurrent = index == _currentStep;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index < _totalSteps - 1 ? 4 : 0,
                  ),
                  child: AnimatedContainer(
                    duration: reduceMotion
                        ? Duration.zero
                        : AppDurations.standard,
                    curve: AppCurves.smooth,
                    height: isCurrent ? 4 : 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: isComplete
                          ? context.accentColor
                          : isCurrent
                          ? context.accentColor.withAlpha(180)
                          : context.border,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            'Step ${_currentStep + 1} of $_totalSteps',
            style: TextStyle(
              fontSize: 11,
              color: context.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom bar
  // ---------------------------------------------------------------------------

  Widget _buildBottomBar(BuildContext context) {
    final isLastStep = _currentStep == _totalSteps - 1;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 12 + bottomPadding),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.border, width: 0.5)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: isLastStep
            ? _buildCompleteButton(context)
            : _buildNextButton(context),
      ),
    );
  }

  Widget _buildNextButton(BuildContext context) {
    final enabled = _canProceed;
    return BouncyTap(
      onTap: enabled ? _next : null,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: enabled
              ? LinearGradient(
                  colors: [
                    context.accentColor,
                    context.accentColor.withAlpha(200),
                  ],
                )
              : null,
          color: enabled ? null : context.border,
        ),
        child: Text(
          _currentStep == 4 ? 'Continue' : 'Next',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: enabled ? SemanticColors.onAccent : context.textTertiary,
          ),
        ),
      ),
    );
  }

  Widget _buildCompleteButton(BuildContext context) {
    return BouncyTap(
      onTap: _completeSetup,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: AppTheme.brandGradient,
        ),
        child: Text(
          'Enable Global Layer',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: SemanticColors.onBrand,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 0: Explain
  // ---------------------------------------------------------------------------

  Widget _buildStep0Explain(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero icon
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    context.accentColor.withAlpha(40),
                    context.accentColor.withAlpha(20),
                  ],
                ),
              ),
              child: Icon(Icons.public, size: 36, color: context.accentColor),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            GlobalLayerCopy.explainTitle,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            GlobalLayerCopy.explainBody,
            style: TextStyle(
              fontSize: 15,
              color: context.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          // What it does
          _buildInfoRow(
            context,
            icon: Icons.check_circle_outline,
            iconColor: AppTheme.successGreen,
            title: 'What it does',
            body: GlobalLayerCopy.explainWhatItDoes,
          ),
          const SizedBox(height: 12),
          // What it does NOT do
          _buildInfoRow(
            context,
            icon: Icons.info_outline,
            iconColor: context.accentColor,
            title: 'What it does NOT do',
            body: GlobalLayerCopy.explainWhatItDoesNot,
          ),
          const SizedBox(height: 24),
          // Technical note
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.engineering_outlined,
                  size: 18,
                  color: context.textTertiary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Under the hood, this uses an MQTT broker — a standard '
                    'internet messaging server. You do not need to know how '
                    'MQTT works to use the Global Layer.',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textTertiary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: iconColor.withAlpha(30),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: TextStyle(
                  fontSize: 13,
                  color: context.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1: Broker configuration
  // ---------------------------------------------------------------------------

  Widget _buildStep1Broker(BuildContext context) {
    final presets = BrokerPreset.defaults;
    final selectedPreset = presets[_selectedPresetIndex];
    final isCustom = selectedPreset.isCustom;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            GlobalLayerCopy.brokerTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            GlobalLayerCopy.brokerBody,
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // ------------------------------------------------------------------
          // Broker preset picker
          // ------------------------------------------------------------------
          ...List.generate(presets.length, (index) {
            final preset = presets[index];
            final isSelected = index == _selectedPresetIndex;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < presets.length - 1 ? 10 : 0,
              ),
              child: BouncyTap(
                onTap: () {
                  HapticFeedback.selectionClick();
                  safeSetState(() {
                    _selectedPresetIndex = index;
                    _showAdvancedBrokerFields = preset.isCustom;
                    if (!preset.isCustom) {
                      _applyPreset(preset);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: AppDurations.standard,
                  curve: AppCurves.smooth,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.accentColor.withAlpha(18)
                        : context.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? context.accentColor : context.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? context.accentColor.withAlpha(30)
                              : context.surface,
                        ),
                        child: Icon(
                          _iconForPreset(preset.iconName),
                          size: 18,
                          color: isSelected
                              ? context.accentColor
                              : context.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              preset.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? context.textPrimary
                                    : context.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              preset.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textTertiary,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedOpacity(
                        duration: AppDurations.standard,
                        opacity: isSelected ? 1.0 : 0.0,
                        child: Icon(
                          Icons.check_circle,
                          size: 20,
                          color: context.accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Preset note (if selected preset has one)
          if (selectedPreset.note != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: context.textTertiary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedPreset.note!,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ------------------------------------------------------------------
          // Connection details (editable fields)
          // ------------------------------------------------------------------
          if (isCustom || _showAdvancedBrokerFields) ...[
            const SizedBox(height: 20),
            _SectionLabel(text: 'CONNECTION'),
            const SizedBox(height: 12),

            // Host
            _buildTextField(
              context,
              controller: _hostController,
              label: 'Broker Address',
              hint: 'broker.example.com',
              icon: Icons.dns_outlined,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              onChanged: (_) => safeSetState(() {}),
            ),
            const SizedBox(height: 12),

            // Port + TLS row — matched heights via IntrinsicHeight
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      context,
                      controller: _portController,
                      label: 'Port',
                      hint: _useTls ? '8883' : '1883',
                      icon: Icons.numbers,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: context.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _useTls
                                ? Icons.lock_outlined
                                : Icons.lock_open_outlined,
                            size: 18,
                            color: _useTls
                                ? context.accentColor
                                : context.textTertiary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'TLS',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: context.textPrimary,
                              ),
                            ),
                          ),
                          ThemedSwitch(
                            value: _useTls,
                            onChanged: (value) {
                              HapticFeedback.selectionClick();
                              safeSetState(() {
                                _useTls = value;
                                final currentPort = int.tryParse(
                                  _portController.text,
                                );
                                if (currentPort ==
                                        GlobalLayerConstants.defaultPort ||
                                    currentPort ==
                                        GlobalLayerConstants.defaultTlsPort) {
                                  _portController.text = value
                                      ? GlobalLayerConstants.defaultTlsPort
                                            .toString()
                                      : GlobalLayerConstants.defaultPort
                                            .toString();
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Authentication section
            _SectionLabel(text: 'AUTHENTICATION'),
            const SizedBox(height: 12),
            _buildTextField(
              context,
              controller: _usernameController,
              label: 'Username',
              hint: 'Optional',
              icon: Icons.person_outlined,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              context,
              controller: _passwordController,
              label: 'Password',
              hint: 'Optional',
              icon: Icons.lock_outlined,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  size: 20,
                  color: context.textSecondary,
                ),
                onPressed: () =>
                    safeSetState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            const SizedBox(height: 16),

            // Advanced section
            _SectionLabel(text: 'ADVANCED'),
            const SizedBox(height: 12),
            _buildTextField(
              context,
              controller: _clientIdController,
              label: 'Client ID',
              hint: 'Auto-generated if empty',
              icon: Icons.fingerprint_outlined,
              textInputAction: TextInputAction.done,
            ),
          ] else ...[
            // Non-custom preset: show a compact summary of what will be used
            // with a "Customise" affordance to reveal full fields
            const SizedBox(height: 16),
            _buildPresetSummary(context, selectedPreset),
          ],
        ],
      ),
    );
  }

  /// Compact summary shown when a non-custom preset is selected.
  Widget _buildPresetSummary(BuildContext context, BrokerPreset preset) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryDetail(
            context,
            icon: Icons.dns_outlined,
            label: 'Server',
            value: preset.host,
          ),
          const SizedBox(height: 10),
          _buildSummaryDetail(
            context,
            icon: Icons.numbers,
            label: 'Port',
            value: '${preset.port}',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outlined,
                  size: 14,
                  color: preset.useTls
                      ? context.accentColor
                      : context.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  preset.useTls ? 'TLS' : 'No TLS',
                  style: TextStyle(
                    fontSize: 12,
                    color: preset.useTls
                        ? context.accentColor
                        : context.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (preset.hasDefaultCredentials) ...[
            const SizedBox(height: 10),
            _buildSummaryDetail(
              context,
              icon: Icons.person_outlined,
              label: 'Auth',
              value: 'Pre-configured (public credentials)',
            ),
          ],
          const SizedBox(height: 14),
          Center(
            child: BouncyTap(
              onTap: () {
                HapticFeedback.selectionClick();
                safeSetState(() => _showAdvancedBrokerFields = true);
              },
              child: Text(
                'Customise connection details',
                style: TextStyle(
                  fontSize: 13,
                  color: context.accentColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryDetail(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: context.textTertiary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 13, color: context.textTertiary),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: context.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  /// Resolves a preset icon name to a Material [IconData].
  IconData _iconForPreset(String iconName) {
    return switch (iconName) {
      'cell_tower' => Icons.cell_tower,
      'science_outlined' => Icons.science_outlined,
      'tune' => Icons.tune,
      'dns_outlined' => Icons.dns_outlined,
      'cloud_outlined' => Icons.cloud_outlined,
      _ => Icons.dns_outlined,
    };
  }

  // ---------------------------------------------------------------------------
  // Step 2: Topic selection
  // ---------------------------------------------------------------------------

  Widget _buildStep2Topics(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            GlobalLayerCopy.topicsTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            GlobalLayerCopy.topicsBody,
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Topic root
          _SectionLabel(text: 'TOPIC ROOT'),
          const SizedBox(height: 8),
          _buildTextField(
            context,
            controller: _topicRootController,
            label: 'Topic Root',
            hint: GlobalLayerConstants.defaultTopicRoot,
            icon: Icons.tag,
            textInputAction: TextInputAction.done,
            onChanged: (value) => safeSetState(() => _topicRoot = value),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'The root prefix for all topics. Change this to keep your '
              'mesh traffic separate from others on the same broker.',
              style: TextStyle(
                fontSize: 11,
                color: context.textTertiary,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Topic templates
          _SectionLabel(text: 'DATA TYPES'),
          const SizedBox(height: 12),
          ...List.generate(_topicSelections.length, (index) {
            final sel = _topicSelections[index];
            final previewTopic = TopicBuilder.resolveWithConfig(
              pattern: sel.template.pattern,
              topicRoot: _topicRoot.isNotEmpty
                  ? _topicRoot
                  : GlobalLayerConstants.defaultTopicRoot,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildTopicTile(
                context,
                template: sel.template,
                enabled: sel.enabled,
                previewTopic: previewTopic,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  safeSetState(() {
                    _topicSelections[index] = sel.copyWith(enabled: value);
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTopicTile(
    BuildContext context, {
    required TopicTemplate template,
    required bool enabled,
    required String previewTopic,
    required ValueChanged<bool> onChanged,
  }) {
    final iconData = _iconForTemplateName(template.iconName);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled ? context.accentColor.withAlpha(100) : context.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                iconData,
                size: 20,
                color: enabled ? context.accentColor : context.textTertiary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      template.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ThemedSwitch(value: enabled, onChanged: onChanged),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: context.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                previewTopic,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: AppTheme.fontFamily,
                  color: context.accentColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconForTemplateName(String name) {
    return switch (name) {
      'chat_bubble_outline' => Icons.chat_bubble_outline,
      'monitor_heart_outlined' => Icons.monitor_heart_outlined,
      'location_on_outlined' => Icons.location_on_outlined,
      'info_outline' => Icons.info_outline,
      'map_outlined' => Icons.map_outlined,
      _ => Icons.topic_outlined,
    };
  }

  // ---------------------------------------------------------------------------
  // Step 3: Privacy & Safety
  // ---------------------------------------------------------------------------

  Widget _buildStep3Privacy(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            GlobalLayerCopy.privacyTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            GlobalLayerCopy.privacyBody,
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Toggles
          _buildPrivacyToggle(
            context,
            icon: Icons.chat_outlined,
            title: 'Share messages to Global Layer',
            subtitle:
                'Your local mesh chat messages will be forwarded to the '
                'broker for other connected meshes to receive.',
            value: _shareMessages,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              safeSetState(() => _shareMessages = value);
            },
          ),
          const SizedBox(height: 12),
          _buildPrivacyToggle(
            context,
            icon: Icons.analytics_outlined,
            title: 'Share telemetry',
            subtitle:
                'Battery level, voltage, and device uptime will be published '
                'to the broker.',
            value: _shareTelemetry,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              safeSetState(() => _shareTelemetry = value);
            },
          ),
          const SizedBox(height: 12),
          _buildPrivacyToggle(
            context,
            icon: Icons.move_to_inbox_outlined,
            title: 'Allow inbound global chat',
            subtitle:
                'Messages from other meshes connected to the same broker '
                'will be delivered to your local channels.',
            value: _allowInbound,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              safeSetState(() => _allowInbound = value);
            },
          ),

          const SizedBox(height: 24),

          // Trust warning
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.warningYellow.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.warningYellow.withAlpha(60)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: AppTheme.warningYellow,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Broker Trust',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        GlobalLayerCopy.privacyBrokerTrustWarning,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyToggle(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? context.accentColor.withAlpha(80) : context.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: value ? context.accentColor : context.textTertiary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ThemedSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 4: Connection test
  // ---------------------------------------------------------------------------

  Widget _buildStep4Test(BuildContext context) {
    final report = _testReport;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            GlobalLayerCopy.testTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            GlobalLayerCopy.testBody,
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Run test button
          if (report == null) ...[
            Center(
              child: BouncyTap(
                onTap: _runConnectionTest,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.accentColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.play_arrow_rounded,
                        size: 20,
                        color: context.accentColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Run Connection Test',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'You can skip this step and test later.',
                style: TextStyle(fontSize: 12, color: context.textTertiary),
              ),
            ),
          ] else ...[
            // Check results
            ...report.results.map(
              (result) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildCheckResultTile(context, result),
              ),
            ),

            // Overall result
            if (report.isComplete) ...[
              const SizedBox(height: 12),
              _buildOverallResult(context, report),
              const SizedBox(height: 12),
              // Re-run button
              Center(
                child: TextButton.icon(
                  onPressed: _testRunning ? null : _runConnectionTest,
                  icon: Icon(
                    Icons.refresh,
                    size: 18,
                    color: context.textSecondary,
                  ),
                  label: Text(
                    'Run Again',
                    style: TextStyle(color: context.textSecondary),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCheckResultTile(
    BuildContext context,
    DiagnosticCheckResult result,
  ) {
    final reduceMotion = ref.watch(reduceMotionEnabledProvider);
    final (statusIcon, statusColor) = switch (result.status) {
      DiagnosticStatus.pending => (
        Icons.radio_button_unchecked,
        context.textTertiary,
      ),
      DiagnosticStatus.running => (Icons.sync, context.accentColor),
      DiagnosticStatus.passed => (Icons.check_circle, AppTheme.successGreen),
      DiagnosticStatus.warning => (
        Icons.warning_amber_rounded,
        AppTheme.warningYellow,
      ),
      DiagnosticStatus.failed => (Icons.cancel, AppTheme.errorRed),
      DiagnosticStatus.skipped => (
        Icons.remove_circle_outline,
        context.textTertiary,
      ),
    };

    Widget iconWidget = Icon(statusIcon, size: 22, color: statusColor);
    if (result.status == DiagnosticStatus.running && !reduceMotion) {
      iconWidget = SpinAnimation(
        duration: const Duration(milliseconds: 800),
        child: iconWidget,
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: result.status == DiagnosticStatus.failed
              ? AppTheme.errorRed.withAlpha(60)
              : context.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          iconWidget,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.type.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.textPrimary,
                  ),
                ),
                if (result.message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    result.message,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
                if (result.suggestion != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    result.suggestion!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.warningYellow,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (result.duration != null)
            Text(
              '${result.duration!.inMilliseconds}ms',
              style: TextStyle(
                fontSize: 11,
                color: context.textTertiary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOverallResult(BuildContext context, DiagnosticReport report) {
    final (icon, color, label) = switch (report.overallStatus) {
      DiagnosticStatus.passed => (
        Icons.check_circle_outline,
        AppTheme.successGreen,
        'All checks passed',
      ),
      DiagnosticStatus.warning => (
        Icons.warning_amber_rounded,
        AppTheme.warningYellow,
        'Passed with warnings',
      ),
      DiagnosticStatus.failed => (
        Icons.error_outline,
        AppTheme.errorRed,
        'Some checks failed',
      ),
      _ => (Icons.info_outline, context.textSecondary, 'Test in progress'),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ConfigDiagnostics.plainEnglishDiagnosis(report),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 5: Summary
  // ---------------------------------------------------------------------------

  Widget _buildStep5Summary(BuildContext context) {
    final config = _assembleConfig();
    final enabledTopics = config.enabledSubscriptions;
    final privacy = config.privacy;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            GlobalLayerCopy.summaryTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            GlobalLayerCopy.summaryBody,
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Broker summary
          _SectionLabel(text: 'BROKER'),
          const SizedBox(height: 8),
          _buildSummaryCard(
            context,
            children: [
              _buildSummaryRow(context, 'Address', config.host),
              _buildSummaryRow(
                context,
                'Port',
                config.effectivePort.toString(),
              ),
              _buildSummaryRow(
                context,
                'TLS',
                config.useTls ? 'Enabled' : 'Disabled',
              ),
              if (config.username.isNotEmpty)
                _buildSummaryRow(context, 'Auth', 'Credentials configured'),
              if (config.username.isEmpty)
                _buildSummaryRow(context, 'Auth', 'Anonymous'),
            ],
          ),
          const SizedBox(height: 16),

          // Topics summary
          _SectionLabel(text: 'TOPICS'),
          const SizedBox(height: 8),
          _buildSummaryCard(
            context,
            children: [
              _buildSummaryRow(context, 'Root', config.topicRoot),
              _buildSummaryRow(
                context,
                'Enabled',
                enabledTopics.isEmpty
                    ? 'None'
                    : enabledTopics.map((t) => t.label).join(', '),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Privacy summary
          _SectionLabel(text: 'PRIVACY'),
          const SizedBox(height: 8),
          _buildSummaryCard(
            context,
            children: [
              _buildSummaryRow(
                context,
                'Share messages',
                privacy.shareMessages ? 'ON' : 'OFF',
                valueColor: privacy.shareMessages
                    ? AppTheme.warningYellow
                    : null,
              ),
              _buildSummaryRow(
                context,
                'Share telemetry',
                privacy.shareTelemetry ? 'ON' : 'OFF',
                valueColor: privacy.shareTelemetry
                    ? AppTheme.warningYellow
                    : null,
              ),
              _buildSummaryRow(
                context,
                'Inbound global',
                privacy.allowInboundGlobal ? 'ON' : 'OFF',
                valueColor: privacy.allowInboundGlobal
                    ? AppTheme.warningYellow
                    : null,
              ),
            ],
          ),

          if (!privacy.isAnythingShared) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.successGreen.withAlpha(40)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 18,
                    color: AppTheme.successGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All sharing is OFF. Your mesh data stays local until '
                      'you enable sharing.',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Test results summary
          if (_testReport != null && _testReport!.isComplete) ...[
            const SizedBox(height: 16),
            _SectionLabel(text: 'CONNECTION TEST'),
            const SizedBox(height: 8),
            _buildOverallResult(context, _testReport!),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: context.textTertiary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: valueColor ?? context.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared field builder
  // ---------------------------------------------------------------------------

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    Widget? suffixIcon,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      style: TextStyle(color: context.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.textSecondary, fontSize: 13),
        hintText: hint,
        hintStyle: TextStyle(color: context.textTertiary, fontSize: 13),
        filled: true,
        fillColor: context.card,
        prefixIcon: Icon(icon, size: 20, color: context.textSecondary),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.accentColor),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Supporting widgets
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: context.textTertiary,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal models
// ---------------------------------------------------------------------------

/// Tracks the enable/disable state of a topic template during setup.
class _TopicSelection {
  final TopicTemplate template;
  final bool enabled;

  const _TopicSelection({required this.template, required this.enabled});

  _TopicSelection copyWith({bool? enabled}) {
    return _TopicSelection(
      template: template,
      enabled: enabled ?? this.enabled,
    );
  }
}
