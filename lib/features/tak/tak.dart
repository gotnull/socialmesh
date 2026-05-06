// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
/// TAK/CoT gateway feature — receives normalized CoT events from the
/// SocialMesh TAK Gateway, persists them to SQLite, and renders them
/// on the map with MIL-STD-2525 affiliation coloring.
///
/// Gated by [AppFeatureFlags.isTakGatewayEnabled].
library;

export 'models/tak_event.dart';
export 'models/tak_publish_config.dart';
export 'models/video_stream.dart';
export 'models/video_stream_state.dart';
export 'providers/tak_filter_provider.dart';
export 'providers/tak_providers.dart';
export 'providers/tak_settings_provider.dart';
export 'providers/tak_tracking_provider.dart';
export 'providers/tak_video_providers.dart';
export 'screens/tak_event_detail_screen.dart';
export 'screens/tak_screen.dart';
export 'screens/tak_settings_screen.dart';
export 'screens/tak_video_player_screen.dart';
export 'screens/tak_video_publish_screen.dart';
export 'screens/tak_video_streams_screen.dart';
export 'services/tak_database.dart';
export 'services/tak_gateway_client.dart';
export 'services/tak_position_publisher.dart';
export 'services/tak_stale_monitor.dart';
export 'services/tak_video_stream_service.dart';
export 'utils/cot_affiliation.dart';
export 'widgets/tak_filter_bar.dart';
export 'widgets/tak_map_layer.dart';
export 'widgets/tak_map_marker.dart';
export 'widgets/tak_trail_layer.dart';
