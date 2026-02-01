// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/transport/ble_transport.dart';

void main() {
  group('MeshtasticServiceNotFoundException', () {
    test('creates exception with message', () {
      const message = 'Service not found';
      final exception = MeshtasticServiceNotFoundException(message);

      expect(exception.message, equals(message));
    });

    test('toString includes exception type and message', () {
      const message = 'Meshtastic service UUID not found on device';
      final exception = MeshtasticServiceNotFoundException(message);

      expect(
        exception.toString(),
        equals('MeshtasticServiceNotFoundException: $message'),
      );
    });

    test('can be thrown and caught', () {
      expect(
        () => throw const MeshtasticServiceNotFoundException(
          'Device may be running MeshCore',
        ),
        throwsA(isA<MeshtasticServiceNotFoundException>()),
      );
    });

    test('provides helpful error message for MeshCore devices', () {
      const message =
          'Meshtastic BLE service not found. This device may be '
          'running a different protocol (e.g., MeshCore) or is not a mesh radio.';
      final exception = MeshtasticServiceNotFoundException(message);

      expect(exception.message, contains('MeshCore'));
      expect(exception.message, contains('different protocol'));
    });

    test('is an Exception', () {
      final exception = MeshtasticServiceNotFoundException('test');
      expect(exception, isA<Exception>());
    });
  });
}
