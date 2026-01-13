import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/glyph_service.dart';

/// Provider for the glyph service singleton
final glyphServiceProvider = Provider<GlyphService>((ref) {
  return GlyphService();
});

/// Provider to initialize the glyph service
final glyphServiceInitProvider = FutureProvider<void>((ref) async {
  final service = ref.read(glyphServiceProvider);
  await service.init();
});

/// Provider for glyph support status (after initialization)
/// Returns true only when init completes AND device supports glyph
final glyphSupportedProvider = Provider<bool>((ref) {
  // Must wait for init to complete before checking support
  final initState = ref.watch(glyphServiceInitProvider);

  return initState.maybeWhen(
    data: (_) {
      final service = ref.read(glyphServiceProvider);
      return service.isSupported;
    },
    orElse: () => false,
  );
});
