import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ifttt/ifttt_service.dart';
import 'app_providers.dart';

/// IFTTT configuration state provider
final iftttConfigProvider = Provider<IftttConfig>((ref) {
  final service = ref.watch(iftttServiceProvider);
  return service.config;
});

/// IFTTT enabled state provider
final iftttEnabledProvider = Provider<bool>((ref) {
  final service = ref.watch(iftttServiceProvider);
  return service.isActive;
});
