// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:shared_preferences/shared_preferences.dart';

/// App-side persisted MQTT preferences that are not part of the radio's
/// MQTT module config.
///
/// Currently exposes the **Map Reporting opt-in** — a GDPR / CCPA
/// disclaimer the user must tick before the app-side proxy will broadcast
/// the device's real-time location through the public MQTT broker.
///
/// The radio's `mapReportingEnabled` flag plus this app-local
/// `mapReportingOptIn` flag together gate the `shouldReportLocation`
/// field of `MapReportSettings` at config-save time, and the proxy's
/// connect path at runtime — both conditions must be true before the
/// firmware is authorized to emit unencrypted location.
class MqttPreferences {
  /// Storage key — kept stable across releases; do not rename.
  static const String mapReportingOptInKey =
      'mqtt.map_reporting_opt_in'; // lint-allow: hardcoded-string

  /// Reads the current opt-in flag. Defaults to `false` so a fresh
  /// install never accidentally consents.
  static Future<bool> getMapReportingOptIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(mapReportingOptInKey) ?? false;
  }

  /// Writes the opt-in flag. Pass `false` to revoke consent.
  static Future<void> setMapReportingOptIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(mapReportingOptInKey, value);
  }
}
