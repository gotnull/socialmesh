/// Device error codes from Meshtastic
enum DeviceErrorCode {
  none,
  txWatchdog,
  sleepEnterWait,
  noRadio,
  unspecified,
  ubloxInitFailed,
  noAxp192,
  invalidRadioSetting,
  transmitFailed,
  brownout,
  sxTxTimeout,
  noAckFromRemoteRadio,
  unknown,
}

/// Maps integer error codes to enum values
DeviceErrorCode deviceErrorCodeFromInt(int code) {
  switch (code) {
    case 0:
      return DeviceErrorCode.none;
    case 1:
      return DeviceErrorCode.txWatchdog;
    case 2:
      return DeviceErrorCode.sleepEnterWait;
    case 3:
      return DeviceErrorCode.noRadio;
    case 4:
      return DeviceErrorCode.unspecified;
    case 5:
      return DeviceErrorCode.ubloxInitFailed;
    case 6:
      return DeviceErrorCode.noAxp192;
    case 7:
      return DeviceErrorCode.invalidRadioSetting;
    case 8:
      return DeviceErrorCode.transmitFailed;
    case 9:
      return DeviceErrorCode.brownout;
    case 10:
      return DeviceErrorCode.sxTxTimeout;
    case 11:
      return DeviceErrorCode.noAckFromRemoteRadio;
    default:
      return DeviceErrorCode.unknown;
  }
}

/// Device error with details
class DeviceError {
  final DeviceErrorCode code;
  final String message;
  final DateTime timestamp;

  const DeviceError({
    required this.code,
    required this.message,
    required this.timestamp,
  });

  /// User-friendly error description
  String get description {
    switch (code) {
      case DeviceErrorCode.none:
        return 'No error';
      case DeviceErrorCode.txWatchdog:
        return 'Transmit watchdog timeout';
      case DeviceErrorCode.sleepEnterWait:
        return 'Device entering sleep mode';
      case DeviceErrorCode.noRadio:
        return 'Radio hardware not found';
      case DeviceErrorCode.unspecified:
        return 'Unspecified error';
      case DeviceErrorCode.ubloxInitFailed:
        return 'GPS initialization failed';
      case DeviceErrorCode.noAxp192:
        return 'Power management chip not found';
      case DeviceErrorCode.invalidRadioSetting:
        return 'Invalid radio configuration';
      case DeviceErrorCode.transmitFailed:
        return 'Transmission failed';
      case DeviceErrorCode.brownout:
        return 'Low voltage brownout detected';
      case DeviceErrorCode.sxTxTimeout:
        return 'Radio transmit timeout';
      case DeviceErrorCode.noAckFromRemoteRadio:
        return 'No acknowledgment from remote device';
      case DeviceErrorCode.unknown:
        return 'Unknown error';
    }
  }

  @override
  String toString() => '$code: $message';
}
