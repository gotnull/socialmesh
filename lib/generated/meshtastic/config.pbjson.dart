// This is a generated file - do not edit.
//
// Generated from meshtastic/config.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use configDescriptor instead')
const Config$json = {
  '1': 'Config',
  '2': [
    {
      '1': 'device',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Config.DeviceConfig',
      '9': 0,
      '10': 'device'
    },
    {
      '1': 'position',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Config.PositionConfig',
      '9': 0,
      '10': 'position'
    },
    {
      '1': 'power',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Config.PowerConfig',
      '9': 0,
      '10': 'power'
    },
    {
      '1': 'network',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Config.NetworkConfig',
      '9': 0,
      '10': 'network'
    },
    {
      '1': 'display',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Config.DisplayConfig',
      '9': 0,
      '10': 'display'
    },
    {
      '1': 'lora',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Config.LoRaConfig',
      '9': 0,
      '10': 'lora'
    },
    {
      '1': 'bluetooth',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Config.BluetoothConfig',
      '9': 0,
      '10': 'bluetooth'
    },
    {
      '1': 'security',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Config.SecurityConfig',
      '9': 0,
      '10': 'security'
    },
    {
      '1': 'sessionkey',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Config.SessionkeyConfig',
      '9': 0,
      '10': 'sessionkey'
    },
    {
      '1': 'device_ui',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.DeviceUIConfig',
      '9': 0,
      '10': 'deviceUi'
    },
  ],
  '3': [
    Config_DeviceConfig$json,
    Config_PositionConfig$json,
    Config_PowerConfig$json,
    Config_NetworkConfig$json,
    Config_DisplayConfig$json,
    Config_LoRaConfig$json,
    Config_BluetoothConfig$json,
    Config_SecurityConfig$json,
    Config_SessionkeyConfig$json
  ],
  '8': [
    {'1': 'payload_variant'},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_DeviceConfig$json = {
  '1': 'DeviceConfig',
  '2': [
    {
      '1': 'role',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.DeviceConfig.Role',
      '8': {},
      '10': 'role'
    },
    {
      '1': 'serial_enabled',
      '3': 2,
      '4': 1,
      '5': 8,
      '8': {'3': true},
      '10': 'serialEnabled',
    },
    {'1': 'button_gpio', '3': 4, '4': 1, '5': 13, '8': {}, '10': 'buttonGpio'},
    {'1': 'buzzer_gpio', '3': 5, '4': 1, '5': 13, '8': {}, '10': 'buzzerGpio'},
    {
      '1': 'rebroadcast_mode',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.DeviceConfig.RebroadcastMode',
      '8': {},
      '10': 'rebroadcastMode'
    },
    {
      '1': 'node_info_broadcast_secs',
      '3': 7,
      '4': 1,
      '5': 13,
      '8': {},
      '10': 'nodeInfoBroadcastSecs'
    },
    {
      '1': 'double_tap_as_button_press',
      '3': 8,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'doubleTapAsButtonPress'
    },
    {
      '1': 'is_managed',
      '3': 9,
      '4': 1,
      '5': 8,
      '8': {'3': true},
      '10': 'isManaged',
    },
    {
      '1': 'disable_triple_click',
      '3': 10,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'disableTripleClick'
    },
    {'1': 'tzdef', '3': 11, '4': 1, '5': 9, '8': {}, '10': 'tzdef'},
    {
      '1': 'led_heartbeat_disabled',
      '3': 12,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'ledHeartbeatDisabled'
    },
    {
      '1': 'buzzer_mode',
      '3': 13,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.DeviceConfig.BuzzerMode',
      '8': {},
      '10': 'buzzerMode'
    },
  ],
  '4': [
    Config_DeviceConfig_Role$json,
    Config_DeviceConfig_RebroadcastMode$json,
    Config_DeviceConfig_BuzzerMode$json
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_DeviceConfig_Role$json = {
  '1': 'Role',
  '2': [
    {'1': 'CLIENT', '2': 0, '3': {}},
    {'1': 'CLIENT_MUTE', '2': 1, '3': {}},
    {'1': 'ROUTER', '2': 2, '3': {}},
    {
      '1': 'ROUTER_CLIENT',
      '2': 3,
      '3': {'1': true},
    },
    {
      '1': 'REPEATER',
      '2': 4,
      '3': {'1': true},
    },
    {'1': 'TRACKER', '2': 5, '3': {}},
    {'1': 'SENSOR', '2': 6, '3': {}},
    {'1': 'TAK', '2': 7, '3': {}},
    {'1': 'CLIENT_HIDDEN', '2': 8, '3': {}},
    {'1': 'LOST_AND_FOUND', '2': 9, '3': {}},
    {'1': 'TAK_TRACKER', '2': 10, '3': {}},
    {'1': 'ROUTER_LATE', '2': 11, '3': {}},
    {'1': 'CLIENT_BASE', '2': 12, '3': {}},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_DeviceConfig_RebroadcastMode$json = {
  '1': 'RebroadcastMode',
  '2': [
    {'1': 'ALL', '2': 0, '3': {}},
    {'1': 'ALL_SKIP_DECODING', '2': 1, '3': {}},
    {'1': 'LOCAL_ONLY', '2': 2, '3': {}},
    {'1': 'KNOWN_ONLY', '2': 3, '3': {}},
    {'1': 'NONE', '2': 4, '3': {}},
    {'1': 'CORE_PORTNUMS_ONLY', '2': 5, '3': {}},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_DeviceConfig_BuzzerMode$json = {
  '1': 'BuzzerMode',
  '2': [
    {'1': 'ALL_ENABLED', '2': 0},
    {'1': 'DISABLED', '2': 1},
    {'1': 'NOTIFICATIONS_ONLY', '2': 2},
    {'1': 'SYSTEM_ONLY', '2': 3},
    {'1': 'DIRECT_MSG_ONLY', '2': 4},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_PositionConfig$json = {
  '1': 'PositionConfig',
  '2': [
    {
      '1': 'position_broadcast_secs',
      '3': 1,
      '4': 1,
      '5': 13,
      '8': {},
      '10': 'positionBroadcastSecs'
    },
    {
      '1': 'position_broadcast_smart_enabled',
      '3': 2,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'positionBroadcastSmartEnabled'
    },
    {
      '1': 'fixed_position',
      '3': 3,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'fixedPosition'
    },
    {
      '1': 'gps_enabled',
      '3': 4,
      '4': 1,
      '5': 8,
      '8': {'3': true},
      '10': 'gpsEnabled',
    },
    {
      '1': 'gps_update_interval',
      '3': 5,
      '4': 1,
      '5': 13,
      '8': {},
      '10': 'gpsUpdateInterval'
    },
    {
      '1': 'gps_attempt_time',
      '3': 6,
      '4': 1,
      '5': 13,
      '8': {'3': true},
      '10': 'gpsAttemptTime',
    },
    {
      '1': 'position_flags',
      '3': 7,
      '4': 1,
      '5': 13,
      '8': {},
      '10': 'positionFlags'
    },
    {'1': 'rx_gpio', '3': 8, '4': 1, '5': 13, '8': {}, '10': 'rxGpio'},
    {'1': 'tx_gpio', '3': 9, '4': 1, '5': 13, '8': {}, '10': 'txGpio'},
    {
      '1': 'broadcast_smart_minimum_distance',
      '3': 10,
      '4': 1,
      '5': 13,
      '8': {},
      '10': 'broadcastSmartMinimumDistance'
    },
    {
      '1': 'broadcast_smart_minimum_interval_secs',
      '3': 11,
      '4': 1,
      '5': 13,
      '8': {},
      '10': 'broadcastSmartMinimumIntervalSecs'
    },
    {'1': 'gps_en_gpio', '3': 12, '4': 1, '5': 13, '8': {}, '10': 'gpsEnGpio'},
    {
      '1': 'gps_mode',
      '3': 13,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.PositionConfig.GpsMode',
      '8': {},
      '10': 'gpsMode'
    },
  ],
  '4': [
    Config_PositionConfig_PositionFlags$json,
    Config_PositionConfig_GpsMode$json
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_PositionConfig_PositionFlags$json = {
  '1': 'PositionFlags',
  '2': [
    {'1': 'UNSET', '2': 0},
    {'1': 'ALTITUDE', '2': 1, '3': {}},
    {'1': 'ALTITUDE_MSL', '2': 2, '3': {}},
    {'1': 'GEOIDAL_SEPARATION', '2': 4, '3': {}},
    {'1': 'DOP', '2': 8, '3': {}},
    {'1': 'HVDOP', '2': 16, '3': {}},
    {'1': 'SATINVIEW', '2': 32, '3': {}},
    {'1': 'SEQ_NO', '2': 64, '3': {}},
    {'1': 'TIMESTAMP', '2': 128, '3': {}},
    {'1': 'HEADING', '2': 256, '3': {}},
    {'1': 'SPEED', '2': 512, '3': {}},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_PositionConfig_GpsMode$json = {
  '1': 'GpsMode',
  '2': [
    {'1': 'DISABLED', '2': 0, '3': {}},
    {'1': 'ENABLED', '2': 1, '3': {}},
    {'1': 'NOT_PRESENT', '2': 2, '3': {}},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_PowerConfig$json = {
  '1': 'PowerConfig',
  '2': [
    {
      '1': 'is_power_saving',
      '3': 1,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'isPowerSaving'
    },
    {
      '1': 'on_battery_shutdown_after_secs',
      '3': 2,
      '4': 1,
      '5': 13,
      '8': {},
      '10': 'onBatteryShutdownAfterSecs'
    },
    {
      '1': 'adc_multiplier_override',
      '3': 3,
      '4': 1,
      '5': 2,
      '8': {},
      '10': 'adcMultiplierOverride'
    },
    {
      '1': 'wait_bluetooth_secs',
      '3': 4,
      '4': 1,
      '5': 13,
      '8': {},
      '10': 'waitBluetoothSecs'
    },
    {'1': 'sds_secs', '3': 6, '4': 1, '5': 13, '8': {}, '10': 'sdsSecs'},
    {'1': 'ls_secs', '3': 7, '4': 1, '5': 13, '10': 'lsSecs'},
    {
      '1': 'min_wake_secs',
      '3': 8,
      '4': 1,
      '5': 13,
      '8': {},
      '10': 'minWakeSecs'
    },
    {
      '1': 'device_battery_ina_address',
      '3': 9,
      '4': 1,
      '5': 13,
      '8': {},
      '10': 'deviceBatteryInaAddress'
    },
    {'1': 'powermon_enables', '3': 32, '4': 1, '5': 4, '10': 'powermonEnables'},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_NetworkConfig$json = {
  '1': 'NetworkConfig',
  '2': [
    {'1': 'wifi_enabled', '3': 1, '4': 1, '5': 8, '8': {}, '10': 'wifiEnabled'},
    {'1': 'wifi_ssid', '3': 3, '4': 1, '5': 9, '8': {}, '10': 'wifiSsid'},
    {'1': 'wifi_psk', '3': 4, '4': 1, '5': 9, '8': {}, '10': 'wifiPsk'},
    {'1': 'ntp_server', '3': 5, '4': 1, '5': 9, '8': {}, '10': 'ntpServer'},
    {'1': 'eth_enabled', '3': 6, '4': 1, '5': 8, '8': {}, '10': 'ethEnabled'},
    {
      '1': 'address_mode',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.NetworkConfig.AddressMode',
      '8': {},
      '10': 'addressMode'
    },
    {
      '1': 'ipv4_config',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Config.NetworkConfig.IpV4Config',
      '10': 'ipv4Config'
    },
    {
      '1': 'rsyslog_server',
      '3': 9,
      '4': 1,
      '5': 9,
      '8': {},
      '10': 'rsyslogServer'
    },
    {
      '1': 'enabled_protocols',
      '3': 10,
      '4': 1,
      '5': 13,
      '8': {},
      '10': 'enabledProtocols'
    },
    {
      '1': 'ipv6_enabled',
      '3': 11,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'ipv6Enabled'
    },
  ],
  '3': [Config_NetworkConfig_IpV4Config$json],
  '4': [
    Config_NetworkConfig_AddressMode$json,
    Config_NetworkConfig_ProtocolFlags$json
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_NetworkConfig_IpV4Config$json = {
  '1': 'IpV4Config',
  '2': [
    {'1': 'ip', '3': 1, '4': 1, '5': 7, '8': {}, '10': 'ip'},
    {'1': 'gateway', '3': 2, '4': 1, '5': 7, '8': {}, '10': 'gateway'},
    {'1': 'subnet', '3': 3, '4': 1, '5': 7, '8': {}, '10': 'subnet'},
    {'1': 'dns', '3': 4, '4': 1, '5': 7, '8': {}, '10': 'dns'},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_NetworkConfig_AddressMode$json = {
  '1': 'AddressMode',
  '2': [
    {'1': 'DHCP', '2': 0, '3': {}},
    {'1': 'STATIC', '2': 1, '3': {}},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_NetworkConfig_ProtocolFlags$json = {
  '1': 'ProtocolFlags',
  '2': [
    {'1': 'NO_BROADCAST', '2': 0, '3': {}},
    {'1': 'UDP_BROADCAST', '2': 1, '3': {}},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_DisplayConfig$json = {
  '1': 'DisplayConfig',
  '2': [
    {
      '1': 'screen_on_secs',
      '3': 1,
      '4': 1,
      '5': 13,
      '8': {},
      '10': 'screenOnSecs'
    },
    {
      '1': 'gps_format',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.DisplayConfig.DeprecatedGpsCoordinateFormat',
      '8': {'3': true},
      '10': 'gpsFormat',
    },
    {
      '1': 'auto_screen_carousel_secs',
      '3': 3,
      '4': 1,
      '5': 13,
      '8': {},
      '10': 'autoScreenCarouselSecs'
    },
    {
      '1': 'compass_north_top',
      '3': 4,
      '4': 1,
      '5': 8,
      '8': {'3': true},
      '10': 'compassNorthTop',
    },
    {'1': 'flip_screen', '3': 5, '4': 1, '5': 8, '8': {}, '10': 'flipScreen'},
    {
      '1': 'units',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.DisplayConfig.DisplayUnits',
      '8': {},
      '10': 'units'
    },
    {
      '1': 'oled',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.DisplayConfig.OledType',
      '8': {},
      '10': 'oled'
    },
    {
      '1': 'displaymode',
      '3': 8,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.DisplayConfig.DisplayMode',
      '8': {},
      '10': 'displaymode'
    },
    {'1': 'heading_bold', '3': 9, '4': 1, '5': 8, '8': {}, '10': 'headingBold'},
    {
      '1': 'wake_on_tap_or_motion',
      '3': 10,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'wakeOnTapOrMotion'
    },
    {
      '1': 'compass_orientation',
      '3': 11,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.DisplayConfig.CompassOrientation',
      '8': {},
      '10': 'compassOrientation'
    },
    {
      '1': 'use_12h_clock',
      '3': 12,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'use12hClock'
    },
    {
      '1': 'use_long_node_name',
      '3': 13,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'useLongNodeName'
    },
    {
      '1': 'enable_message_bubbles',
      '3': 14,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'enableMessageBubbles'
    },
  ],
  '4': [
    Config_DisplayConfig_DeprecatedGpsCoordinateFormat$json,
    Config_DisplayConfig_DisplayUnits$json,
    Config_DisplayConfig_OledType$json,
    Config_DisplayConfig_DisplayMode$json,
    Config_DisplayConfig_CompassOrientation$json
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_DisplayConfig_DeprecatedGpsCoordinateFormat$json = {
  '1': 'DeprecatedGpsCoordinateFormat',
  '2': [
    {'1': 'UNUSED', '2': 0},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_DisplayConfig_DisplayUnits$json = {
  '1': 'DisplayUnits',
  '2': [
    {'1': 'METRIC', '2': 0, '3': {}},
    {'1': 'IMPERIAL', '2': 1, '3': {}},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_DisplayConfig_OledType$json = {
  '1': 'OledType',
  '2': [
    {'1': 'OLED_AUTO', '2': 0, '3': {}},
    {'1': 'OLED_SSD1306', '2': 1, '3': {}},
    {'1': 'OLED_SH1106', '2': 2, '3': {}},
    {'1': 'OLED_SH1107', '2': 3, '3': {}},
    {'1': 'OLED_SH1107_128_128', '2': 4, '3': {}},
    {'1': 'OLED_SH1107_ROTATED', '2': 5, '3': {}},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_DisplayConfig_DisplayMode$json = {
  '1': 'DisplayMode',
  '2': [
    {'1': 'DEFAULT', '2': 0, '3': {}},
    {'1': 'TWOCOLOR', '2': 1, '3': {}},
    {'1': 'INVERTED', '2': 2, '3': {}},
    {'1': 'COLOR', '2': 3, '3': {}},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_DisplayConfig_CompassOrientation$json = {
  '1': 'CompassOrientation',
  '2': [
    {'1': 'DEGREES_0', '2': 0, '3': {}},
    {'1': 'DEGREES_90', '2': 1, '3': {}},
    {'1': 'DEGREES_180', '2': 2, '3': {}},
    {'1': 'DEGREES_270', '2': 3, '3': {}},
    {'1': 'DEGREES_0_INVERTED', '2': 4, '3': {}},
    {'1': 'DEGREES_90_INVERTED', '2': 5, '3': {}},
    {'1': 'DEGREES_180_INVERTED', '2': 6, '3': {}},
    {'1': 'DEGREES_270_INVERTED', '2': 7, '3': {}},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_LoRaConfig$json = {
  '1': 'LoRaConfig',
  '2': [
    {'1': 'use_preset', '3': 1, '4': 1, '5': 8, '8': {}, '10': 'usePreset'},
    {
      '1': 'modem_preset',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.LoRaConfig.ModemPreset',
      '8': {},
      '10': 'modemPreset'
    },
    {'1': 'bandwidth', '3': 3, '4': 1, '5': 13, '8': {}, '10': 'bandwidth'},
    {
      '1': 'spread_factor',
      '3': 4,
      '4': 1,
      '5': 13,
      '8': {},
      '10': 'spreadFactor'
    },
    {'1': 'coding_rate', '3': 5, '4': 1, '5': 13, '8': {}, '10': 'codingRate'},
    {'1': 'frequency_offset', '3': 6, '4': 1, '5': 2, '10': 'frequencyOffset'},
    {
      '1': 'region',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.LoRaConfig.RegionCode',
      '8': {},
      '10': 'region'
    },
    {'1': 'hop_limit', '3': 8, '4': 1, '5': 13, '8': {}, '10': 'hopLimit'},
    {'1': 'tx_enabled', '3': 9, '4': 1, '5': 8, '8': {}, '10': 'txEnabled'},
    {'1': 'tx_power', '3': 10, '4': 1, '5': 5, '8': {}, '10': 'txPower'},
    {'1': 'channel_num', '3': 11, '4': 1, '5': 13, '8': {}, '10': 'channelNum'},
    {
      '1': 'override_duty_cycle',
      '3': 12,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'overrideDutyCycle'
    },
    {
      '1': 'sx126x_rx_boosted_gain',
      '3': 13,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'sx126xRxBoostedGain'
    },
    {
      '1': 'override_frequency',
      '3': 14,
      '4': 1,
      '5': 2,
      '8': {},
      '10': 'overrideFrequency'
    },
    {
      '1': 'pa_fan_disabled',
      '3': 15,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'paFanDisabled'
    },
    {
      '1': 'ignore_incoming',
      '3': 103,
      '4': 3,
      '5': 13,
      '8': {},
      '10': 'ignoreIncoming'
    },
    {'1': 'ignore_mqtt', '3': 104, '4': 1, '5': 8, '8': {}, '10': 'ignoreMqtt'},
    {
      '1': 'config_ok_to_mqtt',
      '3': 105,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'configOkToMqtt'
    },
    {
      '1': 'fem_lna_mode',
      '3': 106,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.LoRaConfig.FEM_LNA_Mode',
      '8': {},
      '10': 'femLnaMode'
    },
    {'1': 'serial_hal_only', '3': 107, '4': 1, '5': 8, '10': 'serialHalOnly'},
    {
      '1': 'transparent_mode',
      '3': 108,
      '4': 1,
      '5': 8,
      '10': 'transparentMode'
    },
  ],
  '4': [
    Config_LoRaConfig_RegionCode$json,
    Config_LoRaConfig_ModemPreset$json,
    Config_LoRaConfig_FEM_LNA_Mode$json
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_LoRaConfig_RegionCode$json = {
  '1': 'RegionCode',
  '2': [
    {'1': 'UNSET', '2': 0, '3': {}},
    {'1': 'US', '2': 1, '3': {}},
    {'1': 'EU_433', '2': 2, '3': {}},
    {'1': 'EU_868', '2': 3, '3': {}},
    {'1': 'CN', '2': 4, '3': {}},
    {'1': 'JP', '2': 5, '3': {}},
    {'1': 'ANZ', '2': 6, '3': {}},
    {'1': 'KR', '2': 7, '3': {}},
    {'1': 'TW', '2': 8, '3': {}},
    {'1': 'RU', '2': 9, '3': {}},
    {'1': 'IN', '2': 10, '3': {}},
    {'1': 'NZ_865', '2': 11, '3': {}},
    {'1': 'TH', '2': 12, '3': {}},
    {'1': 'LORA_24', '2': 13, '3': {}},
    {'1': 'UA_433', '2': 14, '3': {}},
    {
      '1': 'UA_868',
      '2': 15,
      '3': {'1': true},
    },
    {'1': 'MY_433', '2': 16, '3': {}},
    {'1': 'MY_919', '2': 17, '3': {}},
    {'1': 'SG_923', '2': 18, '3': {}},
    {'1': 'PH_433', '2': 19, '3': {}},
    {'1': 'PH_868', '2': 20, '3': {}},
    {'1': 'PH_915', '2': 21, '3': {}},
    {'1': 'ANZ_433', '2': 22, '3': {}},
    {'1': 'KZ_433', '2': 23, '3': {}},
    {'1': 'KZ_863', '2': 24, '3': {}},
    {'1': 'NP_865', '2': 25, '3': {}},
    {'1': 'BR_902', '2': 26, '3': {}},
    {'1': 'ITU1_2M', '2': 27, '3': {}},
    {'1': 'ITU2_2M', '2': 28, '3': {}},
    {'1': 'EU_866', '2': 29, '3': {}},
    {'1': 'EU_874', '2': 30, '3': {}},
    {'1': 'EU_917', '2': 31, '3': {}},
    {'1': 'EU_N_868', '2': 32, '3': {}},
    {'1': 'ITU3_2M', '2': 33, '3': {}},
    {'1': 'ITU1_70CM', '2': 34, '3': {}},
    {'1': 'ITU2_70CM', '2': 35, '3': {}},
    {'1': 'ITU3_70CM', '2': 36, '3': {}},
    {'1': 'ITU2_125CM', '2': 37, '3': {}},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_LoRaConfig_ModemPreset$json = {
  '1': 'ModemPreset',
  '2': [
    {'1': 'LONG_FAST', '2': 0, '3': {}},
    {
      '1': 'LONG_SLOW',
      '2': 1,
      '3': {'1': true},
    },
    {
      '1': 'VERY_LONG_SLOW',
      '2': 2,
      '3': {'1': true},
    },
    {'1': 'MEDIUM_SLOW', '2': 3, '3': {}},
    {'1': 'MEDIUM_FAST', '2': 4, '3': {}},
    {'1': 'SHORT_SLOW', '2': 5, '3': {}},
    {'1': 'SHORT_FAST', '2': 6, '3': {}},
    {'1': 'LONG_MODERATE', '2': 7, '3': {}},
    {'1': 'SHORT_TURBO', '2': 8, '3': {}},
    {'1': 'LONG_TURBO', '2': 9, '3': {}},
    {'1': 'LITE_FAST', '2': 10, '3': {}},
    {'1': 'LITE_SLOW', '2': 11, '3': {}},
    {'1': 'NARROW_FAST', '2': 12, '3': {}},
    {'1': 'NARROW_SLOW', '2': 13, '3': {}},
    {'1': 'TINY_FAST', '2': 14, '3': {}},
    {'1': 'TINY_SLOW', '2': 15, '3': {}},
    {'1': 'MEDIUM_TURBO', '2': 16, '3': {}},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_LoRaConfig_FEM_LNA_Mode$json = {
  '1': 'FEM_LNA_Mode',
  '2': [
    {'1': 'DISABLED', '2': 0},
    {'1': 'ENABLED', '2': 1},
    {'1': 'NOT_PRESENT', '2': 2},
    {'1': 'AUTO', '2': 3},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_BluetoothConfig$json = {
  '1': 'BluetoothConfig',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '8': {}, '10': 'enabled'},
    {
      '1': 'mode',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.BluetoothConfig.PairingMode',
      '8': {},
      '10': 'mode'
    },
    {'1': 'fixed_pin', '3': 3, '4': 1, '5': 13, '8': {}, '10': 'fixedPin'},
  ],
  '4': [Config_BluetoothConfig_PairingMode$json],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_BluetoothConfig_PairingMode$json = {
  '1': 'PairingMode',
  '2': [
    {'1': 'RANDOM_PIN', '2': 0, '3': {}},
    {'1': 'FIXED_PIN', '2': 1, '3': {}},
    {'1': 'NO_PIN', '2': 2, '3': {}},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_SecurityConfig$json = {
  '1': 'SecurityConfig',
  '2': [
    {'1': 'public_key', '3': 1, '4': 1, '5': 12, '8': {}, '10': 'publicKey'},
    {'1': 'private_key', '3': 2, '4': 1, '5': 12, '8': {}, '10': 'privateKey'},
    {'1': 'admin_key', '3': 3, '4': 3, '5': 12, '8': {}, '10': 'adminKey'},
    {'1': 'is_managed', '3': 4, '4': 1, '5': 8, '8': {}, '10': 'isManaged'},
    {
      '1': 'serial_enabled',
      '3': 5,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'serialEnabled'
    },
    {
      '1': 'debug_log_api_enabled',
      '3': 6,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'debugLogApiEnabled'
    },
    {
      '1': 'admin_channel_enabled',
      '3': 8,
      '4': 1,
      '5': 8,
      '10': 'adminChannelEnabled'
    },
    {
      '1': 'packet_signature_policy',
      '3': 9,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.SecurityConfig.PacketSignaturePolicy',
      '8': {},
      '10': 'packetSignaturePolicy'
    },
  ],
  '4': [Config_SecurityConfig_PacketSignaturePolicy$json],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_SecurityConfig_PacketSignaturePolicy$json = {
  '1': 'PacketSignaturePolicy',
  '2': [
    {'1': 'PACKET_SIGNATURE_POLICY_COMPATIBLE', '2': 0, '3': {}},
    {'1': 'PACKET_SIGNATURE_POLICY_BALANCED', '2': 1, '3': {}},
    {'1': 'PACKET_SIGNATURE_POLICY_STRICT', '2': 2, '3': {}},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_SessionkeyConfig$json = {
  '1': 'SessionkeyConfig',
};

/// Descriptor for `Config`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List configDescriptor = $convert.base64Decode(
    'CgZDb25maWcSOQoGZGV2aWNlGAEgASgLMh8ubWVzaHRhc3RpYy5Db25maWcuRGV2aWNlQ29uZm'
    'lnSABSBmRldmljZRI/Cghwb3NpdGlvbhgCIAEoCzIhLm1lc2h0YXN0aWMuQ29uZmlnLlBvc2l0'
    'aW9uQ29uZmlnSABSCHBvc2l0aW9uEjYKBXBvd2VyGAMgASgLMh4ubWVzaHRhc3RpYy5Db25maW'
    'cuUG93ZXJDb25maWdIAFIFcG93ZXISPAoHbmV0d29yaxgEIAEoCzIgLm1lc2h0YXN0aWMuQ29u'
    'ZmlnLk5ldHdvcmtDb25maWdIAFIHbmV0d29yaxI8CgdkaXNwbGF5GAUgASgLMiAubWVzaHRhc3'
    'RpYy5Db25maWcuRGlzcGxheUNvbmZpZ0gAUgdkaXNwbGF5EjMKBGxvcmEYBiABKAsyHS5tZXNo'
    'dGFzdGljLkNvbmZpZy5Mb1JhQ29uZmlnSABSBGxvcmESQgoJYmx1ZXRvb3RoGAcgASgLMiIubW'
    'VzaHRhc3RpYy5Db25maWcuQmx1ZXRvb3RoQ29uZmlnSABSCWJsdWV0b290aBI/CghzZWN1cml0'
    'eRgIIAEoCzIhLm1lc2h0YXN0aWMuQ29uZmlnLlNlY3VyaXR5Q29uZmlnSABSCHNlY3VyaXR5Ek'
    'UKCnNlc3Npb25rZXkYCSABKAsyIy5tZXNodGFzdGljLkNvbmZpZy5TZXNzaW9ua2V5Q29uZmln'
    'SABSCnNlc3Npb25rZXkSOQoJZGV2aWNlX3VpGAogASgLMhoubWVzaHRhc3RpYy5EZXZpY2VVSU'
    'NvbmZpZ0gAUghkZXZpY2VVaRrBIAoMRGV2aWNlQ29uZmlnEksKBHJvbGUYASABKA4yJC5tZXNo'
    'dGFzdGljLkNvbmZpZy5EZXZpY2VDb25maWcuUm9sZUIRyvMYDToLRGV2aWNlIFJvbGVSBHJvbG'
    'USNAoOc2VyaWFsX2VuYWJsZWQYAiABKAhCDRgByvMYB1oFMi41LjBSDXNlcmlhbEVuYWJsZWQS'
    'gQEKC2J1dHRvbl9ncGlvGAQgASgNQmDK8xhcOgtCdXR0b24gR1BJT0JNR1BJTyBwaW4gZm9yIH'
    'RoZSB1c2VyIGJ1dHRvbiwgY2FuIGJlIHJlbWFwcGVkIG9uIGJvYXJkcyB3aXRoIG11bHRpcGxl'
    'IGJ1dHRvbnNSCmJ1dHRvbkdwaW8STwoLYnV6emVyX2dwaW8YBSABKA1CLsrzGCo6C0J1enplci'
    'BHUElPQhtHUElPIHBpbiBmb3IgdGhlIFBXTSBidXp6ZXJSCmJ1enplckdwaW8ScgoQcmVicm9h'
    'ZGNhc3RfbW9kZRgGIAEoDjIvLm1lc2h0YXN0aWMuQ29uZmlnLkRldmljZUNvbmZpZy5SZWJyb2'
    'FkY2FzdE1vZGVCFsrzGBI6EFJlYnJvYWRjYXN0IE1vZGVSD3JlYnJvYWRjYXN0TW9kZRKxAQoY'
    'bm9kZV9pbmZvX2Jyb2FkY2FzdF9zZWNzGAcgASgNQnjK8xh0GQAAAAAAIKxAKgFzOhxOb2RlIE'
    'luZm8gQnJvYWRjYXN0IEludGVydmFsQkhIb3cgb2Z0ZW4gbm9kZSBpbmZvcm1hdGlvbiBpcyBz'
    'ZW50LiBEZWZhdWx0cyB0byAzIGhvdXJzLCBtaW5pbXVtIDEgaG91ci5SFW5vZGVJbmZvQnJvYW'
    'RjYXN0U2VjcxKcAQoaZG91YmxlX3RhcF9hc19idXR0b25fcHJlc3MYCCABKAhCYMrzGFw6FERv'
    'dWJsZSBUYXAgYXMgQnV0dG9uQkRUcmVhdCBkb3VibGUgdGFwIG9uIHN1cHBvcnRlZCBhY2NlbG'
    'Vyb21ldGVycyBhcyBhIHVzZXIgYnV0dG9uIHByZXNzLlIWZG91YmxlVGFwQXNCdXR0b25QcmVz'
    'cxIsCgppc19tYW5hZ2VkGAkgASgIQg0YAcrzGAdaBTIuNS4wUglpc01hbmFnZWQSfQoUZGlzYW'
    'JsZV90cmlwbGVfY2xpY2sYCiABKAhCS8rzGEc6FERpc2FibGUgVHJpcGxlIENsaWNrQi9EaXNh'
    'YmxlcyB0aGUgdXNlciBidXR0b24gdHJpcGxlLXByZXNzIHNob3J0Y3V0LlISZGlzYWJsZVRyaX'
    'BsZUNsaWNrEkcKBXR6ZGVmGAsgASgJQjHK8xgtOglUaW1lIFpvbmVCIFBPU0lYIHRpbWV6b25l'
    'IGRlZmluaXRpb24gc3RyaW5nUgV0emRlZhLbAQoWbGVkX2hlYXJ0YmVhdF9kaXNhYmxlZBgMIA'
    'EoCEKkAcrzGJ8BOhVEaXNhYmxlIExFRCBIZWFydGJlYXRChQFUdXJucyBvZmYgdGhlIGJsaW5r'
    'aW5nIExFRCBvbiB0aGUgZGV2aWNlLiBPbiBtb3N0IGRldmljZXMgdGhpcyBpcyBvbmUgb2YgdX'
    'AgdG8gNCBMRURzOyB0aGUgY2hhcmdlciBhbmQgR1BTIExFRHMgYXJlIG5vdCBjb250cm9sbGFi'
    'bGUuUhRsZWRIZWFydGJlYXREaXNhYmxlZBJYCgtidXp6ZXJfbW9kZRgNIAEoDjIqLm1lc2h0YX'
    'N0aWMuQ29uZmlnLkRldmljZUNvbmZpZy5CdXp6ZXJNb2RlQgvK8xgHUgUyLjcuMFIKYnV6emVy'
    'TW9kZSL/CwoEUm9sZRJHCgZDTElFTlQQABo7yvMYNzoGQ2xpZW50Qi1BcHAgY29ubmVjdGVkIG'
    '9yIHN0YW5kYWxvbmUgbWVzc2FnaW5nIGRldmljZS4SXAoLQ0xJRU5UX01VVEUQARpLyvMYRzoL'
    'Q2xpZW50IE11dGVCOERldmljZSB0aGF0IGRvZXMgbm90IGZvcndhcmQgcGFja2V0cyBmcm9tIG'
    '90aGVyIGRldmljZXMuEq4BCgZST1VURVIQAhqhAcrzGJwBOgZSb3V0ZXJCkQFJbmZyYXN0cnVj'
    'dHVyZSBub2RlIG9uIGEgdG93ZXIgb3IgbW91bnRhaW4gdG9wIG9ubHkuIE5vdCB0byBiZSB1c2'
    'VkIGZvciByb29mcyBvciBtb2JpbGUgbm9kZXMuIE5lZWRzIGV4Y2VwdGlvbmFsIGNvdmVyYWdl'
    'LiBWaXNpYmxlIGluIE5vZGVzIGxpc3QuEjAKDVJPVVRFUl9DTElFTlQQAxodCAHK8xgXOg1Sb3'
    'V0ZXIgQ2xpZW50WgYyLjMuMTUSuwEKCFJFUEVBVEVSEAQarAEIAcrzGKUBOghSZXBlYXRlckKQ'
    'AURlcHJlY2F0ZWQgaW5mcmFzdHJ1Y3R1cmUgcm9sZSB0aGF0IGNyZWF0ZXMgZ2FwcyBpbiB0aG'
    'UgbWVzaCByZWJyb2FkY2FzdCBjaGFpbi4gU3dpdGNoIHRoaXMgbm9kZSB0byBhIFJvdXRlci1i'
    'YXNlZCByb2xlIChSb3V0ZXIgb3IgUm91dGVyIExhdGUpLloGMi43LjExEkgKB1RSQUNLRVIQBR'
    'o7yvMYNzoHVHJhY2tlckIsQnJvYWRjYXN0cyBHUFMgcG9zaXRpb24gcGFja2V0cyBhcyBwcmlv'
    'cml0eS4SQwoGU0VOU09SEAYaN8rzGDM6BlNlbnNvckIpQnJvYWRjYXN0cyB0ZWxlbWV0cnkgcG'
    'Fja2V0cyBhcyBwcmlvcml0eS4SWAoDVEFLEAcaT8rzGEs6A1RBS0JET3B0aW1pemVkIGZvciBB'
    'VEFLIHN5c3RlbSBjb21tdW5pY2F0aW9uLCByZWR1Y2VzIHJvdXRpbmUgYnJvYWRjYXN0cy4Saw'
    'oNQ0xJRU5UX0hJRERFThAIGljK8xhUOg1DbGllbnQgSGlkZGVuQkNEZXZpY2UgdGhhdCBvbmx5'
    'IGJyb2FkY2FzdHMgYXMgbmVlZGVkIGZvciBzdGVhbHRoIG9yIHBvd2VyIHNhdmluZ3MuEoUBCg'
    '5MT1NUX0FORF9GT1VORBAJGnHK8xhtOg5Mb3N0IGFuZCBGb3VuZEJbQnJvYWRjYXN0cyBsb2Nh'
    'dGlvbiBhcyBtZXNzYWdlIHRvIGRlZmF1bHQgY2hhbm5lbCByZWd1bGFybHkgdG8gYXNzaXN0IH'
    'dpdGggZGV2aWNlIHJlY292ZXJ5LhJoCgtUQUtfVFJBQ0tFUhAKGlfK8xhTOgtUQUsgVHJhY2tl'
    'ckJERW5hYmxlcyBhdXRvbWF0aWMgVEFLIFBMSSBicm9hZGNhc3RzIGFuZCByZWR1Y2VzIHJvdX'
    'RpbmUgYnJvYWRjYXN0cy4SvAEKC1JPVVRFUl9MQVRFEAsaqgHK8xilAToLUm91dGVyIExhdGVC'
    'lQFJbmZyYXN0cnVjdHVyZSBub2RlIHRoYXQgYWx3YXlzIHJlYnJvYWRjYXN0cyBwYWNrZXRzIG'
    '9uY2UgYnV0IG9ubHkgYWZ0ZXIgYWxsIG90aGVyIG1vZGVzLiBWaXNpYmxlIGluIE5vZGVzIGxp'
    'c3QuIE5vdCBhIGdvb2QgY2hvaWNlIGZvciByb29mdG9wIG5vZGVzLhKnAQoLQ0xJRU5UX0JBU0'
    'UQDBqVAcrzGJABOgtDbGllbnQgQmFzZUKAAVJvb2Z0b3Agb3IgYXR0aWMgbm9kZSB0aGF0IHJl'
    'YnJvYWRjYXN0cyBsaWtlIFJvdXRlciBMYXRlIGZvciBwYWNrZXRzIGZyb20gb3IgdG8gZmF2b3'
    'JpdGVkIG5vZGVzLCBhbmQgbGlrZSBDbGllbnQgZm9yIGFsbCBvdGhlcnMuIvYICg9SZWJyb2Fk'
    'Y2FzdE1vZGUSjAEKA0FMTBAAGoIByvMYfjoDQWxsQndSZWJyb2FkY2FzdCBhbnkgb2JzZXJ2ZW'
    'QgbWVzc2FnZSwgaWYgaXQgd2FzIG9uIG91ciBwcml2YXRlIGNoYW5uZWwgb3IgZnJvbSBhbm90'
    'aGVyIGNoYW5uZWwgd2l0aCB0aGUgc2FtZSBMb1JhIHNldHRpbmdzLhKaAQoRQUxMX1NLSVBfRE'
    'VDT0RJTkcQARqCAcrzGH46EUFsbCBTa2lwIERlY29kaW5nQmlCZWhhdmVzIGFzIEFsbC4gU2tp'
    'cHBpbmcgcGFja2V0IGRlY29kaW5nIGFwcGxpZWQgb25seSB0byB0aGUgUmVwZWF0ZXIgcm9sZS'
    'wgd2hpY2ggaXMgbm8gbG9uZ2VyIHN1cHBvcnRlZC4SzwEKCkxPQ0FMX09OTFkQAhq+AcrzGLkB'
    'OgpMb2NhbCBPbmx5QqoBSWdub3JlcyBvYnNlcnZlZCBtZXNzYWdlcyBmcm9tIGZvcmVpZ24gbW'
    'VzaGVzIHRoYXQgYXJlIG9wZW4gb3IgdGhvc2Ugd2hpY2ggaXQgY2Fubm90IGRlY3J5cHQuIE9u'
    'bHkgcmVicm9hZGNhc3RzIG1lc3NhZ2VzIG9uIHRoZSBub2RlJ3MgbG9jYWwgcHJpbWFyeSAvIH'
    'NlY29uZGFyeSBjaGFubmVscy4SygEKCktOT1dOX09OTFkQAxq5AcrzGLQBOgpLbm93biBPbmx5'
    'QqUBSWdub3JlcyBvYnNlcnZlZCBtZXNzYWdlcyBmcm9tIGZvcmVpZ24gbWVzaGVzIGxpa2UgTG'
    '9jYWwgT25seSwgYnV0IHRha2VzIGl0IGEgc3RlcCBmdXJ0aGVyIGJ5IGFsc28gaWdub3Jpbmcg'
    'bWVzc2FnZXMgZnJvbSBub2RlcyBub3QgYWxyZWFkeSBpbiB0aGUgbm9kZSdzIGtub3duIGxpc3'
    'QuEnwKBE5PTkUQBBpyyvMYbjoETm9uZUJmSW5oaWJpdHMgYWxsIHJlYnJvYWRjYXN0cywgbGlr'
    'ZSB0aGUgQ2xpZW50IE11dGUgcm9sZS4gTm90IGFsbG93ZWQgb24gdGhlIFJvdXRlciBhbmQgUm'
    '91dGVyIExhdGUgcm9sZXMuEpkCChJDT1JFX1BPUlROVU1TX09OTFkQBRqAAsrzGPsBOhJDb3Jl'
    'IFBvcnRudW1zIE9ubHlC5AFJZ25vcmVzIHBhY2tldHMgb24gbm9uLWNvcmUgcG9ydG51bXMgc3'
    'VjaCBhcyBSYW5nZSBUZXN0LCBQQVggQ291bnRlciBhbmQgQVRBSywgYW5kIGRvZXMgbm90IHJl'
    'YnJvYWRjYXN0IHRoZW0uIENvcmUgcG9ydG51bXMgaW5jbHVkZSBUZXh0LCBQb3NpdGlvbiwgTm'
    '9kZUluZm8sIFRlbGVtZXRyeSwgUm91dGluZywgQWRtaW4sIFdheXBvaW50LCBUcmFjZXJvdXRl'
    'IGFuZCBTdG9yZSBhbmQgRm9yd2FyZC4iaQoKQnV6emVyTW9kZRIPCgtBTExfRU5BQkxFRBAAEg'
    'wKCERJU0FCTEVEEAESFgoSTk9USUZJQ0FUSU9OU19PTkxZEAISDwoLU1lTVEVNX09OTFkQAxIT'
    'Cg9ESVJFQ1RfTVNHX09OTFkQBBqcEQoOUG9zaXRpb25Db25maWcSkAEKF3Bvc2l0aW9uX2Jyb2'
    'FkY2FzdF9zZWNzGAEgASgNQljK8xhUKgFzOhJCcm9hZGNhc3QgSW50ZXJ2YWxCO1RoZSBsb25n'
    'ZXN0IGEgbm9kZSB3aWxsIGdvIHdpdGhvdXQgYnJvYWRjYXN0aW5nIGEgcG9zaXRpb24uUhVwb3'
    'NpdGlvbkJyb2FkY2FzdFNlY3MSXQogcG9zaXRpb25fYnJvYWRjYXN0X3NtYXJ0X2VuYWJsZWQY'
    'AiABKAhCFMrzGBA6DlNtYXJ0IFBvc2l0aW9uUh1wb3NpdGlvbkJyb2FkY2FzdFNtYXJ0RW5hYm'
    'xlZBLBAQoOZml4ZWRfcG9zaXRpb24YAyABKAhCmQHK8xiUAToORml4ZWQgUG9zaXRpb25CgQFU'
    'aGUgbGFzdCBrbm93biBsYXRpdHVkZSwgbG9uZ2l0dWRlIGFuZCBhbHRpdHVkZSBhcmUgYnJvYW'
    'RjYXN0IG92ZXIgdGhlIG1lc2ggb24gdGhlIHBvc2l0aW9uIGludGVydmFsLCByYXRoZXIgdGhh'
    'biBhIGxpdmUgR1BTIGZpeC5SDWZpeGVkUG9zaXRpb24SLwoLZ3BzX2VuYWJsZWQYBCABKAhCDh'
    'gByvMYCFoGMi4yLjIxUgpncHNFbmFibGVkEnEKE2dwc191cGRhdGVfaW50ZXJ2YWwYBSABKA1C'
    'QcrzGD0qAXM6D1VwZGF0ZSBJbnRlcnZhbEInSG93IG9mdGVuIHRvIHRyeSB0byBnZXQgYSBHUF'
    'MgcG9zaXRpb24uUhFncHNVcGRhdGVJbnRlcnZhbBI4ChBncHNfYXR0ZW1wdF90aW1lGAYgASgN'
    'Qg4YAcrzGAhaBjIuMi4xOFIOZ3BzQXR0ZW1wdFRpbWUSeQoOcG9zaXRpb25fZmxhZ3MYByABKA'
    '1CUsrzGE46DlBvc2l0aW9uIEZsYWdzQjxPcHRpb25hbCBmaWVsZHMgdG8gaW5jbHVkZSB3aGVu'
    'IGFzc2VtYmxpbmcgcG9zaXRpb24gbWVzc2FnZXNSDXBvc2l0aW9uRmxhZ3MSRgoHcnhfZ3Bpbx'
    'gIIAEoDUItyvMYKQgBOhBHUFMgUmVjZWl2ZSBHUElPQhNHUElPIHBpbiBmb3IgR1BTIFJYUgZy'
    'eEdwaW8SRwoHdHhfZ3BpbxgJIAEoDUIuyvMYKggBOhFHUFMgVHJhbnNtaXQgR1BJT0ITR1BJTy'
    'BwaW4gZm9yIEdQUyBUWFIGdHhHcGlvErMBCiBicm9hZGNhc3Rfc21hcnRfbWluaW11bV9kaXN0'
    'YW5jZRgKIAEoDUJqyvMYZioBbToQTWluaW11bSBEaXN0YW5jZUJPVGhlIG1pbmltdW0gY2hhbm'
    'dlIGluIGRpc3RhbmNlIGJlZm9yZSBhIHNtYXJ0IHBvc2l0aW9uIGJyb2FkY2FzdCBpcyBjb25z'
    'aWRlcmVkLlIdYnJvYWRjYXN0U21hcnRNaW5pbXVtRGlzdGFuY2USwwEKJWJyb2FkY2FzdF9zbW'
    'FydF9taW5pbXVtX2ludGVydmFsX3NlY3MYCyABKA1CccrzGG0qAXM6EE1pbmltdW0gSW50ZXJ2'
    'YWxCVlRoZSBzaG9ydGVzdCBpbnRlcnZhbCBiZXR3ZWVuIHBvc2l0aW9uIHVwZGF0ZXMgb25jZS'
    'B0aGUgbWluaW11bSBkaXN0YW5jZSBoYXMgYmVlbiBtZXQuUiFicm9hZGNhc3RTbWFydE1pbmlt'
    'dW1JbnRlcnZhbFNlY3MSUAoLZ3BzX2VuX2dwaW8YDCABKA1CMMrzGCwIAToPR1BTIEVuYWJsZS'
    'BHUElPQhdHUElPIHBpbiBmb3IgR1BTIGVuYWJsZVIJZ3BzRW5HcGlvElQKCGdwc19tb2RlGA0g'
    'ASgOMikubWVzaHRhc3RpYy5Db25maWcuUG9zaXRpb25Db25maWcuR3BzTW9kZUIOyvMYCjoIR1'
    'BTIE1vZGVSB2dwc01vZGUi3AQKDVBvc2l0aW9uRmxhZ3MSCQoFVU5TRVQQABJjCghBTFRJVFVE'
    'RRABGlXK8xhROghBbHRpdHVkZUJFSW5jbHVkZSBhbiBhbHRpdHVkZSB2YWx1ZSBpbiBwb3NpdG'
    'lvbiByZXBvcnRzLCB3aGVuIG9uZSBpcyBhdmFpbGFibGUuEjIKDEFMVElUVURFX01TTBACGiDK'
    '8xgcOhpBbHRpdHVkZSBpcyBNZWFuIFNlYSBMZXZlbBI5ChJHRU9JREFMX1NFUEFSQVRJT04QBB'
    'ohyvMYHTobQWx0aXR1ZGUgR2VvaWRhbCBTZXBhcmF0aW9uElUKA0RPUBAIGkzK8xhIOgNET1BC'
    'QUluY2x1ZGUgdGhlIGRpbHV0aW9uIG9mIHByZWNpc2lvbiB2YWx1ZS4gUERPUCBpcyB1c2VkIG'
    'J5IGRlZmF1bHQuEmAKBUhWRE9QEBAaVcrzGFE6C0hET1AgLyBWRE9QQkJJZiBET1AgaXMgc2V0'
    'LCBzZW5kIHNlcGFyYXRlIEhET1AgYW5kIFZET1AgdmFsdWVzIGluc3RlYWQgb2YgUERPUC4SKQ'
    'oJU0FUSU5WSUVXECAaGsrzGBY6FE51bWJlciBvZiBzYXRlbGxpdGVzEiEKBlNFUV9OTxBAGhXK'
    '8xgROg9TZXF1ZW5jZSBudW1iZXISHwoJVElNRVNUQU1QEIABGg/K8xgLOglUaW1lc3RhbXASIw'
    'oHSEVBRElORxCAAhoVyvMYEToPVmVoaWNsZSBoZWFkaW5nEh8KBVNQRUVEEIAEGhPK8xgPOg1W'
    'ZWhpY2xlIHNwZWVkImcKB0dwc01vZGUSHAoIRElTQUJMRUQQABoOyvMYCjoIRGlzYWJsZWQSGg'
    'oHRU5BQkxFRBABGg3K8xgJOgdFbmFibGVkEiIKC05PVF9QUkVTRU5UEAIaEcrzGA06C05vdCBQ'
    'cmVzZW50Gr4KCgtQb3dlckNvbmZpZxKkAgoPaXNfcG93ZXJfc2F2aW5nGAEgASgIQvsByvMY9g'
    'E6DFBvd2VyIFNhdmluZ0LlAVdpbGwgc2xlZXAgZXZlcnl0aGluZyBhcyBtdWNoIGFzIHBvc3Np'
    'YmxlLCBmb3IgdGhlIFRyYWNrZXIgYW5kIFNlbnNvciByb2xlcyB0aGlzIGFsc28gaW5jbHVkZX'
    'MgdGhlIExvUmEgcmFkaW8uIERvbid0IHVzZSB0aGlzIHNldHRpbmcgaWYgeW91IHdhbnQgdG8g'
    'dXNlIHlvdXIgZGV2aWNlIHdpdGggdGhlIHBob25lIGFwcHMgb3IgYXJlIHVzaW5nIGEgZGV2aW'
    'NlIHdpdGhvdXQgYSB1c2VyIGJ1dHRvbi5SDWlzUG93ZXJTYXZpbmcS6QEKHm9uX2JhdHRlcnlf'
    'c2h1dGRvd25fYWZ0ZXJfc2VjcxgCIAEoDUKkAcrzGJ8BKgFzOhZTaHV0ZG93biBvbiBQb3dlci'
    'BMb3NzQoEBSG93IGxvbmcgYWZ0ZXIgZXh0ZXJuYWwgcG93ZXIgaXMgcmVtb3ZlZCBiZWZvcmUg'
    'dGhlIGRldmljZSBwb3dlcnMgb2ZmLiBaZXJvIHRvIGRpc2FibGU7IHZhbHVlcyB1bmRlciAzMC'
    'BzZWNvbmRzIGFyZSByYWlzZWQgdG8gMzAuUhpvbkJhdHRlcnlTaHV0ZG93bkFmdGVyU2VjcxJK'
    'ChdhZGNfbXVsdGlwbGllcl9vdmVycmlkZRgDIAEoAkISyvMYDjoMQURDIE92ZXJyaWRlUhVhZG'
    'NNdWx0aXBsaWVyT3ZlcnJpZGUSVAoTd2FpdF9ibHVldG9vdGhfc2VjcxgEIAEoDUIkyvMYICoB'
    'czobV2FpdCBmb3IgQmx1ZXRvb3RoIER1cmF0aW9uUhF3YWl0Qmx1ZXRvb3RoU2VjcxLJAQoIc2'
    'RzX3NlY3MYBiABKA1CrQHK8xioASoBczoZU3VwZXIgRGVlcCBTbGVlcCBEdXJhdGlvbkKHAUhv'
    'dyBsb25nIHRoZSByYWRpbyBzdGF5cyBpbiBzdXBlciBkZWVwIHNsZWVwIGJlZm9yZSB3YWtpbm'
    'csIHVubGVzcyB0aGUgYnV0dG9uIGlzIHByZXNzZWQuIFplcm8gbGVhdmVzIHRoZSBmaXJtd2Fy'
    'ZSBkZWZhdWx0IG9mIG9uZSB5ZWFyLlIHc2RzU2VjcxIXCgdsc19zZWNzGAcgASgNUgZsc1NlY3'
    'MSxwEKDW1pbl93YWtlX3NlY3MYCCABKA1CogHK8xidASoBczoRTWluaW11bSBXYWtlIFRpbWVC'
    'hAFIb3cgbG9uZyB0aGUgcmFkaW8gc3RheXMgYXdha2UgYWZ0ZXIgaGFuZGxpbmcgYSBwYWNrZX'
    'QgcmVjZWl2ZWQgZHVyaW5nIGxpZ2h0IHNsZWVwLiBaZXJvIGxlYXZlcyB0aGUgZmlybXdhcmUg'
    'ZGVmYXVsdCBvZiB0ZW4gc2Vjb25kcy5SC21pbldha2VTZWNzEp8BChpkZXZpY2VfYmF0dGVyeV'
    '9pbmFfYWRkcmVzcxgJIAEoDUJiyvMYXjobQmF0dGVyeSBJTkFfMlhYIEkyQyBBZGRyZXNzQj9J'
    'MkMgYWRkcmVzcyBvZiB0aGUgSU5BXzJYWCBzZW5zb3IgdXNlZCB0byByZWFkIGJhdHRlcnkgdm'
    '9sdGFnZS5SF2RldmljZUJhdHRlcnlJbmFBZGRyZXNzEikKEHBvd2VybW9uX2VuYWJsZXMYICAB'
    'KARSD3Bvd2VybW9uRW5hYmxlcxrxCQoNTmV0d29ya0NvbmZpZxJ2Cgx3aWZpX2VuYWJsZWQYAS'
    'ABKAhCU8rzGE86DFdpRmkgRW5hYmxlZEI/RW5hYmxpbmcgV2lGaSB3aWxsIGRpc2FibGUgdGhl'
    'IEJsdWV0b290aCBjb25uZWN0aW9uIHRvIHRoZSBhcHAuUgt3aWZpRW5hYmxlZBJICgl3aWZpX3'
    'NzaWQYAyABKAlCK8rzGCc6BFNTSURCH1dpRmkgbmV0d29yayBuYW1lIHRvIGNvbm5lY3QgdG9S'
    'CHdpZmlTc2lkEk0KCHdpZmlfcHNrGAQgASgJQjLK8xguOghQYXNzd29yZEIgV2lGaSBwYXNzd2'
    '9yZCBmb3IgYXV0aGVudGljYXRpb25oAVIHd2lmaVBzaxJoCgpudHBfc2VydmVyGAUgASgJQknK'
    '8xhFOgpOVFAgU2VydmVyQjdOVFAgc2VydmVyIGFkZHJlc3MuIERlZmF1bHRzIHRvIG1lc2h0YX'
    'N0aWMucG9vbC5udHAub3JnUgludHBTZXJ2ZXISjQEKC2V0aF9lbmFibGVkGAYgASgIQmzK8xho'
    'OhBFdGhlcm5ldCBFbmFibGVkQlRPbiBFU1AzMiBib2FyZHMsIGVuYWJsaW5nIEV0aGVybmV0IH'
    'dpbGwgZGlzYWJsZSB0aGUgQmx1ZXRvb3RoIGNvbm5lY3Rpb24gdG8gdGhlIGFwcC5SCmV0aEVu'
    'YWJsZWQSYwoMYWRkcmVzc19tb2RlGAcgASgOMiwubWVzaHRhc3RpYy5Db25maWcuTmV0d29ya0'
    'NvbmZpZy5BZGRyZXNzTW9kZUISyvMYDjoMQWRkcmVzcyBNb2RlUgthZGRyZXNzTW9kZRJMCgtp'
    'cHY0X2NvbmZpZxgIIAEoCzIrLm1lc2h0YXN0aWMuQ29uZmlnLk5ldHdvcmtDb25maWcuSXBWNE'
    'NvbmZpZ1IKaXB2NENvbmZpZxI7Cg5yc3lzbG9nX3NlcnZlchgJIAEoCUIUyvMYEDoOUnN5c2xv'
    'ZyBTZXJ2ZXJSDXJzeXNsb2dTZXJ2ZXISiAEKEWVuYWJsZWRfcHJvdG9jb2xzGAogASgNQlvK8x'
    'hXOhFFbmFibGVkIFByb3RvY29sc0I7RW5hYmxlIGJyb2FkY2FzdGluZyBwYWNrZXRzIHZpYSBV'
    'RFAgb3ZlciB0aGUgbG9jYWwgbmV0d29yay5SBTIuNi4wUhBlbmFibGVkUHJvdG9jb2xzEi8KDG'
    'lwdjZfZW5hYmxlZBgLIAEoCEIMyvMYCFIGMi43LjE2UgtpcHY2RW5hYmxlZBqSAQoKSXBWNENv'
    'bmZpZxIYCgJpcBgBIAEoB0IIyvMYBDoCSVBSAmlwEicKB2dhdGV3YXkYAiABKAdCDcrzGAk6B0'
    'dhdGV3YXlSB2dhdGV3YXkSJAoGc3VibmV0GAMgASgHQgzK8xgIOgZTdWJuZXRSBnN1Ym5ldBIb'
    'CgNkbnMYBCABKAdCCcrzGAU6A0ROU1IDZG5zIj0KC0FkZHJlc3NNb2RlEhQKBERIQ1AQABoKyv'
    'MYBjoEREhDUBIYCgZTVEFUSUMQARoMyvMYCDoGU3RhdGljIlUKDVByb3RvY29sRmxhZ3MSHAoM'
    'Tk9fQlJPQURDQVNUEAAaCsrzGAY6BE5vbmUSJgoNVURQX0JST0FEQ0FTVBABGhPK8xgPOg1VRF'
    'AgQnJvYWRjYXN0GvAVCg1EaXNwbGF5Q29uZmlnEpcBCg5zY3JlZW5fb25fc2VjcxgBIAEoDUJx'
    'yvMYbSoBczoNU2NyZWVuIG9uIGZvckJZSG93IGxvbmcgdGhlIHNjcmVlbiByZW1haW5zIG9uIG'
    'FmdGVyIHRoZSB1c2VyIGJ1dHRvbiBpcyBwcmVzc2VkIG9yIG1lc3NhZ2VzIGFyZSByZWNlaXZl'
    'ZC5SDHNjcmVlbk9uU2VjcxJtCgpncHNfZm9ybWF0GAIgASgOMj4ubWVzaHRhc3RpYy5Db25maW'
    'cuRGlzcGxheUNvbmZpZy5EZXByZWNhdGVkR3BzQ29vcmRpbmF0ZUZvcm1hdEIOGAHK8xgIWgYy'
    'LjcuMTBSCWdwc0Zvcm1hdBKmAQoZYXV0b19zY3JlZW5fY2Fyb3VzZWxfc2VjcxgDIAEoDUJryv'
    'MYZyoBczoRQ2Fyb3VzZWwgSW50ZXJ2YWxCT0F1dG9tYXRpY2FsbHkgbW92ZXMgdG8gdGhlIG5l'
    'eHQgc2NyZWVuIHBhZ2UsIGxpa2UgYSBjYXJvdXNlbCwgb24gdGhpcyBpbnRlcnZhbC5SFmF1dG'
    '9TY3JlZW5DYXJvdXNlbFNlY3MSnwEKEWNvbXBhc3Nfbm9ydGhfdG9wGAQgASgIQnMYAcrzGG06'
    'EkFsd2F5cyBwb2ludCBub3J0aEJQVGhlIGNvbXBhc3MgaGVhZGluZyBvbiB0aGUgc2NyZWVuIG'
    '91dHNpZGUgb2YgdGhlIGNpcmNsZSB3aWxsIGFsd2F5cyBwb2ludCBub3J0aC5aBTIuNy4xUg9j'
    'b21wYXNzTm9ydGhUb3ASSgoLZmxpcF9zY3JlZW4YBSABKAhCKcrzGCU6C0ZsaXAgU2NyZWVuQh'
    'ZGbGlwIHNjcmVlbiB2ZXJ0aWNhbGx5UgpmbGlwU2NyZWVuEnsKBXVuaXRzGAYgASgOMi0ubWVz'
    'aHRhc3RpYy5Db25maWcuRGlzcGxheUNvbmZpZy5EaXNwbGF5VW5pdHNCNsrzGDI6DURpc3BsYX'
    'kgVW5pdHNCIVVuaXRzIHNob3duIG9uIHRoZSBkZXZpY2Ugc2NyZWVuLlIFdW5pdHMSeQoEb2xl'
    'ZBgHIAEoDjIpLm1lc2h0YXN0aWMuQ29uZmlnLkRpc3BsYXlDb25maWcuT2xlZFR5cGVCOsrzGD'
    'Y6CU9MRUQgVHlwZUIpT3ZlcnJpZGUgYXV0b21hdGljIE9MRUQgc2NyZWVuIGRldGVjdGlvbi5S'
    'BG9sZWQSgwEKC2Rpc3BsYXltb2RlGAggASgOMiwubWVzaHRhc3RpYy5Db25maWcuRGlzcGxheU'
    'NvbmZpZy5EaXNwbGF5TW9kZUIzyvMYLzoMRGlzcGxheSBNb2RlQh9PdmVycmlkZSBkZWZhdWx0'
    'IHNjcmVlbiBsYXlvdXQuUgtkaXNwbGF5bW9kZRJbCgxoZWFkaW5nX2JvbGQYCSABKAhCOMrzGD'
    'Q6DEJvbGQgSGVhZGluZ0IkQm9sZCB0aGUgaGVhZGluZyB0ZXh0IG9uIHRoZSBzY3JlZW4uUgto'
    'ZWFkaW5nQm9sZBKNAQoVd2FrZV9vbl90YXBfb3JfbW90aW9uGAogASgIQlvK8xhXOhxXYWtlIF'
    'NjcmVlbiBvbiB0YXAgb3IgbW90aW9uQjdSZXF1aXJlcyB0aGF0IHRoZXJlIGJlIGFuIGFjY2Vs'
    'ZXJvbWV0ZXIgb24geW91ciBkZXZpY2UuUhF3YWtlT25UYXBPck1vdGlvbhLLAQoTY29tcGFzc1'
    '9vcmllbnRhdGlvbhgLIAEoDjIzLm1lc2h0YXN0aWMuQ29uZmlnLkRpc3BsYXlDb25maWcuQ29t'
    'cGFzc09yaWVudGF0aW9uQmXK8xhhOhNDb21wYXNzIE9yaWVudGF0aW9uQkpJbmRpY2F0ZXMgaG'
    '93IHRvIHJvdGF0ZSBvciBpbnZlcnQgdGhlIGNvbXBhc3Mgb3V0cHV0IGZvciBhY2N1cmF0ZSBk'
    'aXNwbGF5LlISY29tcGFzc09yaWVudGF0aW9uEmkKDXVzZV8xMmhfY2xvY2sYDCABKAhCRcrzGE'
    'E6DTEyIEhvdXIgQ2xvY2tCKFNldHMgdGhlIHNjcmVlbiBjbG9jayBmb3JtYXQgdG8gMTItaG91'
    'ci5SBjIuNS4yMlILdXNlMTJoQ2xvY2sSjQEKEnVzZV9sb25nX25vZGVfbmFtZRgNIAEoCEJgyv'
    'MYXDoPTG9uZyBOb2RlIE5hbWVzQkFTaG93IGZ1bGwgbm9kZSBuYW1lcyBvbiB0aGUgZGV2aWNl'
    'IHNjcmVlbiBpbnN0ZWFkIG9mIHNob3J0IG5hbWVzLlIGMi43LjEzUg91c2VMb25nTm9kZU5hbW'
    'USgwEKFmVuYWJsZV9tZXNzYWdlX2J1YmJsZXMYDiABKAhCTcrzGEk6D01lc3NhZ2UgQnViYmxl'
    'c0IuRHJhdyBtZXNzYWdlcyBvbiB0aGUgZGV2aWNlIHNjcmVlbiBhcyBidWJibGVzLlIGMi43Lj'
    'E5UhRlbmFibGVNZXNzYWdlQnViYmxlcyIrCh1EZXByZWNhdGVkR3BzQ29vcmRpbmF0ZUZvcm1h'
    'dBIKCgZVTlVTRUQQACJGCgxEaXNwbGF5VW5pdHMSGAoGTUVUUklDEAAaDMrzGAg6Bk1ldHJpYx'
    'IcCghJTVBFUklBTBABGg7K8xgKOghJbXBlcmlhbCLyAQoIT2xlZFR5cGUSKQoJT0xFRF9BVVRP'
    'EAAaGsrzGBY6FERldGVjdCBBdXRvbWF0aWNhbGx5Eh8KDE9MRURfU1NEMTMwNhABGg3K8xgJOg'
    'dTU0QxMzA2Eh0KC09MRURfU0gxMTA2EAIaDMrzGAg6BlNIMTEwNhIdCgtPTEVEX1NIMTEwNxAD'
    'GgzK8xgIOgZTSDExMDcSLQoTT0xFRF9TSDExMDdfMTI4XzEyOBAEGhTK8xgQOg5TSDExMDcgMT'
    'I4eDEyOBItChNPTEVEX1NIMTEwN19ST1RBVEVEEAUaFMrzGBA6DlNIMTEwNyBSb3RhdGVkItcB'
    'CgtEaXNwbGF5TW9kZRIvCgdERUZBVUxUEAAaIsrzGB46HERlZmF1bHQgMTI4eDY0IHNjcmVlbi'
    'BsYXlvdXQSMgoIVFdPQ09MT1IQARokyvMYIDoeT3B0aW1pemVkIGZvciAyIGNvbG9yIGRpc3Bs'
    'YXlzEjkKCElOVkVSVEVEEAIaK8rzGCc6JUludmVydGVkIHRvcCBiYXIgZm9yIDIgY29sb3IgZG'
    'lzcGxheXMSKAoFQ09MT1IQAxodyvMYGToXVEZUIEZ1bGwgQ29sb3IgRGlzcGxheXMiwAIKEkNv'
    'bXBhc3NPcmllbnRhdGlvbhIYCglERUdSRUVTXzAQABoJyvMYBToDMMKwEhoKCkRFR1JFRVNfOT'
    'AQARoKyvMYBjoEOTDCsBIcCgtERUdSRUVTXzE4MBACGgvK8xgHOgUxODDCsBIcCgtERUdSRUVT'
    'XzI3MBADGgvK8xgHOgUyNzDCsBIqChJERUdSRUVTXzBfSU5WRVJURUQQBBoSyvMYDjoMMMKwIE'
    'ludmVydGVkEiwKE0RFR1JFRVNfOTBfSU5WRVJURUQQBRoTyvMYDzoNOTDCsCBJbnZlcnRlZBIu'
    'ChRERUdSRUVTXzE4MF9JTlZFUlRFRBAGGhTK8xgQOg4xODDCsCBJbnZlcnRlZBIuChRERUdSRU'
    'VTXzI3MF9JTlZFUlRFRBAHGhTK8xgQOg4yNzDCsCBJbnZlcnRlZBrbIwoKTG9SYUNvbmZpZxKL'
    'AQoKdXNlX3ByZXNldBgBIAEoCEJsyvMYaDoKVXNlIFByZXNldEJaVXNlIHRoZSBtb2RlbSBwcm'
    'VzZXQgc2V0dGluZ3MgaW5zdGVhZCBvZiBhIG1hbnVhbCBiYW5kd2lkdGgsIHNwcmVhZCBmYWN0'
    'b3IgYW5kIGNvZGluZyByYXRlUgl1c2VQcmVzZXQSWwoMbW9kZW1fcHJlc2V0GAIgASgOMikubW'
    'VzaHRhc3RpYy5Db25maWcuTG9SYUNvbmZpZy5Nb2RlbVByZXNldEINyvMYCToHUHJlc2V0c1IL'
    'bW9kZW1QcmVzZXQSMgoJYmFuZHdpZHRoGAMgASgNQhTK8xgQKgNrSHo6CUJhbmR3aWR0aFIJYm'
    'FuZHdpZHRoEoMBCg1zcHJlYWRfZmFjdG9yGAQgASgNQl7K8xhaGQAAAAAAABRAIQAAAAAAAChA'
    'Og1TcHJlYWQgRmFjdG9yQjdOdW1iZXIgb2YgY2hpcnBzIHBlciBzeW1ib2wsIGFzIDIgcmFpc2'
    'VkIHRvIHRoaXMgdmFsdWUuUgxzcHJlYWRGYWN0b3ISrwEKC2NvZGluZ19yYXRlGAUgASgNQo0B'
    'yvMYiAE6C0NvZGluZyBSYXRlQnlFcnJvci1jb3JyZWN0aW9uIHJlZHVuZGFuY3ksIGFzIHRoZS'
    'BkZW5vbWluYXRvciBvZiA0L24uIEhpZ2hlciB2YWx1ZXMgc3Vydml2ZSBub2lzaWVyIGxpbmtz'
    'IGJ1dCBtYWtlIGV2ZXJ5IHBhY2tldCBsb25nZXIuUgpjb2RpbmdSYXRlEikKEGZyZXF1ZW5jeV'
    '9vZmZzZXQYBiABKAJSD2ZyZXF1ZW5jeU9mZnNldBJ/CgZyZWdpb24YByABKA4yKC5tZXNodGFz'
    'dGljLkNvbmZpZy5Mb1JhQ29uZmlnLlJlZ2lvbkNvZGVCPcrzGDk6BlJlZ2lvbkIvVGhlIHJlZ2'
    'lvbiB3aGVyZSB5b3Ugd2lsbCBiZSB1c2luZyB5b3VyIHJhZGlvcy5SBnJlZ2lvbhKnAQoJaG9w'
    'X2xpbWl0GAggASgNQokByvMYhAEZAAAAAAAAAAAhAAAAAAAAHEA6CUhvcCBMaW1pdEJJSG93IG'
    '1hbnkgdGltZXMgYSBtZXNzYWdlIG1heSBiZSByZXBlYXRlZCBiZWZvcmUgaXQgc3RvcHMgYmVp'
    'bmcgZm9yd2FyZGVkLkoaaG9wc3x0dGx8cmFuZ2V8cmVicm9hZGNhc3RSCGhvcExpbWl0Eo8BCg'
    'p0eF9lbmFibGVkGAkgASgIQnDK8xhsOhBUcmFuc21pdCBFbmFibGVkQlhBbGxvdyB0aGUgTG9S'
    'YSByYWRpbyB0byB0cmFuc21pdC4gVHVybiBvZmYgd2hpbGUgaG90LXN3YXBwaW5nIGFudGVubm'
    'FzIG9yIGJlbmNoIHRlc3RpbmcuUgl0eEVuYWJsZWQS1wEKCHR4X3Bvd2VyGAogASgFQrsByvMY'
    'tgEZAAAAAAAAAAAhAAAAAAAAQkAqA2RCbToOVHJhbnNtaXQgUG93ZXJCeFJhZGlvIHRyYW5zbW'
    'l0IHBvd2VyLiBMZWF2ZSBhdCB6ZXJvIHRvIHVzZSB0aGUgaGlnaGVzdCBsZXZlbCBsZWdhbCBm'
    'b3IgdGhlIHJlZ2lvbiwgd2hpY2ggaXMgd2hhdCBtb3N0IHJhZGlvcyBzaG91bGQgdXNlLkoTdH'
    'h8cG93ZXJ8ZGJtfG91dHB1dFIHdHhQb3dlchLkAQoLY2hhbm5lbF9udW0YCyABKA1CwgHK8xi9'
    'AToORnJlcXVlbmN5IFNsb3RCqgFZb3VyIG5vZGUncyBvcGVyYXRpbmcgZnJlcXVlbmN5IGlzIG'
    'NhbGN1bGF0ZWQgYmFzZWQgb24gdGhlIHJlZ2lvbiwgbW9kZW0gcHJlc2V0LCBhbmQgdGhpcyBm'
    'aWVsZC4gV2hlbiAwLCB0aGUgcmVnaW9uIHBpY2tzIHRoZSBzbG90LCB1c3VhbGx5IGZyb20gdG'
    'hlIHByaW1hcnkgY2hhbm5lbCBuYW1lLlIKY2hhbm5lbE51bRJJChNvdmVycmlkZV9kdXR5X2N5'
    'Y2xlGAwgASgIQhnK8xgVOhNPdmVycmlkZSBEdXR5IEN5Y2xlUhFvdmVycmlkZUR1dHlDeWNsZR'
    'J/ChZzeDEyNnhfcnhfYm9vc3RlZF9nYWluGA0gASgIQkrK8xhGOg9SWCBCb29zdGVkIEdhaW5C'
    'M0VuYWJsZSBSWCBib29zdGVkIGdhaW4gbW9kZSBvbiBTWDEyNngtYmFzZWQgcmFkaW9zLlITc3'
    'gxMjZ4UnhCb29zdGVkR2FpbhJMChJvdmVycmlkZV9mcmVxdWVuY3kYDiABKAJCHcrzGBkqA01I'
    'ejoSRnJlcXVlbmN5IE92ZXJyaWRlUhFvdmVycmlkZUZyZXF1ZW5jeRI9Cg9wYV9mYW5fZGlzYW'
    'JsZWQYDyABKAhCFcrzGBE6D1BBIEZhbiBEaXNhYmxlZFINcGFGYW5EaXNhYmxlZBI+Cg9pZ25v'
    'cmVfaW5jb21pbmcYZyADKA1CFcrzGBE6D0lnbm9yZSBJbmNvbWluZ1IOaWdub3JlSW5jb21pbm'
    'cShQEKC2lnbm9yZV9tcXR0GGggASgIQmTK8xhgOgtJZ25vcmUgTVFUVEJRSWdub3JlIHBhY2tl'
    'dHMgcmVjZWl2ZWQgb3ZlciBMb1JhIHRoYXQgdHJhdmVsbGVkIHZpYSBNUVRUIGFueXdoZXJlIG'
    '9uIHRoZWlyIHBhdGguUgppZ25vcmVNcXR0EjsKEWNvbmZpZ19va190b19tcXR0GGkgASgIQhDK'
    '8xgMOgpPSyB0byBNUVRUUg5jb25maWdPa1RvTXF0dBJaCgxmZW1fbG5hX21vZGUYaiABKA4yKi'
    '5tZXNodGFzdGljLkNvbmZpZy5Mb1JhQ29uZmlnLkZFTV9MTkFfTW9kZUIMyvMYCFIGMi43LjIw'
    'UgpmZW1MbmFNb2RlEiYKD3NlcmlhbF9oYWxfb25seRhrIAEoCFINc2VyaWFsSGFsT25seRIpCh'
    'B0cmFuc3BhcmVudF9tb2RlGGwgASgIUg90cmFuc3BhcmVudE1vZGUilgsKClJlZ2lvbkNvZGUS'
    'JAoFVU5TRVQQABoZyvMYFToTUGxlYXNlIHNldCBhIHJlZ2lvbhIbCgJVUxABGhPK8xgPOg1Vbm'
    'l0ZWQgU3RhdGVzEicKBkVVXzQzMxACGhvK8xgXOhVFdXJvcGVhbiBVbmlvbiA0MzNNSHoSJwoG'
    'RVVfODY4EAMaG8rzGBc6FUV1cm9wZWFuIFVuaW9uIDg2OE1IehITCgJDThAEGgvK8xgHOgVDaG'
    'luYRITCgJKUBAFGgvK8xgHOgVKYXBhbhIvCgNBTloQBhomyvMYIjogQXVzdHJhbGlhIC8gQnJh'
    'emlsIC8gTmV3IFplYWxhbmQSEwoCS1IQBxoLyvMYBzoFS29yZWESFAoCVFcQCBoMyvMYCDoGVG'
    'Fpd2FuEhQKAlJVEAkaDMrzGAg6BlJ1c3NpYRITCgJJThAKGgvK8xgHOgVJbmRpYRIkCgZOWl84'
    'NjUQCxoYyvMYFDoSTmV3IFplYWxhbmQgODY1TUh6EhYKAlRIEAwaDsrzGAo6CFRoYWlsYW5kEh'
    'oKB0xPUkFfMjQQDRoNyvMYCToHMi40IEdIehIgCgZVQV80MzMQDhoUyvMYEDoOVWtyYWluZSA0'
    'MzNNSHoSKQoGVUFfODY4EA8aHQgByvMYFzoOVWtyYWluZSA4NjhNSHpaBTIuOC4wEiEKBk1ZXz'
    'QzMxAQGhXK8xgROg9NYWxheXNpYSA0MzNNSHoSIQoGTVlfOTE5EBEaFcrzGBE6D01hbGF5c2lh'
    'IDkxOU1IehIiCgZTR185MjMQEhoWyvMYEjoQU2luZ2Fwb3JlIDkyM01IehIkCgZQSF80MzMQEx'
    'oYyvMYFDoSUGhpbGlwcGluZXMgNDMzTUh6EiQKBlBIXzg2OBAUGhjK8xgUOhJQaGlsaXBwaW5l'
    'cyA4NjhNSHoSJAoGUEhfOTE1EBUaGMrzGBQ6ElBoaWxpcHBpbmVzIDkxNU1IehIxCgdBTlpfND'
    'MzEBYaJMrzGCA6HkF1c3RyYWxpYSAvIE5ldyBaZWFsYW5kIDQzM01IehIjCgZLWl80MzMQFxoX'
    'yvMYEzoRS2F6YWtoc3RhbiA0MzNNSHoSIwoGS1pfODYzEBgaF8rzGBM6EUthemFraHN0YW4gOD'
    'YzTUh6Eh4KBk5QXzg2NRAZGhLK8xgOOgxOZXBhbCA4NjVNSHoSHwoGQlJfOTAyEBoaE8rzGA86'
    'DUJyYXppbCA5MDJNSHoSLAoHSVRVMV8yTRAbGh/K8xgbOhlJVFUgUmVnaW9uIDEgLyBBbWF0ZX'
    'VyIDJtEiwKB0lUVTJfMk0QHBofyvMYGzoZSVRVIFJlZ2lvbiAyIC8gQW1hdGV1ciAybRInCgZF'
    'VV84NjYQHRobyvMYFzoVRXVyb3BlYW4gVW5pb24gODY2TUh6EicKBkVVXzg3NBAeGhvK8xgXOh'
    'VFdXJvcGVhbiBVbmlvbiA4NzRNSHoSJwoGRVVfOTE3EB8aG8rzGBc6FUV1cm9wZWFuIFVuaW9u'
    'IDkxN01IehIyCghFVV9OXzg2OBAgGiTK8xggOh5FdXJvcGVhbiBVbmlvbiA4NjhNSHogKE5hcn'
    'JvdykSLAoHSVRVM18yTRAhGh/K8xgbOhlJVFUgUmVnaW9uIDMgLyBBbWF0ZXVyIDJtEjAKCUlU'
    'VTFfNzBDTRAiGiHK8xgdOhtJVFUgUmVnaW9uIDEgLyBBbWF0ZXVyIDcwY20SMAoJSVRVMl83ME'
    'NNECMaIcrzGB06G0lUVSBSZWdpb24gMiAvIEFtYXRldXIgNzBjbRIwCglJVFUzXzcwQ00QJBoh'
    'yvMYHTobSVRVIFJlZ2lvbiAzIC8gQW1hdGV1ciA3MGNtEjIKCklUVTJfMTI1Q00QJRoiyvMYHj'
    'ocSVRVIFJlZ2lvbiAyIC8gQW1hdGV1ciAxLjI1bSLgBQoLTW9kZW1QcmVzZXQSOAoJTE9OR19G'
    'QVNUEAAaKcrzGCU6EUxvbmcgUmFuZ2UgLSBGYXN0ShBsb25nZmFzdHxkZWZhdWx0EigKCUxPTk'
    'dfU0xPVxABGhkIAcrzGBM6EUxvbmcgUmFuZ2UgLSBTbG93EjkKDlZFUllfTE9OR19TTE9XEAIa'
    'JQgByvMYHzoWVmVyeSBMb25nIFJhbmdlIC0gU2xvd1oFMi42LjUSKgoLTUVESVVNX1NMT1cQAx'
    'oZyvMYFToTTWVkaXVtIFJhbmdlIC0gU2xvdxIqCgtNRURJVU1fRkFTVBAEGhnK8xgVOhNNZWRp'
    'dW0gUmFuZ2UgLSBGYXN0EigKClNIT1JUX1NMT1cQBRoYyvMYFDoSU2hvcnQgUmFuZ2UgLSBTbG'
    '93EigKClNIT1JUX0ZBU1QQBhoYyvMYFDoSU2hvcnQgUmFuZ2UgLSBGYXN0Ei4KDUxPTkdfTU9E'
    'RVJBVEUQBxobyvMYFzoVTG9uZyBSYW5nZSAtIE1vZGVyYXRlEioKC1NIT1JUX1RVUkJPEAgaGc'
    'rzGBU6E1Nob3J0IFJhbmdlIC0gVHVyYm8SKAoKTE9OR19UVVJCTxAJGhjK8xgUOhJMb25nIFJh'
    'bmdlIC0gVHVyYm8SIAoJTElURV9GQVNUEAoaEcrzGA06C0xpdGUgLSBGYXN0EiAKCUxJVEVfU0'
    'xPVxALGhHK8xgNOgtMaXRlIC0gU2xvdxIkCgtOQVJST1dfRkFTVBAMGhPK8xgPOg1OYXJyb3cg'
    'LSBGYXN0EiQKC05BUlJPV19TTE9XEA0aE8rzGA86DU5hcnJvdyAtIFNsb3cSIAoJVElOWV9GQV'
    'NUEA4aEcrzGA06C1RpbnkgLSBGYXN0EiAKCVRJTllfU0xPVxAPGhHK8xgNOgtUaW55IC0gU2xv'
    'dxIsCgxNRURJVU1fVFVSQk8QEBoayvMYFjoUTWVkaXVtIFJhbmdlIC0gVHVyYm8iRAoMRkVNX0'
    'xOQV9Nb2RlEgwKCERJU0FCTEVEEAASCwoHRU5BQkxFRBABEg8KC05PVF9QUkVTRU5UEAISCAoE'
    'QVVUTxADGs0DCg9CbHVldG9vdGhDb25maWcSUQoHZW5hYmxlZBgBIAEoCEI3yvMYMzoRQmx1ZX'
    'Rvb3RoIEVuYWJsZWRCHkVuYWJsZSBCbHVldG9vdGggb24gdGhlIGRldmljZVIHZW5hYmxlZBJy'
    'CgRtb2RlGAIgASgOMi4ubWVzaHRhc3RpYy5Db25maWcuQmx1ZXRvb3RoQ29uZmlnLlBhaXJpbm'
    'dNb2RlQi7K8xgqOgxQYWlyaW5nIE1vZGVCGkJsdWV0b290aCBwYWlyaW5nIHN0cmF0ZWd5UgRt'
    'b2RlEnsKCWZpeGVkX3BpbhgDIAEoDUJeyvMYWjoJRml4ZWQgUGluQktGaXhlZCBQSU4gZm9yIE'
    'JsdWV0b290aCBwYWlyaW5nLiBVc2VkIHdoZW4gcGFpcmluZyBtb2RlIGlzIHNldCB0byBmaXhl'
    'ZCBQSU5oAVIIZml4ZWRQaW4idgoLUGFpcmluZ01vZGUSIAoKUkFORE9NX1BJThAAGhDK8xgMOg'
    'pSYW5kb20gUElOEh4KCUZJWEVEX1BJThABGg/K8xgLOglGaXhlZCBQSU4SJQoGTk9fUElOEAIa'
    'GcrzGBU6E05vIFBJTiAoSnVzdCBXb3Jrcyka1AwKDlNlY3VyaXR5Q29uZmlnEqcBCgpwdWJsaW'
    'Nfa2V5GAEgASgMQocByvMYggE6ClB1YmxpYyBLZXlCdEdlbmVyYXRlZCBmcm9tIHlvdXIgcHJp'
    'dmF0ZSBrZXkgYW5kIHNlbnQgb3V0IHRvIG90aGVyIG5vZGVzIG9uIHRoZSBtZXNoIHRvIGFsbG'
    '93IHRoZW0gdG8gY29tcHV0ZSBhIHNoYXJlZCBzZWNyZXQga2V5UglwdWJsaWNLZXkSZgoLcHJp'
    'dmF0ZV9rZXkYAiABKAxCRcrzGEE6C1ByaXZhdGUgS2V5QjBVc2VkIHRvIGNyZWF0ZSBhIHNoYX'
    'JlZCBrZXkgd2l0aCBhIHJlbW90ZSBkZXZpY2VoAVIKcHJpdmF0ZUtleRJ3CglhZG1pbl9rZXkY'
    'AyADKAxCWsrzGFY6CUFkbWluIEtleUJJUHVibGljIGtleXMgKHVwIHRvIHRocmVlKSBhdXRob3'
    'JpemVkIHRvIHNlbmQgYWRtaW4gbWVzc2FnZXMgdG8gdGhpcyBub2RlLlIIYWRtaW5LZXkSrQEK'
    'CmlzX21hbmFnZWQYBCABKAhCjQHK8xiIAToOTWFuYWdlZCBEZXZpY2VCdlNldHRpbmdzIGFyZS'
    'BjaGFuZ2VkIGJ5IGEgbWVzaCBhZG1pbmlzdHJhdG9yIHVzaW5nIGFuIGFkbWluIGtleSwgbm90'
    'IGZyb20gdGhlIGxvY2FsIGFwcC4gTmVlZHMgYXQgbGVhc3Qgb25lIGFkbWluIGtleS5SCWlzTW'
    'FuYWdlZBJgCg5zZXJpYWxfZW5hYmxlZBgFIAEoCEI5yvMYNToOU2VyaWFsIENvbnNvbGVCI1Nl'
    'cmlhbCBDb25zb2xlIG92ZXIgdGhlIFN0cmVhbSBBUEkuUg1zZXJpYWxFbmFibGVkEqkBChVkZW'
    'J1Z19sb2dfYXBpX2VuYWJsZWQYBiABKAhCdsrzGHI6CkRlYnVnIExvZ3NCZE91dHB1dCBsaXZl'
    'IGRlYnVnIGxvZ2dpbmcgb3ZlciBzZXJpYWwsIHZpZXcgYW5kIGV4cG9ydCBwb3NpdGlvbi1yZW'
    'RhY3RlZCBkZXZpY2UgbG9ncyBvdmVyIEJsdWV0b290aC5SEmRlYnVnTG9nQXBpRW5hYmxlZBIy'
    'ChVhZG1pbl9jaGFubmVsX2VuYWJsZWQYCCABKAhSE2FkbWluQ2hhbm5lbEVuYWJsZWQSfAoXcG'
    'Fja2V0X3NpZ25hdHVyZV9wb2xpY3kYCSABKA4yNy5tZXNodGFzdGljLkNvbmZpZy5TZWN1cml0'
    'eUNvbmZpZy5QYWNrZXRTaWduYXR1cmVQb2xpY3lCC8rzGAdSBTIuOC4wUhVwYWNrZXRTaWduYX'
    'R1cmVQb2xpY3kixgQKFVBhY2tldFNpZ25hdHVyZVBvbGljeRJ3CiJQQUNLRVRfU0lHTkFUVVJF'
    'X1BPTElDWV9DT01QQVRJQkxFEAAaT8rzGEs6F0NvbXBhdGlibGUgLSBObyBTaWduaW5nQjBEb2'
    '4ndCBzaWduIHBhY2tldHMsIGFuZCBhY2NlcHQgdW5zaWduZWQgcGFja2V0cy4S4QEKIFBBQ0tF'
    'VF9TSUdOQVRVUkVfUE9MSUNZX0JBTEFOQ0VEEAEaugHK8xi1ATogQmFsYW5jZWQgLSBTaWduLC'
    'BBY2NlcHQgVW5zaWduZWRCkAFTaWduIGJyb2FkY2FzdHMsIGFuZCBhY2NlcHQgdW5zaWduZWQg'
    'cGFja2V0cy4gQXBwcyBzaG93IHdoaWNoIHBhY2tldHMgd2VyZSBzaWduZWQuIFJlY29tbWVuZG'
    'VkIG9ubHkgd2hlcmUgbm8gcmVsYXlzIHJ1biBmaXJtd2FyZSBvbGRlciB0aGFuIDIuOC4SzwEK'
    'HlBBQ0tFVF9TSUdOQVRVUkVfUE9MSUNZX1NUUklDVBACGqoByvMYpQE6G1N0cmljdCAtIFJlcX'
    'VpcmUgU2lnbmF0dXJlc0KFAVNpZ24gYnJvYWRjYXN0cywgYW5kIGRyb3AgdW5zaWduZWQgcGFj'
    'a2V0cy4gUEtJIGRpcmVjdCBtZXNzYWdlcywgQUVTLUNDTSBjaGFubmVscywgYWNrcywgdHJhY2'
    'Vyb3V0ZXMgYW5kIGtleSB2ZXJpZmljYXRpb24gYXJlIGV4ZW1wdC4aEgoQU2Vzc2lvbmtleUNv'
    'bmZpZ0IRCg9wYXlsb2FkX3ZhcmlhbnQ=');
