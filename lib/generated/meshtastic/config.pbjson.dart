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
    {'1': 'sds_secs', '3': 6, '4': 1, '5': 13, '10': 'sdsSecs'},
    {'1': 'ls_secs', '3': 7, '4': 1, '5': 13, '10': 'lsSecs'},
    {'1': 'min_wake_secs', '3': 8, '4': 1, '5': 13, '10': 'minWakeSecs'},
    {
      '1': 'device_battery_ina_address',
      '3': 9,
      '4': 1,
      '5': 13,
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
    'NvbmZpZ0gAUghkZXZpY2VVaRrFHwoMRGV2aWNlQ29uZmlnEksKBHJvbGUYASABKA4yJC5tZXNo'
    'dGFzdGljLkNvbmZpZy5EZXZpY2VDb25maWcuUm9sZUIRyvMYDToLRGV2aWNlIFJvbGVSBHJvbG'
    'USKQoOc2VyaWFsX2VuYWJsZWQYAiABKAhCAhgBUg1zZXJpYWxFbmFibGVkEoEBCgtidXR0b25f'
    'Z3BpbxgEIAEoDUJgyvMYXDoLQnV0dG9uIEdQSU9CTUdQSU8gcGluIGZvciB0aGUgdXNlciBidX'
    'R0b24sIGNhbiBiZSByZW1hcHBlZCBvbiBib2FyZHMgd2l0aCBtdWx0aXBsZSBidXR0b25zUgpi'
    'dXR0b25HcGlvEk8KC2J1enplcl9ncGlvGAUgASgNQi7K8xgqOgtCdXp6ZXIgR1BJT0IbR1BJTy'
    'BwaW4gZm9yIHRoZSBQV00gYnV6emVyUgpidXp6ZXJHcGlvEnIKEHJlYnJvYWRjYXN0X21vZGUY'
    'BiABKA4yLy5tZXNodGFzdGljLkNvbmZpZy5EZXZpY2VDb25maWcuUmVicm9hZGNhc3RNb2RlQh'
    'bK8xgSOhBSZWJyb2FkY2FzdCBNb2RlUg9yZWJyb2FkY2FzdE1vZGUSnAEKGG5vZGVfaW5mb19i'
    'cm9hZGNhc3Rfc2VjcxgHIAEoDUJjyvMYXyoBczocTm9kZSBJbmZvIEJyb2FkY2FzdCBJbnRlcn'
    'ZhbEI8SG93IG9mdGVuIG5vZGUgaW5mb3JtYXRpb24gaXMgc2VudC4gRGVmYXVsdHMgdG8gOTAw'
    'IHNlY29uZHMuUhVub2RlSW5mb0Jyb2FkY2FzdFNlY3MSnAEKGmRvdWJsZV90YXBfYXNfYnV0dG'
    '9uX3ByZXNzGAggASgIQmDK8xhcOhREb3VibGUgVGFwIGFzIEJ1dHRvbkJEVHJlYXQgZG91Ymxl'
    'IHRhcCBvbiBzdXBwb3J0ZWQgYWNjZWxlcm9tZXRlcnMgYXMgYSB1c2VyIGJ1dHRvbiBwcmVzcy'
    '5SFmRvdWJsZVRhcEFzQnV0dG9uUHJlc3MSIQoKaXNfbWFuYWdlZBgJIAEoCEICGAFSCWlzTWFu'
    'YWdlZBJ9ChRkaXNhYmxlX3RyaXBsZV9jbGljaxgKIAEoCEJLyvMYRzoURGlzYWJsZSBUcmlwbG'
    'UgQ2xpY2tCL0Rpc2FibGVzIHRoZSB1c2VyIGJ1dHRvbiB0cmlwbGUtcHJlc3Mgc2hvcnRjdXQu'
    'UhJkaXNhYmxlVHJpcGxlQ2xpY2sSRwoFdHpkZWYYCyABKAlCMcrzGC06CVRpbWUgWm9uZUIgUE'
    '9TSVggdGltZXpvbmUgZGVmaW5pdGlvbiBzdHJpbmdSBXR6ZGVmEuIBChZsZWRfaGVhcnRiZWF0'
    'X2Rpc2FibGVkGAwgASgIQqsByvMYpgE6DUxFRCBIZWFydGJlYXRClAFDb250cm9scyB0aGUgYm'
    'xpbmtpbmcgTEVEIG9uIHRoZSBkZXZpY2UuICBGb3IgbW9zdCBkZXZpY2VzIHRoaXMgd2lsbCBj'
    'b250cm9sIG9uZSBvZiB0aGUgdXAgdG8gNCBMRURTLCB0aGUgY2hhcmdlciBhbmQgR1BTIExFRH'
    'MgYXJlIG5vdCBjb250cm9sbGFibGUuUhRsZWRIZWFydGJlYXREaXNhYmxlZBJYCgtidXp6ZXJf'
    'bW9kZRgNIAEoDjIqLm1lc2h0YXN0aWMuQ29uZmlnLkRldmljZUNvbmZpZy5CdXp6ZXJNb2RlQg'
    'vK8xgHUgUyLjcuMFIKYnV6emVyTW9kZSLUCwoEUm9sZRJICgZDTElFTlQQABo8yvMYODoGQ2xp'
    'ZW50Qi5BcHAgY29ubmVjdGVkIG9yIHN0YW5kIGFsb25lIG1lc3NhZ2luZyBkZXZpY2UuElwKC0'
    'NMSUVOVF9NVVRFEAEaS8rzGEc6C0NsaWVudCBNdXRlQjhEZXZpY2UgdGhhdCBkb2VzIG5vdCBm'
    'b3J3YXJkIHBhY2tldHMgZnJvbSBvdGhlciBkZXZpY2VzLhKwAQoGUk9VVEVSEAIaowHK8xieAT'
    'oGUm91dGVyQpMBSW5mcmFzdHJ1Y3R1cmUgbm9kZSBvbiBhIHRvd2VyIG9yIG1vdW50YWluIHRv'
    'cCBvbmx5LiAgTm90IHRvIGJlIHVzZWQgZm9yIHJvb2ZzIG9yIG1vYmlsZSBub2Rlcy4gIE5lZW'
    'RzIGV4Y2VwdGlvbmFsIGNvdmVyYWdlLiBWaXNpYmxlIGluIE5vZGVzIGxpc3QuEigKDVJPVVRF'
    'Ul9DTElFTlQQAxoVCAHK8xgPOg1Sb3V0ZXIgQ2xpZW50ErMBCghSRVBFQVRFUhAEGqQBCAHK8x'
    'idAToIUmVwZWF0ZXJCkAFEZXByZWNhdGVkIGluZnJhc3RydWN0dXJlIHJvbGUgdGhhdCBjcmVh'
    'dGVzIGdhcHMgaW4gdGhlIG1lc2ggcmVicm9hZGNhc3QgY2hhaW4uIFN3aXRjaCB0aGlzIG5vZG'
    'UgdG8gYSBSb3V0ZXItYmFzZWQgcm9sZSAoUm91dGVyIG9yIFJvdXRlciBMYXRlKS4SSAoHVFJB'
    'Q0tFUhAFGjvK8xg3OgdUcmFja2VyQixCcm9hZGNhc3RzIEdQUyBwb3NpdGlvbiBwYWNrZXRzIG'
    'FzIHByaW9yaXR5LhJDCgZTRU5TT1IQBho3yvMYMzoGU2Vuc29yQilCcm9hZGNhc3RzIHRlbGVt'
    'ZXRyeSBwYWNrZXRzIGFzIHByaW9yaXR5LhJYCgNUQUsQBxpPyvMYSzoDVEFLQkRPcHRpbWl6ZW'
    'QgZm9yIEFUQUsgc3lzdGVtIGNvbW11bmljYXRpb24sIHJlZHVjZXMgcm91dGluZSBicm9hZGNh'
    'c3RzLhJrCg1DTElFTlRfSElEREVOEAgaWMrzGFQ6DUNsaWVudCBIaWRkZW5CQ0RldmljZSB0aG'
    'F0IG9ubHkgYnJvYWRjYXN0cyBhcyBuZWVkZWQgZm9yIHN0ZWFsdGggb3IgcG93ZXIgc2F2aW5n'
    'cy4SiQEKDkxPU1RfQU5EX0ZPVU5EEAkadcrzGHE6Dkxvc3QgYW5kIEZvdW5kQl9Ccm9hZGNhc3'
    'RzIGxvY2F0aW9uIGFzIG1lc3NhZ2UgdG8gZGVmYXVsdCBjaGFubmVsIHJlZ3VsYXJseSBmb3Ig'
    'dG8gYXNzaXN0IHdpdGggZGV2aWNlIHJlY292ZXJ5LhJoCgtUQUtfVFJBQ0tFUhAKGlfK8xhTOg'
    'tUQUsgVHJhY2tlckJERW5hYmxlcyBhdXRvbWF0aWMgVEFLIFBMSSBicm9hZGNhc3RzIGFuZCBy'
    'ZWR1Y2VzIHJvdXRpbmUgYnJvYWRjYXN0cy4SvAEKC1JPVVRFUl9MQVRFEAsaqgHK8xilAToLUm'
    '91dGVyIExhdGVClQFJbmZyYXN0cnVjdHVyZSBub2RlIHRoYXQgYWx3YXlzIHJlYnJvYWRjYXN0'
    'cyBwYWNrZXRzIG9uY2UgYnV0IG9ubHkgYWZ0ZXIgYWxsIG90aGVyIG1vZGVzLiBWaXNpYmxlIG'
    'luIE5vZGVzIGxpc3QuIE5vdCBhIGdvb2QgY2hvaWNlIGZvciByb29mdG9wIG5vZGVzLhKFAQoL'
    'Q0xJRU5UX0JBU0UQDBp0yvMYcDoLQ2xpZW50IEJhc2VCYVVzZWQgZm9yIHJvb2Z0b3Agbm9kZX'
    'MgdG8gZGlzdHJpYnV0ZSBtZXNzYWdlcyBtb3JlIHdpZGVseSBmcm9tIG11bHRpcGxlIG5lYXJi'
    'eSBjbGllbnQgbXV0ZSBub2Rlcy4iyQgKD1JlYnJvYWRjYXN0TW9kZRKKAQoDQUxMEAAagAHK8x'
    'h8OgNBbGxCdVJlYnJvYWRjYXN0IGFueSBvYnNlcnZlZCBtZXNzYWdlLCBpZiBpdCB3YXMgb24g'
    'b3VyIHByaXZhdGUgY2hhbm5lbCBvciBmcm9tIGFub3RoZXIgY2hhbm5lbCB3aXRoIHRoZSBzYW'
    '1lIGxvcmEgcGFyYW1zLhLgAQoRQUxMX1NLSVBfREVDT0RJTkcQARrIAcrzGMMBOhFBbGwgU2tp'
    'cCBEZWNvZGluZ0KtAVNhbWUgYXMgYmVoYXZpb3IgYXMgQUxMIGJ1dCBza2lwcyBwYWNrZXQgZG'
    'Vjb2RpbmcgYW5kIHNpbXBseSByZWJyb2FkY2FzdHMgdGhlbS4gT25seSBhdmFpbGFibGUgaW4g'
    'UmVwZWF0ZXIgcm9sZS4gU2V0dGluZyB0aGlzIG9uIGFueSBvdGhlciByb2xlcyB3aWxsIHJlc3'
    'VsdCBpbiBBTEwgYmVoYXZpb3IuEs0BCgpMT0NBTF9PTkxZEAIavAHK8xi3AToKTG9jYWwgT25s'
    'eUKoAUlnbm9yZXMgb2JzZXJ2ZWQgbWVzc2FnZXMgZnJvbSBmb3JlaWduIG1lc2hlcyB0aGF0IG'
    'FyZSBvcGVuIG9yIHRob3NlIHdoaWNoIGl0IGNhbm5vdCBkZWNyeXB0LiBPbmx5IHJlYnJvYWRj'
    'YXN0cyBtZXNzYWdlIG9uIHRoZSBub2RlcyBsb2NhbCBwcmltYXJ5IC8gc2Vjb25kYXJ5IGNoYW'
    '5uZWxzLhLIAQoKS05PV05fT05MWRADGrcByvMYsgE6Cktub3duIE9ubHlCowFJZ25vcmVzIG9i'
    'c2VydmVkIG1lc3NhZ2VzIGZyb20gZm9yZWlnbiBtZXNoZXMgbGlrZSBMb2NhbCBPbmx5LCBidX'
    'QgdGFrZXMgaXQgc3RlcCBmdXJ0aGVyIGJ5IGFsc28gaWdub3JpbmcgbWVzc2FnZXMgZnJvbSBu'
    'b2RlcyBub3QgYWxyZWFkeSBpbiB0aGUgbm9kZSdzIGtub3duIGxpc3QuEpIBCgROT05FEAQahw'
    'HK8xiCAToETm9uZUJ6T25seSBwZXJtaXR0ZWQgZm9yIFNFTlNPUiwgVFJBQ0tFUiBhbmQgVEFL'
    'X1RSQUNLRVIgcm9sZXMsIHRoaXMgd2lsbCBpbmhpYml0IGFsbCByZWJyb2FkY2FzdHMsIG5vdC'
    'B1bmxpa2UgQ0xJRU5UX01VVEUgcm9sZS4SlQEKEkNPUkVfUE9SVE5VTVNfT05MWRAFGn3K8xh5'
    'OhJDb3JlIFBvcnRudW1zIE9ubHlCY09ubHkgcmVicm9hZGNhc3RzIHBhY2tldHMgZnJvbSB0aG'
    'UgY29yZSBwb3J0bnVtczogTm9kZUluZm8sIFRleHQsIFBvc2l0aW9uLCBUZWxlbWV0cnksIGFu'
    'ZCBSb3V0aW5nLiJpCgpCdXp6ZXJNb2RlEg8KC0FMTF9FTkFCTEVEEAASDAoIRElTQUJMRUQQAR'
    'IWChJOT1RJRklDQVRJT05TX09OTFkQAhIPCgtTWVNURU1fT05MWRADEhMKD0RJUkVDVF9NU0df'
    'T05MWRAEGoARCg5Qb3NpdGlvbkNvbmZpZxKQAQoXcG9zaXRpb25fYnJvYWRjYXN0X3NlY3MYAS'
    'ABKA1CWMrzGFQqAXM6EkJyb2FkY2FzdCBJbnRlcnZhbEI7VGhlIGxvbmdlc3QgYSBub2RlIHdp'
    'bGwgZ28gd2l0aG91dCBicm9hZGNhc3RpbmcgYSBwb3NpdGlvbi5SFXBvc2l0aW9uQnJvYWRjYX'
    'N0U2VjcxJdCiBwb3NpdGlvbl9icm9hZGNhc3Rfc21hcnRfZW5hYmxlZBgCIAEoCEIUyvMYEDoO'
    'U21hcnQgUG9zaXRpb25SHXBvc2l0aW9uQnJvYWRjYXN0U21hcnRFbmFibGVkEsEBCg5maXhlZF'
    '9wb3NpdGlvbhgDIAEoCEKZAcrzGJQBOg5GaXhlZCBQb3NpdGlvbkKBAVRoZSBsYXN0IGtub3du'
    'IGxhdGl0dWRlLCBsb25naXR1ZGUgYW5kIGFsdGl0dWRlIGFyZSBicm9hZGNhc3Qgb3ZlciB0aG'
    'UgbWVzaCBvbiB0aGUgcG9zaXRpb24gaW50ZXJ2YWwsIHJhdGhlciB0aGFuIGEgbGl2ZSBHUFMg'
    'Zml4LlINZml4ZWRQb3NpdGlvbhIjCgtncHNfZW5hYmxlZBgEIAEoCEICGAFSCmdwc0VuYWJsZW'
    'QScQoTZ3BzX3VwZGF0ZV9pbnRlcnZhbBgFIAEoDUJByvMYPSoBczoPVXBkYXRlIEludGVydmFs'
    'QidIb3cgb2Z0ZW4gdG8gdHJ5IHRvIGdldCBhIEdQUyBwb3NpdGlvbi5SEWdwc1VwZGF0ZUludG'
    'VydmFsEiwKEGdwc19hdHRlbXB0X3RpbWUYBiABKA1CAhgBUg5ncHNBdHRlbXB0VGltZRJ5Cg5w'
    'b3NpdGlvbl9mbGFncxgHIAEoDUJSyvMYTjoOUG9zaXRpb24gRmxhZ3NCPE9wdGlvbmFsIGZpZW'
    'xkcyB0byBpbmNsdWRlIHdoZW4gYXNzZW1ibGluZyBwb3NpdGlvbiBtZXNzYWdlc1INcG9zaXRp'
    'b25GbGFncxJGCgdyeF9ncGlvGAggASgNQi3K8xgpCAE6EEdQUyBSZWNlaXZlIEdQSU9CE0dQSU'
    '8gcGluIGZvciBHUFMgUlhSBnJ4R3BpbxJHCgd0eF9ncGlvGAkgASgNQi7K8xgqCAE6EUdQUyBU'
    'cmFuc21pdCBHUElPQhNHUElPIHBpbiBmb3IgR1BTIFRYUgZ0eEdwaW8SswEKIGJyb2FkY2FzdF'
    '9zbWFydF9taW5pbXVtX2Rpc3RhbmNlGAogASgNQmrK8xhmKgFtOhBNaW5pbXVtIERpc3RhbmNl'
    'Qk9UaGUgbWluaW11bSBjaGFuZ2UgaW4gZGlzdGFuY2UgYmVmb3JlIGEgc21hcnQgcG9zaXRpb2'
    '4gYnJvYWRjYXN0IGlzIGNvbnNpZGVyZWQuUh1icm9hZGNhc3RTbWFydE1pbmltdW1EaXN0YW5j'
    'ZRLDAQolYnJvYWRjYXN0X3NtYXJ0X21pbmltdW1faW50ZXJ2YWxfc2VjcxgLIAEoDUJxyvMYbS'
    'oBczoQTWluaW11bSBJbnRlcnZhbEJWVGhlIHNob3J0ZXN0IGludGVydmFsIGJldHdlZW4gcG9z'
    'aXRpb24gdXBkYXRlcyBvbmNlIHRoZSBtaW5pbXVtIGRpc3RhbmNlIGhhcyBiZWVuIG1ldC5SIW'
    'Jyb2FkY2FzdFNtYXJ0TWluaW11bUludGVydmFsU2VjcxJMCgtncHNfZW5fZ3BpbxgMIAEoDUIs'
    'yvMYKAgBOgtHUFMgRU4gR1BJT0IXR1BJTyBwaW4gZm9yIEdQUyBlbmFibGVSCWdwc0VuR3Bpbx'
    'JUCghncHNfbW9kZRgNIAEoDjIpLm1lc2h0YXN0aWMuQ29uZmlnLlBvc2l0aW9uQ29uZmlnLkdw'
    'c01vZGVCDsrzGAo6CEdQUyBNb2RlUgdncHNNb2RlItwECg1Qb3NpdGlvbkZsYWdzEgkKBVVOU0'
    'VUEAASYwoIQUxUSVRVREUQARpVyvMYUToIQWx0aXR1ZGVCRUluY2x1ZGUgYW4gYWx0aXR1ZGUg'
    'dmFsdWUgaW4gcG9zaXRpb24gcmVwb3J0cywgd2hlbiBvbmUgaXMgYXZhaWxhYmxlLhIyCgxBTF'
    'RJVFVERV9NU0wQAhogyvMYHDoaQWx0aXR1ZGUgaXMgTWVhbiBTZWEgTGV2ZWwSOQoSR0VPSURB'
    'TF9TRVBBUkFUSU9OEAQaIcrzGB06G0FsdGl0dWRlIEdlb2lkYWwgU2VwYXJhdGlvbhJVCgNET1'
    'AQCBpMyvMYSDoDRE9QQkFJbmNsdWRlIHRoZSBkaWx1dGlvbiBvZiBwcmVjaXNpb24gdmFsdWUu'
    'IFBET1AgaXMgdXNlZCBieSBkZWZhdWx0LhJgCgVIVkRPUBAQGlXK8xhROgtIRE9QIC8gVkRPUE'
    'JCSWYgRE9QIGlzIHNldCwgc2VuZCBzZXBhcmF0ZSBIRE9QIGFuZCBWRE9QIHZhbHVlcyBpbnN0'
    'ZWFkIG9mIFBET1AuEikKCVNBVElOVklFVxAgGhrK8xgWOhROdW1iZXIgb2Ygc2F0ZWxsaXRlcx'
    'IhCgZTRVFfTk8QQBoVyvMYEToPU2VxdWVuY2UgbnVtYmVyEh8KCVRJTUVTVEFNUBCAARoPyvMY'
    'CzoJVGltZXN0YW1wEiMKB0hFQURJTkcQgAIaFcrzGBE6D1ZlaGljbGUgaGVhZGluZxIfCgVTUE'
    'VFRBCABBoTyvMYDzoNVmVoaWNsZSBzcGVlZCJnCgdHcHNNb2RlEhwKCERJU0FCTEVEEAAaDsrz'
    'GAo6CERpc2FibGVkEhoKB0VOQUJMRUQQARoNyvMYCToHRW5hYmxlZBIiCgtOT1RfUFJFU0VOVB'
    'ACGhHK8xgNOgtOb3QgUHJlc2VudBrVBgoLUG93ZXJDb25maWcSpwIKD2lzX3Bvd2VyX3Nhdmlu'
    'ZxgBIAEoCEL+AcrzGPkBOgxQb3dlciBTYXZpbmdC6AFXaWxsIHNsZWVwIGV2ZXJ5dGhpbmcgYX'
    'MgbXVjaCBhcyBwb3NzaWJsZSwgZm9yIHRoZSB0cmFja2VyIGFuZCBzZW5zb3Igcm9sZSB0aGlz'
    'IHdpbGwgYWxzbyBpbmNsdWRlIHRoZSBsb3JhIHJhZGlvLiBEb24ndCB1c2UgdGhpcyBzZXR0aW'
    '5nIGlmIHlvdSB3YW50IHRvIHVzZSB5b3VyIGRldmljZSB3aXRoIHRoZSBwaG9uZSBhcHBzIG9y'
    'IGFyZSB1c2luZyBhIGRldmljZSB3aXRob3V0IGEgdXNlciBidXR0b24uUg1pc1Bvd2VyU2F2aW'
    '5nErwBCh5vbl9iYXR0ZXJ5X3NodXRkb3duX2FmdGVyX3NlY3MYAiABKA1CeMrzGHQqAXM6FlNo'
    'dXRkb3duIG9uIFBvd2VyIExvc3NCV0hvdyBsb25nIGFmdGVyIGV4dGVybmFsIHBvd2VyIGlzIH'
    'JlbW92ZWQgYmVmb3JlIHRoZSBkZXZpY2UgcG93ZXJzIG9mZi4gWmVybyB0byBkaXNhYmxlLlIa'
    'b25CYXR0ZXJ5U2h1dGRvd25BZnRlclNlY3MSSgoXYWRjX211bHRpcGxpZXJfb3ZlcnJpZGUYAy'
    'ABKAJCEsrzGA46DEFEQyBPdmVycmlkZVIVYWRjTXVsdGlwbGllck92ZXJyaWRlElEKE3dhaXRf'
    'Ymx1ZXRvb3RoX3NlY3MYBCABKA1CIcrzGB06G1dhaXQgZm9yIEJsdWV0b290aCBEdXJhdGlvbl'
    'IRd2FpdEJsdWV0b290aFNlY3MSGQoIc2RzX3NlY3MYBiABKA1SB3Nkc1NlY3MSFwoHbHNfc2Vj'
    'cxgHIAEoDVIGbHNTZWNzEiIKDW1pbl93YWtlX3NlY3MYCCABKA1SC21pbldha2VTZWNzEjsKGm'
    'RldmljZV9iYXR0ZXJ5X2luYV9hZGRyZXNzGAkgASgNUhdkZXZpY2VCYXR0ZXJ5SW5hQWRkcmVz'
    'cxIpChBwb3dlcm1vbl9lbmFibGVzGCAgASgEUg9wb3dlcm1vbkVuYWJsZXMa3QkKDU5ldHdvcm'
    'tDb25maWcSdgoMd2lmaV9lbmFibGVkGAEgASgIQlPK8xhPOgxXaUZpIEVuYWJsZWRCP0VuYWJs'
    'aW5nIFdpRmkgd2lsbCBkaXNhYmxlIHRoZSBibHVldG9vdGggY29ubmVjdGlvbiB0byB0aGUgYX'
    'BwLlILd2lmaUVuYWJsZWQSSAoJd2lmaV9zc2lkGAMgASgJQivK8xgnOgRTU0lEQh9XaUZpIG5l'
    'dHdvcmsgbmFtZSB0byBjb25uZWN0IHRvUgh3aWZpU3NpZBJLCgh3aWZpX3BzaxgEIAEoCUIwyv'
    'MYLDoIUGFzc3dvcmRCIFdpRmkgcGFzc3dvcmQgZm9yIGF1dGhlbnRpY2F0aW9uUgd3aWZpUHNr'
    'EmgKCm50cF9zZXJ2ZXIYBSABKAlCScrzGEU6Ck5UUCBTZXJ2ZXJCN05UUCBzZXJ2ZXIgYWRkcm'
    'Vzcy4gRGVmYXVsdHMgdG8gbWVzaHRhc3RpYy5wb29sLm50cC5vcmdSCW50cFNlcnZlchJ8Cgtl'
    'dGhfZW5hYmxlZBgGIAEoCEJbyvMYVzoQRXRoZXJuZXQgRW5hYmxlZEJDRW5hYmxpbmcgRXRoZX'
    'JuZXQgd2lsbCBkaXNhYmxlIHRoZSBibHVldG9vdGggY29ubmVjdGlvbiB0byB0aGUgYXBwLlIK'
    'ZXRoRW5hYmxlZBJjCgxhZGRyZXNzX21vZGUYByABKA4yLC5tZXNodGFzdGljLkNvbmZpZy5OZX'
    'R3b3JrQ29uZmlnLkFkZHJlc3NNb2RlQhLK8xgOOgxBZGRyZXNzIE1vZGVSC2FkZHJlc3NNb2Rl'
    'EkwKC2lwdjRfY29uZmlnGAggASgLMisubWVzaHRhc3RpYy5Db25maWcuTmV0d29ya0NvbmZpZy'
    '5JcFY0Q29uZmlnUgppcHY0Q29uZmlnEjsKDnJzeXNsb2dfc2VydmVyGAkgASgJQhTK8xgQOg5S'
    'c3lzbG9nIFNlcnZlclINcnN5c2xvZ1NlcnZlchKIAQoRZW5hYmxlZF9wcm90b2NvbHMYCiABKA'
    '1CW8rzGFc6EUVuYWJsZWQgUHJvdG9jb2xzQjtFbmFibGUgYnJvYWRjYXN0aW5nIHBhY2tldHMg'
    'dmlhIFVEUCBvdmVyIHRoZSBsb2NhbCBuZXR3b3JrLlIFMi42LjBSEGVuYWJsZWRQcm90b2NvbH'
    'MSLwoMaXB2Nl9lbmFibGVkGAsgASgIQgzK8xgIUgYyLjcuMTZSC2lwdjZFbmFibGVkGpIBCgpJ'
    'cFY0Q29uZmlnEhgKAmlwGAEgASgHQgjK8xgEOgJJUFICaXASJwoHZ2F0ZXdheRgCIAEoB0INyv'
    'MYCToHR2F0ZXdheVIHZ2F0ZXdheRIkCgZzdWJuZXQYAyABKAdCDMrzGAg6BlN1Ym5ldFIGc3Vi'
    'bmV0EhsKA2RucxgEIAEoB0IJyvMYBToDRE5TUgNkbnMiPQoLQWRkcmVzc01vZGUSFAoEREhDUB'
    'AAGgrK8xgGOgRESENQEhgKBlNUQVRJQxABGgzK8xgIOgZTdGF0aWMiVQoNUHJvdG9jb2xGbGFn'
    'cxIcCgxOT19CUk9BRENBU1QQABoKyvMYBjoETm9uZRImCg1VRFBfQlJPQURDQVNUEAEaE8rzGA'
    '86DVVEUCBCcm9hZGNhc3Qa3RQKDURpc3BsYXlDb25maWcSlwEKDnNjcmVlbl9vbl9zZWNzGAEg'
    'ASgNQnHK8xhtKgFzOg1TY3JlZW4gb24gZm9yQllIb3cgbG9uZyB0aGUgc2NyZWVuIHJlbWFpbn'
    'Mgb24gYWZ0ZXIgdGhlIHVzZXIgYnV0dG9uIGlzIHByZXNzZWQgb3IgbWVzc2FnZXMgYXJlIHJl'
    'Y2VpdmVkLlIMc2NyZWVuT25TZWNzEm0KCmdwc19mb3JtYXQYAiABKA4yPi5tZXNodGFzdGljLk'
    'NvbmZpZy5EaXNwbGF5Q29uZmlnLkRlcHJlY2F0ZWRHcHNDb29yZGluYXRlRm9ybWF0Qg4YAcrz'
    'GAhaBjIuNy4xMFIJZ3BzRm9ybWF0EqYBChlhdXRvX3NjcmVlbl9jYXJvdXNlbF9zZWNzGAMgAS'
    'gNQmvK8xhnKgFzOhFDYXJvdXNlbCBJbnRlcnZhbEJPQXV0b21hdGljYWxseSBtb3ZlcyB0byB0'
    'aGUgbmV4dCBzY3JlZW4gcGFnZSwgbGlrZSBhIGNhcm91c2VsLCBvbiB0aGlzIGludGVydmFsLl'
    'IWYXV0b1NjcmVlbkNhcm91c2VsU2VjcxKfAQoRY29tcGFzc19ub3J0aF90b3AYBCABKAhCcxgB'
    'yvMYbToSQWx3YXlzIHBvaW50IG5vcnRoQlBUaGUgY29tcGFzcyBoZWFkaW5nIG9uIHRoZSBzY3'
    'JlZW4gb3V0c2lkZSBvZiB0aGUgY2lyY2xlIHdpbGwgYWx3YXlzIHBvaW50IG5vcnRoLloFMi43'
    'LjFSD2NvbXBhc3NOb3J0aFRvcBJKCgtmbGlwX3NjcmVlbhgFIAEoCEIpyvMYJToLRmxpcCBTY3'
    'JlZW5CFkZsaXAgc2NyZWVuIHZlcnRpY2FsbHlSCmZsaXBTY3JlZW4SewoFdW5pdHMYBiABKA4y'
    'LS5tZXNodGFzdGljLkNvbmZpZy5EaXNwbGF5Q29uZmlnLkRpc3BsYXlVbml0c0I2yvMYMjoNRG'
    'lzcGxheSBVbml0c0IhVW5pdHMgc2hvd24gb24gdGhlIGRldmljZSBzY3JlZW4uUgV1bml0cxJ5'
    'CgRvbGVkGAcgASgOMikubWVzaHRhc3RpYy5Db25maWcuRGlzcGxheUNvbmZpZy5PbGVkVHlwZU'
    'I6yvMYNjoJT0xFRCBUeXBlQilPdmVycmlkZSBhdXRvbWF0aWMgT0xFRCBzY3JlZW4gZGV0ZWN0'
    'aW9uLlIEb2xlZBKDAQoLZGlzcGxheW1vZGUYCCABKA4yLC5tZXNodGFzdGljLkNvbmZpZy5EaX'
    'NwbGF5Q29uZmlnLkRpc3BsYXlNb2RlQjPK8xgvOgxEaXNwbGF5IE1vZGVCH092ZXJyaWRlIGRl'
    'ZmF1bHQgc2NyZWVuIGxheW91dC5SC2Rpc3BsYXltb2RlElsKDGhlYWRpbmdfYm9sZBgJIAEoCE'
    'I4yvMYNDoMQm9sZCBIZWFkaW5nQiRCb2xkIHRoZSBoZWFkaW5nIHRleHQgb24gdGhlIHNjcmVl'
    'bi5SC2hlYWRpbmdCb2xkEo0BChV3YWtlX29uX3RhcF9vcl9tb3Rpb24YCiABKAhCW8rzGFc6HF'
    'dha2UgU2NyZWVuIG9uIHRhcCBvciBtb3Rpb25CN1JlcXVpcmVzIHRoYXQgdGhlcmUgYmUgYW4g'
    'YWNjZWxlcm9tZXRlciBvbiB5b3VyIGRldmljZS5SEXdha2VPblRhcE9yTW90aW9uEssBChNjb2'
    '1wYXNzX29yaWVudGF0aW9uGAsgASgOMjMubWVzaHRhc3RpYy5Db25maWcuRGlzcGxheUNvbmZp'
    'Zy5Db21wYXNzT3JpZW50YXRpb25CZcrzGGE6E0NvbXBhc3MgT3JpZW50YXRpb25CSkluZGljYX'
    'RlcyBob3cgdG8gcm90YXRlIG9yIGludmVydCB0aGUgY29tcGFzcyBvdXRwdXQgZm9yIGFjY3Vy'
    'YXRlIGRpc3BsYXkuUhJjb21wYXNzT3JpZW50YXRpb24SaQoNdXNlXzEyaF9jbG9jaxgMIAEoCE'
    'JFyvMYQToNMTIgSG91ciBDbG9ja0IoU2V0cyB0aGUgc2NyZWVuIGNsb2NrIGZvcm1hdCB0byAx'
    'Mi1ob3VyLlIGMi41LjIyUgt1c2UxMmhDbG9jaxI5ChJ1c2VfbG9uZ19ub2RlX25hbWUYDSABKA'
    'hCDMrzGAhSBjIuNy4xM1IPdXNlTG9uZ05vZGVOYW1lEkIKFmVuYWJsZV9tZXNzYWdlX2J1YmJs'
    'ZXMYDiABKAhCDMrzGAhSBjIuNy4xOVIUZW5hYmxlTWVzc2FnZUJ1YmJsZXMiKwodRGVwcmVjYX'
    'RlZEdwc0Nvb3JkaW5hdGVGb3JtYXQSCgoGVU5VU0VEEAAiRgoMRGlzcGxheVVuaXRzEhgKBk1F'
    'VFJJQxAAGgzK8xgIOgZNZXRyaWMSHAoISU1QRVJJQUwQARoOyvMYCjoISW1wZXJpYWwi9wEKCE'
    '9sZWRUeXBlEikKCU9MRURfQVVUTxAAGhrK8xgWOhREZXRlY3QgQXV0b21hdGljYWxseRIgCgxP'
    'TEVEX1NTRDEzMDYQARoOyvMYCjoIU1NEIDEzMDYSHgoLT0xFRF9TSDExMDYQAhoNyvMYCToHU0'
    'ggMTEwNhIeCgtPTEVEX1NIMTEwNxADGg3K8xgJOgdTSCAxMTA3Ei4KE09MRURfU0gxMTA3XzEy'
    'OF8xMjgQBBoVyvMYEToPU0ggMTEwNyAxMjh4MTI4Ei4KE09MRURfU0gxMTA3X1JPVEFURUQQBR'
    'oVyvMYEToPU0ggMTEwNyBSb3RhdGVkItYBCgtEaXNwbGF5TW9kZRIvCgdERUZBVUxUEAAaIsrz'
    'GB46HERlZmF1bHQgMTI4eDY0IHNjcmVlbiBsYXlvdXQSMgoIVFdPQ09MT1IQARokyvMYIDoeT3'
    'B0aW1pemVkIGZvciAyIGNvbG9yIGRpc3BsYXlzEjgKCElOVkVSVEVEEAIaKsrzGCY6JEludmVy'
    'dGVkIHRvcCBiYXIgZm9yIDIgQ29sb3IgZGlzcGxheRIoCgVDT0xPUhADGh3K8xgZOhdURlQgRn'
    'VsbCBDb2xvciBEaXNwbGF5cyLAAgoSQ29tcGFzc09yaWVudGF0aW9uEhgKCURFR1JFRVNfMBAA'
    'GgnK8xgFOgMwwrASGgoKREVHUkVFU185MBABGgrK8xgGOgQ5MMKwEhwKC0RFR1JFRVNfMTgwEA'
    'IaC8rzGAc6BTE4MMKwEhwKC0RFR1JFRVNfMjcwEAMaC8rzGAc6BTI3MMKwEioKEkRFR1JFRVNf'
    'MF9JTlZFUlRFRBAEGhLK8xgOOgwwwrAgSW52ZXJ0ZWQSLAoTREVHUkVFU185MF9JTlZFUlRFRB'
    'AFGhPK8xgPOg05MMKwIEludmVydGVkEi4KFERFR1JFRVNfMTgwX0lOVkVSVEVEEAYaFMrzGBA6'
    'DjE4MMKwIEludmVydGVkEi4KFERFR1JFRVNfMjcwX0lOVkVSVEVEEAcaFMrzGBA6DjI3MMKwIE'
    'ludmVydGVkGpYjCgpMb1JhQ29uZmlnEosBCgp1c2VfcHJlc2V0GAEgASgIQmzK8xhoOgpVc2Ug'
    'UHJlc2V0QlpVc2UgdGhlIG1vZGVtIHByZXNldCBzZXR0aW5ncyBpbnN0ZWFkIG9mIGEgbWFudW'
    'FsIGJhbmR3aWR0aCwgc3ByZWFkIGZhY3RvciBhbmQgY29kaW5nIHJhdGVSCXVzZVByZXNldBJb'
    'Cgxtb2RlbV9wcmVzZXQYAiABKA4yKS5tZXNodGFzdGljLkNvbmZpZy5Mb1JhQ29uZmlnLk1vZG'
    'VtUHJlc2V0Qg3K8xgJOgdQcmVzZXRzUgttb2RlbVByZXNldBIyCgliYW5kd2lkdGgYAyABKA1C'
    'FMrzGBAqA2tIejoJQmFuZHdpZHRoUgliYW5kd2lkdGgSgwEKDXNwcmVhZF9mYWN0b3IYBCABKA'
    '1CXsrzGFoZAAAAAAAAFEAhAAAAAAAAKEA6DVNwcmVhZCBGYWN0b3JCN051bWJlciBvZiBjaGly'
    'cHMgcGVyIHN5bWJvbCwgYXMgMiByYWlzZWQgdG8gdGhpcyB2YWx1ZS5SDHNwcmVhZEZhY3Rvch'
    'KvAQoLY29kaW5nX3JhdGUYBSABKA1CjQHK8xiIAToLQ29kaW5nIFJhdGVCeUVycm9yLWNvcnJl'
    'Y3Rpb24gcmVkdW5kYW5jeSwgYXMgdGhlIGRlbm9taW5hdG9yIG9mIDQvbi4gSGlnaGVyIHZhbH'
    'VlcyBzdXJ2aXZlIG5vaXNpZXIgbGlua3MgYnV0IG1ha2UgZXZlcnkgcGFja2V0IGxvbmdlci5S'
    'CmNvZGluZ1JhdGUSKQoQZnJlcXVlbmN5X29mZnNldBgGIAEoAlIPZnJlcXVlbmN5T2Zmc2V0En'
    '8KBnJlZ2lvbhgHIAEoDjIoLm1lc2h0YXN0aWMuQ29uZmlnLkxvUmFDb25maWcuUmVnaW9uQ29k'
    'ZUI9yvMYOToGUmVnaW9uQi9UaGUgcmVnaW9uIHdoZXJlIHlvdSB3aWxsIGJlIHVzaW5nIHlvdX'
    'IgcmFkaW9zLlIGcmVnaW9uEqcBCglob3BfbGltaXQYCCABKA1CiQHK8xiEARkAAAAAAAAAACEA'
    'AAAAAAAcQDoJSG9wIExpbWl0QklIb3cgbWFueSB0aW1lcyBhIG1lc3NhZ2UgbWF5IGJlIHJlcG'
    'VhdGVkIGJlZm9yZSBpdCBzdG9wcyBiZWluZyBmb3J3YXJkZWQuShpob3BzfHR0bHxyYW5nZXxy'
    'ZWJyb2FkY2FzdFIIaG9wTGltaXQSjwEKCnR4X2VuYWJsZWQYCSABKAhCcMrzGGw6EFRyYW5zbW'
    'l0IEVuYWJsZWRCWEFsbG93IHRoZSBMb1JhIHJhZGlvIHRvIHRyYW5zbWl0LiBUdXJuIG9mZiB3'
    'aGlsZSBob3Qtc3dhcHBpbmcgYW50ZW5uYXMgb3IgYmVuY2ggdGVzdGluZy5SCXR4RW5hYmxlZB'
    'LcAQoIdHhfcG93ZXIYCiABKAVCwAHK8xi7ARkAAAAAAAAAACEAAAAAAAA+QCoDZEJtOg5UcmFu'
    'c21pdCBQb3dlckJ4UmFkaW8gdHJhbnNtaXQgcG93ZXIuIExlYXZlIGF0IHplcm8gdG8gdXNlIH'
    'RoZSBoaWdoZXN0IGxldmVsIGxlZ2FsIGZvciB0aGUgcmVnaW9uLCB3aGljaCBpcyB3aGF0IG1v'
    'c3QgcmFkaW9zIHNob3VsZCB1c2UuShh0eHxwb3dlcnxkYm18b3V0cHV0fGdhaW5SB3R4UG93ZX'
    'IS7AEKC2NoYW5uZWxfbnVtGAsgASgNQsoByvMYxQE6DkZyZXF1ZW5jeSBTbG90QrIBWW91ciBu'
    'b2Rl4oCZcyBvcGVyYXRpbmcgZnJlcXVlbmN5IGlzIGNhbGN1bGF0ZWQgYmFzZWQgb24gdGhlIH'
    'JlZ2lvbiwgbW9kZW0gcHJlc2V0LCBhbmQgdGhpcyBmaWVsZC4gV2hlbiAwLCB0aGUgc2xvdCBp'
    'cyBhdXRvbWF0aWNhbGx5IGNhbGN1bGF0ZWQgYmFzZWQgb24gdGhlIHByaW1hcnkgY2hhbm5lbC'
    'BuYW1lLlIKY2hhbm5lbE51bRJJChNvdmVycmlkZV9kdXR5X2N5Y2xlGAwgASgIQhnK8xgVOhNP'
    'dmVycmlkZSBEdXR5IEN5Y2xlUhFvdmVycmlkZUR1dHlDeWNsZRJ+ChZzeDEyNnhfcnhfYm9vc3'
    'RlZF9nYWluGA0gASgIQknK8xhFOg9SWCBCb29zdGVkIEdhaW5CMkVuYWJsZSBSWCBib29zdGVk'
    'IGdhaW4gbW9kZSBvbiBTWDEyNlggYmFzZWQgcmFkaW9zUhNzeDEyNnhSeEJvb3N0ZWRHYWluEk'
    'cKEm92ZXJyaWRlX2ZyZXF1ZW5jeRgOIAEoAkIYyvMYFDoSRnJlcXVlbmN5IE92ZXJyaWRlUhFv'
    'dmVycmlkZUZyZXF1ZW5jeRI9Cg9wYV9mYW5fZGlzYWJsZWQYDyABKAhCFcrzGBE6D1BBIEZhbi'
    'BEaXNhYmxlZFINcGFGYW5EaXNhYmxlZBI+Cg9pZ25vcmVfaW5jb21pbmcYZyADKA1CFcrzGBE6'
    'D0lnbm9yZSBJbmNvbWluZ1IOaWdub3JlSW5jb21pbmcShQEKC2lnbm9yZV9tcXR0GGggASgIQm'
    'TK8xhgOgtJZ25vcmUgTVFUVEJRSWdub3JlIHBhY2tldHMgcmVjZWl2ZWQgb3ZlciBMb1JhIHRo'
    'YXQgdHJhdmVsbGVkIHZpYSBNUVRUIGFueXdoZXJlIG9uIHRoZWlyIHBhdGguUgppZ25vcmVNcX'
    'R0EjsKEWNvbmZpZ19va190b19tcXR0GGkgASgIQhDK8xgMOgpPayB0byBNUVRUUg5jb25maWdP'
    'a1RvTXF0dBJaCgxmZW1fbG5hX21vZGUYaiABKA4yKi5tZXNodGFzdGljLkNvbmZpZy5Mb1JhQ2'
    '9uZmlnLkZFTV9MTkFfTW9kZUIMyvMYCFIGMi43LjIwUgpmZW1MbmFNb2RlEiYKD3NlcmlhbF9o'
    'YWxfb25seRhrIAEoCFINc2VyaWFsSGFsT25seSKGCwoKUmVnaW9uQ29kZRIkCgVVTlNFVBAAGh'
    'nK8xgVOhNQbGVhc2Ugc2V0IGEgcmVnaW9uEhsKAlVTEAEaE8rzGA86DVVuaXRlZCBTdGF0ZXMS'
    'JwoGRVVfNDMzEAIaG8rzGBc6FUV1cm9wZWFuIFVuaW9uIDQzM01IehInCgZFVV84NjgQAxobyv'
    'MYFzoVRXVyb3BlYW4gVW5pb24gODY4TUh6EhMKAkNOEAQaC8rzGAc6BUNoaW5hEhMKAkpQEAUa'
    'C8rzGAc6BUphcGFuEiYKA0FOWhAGGh3K8xgZOhdBdXN0cmFsaWEgLyBOZXcgWmVhbGFuZBITCg'
    'JLUhAHGgvK8xgHOgVLb3JlYRIUCgJUVxAIGgzK8xgIOgZUYWl3YW4SFAoCUlUQCRoMyvMYCDoG'
    'UnVzc2lhEhMKAklOEAoaC8rzGAc6BUluZGlhEiQKBk5aXzg2NRALGhjK8xgUOhJOZXcgWmVhbG'
    'FuZCA4NjVNSHoSFgoCVEgQDBoOyvMYCjoIVGhhaWxhbmQSGgoHTE9SQV8yNBANGg3K8xgJOgcy'
    'LjQgR2h6EiAKBlVBXzQzMxAOGhTK8xgQOg5Va3JhaW5lIDQzM01IehIiCgZVQV84NjgQDxoWCA'
    'HK8xgQOg5Va3JhaW5lIDg2OE1IehIhCgZNWV80MzMQEBoVyvMYEToPTWFsYXlzaWEgNDMzTUh6'
    'EiEKBk1ZXzkxORARGhXK8xgROg9NYWxheXNpYSA5MTlNSHoSIgoGU0dfOTIzEBIaFsrzGBI6EF'
    'NpbmdhcG9yZSA5MjNNSHoSJAoGUEhfNDMzEBMaGMrzGBQ6ElBoaWxpcHBpbmVzIDQzM01IehIk'
    'CgZQSF84NjgQFBoYyvMYFDoSUGhpbGlwcGluZXMgODY4TUh6EiQKBlBIXzkxNRAVGhjK8xgUOh'
    'JQaGlsaXBwaW5lcyA5MTVNSHoSMQoHQU5aXzQzMxAWGiTK8xggOh5BdXN0cmFsaWEgLyBOZXcg'
    'WmVhbGFuZCA0MzNNSHoSIwoGS1pfNDMzEBcaF8rzGBM6EUthemFraHN0YW4gNDMzTUh6EiMKBk'
    'taXzg2MxAYGhfK8xgTOhFLYXpha2hzdGFuIDg2M01IehIeCgZOUF84NjUQGRoSyvMYDjoMTmVw'
    'YWwgODY1TUh6Eh8KBkJSXzkwMhAaGhPK8xgPOg1CcmF6aWwgOTAyTUh6EiwKB0lUVTFfMk0QGx'
    'ofyvMYGzoZSVRVIFJlZ2lvbiAxIC8gQW1hdGV1ciAybRIsCgdJVFUyXzJNEBwaH8rzGBs6GUlU'
    'VSBSZWdpb24gMiAvIEFtYXRldXIgMm0SJwoGRVVfODY2EB0aG8rzGBc6FUV1cm9wZWFuIFVuaW'
    '9uIDg2Nk1IehInCgZFVV84NzQQHhobyvMYFzoVRXVyb3BlYW4gVW5pb24gODc0TUh6EicKBkVV'
    'XzkxNxAfGhvK8xgXOhVFdXJvcGVhbiBVbmlvbiA5MTdNSHoSMgoIRVVfTl84NjgQIBokyvMYID'
    'oeRXVyb3BlYW4gVW5pb24gODY4TUh6IChOYXJyb3cpEiwKB0lUVTNfMk0QIRofyvMYGzoZSVRV'
    'IFJlZ2lvbiAzIC8gQW1hdGV1ciAybRIwCglJVFUxXzcwQ00QIhohyvMYHTobSVRVIFJlZ2lvbi'
    'AxIC8gQW1hdGV1ciA3MGNtEjAKCUlUVTJfNzBDTRAjGiHK8xgdOhtJVFUgUmVnaW9uIDIgLyBB'
    'bWF0ZXVyIDcwY20SMAoJSVRVM183MENNECQaIcrzGB06G0lUVSBSZWdpb24gMyAvIEFtYXRldX'
    'IgNzBjbRIyCgpJVFUyXzEyNUNNECUaIsrzGB46HElUVSBSZWdpb24gMiAvIEFtYXRldXIgMS4y'
    'NW0i2QUKC01vZGVtUHJlc2V0EjgKCUxPTkdfRkFTVBAAGinK8xglOhFMb25nIFJhbmdlIC0gRm'
    'FzdEoQbG9uZ2Zhc3R8ZGVmYXVsdBIoCglMT05HX1NMT1cQARoZCAHK8xgTOhFMb25nIFJhbmdl'
    'IC0gU2xvdxIyCg5WRVJZX0xPTkdfU0xPVxACGh4IAcrzGBg6FlZlcnkgTG9uZyBSYW5nZSAtIF'
    'Nsb3cSKgoLTUVESVVNX1NMT1cQAxoZyvMYFToTTWVkaXVtIFJhbmdlIC0gU2xvdxIqCgtNRURJ'
    'VU1fRkFTVBAEGhnK8xgVOhNNZWRpdW0gUmFuZ2UgLSBGYXN0EigKClNIT1JUX1NMT1cQBRoYyv'
    'MYFDoSU2hvcnQgUmFuZ2UgLSBTbG93EigKClNIT1JUX0ZBU1QQBhoYyvMYFDoSU2hvcnQgUmFu'
    'Z2UgLSBGYXN0Ei4KDUxPTkdfTU9ERVJBVEUQBxobyvMYFzoVTG9uZyBSYW5nZSAtIE1vZGVyYX'
    'RlEioKC1NIT1JUX1RVUkJPEAgaGcrzGBU6E1Nob3J0IFJhbmdlIC0gVHVyYm8SKAoKTE9OR19U'
    'VVJCTxAJGhjK8xgUOhJMb25nIFJhbmdlIC0gVHVyYm8SIAoJTElURV9GQVNUEAoaEcrzGA06C0'
    'xpdGUgLSBGYXN0EiAKCUxJVEVfU0xPVxALGhHK8xgNOgtMaXRlIC0gU2xvdxIkCgtOQVJST1df'
    'RkFTVBAMGhPK8xgPOg1OYXJyb3cgLSBGYXN0EiQKC05BUlJPV19TTE9XEA0aE8rzGA86DU5hcn'
    'JvdyAtIFNsb3cSIAoJVElOWV9GQVNUEA4aEcrzGA06C1RpbnkgLSBGYXN0EiAKCVRJTllfU0xP'
    'VxAPGhHK8xgNOgtUaW55IC0gU2xvdxIsCgxNRURJVU1fVFVSQk8QEBoayvMYFjoUTWVkaXVtIF'
    'JhbmdlIC0gVHVyYm8iOgoMRkVNX0xOQV9Nb2RlEgwKCERJU0FCTEVEEAASCwoHRU5BQkxFRBAB'
    'Eg8KC05PVF9QUkVTRU5UEAIaywMKD0JsdWV0b290aENvbmZpZxJRCgdlbmFibGVkGAEgASgIQj'
    'fK8xgzOhFCbHVldG9vdGggRW5hYmxlZEIeRW5hYmxlIEJsdWV0b290aCBvbiB0aGUgZGV2aWNl'
    'UgdlbmFibGVkEnIKBG1vZGUYAiABKA4yLi5tZXNodGFzdGljLkNvbmZpZy5CbHVldG9vdGhDb2'
    '5maWcuUGFpcmluZ01vZGVCLsrzGCo6DFBhaXJpbmcgTW9kZUIaQmx1ZXRvb3RoIHBhaXJpbmcg'
    'c3RyYXRlZ3lSBG1vZGUSeQoJZml4ZWRfcGluGAMgASgNQlzK8xhYOglGaXhlZCBQaW5CS0ZpeG'
    'VkIFBJTiBmb3IgQmx1ZXRvb3RoIHBhaXJpbmcuIFVzZWQgd2hlbiBwYWlyaW5nIG1vZGUgaXMg'
    'c2V0IHRvIGZpeGVkIFBJTlIIZml4ZWRQaW4idgoLUGFpcmluZ01vZGUSIAoKUkFORE9NX1BJTh'
    'AAGhDK8xgMOgpSYW5kb20gUGluEh4KCUZJWEVEX1BJThABGg/K8xgLOglGaXhlZCBQaW4SJQoG'
    'Tk9fUElOEAIaGcrzGBU6E05vIFBJTiAoSnVzdCBXb3JrcykavQwKDlNlY3VyaXR5Q29uZmlnEq'
    'cBCgpwdWJsaWNfa2V5GAEgASgMQocByvMYggE6ClB1YmxpYyBLZXlCdEdlbmVyYXRlZCBmcm9t'
    'IHlvdXIgcHJpdmF0ZSBrZXkgYW5kIHNlbnQgb3V0IHRvIG90aGVyIG5vZGVzIG9uIHRoZSBtZX'
    'NoIHRvIGFsbG93IHRoZW0gdG8gY29tcHV0ZSBhIHNoYXJlZCBzZWNyZXQga2V5UglwdWJsaWNL'
    'ZXkSZAoLcHJpdmF0ZV9rZXkYAiABKAxCQ8rzGD86C1ByaXZhdGUgS2V5QjBVc2VkIHRvIGNyZW'
    'F0ZSBhIHNoYXJlZCBrZXkgd2l0aCBhIHJlbW90ZSBkZXZpY2VSCnByaXZhdGVLZXkSawoJYWRt'
    'aW5fa2V5GAMgAygMQk7K8xhKOglBZG1pbiBLZXlCPVRoZSBwdWJsaWMga2V5IGF1dGhvcml6ZW'
    'QgdG8gc2VuZCBhZG1pbiBtZXNzYWdlcyB0byB0aGlzIG5vZGVSCGFkbWluS2V5EpgBCgppc19t'
    'YW5hZ2VkGAQgASgIQnnK8xh1Og5NYW5hZ2VkIERldmljZUJjRGV2aWNlIGlzIG1hbmFnZWQgYn'
    'kgYSBtZXNoIGFkbWluaXN0cmF0b3IsIHRoZSB1c2VyIGlzIHVuYWJsZSB0byBhY2Nlc3MgYW55'
    'IG9mIHRoZSBkZXZpY2Ugc2V0dGluZ3MuUglpc01hbmFnZWQSYAoOc2VyaWFsX2VuYWJsZWQYBS'
    'ABKAhCOcrzGDU6DlNlcmlhbCBDb25zb2xlQiNTZXJpYWwgQ29uc29sZSBvdmVyIHRoZSBTdHJl'
    'YW0gQVBJLlINc2VyaWFsRW5hYmxlZBKpAQoVZGVidWdfbG9nX2FwaV9lbmFibGVkGAYgASgIQn'
    'bK8xhyOgpEZWJ1ZyBMb2dzQmRPdXRwdXQgbGl2ZSBkZWJ1ZyBsb2dnaW5nIG92ZXIgc2VyaWFs'
    'LCB2aWV3IGFuZCBleHBvcnQgcG9zaXRpb24tcmVkYWN0ZWQgZGV2aWNlIGxvZ3Mgb3ZlciBCbH'
    'VldG9vdGguUhJkZWJ1Z0xvZ0FwaUVuYWJsZWQSMgoVYWRtaW5fY2hhbm5lbF9lbmFibGVkGAgg'
    'ASgIUhNhZG1pbkNoYW5uZWxFbmFibGVkEnwKF3BhY2tldF9zaWduYXR1cmVfcG9saWN5GAkgAS'
    'gOMjcubWVzaHRhc3RpYy5Db25maWcuU2VjdXJpdHlDb25maWcuUGFja2V0U2lnbmF0dXJlUG9s'
    'aWN5QgvK8xgHUgUyLjguMFIVcGFja2V0U2lnbmF0dXJlUG9saWN5ItIEChVQYWNrZXRTaWduYX'
    'R1cmVQb2xpY3kSxQEKIlBBQ0tFVF9TSUdOQVRVUkVfUE9MSUNZX0NPTVBBVElCTEUQABqcAcrz'
    'GJcBOhxDb21wYXRpYmxlIC0gQWNjZXB0IFVuc2lnbmVkQndBY2NlcHQgdW5zaWduZWQgdHJhZm'
    'ZpYyBmb3IgbWF4aW11bSBjb21wYXRpYmlsaXR5LiBBIHNpZ25hdHVyZSB0aGF0IGNhbiBiZSBj'
    'aGVja2VkIGFuZCBpcyB3cm9uZyBzdGlsbCBkcm9wcyB0aGUgcGFja2V0LhKsAQogUEFDS0VUX1'
    'NJR05BVFVSRV9QT0xJQ1lfQkFMQU5DRUQQARqFAcrzGIABOh9CYWxhbmNlZCAtIFByZWZlciBB'
    'dXRoZW50aWNhdGVkQl1QcmVmZXIgYXV0aGVudGljYXRlZCBwYWNrZXRzLCBidXQgc3RpbGwgYW'
    'NjZXB0IHVuc2lnbmVkIHRyYWZmaWMgZnJvbSBub2RlcyBub3Qga25vd24gdG8gc2lnbi4SwQEK'
    'HlBBQ0tFVF9TSUdOQVRVUkVfUE9MSUNZX1NUUklDVBACGpwByvMYlwE6H1N0cmljdCAtIFJlcX'
    'VpcmUgQXV0aGVudGljYXRpb25CdEFjY2VwdCBvbmx5IHBhY2tldHMgd2l0aCBhIHZlcmlmaWVk'
    'IHNpZ25hdHVyZSBvciBzdWNjZXNzZnVsIFBLSSBkZWNyeXB0aW9uLiBQYWNrZXRzIGZyb20gb2'
    'xkZXIgbm9kZXMgbWF5IGJlIGlnbm9yZWQuGhIKEFNlc3Npb25rZXlDb25maWdCEQoPcGF5bG9h'
    'ZF92YXJpYW50');
