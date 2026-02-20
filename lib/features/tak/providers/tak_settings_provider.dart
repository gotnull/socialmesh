// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging.dart';
import '../models/tak_publish_config.dart';

/// Keys used for TAK settings in SharedPreferences.
abstract final class TakSettingsKeys {
  static const gatewayUrl = 'tak_gateway_url';
  static const autoConnect = 'tak_auto_connect';
  static const publishEnabled = 'tak_publish_enabled';
  static const publishInterval = 'tak_publish_interval';
  static const callsign = 'tak_callsign';
  static const mapLayerVisible = 'tak_map_layer_visible';
  static const proximityAlertEnabled = 'tak_proximity_alert_enabled';
  static const proximityRadiusKm = 'tak_proximity_radius_km';
  static const proximityAffiliations = 'tak_proximity_affiliations';
}

/// Immutable snapshot of all TAK user-facing settings.
class TakSettings {
  /// Custom gateway URL (empty = use env default).
  final String gatewayUrl;

  /// Whether to auto-connect when TAK screens are opened.
  final bool autoConnect;

  /// Whether outbound position publishing is enabled.
  final bool publishEnabled;

  /// Publish interval in seconds.
  final int publishInterval;

  /// User-specified callsign override (empty = use node name).
  final String callsign;

  /// Whether the TAK map layer is visible by default.
  final bool mapLayerVisible;

  /// Whether proximity alerts are enabled.
  final bool proximityAlertEnabled;

  /// Proximity alert radius in kilometers.
  final double proximityRadiusKm;

  /// Affiliations that trigger proximity alerts.
  final Set<String> proximityAffiliations;

  const TakSettings({
    this.gatewayUrl = '',
    this.autoConnect = true,
    this.publishEnabled = false,
    this.publishInterval = 60,
    this.callsign = '',
    this.mapLayerVisible = true,
    this.proximityAlertEnabled = false,
    this.proximityRadiusKm = 5.0,
    this.proximityAffiliations = const {'hostile', 'unknown'},
  });

  /// Build a [TakPublishConfig] from these settings.
  TakPublishConfig toPublishConfig() => TakPublishConfig(
    enabled: publishEnabled,
    intervalSeconds: publishInterval,
    callsignOverride: callsign.isNotEmpty ? callsign : null,
  );

  TakSettings copyWith({
    String? gatewayUrl,
    bool? autoConnect,
    bool? publishEnabled,
    int? publishInterval,
    String? callsign,
    bool? mapLayerVisible,
    bool? proximityAlertEnabled,
    double? proximityRadiusKm,
    Set<String>? proximityAffiliations,
  }) {
    return TakSettings(
      gatewayUrl: gatewayUrl ?? this.gatewayUrl,
      autoConnect: autoConnect ?? this.autoConnect,
      publishEnabled: publishEnabled ?? this.publishEnabled,
      publishInterval: publishInterval ?? this.publishInterval,
      callsign: callsign ?? this.callsign,
      mapLayerVisible: mapLayerVisible ?? this.mapLayerVisible,
      proximityAlertEnabled:
          proximityAlertEnabled ?? this.proximityAlertEnabled,
      proximityRadiusKm: proximityRadiusKm ?? this.proximityRadiusKm,
      proximityAffiliations:
          proximityAffiliations ?? this.proximityAffiliations,
    );
  }
}

/// Allowed publish interval values in seconds.
const takPublishIntervalOptions = [30, 60, 120, 300];

/// Manages TAK settings backed by SharedPreferences.
class TakSettingsNotifier extends AsyncNotifier<TakSettings> {
  @override
  Future<TakSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final proximityAffList = prefs.getStringList(
      TakSettingsKeys.proximityAffiliations,
    );
    final settings = TakSettings(
      gatewayUrl: prefs.getString(TakSettingsKeys.gatewayUrl) ?? '',
      autoConnect: prefs.getBool(TakSettingsKeys.autoConnect) ?? true,
      publishEnabled: prefs.getBool(TakSettingsKeys.publishEnabled) ?? false,
      publishInterval: prefs.getInt(TakSettingsKeys.publishInterval) ?? 60,
      callsign: prefs.getString(TakSettingsKeys.callsign) ?? '',
      mapLayerVisible: prefs.getBool(TakSettingsKeys.mapLayerVisible) ?? true,
      proximityAlertEnabled:
          prefs.getBool(TakSettingsKeys.proximityAlertEnabled) ?? false,
      proximityRadiusKm:
          prefs.getDouble(TakSettingsKeys.proximityRadiusKm) ?? 5.0,
      proximityAffiliations:
          proximityAffList?.toSet() ?? const {'hostile', 'unknown'},
    );
    AppLogging.tak(
      'TakSettingsNotifier loaded: '
      'autoConnect=${settings.autoConnect}, '
      'publish=${settings.publishEnabled}, '
      'interval=${settings.publishInterval}s',
    );
    return settings;
  }

  Future<void> setGatewayUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(TakSettingsKeys.gatewayUrl, value);
    AppLogging.tak('Settings updated: ${TakSettingsKeys.gatewayUrl}=$value');
    state = AsyncData(
      (state.value ?? const TakSettings()).copyWith(gatewayUrl: value),
    );
  }

  Future<void> setAutoConnect(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(TakSettingsKeys.autoConnect, value);
    AppLogging.tak('Settings updated: ${TakSettingsKeys.autoConnect}=$value');
    state = AsyncData(
      (state.value ?? const TakSettings()).copyWith(autoConnect: value),
    );
  }

  Future<void> setPublishEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(TakSettingsKeys.publishEnabled, value);
    AppLogging.tak(
      'Settings updated: ${TakSettingsKeys.publishEnabled}=$value',
    );
    state = AsyncData(
      (state.value ?? const TakSettings()).copyWith(publishEnabled: value),
    );
  }

  Future<void> setPublishInterval(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(TakSettingsKeys.publishInterval, value);
    AppLogging.tak(
      'Settings updated: ${TakSettingsKeys.publishInterval}=$value',
    );
    state = AsyncData(
      (state.value ?? const TakSettings()).copyWith(publishInterval: value),
    );
  }

  Future<void> setCallsign(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(TakSettingsKeys.callsign, value);
    AppLogging.tak('Settings updated: ${TakSettingsKeys.callsign}=$value');
    state = AsyncData(
      (state.value ?? const TakSettings()).copyWith(callsign: value),
    );
  }

  Future<void> setMapLayerVisible(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(TakSettingsKeys.mapLayerVisible, value);
    AppLogging.tak(
      'Settings updated: ${TakSettingsKeys.mapLayerVisible}=$value',
    );
    state = AsyncData(
      (state.value ?? const TakSettings()).copyWith(mapLayerVisible: value),
    );
  }

  Future<void> setProximityAlertEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(TakSettingsKeys.proximityAlertEnabled, value);
    AppLogging.tak(
      'Settings updated: ${TakSettingsKeys.proximityAlertEnabled}=$value',
    );
    state = AsyncData(
      (state.value ?? const TakSettings()).copyWith(
        proximityAlertEnabled: value,
      ),
    );
  }

  Future<void> setProximityRadiusKm(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(TakSettingsKeys.proximityRadiusKm, value);
    AppLogging.tak(
      'Settings updated: ${TakSettingsKeys.proximityRadiusKm}=$value',
    );
    state = AsyncData(
      (state.value ?? const TakSettings()).copyWith(proximityRadiusKm: value),
    );
  }

  Future<void> setProximityAffiliations(Set<String> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      TakSettingsKeys.proximityAffiliations,
      value.toList(),
    );
    AppLogging.tak(
      'Settings updated: ${TakSettingsKeys.proximityAffiliations}=$value',
    );
    state = AsyncData(
      (state.value ?? const TakSettings()).copyWith(
        proximityAffiliations: value,
      ),
    );
  }
}

/// TAK settings provider (async, SharedPreferences-backed).
final takSettingsProvider =
    AsyncNotifierProvider<TakSettingsNotifier, TakSettings>(
      TakSettingsNotifier.new,
    );
