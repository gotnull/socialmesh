// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../generated/meshtastic/admin.pbenum.dart' as admin_pbenum;
import '../../generated/meshtastic/module_config.pb.dart' as module_pb;
import '../../services/protocol/admin_target.dart';
import '../../providers/app_providers.dart';
import '../../providers/countdown_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/status_banner.dart';

/// Screen for configuring External Notification module (buzzers, LEDs, vibration)
class ExternalNotificationConfigScreen extends ConsumerStatefulWidget {
  const ExternalNotificationConfigScreen({super.key});

  @override
  ConsumerState<ExternalNotificationConfigScreen> createState() =>
      _ExternalNotificationConfigScreenState();
}

class _ExternalNotificationConfigScreenState
    extends ConsumerState<ExternalNotificationConfigScreen>
    with LifecycleSafeMixin {
  // Core settings
  bool _enabled = false;
  bool _alertBell = false;
  bool _alertMessage = false;
  bool _usePwm = false;
  bool _useI2sAsBuzzer = false;

  // Primary GPIO settings
  bool _active = false;
  int _output = 0;
  int _outputMs = 0;
  int _nagTimeout = 0;

  // Optional GPIO settings
  bool _alertBellBuzzer = false;
  bool _alertBellVibra = false;
  bool _alertMessageBuzzer = false;
  bool _alertMessageVibra = false;
  int _outputBuzzer = 0;
  int _outputVibra = 0;

  bool _isSaving = false;
  bool _isLoading = true;
  StreamSubscription<module_pb.ModuleConfig_ExternalNotificationConfig>?
  _configSubscription;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _configSubscription?.cancel();
    super.dispose();
  }

  void _applyConfig(module_pb.ModuleConfig_ExternalNotificationConfig config) {
    safeSetState(() {
      _enabled = config.enabled;
      _alertBell = config.alertBell;
      _alertMessage = config.alertMessage;
      _usePwm = config.usePwm;
      _useI2sAsBuzzer = config.useI2sAsBuzzer;
      _active = config.active;
      _output = config.output;
      _outputMs = config.outputMs;
      _nagTimeout = config.nagTimeout;
      _alertBellBuzzer = config.alertBellBuzzer;
      _alertBellVibra = config.alertBellVibra;
      _alertMessageBuzzer = config.alertMessageBuzzer;
      _alertMessageVibra = config.alertMessageVibra;
      _outputBuzzer = config.outputBuzzer;
      _outputVibra = config.outputVibra;
      _isLoading = false;
    });
  }

  Future<void> _loadCurrentConfig() async {
    final l10n = context.l10n;
    AppLogging.settings('[ExternalNotification] Loading config...');
    try {
      final protocol = ref.read(protocolServiceProvider);
      final target = AdminTarget.fromNullable(
        ref.read(remoteAdminTargetProvider),
      );

      // Apply cached config immediately if available (local only)
      if (target.isLocal) {
        final cached = protocol.currentExternalNotificationConfig;
        if (cached != null) {
          AppLogging.settings('[ExternalNotification] Applying cached config');
          _applyConfig(cached);
        }
      }

      // Only request from device if connected
      if (protocol.isConnected) {
        // Listen for config response
        _configSubscription = protocol.externalNotificationConfigStream.listen((
          config,
        ) {
          if (mounted) {
            AppLogging.settings(
              '[ExternalNotification] Config received via stream',
            );
            _applyConfig(config);
          }
        });

        // Request fresh config from device
        AppLogging.settings(
          '[ExternalNotification] Requesting config from device',
        );
        await protocol.getModuleConfig(
          admin_pbenum.AdminMessage_ModuleConfigType.EXTNOTIF_CONFIG,
          target: target,
        );
      } else {
        AppLogging.settings(
          '[ExternalNotification] Not connected, skipping load',
        );
      }
    } catch (e) {
      AppLogging.settings('[ExternalNotification] Error loading config: $e');
      safeShowSnackBar(l10n.extNotifLoadFailed);
    } finally {
      safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    final l10n = context.l10n;
    safeSetState(() => _isSaving = true);

    try {
      final protocol = ref.read(protocolServiceProvider);
      final target = AdminTarget.fromNullable(
        ref.read(remoteAdminTargetProvider),
      );

      // Create the external notification config
      final extNotifConfig = module_pb.ModuleConfig_ExternalNotificationConfig()
        ..enabled = _enabled
        ..alertBell = _alertBell
        ..alertMessage = _alertMessage
        ..usePwm = _usePwm
        ..useI2sAsBuzzer = _useI2sAsBuzzer
        ..active = _active
        ..output = _output
        ..outputMs = _outputMs
        ..nagTimeout = _nagTimeout
        ..alertBellBuzzer = _alertBellBuzzer
        ..alertBellVibra = _alertBellVibra
        ..alertMessageBuzzer = _alertMessageBuzzer
        ..alertMessageVibra = _alertMessageVibra
        ..outputBuzzer = _outputBuzzer
        ..outputVibra = _outputVibra;

      final moduleConfig = module_pb.ModuleConfig()
        ..externalNotification = extNotifConfig;

      await protocol.setModuleConfig(moduleConfig, target: target);

      if (mounted) {
        showSuccessSnackBar(context, l10n.extNotifSaved);
        if (target.isLocal) {
          ref
              .read(countdownProvider.notifier)
              .startDeviceRebootCountdown(
                reason: 'external notification config saved',
              );
        }
        safeNavigatorPop();
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, l10n.extNotifSaveFailed(e.toString()));
      }
    } finally {
      safeSetState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final protocol = ref.watch(protocolServiceProvider);
    final isConnected = protocol.isConnected;

    return GlassScaffold(
      title: context.l10n.extNotifTitle,
      actions: [
        if (isConnected)
          TextButton(
            onPressed: _isSaving ? null : _saveConfig,
            child: _isSaving
                ? LoadingIndicator(size: 20)
                : Text(
                    context.l10n.extNotifSave,
                    style: TextStyle(color: context.accentColor),
                  ),
          ),
      ],
      slivers: [
        if (_isLoading)
          const SliverFillRemaining(child: ScreenLoadingIndicator())
        else ...[
          SliverPadding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (!isConnected)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: StatusBanner.warning(
                      title: context.l10n.extNotifNotConnected,
                      margin: EdgeInsets.zero,
                    ),
                  ),

                // Options Section
                _buildSectionHeader(
                  context,
                  context.l10n.extNotifSectionOptions,
                ),
                _buildCard([
                  _buildSwitch(
                    context,
                    title: context.l10n.extNotifEnabled,
                    subtitle: context.l10n.extNotifEnabledSubtitle,
                    value: _enabled,
                    icon: Icons.notifications_active,
                    onChanged: isConnected
                        ? (v) => setState(() => _enabled = v)
                        : null,
                  ),
                  _buildDivider(),
                  _buildSwitch(
                    context,
                    title: context.l10n.extNotifAlertOnBell,
                    subtitle: context.l10n.extNotifAlertOnBellSubtitle,
                    value: _alertBell,
                    icon: Icons.notifications,
                    onChanged: isConnected
                        ? (v) => setState(() => _alertBell = v)
                        : null,
                  ),
                  _buildDivider(),
                  _buildSwitch(
                    context,
                    title: context.l10n.extNotifAlertOnMessage,
                    subtitle: context.l10n.extNotifAlertOnMessageSubtitle,
                    value: _alertMessage,
                    icon: Icons.message,
                    onChanged: isConnected
                        ? (v) => setState(() => _alertMessage = v)
                        : null,
                  ),
                  _buildDivider(),
                  _buildSwitch(
                    context,
                    title: context.l10n.extNotifUsePwm,
                    subtitle: context.l10n.extNotifUsePwmSubtitle,
                    value: _usePwm,
                    icon: Icons.music_note,
                    onChanged: isConnected
                        ? (v) => setState(() => _usePwm = v)
                        : null,
                  ),
                  _buildDivider(),
                  _buildSwitch(
                    context,
                    title: context.l10n.extNotifUseI2s,
                    subtitle: context.l10n.extNotifUseI2sSubtitle,
                    value: _useI2sAsBuzzer,
                    icon: Icons.speaker,
                    onChanged: isConnected
                        ? (v) => setState(() => _useI2sAsBuzzer = v)
                        : null,
                  ),
                ]),

                const SizedBox(height: AppTheme.spacing24),

                // Primary GPIO Section
                _buildSectionHeader(
                  context,
                  context.l10n.extNotifSectionPrimaryGpio,
                ),
                _buildCard([
                  _buildSwitch(
                    context,
                    title: context.l10n.extNotifActiveHigh,
                    subtitle: context.l10n.extNotifActiveHighSubtitle,
                    value: _active,
                    icon: Icons.power,
                    onChanged: isConnected
                        ? (v) => setState(() => _active = v)
                        : null,
                  ),
                  _buildDivider(),
                  _buildGpioPicker(
                    context,
                    title: context.l10n.extNotifOutputGpioPin,
                    value: _output,
                    onChanged: isConnected
                        ? (v) => setState(() => _output = v)
                        : null,
                  ),
                  _buildDivider(),
                  _buildDurationPicker(
                    context,
                    title: context.l10n.extNotifOutputDuration,
                    subtitle: context.l10n.extNotifOutputDurationSubtitle,
                    valueMs: _outputMs,
                    onChanged: isConnected
                        ? (v) => setState(() => _outputMs = v)
                        : null,
                  ),
                  _buildDivider(),
                  _buildNagTimeoutPicker(
                    context,
                    title: context.l10n.extNotifNagTimeout,
                    subtitle: context.l10n.extNotifNagTimeoutSubtitle,
                    valueSecs: _nagTimeout,
                    onChanged: isConnected
                        ? (v) => setState(() => _nagTimeout = v)
                        : null,
                  ),
                ]),

                const SizedBox(height: AppTheme.spacing24),

                // Optional GPIO Section
                _buildSectionHeader(
                  context,
                  context.l10n.extNotifSectionOptionalGpio,
                ),
                _buildCard([
                  _buildSwitch(
                    context,
                    title: context.l10n.extNotifBuzzerOnBell,
                    subtitle: context.l10n.extNotifBuzzerOnBellSubtitle,
                    value: _alertBellBuzzer,
                    icon: Icons.volume_up,
                    onChanged: isConnected
                        ? (v) => setState(() => _alertBellBuzzer = v)
                        : null,
                  ),
                  _buildDivider(),
                  _buildSwitch(
                    context,
                    title: context.l10n.extNotifVibraOnBell,
                    subtitle: context.l10n.extNotifVibraOnBellSubtitle,
                    value: _alertBellVibra,
                    icon: Icons.vibration,
                    onChanged: isConnected
                        ? (v) => setState(() => _alertBellVibra = v)
                        : null,
                  ),
                  _buildDivider(),
                  _buildSwitch(
                    context,
                    title: context.l10n.extNotifBuzzerOnMsg,
                    subtitle: context.l10n.extNotifBuzzerOnMsgSubtitle,
                    value: _alertMessageBuzzer,
                    icon: Icons.volume_up,
                    onChanged: isConnected
                        ? (v) => setState(() => _alertMessageBuzzer = v)
                        : null,
                  ),
                  _buildDivider(),
                  _buildSwitch(
                    context,
                    title: context.l10n.extNotifVibraOnMsg,
                    subtitle: context.l10n.extNotifVibraOnMsgSubtitle,
                    value: _alertMessageVibra,
                    icon: Icons.vibration,
                    onChanged: isConnected
                        ? (v) => setState(() => _alertMessageVibra = v)
                        : null,
                  ),
                  _buildDivider(),
                  _buildGpioPicker(
                    context,
                    title: context.l10n.extNotifBuzzerGpioPin,
                    value: _outputBuzzer,
                    onChanged: isConnected
                        ? (v) => setState(() => _outputBuzzer = v)
                        : null,
                  ),
                  _buildDivider(),
                  _buildGpioPicker(
                    context,
                    title: context.l10n.extNotifVibraGpioPin,
                    value: _outputVibra,
                    onChanged: isConnected
                        ? (v) => setState(() => _outputVibra = v)
                        : null,
                  ),
                ]),

                const SizedBox(height: AppTheme.spacing32),
              ]),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: context.accentColor, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(color: context.border),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, indent: 56, color: context.border);
  }

  Widget _buildSwitch(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required ValueChanged<bool>? onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: context.textSecondary, fontSize: 12),
      ),
      leading: Icon(icon, color: context.accentColor),
      trailing: ThemedSwitch(value: value, onChanged: onChanged),
    );
  }

  Widget _buildGpioPicker(
    BuildContext context, {
    required String title,
    required int value,
    required ValueChanged<int>? onChanged,
  }) {
    return ListTile(
      leading: Icon(Icons.memory, color: context.accentColor),
      title: Text(title),
      subtitle: Text(
        value == 0
            ? context.l10n.extNotifGpioUnset
            : context.l10n.extNotifGpioValue(value),
        style: TextStyle(color: context.textSecondary),
      ),
      trailing: DropdownButton<int>(
        value: value,
        underline: const SizedBox(),
        items: List.generate(49, (i) => i).map((pin) {
          return DropdownMenuItem<int>(
            value: pin,
            child: Text(
              pin == 0
                  ? context.l10n.extNotifGpioUnset
                  : context.l10n.extNotifGpioPinLabel(pin),
            ),
          );
        }).toList(),
        onChanged: onChanged == null ? null : (v) => onChanged(v ?? 0),
      ),
    );
  }

  Widget _buildDurationPicker(
    BuildContext context, {
    required String title,
    required String subtitle,
    required int valueMs,
    required ValueChanged<int>? onChanged,
  }) {
    final durations = [
      (0, context.l10n.extNotifDurationDefault),
      (100, context.l10n.extNotifDuration100ms),
      (250, context.l10n.extNotifDuration250ms),
      (500, context.l10n.extNotifDuration500ms),
      (1000, context.l10n.extNotifDuration1s),
      (2000, context.l10n.extNotifDuration2s),
      (5000, context.l10n.extNotifDuration5s),
    ];

    return ListTile(
      leading: Icon(Icons.timer, color: context.accentColor),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: context.textSecondary, fontSize: 12),
      ),
      trailing: DropdownButton<int>(
        value: durations.any((d) => d.$1 == valueMs) ? valueMs : 0,
        underline: const SizedBox(),
        items: durations.map((d) {
          return DropdownMenuItem<int>(value: d.$1, child: Text(d.$2));
        }).toList(),
        onChanged: onChanged == null ? null : (v) => onChanged(v ?? 0),
      ),
    );
  }

  Widget _buildNagTimeoutPicker(
    BuildContext context, {
    required String title,
    required String subtitle,
    required int valueSecs,
    required ValueChanged<int>? onChanged,
  }) {
    final timeouts = [
      (0, context.l10n.extNotifTimeoutDisabled),
      (15, context.l10n.extNotifTimeout15s),
      (30, context.l10n.extNotifTimeout30s),
      (60, context.l10n.extNotifTimeout1m),
      (120, context.l10n.extNotifTimeout2m),
      (300, context.l10n.extNotifTimeout5m),
      (600, context.l10n.extNotifTimeout10m),
    ];

    return ListTile(
      leading: Icon(Icons.repeat, color: context.accentColor),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: context.textSecondary, fontSize: 12),
      ),
      trailing: DropdownButton<int>(
        value: timeouts.any((t) => t.$1 == valueSecs) ? valueSecs : 0,
        underline: const SizedBox(),
        items: timeouts.map((t) {
          return DropdownMenuItem<int>(value: t.$1, child: Text(t.$2));
        }).toList(),
        onChanged: onChanged == null ? null : (v) => onChanged(v ?? 0),
      ),
    );
  }
}
