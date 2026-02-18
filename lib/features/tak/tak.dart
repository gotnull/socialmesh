// SPDX-License-Identifier: GPL-3.0-or-later
/// TAK/CoT gateway feature — receives normalized CoT events from the
/// Socialmesh TAK Gateway and displays them in a diagnostic viewer.
///
/// Gated by [AppFeatureFlags.isTakGatewayEnabled].
library;

export 'models/tak_event.dart';
export 'services/tak_database.dart';
export 'services/tak_gateway_client.dart';
export 'providers/tak_providers.dart';
export 'screens/tak_screen.dart';
export 'screens/tak_event_detail_screen.dart';
