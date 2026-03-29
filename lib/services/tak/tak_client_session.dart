// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../core/logging.dart';
import 'tak_protocol_handler.dart';

/// Connection state of a TAK client session.
enum TakSessionState {
  /// Connected, awaiting protocol negotiation.
  pendingNegotiation,

  /// Negotiation complete, operational.
  authenticated,

  /// Session closed.
  closed,
}

/// Represents a single ATAK/iTAK client connected to [TakServer].
class TakClientSession {
  final SecureSocket socket;
  final TakProtocolHandler protocolHandler = TakProtocolHandler();
  final DateTime connectedAt = DateTime.now();
  DateTime lastActivityAt;
  String callsign;
  String uid;
  TakSessionState state;
  int missedKeepalives;
  StreamSubscription<Uint8List>? _subscription;
  Timer? _keepaliveTimer;
  Timer? _keepaliveTimeoutTimer;

  /// Controller for CoT events received from this client.
  final _cotController = StreamController<String>.broadcast();

  /// Controller for session lifecycle events.
  final _eventController = StreamController<TakSessionEvent>.broadcast();

  TakClientSession(this.socket)
    : lastActivityAt = DateTime.now(),
      callsign = '',
      uid = '',
      state = TakSessionState.pendingNegotiation,
      missedKeepalives = 0;

  /// Stream of CoT XML events received from this client.
  Stream<String> get cotEvents => _cotController.stream;

  /// Stream of session lifecycle events.
  Stream<TakSessionEvent> get events => _eventController.stream;

  /// Remote address string.
  String get remoteAddress =>
      '${socket.remoteAddress.address}:${socket.remotePort}';

  /// Connection duration.
  Duration get connectionDuration => DateTime.now().difference(connectedAt);

  /// Starts listening on the socket and initiates negotiation.
  void start() {
    _subscription = socket.listen(
      _onData,
      onError: (Object error) {
        AppLogging.tak('Client $remoteAddress error: $error');
        close();
      },
      onDone: close,
    );

    // Send server negotiation.
    _sendRaw(TakProtocolHandler.buildNegotiation());
    AppLogging.tak('Client connected: $remoteAddress (pending negotiation)');
  }

  /// Sends a CoT XML event to this client.
  void sendCot(String cotXml) {
    if (state == TakSessionState.closed) return;
    final frame = TakProtocolHandler.buildXmlCotFrame(cotXml);
    _sendRaw(frame);
  }

  /// Closes the session and releases resources.
  void close() {
    if (state == TakSessionState.closed) return;
    state = TakSessionState.closed;
    _keepaliveTimer?.cancel();
    _keepaliveTimeoutTimer?.cancel();
    _subscription?.cancel();
    socket.destroy();
    _eventController.add(TakSessionEvent.disconnected);
    _cotController.close();
    _eventController.close();
    AppLogging.tak(
      'Client disconnected: ${callsign.isNotEmpty ? callsign : remoteAddress}',
    );
  }

  void _onData(Uint8List data) {
    lastActivityAt = DateTime.now();
    final frames = protocolHandler.feedBytes(data);

    for (final frame in frames) {
      switch (frame.type) {
        case TakFrameType.negotiation:
          _handleNegotiation(frame);
        case TakFrameType.xmlCot:
          _handleXmlCot(frame);
        case TakFrameType.protobufCot:
          _handleProtobufCot(frame);
        case TakFrameType.keepalive:
          _handleKeepalive();
      }
    }
  }

  void _handleNegotiation(TakFrame frame) {
    state = TakSessionState.authenticated;
    // Extract version from negotiation payload.
    final version = frame.payload.isNotEmpty ? frame.payload[0] : 0;
    AppLogging.tak(
      'Protocol negotiation: client=TAKv$version, server=TAKv1, agreed=TAKv1',
    );
    _eventController.add(TakSessionEvent.authenticated);
    _startKeepalive();
  }

  void _handleXmlCot(TakFrame frame) {
    final xml = String.fromCharCodes(frame.payload);
    _cotController.add(xml);
  }

  void _handleProtobufCot(TakFrame frame) {
    // For protobuf CoT, we'll handle it at the bridge level.
    // Emit as base64 or pass raw bytes through a separate channel.
    AppLogging.tak(
      'Received protobuf CoT from ${callsign.isNotEmpty ? callsign : remoteAddress} (${frame.payload.length} bytes)',
    );
  }

  void _handleKeepalive() {
    missedKeepalives = 0;
    _keepaliveTimeoutTimer?.cancel();
  }

  void _startKeepalive() {
    _keepaliveTimer = Timer.periodic(
      TakProtocolHandler.keepaliveInterval,
      (_) => _sendKeepalivePing(),
    );
  }

  void _sendKeepalivePing() {
    if (state == TakSessionState.closed) return;

    _sendRaw(TakProtocolHandler.buildKeepalivePing());

    _keepaliveTimeoutTimer?.cancel();
    _keepaliveTimeoutTimer = Timer(TakProtocolHandler.keepaliveTimeout, () {
      missedKeepalives++;
      if (missedKeepalives >= TakProtocolHandler.maxMissedKeepalives) {
        AppLogging.tak(
          'Client ${callsign.isNotEmpty ? callsign : remoteAddress} missed $missedKeepalives keepalives, closing session',
        );
        close();
      }
    });
  }

  void _sendRaw(Uint8List data) {
    if (state == TakSessionState.closed) return;
    try {
      socket.add(data);
    } on SocketException {
      close();
    }
  }
}

/// Events emitted by a [TakClientSession].
enum TakSessionEvent { authenticated, disconnected }
