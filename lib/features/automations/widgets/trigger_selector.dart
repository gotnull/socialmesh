import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/node_selector_sheet.dart';
import '../../../models/mesh_models.dart';
import '../../settings/geofence_picker_screen.dart';
import '../models/automation.dart';

/// Widget for selecting and configuring a trigger
class TriggerSelector extends StatefulWidget {
  final AutomationTrigger trigger;
  final void Function(AutomationTrigger trigger) onChanged;
  final List<MeshNode> availableNodes;

  const TriggerSelector({
    super.key,
    required this.trigger,
    required this.onChanged,
    this.availableNodes = const [],
  });

  @override
  State<TriggerSelector> createState() => _TriggerSelectorState();
}

class _TriggerSelectorState extends State<TriggerSelector> {
  // Controllers for text fields
  late TextEditingController _keywordController;
  late TextEditingController _latController;
  late TextEditingController _lonController;

  @override
  void initState() {
    super.initState();
    _keywordController = TextEditingController(
      text: widget.trigger.keyword ?? '',
    );
    _latController = TextEditingController(
      text: widget.trigger.geofenceLat?.toString() ?? '',
    );
    _lonController = TextEditingController(
      text: widget.trigger.geofenceLon?.toString() ?? '',
    );
  }

  @override
  void didUpdateWidget(TriggerSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update controllers if the trigger type changed (not during typing)
    if (oldWidget.trigger.type != widget.trigger.type) {
      _keywordController.text = widget.trigger.keyword ?? '';
      _latController.text = widget.trigger.geofenceLat?.toString() ?? '';
      _lonController.text = widget.trigger.geofenceLon?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

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
              color: context.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.border),
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
                  child: Icon(widget.trigger.type.icon, color: Colors.amber),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.trigger.type.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.trigger.type.category,
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
    switch (widget.trigger.type) {
      case TriggerType.batteryLow:
        return Column(
          children: [
            _buildSliderConfig(
              context,
              label: 'Battery threshold',
              value: widget.trigger.batteryThreshold.toDouble(),
              min: 5,
              max: 50,
              suffix: '%',
              onChanged: (value) {
                widget.onChanged(
                  widget.trigger.copyWith(
                    config: {
                      ...widget.trigger.config,
                      'batteryThreshold': value.round(),
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildNodeFilterConfig(context),
          ],
        );

      case TriggerType.batteryFull:
        return _buildNodeFilterConfig(context);

      case TriggerType.messageContains:
        return _buildKeywordConfig(context);

      case TriggerType.geofenceEnter:
      case TriggerType.geofenceExit:
        return Column(
          children: [
            _buildGeofenceConfig(context),
            const SizedBox(height: 8),
            _buildNodeFilterConfig(context),
          ],
        );

      case TriggerType.nodeSilent:
        return Column(
          children: [
            _buildSliderConfig(
              context,
              label: 'Silent duration',
              value: widget.trigger.silentMinutes.toDouble(),
              min: 5,
              max: 120,
              suffix: ' min',
              divisions: 23,
              onChanged: (value) {
                widget.onChanged(
                  widget.trigger.copyWith(
                    config: {
                      ...widget.trigger.config,
                      'silentMinutes': value.round(),
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildNodeFilterConfig(context),
          ],
        );

      case TriggerType.signalWeak:
        return Column(
          children: [
            _buildSliderConfig(
              context,
              label: 'Signal threshold (SNR)',
              value: widget.trigger.signalThreshold.toDouble(),
              min: -20,
              max: 0,
              suffix: ' dB',
              onChanged: (value) {
                widget.onChanged(
                  widget.trigger.copyWith(
                    config: {
                      ...widget.trigger.config,
                      'signalThreshold': value.round(),
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildNodeFilterConfig(context),
          ],
        );

      case TriggerType.positionChanged:
        return _buildNodeFilterConfig(context);

      case TriggerType.nodeOnline:
      case TriggerType.nodeOffline:
        return _buildNodeFilterConfig(context);

      case TriggerType.detectionSensor:
        return Column(
          children: [
            _buildDetectionSensorConfig(context),
            const SizedBox(height: 8),
            _buildNodeFilterConfig(context),
          ],
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
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
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

  Widget _buildKeywordConfig(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Keyword to match', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          TextField(
            controller: _keywordController,
            onChanged: (value) {
              widget.onChanged(
                widget.trigger.copyWith(
                  config: {...widget.trigger.config, 'keyword': value},
                ),
              );
            },
            decoration: InputDecoration(
              hintText: 'e.g., SOS, help, emergency',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: context.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: context.border),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionSensorConfig(BuildContext context) {
    final sensorNameFilter = widget.trigger.sensorNameFilter ?? '';
    final detectedStateFilter = widget.trigger.detectedStateFilter;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sensor name filter (optional)',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            'Leave empty to trigger for any sensor',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: sensorNameFilter),
            onChanged: (value) {
              final newConfig = Map<String, dynamic>.from(
                widget.trigger.config,
              );
              if (value.isEmpty) {
                newConfig.remove('sensorNameFilter');
              } else {
                newConfig['sensorNameFilter'] = value;
              }
              widget.onChanged(widget.trigger.copyWith(config: newConfig));
            },
            decoration: InputDecoration(
              hintText: 'e.g., Motion, Door, Window',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: context.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: context.border),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Trigger when sensor is',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool?>(
            segments: const [
              ButtonSegment(value: null, label: Text('Any')),
              ButtonSegment(value: true, label: Text('Detected')),
              ButtonSegment(value: false, label: Text('Clear')),
            ],
            selected: {detectedStateFilter},
            onSelectionChanged: (selected) {
              final newConfig = Map<String, dynamic>.from(
                widget.trigger.config,
              );
              final value = selected.first;
              if (value == null) {
                newConfig.remove('detectedStateFilter');
              } else {
                newConfig['detectedStateFilter'] = value;
              }
              widget.onChanged(widget.trigger.copyWith(config: newConfig));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNodeFilterConfig(BuildContext context) {
    final selectedNodeNum = widget.trigger.nodeNum;
    final selectedNode = selectedNodeNum != null
        ? widget.availableNodes
              .where((n) => n.nodeNum == selectedNodeNum)
              .firstOrNull
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter by node (optional)',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            'Leave empty to trigger for any node',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 12),
          BouncyTap(
            onTap: () => _showNodePicker(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: context.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: selectedNode != null
                          ? Colors.blue.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      selectedNode != null ? Icons.router : Icons.all_inclusive,
                      size: 18,
                      color: selectedNode != null ? Colors.blue : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedNode?.longName ??
                              selectedNode?.shortName ??
                              'Any node',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: selectedNode != null
                                ? context.textPrimary
                                : Colors.grey,
                          ),
                        ),
                        if (selectedNode != null)
                          Text(
                            '!${selectedNode.nodeNum.toRadixString(16)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (selectedNode != null)
                    GestureDetector(
                      onTap: () {
                        // Clear node filter
                        final newConfig = Map<String, dynamic>.from(
                          widget.trigger.config,
                        );
                        newConfig.remove('nodeNum');
                        widget.onChanged(
                          widget.trigger.copyWith(config: newConfig),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    )
                  else
                    const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showNodePicker(BuildContext context) async {
    final selection = await NodeSelectorSheet.show(
      context,
      title: 'Select Node',
      allowBroadcast: false,
      initialSelection: widget.trigger.nodeNum,
    );

    if (selection != null && selection.nodeNum != null) {
      widget.onChanged(
        widget.trigger.copyWith(
          config: {...widget.trigger.config, 'nodeNum': selection.nodeNum},
        ),
      );
    }
  }

  Widget _buildGeofenceConfig(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  controller: _latController,
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
                      widget.onChanged(
                        widget.trigger.copyWith(
                          config: {
                            ...widget.trigger.config,
                            'geofenceLat': lat,
                          },
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _lonController,
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
                      widget.onChanged(
                        widget.trigger.copyWith(
                          config: {
                            ...widget.trigger.config,
                            'geofenceLon': lon,
                          },
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
                '${widget.trigger.geofenceRadius.round()}m',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Slider(
            value: widget.trigger.geofenceRadius,
            min: 100,
            max: 5000,
            divisions: 49,
            onChanged: (value) {
              widget.onChanged(
                widget.trigger.copyWith(
                  config: {...widget.trigger.config, 'geofenceRadius': value},
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
                      initialLat: widget.trigger.geofenceLat,
                      initialLon: widget.trigger.geofenceLon,
                      initialRadius: widget.trigger.geofenceRadius,
                    ),
                  ),
                );

                if (result != null) {
                  // Update controllers with new values
                  _latController.text = result.latitude.toString();
                  _lonController.text = result.longitude.toString();
                  widget.onChanged(
                    widget.trigger.copyWith(
                      config: {
                        ...widget.trigger.config,
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
      backgroundColor: context.surface,
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
                color: type == widget.trigger.type
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.2)
                    : context.card,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                type.icon,
                size: 20,
                color: type == widget.trigger.type
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
              ),
            ),
            title: Text(type.displayName),
            trailing: type == widget.trigger.type
                ? Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
            onTap: () {
              Navigator.pop(context);
              // Reset controllers when type changes
              _keywordController.text = '';
              _latController.text = '';
              _lonController.text = '';

              // Check if both old and new types are node-related
              final nodeRelatedTypes = {
                TriggerType.nodeOnline,
                TriggerType.nodeOffline,
                TriggerType.batteryLow,
                TriggerType.batteryFull,
                TriggerType.signalWeak,
                TriggerType.nodeSilent,
                TriggerType.positionChanged,
              };

              final oldType = widget.trigger.type;
              final preserveNode =
                  nodeRelatedTypes.contains(oldType) &&
                  nodeRelatedTypes.contains(type);

              // Create new trigger, preserving nodeNum if switching between
              // node-related triggers
              final newConfig = <String, dynamic>{};
              if (preserveNode && widget.trigger.nodeNum != null) {
                newConfig['nodeNum'] = widget.trigger.nodeNum;
              }

              final newTrigger = AutomationTrigger(
                type: type,
                config: newConfig,
              );
              widget.onChanged(newTrigger);

              // If the new trigger type needs a node but doesn't have one,
              // show the picker after a brief delay
              if (nodeRelatedTypes.contains(type) &&
                  newConfig['nodeNum'] == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _showNodePicker(this.context);
                  }
                });
              }
            },
          ),
        );
      }
    }

    return widgets;
  }
}
