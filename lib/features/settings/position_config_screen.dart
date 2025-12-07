import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/widgets/animations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../utils/snackbar.dart';
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
  int _gpsAttemptTime = 30;
  int _smartMinimumDistance = 100;
  int _smartMinimumIntervalSecs = 30;

  // Position flags (bitmask)
  bool _includeAltitude = true;
  bool _includeAltitudeMsl = false;
  bool _includeGeoidalSeparation = false;
  bool _includeDop = false;
  bool _includeHvdop = false;
  bool _includeSatsinview = false;
  bool _includeSeqNo = false;
  bool _includeTimestamp = false;
  bool _includeHeading = false;
  bool _includeSpeed = false;

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
      _gpsAttemptTime = config.gpsAttemptTime > 0 ? config.gpsAttemptTime : 30;
      _smartMinimumDistance = config.broadcastSmartMinimumDistance > 0
          ? config.broadcastSmartMinimumDistance
          : 100;
      _smartMinimumIntervalSecs = config.broadcastSmartMinimumIntervalSecs > 0
          ? config.broadcastSmartMinimumIntervalSecs
          : 30;

      // Parse position flags bitmask
      final flags = config.positionFlags;
      _includeAltitude = (flags & 1) != 0;
      _includeAltitudeMsl = (flags & 2) != 0;
      _includeGeoidalSeparation = (flags & 4) != 0;
      _includeDop = (flags & 8) != 0;
      _includeHvdop = (flags & 16) != 0;
      _includeSatsinview = (flags & 32) != 0;
      _includeSeqNo = (flags & 64) != 0;
      _includeTimestamp = (flags & 128) != 0;
      _includeHeading = (flags & 256) != 0;
      _includeSpeed = (flags & 512) != 0;
    });
  }

  int _buildPositionFlags() {
    int flags = 0;
    if (_includeAltitude) flags |= 1;
    if (_includeAltitudeMsl) flags |= 2;
    if (_includeGeoidalSeparation) flags |= 4;
    if (_includeDop) flags |= 8;
    if (_includeHvdop) flags |= 16;
    if (_includeSatsinview) flags |= 32;
    if (_includeSeqNo) flags |= 64;
    if (_includeTimestamp) flags |= 128;
    if (_includeHeading) flags |= 256;
    if (_includeSpeed) flags |= 512;
    return flags;
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
        gpsMode: _gpsMode ?? pb.Config_PositionConfig_GpsMode.ENABLED,
        gpsUpdateInterval: _gpsUpdateInterval,
        gpsAttemptTime: _gpsAttemptTime,
        broadcastSmartMinimumDistance: _smartMinimumDistance,
        broadcastSmartMinimumIntervalSecs: _smartMinimumIntervalSecs,
        positionFlags: _buildPositionFlags(),
      );

      if (mounted) {
        showAppSnackBar(context, 'Position configuration saved');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to save: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppTheme.darkBackground,
        appBar: AppBar(
          backgroundColor: AppTheme.darkBackground,
          title: const Text(
            'Position',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _isLoading ? null : _saveConfig,
                child: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.accentColor,
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
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  const _SectionHeader(title: 'GPS MODE'),
                  _buildGpsModeSelector(),
                  SizedBox(height: 16),
                  const _SectionHeader(title: 'BROADCAST SETTINGS'),
                  _SettingsTile(
                    icon: Icons.tune,
                    iconColor: _smartBroadcastEnabled
                        ? context.accentColor
                        : null,
                    title: 'Smart Broadcast',
                    subtitle:
                        'Only broadcast when position changes significantly',
                    trailing: ThemedSwitch(
                      value: _smartBroadcastEnabled,
                      onChanged: (value) {
                        HapticFeedback.selectionClick();
                        setState(() => _smartBroadcastEnabled = value);
                      },
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
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
                            Text(
                              'Position Broadcast Interval',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: context.accentColor.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _formatDuration(_positionBroadcastSecs),
                                style: TextStyle(
                                  color: context.accentColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'How often to share position',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 8),
                        SliderTheme(
                          data: SliderThemeData(
                            inactiveTrackColor: AppTheme.darkBorder,
                            thumbColor: context.accentColor,
                            overlayColor: context.accentColor.withValues(
                              alpha: 0.2,
                            ),
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: _positionBroadcastSecs.toDouble(),
                            min: 60,
                            max: 86400,
                            divisions: 20,
                            onChanged: (value) {
                              setState(
                                () => _positionBroadcastSecs = value.toInt(),
                              );
                            },
                          ),
                        ),
                        const Divider(height: 24, color: AppTheme.darkBorder),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'GPS Update Interval',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: context.accentColor.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${_gpsUpdateInterval}s',
                                style: TextStyle(
                                  color: context.accentColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'How often GPS checks for position',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 8),
                        SliderTheme(
                          data: SliderThemeData(
                            inactiveTrackColor: AppTheme.darkBorder,
                            thumbColor: context.accentColor,
                            overlayColor: context.accentColor.withValues(
                              alpha: 0.2,
                            ),
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: _gpsUpdateInterval.toDouble(),
                            min: 5,
                            max: 120,
                            divisions: 23,
                            onChanged: (value) {
                              setState(
                                () => _gpsUpdateInterval = value.toInt(),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  const _SectionHeader(title: 'FIXED POSITION'),
                  _SettingsTile(
                    icon: Icons.pin_drop,
                    iconColor: _fixedPosition ? context.accentColor : null,
                    title: 'Use Fixed Position',
                    subtitle: 'Manually set position instead of using GPS',
                    trailing: ThemedSwitch(
                      value: _fixedPosition,
                      onChanged: (value) {
                        HapticFeedback.selectionClick();
                        setState(() => _fixedPosition = value);
                      },
                    ),
                  ),
                  if (_fixedPosition) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _latController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Latitude',
                              labelStyle: const TextStyle(
                                color: AppTheme.textSecondary,
                              ),
                              hintText: 'e.g., 37.7749',
                              hintStyle: TextStyle(color: Colors.grey.shade600),
                              filled: true,
                              fillColor: AppTheme.darkBackground,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppTheme.darkBorder,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: AppTheme.darkBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: context.accentColor,
                                ),
                              ),
                              prefixIcon: const Icon(
                                Icons.arrow_upward,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _lonController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Longitude',
                              labelStyle: const TextStyle(
                                color: AppTheme.textSecondary,
                              ),
                              hintText: 'e.g., -122.4194',
                              hintStyle: TextStyle(color: Colors.grey.shade600),
                              filled: true,
                              fillColor: AppTheme.darkBackground,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppTheme.darkBorder,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: AppTheme.darkBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: context.accentColor,
                                ),
                              ),
                              prefixIcon: const Icon(
                                Icons.arrow_forward,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _altController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) =>
                                FocusScope.of(context).unfocus(),
                            decoration: InputDecoration(
                              labelText: 'Altitude (meters)',
                              labelStyle: const TextStyle(
                                color: AppTheme.textSecondary,
                              ),
                              hintText: 'e.g., 100',
                              hintStyle: TextStyle(color: Colors.grey.shade600),
                              filled: true,
                              fillColor: AppTheme.darkBackground,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppTheme.darkBorder,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: AppTheme.darkBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: context.accentColor,
                                ),
                              ),
                              prefixIcon: const Icon(
                                Icons.height,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.graphBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.graphBlue.withValues(alpha: 0.3),
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppTheme.graphBlue.withValues(alpha: 0.8),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Fixed position is useful for stationary installations like routers or base stations.',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_smartBroadcastEnabled) ...[
                    const _SectionHeader(title: 'SMART BROADCAST SETTINGS'),
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ),
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
                              Text(
                                'Minimum Distance',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: context.accentColor.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${_smartMinimumDistance}m',
                                  style: TextStyle(
                                    color: context.accentColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Minimum distance moved before broadcasting',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 8),
                          SliderTheme(
                            data: SliderThemeData(
                              inactiveTrackColor: AppTheme.darkBorder,
                              thumbColor: context.accentColor,
                              overlayColor: context.accentColor.withValues(
                                alpha: 0.2,
                              ),
                              trackHeight: 4,
                            ),
                            child: Slider(
                              value: _smartMinimumDistance.toDouble(),
                              min: 10,
                              max: 500,
                              divisions: 49,
                              onChanged: (value) {
                                setState(
                                  () => _smartMinimumDistance = value.toInt(),
                                );
                              },
                            ),
                          ),
                          const Divider(height: 24, color: AppTheme.darkBorder),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Minimum Interval',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: context.accentColor.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${_smartMinimumIntervalSecs}s',
                                  style: TextStyle(
                                    color: context.accentColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Minimum time between broadcasts',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 8),
                          SliderTheme(
                            data: SliderThemeData(
                              inactiveTrackColor: AppTheme.darkBorder,
                              thumbColor: context.accentColor,
                              overlayColor: context.accentColor.withValues(
                                alpha: 0.2,
                              ),
                              trackHeight: 4,
                            ),
                            child: Slider(
                              value: _smartMinimumIntervalSecs.toDouble(),
                              min: 10,
                              max: 300,
                              divisions: 29,
                              onChanged: (value) {
                                setState(
                                  () =>
                                      _smartMinimumIntervalSecs = value.toInt(),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const _SectionHeader(title: 'GPS SETTINGS'),
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
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
                            Text(
                              'GPS Attempt Time',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: context.accentColor.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${_gpsAttemptTime}s',
                                style: TextStyle(
                                  color: context.accentColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'How long to wait for GPS lock before giving up',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 8),
                        SliderTheme(
                          data: SliderThemeData(
                            inactiveTrackColor: AppTheme.darkBorder,
                            thumbColor: context.accentColor,
                            overlayColor: context.accentColor.withValues(
                              alpha: 0.2,
                            ),
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: _gpsAttemptTime.toDouble(),
                            min: 10,
                            max: 300,
                            divisions: 29,
                            onChanged: (value) {
                              setState(() => _gpsAttemptTime = value.toInt());
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _SectionHeader(title: 'POSITION FLAGS'),
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildFlagToggle(
                          'Include Altitude',
                          'Include altitude in position reports',
                          _includeAltitude,
                          (v) => setState(() => _includeAltitude = v),
                        ),
                        _buildFlagToggle(
                          'Include Altitude MSL',
                          'Include altitude above mean sea level',
                          _includeAltitudeMsl,
                          (v) => setState(() => _includeAltitudeMsl = v),
                        ),
                        _buildFlagToggle(
                          'Include Geoidal Separation',
                          'Include geoidal separation value',
                          _includeGeoidalSeparation,
                          (v) => setState(() => _includeGeoidalSeparation = v),
                        ),
                        _buildFlagToggle(
                          'Include DOP',
                          'Include dilution of precision',
                          _includeDop,
                          (v) => setState(() => _includeDop = v),
                        ),
                        _buildFlagToggle(
                          'Include HVDOP',
                          'Include horizontal/vertical DOP',
                          _includeHvdop,
                          (v) => setState(() => _includeHvdop = v),
                        ),
                        _buildFlagToggle(
                          'Include Sats in View',
                          'Include number of satellites visible',
                          _includeSatsinview,
                          (v) => setState(() => _includeSatsinview = v),
                        ),
                        _buildFlagToggle(
                          'Include Sequence Number',
                          'Include position sequence number',
                          _includeSeqNo,
                          (v) => setState(() => _includeSeqNo = v),
                        ),
                        _buildFlagToggle(
                          'Include Timestamp',
                          'Include GPS timestamp',
                          _includeTimestamp,
                          (v) => setState(() => _includeTimestamp = v),
                        ),
                        _buildFlagToggle(
                          'Include Heading',
                          'Include heading/direction of travel',
                          _includeHeading,
                          (v) => setState(() => _includeHeading = v),
                        ),
                        _buildFlagToggle(
                          'Include Speed',
                          'Include ground speed',
                          _includeSpeed,
                          (v) => setState(() => _includeSpeed = v),
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }

  Widget _buildFlagToggle(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged, {
    bool isLast = false,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            ThemedSwitch(
              value: value,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                onChanged(v);
              },
            ),
          ],
        ),
        if (!isLast) const Divider(height: 16, color: AppTheme.darkBorder),
      ],
    );
  }

  Widget _buildGpsModeSelector() {
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                          ? context.accentColor
                          : AppTheme.darkBorder,
                      width: isSelected ? 2 : 1,
                    ),
                    color: isSelected
                        ? context.accentColor.withValues(alpha: 0.1)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        m.$4,
                        color: isSelected
                            ? context.accentColor
                            : AppTheme.textSecondary,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.$2,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? context.accentColor
                                    : Colors.white,
                              ),
                            ),
                            Text(
                              m.$3,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle, color: context.accentColor),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
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
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textTertiary,
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
