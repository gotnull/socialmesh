// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_counters.dart';

void main() {
  group('MrrpCounters', () {
    late MrrpCounters counters;

    setUp(() {
      counters = MrrpCounters();
    });

    test('starts with all zeros', () {
      expect(counters.serviceAdvertsSent, 0);
      expect(counters.serviceAdvertsReceived, 0);
      expect(counters.serviceDirRequestsSent, 0);
      expect(counters.serviceDirRequestsReceived, 0);
      expect(counters.serviceDirResponsesSent, 0);
      expect(counters.serviceDirResponsesReceived, 0);
      expect(counters.requestsSent, 0);
      expect(counters.requestsReceived, 0);
      expect(counters.responsesSent, 0);
      expect(counters.responsesReceived, 0);
      expect(counters.errorsSent, 0);
      expect(counters.errorsReceived, 0);
      expect(counters.duplicateRequestsIgnored, 0);
      expect(counters.duplicateResponsesIgnored, 0);
      expect(counters.cachedResponsesServed, 0);
      expect(counters.requestTimeouts, 0);
      expect(counters.responseTimeouts, 0);
      expect(counters.requestCancellations, 0);
      expect(counters.payloadTooLargeRejections, 0);
      expect(counters.budgetThrottles, 0);
    });

    test('recordServiceAdvertSent increments and sets timestamp', () {
      counters.recordServiceAdvertSent();
      expect(counters.serviceAdvertsSent, 1);
      expect(counters.lastAdvertSent, isNotNull);

      counters.recordServiceAdvertSent();
      expect(counters.serviceAdvertsSent, 2);
    });

    test('recordServiceAdvertReceived increments and sets timestamp', () {
      counters.recordServiceAdvertReceived();
      expect(counters.serviceAdvertsReceived, 1);
      expect(counters.lastAdvertReceived, isNotNull);
    });

    test('recordRequestSent increments global and per-service', () {
      counters.recordRequestSent(serviceId: 0x00000001);
      counters.recordRequestSent(serviceId: 0x00000001);
      counters.recordRequestSent(serviceId: 0xFFFF0001);

      expect(counters.requestsSent, 3);
      expect(counters.requestsSentPerService[0x00000001], 2);
      expect(counters.requestsSentPerService[0xFFFF0001], 1);
    });

    test('recordRequestReceived increments global and per-service', () {
      counters.recordRequestReceived(serviceId: 0x00000001);
      expect(counters.requestsReceived, 1);
      expect(counters.requestsReceivedPerService[0x00000001], 1);
    });

    test('recordResponseSent increments global and per-service', () {
      counters.recordResponseSent(serviceId: 0x00000001);
      expect(counters.responsesSent, 1);
      expect(counters.responsesSentPerService[0x00000001], 1);
    });

    test('recordResponseReceived increments global and per-service', () {
      counters.recordResponseReceived(serviceId: 0xFFFF0001);
      counters.recordResponseReceived(serviceId: 0xFFFF0001);
      expect(counters.responsesReceived, 2);
      expect(counters.responsesReceivedPerService[0xFFFF0001], 2);
    });

    test('recordErrorReceived increments global and per-status', () {
      counters.recordErrorReceived(statusCode: 1);
      counters.recordErrorReceived(statusCode: 1);
      counters.recordErrorReceived(statusCode: 3);
      expect(counters.errorsReceived, 3);
      expect(counters.errorsReceivedPerStatus[1], 2);
      expect(counters.errorsReceivedPerStatus[3], 1);
    });

    test('dedup counters increment independently', () {
      counters.recordDuplicateRequestIgnored();
      counters.recordDuplicateRequestIgnored();
      counters.recordDuplicateResponseIgnored();
      counters.recordCachedResponseServed();
      expect(counters.duplicateRequestsIgnored, 2);
      expect(counters.duplicateResponsesIgnored, 1);
      expect(counters.cachedResponsesServed, 1);
    });

    test('recordRequestTimeout increments global and per-service', () {
      counters.recordRequestTimeout(serviceId: 0x00000001);
      counters.recordRequestTimeout(serviceId: 0x00000001);
      counters.recordRequestTimeout(serviceId: 0x00000003);
      expect(counters.requestTimeouts, 3);
      expect(counters.requestTimeoutsPerService[0x00000001], 2);
      expect(counters.requestTimeoutsPerService[0x00000003], 1);
    });

    test('response timeout and cancellation counters', () {
      counters.recordResponseTimeout();
      counters.recordResponseTimeout();
      counters.recordRequestCancellation();
      expect(counters.responseTimeouts, 2);
      expect(counters.requestCancellations, 1);
    });

    test('harness actions track per-action type', () {
      counters.recordHarnessAction('compose_request');
      counters.recordHarnessAction('compose_request');
      counters.recordHarnessAction('fixture_replay');
      expect(counters.harnessActionsPerformed['compose_request'], 2);
      expect(counters.harnessActionsPerformed['fixture_replay'], 1);
    });

    test('simulated faults track per-fault type', () {
      counters.recordSimulatedFault('timeout');
      counters.recordSimulatedFault('error');
      counters.recordSimulatedFault('timeout');
      expect(counters.simulatedFaultsInjected['timeout'], 2);
      expect(counters.simulatedFaultsInjected['error'], 1);
    });

    test('rejection counters increment', () {
      counters.recordPayloadTooLargeRejection();
      counters.recordBudgetThrottle();
      counters.recordBudgetThrottle();
      expect(counters.payloadTooLargeRejections, 1);
      expect(counters.budgetThrottles, 2);
    });

    test('legacy aliases return correct values', () {
      counters.recordBudgetThrottle();
      counters.recordDuplicateRequestIgnored();
      counters.recordDuplicateResponseIgnored();
      counters.recordRequestTimeout();
      counters.recordResponseTimeout();
      counters.recordServiceAdvertSent();
      counters.recordServiceAdvertReceived();

      expect(counters.sendsBlocked, 1);
      expect(counters.dedupHits, 2); // req + resp dedup
      expect(counters.timeouts, 2); // req + resp timeouts
      expect(counters.advertsSent, 1);
      expect(counters.advertsReceived, 1);
    });

    test('legacy recording methods delegate correctly', () {
      counters.recordSendBlocked();
      expect(counters.budgetThrottles, 1);

      counters.recordDedupHit();
      expect(counters.duplicateRequestsIgnored, 1);

      counters.recordTimeout();
      expect(counters.requestTimeouts, 1);

      counters.recordAdvertSent();
      expect(counters.serviceAdvertsSent, 1);

      counters.recordAdvertReceived();
      expect(counters.serviceAdvertsReceived, 1);
    });

    test('latency tracking records and retrieves stats', () {
      counters.recordLatency(0x00000001, const Duration(milliseconds: 100));
      counters.recordLatency(0x00000001, const Duration(milliseconds: 200));
      counters.recordLatency(0x00000001, const Duration(milliseconds: 300));

      final stats = counters.getLatencyStats(0x00000001);
      expect(stats, isNotNull);
      expect(stats!.count, 3);
      expect(stats.min.inMilliseconds, 100);
      expect(stats.max.inMilliseconds, 300);
      expect(stats.average.inMilliseconds, 200);
      expect(stats.last.inMilliseconds, 300);

      expect(counters.serviceIdsWithLatency, contains(0x00000001));
      expect(counters.getLatencyStats(0xDEAD), isNull);
    });

    test('reset clears everything', () {
      counters.recordServiceAdvertSent();
      counters.recordRequestSent(serviceId: 0x00000001);
      counters.recordErrorReceived(statusCode: 1);
      counters.recordDuplicateRequestIgnored();
      counters.recordRequestTimeout(serviceId: 0x00000001);
      counters.recordHarnessAction('test');
      counters.recordSimulatedFault('test');
      counters.recordBudgetThrottle();
      counters.recordLatency(0x00000001, const Duration(milliseconds: 50));

      counters.reset();

      expect(counters.serviceAdvertsSent, 0);
      expect(counters.requestsSent, 0);
      expect(counters.errorsReceived, 0);
      expect(counters.duplicateRequestsIgnored, 0);
      expect(counters.requestTimeouts, 0);
      expect(counters.budgetThrottles, 0);
      expect(counters.requestsSentPerService, isEmpty);
      expect(counters.errorsReceivedPerStatus, isEmpty);
      expect(counters.requestTimeoutsPerService, isEmpty);
      expect(counters.harnessActionsPerformed, isEmpty);
      expect(counters.simulatedFaultsInjected, isEmpty);
      expect(counters.lastAdvertSent, isNull);
      expect(counters.serviceIdsWithLatency, isEmpty);
    });

    test('recordRequestSent without serviceId only increments global', () {
      counters.recordRequestSent();
      expect(counters.requestsSent, 1);
      expect(counters.requestsSentPerService, isEmpty);
    });
  });
}
