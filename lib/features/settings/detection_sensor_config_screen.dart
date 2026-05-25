// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';
import '../../providers/app_providers.dart';
import '../../providers/countdown_providers.dart';
import '../../generated/meshtastic/admin.pbenum.dart' as admin_pbenum;
import '../../generated/meshtastic/module_config.pb.dart' as module_pb;
import '../../generated/meshtastic/module_config.pbenum.dart' as module_pbenum;
import '../../services/protocol/admin_target.dart';
import '../../core/widgets/loading_indicator.dart';

/// Screen for configuring Detection Sensor module
class DetectionSensorConfigScreen extends ConsumerStatefulWidget {
  const DetectionSensorConfigScreen({super.key});

  @override
  ConsumerState<DetectionSensorConfigScreen> createState() =>
      _DetectionSensorConfigScreenState();
}

class _DetectionSensorConfigScreenState
    extends ConsumerState<DetectionSensorConfigScreen>
    with LifecycleSafeMixin {
  void _dismissKeyboard() {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
  }

  bool _enabled = false;
  String _name = '';
  int _monitorPin = 0;
  int _minimumBroadcastSecs = 45;
  int _stateBroadcastSecs = 300;
  bool _sendBell = false;
  bool _usePullup = false;
  module_pbenum.ModuleConfig_DetectionSensorConfig_TriggerType _triggerType =
      module_pbenum.ModuleConfig_DetectionSensorConfig_TriggerType.LOGIC_HIGH;

  bool _isSaving = false;
  bool _isLoading = true;
  bool _notificationsEnabled = false; // App-side notification preference
  StreamSubscription<module_pb.ModuleConfig_DetectionSensorConfig>?
  _configSubscription;

  final _nameController = TextEditingController();
  final _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _configSubscription?.cancel();
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _applyConfig(module_pb.ModuleConfig_DetectionSensorConfig config) {
    safeSetState(() {
      _enabled = config.enabled;
      _name = config.name;
      _monitorPin = config.monitorPin;
      _minimumBroadcastSecs = config.minimumBroadcastSecs > 0
          ? config.minimumBroadcastSecs
          : 45;
      _stateBroadcastSecs = config.stateBroadcastSecs > 0
          ? config.stateBroadcastSecs
          : 300;
      _sendBell = config.sendBell;
      _usePullup = config.usePullup;
      _triggerType = config.detectionTriggerType;
      _nameController.text = _name;
      _pinController.text = _monitorPin.toString();
    });
  }

  Future<void> _loadCurrentConfig() async {
    AppLogging.settings('[DetectionSensor] Loading config...');
    try {
      final protocol = ref.read(protocolServiceProvider);
      final target = AdminTarget.fromNullable(
        ref.read(remoteAdminTargetProvider),
      );

      // Load app-side notification preference
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final notifEnabled =
          prefs.getBool('enableDetectionNotifications') ?? false;
      safeSetState(() => _notificationsEnabled = notifEnabled);

      // Apply cached config immediately if available (local only)
      if (target.isLocal) {
        final cached = protocol.currentDetectionSensorConfig;
        if (cached != null) {
          AppLogging.settings('[DetectionSensor] Applying cached config');
          _applyConfig(cached);
        }
      }

      // Only request from device if connected
      if (protocol.isConnected) {
        // Listen for config response
        _configSubscription = protocol.detectionSensorConfigStream.listen((
          config,
        ) {
          if (mounted) {
            AppLogging.settings('[DetectionSensor] Config received via stream');
            _applyConfig(config);
          }
        });

        // Request fresh config from device
        AppLogging.settings('[DetectionSensor] Requesting config from device');
        await protocol.getModuleConfig(
          admin_pbenum.AdminMessage_ModuleConfigType.DETECTIONSENSOR_CONFIG,
          target: target,
        );
      }
    } catch (e) {
      AppLogging.settings('[DetectionSensor] Error loading config: $e');
    } finally {
      safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    safeSetState(() => _isSaving = true);

    try {
      final protocol = ref.read(protocolServiceProvider);
      final target = AdminTarget.fromNullable(
        ref.read(remoteAdminTargetProvider),
      );

      // Create the detection sensor config
      final dsConfig = module_pb.ModuleConfig_DetectionSensorConfig()
        ..enabled = _enabled
        ..name = _name
        ..monitorPin = _monitorPin
        ..minimumBroadcastSecs = _minimumBroadcastSecs
        ..stateBroadcastSecs = _stateBroadcastSecs
        ..sendBell = _sendBell
        ..usePullup = _usePullup
        ..detectionTriggerType = _triggerType;

      final moduleConfig = module_pb.ModuleConfig()..detectionSensor = dsConfig;
      await protocol.setModuleConfig(moduleConfig, target: target);

      if (mounted) {
        showSuccessSnackBar(context, context.l10n.detectionSensorSaveSuccess);
        if (target.isLocal) {
          ref
              .read(countdownProvider.notifier)
              .startDeviceRebootCountdown(
                reason: 'detection sensor config saved',
              );
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          context.l10n.detectionSensorSaveFailed('$e'),
        );
      }
    } finally {
      safeSetState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismissKeyboard,
      child: GlassScaffold(
        title: context.l10n.detectionSensorTitle,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveConfig,
            child: _isSaving
                ? LoadingIndicator(size: 20)
                : Text(
                    context.l10n.detectionSensorSave,
                    style: TextStyle(color: context.accentColor),
                  ),
          ),
        ],
        slivers: [
          if (_isLoading)
            const SliverFillRemaining(child: ScreenLoadingIndicator())
          else
            SliverPadding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Info card
                  _buildInfoCard(),

                  const SizedBox(height: AppTheme.spacing16),

                  // Basic settings
                  _buildSectionTitle(context.l10n.detectionSensorBasicSettings),
                  _buildBasicSettingsCard(),

                  const SizedBox(height: AppTheme.spacing16),

                  // Pin configuration (only shown if enabled)
                  if (_enabled) ...[
                    _buildSectionTitle(context.l10n.detectionSensorPinConfig),
                    _buildPinConfigCard(),

                    const SizedBox(height: AppTheme.spacing16),

                    // Timing settings
                    _buildSectionTitle(context.l10n.detectionSensorTiming),
                    _buildTimingCard(),

                    const SizedBox(height: AppTheme.spacing16),

                    // Client options (app-side settings)
                    _buildSectionTitle(
                      context.l10n.detectionSensorClientOptions,
                    ),
                    _buildClientOptionsCard(),
                  ],
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: context.textTertiary,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: AppTheme.accentOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: AppTheme.accentOrange.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sensors, color: AppTheme.accentOrange, size: 24),
          SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.detectionSensorTitle,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  context.l10n.detectionSensorInfoDescription,
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicSettingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              context.l10n.detectionSensorEnable,
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              context.l10n.detectionSensorEnableSubtitle,
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
            trailing: ThemedSwitch(
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
          ),
          if (_enabled) ...[
            Divider(height: 1, color: context.border),
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: TextField(
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                maxLength: 100,
                controller: _nameController,
                style: TextStyle(color: context.textPrimary),
                decoration: InputDecoration(
                  labelText: context.l10n.detectionSensorName,
                  labelStyle: TextStyle(color: context.textSecondary),
                  hintText: context.l10n.detectionSensorNameHint,
                  hintStyle: TextStyle(
                    color: context.textTertiary.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: context.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  counterText: '',
                ),
                onChanged: (v) => _name = v,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPinConfigCard() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.detectionSensorGpioPin,
                        style: TextStyle(color: context.textPrimary),
                      ),
                      SizedBox(height: AppTheme.spacing4),
                      Text(
                        context.l10n.detectionSensorGpioPinSubtitle,
                        style: TextStyle(
                          color: context.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: TextField(
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    maxLength: 100,
                    controller: _pinController,
                    style: TextStyle(color: context.textPrimary),
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '0', // lint-allow: hardcoded-string
                      hintStyle: TextStyle(
                        color: context.textTertiary.withValues(alpha: 0.5),
                      ),
                      filled: true,
                      fillColor: context.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      counterText: '',
                    ),
                    onChanged: (v) => _monitorPin = int.tryParse(v) ?? 0,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.border),
          ListTile(
            title: Text(
              context.l10n.detectionSensorTriggerType,
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              _getTriggerTypeDescription(_triggerType),
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
            trailing: Icon(
              Icons.keyboard_arrow_down,
              color: context.textSecondary,
            ),
            onTap: () => _showTriggerTypePicker(),
          ),
          Divider(height: 1, color: context.border),
          ListTile(
            title: Text(
              context.l10n.detectionSensorUsePullup,
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              context.l10n.detectionSensorUsePullupSubtitle,
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
            trailing: ThemedSwitch(
              value: _usePullup,
              onChanged: (v) => setState(() => _usePullup = v),
            ),
          ),
          Divider(height: 1, color: context.border),
          ListTile(
            title: Text(
              context.l10n.detectionSensorSendBell,
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              context.l10n.detectionSensorSendBellSubtitle,
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
            trailing: ThemedSwitch(
              value: _sendBell,
              onChanged: (v) => setState(() => _sendBell = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimingCard() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              context.l10n.detectionSensorMinBroadcastInterval,
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              context.l10n.detectionSensorMinBroadcastIntervalSubtitle(
                _minimumBroadcastSecs,
              ),
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.remove, color: context.textSecondary),
                  onPressed: _minimumBroadcastSecs > 15
                      ? () => setState(() => _minimumBroadcastSecs -= 15)
                      : null,
                ),
                Text(
                  '${_minimumBroadcastSecs}s',
                  style: TextStyle(
                    color: context.accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add, color: context.textSecondary),
                  onPressed: _minimumBroadcastSecs < 300
                      ? () => setState(() => _minimumBroadcastSecs += 15)
                      : null,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.border),
          ListTile(
            title: Text(
              context.l10n.detectionSensorStateBroadcastInterval,
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              context.l10n.detectionSensorStateBroadcastIntervalSubtitle(
                _stateBroadcastSecs ~/ 60,
              ),
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.remove, color: context.textSecondary),
                  onPressed: _stateBroadcastSecs > 60
                      ? () => setState(() => _stateBroadcastSecs -= 60)
                      : null,
                ),
                Text(
                  '${_stateBroadcastSecs ~/ 60}m',
                  style: TextStyle(
                    color: context.accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add, color: context.textSecondary),
                  onPressed: _stateBroadcastSecs < 1800
                      ? () => setState(() => _stateBroadcastSecs += 60)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientOptionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.notifications_active,
              color: _notificationsEnabled
                  ? context.accentColor
                  : context.textSecondary,
            ),
            title: Text(
              context.l10n.detectionSensorEnableNotifications,
              style: TextStyle(color: context.textPrimary),
            ),
            subtitle: Text(
              context.l10n.detectionSensorEnableNotificationsSubtitle,
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
            trailing: ThemedSwitch(
              value: _notificationsEnabled,
              onChanged: (value) async {
                safeSetState(() => _notificationsEnabled = value);
                // Save preference immediately
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('enableDetectionNotifications', value);
                AppLogging.settings(
                  '[DetectionSensor] Notifications ${value ? "enabled" : "disabled"}',
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getTriggerTypeDescription(
    module_pbenum.ModuleConfig_DetectionSensorConfig_TriggerType type,
  ) {
    switch (type) {
      case module_pbenum
          .ModuleConfig_DetectionSensorConfig_TriggerType
          .LOGIC_LOW:
        return context.l10n.detectionSensorTriggerLogicLow;
      case module_pbenum
          .ModuleConfig_DetectionSensorConfig_TriggerType
          .LOGIC_HIGH:
        return context.l10n.detectionSensorTriggerLogicHigh;
      case module_pbenum
          .ModuleConfig_DetectionSensorConfig_TriggerType
          .FALLING_EDGE:
        return context.l10n.detectionSensorTriggerFallingEdge;
      case module_pbenum
          .ModuleConfig_DetectionSensorConfig_TriggerType
          .RISING_EDGE:
        return context.l10n.detectionSensorTriggerRisingEdge;
      case module_pbenum
          .ModuleConfig_DetectionSensorConfig_TriggerType
          .EITHER_EDGE_ACTIVE_LOW:
        return context.l10n.detectionSensorTriggerEitherEdgeLow;
      case module_pbenum
          .ModuleConfig_DetectionSensorConfig_TriggerType
          .EITHER_EDGE_ACTIVE_HIGH:
        return context.l10n.detectionSensorTriggerEitherEdgeHigh;
      default:
        return 'Unknown';
    }
  }

  void _showTriggerTypePicker() {
    AppBottomSheet.show<void>(
      context: context,
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Row(
              children: [
                Text(
                  context.l10n.detectionSensorTriggerType,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: context.textTertiary),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.border),
          ...module_pbenum.ModuleConfig_DetectionSensorConfig_TriggerType.values
              .map((type) {
                return ListTile(
                  title: Text(
                    _getTriggerTypeDescription(type),
                    style: TextStyle(
                      color: _triggerType == type
                          ? context.accentColor
                          : context.textPrimary,
                    ),
                  ),
                  trailing: _triggerType == type
                      ? Icon(Icons.check, color: context.accentColor)
                      : null,
                  onTap: () {
                    setState(() => _triggerType = type);
                    Navigator.pop(context);
                  },
                );
              }),
        ],
      ),
    );
  }
}
