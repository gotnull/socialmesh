import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../generated/meshtastic/mesh.pb.dart' as pb;

/// Screen for configuring GPS and position settings
class PositionConfigScreen extends ConsumerStatefulWidget {
  const PositionConfigScreen({super.key});

  @override
  ConsumerState<PositionConfigScreen> createState() =>
      _PositionConfigScreenState();
}

class _PositionConfigScreenState extends ConsumerState<PositionConfigScreen> {
  bool _isLoading = false;
  pb.Config_PositionConfig_GpsMode? _gpsMode;
  bool _smartBroadcastEnabled = true;
  bool _fixedPosition = false;
  int _positionBroadcastSecs = 900;
  int _gpsUpdateInterval = 30;
  StreamSubscription<pb.Config_PositionConfig>? _configSubscription;

  // Fixed position values
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final _altController = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _configSubscription?.cancel();
    _latController.dispose();
    _lonController.dispose();
    _altController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentConfig() async {
    setState(() => _isLoading = true);
    try {
      final protocol = ref.read(protocolServiceProvider);

      // Check if we already have cached config
      final cachedConfig = protocol.currentPositionConfig;
      if (cachedConfig != null) {
        _applyConfig(cachedConfig);
      }

      // Listen for config response
      _configSubscription?.cancel();
      _configSubscription = protocol.positionConfigStream.listen((config) {
        if (mounted) {
          _applyConfig(config);
        }
      });

      // Request fresh config from device
      await protocol.getConfig(pb.AdminMessage_ConfigType.POSITION_CONFIG);

      // Wait a bit for response
      await Future.delayed(const Duration(milliseconds: 500));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyConfig(pb.Config_PositionConfig config) {
    setState(() {
      _gpsMode = config.gpsMode;
      _smartBroadcastEnabled = config.positionBroadcastSmartEnabled;
      _fixedPosition = config.fixedPosition;
      _positionBroadcastSecs = config.positionBroadcastSecs > 0
          ? config.positionBroadcastSecs
          : 900;
      _gpsUpdateInterval = config.gpsUpdateInterval > 0
          ? config.gpsUpdateInterval
          : 30;
    });
  }

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);
    try {
      final protocol = ref.read(protocolServiceProvider);

      // If fixed position is enabled, set the fixed position first
      if (_fixedPosition) {
        final lat = double.tryParse(_latController.text);
        final lon = double.tryParse(_lonController.text);
        final alt = int.tryParse(_altController.text) ?? 0;

        if (lat != null && lon != null) {
          await protocol.setFixedPosition(
            latitude: lat,
            longitude: lon,
            altitude: alt,
          );
        }
      } else {
        await protocol.removeFixedPosition();
      }

      await protocol.setPositionConfig(
        positionBroadcastSecs: _positionBroadcastSecs,
        positionBroadcastSmartEnabled: _smartBroadcastEnabled,
        fixedPosition: _fixedPosition,
        gpsMode: _gpsMode,
        gpsUpdateInterval: _gpsUpdateInterval,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Position configuration saved'),
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
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Position Configuration'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveConfig,
            child: const Text('Save'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionHeader(title: 'GPS MODE'),
                const SizedBox(height: 8),
                _buildGpsModeSelector(theme),
                const SizedBox(height: 24),
                _SectionHeader(title: 'BROADCAST SETTINGS'),
                const SizedBox(height: 8),
                _buildBroadcastSettings(theme),
                const SizedBox(height: 24),
                _SectionHeader(title: 'FIXED POSITION'),
                const SizedBox(height: 8),
                _buildFixedPositionSettings(theme),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildGpsModeSelector(ThemeData theme) {
    final modes = [
      (
        pb.Config_PositionConfig_GpsMode.ENABLED,
        'Enabled',
        'GPS is active and reports position',
        Icons.gps_fixed,
      ),
      (
        pb.Config_PositionConfig_GpsMode.DISABLED,
        'Disabled',
        'GPS hardware is present but turned off',
        Icons.gps_off,
      ),
      (
        pb.Config_PositionConfig_GpsMode.NOT_PRESENT,
        'Not Present',
        'No GPS hardware on this device',
        Icons.gps_not_fixed,
      ),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GPS Hardware Mode',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...modes.map((m) {
              final isSelected = _gpsMode == m.$1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => setState(() => _gpsMode = m.$1),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline.withAlpha(100),
                        width: isSelected ? 2 : 1,
                      ),
                      color: isSelected
                          ? theme.colorScheme.primaryContainer.withAlpha(50)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          m.$4,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.$2,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                              Text(
                                m.$3,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildBroadcastSettings(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              value: _smartBroadcastEnabled,
              onChanged: (value) =>
                  setState(() => _smartBroadcastEnabled = value),
              title: const Text('Smart Broadcast'),
              subtitle: const Text(
                'Only broadcast when position changes significantly',
              ),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Position Broadcast Interval',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'How often to share position: ${_formatDuration(_positionBroadcastSecs)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Slider(
              value: _positionBroadcastSecs.toDouble(),
              min: 60,
              max: 86400,
              divisions: 20,
              label: _formatDuration(_positionBroadcastSecs),
              onChanged: (value) {
                setState(() => _positionBroadcastSecs = value.toInt());
              },
            ),
            const SizedBox(height: 16),
            Text('GPS Update Interval', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'How often GPS checks for position: ${_gpsUpdateInterval}s',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Slider(
              value: _gpsUpdateInterval.toDouble(),
              min: 5,
              max: 120,
              divisions: 23,
              label: '${_gpsUpdateInterval}s',
              onChanged: (value) {
                setState(() => _gpsUpdateInterval = value.toInt());
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFixedPositionSettings(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              value: _fixedPosition,
              onChanged: (value) => setState(() => _fixedPosition = value),
              title: const Text('Use Fixed Position'),
              subtitle: const Text(
                'Manually set position instead of using GPS',
              ),
              contentPadding: EdgeInsets.zero,
            ),
            if (_fixedPosition) ...[
              const Divider(),
              const SizedBox(height: 16),
              TextField(
                controller: _latController,
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                  hintText: 'e.g., 37.7749',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.arrow_upward),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _lonController,
                decoration: const InputDecoration(
                  labelText: 'Longitude',
                  hintText: 'e.g., -122.4194',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.arrow_forward),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _altController,
                decoration: const InputDecoration(
                  labelText: 'Altitude (meters)',
                  hintText: 'e.g., 100',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.height),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Card(
                color: theme.colorScheme.secondaryContainer.withAlpha(100),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Fixed position is useful for stationary installations like routers or base stations.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m';
    if (seconds < 86400) return '${seconds ~/ 3600}h';
    return '${seconds ~/ 86400}d';
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
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
