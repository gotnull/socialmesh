import 'dart:collection';
import 'dart:math' as math;

/// Normalized estimate produced by [ReconnectDirectionEstimator].
class ReconnectDirectionEstimate {
  const ReconnectDirectionEstimate({
    this.bestHeadingDeg,
    this.confidence = 0,
    this.lastRssi,
    this.sampleCount = 0,
    this.lastSampleAt,
  });

  final double? bestHeadingDeg;
  final double confidence;
  final int? lastRssi;
  final int sampleCount;
  final DateTime? lastSampleAt;
}

class _DirectionSample {
  _DirectionSample(this.timestamp, this.headingDeg, this.rssi);

  final DateTime timestamp;
  final double? headingDeg;
  final int rssi;
}

/// Estimates the relative heading toward the target device based on RSSI + phone heading.
class ReconnectDirectionEstimator {
  ReconnectDirectionEstimator({
    this.windowDuration = const Duration(seconds: 10),
    this.maxSamples = 30,
  }) : assert(windowDuration > Duration.zero),
       assert(maxSamples > 0);

  final Duration windowDuration;
  final int maxSamples;
  final _samples = ListQueue<_DirectionSample>();
  int? _lastRssi;
  DateTime? _lastSampleAt;

  /// Adds a sample measured while scanning for the target device.
  void addSample({required int rssi, double? headingDeg, DateTime? timestamp}) {
    final now = timestamp ?? DateTime.now();
    _samples.addLast(_DirectionSample(now, headingDeg, rssi));
    _lastRssi = rssi;
    _lastSampleAt = now;
    _pruneSamples(now);
  }

  /// Clears the rolling window.
  void reset() {
    _samples.clear();
    _lastRssi = null;
    _lastSampleAt = null;
  }

  /// Returns the current estimate derived from the stored samples.
  ReconnectDirectionEstimate get estimate {
    final now = DateTime.now();
    _pruneSamples(now);

    final headingSamples = _samples
        .where((sample) => sample.headingDeg != null)
        .toList();

    if (headingSamples.isEmpty) {
      return ReconnectDirectionEstimate(
        confidence: 0,
        lastRssi: _lastRssi,
        sampleCount: 0,
        lastSampleAt: _lastSampleAt,
      );
    }

    double sumX = 0;
    double sumY = 0;
    double totalWeight = 0;
    double maxWeight = 0;
    double weightSum = 0;

    for (final sample in headingSamples) {
      final recencyFactor =
          (1 -
                  (now.difference(sample.timestamp).inMilliseconds /
                      windowDuration.inMilliseconds))
              .clamp(0.0, 1.0);
      final weight =
          _rssiWeight(sample.rssi) *
          (0.4 + 0.6 * recencyFactor.clamp(0.0, 1.0));
      final radians = sample.headingDeg! * math.pi / 180;
      sumX += math.cos(radians) * weight;
      sumY += math.sin(radians) * weight;
      totalWeight += weight;
      weightSum += weight;
      maxWeight = math.max(maxWeight, weight);
    }

    if (totalWeight == 0) {
      return ReconnectDirectionEstimate(
        confidence: 0,
        lastRssi: _lastRssi,
        sampleCount: headingSamples.length,
        lastSampleAt: _lastSampleAt,
      );
    }

    final headingRadians = math.atan2(sumY, sumX);
    final headingDeg = (headingRadians * 180 / math.pi + 360) % 360;
    final averageWeight = weightSum / headingSamples.length;
    final contrastFactor = maxWeight <= 0
        ? 0.0
        : ((maxWeight - averageWeight) / maxWeight).clamp(0.0, 1.0);
    final countFactor = (headingSamples.length / maxSamples)
        .clamp(0.0, 1.0)
        .toDouble();
    final confidence = (countFactor * 0.6 + contrastFactor * 0.4).clamp(
      0.0,
      1.0,
    );

    return ReconnectDirectionEstimate(
      bestHeadingDeg: headingDeg,
      confidence: confidence,
      lastRssi: _lastRssi,
      sampleCount: headingSamples.length,
      lastSampleAt: _lastSampleAt,
    );
  }

  double _rssiWeight(int rssi) {
    final normalized = (rssi + 100).clamp(0, 100).toDouble();
    return math.pow(1.04, normalized).toDouble();
  }

  void _pruneSamples(DateTime reference) {
    while (_samples.isNotEmpty &&
        reference.difference(_samples.first.timestamp) > windowDuration) {
      _samples.removeFirst();
    }
    while (_samples.length > maxSamples) {
      _samples.removeFirst();
    }
  }
}
