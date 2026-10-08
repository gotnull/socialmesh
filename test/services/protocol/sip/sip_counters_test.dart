// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/services/protocol/sip/sip_counters.dart';
import 'package:socialmesh/services/protocol/sip/sip_types.dart';

void main() {
  late SipCounters counters;

  setUp(() {
    counters = SipCounters();
  });

  group('SipCounters per-type tracking', () {
    test('recordTx increments sent count for message type', () {
      counters.recordTx(SipMessageType.capBeacon, 32);
      counters.recordTx(SipMessageType.capBeacon, 32);
      expect(counters.txCountFor(SipMessageType.capBeacon), equals(2));
      expect(counters.txBytes, equals(64));
    });

    test('recordRx increments received count for message type', () {
      counters.recordRx(SipMessageType.rollcallResp, 40);
      expect(counters.rxCountFor(SipMessageType.rollcallResp), equals(1));
      expect(counters.rxBytes, equals(40));
    });

    test('txCountFor returns 0 for unseen type', () {
      expect(counters.txCountFor(SipMessageType.dmMsg), equals(0));
    });

    test('rxCountFor returns 0 for unseen type', () {
      expect(counters.rxCountFor(SipMessageType.error), equals(0));
    });

    test('multiple types tracked independently', () {
      counters.recordTx(SipMessageType.capBeacon, 32);
      counters.recordTx(SipMessageType.hsHello, 50);
      counters.recordRx(SipMessageType.hsChallenge, 60);

      expect(counters.txCountFor(SipMessageType.capBeacon), equals(1));
      expect(counters.txCountFor(SipMessageType.hsHello), equals(1));
      expect(counters.rxCountFor(SipMessageType.hsChallenge), equals(1));
      expect(counters.txBytes, equals(82));
      expect(counters.rxBytes, equals(60));
    });
  });

  group('SipCounters error/security counters', () {
    test('replayRejects increments', () {
      counters.recordReplayReject();
      counters.recordReplayReject();
      expect(counters.replayRejects, equals(2));
    });

    test('signatureFailures increments', () {
      counters.recordSignatureFailure();
      expect(counters.signatureFailures, equals(1));
    });

    test('signatureSuccesses increments', () {
      counters.recordSignatureSuccess();
      counters.recordSignatureSuccess();
      counters.recordSignatureSuccess();
      expect(counters.signatureSuccesses, equals(3));
    });
  });

  group('SipCounters budget/congestion counters', () {
    test('budgetThrottles increments', () {
      counters.recordBudgetThrottle();
      expect(counters.budgetThrottles, equals(1));
    });

    test('congestionPauses increments', () {
      counters.recordCongestionPause();
      counters.recordCongestionPause();
      expect(counters.congestionPauses, equals(2));
    });
  });

  group('SipCounters handshake counters', () {
    test('handshake lifecycle tracking', () {
      counters.recordHandshakeInitiated();
      counters.recordHandshakeInitiated();
      counters.recordHandshakeCompleted();
      counters.recordHandshakeFailed();

      expect(counters.handshakeInitiated, equals(2));
      expect(counters.handshakeCompleted, equals(1));
      expect(counters.handshakeFailed, equals(1));
    });
  });

  group('SipCounters identity counters', () {
    test('identity tracking', () {
      counters.recordIdentityVerified();
      counters.recordIdentityVerified();
      counters.recordIdentityChangedKey();

      expect(counters.identityVerified, equals(2));
      expect(counters.identityChangedKey, equals(1));
    });
  });

  group('SipCounters transfer counters', () {
    test('transfer lifecycle tracking', () {
      counters.recordTransferStarted();
      counters.recordTransferCompleted();
      counters.recordTransferFailed('timeout');
      counters.recordTransferFailed('timeout');
      counters.recordTransferFailed('budget');

      expect(counters.transferStarted, equals(1));
      expect(counters.transferCompleted, equals(1));
      expect(counters.transferFailed, equals({'timeout': 2, 'budget': 1}));
    });

    test('nack tracking', () {
      counters.recordNackSent();
      counters.recordNacksReceived();
      counters.recordNacksReceived();

      expect(counters.nacksSent, equals(1));
      expect(counters.nacksReceived, equals(2));
    });

    test('retransmission tracking', () {
      counters.recordRetransmission();
      expect(counters.retransmissions, equals(1));
    });
  });

  group('SipCounters export', () {
    test('export returns all counters as map', () {
      counters.recordTx(SipMessageType.capBeacon, 32);
      counters.recordRx(SipMessageType.rollcallResp, 40);
      counters.recordReplayReject();
      counters.recordHandshakeCompleted();

      final exported = counters.export();
      expect(exported['tx_count'], isA<Map<String, int>>());
      expect((exported['tx_count'] as Map)['capBeacon'], equals(1));
      expect((exported['rx_count'] as Map)['rollcallResp'], equals(1));
      expect(exported['tx_bytes'], equals(32));
      expect(exported['rx_bytes'], equals(40));
      expect(exported['replay_rejects'], equals(1));
      expect(exported['handshake_completed'], equals(1));
    });

    test('export returns empty maps for fresh counters', () {
      final exported = counters.export();
      expect((exported['tx_count'] as Map), isEmpty);
      expect((exported['rx_count'] as Map), isEmpty);
      expect(exported['tx_bytes'], equals(0));
    });
  });

  group('SipCounters toDisplayEntries', () {
    test('returns entries for non-zero counters', () {
      counters.recordTx(SipMessageType.capBeacon, 32);
      counters.recordTx(SipMessageType.hsHello, 50);
      counters.recordRx(SipMessageType.hsChallenge, 60);
      counters.recordHandshakeInitiated();
      counters.recordBudgetThrottle();

      final entries = counters.toDisplayEntries(AppLocalizationsEn());
      expect(entries, isNotEmpty);

      final labels = entries.map((e) => e.label).toList();
      expect(labels, contains('CAP_BEACON sent'));
      expect(labels, contains('HS_HELLO sent'));
      expect(labels, contains('HS_CHALLENGE received'));
      expect(labels, contains('Handshakes initiated'));
      expect(labels, contains('Budget throttles'));
    });

    test('display entry values are correct', () {
      counters.recordTx(SipMessageType.dmMsg, 27);
      counters.recordTx(SipMessageType.dmMsg, 30);

      final entries = counters.toDisplayEntries(AppLocalizationsEn());
      final dmEntry = entries.firstWhere((e) => e.label == 'DM_MSG sent');
      expect(dmEntry.value, equals(2));
    });
  });

  group('SipCounters reset', () {
    test('reset clears all counters', () {
      counters.recordTx(SipMessageType.capBeacon, 100);
      counters.recordRx(SipMessageType.dmMsg, 50);
      counters.recordReplayReject();
      counters.recordSignatureFailure();
      counters.recordBudgetThrottle();
      counters.recordCongestionPause();
      counters.recordHandshakeInitiated();
      counters.recordHandshakeCompleted();
      counters.recordHandshakeFailed();
      counters.recordIdentityVerified();
      counters.recordIdentityChangedKey();
      counters.recordTransferStarted();
      counters.recordTransferFailed('test');
      counters.recordRetransmission();
      counters.recordNackSent();
      counters.recordNacksReceived();

      counters.reset();

      expect(counters.txCountFor(SipMessageType.capBeacon), equals(0));
      expect(counters.rxCountFor(SipMessageType.dmMsg), equals(0));
      expect(counters.txBytes, equals(0));
      expect(counters.rxBytes, equals(0));
      expect(counters.replayRejects, equals(0));
      expect(counters.signatureFailures, equals(0));
      expect(counters.budgetThrottles, equals(0));
      expect(counters.congestionPauses, equals(0));
      expect(counters.handshakeInitiated, equals(0));
      expect(counters.handshakeCompleted, equals(0));
      expect(counters.handshakeFailed, equals(0));
      expect(counters.identityVerified, equals(0));
      expect(counters.identityChangedKey, equals(0));
      expect(counters.transferStarted, equals(0));
      expect(counters.transferFailed, isEmpty);
      expect(counters.retransmissions, equals(0));
      expect(counters.nacksSent, equals(0));
      expect(counters.nacksReceived, equals(0));
    });
  });
}
