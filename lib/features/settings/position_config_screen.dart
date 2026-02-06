// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/widgets/animations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';
import '../../generated/meshtastic/config.pb.dart' as config_pb;
import '../../generated/meshtastic/config.pbenum.dart' as config_pbenum;
import '../../generated/meshtastic/admin.pbenum.dart' as admin_pbenum;
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/glass_scaffold.dart';

/// Screen for configuring GPS and position settings
class PositionConfigScreen extends ConsumerStatefulWidget {
  const PositionConfigScreen({super.key});

  @override
  ConsumerState<PositionConfigScreen> createState() =>
      _PositionConfigScreenState();
}

class _PositionConfigScreenState extends ConsumerState<PositionConfigScreen>
    with LifecycleSafeMixin {
  bool _isLoading = false;
  config_pbenum.Config_PositionConfig_GpsMode? _gpsMode;
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

  // GPS GPIO pins
  int _rxGpio = 0;
  int _txGpio = 0;
  int _gpsEnGpio = 0;

  StreamSubscription<config_pb.Config_PositionConfig>? _configSubscription;

  // Fixed position values
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final _altController = TextEditingController(text: '0');
  bool _isGettingLocation = false;

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

  Future<void> _useCurrentLocation() async {
    safeSetState(() => _isGettingLocation = true);
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          showErrorSnackBar(context, 'Location services are disabled');
        }
        return;
      }

      // Check and request permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            showErrorSnackBar(context, 'Location permission denied');
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          showErrorSnackBar(
            context,
            'Location permission permanently denied. Enable in settings.',
          );
        }
        return;
      }

      // Get the current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        ),
      );

      safeSetState(() {
        _latController.text = position.latitude.toStringAsFixed(6);
        _lonController.text = position.longitude.toStringAsFixed(6);
        _altController.text = position.altitude.toInt().toString();
      });
      if (mounted) {
        showSuccessSnackBar(context, 'Location updated from phone GPS');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to get location: $e');
      }
    } finally {
      safeSetState(() => _isGettingLocation = false);
    }
  }

  Future<void> _loadCurrentConfig() async {
    safeSetState(() => _isLoading = true);
    try {
      final protocol = ref.read(protocolServiceProvider);

      // Check if we already have cached config
      final cachedConfig = protocol.currentPositionConfig;
      if (cachedConfig != null) {
        _applyConfig(cachedConfig);
      }

      // Only request from device if connected
      if (protocol.isConnected) {
        // Listen for config response
        _configSubscription?.cancel();
        _configSubscription = protocol.positionConfigStream.listen((config) {
          if (mounted) {
            _applyConfig(config);
          }
        });

        // Request fresh config from device
        await protocol.getConfig(
          admin_pbenum.AdminMessage_ConfigType.POSITION_CONFIG,
        );

        // Wait a bit for response
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } finally {
      safeSetState(() => _isLoading = false);
    }
  }

  void _applyConfig(config_pb.Config_PositionConfig config) {
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

      // GPS GPIO pins
      _rxGpio = config.rxGpio;
      _txGpio = config.txGpio;
      _gpsEnGpio = config.gpsEnGpio;
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
    safeSetState(() => _isLoading = true);
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
        gpsMode:
            _gpsMode ?? config_pbenum.Config_PositionConfig_GpsMode.ENABLED,
        gpsUpdateInterval: _gpsUpdateInterval,
        gpsAttemptTime: _gpsAttemptTime,
        broadcastSmartMinimumDistance: _smartMinimumDistance,
        broadcastSmartMinimumIntervalSecs: _smartMinimumIntervalSecs,
        positionFlags: _buildPositionFlags(),
        rxGpio: _rxGpio,
        txGpio: _txGpio,
        gpsEnGpio: _gpsEnGpio,
      );

      if (mounted) {
        showSuccessSnackBar(context, 'Position configuration saved');
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
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold(
        title: 'Position',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isLoading ? null : _saveConfig,
              child: _isLoading
                  ? LoadingIndicator(size: 20)
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
        slivers: [
          if (_isLoading)
            const SliverFillRemaining(child: ScreenLoadingIndicator())
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              sliver: SliverList.list(
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
                              'Position Broadcast Interval',
                              style: TextStyle(
                                color: context.textPrimary,
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
                        SizedBox(height: 4),
                        Text(
                          'How often to share position',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 8),
                        SliderTheme(
                          data: SliderThemeData(
                            inactiveTrackColor: context.border,
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
                        Divider(height: 24, color: context.border),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'GPS Update Interval',
                              style: TextStyle(
                                color: context.textPrimary,
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
                        SizedBox(height: 4),
                        Text(
                          'How often GPS checks for position',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 8),
                        SliderTheme(
                          data: SliderThemeData(
                            inactiveTrackColor: context.border,
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
                        color: context.card,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _latController,
                            style: TextStyle(color: context.textPrimary),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Latitude',
                              labelStyle: TextStyle(
                                color: context.textSecondary,
                              ),
                              hintText: 'e.g., 37.7749',
                              hintStyle: TextStyle(color: Colors.grey.shade600),
                              filled: true,
                              fillColor: context.background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: context.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: context.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: context.accentColor,
                                ),
                              ),
                              prefixIcon: Icon(
                                Icons.arrow_upward,
                                color: context.textSecondary,
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          TextField(
                            controller: _lonController,
                            style: TextStyle(color: context.textPrimary),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Longitude',
                              labelStyle: TextStyle(
                                color: context.textSecondary,
                              ),
                              hintText: 'e.g., -122.4194',
                              hintStyle: TextStyle(color: Colors.grey.shade600),
                              filled: true,
                              fillColor: context.background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: context.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: context.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: context.accentColor,
                                ),
                              ),
                              prefixIcon: Icon(
                                Icons.arrow_forward,
                                color: context.textSecondary,
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          TextField(
                            controller: _altController,
                            style: TextStyle(color: context.textPrimary),
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) =>
                                FocusScope.of(context).unfocus(),
                            decoration: InputDecoration(
                              labelText: 'Altitude (meters)',
                              labelStyle: TextStyle(
                                color: context.textSecondary,
                              ),
                              hintText: 'e.g., 100',
                              hintStyle: TextStyle(color: Colors.grey.shade600),
                              filled: true,
                              fillColor: context.background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: context.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: context.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: context.accentColor,
                                ),
                              ),
                              prefixIcon: Icon(
                                Icons.height,
                                color: context.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Use Current Location Button
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isGettingLocation
                            ? null
                            : _useCurrentLocation,
                        icon: _isGettingLocation
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: context.accentColor,
                                ),
                              )
                            : Icon(
                                Icons.my_location,
                                color: context.accentColor,
                              ),
                        label: Text(
                          _isGettingLocation
                              ? 'Getting Location...'
                              : 'Use Current Location',
                          style: TextStyle(
                            color: context.accentColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: context.accentColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: context.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: context.accentColor.withValues(alpha: 0.3),
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: context.accentColor.withValues(alpha: 0.8),
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Fixed position is useful for stationary installations like routers or base stations.',
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 16),
                  if (_smartBroadcastEnabled) ...[
                    const _SectionHeader(title: 'SMART BROADCAST SETTINGS'),
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
                                'Minimum Distance',
                                style: TextStyle(
                                  color: context.textPrimary,
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
                          SizedBox(height: 4),
                          Text(
                            'Minimum distance moved before broadcasting',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 8),
                          SliderTheme(
                            data: SliderThemeData(
                              inactiveTrackColor: context.border,
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
                          Divider(height: 24, color: context.border),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Minimum Interval',
                                style: TextStyle(
                                  color: context.textPrimary,
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
                          SizedBox(height: 4),
                          Text(
                            'Minimum time between broadcasts',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 8),
                          SliderTheme(
                            data: SliderThemeData(
                              inactiveTrackColor: context.border,
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
                    SizedBox(height: 16),
                  ],
                  const _SectionHeader(title: 'GPS SETTINGS'),
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
                              'GPS Attempt Time',
                              style: TextStyle(
                                color: context.textPrimary,
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
                        SizedBox(height: 4),
                        Text(
                          'How long to wait for GPS lock before giving up',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 8),
                        SliderTheme(
                          data: SliderThemeData(
                            inactiveTrackColor: context.border,
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
                  SizedBox(height: 16),
                  const _SectionHeader(title: 'GPS GPIO'),
                  _buildGpioSettings(),
                  SizedBox(height: 16),
                  const _SectionHeader(title: 'POSITION FLAGS'),
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
        ],
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: context.bodySmallStyle?.copyWith(
                      color: context.textTertiary,
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
        if (!isLast) Divider(height: 16, color: context.border),
      ],
    );
  }

  Widget _buildGpioSettings() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // RX GPIO
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'GPS RX GPIO',
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: context.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButton<int>(
                  underline: const SizedBox.shrink(),
                  dropdownColor: context.card,
                  style: TextStyle(color: context.textPrimary),
                  value: _rxGpio,
                  items: List.generate(49, (i) {
                    return DropdownMenuItem(
                      value: i,
                      child: Text(i == 0 ? 'Unset' : 'Pin $i'),
                    );
                  }),
                  onChanged: (value) {
                    if (value != null) setState(() => _rxGpio = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'GPIO pin for GPS RX signal',
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
          Divider(height: 24, color: context.border),
          // TX GPIO
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'GPS TX GPIO',
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: context.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButton<int>(
                  underline: const SizedBox.shrink(),
                  dropdownColor: context.card,
                  style: TextStyle(color: context.textPrimary),
                  value: _txGpio,
                  items: List.generate(49, (i) {
                    return DropdownMenuItem(
                      value: i,
                      child: Text(i == 0 ? 'Unset' : 'Pin $i'),
                    );
                  }),
                  onChanged: (value) {
                    if (value != null) setState(() => _txGpio = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'GPIO pin for GPS TX signal',
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
          Divider(height: 24, color: context.border),
          // GPS Enable GPIO
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'GPS Enable GPIO',
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: context.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButton<int>(
                  underline: const SizedBox.shrink(),
                  dropdownColor: context.card,
                  style: TextStyle(color: context.textPrimary),
                  value: _gpsEnGpio,
                  items: List.generate(49, (i) {
                    return DropdownMenuItem(
                      value: i,
                      child: Text(i == 0 ? 'Unset' : 'Pin $i'),
                    );
                  }),
                  onChanged: (value) {
                    if (value != null) setState(() => _gpsEnGpio = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'GPIO pin to control GPS power',
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildGpsModeSelector() {
    final modes = [
      (
        config_pbenum.Config_PositionConfig_GpsMode.ENABLED,
        'Enabled',
        'GPS is active and reports position',
        Icons.gps_fixed,
      ),
      (
        config_pbenum.Config_PositionConfig_GpsMode.DISABLED,
        'Disabled',
        'GPS hardware is present but turned off',
        Icons.gps_off,
      ),
      (
        config_pbenum.Config_PositionConfig_GpsMode.NOT_PRESENT,
        'Not Present',
        'No GPS hardware on this device',
        Icons.gps_not_fixed,
      ),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
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
                      color: isSelected ? context.accentColor : context.border,
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
                            : context.textSecondary,
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
                                    : context.textPrimary,
                              ),
                            ),
                            Text(
                              m.$3,
                              style: TextStyle(
                                color: context.textSecondary,
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
                    style: context.bodySmallStyle?.copyWith(
                      color: context.textTertiary,
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
