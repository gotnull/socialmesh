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

/// Provider for glyph support status
final glyphSupportedProvider = Provider<bool>((ref) {
  final service = ref.watch(glyphServiceProvider);
  return service.isSupported;
});
