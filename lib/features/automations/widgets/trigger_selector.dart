// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: haptic-feedback — onTap delegates to parent callback
import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/chip_selector.dart';
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
        // Protocol scope picker. Determines which protocol's event
        // stream fires this trigger. Default is "Any" so legacy
        // automations stay back-compat. Pinning to a single protocol
        // is the only way to silence a trigger on the other side.
        _buildProtocolFilterConfig(context),

        const SizedBox(height: AppTheme.spacing8),

        // Trigger type selector
        BouncyTap(
          onTap: () => _showTriggerTypePicker(context),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
              border: Border.all(color: context.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.warningYellow.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                  child: Icon(
                    widget.trigger.type.icon,
                    color: AppTheme.warningYellow,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.trigger.type.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: AppTheme.spacing2),
                      Text(
                        widget.trigger.type.category,
                        style: const TextStyle(
                          color: SemanticColors.disabled,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: SemanticColors.disabled),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppTheme.spacing8),

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
              label: context.l10n.automationTriggerBatteryThreshold,
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
            const SizedBox(height: AppTheme.spacing8),
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
            const SizedBox(height: AppTheme.spacing8),
            _buildNodeFilterConfig(context),
          ],
        );

      case TriggerType.nodeSilent:
        return Column(
          children: [
            _buildSliderConfig(
              context,
              label: context.l10n.automationTriggerSilentDuration,
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
            const SizedBox(height: AppTheme.spacing8),
            _buildNodeFilterConfig(context),
          ],
        );

      case TriggerType.signalWeak:
        return Column(
          children: [
            _buildSliderConfig(
              context,
              label: context.l10n.automationTriggerSignalThreshold,
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
            const SizedBox(height: AppTheme.spacing8),
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
            const SizedBox(height: AppTheme.spacing8),
            _buildNodeFilterConfig(context),
          ],
        );

      case TriggerType.scheduled:
        return _buildScheduledConfig(context);

      case TriggerType.channelActivity:
        return _buildChannelActivityConfig(context);

      case TriggerType.manual:
        return _buildManualTriggerInfo(context);

      case TriggerType.messageReceived:
        return _buildNodeFilterConfig(context);
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
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(color: SemanticColors.disabled),
              ),
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
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.automationTriggerKeywordLabel,
            style: const TextStyle(color: SemanticColors.disabled),
          ),
          const SizedBox(height: AppTheme.spacing8),
          TextField(
            maxLength: 100,
            controller: _keywordController,
            onChanged: (value) {
              widget.onChanged(
                widget.trigger.copyWith(
                  config: {...widget.trigger.config, 'keyword': value},
                ),
              );
            },
            decoration: InputDecoration(
              hintText: context.l10n.automationTriggerKeywordHint,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                borderSide: BorderSide(color: context.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                borderSide: BorderSide(color: context.border),
              ),
              counterText: '',
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
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.automationTriggerSensorNameLabel,
            style: const TextStyle(color: SemanticColors.disabled),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            context.l10n.automationTriggerSensorNameHelp,
            style: TextStyle(color: SemanticColors.muted, fontSize: 12),
          ),
          const SizedBox(height: AppTheme.spacing8),
          TextFormField(
            maxLength: 100,
            initialValue: sensorNameFilter,
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
              hintText: context.l10n.automationTriggerSensorNameHint,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                borderSide: BorderSide(color: context.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                borderSide: BorderSide(color: context.border),
              ),
              counterText: '',
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          Text(
            context.l10n.automationTriggerSensorState,
            style: const TextStyle(color: SemanticColors.disabled),
          ),
          const SizedBox(height: AppTheme.spacing8),
          ChipSelector<bool?>(
            value: detectedStateFilter,
            onChanged: _setDetectedStateFilter,
            options: [
              ChipOption(
                value: null,
                label: context.l10n.automationTriggerSensorAny,
                icon: Icons.tune,
                color: AppTheme.primaryBlue,
              ),
              ChipOption(
                value: true,
                label: context.l10n.automationTriggerSensorDetected,
                icon: Icons.sensors,
                color: AppTheme.successGreen,
              ),
              ChipOption(
                value: false,
                label: context.l10n.automationTriggerSensorClear,
                icon: Icons.sensors_off,
                color: AppTheme.errorRed,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _setDetectedStateFilter(bool? value) {
    final newConfig = Map<String, dynamic>.from(widget.trigger.config);
    if (value == null) {
      newConfig.remove('detectedStateFilter');
    } else {
      newConfig['detectedStateFilter'] = value;
    }
    widget.onChanged(widget.trigger.copyWith(config: newConfig));
  }

  Widget _buildProtocolFilterConfig(BuildContext context) {
    final current = widget.trigger.protocolFilter;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.automationTriggerProtocolLabel,
            style: const TextStyle(color: SemanticColors.disabled),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            context.l10n.automationTriggerProtocolHelp,
            style: TextStyle(color: SemanticColors.muted, fontSize: 12),
          ),
          const SizedBox(height: AppTheme.spacing12),
          ChipSelector<TriggerProtocolFilter>(
            value: current,
            onChanged: _setProtocolFilter,
            options: [
              ChipOption(
                value: TriggerProtocolFilter.any,
                label: context.l10n.automationTriggerProtocolAny,
                icon: Icons.all_inclusive,
                color: AppTheme.primaryBlue,
              ),
              ChipOption(
                value: TriggerProtocolFilter.meshtastic,
                label: context.l10n.automationTriggerProtocolMeshtastic,
                icon: Icons.router,
                color: AccentColors.cyan,
              ),
              ChipOption(
                value: TriggerProtocolFilter.meshcore,
                label: context.l10n.automationTriggerProtocolMeshcore,
                icon: Icons.hub,
                color: AppTheme.primaryMagenta,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Writes `protocolFilter` to trigger config. Drops the key entirely
  // when the user selects `any` so legacy JSON shape (no key) is
  // restored - keeps the persisted config tidy and means automations
  // created before this slice never grow a synthetic field.
  void _setProtocolFilter(TriggerProtocolFilter value) {
    final newConfig = Map<String, dynamic>.from(widget.trigger.config);
    if (value == TriggerProtocolFilter.any) {
      newConfig.remove('protocolFilter');
    } else {
      newConfig['protocolFilter'] = value.name;
    }
    widget.onChanged(widget.trigger.copyWith(config: newConfig));
  }

  Widget _buildNodeFilterConfig(BuildContext context) {
    final selectedNodeNum = widget.trigger.nodeNum;
    final selectedNode = selectedNodeNum != null
        ? widget.availableNodes
              .where((n) => n.nodeNum == selectedNodeNum)
              .firstOrNull
        : null;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.automationTriggerNodeFilterLabel,
            style: TextStyle(color: SemanticColors.disabled),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            context.l10n.automationTriggerNodeFilterHelp,
            style: TextStyle(color: SemanticColors.muted, fontSize: 12),
          ),
          const SizedBox(height: AppTheme.spacing12),
          BouncyTap(
            onTap: () => _showNodePicker(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: context.background,
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                border: Border.all(color: context.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: selectedNode != null
                          ? AccentColors.blue.withValues(alpha: 0.2)
                          : SemanticColors.disabled.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                    ),
                    child: Icon(
                      selectedNode != null ? Icons.router : Icons.all_inclusive,
                      size: 18,
                      color: selectedNode != null
                          ? AccentColors.blue
                          : SemanticColors.disabled,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedNode?.longName ??
                              selectedNode?.shortName ??
                              context.l10n.automationTriggerAnyNode,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: selectedNode != null
                                ? context.textPrimary
                                : SemanticColors.disabled,
                          ),
                        ),
                        if (selectedNode != null)
                          Text(
                            '!${selectedNode.nodeNum.toRadixString(16)}',
                            style: TextStyle(
                              color: SemanticColors.muted,
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
                        padding: const EdgeInsets.all(AppTheme.spacing4),
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: SemanticColors.muted,
                        ),
                      ),
                    )
                  else
                    const Icon(
                      Icons.chevron_right,
                      color: SemanticColors.disabled,
                    ),
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
      title: context.l10n.automationTriggerSelectNode,
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
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, size: 18, color: SemanticColors.disabled),
              SizedBox(width: AppTheme.spacing8),
              Text(
                context.l10n.automationTriggerGeofenceCenter,
                style: TextStyle(color: SemanticColors.disabled),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  maxLength: 20,
                  controller: _latController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.automationTriggerLatitude,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                    ),
                    counterText: '',
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
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: TextField(
                  maxLength: 20,
                  controller: _lonController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.automationTriggerLongitude,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                    ),
                    counterText: '',
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
          const SizedBox(height: AppTheme.spacing16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.automationTriggerRadius,
                style: const TextStyle(color: SemanticColors.disabled),
              ),
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
              label: Text(context.l10n.automationTriggerPickOnMap),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduledConfig(BuildContext context) {
    final scheduleType =
        widget.trigger.config['scheduleType'] as String? ?? 'daily';
    final hour = widget.trigger.config['hour'] as int? ?? 9;
    final minute = widget.trigger.config['minute'] as int? ?? 0;
    final daysOfWeek =
        (widget.trigger.config['daysOfWeek'] as List<dynamic>?)?.cast<int>() ??
        [1, 2, 3, 4, 5]; // Weekdays default
    final intervalMinutes =
        widget.trigger.config['intervalMinutes'] as int? ?? 60;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.automationTriggerScheduleType,
            style: const TextStyle(color: SemanticColors.disabled),
          ),
          const SizedBox(height: AppTheme.spacing8),
          ChipSelector<String>(
            value: scheduleType,
            onChanged: (selected) {
              final newConfig = Map<String, dynamic>.from(
                widget.trigger.config,
              );
              newConfig['scheduleType'] = selected;
              newConfig['schedule'] = _buildScheduleString(
                selected,
                hour,
                minute,
                daysOfWeek,
                intervalMinutes,
              );
              widget.onChanged(widget.trigger.copyWith(config: newConfig));
            },
            options: [
              ChipOption(
                value: 'daily',
                label: context.l10n.automationTriggerDaily,
                icon: Icons.today,
                color: AppTheme.primaryBlue,
              ),
              ChipOption(
                value: 'weekly',
                label: context.l10n.automationTriggerWeekly,
                icon: Icons.calendar_view_week,
                color: AppTheme.primaryMagenta,
              ),
              ChipOption(
                value: 'interval',
                label: context.l10n.automationTriggerInterval,
                icon: Icons.timer_outlined,
                color: AppTheme.successGreen,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing16),

          // Time picker for daily/weekly
          if (scheduleType == 'daily' || scheduleType == 'weekly') ...[
            Text(
              context.l10n.automationTriggerTime,
              style: const TextStyle(color: SemanticColors.disabled),
            ),
            const SizedBox(height: AppTheme.spacing8),
            BouncyTap(
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: hour, minute: minute),
                );
                if (!mounted) return;
                if (time != null) {
                  final newConfig = Map<String, dynamic>.from(
                    widget.trigger.config,
                  );
                  newConfig['hour'] = time.hour;
                  newConfig['minute'] = time.minute;
                  newConfig['schedule'] = _buildScheduleString(
                    scheduleType,
                    time.hour,
                    time.minute,
                    daysOfWeek,
                    intervalMinutes,
                  );
                  widget.onChanged(widget.trigger.copyWith(config: newConfig));
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: context.border),
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      TimeOfDay(hour: hour, minute: minute).format(context),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const Icon(
                      Icons.access_time,
                      color: SemanticColors.disabled,
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Days of week picker for weekly
          if (scheduleType == 'weekly') ...[
            const SizedBox(height: AppTheme.spacing16),
            Text(
              context.l10n.automationTriggerDays,
              style: const TextStyle(color: SemanticColors.disabled),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Wrap(
              spacing: 8,
              children: [
                for (final day in [
                  (1, context.l10n.automationTriggerDayMon),
                  (2, context.l10n.automationTriggerDayTue),
                  (3, context.l10n.automationTriggerDayWed),
                  (4, context.l10n.automationTriggerDayThu),
                  (5, context.l10n.automationTriggerDayFri),
                  (6, context.l10n.automationTriggerDaySat),
                  (0, context.l10n.automationTriggerDaySun),
                ])
                  FilterChip(
                    label: Text(day.$2),
                    selected: daysOfWeek.contains(day.$1),
                    onSelected: (selected) {
                      final newDays = List<int>.from(daysOfWeek);
                      if (selected) {
                        if (!newDays.contains(day.$1)) newDays.add(day.$1);
                      } else {
                        newDays.remove(day.$1);
                      }
                      // Ensure at least one day is selected
                      if (newDays.isEmpty) return;
                      final newConfig = Map<String, dynamic>.from(
                        widget.trigger.config,
                      );
                      newConfig['daysOfWeek'] = newDays;
                      newConfig['schedule'] = _buildScheduleString(
                        scheduleType,
                        hour,
                        minute,
                        newDays,
                        intervalMinutes,
                      );
                      widget.onChanged(
                        widget.trigger.copyWith(config: newConfig),
                      );
                    },
                  ),
              ],
            ),
          ],

          // Interval picker for interval type
          if (scheduleType == 'interval') ...[
            const SizedBox(height: AppTheme.spacing16),
            _buildSliderConfig(
              context,
              label: context.l10n.automationTriggerRepeatEvery,
              value: intervalMinutes.toDouble(),
              min: 15, // WorkManager minimum
              max: 1440, // 24 hours
              suffix: ' min',
              divisions: 95,
              onChanged: (value) {
                final newConfig = Map<String, dynamic>.from(
                  widget.trigger.config,
                );
                newConfig['intervalMinutes'] = value.round();
                newConfig['schedule'] = _buildScheduleString(
                  scheduleType,
                  hour,
                  minute,
                  daysOfWeek,
                  value.round(),
                );
                widget.onChanged(widget.trigger.copyWith(config: newConfig));
              },
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              _formatInterval(context, intervalMinutes),
              style: TextStyle(color: SemanticColors.muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  String _buildScheduleString(
    String scheduleType,
    int hour,
    int minute,
    List<int> daysOfWeek,
    int intervalMinutes,
  ) {
    switch (scheduleType) {
      case 'daily':
        return 'daily:$hour:$minute'; // lint-allow: hardcoded-string
      case 'weekly':
        final days = daysOfWeek.join(',');
        return 'weekly:$hour:$minute:$days'; // lint-allow: hardcoded-string
      case 'interval':
        return 'interval:$intervalMinutes'; // lint-allow: hardcoded-string
      default:
        return '';
    }
  }

  String _formatInterval(BuildContext context, int minutes) {
    if (minutes < 60) {
      return context.l10n.automationTriggerEveryMinutes(minutes);
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) {
      return context.l10n.automationTriggerEveryHours(
        hours,
        hours > 1 ? 's' : '',
      );
    }
    return context.l10n.automationTriggerEveryHoursMinutes(
      hours,
      hours > 1 ? 's' : '',
      mins,
    );
  }

  Widget _buildChannelActivityConfig(BuildContext context) {
    final channelIndex = widget.trigger.config['channelIndex'] as int?;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.automationTriggerChannelLabel,
            style: const TextStyle(color: SemanticColors.disabled),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            context.l10n.automationTriggerChannelHelp,
            style: TextStyle(color: SemanticColors.muted, fontSize: 12),
          ),
          const SizedBox(height: AppTheme.spacing8),
          DropdownButtonFormField<int?>(
            value: channelIndex,
            decoration: InputDecoration(
              hintText: context.l10n.automationTriggerAnyChannel,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                borderSide: BorderSide(color: context.border),
              ),
            ),
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Text(context.l10n.automationTriggerAnyChannel),
              ),
              for (var i = 0; i < 8; i++)
                DropdownMenuItem<int>(
                  value: i,
                  child: Text(context.l10n.automationTriggerChannelIndex(i)),
                ),
            ],
            onChanged: (value) {
              final newConfig = Map<String, dynamic>.from(
                widget.trigger.config,
              );
              if (value == null) {
                newConfig.remove('channelIndex');
              } else {
                newConfig['channelIndex'] = value;
              }
              widget.onChanged(widget.trigger.copyWith(config: newConfig));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildManualTriggerInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AccentColors.blue, size: 20),
              const SizedBox(width: AppTheme.spacing8),
              Text(
                context.l10n.automationTriggerManualTitle,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            context.l10n.automationTriggerManualDescription,
            style: TextStyle(
              color: SemanticColors.disabled,
              fontSize: 13,
              height: 1.5,
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
        builder: (context, scrollController) => SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: SemanticColors.muted,
                  borderRadius: BorderRadius.circular(AppTheme.radius2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  context.l10n.automationTriggerSelectTrigger,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: AppTheme.spacing8),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: _buildTriggerList(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Category order for consistent display
  static const _categoryOrder = [
    'Node Status', // lint-allow: hardcoded-string
    'Battery',
    'Messages',
    'Location',
    'Time',
    'Signal',
    'Sensors',
    'Manual',
  ];

  List<Widget> _buildTriggerList(BuildContext context) {
    final grouped = <String, List<TriggerType>>{};
    for (final type in TriggerType.values) {
      grouped.putIfAbsent(type.category, () => []).add(type);
    }

    final widgets = <Widget>[];
    for (final category in _categoryOrder) {
      final triggers = grouped[category];
      if (triggers == null || triggers.isEmpty) continue;

      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 16, 16, 8),
          child: Text(
            category,
            style: const TextStyle(
              color: SemanticColors.disabled,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      );

      for (final type in triggers) {
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
                borderRadius: BorderRadius.circular(AppTheme.radius10),
              ),
              child: Icon(
                type.icon,
                size: 20,
                color: type == widget.trigger.type
                    ? Theme.of(context).colorScheme.primary
                    : SemanticColors.disabled,
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
