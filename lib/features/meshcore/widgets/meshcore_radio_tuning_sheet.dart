// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCore radio tuning sheet (firmware v1.18+). Reads the current values
// over the companion CLI when it opens and sends a "set" only for what the
// user changed. Same shell and field style as the radio settings sheet.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../../../core/widgets/settings_primitives.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../services/meshcore/meshcore_radio_tuning.dart';
import '../../../utils/snackbar.dart';

/// Open the radio tuning sheet for the connected v1.18+ MeshCore radio.
Future<void> showMeshCoreRadioTuningSheet(BuildContext context) {
  return AppBottomSheet.showScrollable<void>(
    context: context,
    initialChildSize: 0.85,
    minChildSize: 0.5,
    maxChildSize: 0.95,
    builder: (controller) =>
        _MeshCoreRadioTuningSheet(scrollController: controller),
  );
}

class _MeshCoreRadioTuningSheet extends ConsumerStatefulWidget {
  const _MeshCoreRadioTuningSheet({required this.scrollController});

  final ScrollController scrollController;

  @override
  ConsumerState<_MeshCoreRadioTuningSheet> createState() =>
      _MeshCoreRadioTuningSheetState();
}

class _MeshCoreRadioTuningSheetState
    extends ConsumerState<_MeshCoreRadioTuningSheet>
    with LifecycleSafeMixin {
  final _formKey = GlobalKey<FormState>();
  final _thresholdController = TextEditingController();
  final _agcController = TextEditingController();
  final _floodController = TextEditingController();
  final _directController = TextEditingController();

  MeshCoreRadioTuning? _loaded;
  bool _cadEnabled = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    _agcController.dispose();
    _floodController.dispose();
    _directController.dispose();
    super.dispose();
  }

  Future<String?> _run(String command) async {
    final session = ref.read(meshCoreSessionProvider);
    if (session == null || !session.isActive) return null;
    return session.runCliCommand(command);
  }

  Future<void> _load() async {
    final tuning = await MeshCoreRadioTuning.read(_run);
    if (!mounted) return;
    safeSetState(() {
      _loading = false;
      _loaded = tuning;
      if (tuning == null) return;
      _cadEnabled = tuning.cadEnabled;
      _thresholdController.text = '${tuning.interferenceThreshold}';
      _agcController.text = '${tuning.agcResetIntervalSecs}';
      _floodController.text = MeshCoreRadioTuning.formatDelay(
        tuning.floodTxDelay,
      );
      _directController.text = MeshCoreRadioTuning.formatDelay(
        tuning.directTxDelay,
      );
    });
  }

  Future<void> _apply() async {
    final loaded = _loaded;
    if (loaded == null || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final l10n = context.l10n;
    final edited = MeshCoreRadioTuning(
      cadEnabled: _cadEnabled,
      interferenceThreshold: int.parse(_thresholdController.text),
      agcResetIntervalSecs: int.parse(_agcController.text),
      floodTxDelay: double.parse(_floodController.text),
      directTxDelay: double.parse(_directController.text),
    );
    final commands = edited.commandsToApply(loaded);
    if (commands.isEmpty) {
      safeNavigatorPop();
      return;
    }

    safeSetState(() => _saving = true);
    for (final command in commands) {
      final reply = await _run(command);
      if (!mounted) return;
      if (!MeshCoreRadioTuning.isOk(reply)) {
        AppLogging.meshcore('event=tuning.rejected cmd="$command"');
        safeSetState(() => _saving = false);
        showErrorSnackBar(
          context,
          l10n.meshcoreTuningRejected(
            _settingLabel(command, l10n),
            reply ?? l10n.meshcoreTuningNoReply,
          ),
        );
        return;
      }
    }
    AppLogging.meshcore('event=tuning.applied count=${commands.length}');
    showSuccessSnackBar(context, l10n.meshcoreTuningApplied);
    safeNavigatorPop();
  }

  String _settingLabel(String command, AppLocalizations l10n) {
    if (command.startsWith('set cad')) return l10n.meshcoreTuningCadTitle;
    if (command.startsWith('set int.thresh')) {
      return l10n.meshcoreTuningInterferenceLabel;
    }
    if (command.startsWith('set agc')) return l10n.meshcoreTuningAgcLabel;
    if (command.startsWith('set direct')) {
      return l10n.meshcoreTuningDirectDelayLabel;
    }
    return l10n.meshcoreTuningFloodDelayLabel;
  }

  String? _validateInt(String? value, int max, AppLocalizations l10n) {
    final n = int.tryParse(value ?? '');
    if (n == null || n < 0 || n > max) {
      return l10n.meshcoreTuningRangeError('0', '$max');
    }
    return null;
  }

  String? _validateAgc(String? value, AppLocalizations l10n) {
    final range = _validateInt(
      value,
      MeshCoreRadioTuning.maxAgcResetIntervalSecs,
      l10n,
    );
    if (range != null) return range;
    return int.parse(value!) % MeshCoreRadioTuning.agcStepSecs == 0
        ? null
        : l10n.meshcoreTuningAgcStepError;
  }

  String? _validateDelay(String? value, AppLocalizations l10n) {
    final d = double.tryParse(value ?? '');
    if (d == null || d < 0 || d > MeshCoreRadioTuning.maxTxDelay) {
      return l10n.meshcoreTuningRangeError(
        '0',
        MeshCoreRadioTuning.formatDelay(MeshCoreRadioTuning.maxTxDelay),
      );
    }
    return null;
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool decimal,
    required FormFieldValidator<String> validator,
    String? helper,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_saving,
      maxLength: 6,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(decimal ? r'[0-9.]' : '[0-9]'),
        ),
      ],
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      style: TextStyle(color: context.textPrimary),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.textSecondary),
        helperText: helper,
        helperMaxLines: 4,
        errorMaxLines: 3,
        filled: true,
        fillColor: context.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius8),
          borderSide: BorderSide(color: context.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius8),
          borderSide: BorderSide(color: context.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius8),
          borderSide: BorderSide(color: context.accentColor),
        ),
        prefixIcon: Icon(icon, color: context.textSecondary),
        counterText: '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Form(
      key: _formKey,
      child: ListView(
        controller: widget.scrollController,
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              AppTheme.spacing8,
              AppTheme.spacing16,
              AppTheme.spacing8,
            ),
            child: Text(
              l10n.meshcoreRadioTuning,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              0,
              AppTheme.spacing16,
              AppTheme.spacing16,
            ),
            child: Text(
              l10n.meshcoreRadioTuningHint,
              style: TextStyle(fontSize: 13, color: context.textTertiary),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(AppTheme.spacing32),
              child: Center(child: LoadingIndicator()),
            )
          else if (_loaded == null)
            StatusBanner.error(
              title: l10n.meshcoreTuningLoadFailed,
              margin: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing16,
              ),
            )
          else ...[
            SettingsSectionHeader(title: l10n.meshcoreTuningChannelHeader),
            SettingsTile(
              icon: Icons.hearing_rounded,
              title: l10n.meshcoreTuningCadTitle,
              subtitle: l10n.meshcoreTuningCadSubtitle,
              crossAxisAlignment: CrossAxisAlignment.start,
              trailing: ThemedSwitch(
                value: _cadEnabled,
                onChanged: _saving
                    ? null
                    : (v) {
                        HapticFeedback.selectionClick();
                        safeSetState(() => _cadEnabled = v);
                      },
              ),
            ),
            FieldGroupCard(
              child: Column(
                children: [
                  _numberField(
                    controller: _thresholdController,
                    label: l10n.meshcoreTuningInterferenceLabel,
                    helper: l10n.meshcoreTuningInterferenceHelper,
                    icon: Icons.graphic_eq_rounded,
                    decimal: false,
                    validator: (v) => _validateInt(
                      v,
                      MeshCoreRadioTuning.maxInterferenceThreshold,
                      l10n,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  _numberField(
                    controller: _agcController,
                    label: l10n.meshcoreTuningAgcLabel,
                    helper: l10n.meshcoreTuningAgcHelper,
                    icon: Icons.timer_outlined,
                    decimal: false,
                    validator: (v) => _validateAgc(v, l10n),
                  ),
                ],
              ),
            ),
            SettingsSectionHeader(title: l10n.meshcoreTuningDelayHeader),
            FieldGroupCard(
              child: Column(
                children: [
                  _numberField(
                    controller: _floodController,
                    label: l10n.meshcoreTuningFloodDelayLabel,
                    icon: Icons.waves_rounded,
                    decimal: true,
                    validator: (v) => _validateDelay(v, l10n),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  _numberField(
                    controller: _directController,
                    label: l10n.meshcoreTuningDirectDelayLabel,
                    helper: l10n.meshcoreTuningDelayHelper,
                    icon: Icons.alt_route_rounded,
                    decimal: true,
                    validator: (v) => _validateDelay(v, l10n),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppTheme.spacing24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : safeNavigatorPop,
                    child: Text(l10n.meshcoreCancel),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: PrimaryGradientButton(
                    label: _saving
                        ? l10n.meshcoreRadioSettingsApplying
                        : l10n.meshcoreRadioSettingsApply,
                    icon: Icons.check_rounded,
                    onPressed: (_saving || _loaded == null) ? null : _apply,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
        ],
      ),
    );
  }
}
