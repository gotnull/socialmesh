// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/legal/legal_constants.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';

import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../core/widgets/animations.dart';
import '../../utils/validation.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/bottom_action_bar.dart';
import '../../core/widgets/branded_qr_code.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/channel_key_field.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../l10n/app_localizations.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import '../../utils/encoding.dart';
import '../../utils/snackbar.dart';
import '../../core/widgets/legal_document_sheet.dart';
import '../../core/widgets/status_banner.dart';
import '../../generated/meshtastic/channel.pb.dart' as channel_pb;
import '../../generated/meshtastic/channel.pbenum.dart' as channel_pbenum;

/// Step-specific help content for the channel wizard
class _WizardStepHelp {
  final String Function(AppLocalizations l10n) title;
  final String Function(AppLocalizations l10n) content;
  final IconData icon;
  final Color color;

  const _WizardStepHelp({
    required this.title,
    required this.content,
    required this.icon,
    required this.color,
  });

  static List<_WizardStepHelp> steps = [
    _WizardStepHelp(
      title: (l10n) => l10n.channelWizardStepNameTitle,
      icon: Icons.edit,
      color: AppTheme.primaryBlue,
      content: (l10n) => l10n.channelWizardStepNameContent,
    ),
    _WizardStepHelp(
      title: (l10n) => l10n.channelWizardStepPrivacyTitle,
      icon: Icons.security,
      color: AppTheme.primaryPurple,
      content: (l10n) => l10n.channelWizardStepPrivacyContent,
    ),
    _WizardStepHelp(
      title: (l10n) => l10n.channelWizardStepOptionsTitle,
      icon: Icons.tune,
      color: AppTheme.primaryBlue,
      content: (l10n) => l10n.channelWizardStepOptionsContent,
    ),
    _WizardStepHelp(
      title: (l10n) => l10n.channelWizardStepReviewTitle,
      icon: Icons.check_circle,
      color: AppTheme.successGreen,
      content: (l10n) => l10n.channelWizardStepReviewContent,
    ),
  ];
}

/// Key size options with security explanations
enum WizardKeySize {
  none(0),
  default1(1),
  bit128(16),
  bit256(32);

  final int bytes;

  const WizardKeySize(this.bytes);

  String displayName(AppLocalizations l10n) {
    switch (this) {
      case WizardKeySize.none:
        return l10n.channelWizardKeySizeNone;
      case WizardKeySize.default1:
        return l10n.channelWizardKeySizeDefault;
      case WizardKeySize.bit128:
        return l10n.channelWizardKeySizeAes128;
      case WizardKeySize.bit256:
        return l10n.channelWizardKeySizeAes256;
    }
  }

  String description(AppLocalizations l10n) {
    switch (this) {
      case WizardKeySize.none:
        return l10n.channelWizardKeySizeNoneDesc;
      case WizardKeySize.default1:
        return l10n.channelWizardKeySizeDefaultDesc;
      case WizardKeySize.bit128:
        return l10n.channelWizardKeySizeAes128Desc;
      case WizardKeySize.bit256:
        return l10n.channelWizardKeySizeAes256Desc;
    }
  }
}

/// Privacy level with detailed explanations
enum PrivacyLevel { open, shared, private, maximum }

extension PrivacyLevelExt on PrivacyLevel {
  String title(AppLocalizations l10n) {
    switch (this) {
      case PrivacyLevel.open:
        return l10n.channelWizardPrivacyOpenTitle;
      case PrivacyLevel.shared:
        return l10n.channelWizardPrivacySharedTitle;
      case PrivacyLevel.private:
        return l10n.channelWizardPrivacyPrivateTitle;
      case PrivacyLevel.maximum:
        return l10n.channelWizardPrivacyMaxTitle;
    }
  }

  String description(AppLocalizations l10n) {
    switch (this) {
      case PrivacyLevel.open:
        return l10n.channelWizardPrivacyOpenDesc;
      case PrivacyLevel.shared:
        return l10n.channelWizardPrivacySharedDesc;
      case PrivacyLevel.private:
        return l10n.channelWizardPrivacyPrivateDesc;
      case PrivacyLevel.maximum:
        return l10n.channelWizardPrivacyMaxDesc;
    }
  }

  IconData get icon {
    switch (this) {
      case PrivacyLevel.open:
        return Icons.public;
      case PrivacyLevel.shared:
        return Icons.people;
      case PrivacyLevel.private:
        return Icons.lock;
      case PrivacyLevel.maximum:
        return Icons.shield;
    }
  }

  Color get color {
    switch (this) {
      case PrivacyLevel.open:
        return AppTheme.warningYellow;
      case PrivacyLevel.shared:
        return AppTheme.primaryBlue;
      case PrivacyLevel.private:
        return AppTheme.successGreen;
      case PrivacyLevel.maximum:
        return AppTheme.primaryPurple;
    }
  }

  WizardKeySize get keySize {
    switch (this) {
      case PrivacyLevel.open:
        return WizardKeySize.none;
      case PrivacyLevel.shared:
        return WizardKeySize.default1;
      case PrivacyLevel.private:
        return WizardKeySize.bit128;
      case PrivacyLevel.maximum:
        return WizardKeySize.bit256;
    }
  }
}

class ChannelWizardScreen extends ConsumerStatefulWidget {
  final int channelIndex;

  const ChannelWizardScreen({super.key, required this.channelIndex});

  @override
  ConsumerState<ChannelWizardScreen> createState() =>
      _ChannelWizardScreenState();
}

class _ChannelWizardScreenState extends ConsumerState<ChannelWizardScreen>
    with LifecycleSafeMixin {
  final _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 4;

  // Step 1: Name
  final _nameController = TextEditingController();

  // Step 2: Privacy level
  PrivacyLevel _privacyLevel = PrivacyLevel.private;

  // Step 3: Advanced options (optional)
  bool _uplinkEnabled = false;
  bool _downlinkEnabled = false;
  bool _positionEnabled = false;

  // Key management — controller is wizard-owned so the manual-entry
  // text can be committed into _generatedKey before navigating to
  // Review or saving the channel.
  final _keyController = TextEditingController();
  List<int> _generatedKey = [];
  String? _keyCommitError;

  // Saving state
  bool _isSaving = false;
  bool _saveComplete = false;

  @override
  void initState() {
    super.initState();
    _generateKey(source: 'init');
    // Rebuild the Continue button as the user types so it tracks key
    // validity in real time and stays disabled on invalid base64.
    _keyController.addListener(_onKeyControllerChanged);
  }

  @override
  void dispose() {
    _keyController.removeListener(_onKeyControllerChanged);
    _nameController.dispose();
    _keyController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onKeyControllerChanged() {
    if (!mounted) return;
    setState(() {
      // Clear any stale commit error once the user resumes typing —
      // the live validity check in canProceed takes over.
      if (_keyCommitError != null) _keyCommitError = null;
    });
  }

  bool _isEncryptionKeyValid() {
    if (!_keyFieldVisible) return true;
    final expected = _privacyLevel.keySize.bytes;
    if (expected <= 1) return true;
    final decoded = ChannelKeyUtils.base64ToKey(_keyController.text.trim());
    return decoded != null && decoded.length == expected;
  }

  bool get _isDirty {
    if (_saveComplete) return false;
    if (_nameController.text.trim().isNotEmpty) return true;
    if (_currentStep > 0) return true;
    if (_uplinkEnabled || _downlinkEnabled || _positionEnabled) return true;
    return false;
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_isDirty) return true;
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.channelWizardDiscardTitle,
      message: context.l10n.channelWizardDiscardMessage,
      confirmLabel: context.l10n.channelWizardDiscardConfirm,
      cancelLabel: context.l10n.channelWizardDiscardCancel,
      isDestructive: true,
    );
    return confirmed == true;
  }

  Future<void> _handleCloseTap() async {
    FocusScope.of(context).unfocus();
    if (_isSaving) return;
    final navigator = Navigator.of(context);
    final shouldClose = await _confirmDiscardChanges();
    if (shouldClose && mounted) {
      navigator.pop();
    }
  }

  void _generateKey({String source = 'generated'}) {
    final keySize = _privacyLevel.keySize;
    if (keySize.bytes == 0) {
      _generatedKey = [];
    } else if (keySize.bytes == 1) {
      _generatedKey = [1]; // Default key marker
    } else {
      final random = Random.secure();
      _generatedKey = List.generate(keySize.bytes, (_) => random.nextInt(256));
    }
    _keyController.text = ChannelKeyUtils.keyToBase64(_generatedKey);
    _keyCommitError = null;
    AppLogging.channels(
      'wizard key commit: source=$source byteLength=${_generatedKey.length} '
      'valid=true pskFp=${AppLogging.pskFingerprint(_generatedKey)}',
    );
  }

  /// Trim/validate the live text in the key controller and persist it
  /// into the wizard draft. Returns false (and sets [_keyCommitError])
  /// when the controller text is not valid base64 for the current
  /// privacy level — callers must block navigation in that case.
  ///
  /// Steps that don't render a key field (Open, Shared, or any
  /// privacy level whose key size is < 16 bytes) commit a fixed value
  /// derived from the privacy level itself and always succeed.
  bool _commitEncryptionKeyFromController() {
    final expectedBytes = _privacyLevel.keySize.bytes;
    if (expectedBytes == 0) {
      _generatedKey = [];
      _keyController.text = '';
      _keyCommitError = null;
      AppLogging.channels(
        'wizard key commit: source=none expectedBytes=0 valid=true',
      );
      return true;
    }
    if (expectedBytes == 1) {
      _generatedKey = [1];
      _keyController.text = 'AQ==';
      _keyCommitError = null;
      AppLogging.channels(
        'wizard key commit: source=default expectedBytes=1 valid=true',
      );
      return true;
    }
    final raw = _keyController.text.trim();
    final decoded = ChannelKeyUtils.base64ToKey(raw);
    if (decoded == null) {
      safeSetState(() {
        _keyCommitError = context.l10n.channelWizardKeyInvalidBase64;
      });
      AppLogging.channels(
        'wizard key commit FAILED: source=manual reason=invalid_base64 '
        'expectedBytes=$expectedBytes valid=false',
      );
      return false;
    }
    if (decoded.length != expectedBytes) {
      safeSetState(() {
        _keyCommitError = context.l10n.channelWizardKeyWrongLength(
          expectedBytes,
          decoded.length,
        );
      });
      AppLogging.channels(
        'wizard key commit FAILED: source=manual reason=wrong_length '
        'expectedBytes=$expectedBytes actualBytes=${decoded.length} valid=false',
      );
      return false;
    }
    final normalized = ChannelKeyUtils.keyToBase64(decoded);
    safeSetState(() {
      _generatedKey = decoded;
      _keyCommitError = null;
      if (_keyController.text != normalized) {
        _keyController.text = normalized;
      }
    });
    AppLogging.channels(
      'wizard key commit: source=manual byteLength=${decoded.length} '
      'valid=true pskFp=${AppLogging.pskFingerprint(_generatedKey)}',
    );
    return true;
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      // Warn about default key when advancing from privacy step with "Shared"
      if (_currentStep == 1 && _privacyLevel == PrivacyLevel.shared) {
        _showDefaultKeyWarning();
        return;
      }
      // Leaving the Advanced Options step: commit whatever the user
      // currently has in the encryption-key field so Review sees the
      // exact bytes that will end up on the channel.
      if (_currentStep == 2 && _keyFieldVisible) {
        if (!_commitEncryptionKeyFromController()) {
          showErrorSnackBar(
            context,
            _keyCommitError ?? context.l10n.channelWizardKeyInvalidBase64,
          );
          return;
        }
      }
      _proceedToNextStep();
    }
  }

  bool get _keyFieldVisible =>
      _privacyLevel == PrivacyLevel.private ||
      _privacyLevel == PrivacyLevel.maximum;

  void _proceedToNextStep() {
    // Regenerate key when privacy level changes (entering options step)
    if (_currentStep == 1) {
      _generateKey(source: 'privacy_changed');
    }
    setState(() {
      _currentStep++;
    });
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _showDefaultKeyWarning() {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppTheme.spacing16),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.warningYellow.withAlpha(51),
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.warningYellow,
                ),
              ),
              const SizedBox(width: AppTheme.spacing16),
              Expanded(
                child: Text(
                  l10n.channelWizardDefaultKeyWarningTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing20),
          Text(
            l10n.channelWizardDefaultKeyWarningBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _privacyLevel = PrivacyLevel.private;
                });
                _proceedToNextStep();
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.successGreen,
                padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.spacing16,
                ),
              ),
              child: Text(l10n.channelWizardDefaultKeyUpgrade),
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                _proceedToNextStep();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: context.textSecondary,
                side: BorderSide(color: context.border),
                padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.spacing16,
                ),
              ),
              child: Text(l10n.channelWizardDefaultKeyKeep),
            ),
          ),
        ],
      ),
    );
  }

  void _previousStep() {
    if (_currentStep > 0) {
      FocusScope.of(context).unfocus();
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showStepHelp() {
    final stepHelp = _WizardStepHelp.steps[_currentStep];
    final l10n = context.l10n;
    AppBottomSheet.show<void>(
      context: context,
      child: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: stepHelp.color.withAlpha(51),
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                  child: Icon(stepHelp.icon, color: stepHelp.color),
                ),
                const SizedBox(width: AppTheme.spacing16),
                Expanded(
                  child: Text(
                    stepHelp.title(l10n),
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(
                          color: sheetContext.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: sheetContext.textSecondary),
                  onPressed: () => Navigator.pop(sheetContext),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing20),
            Text(
              stepHelp.content(l10n),
              style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                color: sheetContext.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
            InkWell(
              onTap: () {
                Navigator.pop(sheetContext);
                LegalDocumentSheet.showTermsSection(
                  context,
                  LegalConstants.anchorRadioCompliance,
                );
              },
              borderRadius: BorderRadius.circular(AppTheme.radius8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.cell_tower,
                      size: 18,
                      color: sheetContext.accentColor,
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    Expanded(
                      child: Text(
                        sheetContext.l10n.channelWizardRadioComplianceLink,
                        style: TextStyle(
                          color: sheetContext.accentColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.open_in_new,
                      size: 16,
                      color: sheetContext.accentColor,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveChannel() async {
    if (_isSaving) return;

    // Safety net: if the user somehow reached Review without leaving
    // step 3 through _nextStep (programmatic jump, future shortcut),
    // re-commit the key field before sending the channel.
    if (_keyFieldVisible && !_commitEncryptionKeyFromController()) {
      showErrorSnackBar(
        context,
        _keyCommitError ?? context.l10n.channelWizardKeyInvalidBase64,
      );
      return;
    }

    // Check connection state before saving
    final connectionState = ref.read(connectionStateProvider);
    final isConnected = connectionState.maybeWhen(
      data: (state) => state == DeviceConnectionState.connected,
      orElse: () => false,
    );

    if (!isConnected) {
      showErrorSnackBar(context, context.l10n.channelWizardDeviceNotConnected);
      return;
    }

    // Capture providers before async gap
    final protocol = ref.read(protocolServiceProvider);
    final channelsNotifier = ref.read(channelsProvider.notifier);

    safeSetState(() {
      _isSaving = true;
    });

    try {
      final channel = ChannelConfig(
        index: widget.channelIndex,
        name: _nameController.text.trim(),
        psk: _generatedKey,
        role: 'SECONDARY',
        uplink: _uplinkEnabled,
        downlink: _downlinkEnabled,
        positionPrecision: _positionEnabled ? 32 : 0,
      );

      AppLogging.channels(
        'wizard create channel: index=${channel.index} '
        'pskFp=${AppLogging.pskFingerprint(channel.psk)}',
      );

      await protocol.setChannel(channel);
      if (!mounted) return;

      // Update local state
      channelsNotifier.setChannel(channel);

      safeSetState(() {
        _saveComplete = true;
      });
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          context.l10n.channelWizardCreateFailed(e.toString()),
        );
        safeSetState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _generateChannelUrl() {
    final channelSettings = channel_pb.ChannelSettings()
      ..name = _nameController.text.trim();

    final key = _generatedKey;
    if (key.isNotEmpty) {
      channelSettings.psk = key;
    }

    final channel = channel_pb.Channel()
      ..index = widget.channelIndex
      ..settings = channelSettings
      ..role = channel_pbenum.Channel_Role.SECONDARY;

    final bytes = channel.writeToBuffer();
    final encoded = base64
        .encode(bytes)
        .replaceAll('+', '-')
        .replaceAll('/', '_');
    return 'socialmesh://channel/$encoded'; // lint-allow: hardcoded-string
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stepHelp = _WizardStepHelp.steps[_currentStep];

    return PopScope(
      canPop: !_isDirty || _saveComplete,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_isSaving) return;
        final navigator = Navigator.of(context);
        final shouldClose = await _confirmDiscardChanges();
        if (shouldClose && mounted) {
          navigator.pop();
        }
      },
      child: _buildScaffold(theme, stepHelp),
    );
  }

  Widget _buildScaffold(ThemeData theme, _WizardStepHelp stepHelp) {
    return GlassScaffold.body(
      hasScrollBody: true,
      title: context.l10n.channelWizardScreenTitle,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _handleCloseTap,
      ),
      actions: [
        IconButton(
          icon: Icon(stepHelp.icon, color: stepHelp.color),
          onPressed: _showStepHelp,
          tooltip: context.l10n.channelWizardHelpTooltip,
        ),
      ],
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            // Progress indicator
            _buildProgressIndicator(),
            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildNameStep(theme),
                  _buildPrivacyStep(theme),
                  _buildOptionsStep(theme),
                  _buildCompleteStep(theme),
                ],
              ),
            ),
            // Navigation buttons
            if (!_saveComplete) _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final isActive = index <= _currentStep;
          final isComplete = index < _currentStep;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isComplete
                        ? AppTheme.successGreen
                        : isActive
                        ? context.accentColor
                        : context.surface,
                    border: isActive && !isComplete
                        ? Border.all(color: context.accentColor, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: isComplete
                        ? Icon(Icons.check, size: 16, color: Colors.white)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isActive
                                  ? Colors.white
                                  : context.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                  ),
                ),
                if (index < _totalSteps - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: isComplete
                          ? AppTheme.successGreen
                          : context.surface,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNameStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.edit, size: 48, color: context.accentColor),
          SizedBox(height: AppTheme.spacing24),
          Text(
            context.l10n.channelWizardNameHeading,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            context.l10n.channelWizardNameSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
          SizedBox(height: AppTheme.spacing32),
          TextField(
            controller: _nameController,
            style: TextStyle(color: context.textPrimary),
            maxLength: maxChannelNameLength,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_\-]')),
            ],
            decoration: InputDecoration(
              labelText: context.l10n.channelWizardNameLabel,
              labelStyle: TextStyle(color: context.textSecondary),
              hintText: context.l10n.channelWizardNameHint,
              hintStyle: TextStyle(color: context.textSecondary.withAlpha(128)),
              filled: true,
              fillColor: context.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                borderSide: BorderSide(color: context.accentColor, width: 2),
              ),
              counterStyle: TextStyle(
                color: context.textSecondary,
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppTheme.spacing16),
          StatusBanner.info(
            title: context.l10n.channelWizardNameBannerInfo,
            margin: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.security, size: 48, color: AppTheme.primaryPurple),
          const SizedBox(height: AppTheme.spacing24),
          Text(
            context.l10n.channelWizardPrivacyHeading,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            context.l10n.channelWizardPrivacySubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),
          Column(
            children: PrivacyLevel.values
                .map((level) => _buildPrivacyOption(level, theme))
                .toList(),
          ),
          const SizedBox(height: AppTheme.spacing24),
          _buildCompatibilityInfo(theme),
        ],
      ),
    );
  }

  Widget _buildPrivacyOption(PrivacyLevel level, ThemeData theme) {
    final isSelected = _privacyLevel == level;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _privacyLevel = level;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(AppTheme.spacing16),
        decoration: BoxDecoration(
          color: isSelected ? level.color.withAlpha(26) : context.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(
            color: isSelected ? level.color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: level.color.withAlpha(51),
                borderRadius: BorderRadius.circular(AppTheme.radius12),
              ),
              child: Icon(level.icon, color: level.color),
            ),
            SizedBox(width: AppTheme.spacing16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        level.title(context.l10n),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacing8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: level.color.withAlpha(51),
                          borderRadius: BorderRadius.circular(AppTheme.radius4),
                        ),
                        child: Text(
                          level.keySize.displayName(context.l10n),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: level.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacing4),
                  Text(
                    level.description(context.l10n),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: AppTheme.spacing12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? level.color : context.textTertiary,
                  width: 2,
                ),
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSelected ? 12 : 0,
                  height: isSelected ? 12 : 0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? level.color : Colors.transparent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompatibilityInfo(ThemeData theme) {
    String compatibilityText;
    IconData compatibilityIcon;
    Color compatibilityColor;

    switch (_privacyLevel) {
      case PrivacyLevel.open:
        compatibilityText = context.l10n.channelWizardCompatOpen;
        compatibilityIcon = Icons.check_circle;
        compatibilityColor = AppTheme.successGreen;
        break;
      case PrivacyLevel.shared:
        compatibilityText = context.l10n.channelWizardCompatShared;
        compatibilityIcon = Icons.warning;
        compatibilityColor = AppTheme.warningYellow;
        break;
      case PrivacyLevel.private:
        compatibilityText = context.l10n.channelWizardCompatPrivate;
        compatibilityIcon = Icons.recommend;
        compatibilityColor = AppTheme.successGreen;
        break;
      case PrivacyLevel.maximum:
        compatibilityText = context.l10n.channelWizardCompatMax;
        compatibilityIcon = Icons.verified_user;
        compatibilityColor = AppTheme.primaryPurple;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: compatibilityColor.withAlpha(26),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(color: compatibilityColor.withAlpha(77)),
      ),
      child: Row(
        children: [
          Icon(compatibilityIcon, color: compatibilityColor, size: 20),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Text(
              compatibilityText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: compatibilityColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tune, size: 48, color: AppTheme.primaryBlue),
          const SizedBox(height: AppTheme.spacing24),
          Text(
            context.l10n.channelWizardOptionsHeading,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            context.l10n.channelWizardOptionsSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing32),
          // Encryption key section (only for private/maximum)
          if (_keyFieldVisible) ...[
            const SizedBox(height: AppTheme.spacing12),
            ChannelKeyField(
              controller: _keyController,
              keyBase64: _keyController.text,
              onKeyChanged: (newKey) {
                final decoded = ChannelKeyUtils.base64ToKey(newKey);
                if (decoded != null &&
                    decoded.length == _privacyLevel.keySize.bytes) {
                  setState(() {
                    _generatedKey = decoded;
                    _keyCommitError = null;
                  });
                  AppLogging.channels(
                    'wizard key commit: source=field_change '
                    'byteLength=${decoded.length} valid=true '
                    'pskFp=${AppLogging.pskFingerprint(_generatedKey)}',
                  );
                }
              },
              expectedKeyBytes: _privacyLevel.keySize.bytes,
              accentColor: _privacyLevel.color,
            ),
            if (_keyCommitError != null) ...[
              const SizedBox(height: AppTheme.spacing8),
              Text(
                _keyCommitError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.errorRed,
                ),
              ),
            ],
            const SizedBox(height: AppTheme.spacing24),
          ],
          // Position setting (doesn't require MQTT)
          _buildToggleOption(
            theme: theme,
            title: context.l10n.channelWizardPositionTitle,
            subtitle: context.l10n.channelWizardPositionSubtitle,
            value: _positionEnabled,
            onChanged: (value) {
              setState(() {
                _positionEnabled = value;
              });
            },
          ),
          SizedBox(height: AppTheme.spacing24),
          // MQTT section header
          Row(
            children: [
              Icon(Icons.cloud_outlined, size: 16, color: context.textTertiary),
              SizedBox(width: AppTheme.spacing8),
              Text(
                context.l10n.channelWizardMqttHeader,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: context.textTertiary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          _buildToggleOption(
            theme: theme,
            title: context.l10n.channelWizardUplinkTitle,
            subtitle: context.l10n.channelWizardUplinkSubtitle,
            value: _uplinkEnabled,
            onChanged: (value) {
              setState(() {
                _uplinkEnabled = value;
              });
            },
          ),
          const SizedBox(height: AppTheme.spacing16),
          _buildToggleOption(
            theme: theme,
            title: context.l10n.channelWizardDownlinkTitle,
            subtitle: context.l10n.channelWizardDownlinkSubtitle,
            value: _downlinkEnabled,
            onChanged: (value) {
              setState(() {
                _downlinkEnabled = value;
              });
            },
          ),
          if (_uplinkEnabled || _downlinkEnabled) ...[
            const SizedBox(height: AppTheme.spacing16),
            StatusBanner.warning(
              title: context.l10n.channelWizardMqttWarning,
              margin: EdgeInsets.zero,
            ),
            const SizedBox(height: AppTheme.spacing12),
            StatusBanner.info(
              title: context.l10n.channelWizardMqttFloodWarning,
              margin: EdgeInsets.zero,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToggleOption({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: AppTheme.spacing4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: AppTheme.spacing16),
          ThemedSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildCompleteStep(ThemeData theme) {
    if (_isSaving && !_saveComplete) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LoadingIndicator(size: 64),
            SizedBox(height: AppTheme.spacing24),
            Text(
              context.l10n.channelWizardCreating,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_saveComplete) {
      final channelUrl = _generateChannelUrl();

      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: AppTheme.successGreen),
            const SizedBox(height: AppTheme.spacing24),
            Text(
              context.l10n.channelWizardCreatedHeading,
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              context.l10n.channelWizardCreatedSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppTheme.spacing32),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radius16),
              ),
              child: BrandedQrCode(data: channelUrl, size: 200),
            ),
            const SizedBox(height: AppTheme.spacing24),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(AppTheme.radius12),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(
                    theme,
                    context.l10n.channelWizardSummaryName,
                    _nameController.text,
                  ),
                  Divider(color: context.border.withAlpha(128)),
                  _buildSummaryRow(
                    theme,
                    context.l10n.channelWizardSummaryPrivacy,
                    _privacyLevel.title(context.l10n),
                  ),
                  Divider(color: context.border.withAlpha(128)),
                  _buildSummaryRow(
                    theme,
                    context.l10n.channelWizardSummaryEncryption,
                    _privacyLevel.keySize.displayName(context.l10n),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacing24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: channelUrl));
                      showSuccessSnackBar(
                        context,
                        context.l10n.channelWizardUrlCopied,
                      );
                    },
                    icon: Icon(Icons.copy),
                    label: Text(context.l10n.channelWizardCopyUrlButton),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.accentColor,
                      side: BorderSide(color: context.accentColor),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                SizedBox(width: AppTheme.spacing16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.check),
                    label: Text(context.l10n.channelWizardDoneButton),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Preview step before saving
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.preview, size: 48, color: AppTheme.successGreen),
          const SizedBox(height: AppTheme.spacing24),
          Text(
            context.l10n.channelWizardReviewHeading,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            context.l10n.channelWizardReviewSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
          SizedBox(height: AppTheme.spacing32),
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            child: Column(
              children: [
                _buildSummaryRow(
                  theme,
                  context.l10n.channelWizardReviewName,
                  _nameController.text,
                ),
                Divider(color: context.border.withAlpha(128)),
                _buildSummaryRow(
                  theme,
                  context.l10n.channelWizardReviewPrivacyLevel,
                  _privacyLevel.title(context.l10n),
                ),
                Divider(color: context.border.withAlpha(128)),
                _buildSummaryRow(
                  theme,
                  context.l10n.channelWizardReviewEncryption,
                  _privacyLevel.keySize.displayName(context.l10n),
                ),
                Divider(color: context.border.withAlpha(128)),
                _buildSummaryRow(
                  theme,
                  context.l10n.channelWizardReviewKeySize,
                  _privacyLevel.keySize.bytes == 0
                      ? context.l10n.channelWizardNoKey
                      : _privacyLevel.keySize.bytes == 1
                      ? context.l10n.channelWizardDefaultKey
                      : context.l10n.channelWizardKeyBits(
                          _privacyLevel.keySize.bytes * 8,
                        ),
                ),
                if (_privacyLevel.keySize.bytes > 1) ...[
                  Divider(color: context.border.withAlpha(128)),
                  _buildKeyRow(theme),
                ],
                Divider(color: context.border.withAlpha(128)),
                _buildSummaryRow(
                  theme,
                  context.l10n.channelWizardReviewMqttUplink,
                  _uplinkEnabled
                      ? context.l10n.channelWizardEnabled
                      : context.l10n.channelWizardDisabled,
                ),
                Divider(color: context.border.withAlpha(128)),
                _buildSummaryRow(
                  theme,
                  context.l10n.channelWizardReviewMqttDownlink,
                  _downlinkEnabled
                      ? context.l10n.channelWizardEnabled
                      : context.l10n.channelWizardDisabled,
                ),
                Divider(color: context.border.withAlpha(128)),
                _buildSummaryRow(
                  theme,
                  context.l10n.channelWizardReviewPositionSharing,
                  _positionEnabled
                      ? context.l10n.channelWizardEnabled
                      : context.l10n.channelWizardDisabled,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing12),
            decoration: BoxDecoration(
              color: _privacyLevel.color.withAlpha(26),
              borderRadius: BorderRadius.circular(AppTheme.radius8),
              border: Border.all(color: _privacyLevel.color.withAlpha(77)),
            ),
            child: Row(
              children: [
                Icon(_privacyLevel.icon, color: _privacyLevel.color, size: 20),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Text(
                    _privacyLevel.description(context.l10n),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _privacyLevel.color,
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

  Widget _buildSummaryRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
          Text(
            value.isEmpty ? '-' : value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyRow(ThemeData theme) {
    final keyBase64 = ChannelKeyUtils.keyToBase64(_generatedKey);
    AppLogging.channels(
      'wizard review key: byteLength=${_generatedKey.length} '
      'pskFp=${AppLogging.pskFingerprint(_generatedKey)}',
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            context.l10n.channelWizardEncryptionKeyLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              keyBase64.isNotEmpty
                  ? '${keyBase64.substring(0, keyBase64.length.clamp(0, 8))}…'
                  : '-',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.textPrimary,
                fontWeight: FontWeight.w600,
                fontFamily: AppTheme.fontFamily,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    bool canProceed;
    switch (_currentStep) {
      case 0:
        canProceed = _nameController.text.trim().isNotEmpty;
        break;
      case 2:
      case 3:
        canProceed = _isEncryptionKeyValid();
        break;
      default:
        canProceed = true;
    }

    return BottomActionBar(
      horizontalPadding: AppTheme.spacing24,
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: context.border),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(context.l10n.channelWizardBackButton),
              ),
            ),
          if (_currentStep > 0) SizedBox(width: AppTheme.spacing16),
          Expanded(
            child: FilledButton(
              onPressed: canProceed
                  ? () {
                      FocusScope.of(context).unfocus();
                      if (_currentStep == _totalSteps - 1) {
                        _saveChannel();
                      } else {
                        _nextStep();
                      }
                    }
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: context.accentColor,
                disabledBackgroundColor: context.accentColor.withAlpha(77),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                _currentStep == _totalSteps - 1
                    ? context.l10n.channelWizardCreateButton
                    : context.l10n.channelWizardContinueButton,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
