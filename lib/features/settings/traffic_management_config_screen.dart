// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/settings_primitives.dart';
import '../../providers/app_providers.dart';
import '../../providers/countdown_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';
import '../../generated/meshtastic/module_config.pb.dart' as module_pb;
import '../../generated/meshtastic/admin.pbenum.dart' as admin_pbenum;
import '../../services/protocol/admin_target.dart';

/// Screen for configuring the traffic management module.
///
/// Firmware 2.8 dropped the module's boolean switches: every feature is
/// now a single numeric field where a non-zero value means enabled and
/// zero means off. The switches on this screen are a presentation layer
/// over that rule - turning a feature off writes zero, turning it on
/// restores the last value shown on its slider.
class TrafficManagementConfigScreen extends ConsumerStatefulWidget {
  const TrafficManagementConfigScreen({super.key});

  @override
  ConsumerState<TrafficManagementConfigScreen> createState() =>
      _TrafficManagementConfigScreenState();
}

class _TrafficManagementConfigScreenState
    extends ConsumerState<TrafficManagementConfigScreen>
    with LifecycleSafeMixin {
  static const int _defaultPositionMinIntervalSecs = 60;
  static const int _defaultNodeinfoMaxHops = 3;
  static const int _defaultRateLimitWindowSecs = 60;
  static const int _defaultRateLimitMaxPackets = 10;
  static const int _defaultUnknownPacketThreshold = 5;

  bool _isLoading = false;
  bool _isSaving = false;

  // Position deduplication: suppression window, 0 = off.
  bool _positionDedupEnabled = false;
  int _positionMinIntervalSecs = _defaultPositionMinIntervalSecs;

  // NodeInfo direct response: max hop distance served from cache, 0 = off.
  bool _nodeinfoDirectResponse = false;
  int _nodeinfoDirectResponseMaxHops = _defaultNodeinfoMaxHops;

  // Per-node rate limiting: window and packet budget, either 0 = off.
  bool _rateLimitEnabled = false;
  int _rateLimitWindowSecs = _defaultRateLimitWindowSecs;
  int _rateLimitMaxPackets = _defaultRateLimitMaxPackets;

  // Unknown packet handling: drop threshold, 0 = off.
  bool _dropUnknownEnabled = false;
  int _unknownPacketThreshold = _defaultUnknownPacketThreshold;

  StreamSubscription<module_pb.ModuleConfig_TrafficManagementConfig>?
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

  void _applyConfig(module_pb.ModuleConfig_TrafficManagementConfig config) {
    safeSetState(() {
      _positionDedupEnabled = config.positionMinIntervalSecs > 0;
      _positionMinIntervalSecs = config.positionMinIntervalSecs > 0
          ? config.positionMinIntervalSecs
          : _defaultPositionMinIntervalSecs;
      _nodeinfoDirectResponse = config.nodeinfoDirectResponseMaxHops > 0;
      _nodeinfoDirectResponseMaxHops = config.nodeinfoDirectResponseMaxHops > 0
          ? config.nodeinfoDirectResponseMaxHops
          : _defaultNodeinfoMaxHops;
      _rateLimitEnabled =
          config.rateLimitWindowSecs > 0 && config.rateLimitMaxPackets > 0;
      _rateLimitWindowSecs = config.rateLimitWindowSecs > 0
          ? config.rateLimitWindowSecs
          : _defaultRateLimitWindowSecs;
      _rateLimitMaxPackets = config.rateLimitMaxPackets > 0
          ? config.rateLimitMaxPackets
          : _defaultRateLimitMaxPackets;
      _dropUnknownEnabled = config.unknownPacketThreshold > 0;
      _unknownPacketThreshold = config.unknownPacketThreshold > 0
          ? config.unknownPacketThreshold
          : _defaultUnknownPacketThreshold;
    });
  }

  Future<void> _loadCurrentConfig() async {
    safeSetState(() => _isLoading = true);
    try {
      final protocol = ref.read(protocolServiceProvider);
      final target = AdminTarget.fromNullable(
        ref.read(remoteAdminTargetProvider),
      );

      // Apply cached config immediately if available (local only)
      if (target.isLocal) {
        final cached = protocol.currentTrafficManagementConfig;
        if (cached != null) {
          _applyConfig(cached);
        }
      }

      // Only request from device if connected
      if (protocol.isConnected) {
        _configSubscription = protocol.trafficManagementConfigStream.listen((
          config,
        ) {
          if (mounted) _applyConfig(config);
        });

        await protocol.getModuleConfig(
          admin_pbenum.AdminMessage_ModuleConfigType.TRAFFICMANAGEMENT_CONFIG,
          target: target,
        );
      }
    } catch (e) {
      AppLogging.protocol('Traffic management config load aborted: $e');
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
      await protocol.setTrafficManagementConfig(
        positionMinIntervalSecs: _positionDedupEnabled
            ? _positionMinIntervalSecs
            : 0,
        nodeinfoDirectResponseMaxHops: _nodeinfoDirectResponse
            ? _nodeinfoDirectResponseMaxHops
            : 0,
        rateLimitWindowSecs: _rateLimitEnabled ? _rateLimitWindowSecs : 0,
        rateLimitMaxPackets: _rateLimitEnabled ? _rateLimitMaxPackets : 0,
        unknownPacketThreshold: _dropUnknownEnabled
            ? _unknownPacketThreshold
            : 0,
        target: target,
      );

      if (mounted) {
        showSuccessSnackBar(context, l10n.trafficMgmtSaved);
        if (target.isLocal) {
          ref
              .read(countdownProvider.notifier)
              .startDeviceRebootCountdown(
                reason: 'traffic management config saved',
              );
        }
        safeNavigatorPop();
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, l10n.trafficMgmtSaveFailed(e.toString()));
      }
    } finally {
      safeSetState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: context.l10n.trafficMgmtTitle,
      actions: [
        TextButton(
          onPressed: (_isLoading || _isSaving) ? null : _saveConfig,
          child: Text(
            context.l10n.trafficMgmtSave,
            style: TextStyle(
              color: (_isLoading || _isSaving)
                  ? SemanticColors.disabled
                  : context.accentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
      slivers: [
        if (_isLoading)
          const SliverFillRemaining(child: ScreenLoadingIndicator())
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
            sliver: SliverList.list(
              children: [
                SettingsSectionHeader(
                  title: context.l10n.trafficMgmtSectionPositionDedup,
                ),
                ..._buildPositionDedupSection(),
                const SizedBox(height: AppTheme.spacing16),
                SettingsSectionHeader(
                  title: context.l10n.trafficMgmtSectionNodeinfoResponse,
                ),
                ..._buildNodeinfoSection(),
                const SizedBox(height: AppTheme.spacing16),
                SettingsSectionHeader(
                  title: context.l10n.trafficMgmtSectionRateLimit,
                ),
                ..._buildRateLimitSection(),
                const SizedBox(height: AppTheme.spacing16),
                SettingsSectionHeader(
                  title: context.l10n.trafficMgmtSectionUnknownPackets,
                ),
                ..._buildUnknownPacketsSection(),
                const SizedBox(height: AppTheme.spacing32),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SettingsTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      crossAxisAlignment: CrossAxisAlignment.start,
      trailing: ThemedSwitch(
        value: value,
        onChanged: (next) {
          HapticFeedback.selectionClick();
          setState(() => onChanged(next));
        },
      ),
    );
  }

  Widget _sliderLabel(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppTheme.spacing4),
        Text(
          description,
          style: TextStyle(color: context.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _slider({
    required int value,
    required int min,
    required int max,
    required String label,
    required ValueChanged<int> onChanged,
  }) {
    return SliderTheme(
      data: SliderThemeData(
        inactiveTrackColor: SemanticColors.divider,
        thumbColor: context.accentColor,
        overlayColor: context.accentColor.withAlpha(30),
      ),
      // The radio may hold a value outside the slider's range (firmware
      // 2.8 defaults the position window to 18000s against a 600s slider).
      // Show the slider pinned at its nearest end while the label keeps
      // the radio's real value; the stored value only changes when the
      // user moves the slider.
      child: Slider(
        value: value.clamp(min, max).toDouble(),
        min: min.toDouble(),
        max: max.toDouble(),
        divisions: max - min,
        label: label,
        onChanged: (v) => onChanged(v.toInt()),
      ),
    );
  }

  List<Widget> _buildPositionDedupSection() {
    final l10n = context.l10n;
    return [
      _buildToggleTile(
        icon: Icons.filter_alt,
        title: l10n.trafficMgmtPositionDedup,
        subtitle: l10n.trafficMgmtPositionDedupSubtitle,
        value: _positionDedupEnabled,
        onChanged: (value) => _positionDedupEnabled = value,
      ),
      if (_positionDedupEnabled)
        FieldGroupCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sliderLabel(
                l10n.trafficMgmtMinInterval(_positionMinIntervalSecs),
                l10n.trafficMgmtMinIntervalDesc,
              ),
              _slider(
                value: _positionMinIntervalSecs,
                min: 10,
                max: 600,
                label: '${_positionMinIntervalSecs}s', // lint-allow: hardcoded-string
                onChanged: (v) => setState(() => _positionMinIntervalSecs = v),
              ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _buildNodeinfoSection() {
    final l10n = context.l10n;
    return [
      _buildToggleTile(
        icon: Icons.info_outline,
        title: l10n.trafficMgmtDirectResponse,
        subtitle: l10n.trafficMgmtDirectResponseSubtitle,
        value: _nodeinfoDirectResponse,
        onChanged: (value) => _nodeinfoDirectResponse = value,
      ),
      if (_nodeinfoDirectResponse)
        FieldGroupCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sliderLabel(
                l10n.trafficMgmtMaxHops(_nodeinfoDirectResponseMaxHops),
                l10n.trafficMgmtMaxHopsDesc,
              ),
              _slider(
                value: _nodeinfoDirectResponseMaxHops,
                min: 1,
                max: 7,
                label: '$_nodeinfoDirectResponseMaxHops', // lint-allow: hardcoded-string
                onChanged: (v) =>
                    setState(() => _nodeinfoDirectResponseMaxHops = v),
              ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _buildRateLimitSection() {
    final l10n = context.l10n;
    return [
      _buildToggleTile(
        icon: Icons.speed,
        title: l10n.trafficMgmtPerNodeRateLimit,
        subtitle: l10n.trafficMgmtPerNodeRateLimitSubtitle,
        value: _rateLimitEnabled,
        onChanged: (value) => _rateLimitEnabled = value,
      ),
      if (_rateLimitEnabled)
        FieldGroupCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sliderLabel(
                l10n.trafficMgmtWindow(_rateLimitWindowSecs),
                l10n.trafficMgmtWindowDesc,
              ),
              _slider(
                value: _rateLimitWindowSecs,
                min: 10,
                max: 300,
                label:
                    '${_rateLimitWindowSecs}s', // lint-allow: hardcoded-string
                onChanged: (v) => setState(() => _rateLimitWindowSecs = v),
              ),
              Divider(color: context.border),
              const SizedBox(height: AppTheme.spacing8),
              _sliderLabel(
                l10n.trafficMgmtMaxPackets(_rateLimitMaxPackets),
                l10n.trafficMgmtMaxPacketsDesc,
              ),
              _slider(
                value: _rateLimitMaxPackets,
                min: 1,
                max: 50,
                label: '$_rateLimitMaxPackets', // lint-allow: hardcoded-string
                onChanged: (v) => setState(() => _rateLimitMaxPackets = v),
              ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _buildUnknownPacketsSection() {
    final l10n = context.l10n;
    return [
      _buildToggleTile(
        icon: Icons.help_outline,
        title: l10n.trafficMgmtDropUnknown,
        subtitle: l10n.trafficMgmtDropUnknownSubtitle,
        value: _dropUnknownEnabled,
        onChanged: (value) => _dropUnknownEnabled = value,
      ),
      if (_dropUnknownEnabled)
        FieldGroupCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sliderLabel(
                l10n.trafficMgmtThreshold(_unknownPacketThreshold),
                l10n.trafficMgmtThresholdDesc,
              ),
              _slider(
                value: _unknownPacketThreshold,
                min: 1,
                max: 20,
                label:
                    '$_unknownPacketThreshold', // lint-allow: hardcoded-string
                onChanged: (v) => setState(() => _unknownPacketThreshold = v),
              ),
            ],
          ),
        ),
    ];
  }
}
