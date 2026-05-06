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
  // Radio parameters
  // ---------------------------------------------------------------------------

  /// Set the LoRa radio parameters on the connected MeshCore device.
  ///
  /// Wire format (mirrors upstream `MyMesh.cpp:CMD_SET_RADIO_PARAMS`):
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
