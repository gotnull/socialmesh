import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/connection/reconnect_direction_estimator.dart';
import '../services/sensors/heading_service.dart';

/// Provides the live heading service (permission + sensor access).
final headingServiceProvider = Provider<HeadingService>((ref) {
  final service = HeadingService();
  ref.onDispose(service.dispose);
  return service;
});

/// Stream of normalized heading values (0..360) or null.
final headingStreamProvider = StreamProvider<double?>(
  (ref) => ref.watch(headingServiceProvider).headingDegrees,
);

/// Emits whether the heading data is currently available.
final headingAvailabilityProvider = StreamProvider<bool>(
  (ref) => ref.watch(headingServiceProvider).isAvailable,
);

/// Riverpod notifier that wraps the estimator state.
class ReconnectDirectionEstimatorNotifier
    extends Notifier<ReconnectDirectionEstimate> {
  late final ReconnectDirectionEstimator _estimator;

  @override
  ReconnectDirectionEstimate build() {
    _estimator = ReconnectDirectionEstimator();
    return _estimator.estimate;
  }

  void addSample({required int rssi, double? headingDeg}) {
    _estimator.addSample(rssi: rssi, headingDeg: headingDeg);
    state = _estimator.estimate;
  }

  void reset() {
    _estimator.reset();
    state = _estimator.estimate;
  }
}

final reconnectDirectionEstimatorProvider =
    NotifierProvider<
      ReconnectDirectionEstimatorNotifier,
      ReconnectDirectionEstimate
    >(ReconnectDirectionEstimatorNotifier.new);

/// Aggregates compass + estimator values for the UI.
final reconnectCompassStateProvider = Provider<ReconnectCompassState>((ref) {
  final headingAsync = ref.watch(headingStreamProvider);
  final availabilityAsync = ref.watch(headingAvailabilityProvider);
  final estimator = ref.watch(reconnectDirectionEstimatorProvider);

  final headingValue = headingAsync.whenOrNull(data: (value) => value);
  final hasHeading = availabilityAsync.maybeWhen(
    data: (value) => value,
    orElse: () => false,
  );

  return ReconnectCompassState(
    currentHeadingDeg: headingValue,
    headingAvailable: hasHeading && headingValue != null,
    bestHeadingDeg: estimator.bestHeadingDeg,
    confidence: estimator.confidence,
    lastRssi: estimator.lastRssi,
    sampleCount: estimator.sampleCount,
    lastSampleAt: estimator.lastSampleAt,
  );
});

class ReconnectCompassState {
  const ReconnectCompassState({
    this.currentHeadingDeg,
    required this.headingAvailable,
    this.bestHeadingDeg,
    required this.confidence,
    this.lastRssi,
    this.sampleCount = 0,
    this.lastSampleAt,
  });

  final double? currentHeadingDeg;
  final bool headingAvailable;
  final double? bestHeadingDeg;
  final double confidence;
  final int? lastRssi;
  final int sampleCount;
  final DateTime? lastSampleAt;

  bool get hasDirection => headingAvailable && bestHeadingDeg != null;
}
