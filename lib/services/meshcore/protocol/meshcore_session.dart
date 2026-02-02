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

import 'package:flutter/foundation.dart' show kDebugMode;

import '../../../core/logging.dart';
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

/// Helper class for waiters with validation predicates.
class _ValidatedWaiter {
  final Completer<MeshCoreFrame> completer;
  final bool Function(MeshCoreFrame) predicate;

  _ValidatedWaiter(this.completer, this.predicate);
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

  /// Pending response completers with validation predicates.
  ///
  /// These waiters only complete when both code matches AND predicate returns true.
  final Map<int, _ValidatedWaiter> _validatedWaiters = {};

  /// Stream controller for status/ACK frames (code 0x01).
  final StreamController<MeshCoreStatusFrame> _statusController =
      StreamController<MeshCoreStatusFrame>.broadcast();

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

  /// Convert bytes to hex string for logging.
  static String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
  }

  void _onFrameDecoded(MeshCoreFrame frame) {
    // Debug logging: detailed RX info
    if (kDebugMode) {
      final payloadHex = frame.payload.isEmpty
          ? '(empty)'
          : _bytesToHex(frame.payload);
      AppLogging.protocol(
        'MeshCore RX decoded: code=0x${frame.command.toRadixString(16).padLeft(2, '0')} '
        'len=${frame.payload.length} payload=[$payloadHex]',
      );
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
        final completer = _pendingResponses.remove(frame.command);
        if (completer != null && !completer.isCompleted) {
          completer.complete(frame);
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

    // Debug logging: detailed TX info
    if (kDebugMode) {
      final payloadHex = frame.payload.isEmpty
          ? '(empty)'
          : _bytesToHex(frame.payload);
      AppLogging.protocol(
        'MeshCore TX: code=0x${frame.command.toRadixString(16).padLeft(2, '0')} '
        'len=${frame.payload.length} payload=[$payloadHex] raw=[${_bytesToHex(bytes)}]',
      );
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

    // Enforce single-flight: only one waiter per response code
    if (_pendingResponses.containsKey(responseCode) ||
        _validatedWaiters.containsKey(responseCode)) {
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

    // Enforce single-flight
    if (_pendingResponses.containsKey(responseCode) ||
        _validatedWaiters.containsKey(responseCode)) {
      throw StateError(
        'Single-flight violation: waiter already registered for '
        '0x${responseCode.toRadixString(16)}. '
        'Complete or cancel the existing request first.',
      );
    }

    final completer = Completer<MeshCoreFrame>();
    _validatedWaiters[responseCode] = _ValidatedWaiter(completer, predicate);
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

  // ---------------------------------------------------------------------------
  // High-level Protocol Primitives
  // ---------------------------------------------------------------------------

  /// Minimum payload size for a valid SELF_INFO response.
  static const int _minSelfInfoPayloadSize = 35;

  /// App name sent in APP_START frame.
  static const String _appName = 'Socialmesh';

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
      return contacts;
    } on TimeoutException {
      AppLogging.protocol('MeshCore: getContacts() timeout');
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
    return channels;
  }

  /// Set a channel on the device.
  ///
  /// [index] is the channel slot (0-7).
  /// [name] is the channel name (max 32 chars).
  /// [psk] is the pre-shared key (16 bytes).
  Future<bool> setChannel({
    required int index,
    required String name,
    required Uint8List psk,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (psk.length != 16) {
      throw ArgumentError('PSK must be 16 bytes');
    }

    // Build SET_CHANNEL payload: [index][name...][0x00 padding to 33][psk x16]
    final builder = BytesBuilder();
    builder.addByte(index);

    // Name (max 32 bytes, null-terminated)
    final nameBytes = name.codeUnits.take(32).toList();
    builder.add(nameBytes);
    // Pad with zeros to 33 bytes total (32 name + 1 null)
    for (int i = nameBytes.length; i < 33; i++) {
      builder.addByte(0);
    }

    // PSK (16 bytes)
    builder.add(psk);

    final response = await sendAndWait(
      MeshCoreCommands.setChannel,
      payload: builder.toBytes(),
      expectedResponse: MeshCoreResponses.ok,
      timeout: timeout,
    );

    return response != null;
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

    for (final waiter in _validatedWaiters.values) {
      if (!waiter.completer.isCompleted) {
        waiter.completer.completeError(StateError('Session disposed'));
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
