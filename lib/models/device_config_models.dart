// Device configuration models for Meshtastic admin operations

/// Device configuration
class DeviceConfig {
  final DeviceRole role;
  final RebroadcastMode rebroadcastMode;
  final int nodeInfoBroadcastSecs;
  final bool serialEnabled;
  final bool doubleTapAsButtonPress;
  final bool disableTripleClick;
  final bool ledHeartbeatDisabled;
  final String? tzdef;

  DeviceConfig({
    this.role = DeviceRole.client,
    this.rebroadcastMode = RebroadcastMode.all,
    this.nodeInfoBroadcastSecs = 900,
    this.serialEnabled = true,
    this.doubleTapAsButtonPress = false,
    this.disableTripleClick = false,
    this.ledHeartbeatDisabled = false,
    this.tzdef,
  });

  DeviceConfig copyWith({
    DeviceRole? role,
    RebroadcastMode? rebroadcastMode,
    int? nodeInfoBroadcastSecs,
    bool? serialEnabled,
    bool? doubleTapAsButtonPress,
    bool? disableTripleClick,
    bool? ledHeartbeatDisabled,
    String? tzdef,
  }) {
    return DeviceConfig(
      role: role ?? this.role,
      rebroadcastMode: rebroadcastMode ?? this.rebroadcastMode,
      nodeInfoBroadcastSecs:
          nodeInfoBroadcastSecs ?? this.nodeInfoBroadcastSecs,
      serialEnabled: serialEnabled ?? this.serialEnabled,
      doubleTapAsButtonPress:
          doubleTapAsButtonPress ?? this.doubleTapAsButtonPress,
      disableTripleClick: disableTripleClick ?? this.disableTripleClick,
      ledHeartbeatDisabled: ledHeartbeatDisabled ?? this.ledHeartbeatDisabled,
      tzdef: tzdef ?? this.tzdef,
    );
  }
}

/// Device roles
enum DeviceRole {
  client('Client', 'Standard messaging device'),
  clientMute('Client Mute', 'Does not forward packets'),
  router('Router', 'Infrastructure node for extending coverage'),
  tracker('Tracker', 'Broadcasts GPS position as priority'),
  sensor('Sensor', 'Broadcasts telemetry as priority'),
  tak('TAK', 'Optimized for ATAK communication'),
  clientHidden('Client Hidden', 'Only speaks when spoken to'),
  lostAndFound('Lost & Found', 'Broadcasts location for device recovery'),
  takTracker('TAK Tracker', 'TAK with automatic position broadcasts'),
  routerLate('Router Late', 'Low priority router'),
  clientBase('Client Base', 'Base station for weaker nodes');

  final String displayName;
  final String description;

  const DeviceRole(this.displayName, this.description);
}

/// Rebroadcast modes
enum RebroadcastMode {
  all('All', 'Rebroadcast all observed messages'),
  allSkipDecoding('All (Skip Decoding)', 'Rebroadcast without decoding'),
  localOnly('Local Only', 'Only rebroadcast local channel messages'),
  knownOnly('Known Only', 'Only rebroadcast from known nodes'),
  none('None', 'Do not rebroadcast'),
  corePortnumsOnly('Core Portnums Only', 'Only standard message types');

  final String displayName;
  final String description;

  const RebroadcastMode(this.displayName, this.description);
}

/// Position configuration
class PositionConfig {
  final int positionBroadcastSecs;
  final bool smartBroadcastEnabled;
  final bool fixedPosition;
  final GpsMode gpsMode;
  final int gpsUpdateInterval;
  final int smartMinimumDistance;
  final int smartMinimumIntervalSecs;

  PositionConfig({
    this.positionBroadcastSecs = 900,
    this.smartBroadcastEnabled = true,
    this.fixedPosition = false,
    this.gpsMode = GpsMode.enabled,
    this.gpsUpdateInterval = 30,
    this.smartMinimumDistance = 100,
    this.smartMinimumIntervalSecs = 30,
  });

  PositionConfig copyWith({
    int? positionBroadcastSecs,
    bool? smartBroadcastEnabled,
    bool? fixedPosition,
    GpsMode? gpsMode,
    int? gpsUpdateInterval,
    int? smartMinimumDistance,
    int? smartMinimumIntervalSecs,
  }) {
    return PositionConfig(
      positionBroadcastSecs:
          positionBroadcastSecs ?? this.positionBroadcastSecs,
      smartBroadcastEnabled:
          smartBroadcastEnabled ?? this.smartBroadcastEnabled,
      fixedPosition: fixedPosition ?? this.fixedPosition,
      gpsMode: gpsMode ?? this.gpsMode,
      gpsUpdateInterval: gpsUpdateInterval ?? this.gpsUpdateInterval,
      smartMinimumDistance: smartMinimumDistance ?? this.smartMinimumDistance,
      smartMinimumIntervalSecs:
          smartMinimumIntervalSecs ?? this.smartMinimumIntervalSecs,
    );
  }
}

/// GPS modes
enum GpsMode {
  disabled('Disabled', 'GPS is present but disabled'),
  enabled('Enabled', 'GPS is present and enabled'),
  notPresent('Not Present', 'GPS is not present on device');

  final String displayName;
  final String description;

  const GpsMode(this.displayName, this.description);
}

/// Power configuration
class PowerConfig {
  final bool isPowerSaving;
  final int onBatteryShutdownAfterSecs;
  final int waitBluetoothSecs;
  final int sdsSecs;
  final int lsSecs;
  final int minWakeSecs;

  PowerConfig({
    this.isPowerSaving = false,
    this.onBatteryShutdownAfterSecs = 0,
    this.waitBluetoothSecs = 60,
    this.sdsSecs = 31536000, // 1 year
    this.lsSecs = 300,
    this.minWakeSecs = 10,
  });

  PowerConfig copyWith({
    bool? isPowerSaving,
    int? onBatteryShutdownAfterSecs,
    int? waitBluetoothSecs,
    int? sdsSecs,
    int? lsSecs,
    int? minWakeSecs,
  }) {
    return PowerConfig(
      isPowerSaving: isPowerSaving ?? this.isPowerSaving,
      onBatteryShutdownAfterSecs:
          onBatteryShutdownAfterSecs ?? this.onBatteryShutdownAfterSecs,
      waitBluetoothSecs: waitBluetoothSecs ?? this.waitBluetoothSecs,
      sdsSecs: sdsSecs ?? this.sdsSecs,
      lsSecs: lsSecs ?? this.lsSecs,
      minWakeSecs: minWakeSecs ?? this.minWakeSecs,
    );
  }
}

/// Display configuration
class DisplayConfig {
  final int screenOnSecs;
  final int autoScreenCarouselSecs;
  final bool flipScreen;
  final DisplayUnits units;
  final bool headingBold;
  final bool wakeOnTapOrMotion;
  final bool use12hClock;

  DisplayConfig({
    this.screenOnSecs = 60,
    this.autoScreenCarouselSecs = 0,
    this.flipScreen = false,
    this.units = DisplayUnits.metric,
    this.headingBold = false,
    this.wakeOnTapOrMotion = false,
    this.use12hClock = false,
  });

  DisplayConfig copyWith({
    int? screenOnSecs,
    int? autoScreenCarouselSecs,
    bool? flipScreen,
    DisplayUnits? units,
    bool? headingBold,
    bool? wakeOnTapOrMotion,
    bool? use12hClock,
  }) {
    return DisplayConfig(
      screenOnSecs: screenOnSecs ?? this.screenOnSecs,
      autoScreenCarouselSecs:
          autoScreenCarouselSecs ?? this.autoScreenCarouselSecs,
      flipScreen: flipScreen ?? this.flipScreen,
      units: units ?? this.units,
      headingBold: headingBold ?? this.headingBold,
      wakeOnTapOrMotion: wakeOnTapOrMotion ?? this.wakeOnTapOrMotion,
      use12hClock: use12hClock ?? this.use12hClock,
    );
  }
}

/// Display units
enum DisplayUnits {
  metric('Metric', 'Kilometers, Celsius'),
  imperial('Imperial', 'Miles, Fahrenheit');

  final String displayName;
  final String description;

  const DisplayUnits(this.displayName, this.description);
}

/// Bluetooth configuration
class BluetoothConfig {
  final bool enabled;
  final BluetoothPairingMode mode;
  final int fixedPin;

  BluetoothConfig({
    this.enabled = true,
    this.mode = BluetoothPairingMode.randomPin,
    this.fixedPin = 123456,
  });

  BluetoothConfig copyWith({
    bool? enabled,
    BluetoothPairingMode? mode,
    int? fixedPin,
  }) {
    return BluetoothConfig(
      enabled: enabled ?? this.enabled,
      mode: mode ?? this.mode,
      fixedPin: fixedPin ?? this.fixedPin,
    );
  }
}

/// Bluetooth pairing modes
enum BluetoothPairingMode {
  randomPin('Random PIN', 'Generate random PIN shown on screen'),
  fixedPin('Fixed PIN', 'Use a specified fixed PIN'),
  noPin('No PIN', 'No PIN required for pairing');

  final String displayName;
  final String description;

  const BluetoothPairingMode(this.displayName, this.description);
}

/// LoRa configuration
class LoRaConfig {
  final bool usePreset;
  final ModemPreset modemPreset;
  final int hopLimit;
  final bool txEnabled;
  final int txPower;
  final bool overrideDutyCycle;
  final bool sx126xRxBoostedGain;
  final bool ignoreMqtt;

  LoRaConfig({
    this.usePreset = true,
    this.modemPreset = ModemPreset.longFast,
    this.hopLimit = 3,
    this.txEnabled = true,
    this.txPower = 0,
    this.overrideDutyCycle = false,
    this.sx126xRxBoostedGain = false,
    this.ignoreMqtt = false,
  });

  LoRaConfig copyWith({
    bool? usePreset,
    ModemPreset? modemPreset,
    int? hopLimit,
    bool? txEnabled,
    int? txPower,
    bool? overrideDutyCycle,
    bool? sx126xRxBoostedGain,
    bool? ignoreMqtt,
  }) {
    return LoRaConfig(
      usePreset: usePreset ?? this.usePreset,
      modemPreset: modemPreset ?? this.modemPreset,
      hopLimit: hopLimit ?? this.hopLimit,
      txEnabled: txEnabled ?? this.txEnabled,
      txPower: txPower ?? this.txPower,
      overrideDutyCycle: overrideDutyCycle ?? this.overrideDutyCycle,
      sx126xRxBoostedGain: sx126xRxBoostedGain ?? this.sx126xRxBoostedGain,
      ignoreMqtt: ignoreMqtt ?? this.ignoreMqtt,
    );
  }
}

/// Modem presets
enum ModemPreset {
  longFast('Long Fast', '250kHz bandwidth, optimized for range'),
  longSlow('Long Slow', 'Maximum range, slower speed'),
  mediumSlow('Medium Slow', 'Balanced range and speed'),
  mediumFast('Medium Fast', 'Good range with faster speed'),
  shortSlow('Short Slow', 'Short range, reliable'),
  shortFast('Short Fast', 'Short range, fast'),
  longModerate('Long Moderate', 'Long range, moderate speed'),
  shortTurbo('Short Turbo', 'Fastest preset, 500kHz bandwidth');

  final String displayName;
  final String description;

  const ModemPreset(this.displayName, this.description);
}

/// Device metadata
class DeviceMetadata {
  final String firmwareVersion;
  final int deviceStateVersion;
  final bool canShutdown;
  final bool hasWifi;
  final bool hasBluetooth;
  final bool hasEthernet;
  final String? role;
  final String? hardwareModel;
  final bool hasRemoteHardware;
  final bool hasPKC;

  DeviceMetadata({
    this.firmwareVersion = 'Unknown',
    this.deviceStateVersion = 0,
    this.canShutdown = false,
    this.hasWifi = false,
    this.hasBluetooth = true,
    this.hasEthernet = false,
    this.role,
    this.hardwareModel,
    this.hasRemoteHardware = false,
    this.hasPKC = false,
  });
}

/// MQTT configuration
class MQTTConfig {
  final bool enabled;
  final String address;
  final String username;
  final String password;
  final bool encryptionEnabled;
  final bool jsonEnabled;
  final bool tlsEnabled;
  final String root;
  final bool proxyToClientEnabled;
  final bool mapReportingEnabled;

  MQTTConfig({
    this.enabled = false,
    this.address = '',
    this.username = '',
    this.password = '',
    this.encryptionEnabled = true,
    this.jsonEnabled = false,
    this.tlsEnabled = false,
    this.root = 'msh',
    this.proxyToClientEnabled = false,
    this.mapReportingEnabled = false,
  });

  MQTTConfig copyWith({
    bool? enabled,
    String? address,
    String? username,
    String? password,
    bool? encryptionEnabled,
    bool? jsonEnabled,
    bool? tlsEnabled,
    String? root,
    bool? proxyToClientEnabled,
    bool? mapReportingEnabled,
  }) {
    return MQTTConfig(
      enabled: enabled ?? this.enabled,
      address: address ?? this.address,
      username: username ?? this.username,
      password: password ?? this.password,
      encryptionEnabled: encryptionEnabled ?? this.encryptionEnabled,
      jsonEnabled: jsonEnabled ?? this.jsonEnabled,
      tlsEnabled: tlsEnabled ?? this.tlsEnabled,
      root: root ?? this.root,
      proxyToClientEnabled: proxyToClientEnabled ?? this.proxyToClientEnabled,
      mapReportingEnabled: mapReportingEnabled ?? this.mapReportingEnabled,
    );
  }
}

/// Telemetry configuration
class TelemetryConfig {
  final int deviceUpdateInterval;
  final int environmentUpdateInterval;
  final bool environmentMeasurementEnabled;
  final bool environmentScreenEnabled;
  final bool environmentDisplayFahrenheit;
  final bool airQualityEnabled;
  final int airQualityInterval;
  final bool powerMeasurementEnabled;
  final int powerUpdateInterval;

  TelemetryConfig({
    this.deviceUpdateInterval = 1800,
    this.environmentUpdateInterval = 1800,
    this.environmentMeasurementEnabled = false,
    this.environmentScreenEnabled = false,
    this.environmentDisplayFahrenheit = false,
    this.airQualityEnabled = false,
    this.airQualityInterval = 1800,
    this.powerMeasurementEnabled = false,
    this.powerUpdateInterval = 1800,
  });

  TelemetryConfig copyWith({
    int? deviceUpdateInterval,
    int? environmentUpdateInterval,
    bool? environmentMeasurementEnabled,
    bool? environmentScreenEnabled,
    bool? environmentDisplayFahrenheit,
    bool? airQualityEnabled,
    int? airQualityInterval,
    bool? powerMeasurementEnabled,
    int? powerUpdateInterval,
  }) {
    return TelemetryConfig(
      deviceUpdateInterval: deviceUpdateInterval ?? this.deviceUpdateInterval,
      environmentUpdateInterval:
          environmentUpdateInterval ?? this.environmentUpdateInterval,
      environmentMeasurementEnabled:
          environmentMeasurementEnabled ?? this.environmentMeasurementEnabled,
      environmentScreenEnabled:
          environmentScreenEnabled ?? this.environmentScreenEnabled,
      environmentDisplayFahrenheit:
          environmentDisplayFahrenheit ?? this.environmentDisplayFahrenheit,
      airQualityEnabled: airQualityEnabled ?? this.airQualityEnabled,
      airQualityInterval: airQualityInterval ?? this.airQualityInterval,
      powerMeasurementEnabled:
          powerMeasurementEnabled ?? this.powerMeasurementEnabled,
      powerUpdateInterval: powerUpdateInterval ?? this.powerUpdateInterval,
    );
  }
}

/// External notification configuration
class ExternalNotificationConfig {
  final bool enabled;
  final int outputMs;
  final bool active;
  final bool alertMessage;
  final bool alertBell;
  final bool usePwm;
  final int nagTimeout;

  ExternalNotificationConfig({
    this.enabled = false,
    this.outputMs = 1000,
    this.active = false,
    this.alertMessage = true,
    this.alertBell = true,
    this.usePwm = false,
    this.nagTimeout = 0,
  });

  ExternalNotificationConfig copyWith({
    bool? enabled,
    int? outputMs,
    bool? active,
    bool? alertMessage,
    bool? alertBell,
    bool? usePwm,
    int? nagTimeout,
  }) {
    return ExternalNotificationConfig(
      enabled: enabled ?? this.enabled,
      outputMs: outputMs ?? this.outputMs,
      active: active ?? this.active,
      alertMessage: alertMessage ?? this.alertMessage,
      alertBell: alertBell ?? this.alertBell,
      usePwm: usePwm ?? this.usePwm,
      nagTimeout: nagTimeout ?? this.nagTimeout,
    );
  }
}

/// Store and Forward configuration
class StoreForwardConfig {
  final bool enabled;
  final bool heartbeat;
  final int records;
  final int historyReturnMax;
  final int historyReturnWindow;
  final bool isServer;

  StoreForwardConfig({
    this.enabled = false,
    this.heartbeat = false,
    this.records = 0,
    this.historyReturnMax = 0,
    this.historyReturnWindow = 0,
    this.isServer = false,
  });

  StoreForwardConfig copyWith({
    bool? enabled,
    bool? heartbeat,
    int? records,
    int? historyReturnMax,
    int? historyReturnWindow,
    bool? isServer,
  }) {
    return StoreForwardConfig(
      enabled: enabled ?? this.enabled,
      heartbeat: heartbeat ?? this.heartbeat,
      records: records ?? this.records,
      historyReturnMax: historyReturnMax ?? this.historyReturnMax,
      historyReturnWindow: historyReturnWindow ?? this.historyReturnWindow,
      isServer: isServer ?? this.isServer,
    );
  }
}

/// Range Test configuration
class RangeTestConfig {
  final bool enabled;
  final int sender;
  final bool save;

  RangeTestConfig({this.enabled = false, this.sender = 0, this.save = false});

  RangeTestConfig copyWith({bool? enabled, int? sender, bool? save}) {
    return RangeTestConfig(
      enabled: enabled ?? this.enabled,
      sender: sender ?? this.sender,
      save: save ?? this.save,
    );
  }
}

/// Fixed position data
class FixedPosition {
  final double latitude;
  final double longitude;
  final int altitude;

  FixedPosition({
    required this.latitude,
    required this.longitude,
    this.altitude = 0,
  });
}
