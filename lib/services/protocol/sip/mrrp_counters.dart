// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// MRRP instrumentation counters for the harness budget/timing panel.
///
/// Tracks sends blocked, dedup hits, timeouts, advert cadence,
/// and per-service latency metrics. Session-scoped (not persisted).
library;

/// Aggregated MRRP counters for budget and timing diagnostics.
class MrrpCounters {
  /// Called after any counter is recorded, to trigger UI rebuilds.
  void Function()? onChange;

  void _notify() => onChange?.call();

  // --- Advert counters ---
  int serviceAdvertsSent = 0;
  int serviceAdvertsReceived = 0;

  // --- Service directory counters ---
  int serviceDirRequestsSent = 0;
  int serviceDirRequestsReceived = 0;
  int serviceDirResponsesSent = 0;
  int serviceDirResponsesReceived = 0;

  // --- Request/response counters (global + per-service) ---
  int requestsSent = 0;
  int requestsReceived = 0;
  int responsesSent = 0;
  int responsesReceived = 0;

  final Map<int, int> requestsSentPerService = {};
  final Map<int, int> requestsReceivedPerService = {};
  final Map<int, int> responsesSentPerService = {};
  final Map<int, int> responsesReceivedPerService = {};

  // --- Error counters (global + per-status) ---
  int errorsSent = 0;
  int errorsReceived = 0;
  final Map<int, int> errorsReceivedPerStatus = {};

  // --- Dedup counters ---
  int duplicateRequestsIgnored = 0;
  int duplicateResponsesIgnored = 0;
  int cachedResponsesServed = 0;

  // --- Timeout counters ---
  int requestTimeouts = 0;
  int responseTimeouts = 0;
  final Map<int, int> requestTimeoutsPerService = {};

  // --- Cancellation counters ---
  int requestCancellations = 0;

  // --- Harness counters ---
  final Map<String, int> harnessActionsPerformed = {};
  final Map<String, int> simulatedFaultsInjected = {};

  // --- Rejection counters ---
  int payloadTooLargeRejections = 0;
  int budgetThrottles = 0;

  // --- Advert timing ---
  DateTime? lastAdvertSent;
  DateTime? lastAdvertReceived;

  /// Per-service latency tracking.
  final Map<int, _LatencyTracker> _latencies = {};

  // --- Legacy aliases for backward compat with budget panel ---
  int get sendsBlocked => budgetThrottles;
  int get dedupHits => duplicateRequestsIgnored + duplicateResponsesIgnored;
  int get timeouts => requestTimeouts + responseTimeouts;
  int get advertsSent => serviceAdvertsSent;
  int get advertsReceived => serviceAdvertsReceived;

  // --- Recording methods ---

  void recordServiceAdvertSent() {
    serviceAdvertsSent++;
    lastAdvertSent = DateTime.now();
    _notify();
  }

  void recordServiceAdvertReceived() {
    serviceAdvertsReceived++;
    lastAdvertReceived = DateTime.now();
    _notify();
  }

  void recordServiceDirRequestSent() {
    serviceDirRequestsSent++;
    _notify();
  }

  void recordServiceDirRequestReceived() {
    serviceDirRequestsReceived++;
    _notify();
  }

  void recordServiceDirResponseSent() {
    serviceDirResponsesSent++;
    _notify();
  }

  void recordServiceDirResponseReceived() {
    serviceDirResponsesReceived++;
    _notify();
  }

  void recordRequestSent({int? serviceId}) {
    requestsSent++;
    if (serviceId != null) {
      requestsSentPerService[serviceId] =
          (requestsSentPerService[serviceId] ?? 0) + 1;
    }
    _notify();
  }

  void recordRequestReceived({int? serviceId}) {
    requestsReceived++;
    if (serviceId != null) {
      requestsReceivedPerService[serviceId] =
          (requestsReceivedPerService[serviceId] ?? 0) + 1;
    }
    _notify();
  }

  void recordResponseSent({int? serviceId}) {
    responsesSent++;
    if (serviceId != null) {
      responsesSentPerService[serviceId] =
          (responsesSentPerService[serviceId] ?? 0) + 1;
    }
    _notify();
  }

  void recordResponseReceived({int? serviceId}) {
    responsesReceived++;
    if (serviceId != null) {
      responsesReceivedPerService[serviceId] =
          (responsesReceivedPerService[serviceId] ?? 0) + 1;
    }
    _notify();
  }

  void recordErrorSent() {
    errorsSent++;
    _notify();
  }

  void recordErrorReceived({int? statusCode}) {
    errorsReceived++;
    if (statusCode != null) {
      errorsReceivedPerStatus[statusCode] =
          (errorsReceivedPerStatus[statusCode] ?? 0) + 1;
    }
    _notify();
  }

  void recordDuplicateRequestIgnored() {
    duplicateRequestsIgnored++;
    _notify();
  }

  void recordDuplicateResponseIgnored() {
    duplicateResponsesIgnored++;
    _notify();
  }

  void recordCachedResponseServed() {
    cachedResponsesServed++;
    _notify();
  }

  void recordRequestTimeout({int? serviceId}) {
    requestTimeouts++;
    if (serviceId != null) {
      requestTimeoutsPerService[serviceId] =
          (requestTimeoutsPerService[serviceId] ?? 0) + 1;
    }
    _notify();
  }

  void recordResponseTimeout() {
    responseTimeouts++;
    _notify();
  }

  void recordRequestCancellation() {
    requestCancellations++;
    _notify();
  }

  void recordHarnessAction(String actionType) {
    harnessActionsPerformed[actionType] =
        (harnessActionsPerformed[actionType] ?? 0) + 1;
    _notify();
  }

  void recordSimulatedFault(String faultType) {
    simulatedFaultsInjected[faultType] =
        (simulatedFaultsInjected[faultType] ?? 0) + 1;
    _notify();
  }

  void recordPayloadTooLargeRejection() {
    payloadTooLargeRejections++;
    _notify();
  }

  void recordBudgetThrottle() {
    budgetThrottles++;
    _notify();
  }

  // --- Legacy recording aliases ---
  void recordSendBlocked() => recordBudgetThrottle();
  void recordDedupHit() => recordDuplicateRequestIgnored();
  void recordTimeout() => recordRequestTimeout();

  void recordAdvertSent() => recordServiceAdvertSent();
  void recordAdvertReceived() => recordServiceAdvertReceived();

  void recordLatency(int serviceId, Duration latency) {
    _latencies.putIfAbsent(serviceId, _LatencyTracker.new);
    _latencies[serviceId]!.record(latency);
    _notify();
  }

  /// Get latency stats for a service. Returns null if no data.
  LatencyStats? getLatencyStats(int serviceId) {
    final tracker = _latencies[serviceId];
    if (tracker == null || tracker.count == 0) return null;
    return LatencyStats(
      min: tracker.min,
      max: tracker.max,
      average: tracker.average,
      last: tracker.last,
      count: tracker.count,
    );
  }

  /// All service IDs with latency data.
  List<int> get serviceIdsWithLatency => _latencies.keys.toList();

  void reset() {
    serviceAdvertsSent = 0;
    serviceAdvertsReceived = 0;
    serviceDirRequestsSent = 0;
    serviceDirRequestsReceived = 0;
    serviceDirResponsesSent = 0;
    serviceDirResponsesReceived = 0;
    requestsSent = 0;
    requestsReceived = 0;
    responsesSent = 0;
    responsesReceived = 0;
    requestsSentPerService.clear();
    requestsReceivedPerService.clear();
    responsesSentPerService.clear();
    responsesReceivedPerService.clear();
    errorsSent = 0;
    errorsReceived = 0;
    errorsReceivedPerStatus.clear();
    duplicateRequestsIgnored = 0;
    duplicateResponsesIgnored = 0;
    cachedResponsesServed = 0;
    requestTimeouts = 0;
    responseTimeouts = 0;
    requestTimeoutsPerService.clear();
    requestCancellations = 0;
    harnessActionsPerformed.clear();
    simulatedFaultsInjected.clear();
    payloadTooLargeRejections = 0;
    budgetThrottles = 0;
    lastAdvertSent = null;
    lastAdvertReceived = null;
    _latencies.clear();
    _notify();
  }
}

class _LatencyTracker {
  Duration _min = const Duration(days: 1);
  Duration _max = Duration.zero;
  Duration _total = Duration.zero;
  Duration _last = Duration.zero;
  int _count = 0;

  void record(Duration latency) {
    if (latency < _min) _min = latency;
    if (latency > _max) _max = latency;
    _total += latency;
    _last = latency;
    _count++;
  }

  Duration get min => _min;
  Duration get max => _max;
  Duration get last => _last;
  int get count => _count;
  Duration get average => _count > 0
      ? Duration(microseconds: _total.inMicroseconds ~/ _count)
      : Duration.zero;
}

/// Immutable snapshot of latency stats for a service.
class LatencyStats {
  final Duration min;
  final Duration max;
  final Duration average;
  final Duration last;
  final int count;

  const LatencyStats({
    required this.min,
    required this.max,
    required this.average,
    required this.last,
    required this.count,
  });
}
