// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// SIP instrumentation counters for debug and field test validation.
///
/// Tracks sent/received counts per message type, error conditions,
/// budget throttles, and protocol lifecycle events. Counters are
/// in-memory only (reset on app restart) and exportable for debug
/// log bundles.
library;

import '../../../core/logging.dart';
import 'sip_types.dart';

/// In-memory counter store for SIP operations.
///
/// All counters are reset to zero on construction and when [reset]
/// is called. Thread-safe within Dart's single-isolate model.
class SipCounters {
  // ---------------------------------------------------------------------------
  // Per-message-type counters
  // ---------------------------------------------------------------------------

  /// Frames sent, keyed by message type name.
  final Map<String, int> _txCount = {};

  /// Frames received, keyed by message type name.
  final Map<String, int> _rxCount = {};

  /// Total bytes sent (all SIP frames).
  int _txBytes = 0;

  /// Total bytes received (all SIP frames).
  int _rxBytes = 0;

  // ---------------------------------------------------------------------------
  // Error/security counters
  // ---------------------------------------------------------------------------

  /// Replay cache rejections.
  int _replayRejects = 0;

  /// Signature verification failures.
  int _signatureFailures = 0;

  /// Signature verification successes.
  int _signatureSuccesses = 0;

  // ---------------------------------------------------------------------------
  // Budget/congestion counters
  // ---------------------------------------------------------------------------

  /// Times a send was blocked by the rate limiter.
  int _budgetThrottles = 0;

  /// Times congestion pause was triggered.
  int _congestionPauses = 0;

  // ---------------------------------------------------------------------------
  // Handshake counters
  // ---------------------------------------------------------------------------

  /// Handshakes initiated (HS_HELLO sent).
  int _handshakeInitiated = 0;

  /// Handshakes completed (HS_ACCEPT sent or received).
  int _handshakeCompleted = 0;

  /// Handshakes failed (timeout, nonce mismatch, etc.).
  int _handshakeFailed = 0;

  // ---------------------------------------------------------------------------
  // Identity counters
  // ---------------------------------------------------------------------------

  /// Identity claims verified (TOFU or pinned).
  int _identityVerified = 0;

  /// Identity changed-key events detected.
  int _identityChangedKey = 0;

  // ---------------------------------------------------------------------------
  // Transfer counters (SIP-3, deferred but tracked)
  // ---------------------------------------------------------------------------

  /// Transfers started.
  int _transferStarted = 0;

  /// Transfers completed successfully.
  int _transferCompleted = 0;

  /// Transfers failed (with reason).
  final Map<String, int> _transferFailed = {};

  /// Retransmissions sent.
  int _retransmissions = 0;

  /// NACKs sent.
  int _nacksSent = 0;

  /// NACKs received.
  int _nacksReceived = 0;

  // ---------------------------------------------------------------------------
  // Recording methods
  // ---------------------------------------------------------------------------

  /// Record a frame sent.
  void recordTx(SipMessageType type, int bytes) {
    final key = type.name;
    _txCount[key] = (_txCount[key] ?? 0) + 1;
    _txBytes += bytes;
  }

  /// Record a frame received.
  void recordRx(SipMessageType type, int bytes) {
    final key = type.name;
    _rxCount[key] = (_rxCount[key] ?? 0) + 1;
    _rxBytes += bytes;
  }

  /// Record a replay cache rejection.
  void recordReplayReject() => _replayRejects++;

  /// Record a signature verification failure.
  void recordSignatureFailure() => _signatureFailures++;

  /// Record a signature verification success.
  void recordSignatureSuccess() => _signatureSuccesses++;

  /// Record a budget throttle (send blocked).
  void recordBudgetThrottle() => _budgetThrottles++;

  /// Record a congestion pause.
  void recordCongestionPause() => _congestionPauses++;

  /// Record a handshake initiation.
  void recordHandshakeInitiated() => _handshakeInitiated++;

  /// Record a successful handshake completion.
  void recordHandshakeCompleted() => _handshakeCompleted++;

  /// Record a handshake failure.
  void recordHandshakeFailed() => _handshakeFailed++;

  /// Record an identity verification.
  void recordIdentityVerified() => _identityVerified++;

  /// Record a changed-key detection.
  void recordIdentityChangedKey() => _identityChangedKey++;

  /// Record a transfer started.
  void recordTransferStarted() => _transferStarted++;

  /// Record a transfer completed.
  void recordTransferCompleted() => _transferCompleted++;

  /// Record a transfer failure with reason.
  void recordTransferFailed(String reason) {
    _transferFailed[reason] = (_transferFailed[reason] ?? 0) + 1;
  }

  /// Record a retransmission.
  void recordRetransmission() => _retransmissions++;

  /// Record a NACK sent.
  void recordNackSent() => _nacksSent++;

  /// Record a NACK received.
  void recordNacksReceived() => _nacksReceived++;

  // ---------------------------------------------------------------------------
  // Read access
  // ---------------------------------------------------------------------------

  /// Get the sent count for a specific message type.
  int txCountFor(SipMessageType type) => _txCount[type.name] ?? 0;

  /// Get the received count for a specific message type.
  int rxCountFor(SipMessageType type) => _rxCount[type.name] ?? 0;

  /// Total bytes sent.
  int get txBytes => _txBytes;

  /// Total bytes received.
  int get rxBytes => _rxBytes;

  /// Replay rejections.
  int get replayRejects => _replayRejects;

  /// Signature failures.
  int get signatureFailures => _signatureFailures;

  /// Signature successes.
  int get signatureSuccesses => _signatureSuccesses;

  /// Budget throttles.
  int get budgetThrottles => _budgetThrottles;

  /// Congestion pauses.
  int get congestionPauses => _congestionPauses;

  /// Handshakes initiated.
  int get handshakeInitiated => _handshakeInitiated;

  /// Handshakes completed.
  int get handshakeCompleted => _handshakeCompleted;

  /// Handshakes failed.
  int get handshakeFailed => _handshakeFailed;

  /// Identities verified.
  int get identityVerified => _identityVerified;

  /// Identity changed-key events.
  int get identityChangedKey => _identityChangedKey;

  /// Transfers started.
  int get transferStarted => _transferStarted;

  /// Transfers completed.
  int get transferCompleted => _transferCompleted;

  /// Transfer failure reasons.
  Map<String, int> get transferFailed => Map.unmodifiable(_transferFailed);

  /// Retransmissions.
  int get retransmissions => _retransmissions;

  /// NACKs sent.
  int get nacksSent => _nacksSent;

  /// NACKs received.
  int get nacksReceived => _nacksReceived;

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  /// Export all counters as a structured map for debug log bundles.
  Map<String, dynamic> export() {
    return {
      'tx_count': Map<String, int>.from(_txCount),
      'rx_count': Map<String, int>.from(_rxCount),
      'tx_bytes': _txBytes,
      'rx_bytes': _rxBytes,
      'replay_rejects': _replayRejects,
      'signature_failures': _signatureFailures,
      'signature_successes': _signatureSuccesses,
      'budget_throttles': _budgetThrottles,
      'congestion_pauses': _congestionPauses,
      'handshake_initiated': _handshakeInitiated,
      'handshake_completed': _handshakeCompleted,
      'handshake_failed': _handshakeFailed,
      'identity_verified': _identityVerified,
      'identity_changed_key': _identityChangedKey,
      'transfer_started': _transferStarted,
      'transfer_completed': _transferCompleted,
      'transfer_failed': Map<String, int>.from(_transferFailed),
      'retransmissions': _retransmissions,
      'nacks_sent': _nacksSent,
      'nacks_received': _nacksReceived,
    };
  }

  /// Export counters as a human-readable summary for display.
  List<SipCounterEntry> toDisplayEntries() {
    final entries = <SipCounterEntry>[];

    // Per-type TX
    for (final type in SipMessageType.values) {
      final count = _txCount[type.name] ?? 0;
      if (count > 0) {
        entries.add(
          SipCounterEntry(label: '${_friendlyName(type)} sent', value: count),
        );
      }
    }

    // Per-type RX
    for (final type in SipMessageType.values) {
      final count = _rxCount[type.name] ?? 0;
      if (count > 0) {
        entries.add(
          SipCounterEntry(
            label: '${_friendlyName(type)} received',
            value: count,
          ),
        );
      }
    }

    // Aggregates
    entries.addAll([
      SipCounterEntry(label: 'Total bytes sent', value: _txBytes),
      SipCounterEntry(label: 'Total bytes received', value: _rxBytes),
      SipCounterEntry(
        label: 'Handshakes initiated',
        value: _handshakeInitiated,
      ),
      SipCounterEntry(
        label: 'Handshakes completed',
        value: _handshakeCompleted,
      ),
      SipCounterEntry(label: 'Handshakes failed', value: _handshakeFailed),
      SipCounterEntry(label: 'Identities verified', value: _identityVerified),
      SipCounterEntry(
        label: 'Identity changed-key',
        value: _identityChangedKey,
      ),
      SipCounterEntry(label: 'Budget throttles', value: _budgetThrottles),
      SipCounterEntry(label: 'Congestion pauses', value: _congestionPauses),
      SipCounterEntry(label: 'Replay rejects', value: _replayRejects),
      SipCounterEntry(label: 'Signature failures', value: _signatureFailures),
      SipCounterEntry(label: 'Signature successes', value: _signatureSuccesses),
      SipCounterEntry(label: 'Retransmissions', value: _retransmissions),
      SipCounterEntry(label: 'NACKs sent', value: _nacksSent),
      SipCounterEntry(label: 'NACKs received', value: _nacksReceived),
    ]);

    return entries;
  }

  // ---------------------------------------------------------------------------
  // Reset
  // ---------------------------------------------------------------------------

  /// Reset all counters to zero.
  void reset() {
    _txCount.clear();
    _rxCount.clear();
    _txBytes = 0;
    _rxBytes = 0;
    _replayRejects = 0;
    _signatureFailures = 0;
    _signatureSuccesses = 0;
    _budgetThrottles = 0;
    _congestionPauses = 0;
    _handshakeInitiated = 0;
    _handshakeCompleted = 0;
    _handshakeFailed = 0;
    _identityVerified = 0;
    _identityChangedKey = 0;
    _transferStarted = 0;
    _transferCompleted = 0;
    _transferFailed.clear();
    _retransmissions = 0;
    _nacksSent = 0;
    _nacksReceived = 0;
    AppLogging.sip('SIP_COUNTERS: all counters reset');
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _friendlyName(SipMessageType type) {
    switch (type) {
      case SipMessageType.capBeacon:
        return 'CAP_BEACON';
      case SipMessageType.capReq:
        return 'CAP_REQ';
      case SipMessageType.capResp:
        return 'CAP_RESP';
      case SipMessageType.rollcallReq:
        return 'ROLLCALL_REQ';
      case SipMessageType.rollcallResp:
        return 'ROLLCALL_RESP';
      case SipMessageType.idReq:
        return 'ID_REQ';
      case SipMessageType.idClaim:
        return 'ID_CLAIM';
      case SipMessageType.idResp:
        return 'ID_RESP';
      case SipMessageType.hsHello:
        return 'HS_HELLO';
      case SipMessageType.hsChallenge:
        return 'HS_CHALLENGE';
      case SipMessageType.hsResponse:
        return 'HS_RESPONSE';
      case SipMessageType.hsAccept:
        return 'HS_ACCEPT';
      case SipMessageType.txStart:
        return 'TX_START';
      case SipMessageType.txChunk:
        return 'TX_CHUNK';
      case SipMessageType.txAck:
        return 'TX_ACK';
      case SipMessageType.txNack:
        return 'TX_NACK';
      case SipMessageType.txDone:
        return 'TX_DONE';
      case SipMessageType.txCancel:
        return 'TX_CANCEL';
      case SipMessageType.dmMsg:
        return 'DM_MSG';
      case SipMessageType.dmTyping:
        return 'DM_TYPING';
      case SipMessageType.dmReaction:
        return 'DM_REACTION';
      case SipMessageType.dmDelete:
        return 'DM_DELETE';
      case SipMessageType.error:
        return 'ERROR';
      case SipMessageType.mrrpData:
        return 'MRRP_DATA';
    }
  }
}

/// A single counter entry for display.
class SipCounterEntry {
  /// Human-readable label.
  final String label;

  /// Counter value.
  final int value;

  const SipCounterEntry({required this.label, required this.value});
}
