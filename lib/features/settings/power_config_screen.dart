import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/widgets/animations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';
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
  // New settings matching iOS
  bool _shutdownOnPowerLoss = false;
  int _shutdownAfterSecs = 0;
  bool _adcOverride = false;
  double _adcMultiplier = 0.0;
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
      // New settings
      _shutdownAfterSecs = config.onBatteryShutdownAfterSecs;
      _shutdownOnPowerLoss = _shutdownAfterSecs > 0;
      _adcMultiplier = config.adcMultiplierOverride;
      _adcOverride = _adcMultiplier > 0;
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

      // Only request from device if connected
      if (protocol.isConnected) {
        // Listen for config response
        _configSubscription = protocol.powerConfigStream.listen((config) {
          if (mounted) _applyConfig(config);
        });

        // Request fresh config from device
        await protocol.getConfig(pb.AdminMessage_ConfigType.POWER_CONFIG);
      }
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
        onBatteryShutdownAfterSecs: _shutdownOnPowerLoss
            ? _shutdownAfterSecs
            : 0,
        adcMultiplierOverride: _adcOverride ? _adcMultiplier : 0.0,
      );

      if (mounted) {
        showSuccessSnackBar(context, 'Power configuration saved');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to save: $e');
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
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        title: Text(
          'Power',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _saving ? null : _saveConfig,
              child: _saving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: MeshLoadingIndicator(
                        size: 20,
                        colors: [
                          context.accentColor,
                          context.accentColor.withValues(alpha: 0.6),
                          context.accentColor.withValues(alpha: 0.3),
                        ],
                      ),
                    )
                  : Text(
                      'Save',
                      style: TextStyle(
                        color: context.accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const ScreenLoadingIndicator()
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Power Section
                const _SectionHeader(title: 'POWER'),
                // Power saving mode toggle
                _SettingsTile(
                  icon: _isPowerSaving
                      ? Icons.battery_saver
                      : Icons.battery_full,
                  iconColor: _isPowerSaving ? context.accentColor : null,
                  title: 'Power Saving Mode',
                  subtitle: 'Reduce power consumption when idle',
                  trailing: ThemedSwitch(
                    value: _isPowerSaving,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      setState(() => _isPowerSaving = value);
                    },
                  ),
                ),
                _SettingsTile(
                  icon: Icons.power_settings_new,
                  iconColor: _shutdownOnPowerLoss ? context.accentColor : null,
                  title: 'Shutdown on Power Loss',
                  subtitle: 'Power off device when external power removed',
                  trailing: ThemedSwitch(
                    value: _shutdownOnPowerLoss,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _shutdownOnPowerLoss = value;
                        if (value && _shutdownAfterSecs == 0) {
                          _shutdownAfterSecs = 60; // Default to 1 minute
                        }
                      });
                    },
                  ),
                ),
                // Shutdown After Secs slider (only show when shutdown enabled)
                if (_shutdownOnPowerLoss)
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _buildSliderSetting(
                      title: 'Shutdown Delay',
                      subtitle: 'Time to wait before shutdown after power loss',
                      value: _shutdownAfterSecs.toDouble(),
                      min: 10,
                      max: 3600,
                      divisions: 36,
                      formatValue: (v) => _formatDuration(v.toInt()),
                      onChanged: (value) =>
                          setState(() => _shutdownAfterSecs = value.toInt()),
                    ),
                  ),
                SizedBox(height: 16),

                // Battery Section (ADC Multiplier)
                const _SectionHeader(title: 'BATTERY'),
                _SettingsTile(
                  icon: Icons.battery_charging_full,
                  iconColor: _adcOverride ? context.accentColor : null,
                  title: 'ADC Multiplier Override',
                  subtitle:
                      'Override voltage divider ratio for battery reading',
                  trailing: ThemedSwitch(
                    value: _adcOverride,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _adcOverride = value;
                        if (value && _adcMultiplier == 0.0) {
                          _adcMultiplier = 3.2; // Default ratio
                        }
                      });
                    },
                  ),
                ),
                // ADC Multiplier input (only show when override enabled)
                if (_adcOverride)
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ADC Multiplier',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(
                              width: 80,
                              child: TextField(
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                textAlign: TextAlign.center,
                                style: TextStyle(color: context.textPrimary),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  fillColor: context.background,
                                  filled: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: context.border,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: context.border,
                                    ),
                                  ),
                                ),
                                controller: TextEditingController(
                                  text: _adcMultiplier.toStringAsFixed(2),
                                ),
                                onChanged: (value) {
                                  final parsed = double.tryParse(value);
                                  if (parsed != null &&
                                      parsed >= 2.0 &&
                                      parsed <= 6.0) {
                                    setState(() => _adcMultiplier = parsed);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Voltage divider ratio (2.0 - 6.0)',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(height: 16),

                // Sleep Settings Section
                const _SectionHeader(title: 'SLEEP SETTINGS'),

                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.card,
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
                      SizedBox(height: 20),
                      Divider(height: 1, color: context.border),
                      SizedBox(height: 20),

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
                      Divider(height: 1, color: context.border),
                      SizedBox(height: 20),

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
                      Divider(height: 1, color: context.border),
                      SizedBox(height: 20),

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
                      Expanded(
                        child: Text(
                          'Power settings affect battery life and device responsiveness. Aggressive sleep settings may cause delays in receiving messages.',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 13,
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
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                formatValue(value),
                style: TextStyle(
                  color: context.accentColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: context.textSecondary, fontSize: 13),
        ),
        SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            inactiveTrackColor: context.border,
            thumbColor: context.accentColor,
            overlayColor: context.accentColor.withValues(alpha: 0.2),
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
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: context.textTertiary,
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
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? context.textSecondary),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: context.textTertiary),
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
