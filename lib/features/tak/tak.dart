// SPDX-License-Identifier: GPL-3.0-or-later
/// TAK/CoT gateway feature — receives normalized CoT events from the
/// Socialmesh TAK Gateway, persists them to SQLite, and renders them
/// on the map with MIL-STD-2525 affiliation coloring.
///
/// Gated by [AppFeatureFlags.isTakGatewayEnabled].
library;

export 'models/tak_event.dart';
export 'models/tak_publish_config.dart';
export 'providers/tak_filter_provider.dart';
export 'providers/tak_providers.dart';
export 'providers/tak_settings_provider.dart';
export 'providers/tak_tracking_provider.dart';
export 'screens/tak_event_detail_screen.dart';
export 'screens/tak_screen.dart';
export 'screens/tak_settings_screen.dart';
export 'services/tak_database.dart';
export 'services/tak_gateway_client.dart';
export 'services/tak_position_publisher.dart';
export 'services/tak_stale_monitor.dart';
export 'utils/cot_affiliation.dart';
export 'widgets/tak_filter_bar.dart';
export 'widgets/tak_map_layer.dart';
export 'widgets/tak_map_marker.dart';
export 'widgets/tak_trail_layer.dart';
