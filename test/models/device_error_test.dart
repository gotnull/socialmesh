import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/device_error.dart';

void main() {
  group('DeviceErrorCode', () {
    test('has all expected values', () {
      expect(DeviceErrorCode.values.length, 13);
      expect(DeviceErrorCode.values, contains(DeviceErrorCode.none));
      expect(DeviceErrorCode.values, contains(DeviceErrorCode.txWatchdog));
      expect(DeviceErrorCode.values, contains(DeviceErrorCode.sleepEnterWait));
      expect(DeviceErrorCode.values, contains(DeviceErrorCode.noRadio));
      expect(DeviceErrorCode.values, contains(DeviceErrorCode.unspecified));
      expect(DeviceErrorCode.values, contains(DeviceErrorCode.ubloxInitFailed));
      expect(DeviceErrorCode.values, contains(DeviceErrorCode.noAxp192));
      expect(
        DeviceErrorCode.values,
        contains(DeviceErrorCode.invalidRadioSetting),
      );
      expect(DeviceErrorCode.values, contains(DeviceErrorCode.transmitFailed));
      expect(DeviceErrorCode.values, contains(DeviceErrorCode.brownout));
      expect(DeviceErrorCode.values, contains(DeviceErrorCode.sxTxTimeout));
      expect(
        DeviceErrorCode.values,
        contains(DeviceErrorCode.noAckFromRemoteRadio),
      );
      expect(DeviceErrorCode.values, contains(DeviceErrorCode.unknown));
    });
  });

  group('deviceErrorCodeFromInt', () {
    test('maps 0 to none', () {
      expect(deviceErrorCodeFromInt(0), DeviceErrorCode.none);
    });

    test('maps 1 to txWatchdog', () {
      expect(deviceErrorCodeFromInt(1), DeviceErrorCode.txWatchdog);
    });

    test('maps 2 to sleepEnterWait', () {
      expect(deviceErrorCodeFromInt(2), DeviceErrorCode.sleepEnterWait);
    });

    test('maps 3 to noRadio', () {
      expect(deviceErrorCodeFromInt(3), DeviceErrorCode.noRadio);
    });

    test('maps 4 to unspecified', () {
      expect(deviceErrorCodeFromInt(4), DeviceErrorCode.unspecified);
    });

    test('maps 5 to ubloxInitFailed', () {
      expect(deviceErrorCodeFromInt(5), DeviceErrorCode.ubloxInitFailed);
    });

    test('maps 6 to noAxp192', () {
      expect(deviceErrorCodeFromInt(6), DeviceErrorCode.noAxp192);
    });

    test('maps 7 to invalidRadioSetting', () {
      expect(deviceErrorCodeFromInt(7), DeviceErrorCode.invalidRadioSetting);
    });

    test('maps 8 to transmitFailed', () {
      expect(deviceErrorCodeFromInt(8), DeviceErrorCode.transmitFailed);
    });

    test('maps 9 to brownout', () {
      expect(deviceErrorCodeFromInt(9), DeviceErrorCode.brownout);
    });

    test('maps 10 to sxTxTimeout', () {
      expect(deviceErrorCodeFromInt(10), DeviceErrorCode.sxTxTimeout);
    });

    test('maps 11 to noAckFromRemoteRadio', () {
      expect(deviceErrorCodeFromInt(11), DeviceErrorCode.noAckFromRemoteRadio);
    });

    test('maps unknown codes to unknown', () {
      expect(deviceErrorCodeFromInt(12), DeviceErrorCode.unknown);
      expect(deviceErrorCodeFromInt(100), DeviceErrorCode.unknown);
      expect(deviceErrorCodeFromInt(-1), DeviceErrorCode.unknown);
      expect(deviceErrorCodeFromInt(999), DeviceErrorCode.unknown);
    });
  });

  group('DeviceError', () {
    test('creates with required fields', () {
      final timestamp = DateTime.now();
      final error = DeviceError(
        code: DeviceErrorCode.noRadio,
        message: 'Test error message',
        timestamp: timestamp,
      );

      expect(error.code, DeviceErrorCode.noRadio);
      expect(error.message, 'Test error message');
      expect(error.timestamp, timestamp);
    });

    test('description for none', () {
      final error = DeviceError(
        code: DeviceErrorCode.none,
        message: '',
        timestamp: DateTime.now(),
      );
      expect(error.description, 'No error');
    });

    test('description for txWatchdog', () {
      final error = DeviceError(
        code: DeviceErrorCode.txWatchdog,
        message: '',
        timestamp: DateTime.now(),
      );
      expect(error.description, 'Transmit watchdog timeout');
    });

    test('description for sleepEnterWait', () {
      final error = DeviceError(
        code: DeviceErrorCode.sleepEnterWait,
        message: '',
        timestamp: DateTime.now(),
      );
      expect(error.description, 'Device entering sleep mode');
    });

    test('description for noRadio', () {
      final error = DeviceError(
        code: DeviceErrorCode.noRadio,
        message: '',
        timestamp: DateTime.now(),
      );
      expect(error.description, 'Radio hardware not found');
    });

    test('description for unspecified', () {
      final error = DeviceError(
        code: DeviceErrorCode.unspecified,
        message: '',
        timestamp: DateTime.now(),
      );
      expect(error.description, 'Unspecified error');
    });

    test('description for ubloxInitFailed', () {
      final error = DeviceError(
        code: DeviceErrorCode.ubloxInitFailed,
        message: '',
        timestamp: DateTime.now(),
      );
      expect(error.description, 'GPS initialization failed');
    });

    test('description for noAxp192', () {
      final error = DeviceError(
        code: DeviceErrorCode.noAxp192,
        message: '',
        timestamp: DateTime.now(),
      );
      expect(error.description, 'Power management chip not found');
    });

    test('description for invalidRadioSetting', () {
      final error = DeviceError(
        code: DeviceErrorCode.invalidRadioSetting,
        message: '',
        timestamp: DateTime.now(),
      );
      expect(error.description, 'Invalid radio configuration');
    });

    test('description for transmitFailed', () {
      final error = DeviceError(
        code: DeviceErrorCode.transmitFailed,
        message: '',
        timestamp: DateTime.now(),
      );
      expect(error.description, 'Transmission failed');
    });

    test('description for brownout', () {
      final error = DeviceError(
        code: DeviceErrorCode.brownout,
        message: '',
        timestamp: DateTime.now(),
      );
      expect(error.description, 'Low voltage brownout detected');
    });

    test('description for sxTxTimeout', () {
      final error = DeviceError(
        code: DeviceErrorCode.sxTxTimeout,
        message: '',
        timestamp: DateTime.now(),
      );
      expect(error.description, 'Radio transmit timeout');
    });

    test('description for noAckFromRemoteRadio', () {
      final error = DeviceError(
        code: DeviceErrorCode.noAckFromRemoteRadio,
        message: '',
        timestamp: DateTime.now(),
      );
      expect(error.description, 'No acknowledgment from remote device');
    });

    test('description for unknown', () {
      final error = DeviceError(
        code: DeviceErrorCode.unknown,
        message: '',
        timestamp: DateTime.now(),
      );
      expect(error.description, 'Unknown error');
    });

    test('toString returns code and message', () {
      final error = DeviceError(
        code: DeviceErrorCode.noRadio,
        message: 'Custom message',
        timestamp: DateTime.now(),
      );
      expect(error.toString(), 'DeviceErrorCode.noRadio: Custom message');
    });
  });
}
