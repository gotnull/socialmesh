import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../generated/meshtastic/mesh.pb.dart' as pb;

class PowerConfigScreen extends ConsumerStatefulWidget {
  const PowerConfigScreen({super.key});

  @override
  ConsumerState<PowerConfigScreen> createState() => _PowerConfigScreenState();
}

class _PowerConfigScreenState extends ConsumerState<PowerConfigScreen> {
  bool _isPowerSaving = false;
  int _waitBluetoothSecs = 60;
  int _sdsSecs = 3600; // 1 hour
  int _lsSecs = 300; // 5 minutes
  double _minWakeSecs = 10;
  bool _saving = false;
  bool _loading = false;
  StreamSubscription<pb.Config_PowerConfig>? _configSubscription;

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

  void _applyConfig(pb.Config_PowerConfig config) {
    setState(() {
      _isPowerSaving = config.isPowerSaving;
      _waitBluetoothSecs = config.waitBluetoothSecs > 0
          ? config.waitBluetoothSecs
          : 60;
      _sdsSecs = config.sdsSecs > 0 ? config.sdsSecs : 3600;
      _lsSecs = config.lsSecs > 0 ? config.lsSecs : 300;
      _minWakeSecs = config.minWakeSecs > 0
          ? config.minWakeSecs.toDouble()
          : 10;
    });
  }

  Future<void> _loadCurrentConfig() async {
    setState(() => _loading = true);
    try {
      final protocol = ref.read(protocolServiceProvider);

      // Apply cached config immediately if available
      final cached = protocol.currentPowerConfig;
      if (cached != null) {
        _applyConfig(cached);
      }

      // Listen for config response
      _configSubscription = protocol.powerConfigStream.listen((config) {
        if (mounted) _applyConfig(config);
      });

      // Request fresh config from device
      await protocol.getConfig(pb.AdminMessage_ConfigType.POWER_CONFIG);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveConfig() async {
    final protocol = ref.read(protocolServiceProvider);

    setState(() => _saving = true);

    try {
      await protocol.setPowerConfig(
        isPowerSaving: _isPowerSaving,
        waitBluetoothSecs: _waitBluetoothSecs,
        sdsSecs: _sdsSecs,
        lsSecs: _lsSecs,
        minWakeSecs: _minWakeSecs.toInt(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Power configuration saved'),
            backgroundColor: AppTheme.darkCard,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _formatDuration(int seconds) {
    if (seconds == 0) return 'Disabled';
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${(seconds / 60).round()} min';
    if (seconds < 86400) return '${(seconds / 3600).toStringAsFixed(1)} hr';
    return '${(seconds / 86400).toStringAsFixed(1)} days';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text(
          'Power',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFamily: 'Inter',
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _saving ? null : _saveConfig,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryGreen,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Power saving mode toggle
                _SettingsTile(
                  icon: _isPowerSaving
                      ? Icons.battery_saver
                      : Icons.battery_full,
                  iconColor: _isPowerSaving ? AppTheme.primaryGreen : null,
                  title: 'Power Saving Mode',
                  subtitle: 'Reduce power consumption when idle',
                  trailing: Switch.adaptive(
                    value: _isPowerSaving,
                    activeTrackColor: AppTheme.primaryGreen,
                    inactiveTrackColor: Colors.grey.shade600,
                    thumbColor: WidgetStateProperty.all(Colors.white),
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      setState(() => _isPowerSaving = value);
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Sleep Settings Section
                const _SectionHeader(title: 'SLEEP SETTINGS'),

                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Wait Bluetooth
                      _buildSliderSetting(
                        title: 'Wait for Bluetooth',
                        subtitle:
                            'Time to wait for Bluetooth connection before sleep',
                        value: _waitBluetoothSecs.toDouble(),
                        min: 0,
                        max: 300,
                        divisions: 30,
                        formatValue: (v) => _formatDuration(v.toInt()),
                        onChanged: (value) =>
                            setState(() => _waitBluetoothSecs = value.toInt()),
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 1, color: AppTheme.darkBorder),
                      const SizedBox(height: 20),

                      // Light Sleep
                      _buildSliderSetting(
                        title: 'Light Sleep Duration',
                        subtitle: 'Duration of light sleep before deep sleep',
                        value: _lsSecs.toDouble(),
                        min: 0,
                        max: 3600,
                        divisions: 36,
                        formatValue: (v) => _formatDuration(v.toInt()),
                        onChanged: (value) =>
                            setState(() => _lsSecs = value.toInt()),
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 1, color: AppTheme.darkBorder),
                      const SizedBox(height: 20),

                      // Deep Sleep
                      _buildSliderSetting(
                        title: 'Deep Sleep Duration',
                        subtitle: 'Duration of deep sleep (SDS)',
                        value: _sdsSecs.toDouble(),
                        min: 0,
                        max: 86400,
                        divisions: 24,
                        formatValue: (v) => _formatDuration(v.toInt()),
                        onChanged: (value) =>
                            setState(() => _sdsSecs = value.toInt()),
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 1, color: AppTheme.darkBorder),
                      const SizedBox(height: 20),

                      // Min Wake
                      _buildSliderSetting(
                        title: 'Minimum Wake Time',
                        subtitle: 'Minimum time device stays awake',
                        value: _minWakeSecs,
                        min: 1,
                        max: 120,
                        divisions: 119,
                        formatValue: (v) => '${v.toInt()}s',
                        onChanged: (value) =>
                            setState(() => _minWakeSecs = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Info card
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.warningYellow.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.warningYellow.withValues(alpha: 0.3),
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber,
                        color: AppTheme.warningYellow.withValues(alpha: 0.8),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Power settings affect battery life and device responsiveness. Aggressive sleep settings may cause delays in receiving messages.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildSliderSetting({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String Function(double) formatValue,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontFamily: 'Inter',
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                formatValue(value),
                style: const TextStyle(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppTheme.primaryGreen,
            inactiveTrackColor: AppTheme.darkBorder,
            thumbColor: AppTheme.primaryGreen,
            overlayColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
            trackHeight: 4,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppTheme.textTertiary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? AppTheme.textSecondary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textTertiary,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
