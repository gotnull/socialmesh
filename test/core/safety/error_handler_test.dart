// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/safety/error_handler.dart';

/// Tests for [AppErrorHandler] sanitization and error categorization.
///
/// These tests verify that:
/// 1. Sanitization removes actual secrets (API keys, JWTs, emails, etc.)
/// 2. Sanitization does NOT destroy error-diagnostic information
///    (class names, method names, error messages, stack traces)
/// 3. Error categorization correctly classifies platform errors
void main() {
  // Access _sanitizeString and _categorizePlatformError via the public
  // reportError / runProtectedSync APIs, or test indirectly by verifying
  // the sanitization regex patterns directly.
  //
  // Since _sanitizeString and _categorizePlatformError are private, we
  // test them through their observable effects on the public API, or we
  // replicate the regex patterns here for unit testing.

  group('Sanitization - preserves diagnostic info', () {
    // Replicate the sanitization logic for direct testing since the
    // method is private. This ensures the regexes work as intended.
    String sanitize(String input) {
      var result = input;

      // Email addresses
      result = result.replaceAll(
        RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
        '[REDACTED_EMAIL]',
      );

      // Phone numbers
      result = result.replaceAll(
        RegExp(r'\+?[0-9]{10,15}'),
        '[REDACTED_PHONE]',
      );

      // URLs with query parameters
      result = result.replaceAll(
        RegExp(r'https?://[^\s]+\?[^\s]+'),
        '[REDACTED_URL]',
      );

      // JWT tokens
      result = result.replaceAll(
        RegExp(r'eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
        '[REDACTED_JWT]',
      );

      // Key/token/secret assignments
      result = result.replaceAll(
        RegExp(
          r'(?:key|token|apiKey|api_key|secret|password|auth)[\s]*[=:]\s*[A-Za-z0-9_\-/.+]{20,}',
          caseSensitive: false,
        ),
        '[REDACTED_CREDENTIAL]',
      );

      // Long hex strings (64+ chars, cryptographic material)
      result = result.replaceAll(
        RegExp(r'\b[0-9a-fA-F]{64,}\b'),
        '[REDACTED_HEX]',
      );

      // Base64 with padding
      result = result.replaceAll(
        RegExp(
          r'(?:[A-Za-z0-9+/]{4}){10,}(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)',
        ),
        '[REDACTED_BASE64]',
      );

      return result;
    }

    test('preserves Flutter class names', () {
      const input = 'FlutterBluePlusException: characteristic not found';
      expect(sanitize(input), equals(input));
    });

    test('preserves Dart error type names', () {
      const input = 'StateError: Cannot add event after closing';
      expect(sanitize(input), equals(input));
    });

    test('preserves long method names in stack traces', () {
      const input =
          '#0 BleTransport._subscribeToLogRadioCharacteristic (ble_transport.dart:894)';
      expect(sanitize(input), equals(input));
    });

    test('preserves protocol service class references', () {
      const input =
          'ProtocolService._handleFileTransferOnPrivateApp threw: RangeError (index)';
      expect(sanitize(input), equals(input));
    });

    test('preserves Meshtastic service UUID format', () {
      // BLE UUIDs are 36 chars with hyphens: 8-4-4-4-12
      const input = 'Service not found: 6ba1b218-15a8-461f-9fa8-5dcae273eafd';
      // Should NOT be redacted — UUIDs are not PII
      expect(sanitize(input), contains('6ba1b218'));
    });

    test('preserves short error identifiers', () {
      const input = 'fbp-code: 2, fbp-android-code: 0';
      expect(sanitize(input), equals(input));
    });

    test('preserves protobuf error messages', () {
      const input =
          'InvalidProtocolBufferException: Protocol message contained an invalid tag (zero)';
      expect(sanitize(input), equals(input));
    });

    test('preserves stack trace frame paths', () {
      const input =
          'package:socialmesh/services/protocol/protocol_service.dart 1394:5';
      expect(sanitize(input), equals(input));
    });

    test('preserves widget lifecycle error messages', () {
      const input =
          'A _ChatScreenState was used after being disposed.\n'
          'Once you have called dispose() on a State, it can no longer be used.';
      expect(sanitize(input), equals(input));
    });

    test('preserves stream controller errors', () {
      const input =
          "Bad state: Cannot add event after closing (StreamController)";
      expect(sanitize(input), equals(input));
    });

    test('preserves MeshPacketDedupeStore errors', () {
      const input =
          'MeshPacketDedupeStore: First open attempt failed: '
          'DatabaseException(SqliteException(26): file is not a database)';
      expect(sanitize(input), equals(input));
    });
  });

  group('Sanitization - removes actual secrets', () {
    String sanitize(String input) {
      var result = input;
      result = result.replaceAll(
        RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
        '[REDACTED_EMAIL]',
      );
      result = result.replaceAll(
        RegExp(r'\+?[0-9]{10,15}'),
        '[REDACTED_PHONE]',
      );
      result = result.replaceAll(
        RegExp(r'https?://[^\s]+\?[^\s]+'),
        '[REDACTED_URL]',
      );
      result = result.replaceAll(
        RegExp(r'eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
        '[REDACTED_JWT]',
      );
      result = result.replaceAll(
        RegExp(
          r'(?:key|token|apiKey|api_key|secret|password|auth)[\s]*[=:]\s*[A-Za-z0-9_\-/.+]{20,}',
          caseSensitive: false,
        ),
        '[REDACTED_CREDENTIAL]',
      );
      result = result.replaceAll(
        RegExp(r'\b[0-9a-fA-F]{64,}\b'),
        '[REDACTED_HEX]',
      );
      result = result.replaceAll(
        RegExp(
          r'(?:[A-Za-z0-9+/]{4}){10,}(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)',
        ),
        '[REDACTED_BASE64]',
      );
      return result;
    }

    test('removes email addresses', () {
      const input = 'User email: john.doe@example.com failed';
      final result = sanitize(input);
      expect(result, contains('[REDACTED_EMAIL]'));
      expect(result, isNot(contains('john.doe@example.com')));
    });

    test('removes phone numbers', () {
      const input = 'Phone: +61412345678 is invalid';
      final result = sanitize(input);
      expect(result, contains('[REDACTED_PHONE]'));
      expect(result, isNot(contains('61412345678')));
    });

    test('removes URLs with query parameters', () {
      const input =
          'Failed to fetch https://api.example.com/data?token=abc123&user=foo';
      final result = sanitize(input);
      expect(result, contains('[REDACTED_URL]'));
      expect(result, isNot(contains('token=abc123')));
    });

    test('removes JWT tokens', () {
      const input =
          'Auth failed: eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.'
          'eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIn0.'
          'SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
      final result = sanitize(input);
      expect(result, contains('[REDACTED_JWT]'));
      expect(result, isNot(contains('eyJhbGci')));
    });

    test('removes API key assignments', () {
      const input = 'apiKey=AIzaSyBxRdKqwertyuiopasdfghjklzx failed';
      final result = sanitize(input);
      expect(result, contains('[REDACTED_CREDENTIAL]'));
      expect(result, isNot(contains('AIzaSyB')));
    });

    test('removes token assignments', () {
      const input = 'token: ya29.a0AfH6SMBgTxyzabcdefghijklm';
      final result = sanitize(input);
      expect(result, contains('[REDACTED_CREDENTIAL]'));
    });

    test('removes long hex strings (SHA-256 hashes)', () {
      const hash =
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
      final input = 'Hash: $hash';
      final result = sanitize(input);
      expect(result, contains('[REDACTED_HEX]'));
      expect(result, isNot(contains(hash)));
    });

    test('removes base64 encoded data with padding', () {
      const input =
          'Data: SGVsbG8gV29ybGQhIFRoaXMgaXMgYSBsb25nIGJhc2U2NCBzdHJpbmcgdGhhdCBzaG91bGQgYmUgcmVkYWN0ZWQ=';
      final result = sanitize(input);
      expect(result, contains('[REDACTED_BASE64]'));
    });

    test('does NOT redact short base64 without padding', () {
      // Short strings without padding should not be redacted
      const input = 'Error code: ABC123DEF456';
      expect(sanitize(input), equals(input));
    });
  });

  group('Error categorization', () {
    // Replicate _categorizePlatformError logic for testing
    String categorize(Object error, StackTrace stack) {
      final errorStr = error.toString().toLowerCase();
      final stackStr = stack.toString().toLowerCase();
      final combined = '$errorStr\n$stackStr';

      if (combined.contains('flutterbluplus') ||
          combined.contains('ble_transport') ||
          combined.contains('bluetooth') ||
          combined.contains('characteristic') ||
          combined.contains('gatt')) {
        return 'ble';
      }
      if (combined.contains('firebase') ||
          combined.contains('firestore') ||
          combined.contains('leveldb') ||
          combined.contains('cloud_firestore')) {
        return 'firebase';
      }
      if (combined.contains('protobuf') ||
          combined.contains('invalidprotocolbuffer') ||
          combined.contains('protocol_service') ||
          combined.contains('frombuffer') ||
          combined.contains('codec')) {
        return 'protobuf';
      }
      if (combined.contains('stream has already been listened') ||
          combined.contains('cannot add event after closing') ||
          combined.contains('cannot add new events after calling close') ||
          combined.contains('future already completed') ||
          combined.contains('subscription has been canceled') ||
          combined.contains('cannot fire new event')) {
        return 'stream_lifecycle';
      }
      if (combined.contains('file_transfer') ||
          combined.contains('stl_middleware') ||
          combined.contains('stlenvelope') ||
          combined.contains('smcodec')) {
        return 'file_transfer';
      }
      if (combined.contains('sip') || combined.contains('mrrp')) {
        return 'sip_mrrp';
      }
      if (combined.contains('socketexception') ||
          combined.contains('handshakeexception') ||
          combined.contains('connection refused') ||
          combined.contains('network')) {
        return 'network';
      }
      if (error is TimeoutException || combined.contains('timeout')) {
        return 'timeout';
      }
      if (error is StateError) {
        return 'state_error';
      }
      if (error is TypeError) {
        return 'type_error';
      }
      if (error is RangeError) {
        return 'range_error';
      }
      return 'unknown';
    }

    test('categorizes BLE errors by error message', () {
      expect(
        categorize(
          Exception('FlutterBluePlus: characteristic read failed'),
          StackTrace.current,
        ),
        equals('ble'),
      );
    });

    test('categorizes BLE errors by stack trace', () {
      final stack = StackTrace.fromString(
        '#0 BleTransport.send (ble_transport.dart:1048)\n'
        '#1 ProtocolService._sendHeartbeat (protocol_service.dart:4240)',
      );
      expect(categorize(Exception('write failed'), stack), equals('ble'));
    });

    test('categorizes Firebase/Firestore errors', () {
      expect(
        categorize(
          Exception('Firestore LevelDB corruption detected'),
          StackTrace.current,
        ),
        equals('firebase'),
      );
    });

    test('categorizes protobuf errors', () {
      expect(
        categorize(
          Exception('InvalidProtocolBufferException: invalid tag'),
          StackTrace.current,
        ),
        equals('protobuf'),
      );
    });

    test('categorizes protobuf errors by stack trace', () {
      final stack = StackTrace.fromString(
        '#0 ProtocolService._processPacket (protocol_service.dart:1394)',
      );
      expect(categorize(Exception('parse failed'), stack), equals('protobuf'));
    });

    test('categorizes stream lifecycle errors', () {
      expect(
        categorize(
          StateError('Cannot add event after closing'),
          StackTrace.current,
        ),
        equals('stream_lifecycle'),
      );
    });

    test('categorizes stream already listened errors', () {
      expect(
        categorize(
          StateError('Stream has already been listened to'),
          StackTrace.current,
        ),
        equals('stream_lifecycle'),
      );
    });

    test('categorizes file transfer errors', () {
      final stack = StackTrace.fromString(
        '#0 StlMiddleware.verifyAndUnwrap (stl_middleware.dart:42)',
      );
      expect(
        categorize(Exception('verification failed'), stack),
        equals('file_transfer'),
      );
    });

    test('categorizes SIP/MRRP errors', () {
      expect(
        categorize(Exception('SIP handshake timeout'), StackTrace.current),
        equals('sip_mrrp'),
      );
    });

    test('categorizes network errors', () {
      expect(
        categorize(
          Exception('SocketException: Connection refused'),
          StackTrace.current,
        ),
        equals('network'),
      );
    });

    test('categorizes timeout errors by type', () {
      expect(
        categorize(TimeoutException('Operation timed out'), StackTrace.current),
        equals('timeout'),
      );
    });

    test('categorizes StateError when not stream-related', () {
      expect(
        categorize(StateError('No element'), StackTrace.current),
        equals('state_error'),
      );
    });

    test('categorizes RangeError', () {
      expect(
        categorize(RangeError.index(5, [1, 2, 3]), StackTrace.current),
        equals('range_error'),
      );
    });

    test('returns unknown for unrecognized errors', () {
      expect(
        categorize(
          Exception('Something completely unexpected happened'),
          StackTrace.fromString('#0 main (main.dart:1)'),
        ),
        equals('unknown'),
      );
    });
  });

  group('Sanitization regression - old regex would destroy diagnostics', () {
    // The OLD regex was: [A-Za-z0-9_-]{32,}
    // This test proves the old regex was destructive.
    final oldDestructiveRegex = RegExp(r'[A-Za-z0-9_-]{32,}');

    test('old regex would redact Flutter class names', () {
      const className = '_MeshPacketDedupeStoreProviderElement';
      expect(
        oldDestructiveRegex.hasMatch(className),
        isTrue,
        reason:
            'The old regex WOULD have matched this class name, '
            'proving it was too aggressive',
      );
    });

    test('old regex would redact method signatures in stack traces', () {
      const stackLine = 'ProtocolService__handleFileTransferOnPrivateApp';
      expect(
        oldDestructiveRegex.hasMatch(stackLine),
        isTrue,
        reason:
            'The old regex WOULD have matched this method name, '
            'destroying stack trace information',
      );
    });

    test('old regex would redact BLE error messages', () {
      const errorMsg = 'FlutterBluePlusExceptionCharacteristicNotFound';
      expect(
        oldDestructiveRegex.hasMatch(errorMsg),
        isTrue,
        reason:
            'The old regex WOULD have matched this error type, '
            'making BLE errors undiagnosable',
      );
    });
  });

  group('AppErrorHandler public API', () {
    test('runProtectedSync returns fallback on error', () {
      final result = AppErrorHandler.runProtectedSync<int>(
        () => throw Exception('test error'),
        context: 'test',
        fallback: -1,
      );
      expect(result, equals(-1));
    });

    test('runProtectedSync returns result on success', () {
      final result = AppErrorHandler.runProtectedSync<int>(
        () => 42,
        context: 'test',
      );
      expect(result, equals(42));
    });

    test('addBreadcrumb does not throw', () {
      // Should not throw even if Crashlytics is not initialized
      expect(
        () => AppErrorHandler.addBreadcrumb('test action'),
        returnsNormally,
      );
    });
  });

  group('MQTT keep-alive socket error detection', () {
    // Replicates the private _isMqttKeepAliveSocketError filter used in
    // _handlePlatformError to suppress shamblett/mqtt_client#377 noise.
    // Kept in sync with the implementation in error_handler.dart.
    bool isMqttKeepAliveSocketError(Object error, StackTrace stack) {
      if (error is! SocketException) return false;
      final stackStr = stack.toString();
      return stackStr.contains('mqtt_client_mqtt_connection_keep_alive') ||
          stackStr.contains('mqtt_client_mqtt_server_normal_connection') ||
          stackStr.contains('MqttConnectionKeepAlive.pingRequired') ||
          stackStr.contains('MqttServerNormalConnection.send');
    }

    test('matches SocketException with pingRequired frame', () {
      final stack = StackTrace.fromString(
        '#0      _Socket.add (dart:io)\n'
        '#1      MqttServerNormalConnection.send '
        '(package:mqtt_client/src/connectionhandling/server/'
        'mqtt_client_mqtt_server_normal_connection.dart:133)\n'
        '#2      MqttConnectionHandlerBase.sendMessage '
        '(package:mqtt_client/src/connectionhandling/'
        'mqtt_client_mqtt_connection_handler_base.dart:190)\n'
        '#3      MqttConnectionKeepAlive.pingRequired '
        '(package:mqtt_client/src/connectionhandling/'
        'mqtt_client_mqtt_connection_keep_alive.dart:121)',
      );
      final err = const SocketException('Broken pipe');
      expect(isMqttKeepAliveSocketError(err, stack), isTrue);
    });

    test('does NOT match unrelated SocketException', () {
      final stack = StackTrace.fromString(
        '#0      _HttpClient._getConnection (dart:_http)\n'
        '#1      _HttpClient._openUrl (dart:_http)',
      );
      final err = const SocketException('Connection refused');
      expect(isMqttKeepAliveSocketError(err, stack), isFalse);
    });

    test('does NOT match Firestore SocketException', () {
      final stack = StackTrace.fromString(
        '#0      _Socket.add (dart:io)\n'
        '#1      cloud_firestore_platform_interface (...)',
      );
      final err = const SocketException('Write failed');
      expect(isMqttKeepAliveSocketError(err, stack), isFalse);
    });

    test('does NOT match non-SocketException with mqtt frames', () {
      // A StateError from mqtt_client internals should still be reported —
      // only SocketException from the keep-alive path is suppressed.
      final stack = StackTrace.fromString(
        '#0      MqttConnectionKeepAlive.pingRequired '
        '(package:mqtt_client/...)',
      );
      expect(
        isMqttKeepAliveSocketError(StateError('bad state'), stack),
        isFalse,
      );
    });

    test('matches server normal connection send frame', () {
      final stack = StackTrace.fromString(
        '#0      _Socket.add (dart:io)\n'
        '#1      MqttServerNormalConnection.send '
        '(package:mqtt_client/src/connectionhandling/server/'
        'mqtt_client_mqtt_server_normal_connection.dart:133)',
      );
      final err = const SocketException('Software caused connection abort');
      expect(isMqttKeepAliveSocketError(err, stack), isTrue);
    });
  });

  group('Build reporting gate', () {
    test('reports only on non-debug, non-simulator builds', () {
      expect(
        AppErrorHandler.isReportableBuild(debug: false, simulator: false),
        isTrue,
      );
    });

    test('suppresses debug builds', () {
      expect(
        AppErrorHandler.isReportableBuild(debug: true, simulator: false),
        isFalse,
      );
    });

    test('suppresses simulator builds', () {
      expect(
        AppErrorHandler.isReportableBuild(debug: false, simulator: true),
        isFalse,
      );
    });

    test('suppresses debug + simulator builds', () {
      expect(
        AppErrorHandler.isReportableBuild(debug: true, simulator: true),
        isFalse,
      );
    });
  });

  group('Recoverable transient suppression', () {
    test('suppresses network-image load failures by stack', () {
      final stack = StackTrace.fromString(
        '#0 ImageStreamCompleter.reportError '
        '(package:flutter/src/painting/image_stream.dart:827)\n'
        '#1 MultiFrameImageStreamCompleter.<fn> '
        '(package:flutter/src/painting/image_stream.dart:980)',
      );
      expect(
        AppErrorHandler.isRecoverableTransientError(
          Exception('decode failed'),
          stack,
        ),
        isTrue,
      );
    });

    test('suppresses image-classified errors regardless of stack', () {
      expect(
        AppErrorHandler.isRecoverableTransientError(
          Exception('Failed to load network image: decode error'),
          null,
        ),
        isTrue,
      );
    });

    test('suppresses HandshakeException connection-terminated drops', () {
      expect(
        AppErrorHandler.isRecoverableTransientError(
          const HandshakeException('Connection terminated during handshake'),
          StackTrace.current,
        ),
        isTrue,
      );
    });

    test('suppresses SocketException connection-reset drops', () {
      expect(
        AppErrorHandler.isRecoverableTransientError(
          const SocketException('Connection reset'),
          StackTrace.current,
        ),
        isTrue,
      );
    });

    test('suppresses bare String BLE connection-reset', () {
      expect(
        AppErrorHandler.isRecoverableTransientError(
          'Connection reset',
          StackTrace.current,
        ),
        isTrue,
      );
    });

    test('suppresses bare String foreground-task Service stopped', () {
      expect(
        AppErrorHandler.isRecoverableTransientError(
          'Service stopped',
          StackTrace.current,
        ),
        isTrue,
      );
    });

    test('does NOT suppress genuine SocketException (Connection refused)', () {
      expect(
        AppErrorHandler.isRecoverableTransientError(
          const SocketException('Connection refused'),
          StackTrace.fromString('#0 _HttpClient._openUrl (dart:_http)'),
        ),
        isFalse,
      );
    });

    test('suppresses a network-image fetch that times out', () {
      // The shape reported from production: HTTP frames on top, the image
      // provider underneath, no completer frame, and an error message that
      // never says "image".
      final stack = StackTrace.fromString(
        '#0 _HttpClient.getUrl (dart:_http)\n'
        '#1 NetworkImage._loadAsync '
        '(package:flutter/src/painting/_network_image_io.dart:120)\n'
        '#2 ImageProvider.resolveStreamForKey '
        '(package:flutter/src/painting/image_provider.dart:546)',
      );
      expect(
        AppErrorHandler.isRecoverableTransientError(
          const SocketException(
            'Operation timed out (OS Error: Operation timed out, errno = 60), '
            'address = firebasestorage.googleapis.com, port = 63659',
          ),
          stack,
        ),
        isTrue,
      );
    });

    test('does NOT suppress a malformed image URL on the same path', () {
      // A local file path handed to a network loader is a defect, not the
      // network, and has to keep reporting even though it fails here too.
      final stack = StackTrace.fromString(
        '#0 _HttpClient.getUrl (dart:_http)\n'
        '#1 NetworkImage._loadAsync '
        '(package:flutter/src/painting/_network_image_io.dart:120)',
      );
      expect(
        AppErrorHandler.isRecoverableTransientError(
          ArgumentError.value(
            'file:///Documents/profile_avatars/a.jpg',
            'url',
            'No host specified in URI',
          ),
          stack,
        ),
        isFalse,
      );
    });

    test('does NOT suppress a socket timeout away from the image path', () {
      expect(
        AppErrorHandler.isRecoverableTransientError(
          const SocketException('Operation timed out'),
          StackTrace.fromString(
            '#0 _HttpClient.getUrl (dart:_http)\n'
            '#1 SyncService.upload (package:socialmesh/services/sync.dart:12)',
          ),
        ),
        isFalse,
      );
    });

    test('suppresses an HttpException closed mid-body', () {
      // The server half of a dropped connection: the body stops arriving and
      // dart:io raises HttpException rather than SocketException. Reported
      // from a background isolate whose stack is a single dart:isolate frame,
      // so the type and message are all there is to go on.
      expect(
        AppErrorHandler.isRecoverableTransientError(
          const HttpException('Connection closed while receiving data'),
          StackTrace.fromString(
            '#0 _RawReceivePort._handleMessage (dart:isolate)',
          ),
        ),
        isTrue,
      );
    });

    test('does NOT suppress an HttpException that is not a drop', () {
      expect(
        AppErrorHandler.isRecoverableTransientError(
          const HttpException('Invalid status code 500'),
          StackTrace.current,
        ),
        isFalse,
      );
    });

    test('suppresses a lifecycle string that was wrapped on its way up', () {
      // The protocol layer restates the platform string for the user before
      // rethrowing, which used to hide it from the exact-match branch above.
      expect(
        AppErrorHandler.isRecoverableTransientError(
          Exception('Protocol configuration failed: Service stopped'),
          StackTrace.current,
        ),
        isTrue,
      );
    });

    test(
      'does NOT suppress an error that merely mentions a lifecycle string',
      () {
        expect(
          AppErrorHandler.isRecoverableTransientError(
            Exception('Service stopped before the config write completed'),
            StackTrace.current,
          ),
          isFalse,
        );
      },
    );

    test('does NOT suppress genuine StateError', () {
      expect(
        AppErrorHandler.isRecoverableTransientError(
          StateError('Cannot add event after closing'),
          StackTrace.current,
        ),
        isFalse,
      );
    });

    test('does NOT suppress genuine RangeError', () {
      expect(
        AppErrorHandler.isRecoverableTransientError(
          RangeError.index(5, [1, 2, 3]),
          StackTrace.current,
        ),
        isFalse,
      );
    });

    test('does NOT suppress protobuf parse errors', () {
      expect(
        AppErrorHandler.isRecoverableTransientError(
          Exception('InvalidProtocolBufferException: invalid tag'),
          StackTrace.fromString(
            '#0 ProtocolService._processPacket (protocol_service.dart:1394)',
          ),
        ),
        isFalse,
      );
    });

    test('does NOT suppress arbitrary String errors', () {
      expect(
        AppErrorHandler.isRecoverableTransientError(
          'Some unexpected failure',
          StackTrace.current,
        ),
        isFalse,
      );
    });
  });
}
