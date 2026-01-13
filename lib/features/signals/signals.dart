/// Signals module - mesh-first ephemeral content
///
/// Signals are v1's mesh-first alternative to social posts:
/// - Ephemeral with configurable TTL
/// - Local-first storage and display
/// - No feed fan-out, no likes
/// - Sorted by proximity and expiry
library;

// Screens
export 'screens/presence_feed_screen.dart';
export 'screens/create_signal_screen.dart';
export 'screens/signal_detail_screen.dart';

// Widgets
export 'widgets/signal_card.dart';
export 'widgets/signal_grid_card.dart';
export 'widgets/signal_gallery_view.dart';
export 'widgets/signal_composer.dart';
export 'widgets/ttl_selector.dart';
export 'widgets/dust_dissolve_signal_card.dart';
