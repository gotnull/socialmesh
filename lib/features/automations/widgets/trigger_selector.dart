import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../settings/geofence_picker_screen.dart';
import '../models/automation.dart';

/// Widget for selecting and configuring a trigger
class TriggerSelector extends StatelessWidget {
  final AutomationTrigger trigger;
  final void Function(AutomationTrigger trigger) onChanged;

  const TriggerSelector({
    super.key,
    required this.trigger,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Trigger type selector
        BouncyTap(
          onTap: () => _showTriggerTypePicker(context),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(trigger.type.icon, color: Colors.amber),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trigger.type.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        trigger.type.category,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Trigger configuration
        _buildTriggerConfig(context),
      ],
    );
  }

  Widget _buildTriggerConfig(BuildContext context) {
    switch (trigger.type) {
      case TriggerType.batteryLow:
        return _buildSliderConfig(
          context,
          label: 'Battery threshold',
          value: trigger.batteryThreshold.toDouble(),
          min: 5,
          max: 50,
          suffix: '%',
          onChanged: (value) {
            onChanged(
              trigger.copyWith(
                config: {...trigger.config, 'batteryThreshold': value.round()},
              ),
            );
          },
        );

      case TriggerType.messageContains:
        return _buildTextConfig(
          context,
          label: 'Keyword to match',
          hint: 'e.g., SOS, help, emergency',
          value: trigger.keyword ?? '',
          onChanged: (value) {
            onChanged(
              trigger.copyWith(config: {...trigger.config, 'keyword': value}),
            );
          },
        );

      case TriggerType.geofenceEnter:
      case TriggerType.geofenceExit:
        return _buildGeofenceConfig(context);

      case TriggerType.nodeSilent:
        return _buildSliderConfig(
          context,
          label: 'Silent duration',
          value: trigger.silentMinutes.toDouble(),
          min: 5,
          max: 120,
          suffix: ' min',
          divisions: 23,
          onChanged: (value) {
            onChanged(
              trigger.copyWith(
                config: {...trigger.config, 'silentMinutes': value.round()},
              ),
            );
          },
        );

      case TriggerType.signalWeak:
        return _buildSliderConfig(
          context,
          label: 'Signal threshold (SNR)',
          value: trigger.signalThreshold.toDouble(),
          min: -20,
          max: 0,
          suffix: ' dB',
          onChanged: (value) {
            onChanged(
              trigger.copyWith(
                config: {...trigger.config, 'signalThreshold': value.round()},
              ),
            );
          },
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSliderConfig(
    BuildContext context, {
    required String label,
    required double value,
    required double min,
    required double max,
    required String suffix,
    int? divisions,
    required void Function(double value) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey)),
              Text(
                '${value.round()}$suffix',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions ?? (max - min).round(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildTextConfig(
    BuildContext context, {
    required String label,
    required String hint,
    required String value,
    required void Function(String value) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: value),
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.darkBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.darkBorder),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeofenceConfig(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on, size: 18, color: Colors.grey),
              SizedBox(width: 8),
              Text('Geofence Center', style: TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: TextEditingController(
                    text: trigger.geofenceLat?.toString() ?? '',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Latitude',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    final lat = double.tryParse(value);
                    if (lat != null) {
                      onChanged(
                        trigger.copyWith(
                          config: {...trigger.config, 'geofenceLat': lat},
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: TextEditingController(
                    text: trigger.geofenceLon?.toString() ?? '',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Longitude',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    final lon = double.tryParse(value);
                    if (lon != null) {
                      onChanged(
                        trigger.copyWith(
                          config: {...trigger.config, 'geofenceLon': lon},
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Radius', style: TextStyle(color: Colors.grey)),
              Text(
                '${trigger.geofenceRadius.round()}m',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Slider(
            value: trigger.geofenceRadius,
            min: 100,
            max: 5000,
            divisions: 49,
            onChanged: (value) {
              onChanged(
                trigger.copyWith(
                  config: {...trigger.config, 'geofenceRadius': value},
                ),
              );
            },
          ),
          Center(
            child: TextButton.icon(
              onPressed: () async {
                final result = await Navigator.of(context).push<GeofenceResult>(
                  MaterialPageRoute(
                    builder: (context) => GeofencePickerScreen(
                      initialLat: trigger.geofenceLat,
                      initialLon: trigger.geofenceLon,
                      initialRadius: trigger.geofenceRadius,
                    ),
                  ),
                );

                if (result != null) {
                  onChanged(
                    trigger.copyWith(
                      config: {
                        ...trigger.config,
                        'geofenceLat': result.latitude,
                        'geofenceLon': result.longitude,
                        'geofenceRadius': result.radiusMeters,
                      },
                    ),
                  );
                }
              },
              icon: const Icon(Icons.map, size: 18),
              label: const Text('Pick on Map'),
            ),
          ),
        ],
      ),
    );
  }

  void _showTriggerTypePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Select Trigger',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: _buildTriggerList(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTriggerList(BuildContext context) {
    final grouped = <String, List<TriggerType>>{};
    for (final type in TriggerType.values) {
      grouped.putIfAbsent(type.category, () => []).add(type);
    }

    final widgets = <Widget>[];
    for (final entry in grouped.entries) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            entry.key,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      );

      for (final type in entry.value) {
        widgets.add(
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: type == trigger.type
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.2)
                    : AppTheme.darkCard,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                type.icon,
                size: 20,
                color: type == trigger.type
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
              ),
            ),
            title: Text(type.displayName),
            trailing: type == trigger.type
                ? Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
            onTap: () {
              Navigator.pop(context);
              onChanged(AutomationTrigger(type: type));
            },
          ),
        );
      }
    }

    return widgets;
  }
}
