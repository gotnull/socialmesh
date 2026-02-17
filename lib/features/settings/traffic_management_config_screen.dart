// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../providers/app_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';
import '../../generated/meshtastic/module_config.pb.dart' as module_pb;
import '../../generated/meshtastic/admin.pbenum.dart' as admin_pbenum;

/// Screen for configuring traffic management module settings (v2.7.19)
class TrafficManagementConfigScreen extends ConsumerStatefulWidget {
  const TrafficManagementConfigScreen({super.key});

  @override
  ConsumerState<TrafficManagementConfigScreen> createState() =>
      _TrafficManagementConfigScreenState();
}

class _TrafficManagementConfigScreenState
    extends ConsumerState<TrafficManagementConfigScreen>
    with LifecycleSafeMixin {
  bool _isLoading = false;

  // Master toggle
  bool _enabled = false;

  // Position deduplication
  bool _positionDedupEnabled = false;
  int _positionPrecisionBits = 16;
  int _positionMinIntervalSecs = 60;

  // NodeInfo direct response
  bool _nodeinfoDirectResponse = false;
  int _nodeinfoDirectResponseMaxHops = 3;

  // Rate limiting
  bool _rateLimitEnabled = false;
  int _rateLimitWindowSecs = 60;
  int _rateLimitMaxPackets = 10;

  // Unknown packet handling
  bool _dropUnknownEnabled = false;
  int _unknownPacketThreshold = 5;

  // Hop management
  bool _exhaustHopTelemetry = false;
  bool _exhaustHopPosition = false;
  bool _routerPreserveHops = false;

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
    setState(() {
      _enabled = config.enabled;
      _positionDedupEnabled = config.positionDedupEnabled;
      _positionPrecisionBits = config.positionPrecisionBits > 0
          ? config.positionPrecisionBits
          : 16;
      _positionMinIntervalSecs = config.positionMinIntervalSecs > 0
          ? config.positionMinIntervalSecs
          : 60;
      _nodeinfoDirectResponse = config.nodeinfoDirectResponse;
      _nodeinfoDirectResponseMaxHops = config.nodeinfoDirectResponseMaxHops > 0
          ? config.nodeinfoDirectResponseMaxHops
          : 3;
      _rateLimitEnabled = config.rateLimitEnabled;
      _rateLimitWindowSecs = config.rateLimitWindowSecs > 0
          ? config.rateLimitWindowSecs
          : 60;
      _rateLimitMaxPackets = config.rateLimitMaxPackets > 0
          ? config.rateLimitMaxPackets
          : 10;
      _dropUnknownEnabled = config.dropUnknownEnabled;
      _unknownPacketThreshold = config.unknownPacketThreshold > 0
          ? config.unknownPacketThreshold
          : 5;
      _exhaustHopTelemetry = config.exhaustHopTelemetry;
      _exhaustHopPosition = config.exhaustHopPosition;
      _routerPreserveHops = config.routerPreserveHops;
    });
  }

  Future<void> _loadCurrentConfig() async {
    safeSetState(() => _isLoading = true);
    try {
      final protocol = ref.read(protocolServiceProvider);

      // Apply cached config immediately if available
      final cached = protocol.currentTrafficManagementConfig;
      if (cached != null) {
        _applyConfig(cached);
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
        );
      }
    } catch (e) {
      AppLogging.protocol('Traffic management config load aborted: $e');
    } finally {
      safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    safeSetState(() => _isLoading = true);
    try {
      final protocol = ref.read(protocolServiceProvider);
      await protocol.setTrafficManagementConfig(
        enabled: _enabled,
        positionDedupEnabled: _positionDedupEnabled,
        positionPrecisionBits: _positionPrecisionBits,
        positionMinIntervalSecs: _positionMinIntervalSecs,
        nodeinfoDirectResponse: _nodeinfoDirectResponse,
        nodeinfoDirectResponseMaxHops: _nodeinfoDirectResponseMaxHops,
        rateLimitEnabled: _rateLimitEnabled,
        rateLimitWindowSecs: _rateLimitWindowSecs,
        rateLimitMaxPackets: _rateLimitMaxPackets,
        dropUnknownEnabled: _dropUnknownEnabled,
        unknownPacketThreshold: _unknownPacketThreshold,
        exhaustHopTelemetry: _exhaustHopTelemetry,
        exhaustHopPosition: _exhaustHopPosition,
        routerPreserveHops: _routerPreserveHops,
      );

      if (mounted) {
        showSuccessSnackBar(context, 'Traffic management configuration saved');
        safeNavigatorPop();
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to save: $e');
      }
    } finally {
      safeSetState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Traffic Management',
      actions: [
        TextButton(
          onPressed: _isLoading ? null : _saveConfig,
          child: Text(
            'Save',
            style: TextStyle(
              color: _isLoading ? Colors.grey : context.accentColor,
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
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SectionHeader(title: 'GENERAL'),
                const SizedBox(height: 8),
                _buildGeneralSection(),
                const SizedBox(height: 24),
                _SectionHeader(title: 'POSITION DEDUPLICATION'),
                const SizedBox(height: 8),
                _buildPositionDedupSection(),
                const SizedBox(height: 24),
                _SectionHeader(title: 'NODEINFO DIRECT RESPONSE'),
                const SizedBox(height: 8),
                _buildNodeinfoSection(),
                const SizedBox(height: 24),
                _SectionHeader(title: 'RATE LIMITING'),
                const SizedBox(height: 8),
                _buildRateLimitSection(),
                const SizedBox(height: 24),
                _SectionHeader(title: 'UNKNOWN PACKETS'),
                const SizedBox(height: 8),
                _buildUnknownPacketsSection(),
                const SizedBox(height: 24),
                _SectionHeader(title: 'HOP MANAGEMENT'),
                const SizedBox(height: 8),
                _buildHopManagementSection(),
                const SizedBox(height: 32),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _buildGeneralSection() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: _SettingsTile(
        icon: Icons.traffic,
        title: 'Enable Traffic Management',
        subtitle: 'Master toggle for all traffic management features',
        trailing: ThemedSwitch(
          value: _enabled,
          onChanged: (value) {
            HapticFeedback.selectionClick();
            setState(() => _enabled = value);
          },
        ),
      ),
    );
  }

  Widget _buildPositionDedupSection() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsTile(
            icon: Icons.filter_alt,
            title: 'Position Deduplication',
            subtitle: 'Drop duplicate position packets',
            trailing: ThemedSwitch(
              value: _positionDedupEnabled,
              onChanged: _enabled
                  ? (value) {
                      HapticFeedback.selectionClick();
                      setState(() => _positionDedupEnabled = value);
                    }
                  : null,
            ),
          ),
          if (_positionDedupEnabled && _enabled) ...[
            const SizedBox(height: 16),
            Divider(color: context.border),
            const SizedBox(height: 8),
            Text(
              'Precision Bits: $_positionPrecisionBits',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Lower values mean more aggressive deduplication',
              style: TextStyle(color: context.textSecondary, fontSize: 12),
            ),
            SliderTheme(
              data: SliderThemeData(
                inactiveTrackColor: Colors.grey.shade700,
                thumbColor: context.accentColor,
                overlayColor: context.accentColor.withAlpha(30),
              ),
              child: Slider(
                value: _positionPrecisionBits.toDouble(),
                min: 0,
                max: 32,
                divisions: 32,
                label: '$_positionPrecisionBits bits',
                onChanged: (value) {
                  setState(() => _positionPrecisionBits = value.toInt());
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Min Interval: ${_positionMinIntervalSecs}s',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Minimum seconds between position updates',
              style: TextStyle(color: context.textSecondary, fontSize: 12),
            ),
            SliderTheme(
              data: SliderThemeData(
                inactiveTrackColor: Colors.grey.shade700,
                thumbColor: context.accentColor,
                overlayColor: context.accentColor.withAlpha(30),
              ),
              child: Slider(
                value: _positionMinIntervalSecs.toDouble(),
                min: 10,
                max: 600,
                divisions: 59,
                label: '${_positionMinIntervalSecs}s',
                onChanged: (value) {
                  setState(() => _positionMinIntervalSecs = value.toInt());
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNodeinfoSection() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'Direct Response',
            subtitle: 'Respond to NodeInfo requests directly',
            trailing: ThemedSwitch(
              value: _nodeinfoDirectResponse,
              onChanged: _enabled
                  ? (value) {
                      HapticFeedback.selectionClick();
                      setState(() => _nodeinfoDirectResponse = value);
                    }
                  : null,
            ),
          ),
          if (_nodeinfoDirectResponse && _enabled) ...[
            const SizedBox(height: 16),
            Divider(color: context.border),
            const SizedBox(height: 8),
            Text(
              'Max Hops: $_nodeinfoDirectResponseMaxHops',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Maximum hops for direct NodeInfo response',
              style: TextStyle(color: context.textSecondary, fontSize: 12),
            ),
            SliderTheme(
              data: SliderThemeData(
                inactiveTrackColor: Colors.grey.shade700,
                thumbColor: context.accentColor,
                overlayColor: context.accentColor.withAlpha(30),
              ),
              child: Slider(
                value: _nodeinfoDirectResponseMaxHops.toDouble(),
                min: 0,
                max: 7,
                divisions: 7,
                label: '$_nodeinfoDirectResponseMaxHops',
                onChanged: (value) {
                  setState(
                    () => _nodeinfoDirectResponseMaxHops = value.toInt(),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRateLimitSection() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsTile(
            icon: Icons.speed,
            title: 'Per-Node Rate Limiting',
            subtitle: 'Limit packet rate from individual nodes',
            trailing: ThemedSwitch(
              value: _rateLimitEnabled,
              onChanged: _enabled
                  ? (value) {
                      HapticFeedback.selectionClick();
                      setState(() => _rateLimitEnabled = value);
                    }
                  : null,
            ),
          ),
          if (_rateLimitEnabled && _enabled) ...[
            const SizedBox(height: 16),
            Divider(color: context.border),
            const SizedBox(height: 8),
            Text(
              'Window: ${_rateLimitWindowSecs}s',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Time window for rate limit calculation',
              style: TextStyle(color: context.textSecondary, fontSize: 12),
            ),
            SliderTheme(
              data: SliderThemeData(
                inactiveTrackColor: Colors.grey.shade700,
                thumbColor: context.accentColor,
                overlayColor: context.accentColor.withAlpha(30),
              ),
              child: Slider(
                value: _rateLimitWindowSecs.toDouble(),
                min: 10,
                max: 300,
                divisions: 29,
                label: '${_rateLimitWindowSecs}s',
                onChanged: (value) {
                  setState(() => _rateLimitWindowSecs = value.toInt());
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Max Packets: $_rateLimitMaxPackets',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Maximum packets per window before dropping',
              style: TextStyle(color: context.textSecondary, fontSize: 12),
            ),
            SliderTheme(
              data: SliderThemeData(
                inactiveTrackColor: Colors.grey.shade700,
                thumbColor: context.accentColor,
                overlayColor: context.accentColor.withAlpha(30),
              ),
              child: Slider(
                value: _rateLimitMaxPackets.toDouble(),
                min: 1,
                max: 50,
                divisions: 49,
                label: '$_rateLimitMaxPackets',
                onChanged: (value) {
                  setState(() => _rateLimitMaxPackets = value.toInt());
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUnknownPacketsSection() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsTile(
            icon: Icons.help_outline,
            title: 'Drop Unknown Packets',
            subtitle: 'Drop packets from unknown sources',
            trailing: ThemedSwitch(
              value: _dropUnknownEnabled,
              onChanged: _enabled
                  ? (value) {
                      HapticFeedback.selectionClick();
                      setState(() => _dropUnknownEnabled = value);
                    }
                  : null,
            ),
          ),
          if (_dropUnknownEnabled && _enabled) ...[
            const SizedBox(height: 16),
            Divider(color: context.border),
            const SizedBox(height: 8),
            Text(
              'Threshold: $_unknownPacketThreshold',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Number of unknown packets before dropping',
              style: TextStyle(color: context.textSecondary, fontSize: 12),
            ),
            SliderTheme(
              data: SliderThemeData(
                inactiveTrackColor: Colors.grey.shade700,
                thumbColor: context.accentColor,
                overlayColor: context.accentColor.withAlpha(30),
              ),
              child: Slider(
                value: _unknownPacketThreshold.toDouble(),
                min: 1,
                max: 20,
                divisions: 19,
                label: '$_unknownPacketThreshold',
                onChanged: (value) {
                  setState(() => _unknownPacketThreshold = value.toInt());
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHopManagementSection() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsTile(
            icon: Icons.compress,
            title: 'Exhaust Hop on Telemetry',
            subtitle: 'Set hop limit to 0 for relayed telemetry',
            trailing: ThemedSwitch(
              value: _exhaustHopTelemetry,
              onChanged: _enabled
                  ? (value) {
                      HapticFeedback.selectionClick();
                      setState(() => _exhaustHopTelemetry = value);
                    }
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.compress,
            title: 'Exhaust Hop on Position',
            subtitle: 'Set hop limit to 0 for relayed positions',
            trailing: ThemedSwitch(
              value: _exhaustHopPosition,
              onChanged: _enabled
                  ? (value) {
                      HapticFeedback.selectionClick();
                      setState(() => _exhaustHopPosition = value);
                    }
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.route,
            title: 'Preserve Router Hops',
            subtitle: 'Preserve hop count for router nodes',
            trailing: ThemedSwitch(
              value: _routerPreserveHops,
              onChanged: _enabled
                  ? (value) {
                      HapticFeedback.selectionClick();
                      setState(() => _routerPreserveHops = value);
                    }
                  : null,
            ),
          ),
        ],
      ),
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
      children: [
        Icon(icon, color: context.textSecondary, size: 22),
        SizedBox(width: 12),
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
