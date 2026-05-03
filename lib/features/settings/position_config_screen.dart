// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/settings_primitives.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../providers/countdown_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';
import '../../generated/meshtastic/config.pb.dart' as config_pb;
import '../../generated/meshtastic/config.pbenum.dart' as config_pbenum;
import '../../generated/meshtastic/admin.pbenum.dart' as admin_pbenum;
import '../../services/protocol/admin_target.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/glass_scaffold.dart';

/// Screen for configuring GPS and position settings
class PositionConfigScreen extends ConsumerStatefulWidget {
  const PositionConfigScreen({super.key});

  @override
  ConsumerState<PositionConfigScreen> createState() =>
      _PositionConfigScreenState();
}

/// Discrete position broadcast intervals matching the official Meshtastic iOS
/// app (IntervalConfiguration.broadcastMedium). Minimum 1 hour to protect
/// communities with MQTT bots that block nodes broadcasting below 10 minutes.
const _kBroadcastIntervals = <int>[
  3600, // 1h
  7200, // 2h
  10800, // 3h
  14400, // 4h
  18000, // 5h
  21600, // 6h
  43200, // 12h
  64800, // 18h
  86400, // 24h
  129600, // 36h
  172800, // 48h
  259200, // 72h
  2147483647, // never
];

/// Discrete GPS update intervals matching the official iOS app.
const _kGpsUpdateIntervals = <int>[
  0, // firmware default (30s)
  30, // 30s
  60, // 1m
  120, // 2m
  300, // 5m
  600, // 10m
  900, // 15m
  1800, // 30m
  3600, // 1h
  21600, // 6h
  43200, // 12h
  86400, // 24h
  2147483647, // on boot only
];

/// Smart broadcast minimum interval options matching the iOS app.
const _kSmartMinIntervals = <int>[
  15, // 15s
  30, // 30s
  45, // 45s
  60, // 1m
  300, // 5m
  600, // 10m
  900, // 15m
  1800, // 30m
  3600, // 1h
];

class _PositionConfigScreenState extends ConsumerState<PositionConfigScreen>
    with LifecycleSafeMixin {
  bool _isLoading = false;
  bool _isSaving = false;
  config_pbenum.Config_PositionConfig_GpsMode? _gpsMode;
  bool _smartBroadcastEnabled = true;
  bool _fixedPosition = false;
  int _positionBroadcastSecs = 3600;
  int _gpsUpdateInterval = 0;
  int _smartMinimumDistance = 50;
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
    final l10n = context.l10n;
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          showActionSnackBar(
            context,
            l10n.positionConfigLocationDisabled,
            actionLabel: l10n.positionConfigOpenSettings,
            onAction: () => Geolocator.openLocationSettings(),
            type: SnackBarType.warning,
          );
        }
        return;
      }

      // Check and request permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            showActionSnackBar(
              context,
              l10n.positionConfigPermissionDenied,
              actionLabel: l10n.positionConfigOpenSettings,
              onAction: () => Geolocator.openAppSettings(),
              type: SnackBarType.warning,
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          showActionSnackBar(
            context,
            l10n.positionConfigPermissionPermanentlyDenied,
            actionLabel: l10n.positionConfigOpenSettings,
            onAction: () => Geolocator.openAppSettings(),
            type: SnackBarType.warning,
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
        showSuccessSnackBar(context, l10n.positionConfigLocationUpdated);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          l10n.positionConfigLocationFailed(e.toString()),
        );
      }
    } finally {
      safeSetState(() => _isGettingLocation = false);
    }
  }

  Future<void> _loadCurrentConfig() async {
    safeSetState(() => _isLoading = true);
    try {
      final protocol = ref.read(protocolServiceProvider);
      final target = AdminTarget.fromNullable(
        ref.read(remoteAdminTargetProvider),
      );

      // Check if we already have cached config (local only)
      if (target.isLocal) {
        final cachedConfig = protocol.currentPositionConfig;
        if (cachedConfig != null) {
          _applyConfig(cachedConfig);
        }
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
          target: target,
        );

        // Wait a bit for response
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      // Device disconnected between isConnected check and getConfig call
      // Catches both StateError (from protocol layer) and PlatformException
      // (from BLE layer) when device disconnects during the config request
      AppLogging.protocol('Position config load aborted: $e');
    } finally {
      safeSetState(() => _isLoading = false);
    }
  }

  void _applyConfig(config_pb.Config_PositionConfig config) {
    safeSetState(() {
      _gpsMode = config.gpsMode;
      _smartBroadcastEnabled = config.positionBroadcastSmartEnabled;
      _fixedPosition = config.fixedPosition;

      // Preserve 0 from the device — it means "firmware default".
      // Snap to the nearest allowed discrete value for broadcast interval.
      _positionBroadcastSecs = _snapToNearest(
        config.positionBroadcastSecs > 0 ? config.positionBroadcastSecs : 3600,
        _kBroadcastIntervals,
      );
      _gpsUpdateInterval = _snapToNearest(
        config.gpsUpdateInterval,
        _kGpsUpdateIntervals,
      );
      _smartMinimumDistance = config.broadcastSmartMinimumDistance > 0
          ? config.broadcastSmartMinimumDistance
          : 50;
      _smartMinimumIntervalSecs = _snapToNearest(
        config.broadcastSmartMinimumIntervalSecs > 0
            ? config.broadcastSmartMinimumIntervalSecs
            : 30,
        _kSmartMinIntervals,
      );

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

  /// Snap [value] to the closest entry in [allowed]. If [allowed] is empty or
  /// [value] is already in the list, returns [value] unchanged.
  static int _snapToNearest(int value, List<int> allowed) {
    if (allowed.isEmpty) return value;
    if (allowed.contains(value)) return value;
    int best = allowed.first;
    int bestDist = (value - best).abs();
    for (final v in allowed) {
      final d = (value - v).abs();
      if (d < bestDist) {
        best = v;
        bestDist = d;
      }
    }
    return best;
  }

  bool get _isGpsEnabled =>
      _gpsMode == config_pbenum.Config_PositionConfig_GpsMode.ENABLED;

  Future<void> _saveConfig() async {
    safeSetState(() => _isSaving = true);
    final l10n = context.l10n;
    try {
      final protocol = ref.read(protocolServiceProvider);
      final target = AdminTarget.fromNullable(
        ref.read(remoteAdminTargetProvider),
      );

      // Fixed position set/remove is local-only (uses localAdmin routing)
      if (target.isLocal) {
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
      }

      await protocol.setPositionConfig(
        positionBroadcastSecs: _positionBroadcastSecs,
        positionBroadcastSmartEnabled: _smartBroadcastEnabled,
        fixedPosition: _fixedPosition,
        gpsMode:
            _gpsMode ?? config_pbenum.Config_PositionConfig_GpsMode.ENABLED,
        gpsUpdateInterval: _gpsUpdateInterval,
        broadcastSmartMinimumDistance: _smartMinimumDistance,
        broadcastSmartMinimumIntervalSecs: _smartMinimumIntervalSecs,
        positionFlags: _buildPositionFlags(),
        rxGpio: _rxGpio,
        txGpio: _txGpio,
        gpsEnGpio: _gpsEnGpio,
        target: target,
      );

      if (mounted) {
        showSuccessSnackBar(context, l10n.positionConfigSaved);
        if (target.isLocal) {
          ref
              .read(countdownProvider.notifier)
              .startDeviceRebootCountdown(reason: 'position config saved');
        }
        safeNavigatorPop();
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, l10n.positionConfigSaveFailed(e.toString()));
      }
    } finally {
      safeSetState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRemote = ref.watch(remoteAdminTargetProvider) != null;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold(
        title: context.l10n.positionConfigTitle,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: (_isLoading || _isSaving) ? null : _saveConfig,
              child: _isSaving
                  ? LoadingIndicator(size: 20)
                  : Text(
                      context.l10n.positionConfigSave,
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
                  SettingsSectionHeader(
                    title: context.l10n.positionConfigSectionGpsMode,
                  ),
                  _buildGpsModeSelector(),
                  SizedBox(height: AppTheme.spacing16),
                  SettingsSectionHeader(
                    title: context.l10n.positionConfigSectionBroadcast,
                  ),
                  SettingsTile(
                    icon: Icons.tune,
                    iconColor: _smartBroadcastEnabled
                        ? context.accentColor
                        : null,
                    title: context.l10n.positionConfigSmartBroadcast,
                    subtitle: context.l10n.positionConfigSmartBroadcastSubtitle,
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
                    padding: const EdgeInsets.all(AppTheme.spacing16),
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                context.l10n.positionConfigBroadcastInterval,
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            _IntervalChip(
                              label: _formatDuration(_positionBroadcastSecs),
                            ),
                          ],
                        ),
                        SizedBox(height: AppTheme.spacing4),
                        Text(
                          context.l10n.positionConfigBroadcastIntervalSubtitle,
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: AppTheme.spacing8),
                        _DiscreteIntervalSelector(
                          value: _positionBroadcastSecs,
                          intervals: _kBroadcastIntervals,
                          formatLabel: _formatDuration,
                          onChanged: (v) =>
                              setState(() => _positionBroadcastSecs = v),
                        ),
                        if (_isGpsEnabled) ...[
                          Divider(height: 24, color: context.border),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  context.l10n.positionConfigGpsUpdateInterval,
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              _IntervalChip(
                                label: _formatGpsInterval(_gpsUpdateInterval),
                              ),
                            ],
                          ),
                          SizedBox(height: AppTheme.spacing4),
                          Text(
                            context
                                .l10n
                                .positionConfigGpsUpdateIntervalSubtitle,
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: AppTheme.spacing8),
                          _DiscreteIntervalSelector(
                            value: _gpsUpdateInterval,
                            intervals: _kGpsUpdateIntervals,
                            formatLabel: _formatGpsInterval,
                            onChanged: (v) =>
                                setState(() => _gpsUpdateInterval = v),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: AppTheme.spacing16),
                  // Fixed position: shown when GPS is NOT enabled or
                  // already toggled on (matches official iOS behaviour).
                  // Local-only (uses localAdmin routing).
                  if (!isRemote && (!_isGpsEnabled || _fixedPosition)) ...[
                    SettingsSectionHeader(
                      title: context.l10n.positionConfigSectionFixed,
                    ),
                    SettingsTile(
                      icon: Icons.pin_drop,
                      iconColor: _fixedPosition ? context.accentColor : null,
                      title: context.l10n.positionConfigUseFixed,
                      subtitle: context.l10n.positionConfigUseFixedSubtitle,
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
                        padding: const EdgeInsets.all(AppTheme.spacing16),
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius12,
                          ),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              maxLength: 100,
                              controller: _latController,
                              style: TextStyle(color: context.textPrimary),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: context.l10n.positionConfigLatitude,
                                labelStyle: TextStyle(
                                  color: context.textSecondary,
                                ),
                                hintText:
                                    context.l10n.positionConfigLatitudeHint,
                                hintStyle: TextStyle(
                                  color: SemanticColors.muted,
                                ),
                                filled: true,
                                fillColor: context.background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radius8,
                                  ),
                                  borderSide: BorderSide(color: context.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radius8,
                                  ),
                                  borderSide: BorderSide(color: context.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radius8,
                                  ),
                                  borderSide: BorderSide(
                                    color: context.accentColor,
                                  ),
                                ),
                                prefixIcon: Icon(
                                  Icons.arrow_upward,
                                  color: context.textSecondary,
                                ),
                                counterText: '',
                              ),
                            ),
                            SizedBox(height: AppTheme.spacing16),
                            TextField(
                              maxLength: 100,
                              controller: _lonController,
                              style: TextStyle(color: context.textPrimary),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: context.l10n.positionConfigLongitude,
                                labelStyle: TextStyle(
                                  color: context.textSecondary,
                                ),
                                hintText:
                                    context.l10n.positionConfigLongitudeHint,
                                hintStyle: TextStyle(
                                  color: SemanticColors.muted,
                                ),
                                filled: true,
                                fillColor: context.background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radius8,
                                  ),
                                  borderSide: BorderSide(color: context.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radius8,
                                  ),
                                  borderSide: BorderSide(color: context.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radius8,
                                  ),
                                  borderSide: BorderSide(
                                    color: context.accentColor,
                                  ),
                                ),
                                prefixIcon: Icon(
                                  Icons.arrow_forward,
                                  color: context.textSecondary,
                                ),
                                counterText: '',
                              ),
                            ),
                            SizedBox(height: AppTheme.spacing16),
                            TextField(
                              maxLength: 100,
                              controller: _altController,
                              style: TextStyle(color: context.textPrimary),
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) =>
                                  FocusScope.of(context).unfocus(),
                              decoration: InputDecoration(
                                labelText: context.l10n.positionConfigAltitude,
                                labelStyle: TextStyle(
                                  color: context.textSecondary,
                                ),
                                hintText:
                                    context.l10n.positionConfigAltitudeHint,
                                hintStyle: TextStyle(
                                  color: SemanticColors.muted,
                                ),
                                filled: true,
                                fillColor: context.background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radius8,
                                  ),
                                  borderSide: BorderSide(color: context.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radius8,
                                  ),
                                  borderSide: BorderSide(color: context.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radius8,
                                  ),
                                  borderSide: BorderSide(
                                    color: context.accentColor,
                                  ),
                                ),
                                prefixIcon: Icon(
                                  Icons.height,
                                  color: context.textSecondary,
                                ),
                                counterText: '',
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
                                ? context.l10n.positionConfigGettingLocation
                                : context.l10n.positionConfigUseCurrentLocation,
                            style: TextStyle(
                              color: context.accentColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: context.accentColor),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius10,
                              ),
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
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius12,
                          ),
                          border: Border.all(
                            color: context.accentColor.withValues(alpha: 0.3),
                          ),
                        ),
                        padding: const EdgeInsets.all(AppTheme.spacing16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: context.accentColor.withValues(alpha: 0.8),
                              size: 20,
                            ),
                            SizedBox(width: AppTheme.spacing12),
                            Expanded(
                              child: Text(
                                context.l10n.positionConfigFixedInfo,
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
                  ], // end if (!isRemote)
                  SizedBox(height: AppTheme.spacing16),
                  if (_smartBroadcastEnabled) ...[
                    SettingsSectionHeader(
                      title: context.l10n.positionConfigSectionSmartBroadcast,
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ),
                      padding: const EdgeInsets.all(AppTheme.spacing16),
                      decoration: BoxDecoration(
                        color: context.card,
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                context.l10n.positionConfigMinDistance,
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
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radius6,
                                  ),
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
                          SizedBox(height: AppTheme.spacing4),
                          Text(
                            context.l10n.positionConfigMinDistanceSubtitle,
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: AppTheme.spacing8),
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
                              value: _smartMinimumDistance.toDouble().clamp(
                                10,
                                150,
                              ),
                              min: 10,
                              max: 150,
                              divisions: 28,
                              onChanged: (value) {
                                // Round to nearest multiple of 5
                                // (iOS uses multiples of 5)
                                final rounded = (value / 5).round() * 5;
                                setState(
                                  () => _smartMinimumDistance = rounded.clamp(
                                    10,
                                    150,
                                  ),
                                );
                              },
                            ),
                          ),
                          Divider(height: 24, color: context.border),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  context.l10n.positionConfigMinInterval,
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              _IntervalChip(
                                label: _formatDuration(
                                  _smartMinimumIntervalSecs,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: AppTheme.spacing4),
                          Text(
                            context.l10n.positionConfigMinIntervalSubtitle,
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: AppTheme.spacing8),
                          _DiscreteIntervalSelector(
                            value: _smartMinimumIntervalSecs,
                            intervals: _kSmartMinIntervals,
                            formatLabel: _formatDuration,
                            onChanged: (v) =>
                                setState(() => _smartMinimumIntervalSecs = v),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppTheme.spacing16),
                  ],
                  // GPS Settings and GPIO only shown when GPS is enabled
                  // (matches official Meshtastic iOS behaviour)
                  if (_isGpsEnabled) ...[
                    SettingsSectionHeader(
                      title: context.l10n.positionConfigSectionGpsGpio,
                    ),
                    _buildGpioSettings(),
                    SizedBox(height: AppTheme.spacing16),
                  ],
                  SettingsSectionHeader(
                    title: context.l10n.positionConfigSectionFlags,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Text(
                      context.l10n.positionConfigFlagsInfo,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    padding: const EdgeInsets.all(AppTheme.spacing16),
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                    child: Column(
                      children: [
                        // Position Flags section: conditional visibility
                        // matches the official iOS app structure.
                        _buildFlagToggle(
                          context.l10n.positionConfigFlagAltitude,
                          context.l10n.positionConfigFlagAltitudeDesc,
                          _includeAltitude,
                          (v) => setState(() => _includeAltitude = v),
                        ),
                        _buildFlagToggle(
                          context.l10n.positionConfigFlagSatsInView,
                          context.l10n.positionConfigFlagSatsInViewDesc,
                          _includeSatsinview,
                          (v) => setState(() => _includeSatsinview = v),
                        ),
                        _buildFlagToggle(
                          context.l10n.positionConfigFlagSeqNumber,
                          context.l10n.positionConfigFlagSeqNumberDesc,
                          _includeSeqNo,
                          (v) => setState(() => _includeSeqNo = v),
                        ),
                        _buildFlagToggle(
                          context.l10n.positionConfigFlagTimestamp,
                          context.l10n.positionConfigFlagTimestampDesc,
                          _includeTimestamp,
                          (v) => setState(() => _includeTimestamp = v),
                        ),
                        _buildFlagToggle(
                          context.l10n.positionConfigFlagHeading,
                          context.l10n.positionConfigFlagHeadingDesc,
                          _includeHeading,
                          (v) => setState(() => _includeHeading = v),
                        ),
                        _buildFlagToggle(
                          context.l10n.positionConfigFlagSpeed,
                          context.l10n.positionConfigFlagSpeedDesc,
                          _includeSpeed,
                          (v) => setState(() => _includeSpeed = v),
                          isLast: !_includeAltitude && !_includeDop,
                        ),
                        // Advanced flags: conditional on parent flags
                        // (iOS: MSL/Geoidal only when Altitude on)
                        if (_includeAltitude) ...[
                          _buildFlagToggle(
                            context.l10n.positionConfigFlagMsl,
                            context.l10n.positionConfigFlagMslDesc,
                            _includeAltitudeMsl,
                            (v) => setState(() => _includeAltitudeMsl = v),
                          ),
                          _buildFlagToggle(
                            context.l10n.positionConfigFlagGeoidalSep,
                            context.l10n.positionConfigFlagGeoidalSepDesc,
                            _includeGeoidalSeparation,
                            (v) =>
                                setState(() => _includeGeoidalSeparation = v),
                            isLast: !_includeDop,
                          ),
                        ],
                        // iOS: HVDOP only when DOP is on
                        _buildFlagToggle(
                          context.l10n.positionConfigFlagDop,
                          context.l10n.positionConfigFlagDopDesc,
                          _includeDop,
                          (v) => setState(() => _includeDop = v),
                          isLast: !_includeDop,
                        ),
                        if (_includeDop)
                          _buildFlagToggle(
                            context.l10n.positionConfigFlagHvdop,
                            context.l10n.positionConfigFlagHvdopDesc,
                            _includeHvdop,
                            (v) => setState(() => _includeHvdop = v),
                            isLast: true,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing32),
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
                  const SizedBox(height: AppTheme.spacing2),
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
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // RX GPIO
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.positionConfigGpsRxGpio,
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: context.background,
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
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
                      child: Text(
                        i == 0
                            ? context.l10n.positionConfigGpioPinUnset
                            : context.l10n.positionConfigGpioPinLabel(i),
                      ),
                    );
                  }),
                  onChanged: (value) {
                    if (value != null) setState(() => _rxGpio = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            context.l10n.positionConfigGpsRxGpioDesc,
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
          Divider(height: 24, color: context.border),
          // TX GPIO
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.positionConfigGpsTxGpio,
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: context.background,
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
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
                      child: Text(
                        i == 0
                            ? context.l10n.positionConfigGpioPinUnset
                            : context.l10n.positionConfigGpioPinLabel(i),
                      ),
                    );
                  }),
                  onChanged: (value) {
                    if (value != null) setState(() => _txGpio = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            context.l10n.positionConfigGpsTxGpioDesc,
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
          Divider(height: 24, color: context.border),
          // GPS Enable GPIO
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.positionConfigGpsEnableGpio,
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: context.background,
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
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
                      child: Text(
                        i == 0
                            ? context.l10n.positionConfigGpioPinUnset
                            : context.l10n.positionConfigGpioPinLabel(i),
                      ),
                    );
                  }),
                  onChanged: (value) {
                    if (value != null) setState(() => _gpsEnGpio = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            context.l10n.positionConfigGpsEnableGpioDesc,
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
        context.l10n.positionConfigGpsModeEnabled,
        context.l10n.positionConfigGpsModeEnabledDesc,
        Icons.gps_fixed,
      ),
      (
        config_pbenum.Config_PositionConfig_GpsMode.DISABLED,
        context.l10n.positionConfigGpsModeDisabled,
        context.l10n.positionConfigGpsModeDisabledDesc,
        Icons.gps_off,
      ),
      (
        config_pbenum.Config_PositionConfig_GpsMode.NOT_PRESENT,
        context.l10n.positionConfigGpsModeNotPresent,
        context.l10n.positionConfigGpsModeNotPresentDesc,
        Icons.gps_not_fixed,
      ),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
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
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spacing12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
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
                      SizedBox(width: AppTheme.spacing12),
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
    if (seconds >= 2147483647) return context.l10n.positionConfigIntervalNever;
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m';
    if (seconds < 86400) return '${seconds ~/ 3600}h';
    return '${seconds ~/ 86400}d';
  }

  String _formatGpsInterval(int seconds) {
    if (seconds == 0) return context.l10n.positionConfigIntervalDefault;
    if (seconds >= 2147483647) return context.l10n.positionConfigIntervalOnBoot;
    return _formatDuration(seconds);
  }
}

/// A horizontally-scrolling row of tappable interval chips that replaces the
/// continuous sliders. Each chip shows a formatted label. The selected chip is
/// highlighted with the accent colour.
class _DiscreteIntervalSelector extends StatelessWidget {
  final int value;
  final List<int> intervals;
  final String Function(int) formatLabel;
  final ValueChanged<int> onChanged;

  const _DiscreteIntervalSelector({
    required this.value,
    required this.intervals,
    required this.formatLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: intervals.map((v) {
          final selected = v == value;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(
                formatLabel(v),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? Colors.white : context.textPrimary,
                ),
              ),
              selected: selected,
              showCheckmark: false,
              selectedColor: context.accentColor,
              backgroundColor: context.background,
              side: BorderSide(
                color: selected ? context.accentColor : context.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
              onSelected: (_) {
                HapticFeedback.selectionClick();
                onChanged(v);
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Small accent-coloured badge showing the currently selected interval value.
class _IntervalChip extends StatelessWidget {
  final String label;

  const _IntervalChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radius6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.accentColor,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}
