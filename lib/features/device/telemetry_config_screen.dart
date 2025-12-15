import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../providers/app_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';

/// Telemetry module configuration screen
class TelemetryConfigScreen extends ConsumerStatefulWidget {
  const TelemetryConfigScreen({super.key});

  @override
  ConsumerState<TelemetryConfigScreen> createState() =>
      _TelemetryConfigScreenState();
}

class _TelemetryConfigScreenState extends ConsumerState<TelemetryConfigScreen> {
  // Device Metrics
  int _deviceMetricsUpdateInterval = 1800; // Default 30 minutes
  bool _deviceMetricsEnabled = false;

  // Environment Metrics
  int _environmentMetricsUpdateInterval = 1800; // Default 30 minutes
  bool _environmentMetricsEnabled = false;
  bool _environmentDisplayOnScreen = false;
  bool _environmentDisplayFahrenheit = false;

  // Air Quality
  int _airQualityUpdateInterval = 1800; // Default 30 minutes
  bool _airQualityEnabled = false;

  // Power Metrics
  int _powerMetricsUpdateInterval = 1800; // Default 30 minutes
  bool _powerMetricsEnabled = false;
  bool _powerScreenEnabled = false;

  bool _hasChanges = false;
  bool _isSaving = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  Future<void> _loadCurrentConfig() async {
    final protocol = ref.read(protocolServiceProvider);

    // Check if we're connected before trying to load config
    if (!protocol.isConnected) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    final config = await protocol.getTelemetryModuleConfig();
    if (config != null && mounted) {
      setState(() {
        // Device Metrics - use deviceTelemetryEnabled flag
        _deviceMetricsEnabled = config.deviceTelemetryEnabled;
        _deviceMetricsUpdateInterval = config.deviceUpdateInterval > 0
            ? config.deviceUpdateInterval
            : 1800;

        // Environment Metrics - use environmentMeasurementEnabled flag
        _environmentMetricsEnabled = config.environmentMeasurementEnabled;
        _environmentMetricsUpdateInterval = config.environmentUpdateInterval > 0
            ? config.environmentUpdateInterval
            : 1800;
        _environmentDisplayOnScreen = config.environmentScreenEnabled;
        _environmentDisplayFahrenheit = config.environmentDisplayFahrenheit;

        // Air Quality - use airQualityEnabled flag
        _airQualityEnabled = config.airQualityEnabled;
        _airQualityUpdateInterval = config.airQualityInterval > 0
            ? config.airQualityInterval
            : 1800;

        // Power Metrics - use powerMeasurementEnabled flag
        _powerMetricsEnabled = config.powerMeasurementEnabled;
        _powerMetricsUpdateInterval = config.powerUpdateInterval > 0
            ? config.powerUpdateInterval
            : 1800;
        _powerScreenEnabled = config.powerScreenEnabled;

        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      final protocol = ref.read(protocolServiceProvider);
      await protocol.setTelemetryModuleConfig(
        // Device Metrics
        deviceTelemetryEnabled: _deviceMetricsEnabled,
        deviceUpdateInterval: _deviceMetricsEnabled
            ? _deviceMetricsUpdateInterval
            : 0,
        // Environment Metrics
        environmentMeasurementEnabled: _environmentMetricsEnabled,
        environmentUpdateInterval: _environmentMetricsEnabled
            ? _environmentMetricsUpdateInterval
            : 0,
        environmentScreenEnabled: _environmentDisplayOnScreen,
        environmentDisplayFahrenheit: _environmentDisplayFahrenheit,
        // Air Quality
        airQualityEnabled: _airQualityEnabled,
        airQualityInterval: _airQualityEnabled ? _airQualityUpdateInterval : 0,
        // Power Metrics
        powerMeasurementEnabled: _powerMetricsEnabled,
        powerUpdateInterval: _powerMetricsEnabled
            ? _powerMetricsUpdateInterval
            : 0,
        powerScreenEnabled: _powerScreenEnabled,
      );

      setState(() => _hasChanges = false);
      if (mounted) {
        showSuccessSnackBar(context, 'Telemetry config saved');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to save: $e');
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.darkBackground,
        appBar: AppBar(
          backgroundColor: AppTheme.darkBackground,
          title: const Text(
            'Telemetry',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const ScreenLoadingIndicator(),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text(
          'Telemetry',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: MeshLoadingIndicator(size: 16),
                    )
                  : Text(
                      'Save',
                      style: TextStyle(
                        color: context.accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Device Metrics Section
          _SectionHeader(
            title: 'Device Metrics',
            icon: Icons.memory,
            color: AccentColors.blue,
          ),
          const SizedBox(height: 12),
          _TelemetrySection(
            enabled: _deviceMetricsEnabled,
            updateInterval: _deviceMetricsUpdateInterval,
            onEnabledChanged: (value) {
              setState(() {
                _deviceMetricsEnabled = value;
                _hasChanges = true;
              });
            },
            onIntervalChanged: (value) {
              setState(() {
                _deviceMetricsUpdateInterval = value;
                _hasChanges = true;
              });
            },
            description:
                'Battery level, voltage, channel utilization, air util TX',
          ),

          const SizedBox(height: 24),

          // Environment Metrics Section
          _SectionHeader(
            title: 'Environment Metrics',
            icon: Icons.thermostat,
            color: AccentColors.green,
          ),
          const SizedBox(height: 12),
          _TelemetrySection(
            enabled: _environmentMetricsEnabled,
            updateInterval: _environmentMetricsUpdateInterval,
            onEnabledChanged: (value) {
              setState(() {
                _environmentMetricsEnabled = value;
                _hasChanges = true;
              });
            },
            onIntervalChanged: (value) {
              setState(() {
                _environmentMetricsUpdateInterval = value;
                _hasChanges = true;
              });
            },
            description:
                'Temperature, humidity, barometric pressure, gas resistance',
            additionalWidget: _ToggleTile(
              title: 'Display on Screen',
              subtitle: 'Show environment data on device screen',
              value: _environmentDisplayOnScreen,
              onChanged: (value) {
                setState(() {
                  _environmentDisplayOnScreen = value;
                  _hasChanges = true;
                });
              },
            ),
          ),

          const SizedBox(height: 24),

          // Air Quality Section
          _SectionHeader(
            title: 'Air Quality',
            icon: Icons.air,
            color: AccentColors.teal,
          ),
          const SizedBox(height: 12),
          _TelemetrySection(
            enabled: _airQualityEnabled,
            updateInterval: _airQualityUpdateInterval,
            onEnabledChanged: (value) {
              setState(() {
                _airQualityEnabled = value;
                _hasChanges = true;
              });
            },
            onIntervalChanged: (value) {
              setState(() {
                _airQualityUpdateInterval = value;
                _hasChanges = true;
              });
            },
            description: 'PM1.0, PM2.5, PM10, particle counts, CO2',
          ),

          const SizedBox(height: 24),

          // Power Metrics Section
          _SectionHeader(
            title: 'Power Metrics',
            icon: Icons.electric_bolt,
            color: AccentColors.orange,
          ),
          const SizedBox(height: 12),
          _TelemetrySection(
            enabled: _powerMetricsEnabled,
            updateInterval: _powerMetricsUpdateInterval,
            onEnabledChanged: (value) {
              setState(() {
                _powerMetricsEnabled = value;
                _hasChanges = true;
              });
            },
            onIntervalChanged: (value) {
              setState(() {
                _powerMetricsUpdateInterval = value;
                _hasChanges = true;
              });
            },
            description: 'Voltage and current for channels 1-3',
          ),

          const SizedBox(height: 24),

          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.accentColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: context.accentColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Telemetry data is shared with all nodes on the mesh network. '
                    'Shorter intervals increase airtime usage.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.7),
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
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _TelemetrySection extends StatelessWidget {
  final bool enabled;
  final int updateInterval;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onIntervalChanged;
  final String description;
  final Widget? additionalWidget;

  const _TelemetrySection({
    required this.enabled,
    required this.updateInterval,
    required this.onEnabledChanged,
    required this.onIntervalChanged,
    required this.description,
    this.additionalWidget,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = context.accentColor;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enabled',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              ThemedSwitch(value: enabled, onChanged: onEnabledChanged),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 16),
            Text(
              'Update Interval',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${updateInterval ~/ 60}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
                Text(
                  ' minutes',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: accentColor,
                inactiveTrackColor: accentColor.withValues(alpha: 0.2),
                thumbColor: accentColor,
                overlayColor: accentColor.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: updateInterval.toDouble(),
                min: 60,
                max: 3600,
                divisions: 59,
                onChanged: (value) => onIntervalChanged(value.round()),
              ),
            ),
            if (additionalWidget != null) ...[
              const SizedBox(height: 12),
              additionalWidget!,
            ],
          ],
        ],
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        ThemedSwitch(value: value, onChanged: onChanged),
      ],
    );
  }
}
