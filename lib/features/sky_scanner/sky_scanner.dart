// SPDX-License-Identifier: GPL-3.0-or-later

/// Sky Scanner — track Meshtastic nodes at altitude.
///
/// This feature enables users to:
/// - Schedule flights with their mesh nodes
/// - Track active flights with live position data from OpenSky Network
/// - Report signal receptions from airborne nodes
/// - Compete on the distance leaderboard for longest range contacts
///
/// At cruising altitude (35,000 ft), LoRa signals can reach 400+ km,
/// making this an exciting way to test the limits of mesh communication.
library;

export 'models/sky_node.dart';
export 'providers/sky_scanner_providers.dart';
export 'screens/schedule_flight_screen.dart';
export 'screens/sky_node_detail_screen.dart';
export 'screens/sky_scanner_screen.dart';
export 'services/sky_scanner_service.dart';
