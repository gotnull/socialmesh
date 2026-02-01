// SPDX-License-Identifier: GPL-3.0-or-later

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
import 'dart:typed_data';

import '../../../core/meshcore_constants.dart';
import 'meshcore_capture.dart';
import 'meshcore_codec.dart';
import 'meshcore_frame.dart';
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
  final MeshCoreTransport _transport;
  final MeshCoreCodec _codec;

  final StreamController<MeshCoreFrame> _frameController;
  final StreamController<String> _errorController;
  StreamSubscription<Uint8List>? _rawSubscription;

  MeshCoreSessionState _state = MeshCoreSessionState.disconnected;

  /// Pending response completers by expected response code.
  ///
  /// Single-flight policy: only one waiter per response code.
  /// This prevents mis-association when multiple requests are in flight.
  final Map<int, Completer<MeshCoreFrame>> _pendingResponses = {};

  /// Optional capture for debugging (enabled via setCapture).
  MeshCoreFrameCapture? _capture;

  /// Creates a new MeshCore session over the given transport.
  ///
  /// The session immediately starts listening to the transport's rawRxStream
  /// and decoding frames.
  MeshCoreSession(this._transport)
    : _frameController = StreamController<MeshCoreFrame>.broadcast(),
      _errorController = StreamController<String>.broadcast(),
      _codec = MeshCoreCodec() {
    _initialize();
  }

  /// Creates a session with custom codec (for testing).
  MeshCoreSession.withCodec(this._transport, this._codec)
    : _frameController = StreamController<MeshCoreFrame>.broadcast(),
      _errorController = StreamController<String>.broadcast() {
    _initialize();
  }

  /// Creates a session with optional capture (for debugging).
  MeshCoreSession.withCapture(this._transport, this._capture)
    : _frameController = StreamController<MeshCoreFrame>.broadcast(),
      _errorController = StreamController<String>.broadcast(),
      _codec = MeshCoreCodec() {
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

  void _onFrameDecoded(MeshCoreFrame frame) {
    // Record RX if capture is enabled
    _capture?.recordRx(frame);

    // IMPORTANT: Only response codes (< 0x80) can satisfy waiters.
    // Push codes (>= 0x80) are async events and must not match waiters.
    if (MeshCoreCodeClassification.isResponseCode(frame.command)) {
      final completer = _pendingResponses.remove(frame.command);
      if (completer != null && !completer.isCompleted) {
        completer.complete(frame);
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

    // Enforce single-flight: only one waiter per response code
    if (_pendingResponses.containsKey(responseCode)) {
      throw StateError(
        'Single-flight violation: waiter already registered for '
        '0x${responseCode.toRadixString(16)}. '
        'Complete or cancel the existing request first.',
      );
    }

    final completer = Completer<MeshCoreFrame>();
    _pendingResponses[responseCode] = completer;
    return completer;
  }

  /// Check if a waiter is pending for the given response code.
  bool hasWaiter(int responseCode) =>
      _pendingResponses.containsKey(responseCode);

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

  // ---------------------------------------------------------------------------
  // High-level Protocol Primitives
  // ---------------------------------------------------------------------------

  /// Get device self info using the MeshCore startup sequence.
  ///
  /// Sends cmdDeviceQuery + cmdAppStart, waits for respSelfInfo.
  /// Returns parsed SelfInfo, null on timeout, or throws [MeshCoreParseException]
  /// on parse failure.
  Future<MeshCoreSelfInfo?> getSelfInfo({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    // Register waiter BEFORE sending commands
    final completer = _registerWaiter(MeshCoreResponses.selfInfo);

    // Send startup sequence
    await sendCommand(MeshCoreCommands.deviceQuery);
    await sendCommand(MeshCoreCommands.appStart);

    // Wait for response
    MeshCoreFrame? response;
    try {
      response = await completer.future.timeout(
        timeout,
        onTimeout: () {
          _pendingResponses.remove(MeshCoreResponses.selfInfo);
          throw TimeoutException('Self info timeout');
        },
      );
    } on TimeoutException {
      return null;
    }

    // Parse response
    final result = parseSelfInfo(response.payload);
    if (!result.isSuccess) {
      throw MeshCoreParseException(
        code: response.command,
        payload: response.payload,
        message: result.error ?? 'Failed to parse self info',
      );
    }
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

  /// Clear all pending response waiters.
  void clearPendingResponses() {
    for (final completer in _pendingResponses.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Session disposed'));
      }
    }
    _pendingResponses.clear();
  }

  /// Dispose the session and release resources.
  Future<void> dispose() async {
    clearPendingResponses();
    await _rawSubscription?.cancel();
    _rawSubscription = null;
    _state = MeshCoreSessionState.disconnected;
    await _frameController.close();
    await _errorController.close();
  }
}
