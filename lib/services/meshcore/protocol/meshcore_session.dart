// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCore protocol session management.
//
// Wraps a transport (BLE or USB) and provides frame-level I/O:
// - Exposes Stream of MeshCoreFrame for incoming frames
// - Provides sendFrame() for outgoing frames
// - Handles codec encoding/decoding
// - Provides high-level protocol primitives (getSelfInfo, getBattAndStorage)
//
// This is the main entry point for MeshCore protocol operations.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode;

import '../../../core/logging.dart';
import '../../../core/meshcore_constants.dart';
import '../../../models/meshcore_auto_add_config.dart';
import '../meshcore_send_rate_limiter.dart';
import 'meshcore_capture.dart';
import 'meshcore_codec.dart';
import 'meshcore_frame.dart';
import 'meshcore_cayenne_lpp.dart';
import 'meshcore_messages.dart';

/// Exception thrown when parsing a MeshCore response fails.
///
/// Contains the response code and payload for debugging and logging.
class MeshCoreParseException implements Exception {
  /// The response code that failed to parse.
  final int code;

  /// The payload bytes that failed to parse.
  final Uint8List payload;

  /// A short description of the parse failure.
  final String message;

  /// Optional stack trace from the parsing attempt.
  final StackTrace? stackTrace;

  MeshCoreParseException({
    required this.code,
    required this.payload,
    required this.message,
    this.stackTrace,
  });

  /// Convenience constructor for message-only exceptions (legacy).
  MeshCoreParseException.message(String msg)
    : code = 0,
      payload = Uint8List(0),
      message = msg,
      stackTrace = null;

  @override
  String toString() =>
      'MeshCoreParseException: $message (code=0x${code.toRadixString(16)}, '
      '${payload.length} bytes)';
}

/// Represents a MeshCore status/ACK frame (code 0x01).
///
/// Status frames are sent by the device as acknowledgments to commands.
/// The payload typically contains a single status byte:
/// - 0x00 = OK/success
/// - Non-zero = error code
class MeshCoreStatusFrame {
  /// The status code from the payload (first byte).
  final int statusCode;

  /// The full frame for reference.
  final MeshCoreFrame frame;

  MeshCoreStatusFrame({required this.statusCode, required this.frame});

  /// Whether this is a success status.
  bool get isOk => statusCode == 0;

  /// Whether this is an error status.
  bool get isError => statusCode != 0;

  @override
  String toString() =>
      'MeshCoreStatusFrame(status=${isOk ? "OK" : "ERR:$statusCode"})';
}

/// Thrown when a pending waiter is drained because the session was
/// torn down (transport disconnect, reconnect, or explicit dispose).
/// Callers should treat this as a recoverable cancellation - retry on
/// the next session.
class MeshCoreSessionDisposedError implements Exception {
  final String message;
  const MeshCoreSessionDisposedError([this.message = 'Session disposed']);

  @override
  String toString() => 'MeshCoreSessionDisposedError: $message';
}

/// Plain waiter entry (no predicate). The [generation] is the
/// `_sessionGeneration` value at register time and is the basis for
/// distinguishing "live concurrent collision" (loud, throws) from
/// "stale waiter from previous session" (recoverable, replaces).
class _PendingWaiter {
  final Completer<MeshCoreFrame> completer;
  final int generation;

  _PendingWaiter(this.completer, this.generation);
}

/// Helper class for waiters with validation predicates.
class _ValidatedWaiter {
  final Completer<MeshCoreFrame> completer;
  final bool Function(MeshCoreFrame) predicate;
  final int generation;

  _ValidatedWaiter(this.completer, this.predicate, this.generation);
}

/// Abstract interface for MeshCore transport layer.
///
/// This allows MeshCoreSession to work with BLE, USB, or fake transports.
abstract class MeshCoreTransport {
  /// Stream of raw received bytes from the device.
  Stream<Uint8List> get rawRxStream;

  /// Send raw bytes to the device.
  Future<void> sendRaw(Uint8List data);

  /// Whether currently connected.
  bool get isConnected;
}

/// Session state for MeshCore connection.
enum MeshCoreSessionState {
  /// Not connected to any device.
  disconnected,

  /// Session is active and ready for communication.
  active,

  /// Session encountered an error.
  error,
}

/// A MeshCore protocol session.
///
/// Provides frame-level I/O over a transport layer, plus high-level
/// protocol primitives.
///
/// Key safety features:
/// - Only response codes (0x00-0x7F) can satisfy waiters
/// - Push codes (0x80+) are never matched to waiters
/// - Single-flight policy: only one waiter per response code at a time
///
/// Usage:
/// ```dart
/// final session = MeshCoreSession(transport);
/// session.frameStream.listen((frame) {
///   print('Received: $frame');
/// });
///
/// // High-level: get device info
/// final selfInfo = await session.getSelfInfo();
///
/// // Low-level: send custom frame
/// await session.sendFrame(MeshCoreFrame.simple(cmdGetContacts));
/// ```
class MeshCoreSession {
  /// Outgoing command codes whose payload bytes can carry user-secret
  /// material (message bodies, public keys, channel PSKs, contact names).
  /// kDebugMode TX dumps redact the payload for these codes; only the
  /// `code=` and `len=` are emitted.
  ///
  /// The `meshcore` observability channel still emits structured events
  /// for these flows (e.g. `event=message.send.attempted size=N`); those
  /// are size-only by construction and are unaffected by this denylist.
  ///
  /// Visible for testing.
  static const Set<int> sensitiveTxPayloadCodes = <int>{
    // Outbound message bodies
    MeshCoreCommands.sendTxtMsg, // 0x02
    MeshCoreCommands.sendChannelTxtMsg, // 0x03
    // Contact identity material
    MeshCoreCommands.addUpdateContact, // 0x09
    MeshCoreCommands.shareContact, // 0x10
    MeshCoreCommands.exportContact, // 0x11
    MeshCoreCommands.importContact, // 0x12
    MeshCoreCommands.getContactByKey, // 0x1E
    // Channel PSK
    MeshCoreCommands.setChannel, // 0x20
  };

  /// Incoming response codes whose payload bytes can carry user-secret
  /// material. See [sensitiveTxPayloadCodes] for redaction policy.
  ///
  /// Visible for testing.
  static const Set<int> sensitiveRxPayloadCodes = <int>{
    // Contact descriptor: full pk + name
    MeshCoreResponses.contact, // 0x03
    // Self info: full pk
    MeshCoreResponses.selfInfo, // 0x05
    // Inbound message bodies
    MeshCoreResponses.contactMsgRecv, // 0x07
    MeshCoreResponses.channelMsgRecv, // 0x08
    MeshCoreResponses.contactMsgRecvV3, // 0x10
    MeshCoreResponses.channelMsgRecvV3, // 0x11
    // Channel info: PSK
    MeshCoreResponses.channelInfo, // 0x12
  };

  final MeshCoreTransport _transport;
  final MeshCoreCodec _codec;

  /// D33: token-bucket rate limiter that gates outbound text-message
  /// payloads (`CMD_SEND_TXT_MSG` and `CMD_SEND_CHANNEL_TXT_MSG`).
  /// One bucket per session; refills lazily on each acquire.
  ///
  /// Exposed publicly (read-only) so the chat composer can show a
  /// remaining-budget hint and a countdown to the next allowed send.
  /// Other commands (advertise, get_channel, etc.) are NOT gated —
  /// they're infrequent and don't compete with chat airtime.
  final MeshCoreSendRateLimiter _sendRateLimiter;

  /// Read-only view of the text-send budget. UI uses
  /// `sendRateLimiter.remainingBytes` and the result of
  /// `sendTextMessage(...)` to surface rate-limit feedback.
  MeshCoreSendRateLimiter get sendRateLimiter => _sendRateLimiter;

  final StreamController<MeshCoreFrame> _frameController;
  final StreamController<String> _errorController;
  StreamSubscription<Uint8List>? _rawSubscription;

  MeshCoreSessionState _state = MeshCoreSessionState.disconnected;

  /// Pending response completers by expected response code.
  ///
  /// Single-flight policy: only one waiter per response code.
  /// This prevents mis-association when multiple requests are in flight.
  final Map<int, _PendingWaiter> _pendingResponses = {};

  /// Pending response completers with validation predicates.
  ///
  /// These waiters only complete when both code matches AND predicate returns true.
  final Map<int, _ValidatedWaiter> _validatedWaiters = {};

  // Monotonic counter of how many times the session has been torn down
  // (via clearPendingResponses / dispose / transport disconnect that
  // drains the maps). Each waiter is tagged with the generation it was
  // registered under so _registerWaiter can distinguish a live
  // concurrent collision (same generation - loud throw) from a stale
  // waiter that survived a missed teardown (older generation -
  // recoverable replace + log).
  int _sessionGeneration = 0;

  /// Test-only: current session generation. Used by Cluster A tests to
  /// pin generation-bump-on-clear behaviour.
  int get sessionGenerationForTesting => _sessionGeneration;

  /// Stream controller for status/ACK frames (code 0x01).
  final StreamController<MeshCoreStatusFrame> _statusController =
      StreamController<MeshCoreStatusFrame>.broadcast();

  /// Optional capture for debugging (enabled via setCapture).
  MeshCoreFrameCapture? _capture;

  /// D36-A: single-flight guard for `sendBinaryRequest`. The firmware
  /// only tracks one pending binary request at a time; concurrent
  /// callers would lose correlation when a second SENT ack overwrites
  /// the first tag. This flag rejects the second call early, before
  /// any bytes hit the wire.
  bool _binaryRequestInFlight = false;

  /// D35-FIX-A: single-flight guard for `CMD_GET_STATS` requests
  /// (RADIO / CORE / PACKETS subtypes). All three subtypes share the
  /// same response opcode `RESP_CODE_STATS (0x18)`, so concurrent
  /// `sendAndWait` calls would race on the per-response-code
  /// `_pendingResponses[0x18]` slot and throw `StateError:
  /// Single-flight violation`. The per-notifier `_inFlight` guards in
  /// the providers are subtype-local; this flag coordinates across
  /// every stats helper at the session boundary.
  bool _statsRequestInFlight = false;

  /// Creates a new MeshCore session over the given transport.
  ///
  /// The session immediately starts listening to the transport's rawRxStream
  /// and decoding frames.
  MeshCoreSession(this._transport, {MeshCoreSendRateLimiter? sendRateLimiter})
    : _frameController = StreamController<MeshCoreFrame>.broadcast(),
      _errorController = StreamController<String>.broadcast(),
      _codec = MeshCoreCodec(),
      _sendRateLimiter = sendRateLimiter ?? MeshCoreSendRateLimiter() {
    _initialize();
  }

  /// Creates a session with custom codec (for testing).
  MeshCoreSession.withCodec(
    this._transport,
    this._codec, {
    MeshCoreSendRateLimiter? sendRateLimiter,
  }) : _frameController = StreamController<MeshCoreFrame>.broadcast(),
       _errorController = StreamController<String>.broadcast(),
       _sendRateLimiter = sendRateLimiter ?? MeshCoreSendRateLimiter() {
    _initialize();
  }

  /// Creates a session with optional capture (for debugging).
  MeshCoreSession.withCapture(
    this._transport,
    this._capture, {
    MeshCoreSendRateLimiter? sendRateLimiter,
  }) : _frameController = StreamController<MeshCoreFrame>.broadcast(),
       _errorController = StreamController<String>.broadcast(),
       _codec = MeshCoreCodec(),
       _sendRateLimiter = sendRateLimiter ?? MeshCoreSendRateLimiter() {
    _initialize();
  }

  void _initialize() {
    // Set up codec callbacks
    _codec.decoder.onFrame = _onFrameDecoded;
    _codec.decoder.onError = (error) {
      _errorController.add(error);
    };

    // Subscribe to transport raw stream
    _rawSubscription = _transport.rawRxStream.listen(
      (data) {
        _codec.decode(data);
      },
      onError: (e) {
        _errorController.add('Transport error: $e');
        _state = MeshCoreSessionState.error;
      },
    );

    _state = _transport.isConnected
        ? MeshCoreSessionState.active
        : MeshCoreSessionState.disconnected;
  }

  /// Convert bytes to hex string for logging.
  static String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
  }

  void _onFrameDecoded(MeshCoreFrame frame) {
    final hexCode = frame.command.toRadixString(16).padLeft(2, '0');

    // D17.B: unconditional protocol-layer receive event. Authoritative
    // source for inbound frame visibility, decoupled from any UI listener
    // being mounted. The chat widget previously emitted this event, which
    // meant inbound frames were invisible whenever a chat screen was not
    // open (e.g. during the bridge tests in D15). Code + size only;
    // payload bytes are deliberately omitted to keep secrets out of the
    // structured log channel.
    AppLogging.meshcore(
      'event=frame.received scope=protocol code=0x$hexCode '
      'size=${frame.payload.length}',
    );

    // Debug-only verbose dump for raw hex (full payload), payload-redacted
    // for sensitive codes (message bodies, contact identity material,
    // channel PSKs). Goes to the `Protocol:` log channel, not `meshcore`.
    if (kDebugMode) {
      if (sensitiveRxPayloadCodes.contains(frame.command)) {
        AppLogging.protocol(
          'MeshCore RX decoded: code=0x$hexCode '
          'len=${frame.payload.length} payload=<redacted>',
        );
      } else {
        final payloadHex = frame.payload.isEmpty
            ? '(empty)'
            : _bytesToHex(frame.payload);
        AppLogging.protocol(
          'MeshCore RX decoded: code=0x$hexCode '
          'len=${frame.payload.length} payload=[$payloadHex]',
        );
      }
    }

    // Record RX if capture is enabled
    _capture?.recordRx(frame);

    // Handle status/ACK frames specially (code 0x01)
    // These are acknowledgments and should NOT satisfy data waiters
    if (frame.command == MeshCoreResponses.err) {
      final statusCode = frame.payload.isNotEmpty ? frame.payload[0] : 0xFF;
      final statusFrame = MeshCoreStatusFrame(
        statusCode: statusCode,
        frame: frame,
      );
      AppLogging.protocol('MeshCore: Status/ACK frame received: $statusFrame');
      _statusController.add(statusFrame);
      // Status frames still go to general stream but do NOT satisfy waiters
      _frameController.add(frame);
      return;
    }

    // IMPORTANT: Only response codes (< 0x80) can satisfy waiters.
    // Push codes (>= 0x80) are async events and must not match waiters.
    if (MeshCoreCodeClassification.isResponseCode(frame.command)) {
      // First check validated waiters (they have predicates)
      final validatedWaiter = _validatedWaiters[frame.command];
      if (validatedWaiter != null && !validatedWaiter.completer.isCompleted) {
        if (validatedWaiter.predicate(frame)) {
          _validatedWaiters.remove(frame.command);
          validatedWaiter.completer.complete(frame);
        } else {
          AppLogging.protocol(
            'MeshCore: Frame code=0x${frame.command.toRadixString(16)} '
            'did not satisfy predicate (len=${frame.payload.length}), '
            'waiting for valid response...',
          );
          // Don't complete - keep waiting for a valid frame
        }
      } else {
        // Fall back to simple waiters (no predicate)
        final waiter = _pendingResponses.remove(frame.command);
        if (waiter != null && !waiter.completer.isCompleted) {
          waiter.completer.complete(frame);
        }
      }
    }

    // Always emit to stream for general listeners (both responses and pushes)
    _frameController.add(frame);
  }

  /// Set the capture instance for debugging.
  void setCapture(MeshCoreFrameCapture? capture) {
    _capture = capture;
  }

  /// Get the current capture instance (if any).
  MeshCoreFrameCapture? get capture => _capture;

  /// Current session state.
  MeshCoreSessionState get state => _state;

  /// Whether the session is active and ready for communication.
  bool get isActive => _state == MeshCoreSessionState.active;

  /// Stream of decoded frames from the device.
  Stream<MeshCoreFrame> get frameStream => _frameController.stream;

  /// Stream of status/ACK frames (code 0x01).
  Stream<MeshCoreStatusFrame> get statusStream => _statusController.stream;

  /// Stream of decode/protocol errors.
  Stream<String> get errorStream => _errorController.stream;

  // ---------------------------------------------------------------------------
  // Low-level Frame I/O
  // ---------------------------------------------------------------------------

  /// Send a frame to the device.
  ///
  /// Encodes the frame and sends it via the transport.
  /// Throws if the session is not active or if encoding fails.
  Future<void> sendFrame(MeshCoreFrame frame) async {
    if (!isActive && !_transport.isConnected) {
      throw StateError('Session is not active');
    }

    // Record TX if capture is enabled
    _capture?.recordTx(frame);

    final bytes = _codec.encode(frame);

    // Debug logging: detailed TX info, payload+raw redacted for sensitive
    // codes (message bodies, contact identity material, channel PSKs).
    if (kDebugMode) {
      final hexCode = frame.command.toRadixString(16).padLeft(2, '0');
      if (sensitiveTxPayloadCodes.contains(frame.command)) {
        AppLogging.protocol(
          'MeshCore TX: code=0x$hexCode '
          'len=${frame.payload.length} payload=<redacted> raw=<redacted>',
        );
      } else {
        final payloadHex = frame.payload.isEmpty
            ? '(empty)'
            : _bytesToHex(frame.payload);
        AppLogging.protocol(
          'MeshCore TX: code=0x$hexCode '
          'len=${frame.payload.length} payload=[$payloadHex] raw=[${_bytesToHex(bytes)}]',
        );
      }
    }

    await _transport.sendRaw(bytes);
  }

  /// Send a simple command with no payload.
  Future<void> sendCommand(int command) async {
    await sendFrame(MeshCoreFrame.simple(command));
  }

  /// Send a command with single byte argument.
  Future<void> sendCommandWithByte(int command, int arg) async {
    await sendFrame(
      MeshCoreFrame(command: command, payload: Uint8List.fromList([arg])),
    );
  }

  /// Send a command with payload.
  Future<void> sendCommandWithPayload(int command, Uint8List payload) async {
    await sendFrame(MeshCoreFrame(command: command, payload: payload));
  }

  /// Register a waiter for a specific response code.
  ///
  /// IMPORTANT: Call this BEFORE sending the command to avoid race conditions.
  /// The completer will be completed when a frame with matching code arrives.
  ///
  /// Throws [ArgumentError] if [responseCode] is a push code (>= 0x80).
  /// Throws [StateError] if a waiter is already registered for this code
  /// (single-flight policy).
  Completer<MeshCoreFrame> _registerWaiter(int responseCode) {
    // Validate: only response codes can be waited on
    if (MeshCoreCodeClassification.isPushCode(responseCode)) {
      throw ArgumentError.value(
        responseCode,
        'responseCode',
        'Cannot wait for push codes (0x${responseCode.toRadixString(16)}). '
            'Push codes are async events, not command responses.',
      );
    }

    _evictStaleWaiterIfAny(responseCode);

    // After eviction, any remaining entry is from the CURRENT generation
    // and therefore a live concurrent collision. Keep the loud throw so
    // a real bug stays visible. Crashlytics issue [A f1e904cd].
    if (_pendingResponses.containsKey(responseCode) ||
        _validatedWaiters.containsKey(responseCode)) {
      AppLogging.meshcore(
        '[A f1e904cd] single-flight collision (live) '
        'code=0x${responseCode.toRadixString(16)} '
        'gen=$_sessionGeneration',
        error: true,
      );
      throw StateError(
        'Single-flight violation: waiter already registered for '
        '0x${responseCode.toRadixString(16)}. '
        'Complete or cancel the existing request first.',
      );
    }

    final completer = Completer<MeshCoreFrame>();
    _pendingResponses[responseCode] = _PendingWaiter(
      completer,
      _sessionGeneration,
    );
    return completer;
  }

  // Stale-waiter recovery. If an entry exists for [responseCode] but
  // was registered under an older generation, it survived a teardown
  // that should have drained it - missed cleanup path, not a live
  // collision. Complete it with MeshCoreSessionDisposedError so its
  // awaiter unwinds cleanly, remove from maps, and let _registerWaiter
  // proceed. Logged at info (not error) since this is recoverable.
  void _evictStaleWaiterIfAny(int responseCode) {
    final pending = _pendingResponses[responseCode];
    if (pending != null && pending.generation != _sessionGeneration) {
      AppLogging.meshcore(
        '[A f1e904cd] evicting stale pending waiter '
        'code=0x${responseCode.toRadixString(16)} '
        'staleGen=${pending.generation} currentGen=$_sessionGeneration',
      );
      if (!pending.completer.isCompleted) {
        pending.completer.completeError(
          const MeshCoreSessionDisposedError('Stale waiter from prior session'),
        );
      }
      _pendingResponses.remove(responseCode);
    }
    final validated = _validatedWaiters[responseCode];
    if (validated != null && validated.generation != _sessionGeneration) {
      AppLogging.meshcore(
        '[A f1e904cd] evicting stale validated waiter '
        'code=0x${responseCode.toRadixString(16)} '
        'staleGen=${validated.generation} currentGen=$_sessionGeneration',
      );
      if (!validated.completer.isCompleted) {
        validated.completer.completeError(
          const MeshCoreSessionDisposedError('Stale waiter from prior session'),
        );
      }
      _validatedWaiters.remove(responseCode);
    }
  }

  /// Register a waiter with a validation predicate.
  ///
  /// The waiter only completes when a frame arrives with matching code
  /// AND the predicate returns true. This is useful for filtering out
  /// frames that don't meet certain criteria (e.g., minimum payload size).
  ///
  /// Throws [ArgumentError] if [responseCode] is a push code.
  /// Throws [StateError] if a waiter is already registered for this code.
  Completer<MeshCoreFrame> _registerValidatedWaiter(
    int responseCode,
    bool Function(MeshCoreFrame) predicate,
  ) {
    // Validate: only response codes can be waited on
    if (MeshCoreCodeClassification.isPushCode(responseCode)) {
      throw ArgumentError.value(
        responseCode,
        'responseCode',
        'Cannot wait for push codes (0x${responseCode.toRadixString(16)}). '
            'Push codes are async events, not command responses.',
      );
    }

    _evictStaleWaiterIfAny(responseCode);

    // Enforce single-flight: see _registerWaiter for the same rationale.
    if (_pendingResponses.containsKey(responseCode) ||
        _validatedWaiters.containsKey(responseCode)) {
      AppLogging.meshcore(
        '[A f1e904cd] single-flight collision (live, validated) '
        'code=0x${responseCode.toRadixString(16)} '
        'gen=$_sessionGeneration',
        error: true,
      );
      throw StateError(
        'Single-flight violation: waiter already registered for '
        '0x${responseCode.toRadixString(16)}. '
        'Complete or cancel the existing request first.',
      );
    }

    final completer = Completer<MeshCoreFrame>();
    _validatedWaiters[responseCode] = _ValidatedWaiter(
      completer,
      predicate,
      _sessionGeneration,
    );
    return completer;
  }

  /// Check if a waiter is pending for the given response code.
  bool hasWaiter(int responseCode) =>
      _pendingResponses.containsKey(responseCode) ||
      _validatedWaiters.containsKey(responseCode);

  /// Wait for a specific response code with timeout.
  ///
  /// Returns the first frame matching [responseCode], or null if timeout.
  ///
  /// Throws [ArgumentError] if [responseCode] is a push code.
  /// Throws [StateError] if already waiting for this response code.
  Future<MeshCoreFrame?> waitForResponse(
    int responseCode, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final completer = _registerWaiter(responseCode);

    try {
      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          // Remove from pending on timeout
          _pendingResponses.remove(responseCode);
          throw TimeoutException('Response timeout');
        },
      );
    } on TimeoutException {
      return null;
    }
  }

  /// Send a command and wait for a specific response.
  ///
  /// IMPORTANT: Registers the waiter BEFORE sending to handle fast responses.
  ///
  /// Throws [ArgumentError] if [expectedResponse] is a push code.
  /// Throws [StateError] if already waiting for this response code.
  Future<MeshCoreFrame?> sendAndWait(
    int command, {
    Uint8List? payload,
    int? expectedResponse,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final frame = payload != null
        ? MeshCoreFrame(command: command, payload: payload)
        : MeshCoreFrame.simple(command);

    final responseCode = expectedResponse ?? command;

    // Register waiter BEFORE sending to avoid race condition
    final completer = _registerWaiter(responseCode);

    // Send the command
    await sendFrame(frame);

    // Wait for response
    try {
      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          _pendingResponses.remove(responseCode);
          throw TimeoutException('Response timeout');
        },
      );
    } on TimeoutException {
      return null;
    }
  }

  /// D33: typed wrapper for outbound text-message sends that gates
  /// via [_sendRateLimiter] before consulting [sendAndWait].
  ///
  /// Use this for `CMD_SEND_TXT_MSG` (0x02) and
  /// `CMD_SEND_CHANNEL_TXT_MSG` (0x03). Other commands keep using
  /// [sendAndWait] directly — they are infrequent and don't compete
  /// for chat airtime budget.
  ///
  /// Returns a [MeshCoreTextSendResult] discriminating:
  ///   - `ok`              : firmware acknowledged with the expected
  ///                         response code; payload arrived.
  ///   - `rateLimited`     : the send was rejected at the host before
  ///                         hitting the wire. Tokens are NOT consumed.
  ///                         `nextSendIn` tells the UI when to retry.
  ///   - `firmwareTimeout` : firmware never replied with the expected
  ///                         response within [timeout].
  ///
  /// Budget accounting: the rate limiter charges
  /// `payload.length + 1` bytes (1 byte for the cmd byte). Framing
  /// overhead (codec markers, length prefix, end-of-frame) is NOT
  /// counted; the 1024 B / 60 s default budget already folds that
  /// in. Local validation that throws BEFORE this method is called
  /// (e.g. `ArgumentError` on `setChannel`'s slot range) does NOT
  /// consume tokens.
  Future<MeshCoreTextSendResult> sendTextMessage({
    required int command,
    required Uint8List payload,
    required int expectedResponse,
    Duration timeout = const Duration(seconds: 5),
    MeshCoreSendKind? sendKind,
  }) async {
    if (command != MeshCoreCommands.sendTxtMsg &&
        command != MeshCoreCommands.sendChannelTxtMsg) {
      throw ArgumentError.value(
        command,
        'command',
        'sendTextMessage only supports sendTxtMsg / sendChannelTxtMsg',
      );
    }

    // D34a: classify the send for the chat-traffic measurement layer.
    // Real callers (chat screen) pass `sendKind` explicitly. The
    // inference path is a safety net for any caller that forgets:
    //   - reply if the payload starts with the chat-meta fallback
    //     prefix `[mrrp]`
    //   - plain otherwise
    //   - contact/channel from the command code
    final kind = sendKind ?? _inferSendKind(command, payload);

    final budgetBytes = payload.length + 1;
    final decision = _sendRateLimiter.tryAcquire(budgetBytes);
    if (!decision.allowed) {
      AppLogging.meshcore(
        'event=text.send.rate_limited '
        'kind=${kind.logTag} '
        'cmd=0x${command.toRadixString(16).padLeft(2, '0')} '
        'bytes=$budgetBytes '
        'remaining=${decision.remainingBytes} '
        'wait_ms=${decision.nextSendIn.inMilliseconds}',
      );
      _sendRateLimiter.recordSend(
        kind: kind,
        bytes: budgetBytes,
        allowed: false,
      );
      return MeshCoreTextSendResult.rateLimited(
        nextSendIn: decision.nextSendIn,
        remainingBytes: decision.remainingBytes,
      );
    }

    _sendRateLimiter.recordSend(kind: kind, bytes: budgetBytes, allowed: true);

    final response = await sendAndWait(
      command,
      payload: payload,
      expectedResponse: expectedResponse,
      timeout: timeout,
    );
    if (response == null) {
      return MeshCoreTextSendResult.firmwareTimeout();
    }
    return MeshCoreTextSendResult.ok(response: response);
  }

  /// D34a: literal `startsWith([mrrp])` test on the wire payload.
  ///
  /// Production callers (the chat screen) always pass an explicit
  /// `sendKind`, so the prefix sniff only fires for tests and any
  /// future caller that omits the kind. False negatives (a reply
  /// payload whose routing header pushes `[mrrp]` past offset 0)
  /// classify as plain — acceptable, since per-kind attribution is
  /// best-effort when the kind is omitted; the byte budget itself is
  /// always counted correctly.
  static MeshCoreSendKind _inferSendKind(int command, Uint8List payload) {
    final isReply =
        payload.length >= _kMrrpPrefix.length &&
        _startsWithBytes(payload, _kMrrpPrefix);
    final isChannel = command == MeshCoreCommands.sendChannelTxtMsg;
    if (isReply) {
      return isChannel
          ? MeshCoreSendKind.replyChannel
          : MeshCoreSendKind.replyContact;
    }
    return isChannel
        ? MeshCoreSendKind.plainChannel
        : MeshCoreSendKind.plainContact;
  }

  static bool _startsWithBytes(Uint8List bytes, List<int> prefix) {
    for (int i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) return false;
    }
    return true;
  }

  /// `[mrrp]` as raw UTF-8 bytes. Mirrors `kFallbackPrefix` from the
  /// chat-meta envelope codec; copied locally so the session does not
  /// import the codec just to read this constant.
  static const List<int> _kMrrpPrefix = [0x5B, 0x6D, 0x72, 0x72, 0x70, 0x5D];

  // ---------------------------------------------------------------------------
  // High-level Protocol Primitives
  // ---------------------------------------------------------------------------

  /// Minimum payload size for a valid SELF_INFO response.
  static const int _minSelfInfoPayloadSize = 35;

  /// App name sent in APP_START frame.
  static const String _appName = 'SocialMesh';

  /// Build a CMD_DEVICE_QUERY frame.
  ///
  /// Format: [cmd: 1 byte][app_version: 1 byte]
  /// Firmware requires len >= 2 for this command.
  static Uint8List _buildDeviceQueryFrame() {
    return Uint8List.fromList([
      MeshCoreCommands.deviceQuery,
      MeshCoreFramingConstants.appProtocolVersion,
    ]);
  }

  /// Build a CMD_APP_START frame.
  ///
  /// Format: [cmd: 1 byte][app_version: 1 byte][reserved: 6 bytes][app_name...][null]
  /// Firmware requires len >= 8 for this command.
  static Uint8List _buildAppStartFrame() {
    final builder = BytesBuilder();
    builder.addByte(MeshCoreCommands.appStart);
    builder.addByte(MeshCoreFramingConstants.appProtocolVersion);
    builder.add(Uint8List(6)); // 6 reserved bytes
    builder.add(Uint8List.fromList(_appName.codeUnits));
    builder.addByte(0); // null terminator
    return builder.toBytes();
  }

  /// Get device self info using the MeshCore startup sequence.
  ///
  /// Sends cmdDeviceQuery + cmdAppStart, waits for respSelfInfo.
  /// Returns parsed SelfInfo, null on timeout, or throws [MeshCoreParseException]
  /// on parse failure.
  ///
  /// This method properly handles status/ACK frames (code 0x01) that the device
  /// may send before the actual SELF_INFO response. ACK frames are logged but
  /// do not satisfy the waiter.
  ///
  /// Frame formats (from MeshCore firmware):
  /// - deviceQuery: [0x16][app_version] (2 bytes min)
  /// - appStart: [0x01][app_version][reserved x6][app_name...] (8 bytes min)
  Future<MeshCoreSelfInfo?> getSelfInfo({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    AppLogging.protocol(
      'MeshCore: getSelfInfo() starting (timeout=${timeout.inSeconds}s)',
    );

    // Use validated waiter that requires minimum payload size
    // This ensures we don't complete on tiny ACK-like frames even if they
    // somehow have code 0x05
    final completer = _registerValidatedWaiter(
      MeshCoreResponses.selfInfo,
      (frame) => frame.payload.length >= _minSelfInfoPayloadSize,
    );

    // Build and send startup sequence with proper frame formats
    // The firmware checks len >= 2 for deviceQuery, len >= 8 for appStart
    final deviceQueryFrame = _buildDeviceQueryFrame();
    AppLogging.protocol(
      'MeshCore: Sending deviceQuery (0x16) [${deviceQueryFrame.length} bytes]...',
    );
    await _transport.sendRaw(deviceQueryFrame);
    _capture?.recordTx(
      MeshCoreFrame(
        command: MeshCoreCommands.deviceQuery,
        payload: deviceQueryFrame.sublist(1),
      ),
    );

    final appStartFrame = _buildAppStartFrame();
    AppLogging.protocol(
      'MeshCore: Sending appStart (0x01) [${appStartFrame.length} bytes]...',
    );
    await _transport.sendRaw(appStartFrame);
    _capture?.recordTx(
      MeshCoreFrame(
        command: MeshCoreCommands.appStart,
        payload: appStartFrame.sublist(1),
      ),
    );

    AppLogging.protocol(
      'MeshCore: Waiting for selfInfo response (code=0x05, min $_minSelfInfoPayloadSize bytes)...',
    );

    // Wait for response
    MeshCoreFrame? response;
    try {
      response = await completer.future.timeout(
        timeout,
        onTimeout: () {
          _validatedWaiters.remove(MeshCoreResponses.selfInfo);
          // Debug: dump capture if available
          if (kDebugMode && _capture != null) {
            AppLogging.protocol(
              'MeshCore: getSelfInfo() TIMEOUT - capture dump:\n'
              '${_capture!.toCompactHexLog()}',
            );
          }
          AppLogging.protocol(
            'MeshCore: getSelfInfo() timeout after ${timeout.inSeconds}s',
          );
          throw TimeoutException('Self info timeout');
        },
      );
    } on TimeoutException {
      return null;
    }

    AppLogging.protocol(
      'MeshCore: Received selfInfo response (${response.payload.length} bytes)',
    );

    // Parse response
    final result = parseSelfInfo(response.payload);
    if (!result.isSuccess) {
      AppLogging.protocol(
        'MeshCore: Failed to parse selfInfo: ${result.error}',
      );
      throw MeshCoreParseException(
        code: response.command,
        payload: response.payload,
        message: result.error ?? 'Failed to parse self info',
      );
    }

    AppLogging.protocol('MeshCore: getSelfInfo() success: ${result.value}');
    return result.value;
  }

  /// Get battery and storage info.
  ///
  /// This is also used as a connectivity check since MeshCore has no ping/pong.
  /// Returns parsed BattAndStorage or null on timeout/error.
  Future<MeshCoreBattAndStorage?> getBattAndStorage({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final response = await sendAndWait(
      MeshCoreCommands.getBattAndStorage,
      expectedResponse: MeshCoreResponses.battAndStorage,
      timeout: timeout,
    );

    if (response == null) return null;

    final result = parseBattAndStorage(response.payload);
    return result.value;
  }

  /// D35-A: fetch the firmware-side RADIO stats subtype.
  ///
  /// Wire: outbound `[CMD_GET_STATS=0x38][STATS_TYPE_RADIO=1]` (2 B);
  /// inbound `[RESP_CODE_STATS=0x18][STATS_TYPE_RADIO=1] + 12 B
  /// payload`. The parser (`MeshCoreRadioStats.parse`) rejects wrong
  /// length / wrong discriminator / wrong subtype.
  ///
  /// Returns `null` on timeout, transport drop, or any payload that
  /// fails the discriminator/length checks. UI callers must treat
  /// null as "no fresh data" and either keep the previous snapshot
  /// or fall back to the disconnected placeholder. UI callers MUST
  /// NOT surface this as an error to the user (firmware blips and
  /// transport reconnects are normal).
  ///
  /// **Bypasses `MeshCoreSendRateLimiter`**: this is a host-side
  /// management request, not a chat-bound text send, so it does not
  /// compete for the 1024 B / 60 s D34a budget. Pinned by a session
  /// regression test that asserts `ChatTrafficSnapshot.currentWindow`
  /// counters do NOT bump across `getRadioStats()` polls.
  Future<MeshCoreRadioStats?> getRadioStats({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (_statsRequestInFlight) {
      AppLogging.meshcore('event=radio_stats.skipped reason=stats_in_flight');
      return null;
    }
    _statsRequestInFlight = true;

    final MeshCoreFrame? response;
    try {
      response = await sendAndWait(
        MeshCoreCommands.getStats,
        payload: Uint8List.fromList([MeshCoreStatsType.radio]),
        expectedResponse: MeshCoreResponses.stats,
        timeout: timeout,
      );
    } finally {
      _statsRequestInFlight = false;
    }

    if (response == null) {
      AppLogging.meshcore('event=radio_stats.timeout');
      return null;
    }

    // The response payload is the body AFTER the command byte. To
    // parse via `MeshCoreRadioStats.parse` we need to reconstruct the
    // full 14-byte frame (resp_code + subtype + 12 B body). The
    // `response.command` carries 0x18 and `response.payload` carries
    // the body starting with the subtype byte.
    final body = response.payload;
    if (body.length != 13) {
      // Wrong subtype (CORE / PACKETS) or truncated frame. Drop
      // silently; caller treats as transient.
      return null;
    }
    final reframed = Uint8List(14);
    reframed[0] = MeshCoreResponses.stats;
    reframed.setRange(1, 14, body);

    final stats = MeshCoreRadioStats.parse(reframed);
    if (stats == null) return null;

    AppLogging.meshcore(
      'event=radio_stats.fetched '
      'noise=${stats.noiseFloorDbm} '
      'rssi=${stats.lastRssiDbm} '
      'snr_q=${stats.lastSnrQuarter} '
      'tx_s=${stats.txAirtime.inSeconds} '
      'rx_s=${stats.rxAirtime.inSeconds}',
    );
    return stats;
  }

  /// D35-B-A: fetch the firmware-side CORE stats subtype.
  ///
  /// Wire: outbound `[CMD_GET_STATS=0x38][STATS_TYPE_CORE=0]` (2 B);
  /// inbound `[RESP_CODE_STATS=0x18][STATS_TYPE_CORE=0] + 9 B
  /// payload`. The parser (`MeshCoreCoreStats.parse`) rejects wrong
  /// length / wrong discriminator / wrong subtype.
  ///
  /// Returns `null` on timeout, transport drop, or any payload that
  /// fails the discriminator/length checks. UI callers must treat
  /// null as "no fresh data" and either keep the previous snapshot
  /// or fall back to the disconnected placeholder. UI callers MUST
  /// NOT surface this as an error to the user (firmware blips and
  /// transport reconnects are normal).
  ///
  /// **Bypasses `MeshCoreSendRateLimiter`**: this is a host-side
  /// management request, not a chat-bound text send, so it does not
  /// compete for the 1024 B / 60 s D34a budget. Pinned by the same
  /// session regression test pattern that asserts
  /// `ChatTrafficSnapshot.currentWindow` counters do NOT bump across
  /// `getCoreStats()` polls.
  Future<MeshCoreCoreStats?> getCoreStats({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (_statsRequestInFlight) {
      AppLogging.meshcore('event=core_stats.skipped reason=stats_in_flight');
      return null;
    }
    _statsRequestInFlight = true;

    final MeshCoreFrame? response;
    try {
      response = await sendAndWait(
        MeshCoreCommands.getStats,
        payload: Uint8List.fromList([MeshCoreStatsType.core]),
        expectedResponse: MeshCoreResponses.stats,
        timeout: timeout,
      );
    } finally {
      _statsRequestInFlight = false;
    }

    if (response == null) {
      AppLogging.meshcore('event=core_stats.timeout');
      return null;
    }

    // The response payload is the body AFTER the command byte.
    // Reconstruct the full 11-byte frame so the parser can validate
    // the resp_code + subtype discriminators against its own
    // expectations. CORE body length is 10 (subtype + 9 fields):
    // u16 batt + u32 uptime + u16 err_flags + u8 queue_len.
    final body = response.payload;
    if (body.length != 10) {
      // Wrong subtype (RADIO / PACKETS) or truncated frame. Drop
      // silently; caller treats as transient.
      return null;
    }
    final reframed = Uint8List(11);
    reframed[0] = MeshCoreResponses.stats;
    reframed.setRange(1, 11, body);

    final stats = MeshCoreCoreStats.parse(reframed);
    if (stats == null) return null;

    AppLogging.meshcore(
      'event=core_stats.fetched '
      'uptime_s=${stats.uptime.inSeconds} '
      'q=${stats.queueLength} '
      'err_flags=0x'
      '${stats.errorFlags.toRadixString(16).padLeft(4, '0')}',
    );
    return stats;
  }

  /// D35-PACKETS-A: fetch the firmware-side PACKETS stats subtype.
  ///
  /// Wire: outbound `[CMD_GET_STATS=0x38][STATS_TYPE_PACKETS=2]`
  /// (2 B); inbound `[RESP_CODE_STATS=0x18][STATS_TYPE_PACKETS=2] +
  /// 28 B payload`. The parser (`MeshCorePacketsStats.parse`) rejects
  /// wrong length / wrong discriminator / wrong subtype.
  ///
  /// Returns `null` on timeout, transport drop, or any payload that
  /// fails the discriminator/length checks. UI callers must treat
  /// null as "no fresh data" and either keep the previous snapshot
  /// or fall back to the disconnected placeholder. UI callers MUST
  /// NOT surface this as an error (firmware blips and transport
  /// reconnects are normal).
  ///
  /// **Bypasses `MeshCoreSendRateLimiter`**: this is a host-side
  /// management request, not a chat-bound text send, so it does not
  /// compete for the 1024 B / 60 s D34a budget. Pinned by the
  /// session regression test.
  Future<MeshCorePacketsStats?> getPacketsStats({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (_statsRequestInFlight) {
      AppLogging.meshcore('event=packets_stats.skipped reason=stats_in_flight');
      return null;
    }
    _statsRequestInFlight = true;

    final MeshCoreFrame? response;
    try {
      response = await sendAndWait(
        MeshCoreCommands.getStats,
        payload: Uint8List.fromList([MeshCoreStatsType.packets]),
        expectedResponse: MeshCoreResponses.stats,
        timeout: timeout,
      );
    } finally {
      _statsRequestInFlight = false;
    }

    if (response == null) {
      AppLogging.meshcore('event=packets_stats.timeout');
      return null;
    }

    // The response payload is the body AFTER the command byte.
    // Reconstruct the full 30-byte frame so the parser can validate
    // the resp_code + subtype discriminators against its own
    // expectations. PACKETS body length is 29 (subtype + 7 u32
    // counters = 1 + 28 = 29).
    final body = response.payload;
    if (body.length != 29) {
      // Wrong subtype (RADIO / CORE) or truncated frame. Drop
      // silently; caller treats as transient.
      return null;
    }
    final reframed = Uint8List(30);
    reframed[0] = MeshCoreResponses.stats;
    reframed.setRange(1, 30, body);

    final stats = MeshCorePacketsStats.parse(reframed);
    if (stats == null) return null;

    AppLogging.meshcore(
      'event=packets_stats.fetched '
      'rx=${stats.packetsReceived} '
      'tx=${stats.packetsSent} '
      'tx_flood=${stats.sentFlood} '
      'tx_direct=${stats.sentDirect} '
      'rx_flood=${stats.recvFlood} '
      'rx_direct=${stats.recvDirect} '
      'rx_err=${stats.recvErrors}',
    );
    return stats;
  }

  /// D36-A: send a binary request to a target peer (typically a
  /// repeater) over LoRa via `CMD_SEND_BINARY_REQ` (0x32) and await
  /// the asynchronous `PUSH_CODE_BINARY_RESPONSE` (0x8C) reply with a
  /// firmware-assigned correlation tag.
  ///
  /// Wire shapes:
  /// ```
  /// outbound:  [0x32][recipientPubKey: 32 B][requestBytes: variable]
  ///
  /// sync ACK:  [0x06 RESP_CODE_SENT][route_type:u8][tag:u32 LE]
  ///            [est_timeout_ms:u32 LE]
  ///
  /// async push: [0x8C PUSH_CODE_BINARY_RESPONSE][reserved:u8]
  ///             [tag:u32 LE][response_data: variable]
  /// ```
  ///
  /// The host does NOT supply the tag — the firmware allocates it and
  /// echoes it in the SENT ack. We extract the tag from the ack and
  /// match against subsequent push frames; non-matching pushes are
  /// ignored.
  ///
  /// Returns the `response_data` (push payload from offset 6 onward)
  /// on success, or `null` on:
  ///   - single-flight rejection (a previous binary request is still
  ///     pending; the firmware can only track one tag at a time),
  ///   - no SENT ack within the inner 3 s ACK window,
  ///   - no matching push within [timeout],
  ///   - transport drop / parse failure.
  ///
  /// Bypasses `MeshCoreSendRateLimiter`: this is a host-side
  /// management RPC, not a chat-bound text send. Pinned by a session
  /// regression test asserting `ChatTrafficSnapshot.currentWindow`
  /// counters do NOT bump across `sendBinaryRequest` calls.
  ///
  /// Privacy: logs `target=<8B fingerprint>` only; never the full
  /// pubkey or the request/response payload bytes.
  ///
  /// The helper is intentionally narrow. D36-A's neighbours feature
  /// is the only caller; future binary-request features (telemetry,
  /// etc.) MUST add their own dedicated wrapper with its own recon
  /// rather than reusing this method as a generic binary-RPC tunnel.
  Future<Uint8List?> sendBinaryRequest({
    required Uint8List recipientPubKey,
    required Uint8List requestBytes,
    int expectedResponseCode = MeshCorePushCodes.binaryResponse,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (recipientPubKey.length != meshCorePubKeySize) {
      throw ArgumentError.value(
        recipientPubKey.length,
        'recipientPubKey.length',
        'must be exactly $meshCorePubKeySize bytes',
      );
    }

    if (_binaryRequestInFlight) {
      AppLogging.meshcore(
        'event=binary_request.rejected reason=in_flight '
        'target=${AppLogging.publicKeyFingerprint(recipientPubKey)}',
        error: true,
      );
      return null;
    }
    _binaryRequestInFlight = true;

    final builder = BytesBuilder();
    builder.add(recipientPubKey);
    builder.add(requestBytes);
    final outboundPayload = builder.toBytes();

    final completer = Completer<Uint8List?>();
    final pendingPushes = <(int, Uint8List)>[];
    int? expectedTag;

    // D41-A: telemetry responses (`PUSH_CODE_TELEMETRY_RESPONSE 0x8B`)
    // use a DIFFERENT wire layout from generic binary responses. The
    // firmware emits `[opcode][reserved=0][6-byte pubkey prefix][lpp]`
    // there (no tag in the push). Correlate by pubkey prefix instead.
    // Single-flight is already enforced at the session level so there
    // is never more than one telemetry round-trip in flight to
    // confuse.
    final bool isTelemetry =
        expectedResponseCode == MeshCorePushCodes.telemetryResponse;

    StreamSubscription<MeshCoreFrame>? pushSub;
    pushSub = frameStream.listen((frame) {
      if (frame.command != expectedResponseCode) return;
      if (isTelemetry) {
        // Layout: [reserved:u8][pubkey_prefix:6 B][lpp_payload:...]
        if (frame.payload.length < 7) return;
        for (int i = 0; i < 6; i++) {
          if (frame.payload[1 + i] != recipientPubKey[i]) return;
        }
        final data = Uint8List.fromList(frame.payload.sublist(7));
        if (!completer.isCompleted) {
          completer.complete(data);
        }
        return;
      }
      // `frame.payload` is everything after the wire opcode byte:
      //   payload[0]    = reserved
      //   payload[1..5] = tag (u32 LE)
      //   payload[5..]  = response_data
      if (frame.payload.length < 5) return;
      final pushTag = ByteData.sublistView(
        frame.payload,
      ).getUint32(1, Endian.little);
      final data = Uint8List.fromList(frame.payload.sublist(5));
      if (expectedTag == null) {
        // SENT ack hasn't landed yet; buffer the push so we can
        // match it once the tag is known. Handles the race where
        // the remote peer replies before our local ACK round-trip
        // completes.
        pendingPushes.add((pushTag, data));
        return;
      }
      if (pushTag == expectedTag && !completer.isCompleted) {
        completer.complete(data);
      }
    });

    try {
      final ack = await sendAndWait(
        MeshCoreCommands.sendBinaryReq,
        payload: outboundPayload,
        expectedResponse: MeshCoreResponses.sent,
        timeout: const Duration(seconds: 3),
      );

      // `ack.payload` is everything after the 0x06 wire opcode:
      //   payload[0]    = route_type
      //   payload[1..5] = tag (u32 LE)
      //   payload[5..9] = est_timeout_ms (u32 LE)
      if (ack == null || ack.payload.length < 9) {
        AppLogging.meshcore(
          'event=binary_request.no_ack '
          'target=${AppLogging.publicKeyFingerprint(recipientPubKey)}',
          error: true,
        );
        return null;
      }

      final tag = ByteData.sublistView(ack.payload).getUint32(1, Endian.little);
      final estTimeoutMs = ByteData.sublistView(
        ack.payload,
      ).getUint32(5, Endian.little);
      expectedTag = tag;

      AppLogging.meshcore(
        'event=binary_request.ack_received '
        'tag=0x${tag.toRadixString(16).padLeft(8, '0')} '
        'est_timeout_ms=$estTimeoutMs',
      );

      // Drain any pushes that arrived before the ACK.
      for (final (t, d) in pendingPushes) {
        if (t == tag && !completer.isCompleted) {
          completer.complete(d);
          break;
        }
      }

      final response = await completer.future.timeout(
        timeout,
        onTimeout: () => null,
      );
      if (response == null) {
        AppLogging.meshcore(
          'event=binary_request.timeout '
          'target=${AppLogging.publicKeyFingerprint(recipientPubKey)} '
          'tag=0x${tag.toRadixString(16).padLeft(8, '0')}',
          error: true,
        );
        return null;
      }

      AppLogging.meshcore(
        'event=binary_request.response_received '
        'tag=0x${tag.toRadixString(16).padLeft(8, '0')} '
        'bytes=${response.length}',
      );
      return response;
    } catch (e) {
      AppLogging.meshcore(
        'event=binary_request.failed '
        'target=${AppLogging.publicKeyFingerprint(recipientPubKey)} '
        'reason=${e.runtimeType}',
        error: true,
      );
      return null;
    } finally {
      await pushSub.cancel();
      _binaryRequestInFlight = false;
    }
  }

  /// D41-A: request a contact's Cayenne LPP telemetry over LoRa via
  /// the existing `sendBinaryRequest` plumbing.
  ///
  /// Wire request:
  ///   `[CMD_SEND_BINARY_REQ 0x32][recipientPubKey:32 B]`
  ///   `[REQ_TYPE_GET_TELEMETRY_DATA 0x03][permission_mask 0x00]`
  ///
  /// Wire response:
  ///   `[PUSH_CODE_TELEMETRY_RESPONSE 0x8B][reserved 0]`
  ///   `[pubkey_prefix:6 B][cayenne_lpp_tlv:...]`
  ///
  /// `permission_mask = 0x00` asks the responder for everything its
  /// `telemetry_mode_*` flags allow. The responder may omit channels
  /// at its own discretion; we surface whatever arrives.
  ///
  /// Returns `null` on:
  ///   - empty / missing `recipientPubKey` (asserts in debug),
  ///   - single-flight rejection (another binary request in flight),
  ///   - ACK timeout (no `RESP_CODE_SENT` from local radio),
  ///   - response timeout (no matching `0x8B` push within [timeout]).
  ///
  /// On success returns a `MeshCoreTelemetryResponse` carrying the
  /// parsed Cayenne LPP readings. The LPP parser tolerates trailing
  /// truncation and unknown-but-known-size types; a malformed
  /// payload returns a response with whatever readings parsed cleanly
  /// before the issue (never throws to the caller).
  Future<MeshCoreTelemetryResponse?> requestTelemetry(
    Uint8List recipientPubKey, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final response = await sendBinaryRequest(
      recipientPubKey: recipientPubKey,
      requestBytes: Uint8List.fromList(const [0x03, 0x00]),
      expectedResponseCode: MeshCorePushCodes.telemetryResponse,
      timeout: timeout,
    );
    if (response == null) {
      return null;
    }
    return parseCayenneLpp(response, fetchedAt: DateTime.now());
  }

  /// Check device connectivity using battery request.
  ///
  /// MeshCore has no explicit ping/pong, so we use battery request
  /// as a connectivity check. Returns latency on success, null on timeout.
  Future<Duration?> ping({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final stopwatch = Stopwatch()..start();

    final result = await getBattAndStorage(timeout: timeout);

    stopwatch.stop();

    if (result == null) return null;
    return stopwatch.elapsed;
  }

  // ---------------------------------------------------------------------------
  // Contacts
  // ---------------------------------------------------------------------------

  /// Request contacts list from device.
  ///
  /// Sends CMD_GET_CONTACTS and collects all CONTACT responses until
  /// END_OF_CONTACTS is received.
  ///
  /// Returns list of parsed contacts, or empty list on timeout/error.
  Future<List<MeshCoreContactInfo>> getContacts({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    AppLogging.protocol('MeshCore: getContacts() starting...');
    AppLogging.meshcore('event=contacts.fetch.started');

    final contacts = <MeshCoreContactInfo>[];

    // Register waiter for END_OF_CONTACTS
    final endCompleter = _registerWaiter(MeshCoreResponses.endOfContacts);

    // Listen for CONTACT frames
    final contactSubscription = frameStream
        .where((f) => f.command == MeshCoreResponses.contact)
        .listen((frame) {
          final result = parseContact(frame.payload);
          if (result.isSuccess && result.value != null) {
            contacts.add(result.value!);
            AppLogging.protocol(
              'MeshCore: Received contact: ${result.value!.name}',
            );
          }
        });

    try {
      // Send GET_CONTACTS command
      await sendCommand(MeshCoreCommands.getContacts);

      // Wait for END_OF_CONTACTS
      await endCompleter.future.timeout(
        timeout,
        onTimeout: () {
          _pendingResponses.remove(MeshCoreResponses.endOfContacts);
          throw TimeoutException('Contacts timeout');
        },
      );

      AppLogging.protocol(
        'MeshCore: getContacts() complete: ${contacts.length} contacts',
      );
      AppLogging.meshcore(
        'event=contacts.fetch.completed result=ok count=${contacts.length}',
      );
      return contacts;
    } on TimeoutException {
      AppLogging.protocol('MeshCore: getContacts() timeout');
      AppLogging.meshcore(
        'event=contacts.fetch.completed result=timeout '
        'count=${contacts.length}',
        error: true,
      );
      return contacts; // Return what we got so far
    } finally {
      await contactSubscription.cancel();
    }
  }

  // ---------------------------------------------------------------------------
  // Channels
  // ---------------------------------------------------------------------------

  /// Request channel info from device.
  ///
  /// Sends CMD_GET_CHANNEL for each index and collects CHANNEL_INFO responses.
  /// MeshCore typically supports 8 channels (indices 0-7).
  ///
  /// Returns list of parsed channels, or empty list on error.
  Future<List<MeshCoreChannelInfo>> getChannels({
    int maxChannels = 8,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    AppLogging.protocol('MeshCore: getChannels() starting...');
    AppLogging.meshcore('event=channels.fetch.started max=$maxChannels');

    final channels = <MeshCoreChannelInfo>[];

    for (int i = 0; i < maxChannels; i++) {
      try {
        final response = await sendAndWait(
          MeshCoreCommands.getChannel,
          payload: Uint8List.fromList([i]),
          expectedResponse: MeshCoreResponses.channelInfo,
          timeout: Duration(seconds: 2),
        );

        if (response != null) {
          final result = parseChannelInfo(response.payload);
          if (result.isSuccess && result.value != null) {
            // Skip empty channels
            if (!result.value!.isEmpty) {
              channels.add(result.value!);
              AppLogging.protocol(
                'MeshCore: Received channel $i: ${result.value!.name}',
              );
            }
          }
        }
      } catch (e) {
        AppLogging.protocol('MeshCore: getChannels() error for index $i: $e');
        // Continue to next channel
      }
    }

    AppLogging.protocol(
      'MeshCore: getChannels() complete: ${channels.length} channels',
    );
    AppLogging.meshcore(
      'event=channels.fetch.completed count=${channels.length}',
    );
    return channels;
  }

  /// Set a channel slot on the device.
  ///
  /// Wire format (`CMD_SET_CHANNEL` = `0x20`), payload after cmd byte:
  /// `[idx:u8][name:32 bytes (null-padded)][psk:16 bytes]` = 49 bytes.
  /// Firmware reads `name` as a 32-byte char buffer (null-terminated
  /// within the buffer) and `secret` as 16 raw bytes. The 32-byte secret
  /// branch is signalled by the firmware as `ERR_CODE_UNSUPPORTED_CMD`
  /// at the pinned SHA — only 128-bit keys are supported.
  ///
  /// Firmware returns `RESP_CODE_OK` (0x00) on success, `RESP_CODE_ERR`
  /// (0x01) with `ERR_CODE_NOT_FOUND` on bad slot index. Changes apply
  /// live (`saveChannels()` is called immediately).
  ///
  /// **D31 wire-format fix**: pre-D31 this padded the name region to
  /// 33 bytes (32 + 1 extra null), producing a 50-byte payload. The
  /// firmware accepts that length but reads `secret` from a fixed
  /// offset, so the extra zero became `secret[0]`, shifted the supplied
  /// PSK by 1, and silently dropped `psk[15]`. Every channel write
  /// since this function landed produced a corrupted PSK. Fixed here
  /// to pad to exactly 32 bytes and pinned by a byte-vector test.
  ///
  /// [index] is the channel slot (0-based; firmware capacity is
  /// `MAX_GROUP_CHANNELS`, board-dependent — 8 is the conservative
  /// default our `getChannels` polls).
  /// [name] is the channel name (max 32 bytes; longer names are
  /// truncated. Firmware's `StrHelper::strncpy` accepts 0-32 byte names).
  /// [psk] is the pre-shared key — must be exactly 16 bytes (128-bit).
  Future<bool> setChannel({
    required int index,
    required String name,
    required Uint8List psk,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (index < 0 || index > 255) {
      throw ArgumentError.value(index, 'index', 'must fit in u8');
    }
    if (psk.length != 16) {
      throw ArgumentError.value(
        psk.length,
        'psk.length',
        'PSK must be exactly 16 bytes (128-bit)',
      );
    }
    final nameBytes = name.codeUnits.take(32).toList();
    if (nameBytes.length > 32) {
      throw ArgumentError.value(
        name.length,
        'name.length',
        'name must encode to at most 32 bytes',
      );
    }

    // Build payload: [idx:u8][name:32 (null-padded)][psk:16] = 49 bytes.
    final builder = BytesBuilder();
    builder.addByte(index);
    builder.add(nameBytes);
    for (int i = nameBytes.length; i < 32; i++) {
      builder.addByte(0);
    }
    builder.add(psk);

    final response = await sendAndWait(
      MeshCoreCommands.setChannel,
      payload: builder.toBytes(),
      expectedResponse: MeshCoreResponses.ok,
      timeout: timeout,
    );

    return response != null;
  }

  /// Clear (delete) a channel slot on the device.
  ///
  /// MeshCore firmware has **no dedicated delete-channel opcode** at
  /// the pinned SHA. The effective wire op is `setChannel(idx, "", 0×16)`
  /// — overwrite the slot with empty name + all-zero secret. Our
  /// `parseChannelInfo` then treats the slot as unconfigured
  /// (`MeshCoreChannelInfo.isEmpty`), hiding it from `getChannels`.
  ///
  /// This wrapper exists so callers express intent ("remove this slot")
  /// without each having to know the empty-set convention. The byte
  /// vector this produces is pinned by a separate test from
  /// [setChannel] so a refactor that breaks the convention is caught.
  ///
  /// Caveat: firmware always computes `sha256(secret)` even when the
  /// secret is all zeros, so the slot's stored hash is non-zero after
  /// removal. This is harmless because real channels never use an
  /// all-zero secret, but it's why the firmware-side state is "slot
  /// overwritten with zeros" rather than "slot reset / forgotten".
  ///
  /// Returns `true` when the firmware ACKs the overwrite with
  /// `RESP_CODE_OK` (0x00); `false` on timeout or firmware error.
  Future<bool> removeChannel({
    required int index,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    return setChannel(
      index: index,
      name: '',
      psk: Uint8List(16),
      timeout: timeout,
    );
  }

  // ---------------------------------------------------------------------------
  // Radio parameters
  // ---------------------------------------------------------------------------

  /// Set the LoRa radio parameters on the connected MeshCore device.
  ///
  /// Wire format (`CMD_SET_RADIO_PARAMS`):
  /// `[freq:u32 LE in kHz][bw:u32 LE in Hz][sf:u8][cr:u8]`. The optional
  /// `repeat` byte (firmware version code 9+) is not surfaced here yet.
  ///
  /// Firmware-side validation accepts:
  /// - `freq` 150_000…2_500_000 kHz (150 MHz to 2.5 GHz)
  /// - `bw`   7_000…500_000 Hz (7 kHz to 500 kHz)
  /// - `sf`   5…12
  /// - `cr`   5…8
  ///
  /// Throws [ArgumentError] for out-of-range inputs so the caller never
  /// hits a slow firmware error path. Returns `true` when the radio
  /// acknowledges with `RESP_CODE_OK` (0x00); `false` on timeout or
  /// firmware error response.
  Future<bool> setRadioParams({
    required int freqKhz,
    required int bandwidthHz,
    required int spreadingFactor,
    required int codingRate,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (freqKhz < 150000 || freqKhz > 2500000) {
      throw ArgumentError.value(
        freqKhz,
        'freqKhz',
        'must be between 150000 and 2500000 kHz (150 MHz to 2.5 GHz)',
      );
    }
    if (bandwidthHz < 7000 || bandwidthHz > 500000) {
      throw ArgumentError.value(
        bandwidthHz,
        'bandwidthHz',
        'must be between 7000 and 500000 Hz',
      );
    }
    if (spreadingFactor < 5 || spreadingFactor > 12) {
      throw ArgumentError.value(
        spreadingFactor,
        'spreadingFactor',
        'must be between 5 and 12',
      );
    }
    if (codingRate < 5 || codingRate > 8) {
      throw ArgumentError.value(codingRate, 'codingRate', 'must be 5..8');
    }

    final payload = ByteData(10);
    payload.setUint32(0, freqKhz, Endian.little);
    payload.setUint32(4, bandwidthHz, Endian.little);
    payload.setUint8(8, spreadingFactor);
    payload.setUint8(9, codingRate);

    AppLogging.meshcore(
      'event=radio.set_params freq=${freqKhz}kHz bw=${bandwidthHz}Hz '
      'sf=$spreadingFactor cr=$codingRate',
    );

    final response = await sendAndWait(
      MeshCoreCommands.setRadioParams,
      payload: payload.buffer.asUint8List(),
      expectedResponse: MeshCoreResponses.ok,
      timeout: timeout,
    );

    final ok = response != null;
    AppLogging.meshcore(
      'event=radio.set_params.${ok ? "succeeded" : "failed"}',
      error: !ok,
    );
    return ok;
  }

  /// Set the LoRa transmit power in dBm.
  ///
  /// Wire format: `[power:int8]`. Range -9 to MAX_LORA_TX_POWER (typically
  /// 22 dBm depending on board). The firmware rejects out-of-range values
  /// with `RESP_CODE_ERR`. Returns `true` on `RESP_CODE_OK`.
  Future<bool> setRadioTxPower({
    required int powerDbm,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (powerDbm < -9 || powerDbm > 30) {
      throw ArgumentError.value(
        powerDbm,
        'powerDbm',
        'must be between -9 and 30 dBm',
      );
    }

    final payload = Uint8List(1);
    payload[0] = powerDbm & 0xFF; // int8 two's-complement

    AppLogging.meshcore('event=radio.set_tx_power power=${powerDbm}dBm');

    final response = await sendAndWait(
      MeshCoreCommands.setRadioTxPower,
      payload: payload,
      expectedResponse: MeshCoreResponses.ok,
      timeout: timeout,
    );

    final ok = response != null;
    AppLogging.meshcore(
      'event=radio.set_tx_power.${ok ? "succeeded" : "failed"}',
      error: !ok,
    );
    return ok;
  }

  // ---------------------------------------------------------------------------
  // D29: Contact management commands
  // ---------------------------------------------------------------------------

  /// D29 Part A: add or update a contact in the firmware contact table
  /// (`CMD_ADD_UPDATE_CONTACT` 0x09).
  ///
  /// Wire payload (after the 0x09 opcode byte):
  /// ```
  /// [0..31]   pubkey                  32B
  /// [32]      adv_type                u8
  /// [33]      flags                   u8
  /// [34]      path_len                i8  (-1 / 0xFF = flood / unknown)
  /// [35..98]  path                    64B (zero-padded)
  /// [99..130] name                    32B (UTF-8, null-terminated, padded)
  /// [131..134] last_advert_timestamp  u32 LE (unix seconds; 0 if unknown)
  /// [135..138] gps_lat                i32 LE × 1e6 — included if [latitude] != null
  /// [139..142] gps_lon                i32 LE × 1e6 — included if [longitude] != null
  /// ```
  ///
  /// Firmware enforces a minimum payload of pubkey + type + flags + path_len
  /// + path header + name. The form with GPS exercises the firmware's
  /// optional-fields branch and is forward-compatible with the optional
  /// `lastmod` extension we don't surface.
  ///
  /// Caller MUST pass a 32-byte [pubKey]; the helper rejects partial or
  /// short prefixes (the firmware contact table is keyed on full pubkey
  /// and a partial-prefix add would silently corrupt the table).
  ///
  /// Returns `true` on `RESP_CODE_OK`. Returns `false` on timeout, error
  /// response, or `RESP_CODE_ERR`. Caller should refresh the contact
  /// list from firmware after success — the firmware does not push a
  /// new contact frame.
  Future<bool> addUpdateContact({
    required Uint8List pubKey,
    required int advType,
    required String name,
    int flags = 0,
    int pathLength = -1,
    Uint8List? pathBytes,
    DateTime? lastAdvertAt,
    double? latitude,
    double? longitude,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (pubKey.length != meshCorePubKeySize) {
      throw ArgumentError.value(
        pubKey.length,
        'pubKey.length',
        'must be exactly $meshCorePubKeySize bytes',
      );
    }
    if (advType < 0 || advType > 0xFF) {
      throw ArgumentError.value(advType, 'advType', 'must fit in uint8');
    }
    if (flags < 0 || flags > 0xFF) {
      throw ArgumentError.value(flags, 'flags', 'must fit in uint8');
    }
    if (pathLength < -1 || pathLength > 64) {
      throw ArgumentError.value(
        pathLength,
        'pathLength',
        'must be in [-1, 64] (-1 = flood/unknown)',
      );
    }
    final nameBytes = utf8.encode(name);
    if (nameBytes.length > 31) {
      throw ArgumentError.value(
        name,
        'name',
        'must be at most 31 UTF-8 bytes (got ${nameBytes.length})',
      );
    }
    final hasGps = latitude != null && longitude != null;
    if (latitude != null && (latitude < -90 || latitude > 90)) {
      throw ArgumentError.value(latitude, 'latitude', 'must be [-90, 90]');
    }
    if (longitude != null && (longitude < -180 || longitude > 180)) {
      throw ArgumentError.value(longitude, 'longitude', 'must be [-180, 180]');
    }

    // Total payload size: 32+1+1+1+64+32+4 = 135 (no GPS), 143 (with GPS).
    final totalLen = hasGps ? 143 : 135;
    final payload = Uint8List(totalLen);
    final view = ByteData.view(payload.buffer);

    payload.setRange(0, 32, pubKey);
    payload[32] = advType;
    payload[33] = flags;
    payload[34] =
        pathLength & 0xFF; // signed int8 written as u8 two's complement
    final path = pathBytes ?? const <int>[];
    final pathCopyLen = path.length > 64 ? 64 : path.length;
    if (pathCopyLen > 0) {
      payload.setRange(35, 35 + pathCopyLen, path);
    }
    // Name at offset 99..130, null-terminator+padding handled by Uint8List
    // default zero-fill (we never write past nameBytes.length).
    payload.setRange(99, 99 + nameBytes.length, nameBytes);
    final tsSecs = lastAdvertAt == null
        ? 0
        : (lastAdvertAt.toUtc().millisecondsSinceEpoch ~/ 1000) & 0xFFFFFFFF;
    view.setUint32(131, tsSecs, Endian.little);
    if (hasGps) {
      view.setInt32(
        135,
        (latitude * kMeshCoreAdvertLatLonScale).round(),
        Endian.little,
      );
      view.setInt32(
        139,
        (longitude * kMeshCoreAdvertLatLonScale).round(),
        Endian.little,
      );
    }

    AppLogging.meshcore(
      'event=contact.add_update.attempted name_len=${nameBytes.length} '
      'adv_type=$advType path_len=$pathLength has_gps=$hasGps',
    );
    final response = await sendAndWait(
      MeshCoreCommands.addUpdateContact,
      payload: payload,
      expectedResponse: MeshCoreResponses.ok,
      timeout: timeout,
    );
    final ok = response != null;
    AppLogging.meshcore(
      'event=contact.add_update.${ok ? "succeeded" : "failed"} '
      'name_len=${nameBytes.length}',
      error: !ok,
    );
    return ok;
  }

  /// D29 Part B: remove a contact from the firmware contact table
  /// (`CMD_REMOVE_CONTACT` 0x0F).
  ///
  /// Wire payload: `[0x0F][pubkey 32B]` (33 bytes total).
  ///
  /// Caller MUST pass the full 32-byte pubkey. Returns `true` on
  /// `RESP_CODE_OK`, `false` on `RESP_CODE_ERR` (e.g. contact not in
  /// firmware table) or timeout.
  Future<bool> removeContact(
    Uint8List pubKey, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (pubKey.length != meshCorePubKeySize) {
      throw ArgumentError.value(
        pubKey.length,
        'pubKey.length',
        'must be exactly $meshCorePubKeySize bytes',
      );
    }
    AppLogging.meshcore('event=contact.remove.attempted');
    final response = await sendAndWait(
      MeshCoreCommands.removeContact,
      payload: Uint8List.fromList(pubKey),
      expectedResponse: MeshCoreResponses.ok,
      timeout: timeout,
    );
    final ok = response != null;
    AppLogging.meshcore(
      'event=contact.remove.${ok ? "succeeded" : "failed"}',
      error: !ok,
    );
    return ok;
  }

  /// D46-A: broadcast OUR contact card to nearby peers via
  /// `CMD_SHARE_CONTACT 0x10`. The firmware re-broadcasts its stored
  /// self-advertisement zero-hop; receiving radios see this as a
  /// normal advert (`pushCodeNewAdvert 0x8A`).
  ///
  /// Wire payload: `[0x10][selfPubKey:32B]` (33 bytes total). Caller
  /// passes the LOCAL device's pubkey (from `MeshCoreSelfInfo`);
  /// firmware uses it to identify which contact card to broadcast.
  ///
  /// Returns `true` on `RESP_CODE_OK`, `false` on `RESP_CODE_ERR` or
  /// timeout. The receive side is asynchronous — there's no per-peer
  /// confirmation that an advert was heard.
  Future<bool> shareSelfContact(
    Uint8List selfPubKey, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (selfPubKey.length != meshCorePubKeySize) {
      throw ArgumentError.value(
        selfPubKey.length,
        'selfPubKey.length',
        'must be exactly $meshCorePubKeySize bytes',
      );
    }
    AppLogging.meshcore('event=contact.share.attempted');
    final response = await sendAndWait(
      MeshCoreCommands.shareContact,
      payload: Uint8List.fromList(selfPubKey),
      expectedResponse: MeshCoreResponses.ok,
      timeout: timeout,
    );
    final ok = response != null;
    AppLogging.meshcore(
      'event=contact.share.${ok ? "succeeded" : "failed"}',
      error: !ok,
    );
    return ok;
  }

  /// D46-A: export the 135..147-byte canonical contact frame for the
  /// contact identified by [pubKey] via `CMD_EXPORT_CONTACT 0x11`.
  ///
  /// Wire payload: `[0x11][pubKey:32B]` (33 bytes total). Firmware
  /// replies with `RESP_CODE_EXPORT_CONTACT (0x0B)` whose payload is
  /// the contact frame ready to round-trip through
  /// `CMD_IMPORT_CONTACT` on another radio.
  ///
  /// Returns the frame bytes on success, null on timeout, error, or
  /// a short frame (< 135 bytes) that the firmware shouldn't have
  /// emitted but we reject defensively.
  Future<Uint8List?> exportContact(
    Uint8List pubKey, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (pubKey.length != meshCorePubKeySize) {
      throw ArgumentError.value(
        pubKey.length,
        'pubKey.length',
        'must be exactly $meshCorePubKeySize bytes',
      );
    }
    AppLogging.meshcore('event=contact.export.attempted');
    final response = await sendAndWait(
      MeshCoreCommands.exportContact,
      payload: Uint8List.fromList(pubKey),
      expectedResponse: MeshCoreResponses.exportContact,
      timeout: timeout,
    );
    if (response == null) {
      AppLogging.meshcore('event=contact.export.failed', error: true);
      return null;
    }
    final payload = Uint8List.fromList(response.payload);
    if (payload.length < 135 || payload.length > 147) {
      AppLogging.meshcore(
        'event=contact.export.malformed bytes=${payload.length}',
        error: true,
      );
      return null;
    }
    AppLogging.meshcore(
      'event=contact.export.succeeded bytes=${payload.length}',
    );
    return payload;
  }

  /// D46-A: push a contact frame into the firmware roster via
  /// `CMD_IMPORT_CONTACT 0x12`. Caller is responsible for frame
  /// validity (`MeshCoreContactUrl.decode` validates byte-range);
  /// the firmware performs its own structural check and returns
  /// `RESP_CODE_ERR` on rejection.
  ///
  /// Wire payload: `[0x12][frame:135..147B]`.
  ///
  /// Returns `true` on `RESP_CODE_OK`, `false` on `RESP_CODE_ERR`,
  /// timeout, or an out-of-range frame (caught client-side before
  /// hitting the wire).
  Future<bool> importContact(
    Uint8List contactFrame, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (contactFrame.length < 135 || contactFrame.length > 147) {
      throw ArgumentError.value(
        contactFrame.length,
        'contactFrame.length',
        'must be in 135..147 bytes',
      );
    }
    AppLogging.meshcore(
      'event=contact.import.attempted bytes=${contactFrame.length}',
    );
    final response = await sendAndWait(
      MeshCoreCommands.importContact,
      payload: Uint8List.fromList(contactFrame),
      expectedResponse: MeshCoreResponses.ok,
      timeout: timeout,
    );
    final ok = response != null;
    AppLogging.meshcore(
      'event=contact.import.${ok ? "succeeded" : "failed"}',
      error: !ok,
    );
    return ok;
  }

  /// D47-A: read the firmware's current auto-add config via
  /// `CMD_GET_AUTO_ADD_CONFIG 0x3B`.
  ///
  /// Wire request: `[0x3B]` (no payload).
  /// Wire response: `RESP_CODE_AUTO_ADD_CONFIG 0x19` with a single
  /// flags byte (see [MeshCoreAutoAddFlag]).
  ///
  /// Returns the parsed config on success, null on timeout / error,
  /// short response, or empty payload.
  Future<MeshCoreAutoAddConfig?> getAutoAddConfig({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    AppLogging.meshcore('event=auto_add_config.load.attempted');
    final response = await sendAndWait(
      MeshCoreCommands.getAutoAddConfig,
      expectedResponse: MeshCoreResponses.autoAddConfig,
      timeout: timeout,
    );
    if (response == null) {
      AppLogging.meshcore('event=auto_add_config.load.failed', error: true);
      return null;
    }
    if (response.payload.isEmpty) {
      AppLogging.meshcore(
        'event=auto_add_config.load.malformed bytes=0',
        error: true,
      );
      return null;
    }
    final config = MeshCoreAutoAddConfig.fromFlagsByte(response.payload[0]);
    AppLogging.meshcore(
      'event=auto_add_config.load.succeeded '
      'flags=0x${config.toFlagsByte().toRadixString(16).padLeft(2, '0')}',
    );
    return config;
  }

  /// D47-A: write [config] to the firmware via
  /// `CMD_SET_AUTO_ADD_CONFIG 0x3A`.
  ///
  /// Wire payload: `[0x3A][flags:1B]` (2 bytes total).
  ///
  /// Returns `true` on `RESP_CODE_OK`, false on `RESP_CODE_ERR` or
  /// timeout.
  Future<bool> setAutoAddConfig(
    MeshCoreAutoAddConfig config, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final flagsByte = config.toFlagsByte();
    AppLogging.meshcore(
      'event=auto_add_config.set.attempted '
      'flags=0x${flagsByte.toRadixString(16).padLeft(2, '0')}',
    );
    final response = await sendAndWait(
      MeshCoreCommands.setAutoAddConfig,
      payload: Uint8List.fromList([flagsByte]),
      expectedResponse: MeshCoreResponses.ok,
      timeout: timeout,
    );
    final ok = response != null;
    AppLogging.meshcore(
      'event=auto_add_config.set.${ok ? "succeeded" : "failed"}',
      error: !ok,
    );
    return ok;
  }

  /// D29 Part C: reset the firmware-side learned route for a contact
  /// (`CMD_RESET_PATH` 0x0D). After reset the radio's `out_path_len`
  /// for the contact is set to flood/unknown and re-discovered on the
  /// next outbound message.
  ///
  /// Wire payload: `[0x0D][pubkey 32B]` (33 bytes total). Firmware
  /// does not push a contact-updated frame — caller should refresh the
  /// contact list to see the new path state.
  Future<bool> resetPath(
    Uint8List pubKey, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (pubKey.length != meshCorePubKeySize) {
      throw ArgumentError.value(
        pubKey.length,
        'pubKey.length',
        'must be exactly $meshCorePubKeySize bytes',
      );
    }
    AppLogging.meshcore('event=contact.reset_path.attempted');
    final response = await sendAndWait(
      MeshCoreCommands.resetPath,
      payload: Uint8List.fromList(pubKey),
      expectedResponse: MeshCoreResponses.ok,
      timeout: timeout,
    );
    final ok = response != null;
    AppLogging.meshcore(
      'event=contact.reset_path.${ok ? "succeeded" : "failed"}',
      error: !ok,
    );
    return ok;
  }

  // ---------------------------------------------------------------------------
  // D26: Identity + lifecycle commands
  // ---------------------------------------------------------------------------

  /// Set the device's advertised name (`CMD_SET_ADVERT_NAME` 0x08).
  ///
  /// Wire payload: `[0x08][N UTF-8 name bytes]` (no trailing null).
  /// Firmware caps at [kMeshCoreMaxNodeNameBytes] bytes; we
  /// pre-validate so the user sees the limit explicitly instead
  /// of getting a silently-truncated name on the radio. Empty
  /// names are rejected to avoid the firmware persisting `""`.
  ///
  /// Throws [ArgumentError] on empty or oversized name. Returns
  /// `true` on `RESP_CODE_OK`.
  Future<bool> setAdvertName(
    String name, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    final bytes = utf8.encode(name);
    if (bytes.length > kMeshCoreMaxNodeNameBytes) {
      throw ArgumentError.value(
        name,
        'name',
        'must be at most $kMeshCoreMaxNodeNameBytes UTF-8 bytes '
            '(got ${bytes.length})',
      );
    }

    AppLogging.meshcore(
      'event=identity.set_name.attempted name_len=${bytes.length}',
    );

    final response = await sendAndWait(
      MeshCoreCommands.setAdvertName,
      payload: Uint8List.fromList(bytes),
      expectedResponse: MeshCoreResponses.ok,
      timeout: timeout,
    );
    final ok = response != null;
    AppLogging.meshcore(
      'event=identity.set_name.${ok ? "succeeded" : "failed"}',
      error: !ok,
    );
    return ok;
  }

  /// Set the device's advertised location (`CMD_SET_ADVERT_LAT_LON`
  /// 0x0E).
  ///
  /// Wire payload: `[0x0E][lat int32 LE × 1e6][lon int32 LE × 1e6]`
  /// (9 bytes). The firmware divides by [kMeshCoreAdvertLatLonScale]
  /// to recover degrees and rejects out-of-range with
  /// `ERR_CODE_ILLEGAL_ARG`. Pre-validating in the helper keeps the
  /// rejection path off the wire entirely. Pass `(0, 0)` to clear
  /// the stored location (the firmware accepts the all-zeros
  /// special case).
  ///
  /// Throws [ArgumentError] on out-of-range. Returns `true` on
  /// `RESP_CODE_OK`.
  Future<bool> setAdvertLatLon(
    double lat,
    double lon, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (lat < -90 || lat > 90) {
      throw ArgumentError.value(lat, 'lat', 'must be in [-90, 90]');
    }
    if (lon < -180 || lon > 180) {
      throw ArgumentError.value(lon, 'lon', 'must be in [-180, 180]');
    }

    final latRaw = (lat * kMeshCoreAdvertLatLonScale).round();
    final lonRaw = (lon * kMeshCoreAdvertLatLonScale).round();

    final payload = ByteData(8)
      ..setInt32(0, latRaw, Endian.little)
      ..setInt32(4, lonRaw, Endian.little);

    final cleared = lat == 0 && lon == 0;
    AppLogging.meshcore(
      'event=identity.set_location.attempted '
      'cleared=$cleared location_set=true',
    );

    final response = await sendAndWait(
      MeshCoreCommands.setAdvertLatLon,
      payload: payload.buffer.asUint8List(),
      expectedResponse: MeshCoreResponses.ok,
      timeout: timeout,
    );
    final ok = response != null;
    AppLogging.meshcore(
      'event=identity.set_location.${ok ? "succeeded" : "failed"} '
      'cleared=$cleared',
      error: !ok,
    );
    return ok;
  }

  /// D28 Part C: send `CMD_SEND_TRACE_PATH` (0x24) and await the
  /// matching `PUSH_CODE_TRACE_DATA` (0x89) push.
  ///
  /// Wire format (after the 0x24 opcode byte):
  /// ```
  /// [0..3] tag       u32 LE  — caller-supplied correlation id
  /// [4..7] auth_code u32 LE  — typically 0 for unauthenticated traces
  /// [8]    flag      u8      — control flags (typically 0)
  /// [9..]  path_data variable — target path bytes (e.g. repeater pubkey
  ///                              prefix sequence). Empty path = trace
  ///                              along default route.
  /// ```
  ///
  /// Returns the parsed [MeshCoreTraceResult] when the firmware push
  /// arrives with a matching tag, or null if the [timeout] elapses
  /// without a response. Callers MUST pass a unique [tag] per
  /// in-flight trace so concurrent traces can't cross-correlate.
  ///
  /// Throws [ArgumentError] on path payload longer than 32 bytes
  /// (firmware refuses larger payloads on the trace path).
  Future<MeshCoreTraceResult?> sendTracePath({
    required int tag,
    required Uint8List path,
    int authCode = 0,
    int flag = 0,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (tag < 0 || tag > 0xFFFFFFFF) {
      throw ArgumentError.value(tag, 'tag', 'must fit in uint32');
    }
    if (authCode < 0 || authCode > 0xFFFFFFFF) {
      throw ArgumentError.value(authCode, 'authCode', 'must fit in uint32');
    }
    if (flag < 0 || flag > 0xFF) {
      throw ArgumentError.value(flag, 'flag', 'must fit in uint8');
    }
    if (path.length > 32) {
      throw ArgumentError.value(
        path.length,
        'path.length',
        'trace path payload must be at most 32 bytes',
      );
    }

    final builder = BytesBuilder();
    final header = ByteData(9)
      ..setUint32(0, tag, Endian.little)
      ..setUint32(4, authCode, Endian.little)
      ..setUint8(8, flag);
    builder.add(header.buffer.asUint8List());
    builder.add(path);
    final payload = builder.toBytes();

    AppLogging.meshcore(
      'event=trace.requested tag=$tag path_len=${path.length}',
    );

    // Subscribe BEFORE sending so a fast firmware can't race us.
    final completer = Completer<MeshCoreTraceResult?>();
    StreamSubscription<MeshCoreFrame>? sub;
    sub = frameStream.listen((frame) {
      if (frame.command != MeshCorePushCodes.traceData) return;
      final parsed = parseTraceData(frame.payload);
      if (!parsed.isSuccess) {
        AppLogging.meshcore(
          'event=trace.parse.failed reason=${parsed.error}',
          error: true,
        );
        return;
      }
      final result = parsed.value!;
      if (result.tag != tag) {
        // Different concurrent trace — not ours. Stay subscribed.
        return;
      }
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    });

    try {
      await sendFrame(
        MeshCoreFrame(
          command: MeshCoreCommands.sendTracePath,
          payload: payload,
        ),
      );
      final result = await completer.future.timeout(
        timeout,
        onTimeout: () {
          AppLogging.meshcore('event=trace.timeout tag=$tag', error: true);
          return null;
        },
      );
      if (result != null) {
        AppLogging.meshcore(
          'event=trace.succeeded tag=$tag hops=${result.hops.length}',
        );
      }
      return result;
    } catch (e) {
      AppLogging.meshcore(
        'event=trace.failed tag=$tag reason=${e.runtimeType}',
        error: true,
      );
      return null;
    } finally {
      await sub.cancel();
    }
  }

  /// Push the current epoch seconds to the device
  /// (`CMD_SET_DEVICE_TIME` 0x06). Wire payload: `[0x06][secs uint32
  /// LE]` (5 bytes).
  ///
  /// **Forward-only**: firmware rejects times in the past with
  /// `ERR_CODE_ILLEGAL_ARG`. If the radio's RTC is already ahead of
  /// the phone (e.g. drifted), this will return `false` and the
  /// caller should surface the "device clock is already ahead"
  /// outcome to the user rather than retrying.
  ///
  /// Defaults to `DateTime.now()` in seconds; a [time] override is
  /// accepted for tests.
  Future<bool> setDeviceTime({
    DateTime? time,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final epochSecs =
        (time ?? DateTime.now()).toUtc().millisecondsSinceEpoch ~/ 1000;
    if (epochSecs < 0 || epochSecs > 0xFFFFFFFF) {
      throw ArgumentError.value(
        epochSecs,
        'epochSecs',
        'does not fit in uint32',
      );
    }
    final payload = ByteData(4)..setUint32(0, epochSecs, Endian.little);

    AppLogging.meshcore(
      'event=identity.set_time.attempted epoch_seconds=$epochSecs',
    );
    final response = await sendAndWait(
      MeshCoreCommands.setDeviceTime,
      payload: payload.buffer.asUint8List(),
      expectedResponse: MeshCoreResponses.ok,
      timeout: timeout,
    );
    final ok = response != null;
    AppLogging.meshcore(
      'event=identity.set_time.${ok ? "succeeded" : "failed"} '
      'epoch_seconds=$epochSecs',
      error: !ok,
    );
    return ok;
  }

  /// Reboot the radio (`CMD_REBOOT` 0x13). Wire payload requires the
  /// literal magic word `"reboot"` after the opcode — without it
  /// the firmware silently ignores the frame.
  ///
  /// Fire-and-forget: the radio does NOT send `RESP_CODE_OK`; it
  /// just power-cycles. The transport will drop and the existing
  /// reconnect logic picks the device back up on the next handshake.
  /// Callers should expect `isConnected` to flip false shortly
  /// after the await returns.
  Future<void> rebootDevice() async {
    AppLogging.meshcore('event=identity.reboot.requested');
    // Magic-word literal — without it the firmware drops the frame
    // (`memcmp(&cmd_frame[1], "reboot", 6)` check in companion
    // firmware). Hardcoded; do not extract to a constant since the
    // string itself IS the protocol.
    final payload = Uint8List.fromList(<int>[
      0x72, 0x65, 0x62, 0x6f, 0x6f, 0x74, // "reboot"
    ]);
    await sendCommandWithPayload(MeshCoreCommands.reboot, payload);
    AppLogging.meshcore('event=identity.reboot.sent');
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Reset codec state (clear any partial data).
  void resetCodec() {
    _codec.reset();
  }

  /// Update session state based on transport connection.
  void updateState() {
    _state = _transport.isConnected
        ? MeshCoreSessionState.active
        : MeshCoreSessionState.disconnected;
  }

  /// Clear all pending response waiters. Bumps `_sessionGeneration`
  /// so any waiter that survives this drain (via a missed cleanup path)
  /// can later be recognized as stale and evicted by `_registerWaiter`
  /// instead of triggering the live-collision throw.
  void clearPendingResponses() {
    _sessionGeneration++;
    for (final waiter in _pendingResponses.values) {
      if (!waiter.completer.isCompleted) {
        waiter.completer.completeError(const MeshCoreSessionDisposedError());
      }
    }
    _pendingResponses.clear();

    for (final waiter in _validatedWaiters.values) {
      if (!waiter.completer.isCompleted) {
        waiter.completer.completeError(const MeshCoreSessionDisposedError());
      }
    }
    _validatedWaiters.clear();
  }

  /// Dispose the session and release resources.
  Future<void> dispose() async {
    clearPendingResponses();
    await _rawSubscription?.cancel();
    _rawSubscription = null;
    _state = MeshCoreSessionState.disconnected;
    await _frameController.close();
    await _errorController.close();
    await _statusController.close();
  }
}

/// D33: outcome of [MeshCoreSession.sendTextMessage].
///
/// Discriminates the three terminal states a text-send can reach:
/// successful firmware ack, host-side rate-limit rejection, or
/// firmware response timeout.
class MeshCoreTextSendResult {
  /// Kind of outcome. Branch on this rather than nested null checks.
  final MeshCoreTextSendOutcome outcome;

  /// Firmware response frame on success; null in the other two states.
  final MeshCoreFrame? response;

  /// On `rateLimited`: how long the caller should wait before
  /// retrying. UI uses this to drive a countdown.
  final Duration? nextSendIn;

  /// On `rateLimited`: bytes still available in the budget window
  /// (which the rejected request did NOT consume).
  final int? remainingBytes;

  const MeshCoreTextSendResult._({
    required this.outcome,
    this.response,
    this.nextSendIn,
    this.remainingBytes,
  });

  factory MeshCoreTextSendResult.ok({required MeshCoreFrame response}) =>
      MeshCoreTextSendResult._(
        outcome: MeshCoreTextSendOutcome.ok,
        response: response,
      );

  factory MeshCoreTextSendResult.rateLimited({
    required Duration nextSendIn,
    required int remainingBytes,
  }) => MeshCoreTextSendResult._(
    outcome: MeshCoreTextSendOutcome.rateLimited,
    nextSendIn: nextSendIn,
    remainingBytes: remainingBytes,
  );

  factory MeshCoreTextSendResult.firmwareTimeout() =>
      const MeshCoreTextSendResult._(
        outcome: MeshCoreTextSendOutcome.firmwareTimeout,
      );

  bool get ok => outcome == MeshCoreTextSendOutcome.ok;
  bool get rateLimited => outcome == MeshCoreTextSendOutcome.rateLimited;
  bool get firmwareTimeout =>
      outcome == MeshCoreTextSendOutcome.firmwareTimeout;
}

enum MeshCoreTextSendOutcome { ok, rateLimited, firmwareTimeout }
