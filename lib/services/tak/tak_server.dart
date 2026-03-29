// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';
import 'dart:io';

import '../../core/logging.dart';
import 'certificate_manager.dart';
import 'tak_client_session.dart';

/// Events emitted by [TakServer].
sealed class TakServerEvent {
  const TakServerEvent();
}

/// A client connected to the server.
class TakClientConnected extends TakServerEvent {
  final TakClientSession session;
  const TakClientConnected(this.session);
}

/// A client disconnected from the server.
class TakClientDisconnected extends TakServerEvent {
  final TakClientSession session;
  const TakClientDisconnected(this.session);
}

/// A CoT event was received from a TAK client.
class TakCotReceived extends TakServerEvent {
  final TakClientSession session;
  final String cotXml;
  const TakCotReceived(this.session, this.cotXml);
}

/// A server error occurred.
class TakServerError extends TakServerEvent {
  final String message;
  const TakServerError(this.message);
}

/// On-device TAK TCP/TLS server that accepts ATAK/iTAK client connections.
///
/// Uses mTLS with certificates from [TakCertificateManager].
/// Manages connected client sessions and broadcasts CoT events.
class TakServer {
  /// Default server port (ATAK standard).
  static const int defaultPort = 8089;

  /// Maximum concurrent client connections.
  static const int maxClients = 5;

  /// Inactivity timeout before closing a session.
  static const Duration inactivityTimeout = Duration(seconds: 120);

  final TakCertificateManager _certManager;
  final _eventController = StreamController<TakServerEvent>.broadcast();
  final List<TakClientSession> _clients = [];
  SecureServerSocket? _serverSocket;
  Timer? _inactivityTimer;
  bool _running = false;

  TakServer(this._certManager);

  /// Stream of server events.
  Stream<TakServerEvent> get events => _eventController.stream;

  /// Whether the server is running.
  bool get isRunning => _running;

  /// Current number of connected clients.
  int get clientCount => _clients.length;

  /// Connected client sessions (read-only view).
  List<TakClientSession> get clients => List.unmodifiable(_clients);

  /// Starts the TLS server on [port].
  Future<void> start({int port = defaultPort}) async {
    if (_running) return;

    try {
      final context = await _createSecurityContext();
      _serverSocket = await SecureServerSocket.bind(
        InternetAddress.anyIPv4,
        port,
        context,
      );
      _running = true;

      AppLogging.tak('Server listening on 0.0.0.0:$port');

      _serverSocket!.listen(
        _onClientConnected,
        onError: (Object error) {
          AppLogging.tak('Server error: $error');
          _eventController.add(TakServerError(error.toString()));
        },
      );

      _inactivityTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _checkInactivity(),
      );
    } on SocketException catch (e) {
      AppLogging.tak('Server failed to bind port $port: $e');
      _eventController.add(TakServerError(e.toString()));
    }
  }

  /// Stops the server and disconnects all clients.
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _inactivityTimer?.cancel();

    for (final client in List.of(_clients)) {
      client.close();
    }
    _clients.clear();

    await _serverSocket?.close();
    _serverSocket = null;

    AppLogging.tak('Server stopped');
  }

  /// Broadcasts a CoT XML event to all connected and authenticated clients.
  void broadcastCot(String cotXml) {
    for (final client in _clients) {
      if (client.state == TakSessionState.authenticated) {
        client.sendCot(cotXml);
      }
    }
  }

  /// Sends a CoT event to a specific client by callsign.
  void sendToClient(String callsign, String cotXml) {
    for (final client in _clients) {
      if (client.callsign == callsign &&
          client.state == TakSessionState.authenticated) {
        client.sendCot(cotXml);
        return;
      }
    }
  }

  /// Disposes the server and releases resources.
  Future<void> dispose() async {
    await stop();
    await _eventController.close();
  }

  void _onClientConnected(SecureSocket socket) {
    if (_clients.length >= maxClients) {
      AppLogging.tak('Client rejected: max $maxClients connections reached');
      socket.destroy();
      return;
    }

    final session = TakClientSession(socket);
    _clients.add(session);
    _eventController.add(TakClientConnected(session));

    // Listen for CoT events from this client.
    session.cotEvents.listen((cotXml) {
      _eventController.add(TakCotReceived(session, cotXml));
    });

    // Listen for session lifecycle events.
    session.events.listen((event) {
      if (event == TakSessionEvent.disconnected) {
        _clients.remove(session);
        _eventController.add(TakClientDisconnected(session));
      }
    });

    session.start();
  }

  void _checkInactivity() {
    final now = DateTime.now();
    for (final client in List.of(_clients)) {
      if (now.difference(client.lastActivityAt) > inactivityTimeout) {
        AppLogging.tak(
          'Client ${client.callsign.isNotEmpty ? client.callsign : client.remoteAddress} timed out (inactive ${inactivityTimeout.inSeconds}s)',
        );
        client.close();
      }
    }
  }

  Future<SecurityContext> _createSecurityContext() async {
    final caPem = await _certManager.getCaCertificatePem();
    final serverResult = await _certManager.getServerCertificateAndKey();

    final context = SecurityContext()
      ..useCertificateChainBytes(serverResult.certPem.codeUnits)
      ..usePrivateKeyBytes(serverResult.keyPem.codeUnits)
      ..setTrustedCertificatesBytes(caPem.codeUnits)
      ..setClientAuthoritiesBytes(caPem.codeUnits);

    return context;
  }
}
