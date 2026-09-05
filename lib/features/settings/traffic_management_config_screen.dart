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
            padding: const EdgeInsets.all(AppTheme.spacing16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SectionHeader(
                  title: context.l10n.trafficMgmtSectionPositionDedup,
                ),
                const SizedBox(height: AppTheme.spacing8),
                _buildPositionDedupSection(),
                const SizedBox(height: AppTheme.spacing24),
                _SectionHeader(
                  title: context.l10n.trafficMgmtSectionNodeinfoResponse,
                ),
                const SizedBox(height: AppTheme.spacing8),
                _buildNodeinfoSection(),
                const SizedBox(height: AppTheme.spacing24),
                _SectionHeader(title: context.l10n.trafficMgmtSectionRateLimit),
                const SizedBox(height: AppTheme.spacing8),
                _buildRateLimitSection(),
                const SizedBox(height: AppTheme.spacing24),
                _SectionHeader(
                  title: context.l10n.trafficMgmtSectionUnknownPackets,
                ),
                const SizedBox(height: AppTheme.spacing8),
                _buildUnknownPacketsSection(),
                const SizedBox(height: AppTheme.spacing32),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _sliderLabel(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppTheme.spacing16),
        Divider(color: context.border),
        const SizedBox(height: AppTheme.spacing8),
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

  Widget _buildPositionDedupSection() {
    return _card(
      children: [
        _SettingsTile(
          icon: Icons.filter_alt,
          title: context.l10n.trafficMgmtPositionDedup,
          subtitle: context.l10n.trafficMgmtPositionDedupSubtitle,
          trailing: ThemedSwitch(
            value: _positionDedupEnabled,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() => _positionDedupEnabled = value);
            },
          ),
        ),
        if (_positionDedupEnabled) ...[
          _sliderLabel(
            context.l10n.trafficMgmtMinInterval(_positionMinIntervalSecs),
            context.l10n.trafficMgmtMinIntervalDesc,
          ),
          _slider(
            value: _positionMinIntervalSecs,
            min: 10,
            max: 600,
            label:
                '${_positionMinIntervalSecs}s', // lint-allow: hardcoded-string
            onChanged: (v) => setState(() => _positionMinIntervalSecs = v),
          ),
        ],
      ],
    );
  }

  Widget _buildNodeinfoSection() {
    return _card(
      children: [
        _SettingsTile(
          icon: Icons.info_outline,
          title: context.l10n.trafficMgmtDirectResponse,
          subtitle: context.l10n.trafficMgmtDirectResponseSubtitle,
          trailing: ThemedSwitch(
            value: _nodeinfoDirectResponse,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() => _nodeinfoDirectResponse = value);
            },
          ),
        ),
        if (_nodeinfoDirectResponse) ...[
          _sliderLabel(
            context.l10n.trafficMgmtMaxHops(_nodeinfoDirectResponseMaxHops),
            context.l10n.trafficMgmtMaxHopsDesc,
          ),
          _slider(
            value: _nodeinfoDirectResponseMaxHops,
            min: 1,
            max: 7,
            label:
                '$_nodeinfoDirectResponseMaxHops', // lint-allow: hardcoded-string
            onChanged: (v) =>
                setState(() => _nodeinfoDirectResponseMaxHops = v),
          ),
        ],
      ],
    );
  }

  Widget _buildRateLimitSection() {
    return _card(
      children: [
        _SettingsTile(
          icon: Icons.speed,
          title: context.l10n.trafficMgmtPerNodeRateLimit,
          subtitle: context.l10n.trafficMgmtPerNodeRateLimitSubtitle,
          trailing: ThemedSwitch(
            value: _rateLimitEnabled,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() => _rateLimitEnabled = value);
            },
          ),
        ),
        if (_rateLimitEnabled) ...[
          _sliderLabel(
            context.l10n.trafficMgmtWindow(_rateLimitWindowSecs),
            context.l10n.trafficMgmtWindowDesc,
          ),
          _slider(
            value: _rateLimitWindowSecs,
            min: 10,
            max: 300,
            label: '${_rateLimitWindowSecs}s', // lint-allow: hardcoded-string
            onChanged: (v) => setState(() => _rateLimitWindowSecs = v),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            context.l10n.trafficMgmtMaxPackets(_rateLimitMaxPackets),
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            context.l10n.trafficMgmtMaxPacketsDesc,
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
          _slider(
            value: _rateLimitMaxPackets,
            min: 1,
            max: 50,
            label: '$_rateLimitMaxPackets', // lint-allow: hardcoded-string
            onChanged: (v) => setState(() => _rateLimitMaxPackets = v),
          ),
        ],
      ],
    );
  }

  Widget _buildUnknownPacketsSection() {
    return _card(
      children: [
        _SettingsTile(
          icon: Icons.help_outline,
          title: context.l10n.trafficMgmtDropUnknown,
          subtitle: context.l10n.trafficMgmtDropUnknownSubtitle,
          trailing: ThemedSwitch(
            value: _dropUnknownEnabled,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() => _dropUnknownEnabled = value);
            },
          ),
        ),
        if (_dropUnknownEnabled) ...[
          _sliderLabel(
            context.l10n.trafficMgmtThreshold(_unknownPacketThreshold),
            context.l10n.trafficMgmtThresholdDesc,
          ),
          _slider(
            value: _unknownPacketThreshold,
            min: 1,
            max: 20,
            label: '$_unknownPacketThreshold', // lint-allow: hardcoded-string
            onChanged: (v) => setState(() => _unknownPacketThreshold = v),
          ),
        ],
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: context.textSecondary, size: 22),
        SizedBox(width: AppTheme.spacing12),
        Expanded(
          child: Column(
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
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(color: context.textSecondary, fontSize: 12),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          color: context.textTertiary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
