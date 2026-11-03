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
    'NvbmZpZ0gAUghkZXZpY2VVaRqbIAoMRGV2aWNlQ29uZmlnEksKBHJvbGUYASABKA4yJC5tZXNo'
    'dGFzdGljLkNvbmZpZy5EZXZpY2VDb25maWcuUm9sZUIRyvMYDToLRGV2aWNlIFJvbGVSBHJvbG'
    'USKQoOc2VyaWFsX2VuYWJsZWQYAiABKAhCAhgBUg1zZXJpYWxFbmFibGVkEoEBCgtidXR0b25f'
    'Z3BpbxgEIAEoDUJgyvMYXDoLQnV0dG9uIEdQSU9CTUdQSU8gcGluIGZvciB0aGUgdXNlciBidX'
    'R0b24sIGNhbiBiZSByZW1hcHBlZCBvbiBib2FyZHMgd2l0aCBtdWx0aXBsZSBidXR0b25zUgpi'
    'dXR0b25HcGlvEk8KC2J1enplcl9ncGlvGAUgASgNQi7K8xgqOgtCdXp6ZXIgR1BJT0IbR1BJTy'
    'BwaW4gZm9yIHRoZSBQV00gYnV6emVyUgpidXp6ZXJHcGlvEnIKEHJlYnJvYWRjYXN0X21vZGUY'
    'BiABKA4yLy5tZXNodGFzdGljLkNvbmZpZy5EZXZpY2VDb25maWcuUmVicm9hZGNhc3RNb2RlQh'
    'bK8xgSOhBSZWJyb2FkY2FzdCBNb2RlUg9yZWJyb2FkY2FzdE1vZGUSsQEKGG5vZGVfaW5mb19i'
    'cm9hZGNhc3Rfc2VjcxgHIAEoDUJ4yvMYdBkAAAAAACCsQCoBczocTm9kZSBJbmZvIEJyb2FkY2'
    'FzdCBJbnRlcnZhbEJISG93IG9mdGVuIG5vZGUgaW5mb3JtYXRpb24gaXMgc2VudC4gRGVmYXVs'
    'dHMgdG8gMyBob3VycywgbWluaW11bSAxIGhvdXIuUhVub2RlSW5mb0Jyb2FkY2FzdFNlY3MSnA'
    'EKGmRvdWJsZV90YXBfYXNfYnV0dG9uX3ByZXNzGAggASgIQmDK8xhcOhREb3VibGUgVGFwIGFz'
    'IEJ1dHRvbkJEVHJlYXQgZG91YmxlIHRhcCBvbiBzdXBwb3J0ZWQgYWNjZWxlcm9tZXRlcnMgYX'
    'MgYSB1c2VyIGJ1dHRvbiBwcmVzcy5SFmRvdWJsZVRhcEFzQnV0dG9uUHJlc3MSIQoKaXNfbWFu'
    'YWdlZBgJIAEoCEICGAFSCWlzTWFuYWdlZBJ9ChRkaXNhYmxlX3RyaXBsZV9jbGljaxgKIAEoCE'
    'JLyvMYRzoURGlzYWJsZSBUcmlwbGUgQ2xpY2tCL0Rpc2FibGVzIHRoZSB1c2VyIGJ1dHRvbiB0'
    'cmlwbGUtcHJlc3Mgc2hvcnRjdXQuUhJkaXNhYmxlVHJpcGxlQ2xpY2sSRwoFdHpkZWYYCyABKA'
    'lCMcrzGC06CVRpbWUgWm9uZUIgUE9TSVggdGltZXpvbmUgZGVmaW5pdGlvbiBzdHJpbmdSBXR6'
    'ZGVmEtsBChZsZWRfaGVhcnRiZWF0X2Rpc2FibGVkGAwgASgIQqQByvMYnwE6FURpc2FibGUgTE'
    'VEIEhlYXJ0YmVhdEKFAVR1cm5zIG9mZiB0aGUgYmxpbmtpbmcgTEVEIG9uIHRoZSBkZXZpY2Uu'
    'IE9uIG1vc3QgZGV2aWNlcyB0aGlzIGlzIG9uZSBvZiB1cCB0byA0IExFRHM7IHRoZSBjaGFyZ2'
    'VyIGFuZCBHUFMgTEVEcyBhcmUgbm90IGNvbnRyb2xsYWJsZS5SFGxlZEhlYXJ0YmVhdERpc2Fi'
    'bGVkElgKC2J1enplcl9tb2RlGA0gASgOMioubWVzaHRhc3RpYy5Db25maWcuRGV2aWNlQ29uZm'
    'lnLkJ1enplck1vZGVCC8rzGAdSBTIuNy4wUgpidXp6ZXJNb2RlIu8LCgRSb2xlEkcKBkNMSUVO'
    'VBAAGjvK8xg3OgZDbGllbnRCLUFwcCBjb25uZWN0ZWQgb3Igc3RhbmRhbG9uZSBtZXNzYWdpbm'
    'cgZGV2aWNlLhJcCgtDTElFTlRfTVVURRABGkvK8xhHOgtDbGllbnQgTXV0ZUI4RGV2aWNlIHRo'
    'YXQgZG9lcyBub3QgZm9yd2FyZCBwYWNrZXRzIGZyb20gb3RoZXIgZGV2aWNlcy4SrgEKBlJPVV'
    'RFUhACGqEByvMYnAE6BlJvdXRlckKRAUluZnJhc3RydWN0dXJlIG5vZGUgb24gYSB0b3dlciBv'
    'ciBtb3VudGFpbiB0b3Agb25seS4gTm90IHRvIGJlIHVzZWQgZm9yIHJvb2ZzIG9yIG1vYmlsZS'
    'Bub2Rlcy4gTmVlZHMgZXhjZXB0aW9uYWwgY292ZXJhZ2UuIFZpc2libGUgaW4gTm9kZXMgbGlz'
    'dC4SKAoNUk9VVEVSX0NMSUVOVBADGhUIAcrzGA86DVJvdXRlciBDbGllbnQSswEKCFJFUEVBVE'
    'VSEAQapAEIAcrzGJ0BOghSZXBlYXRlckKQAURlcHJlY2F0ZWQgaW5mcmFzdHJ1Y3R1cmUgcm9s'
    'ZSB0aGF0IGNyZWF0ZXMgZ2FwcyBpbiB0aGUgbWVzaCByZWJyb2FkY2FzdCBjaGFpbi4gU3dpdG'
    'NoIHRoaXMgbm9kZSB0byBhIFJvdXRlci1iYXNlZCByb2xlIChSb3V0ZXIgb3IgUm91dGVyIExh'
    'dGUpLhJICgdUUkFDS0VSEAUaO8rzGDc6B1RyYWNrZXJCLEJyb2FkY2FzdHMgR1BTIHBvc2l0aW'
    '9uIHBhY2tldHMgYXMgcHJpb3JpdHkuEkMKBlNFTlNPUhAGGjfK8xgzOgZTZW5zb3JCKUJyb2Fk'
    'Y2FzdHMgdGVsZW1ldHJ5IHBhY2tldHMgYXMgcHJpb3JpdHkuElgKA1RBSxAHGk/K8xhLOgNUQU'
    'tCRE9wdGltaXplZCBmb3IgQVRBSyBzeXN0ZW0gY29tbXVuaWNhdGlvbiwgcmVkdWNlcyByb3V0'
    'aW5lIGJyb2FkY2FzdHMuEmsKDUNMSUVOVF9ISURERU4QCBpYyvMYVDoNQ2xpZW50IEhpZGRlbk'
    'JDRGV2aWNlIHRoYXQgb25seSBicm9hZGNhc3RzIGFzIG5lZWRlZCBmb3Igc3RlYWx0aCBvciBw'
    'b3dlciBzYXZpbmdzLhKFAQoOTE9TVF9BTkRfRk9VTkQQCRpxyvMYbToOTG9zdCBhbmQgRm91bm'
    'RCW0Jyb2FkY2FzdHMgbG9jYXRpb24gYXMgbWVzc2FnZSB0byBkZWZhdWx0IGNoYW5uZWwgcmVn'
    'dWxhcmx5IHRvIGFzc2lzdCB3aXRoIGRldmljZSByZWNvdmVyeS4SaAoLVEFLX1RSQUNLRVIQCh'
    'pXyvMYUzoLVEFLIFRyYWNrZXJCREVuYWJsZXMgYXV0b21hdGljIFRBSyBQTEkgYnJvYWRjYXN0'
    'cyBhbmQgcmVkdWNlcyByb3V0aW5lIGJyb2FkY2FzdHMuErwBCgtST1VURVJfTEFURRALGqoByv'
    'MYpQE6C1JvdXRlciBMYXRlQpUBSW5mcmFzdHJ1Y3R1cmUgbm9kZSB0aGF0IGFsd2F5cyByZWJy'
    'b2FkY2FzdHMgcGFja2V0cyBvbmNlIGJ1dCBvbmx5IGFmdGVyIGFsbCBvdGhlciBtb2Rlcy4gVm'
    'lzaWJsZSBpbiBOb2RlcyBsaXN0LiBOb3QgYSBnb29kIGNob2ljZSBmb3Igcm9vZnRvcCBub2Rl'
    'cy4SpwEKC0NMSUVOVF9CQVNFEAwalQHK8xiQAToLQ2xpZW50IEJhc2VCgAFSb29mdG9wIG9yIG'
    'F0dGljIG5vZGUgdGhhdCByZWJyb2FkY2FzdHMgbGlrZSBSb3V0ZXIgTGF0ZSBmb3IgcGFja2V0'
    'cyBmcm9tIG9yIHRvIGZhdm9yaXRlZCBub2RlcywgYW5kIGxpa2UgQ2xpZW50IGZvciBhbGwgb3'
    'RoZXJzLiL2CAoPUmVicm9hZGNhc3RNb2RlEowBCgNBTEwQABqCAcrzGH46A0FsbEJ3UmVicm9h'
    'ZGNhc3QgYW55IG9ic2VydmVkIG1lc3NhZ2UsIGlmIGl0IHdhcyBvbiBvdXIgcHJpdmF0ZSBjaG'
    'FubmVsIG9yIGZyb20gYW5vdGhlciBjaGFubmVsIHdpdGggdGhlIHNhbWUgTG9SYSBzZXR0aW5n'
    'cy4SmgEKEUFMTF9TS0lQX0RFQ09ESU5HEAEaggHK8xh+OhFBbGwgU2tpcCBEZWNvZGluZ0JpQm'
    'VoYXZlcyBhcyBBbGwuIFNraXBwaW5nIHBhY2tldCBkZWNvZGluZyBhcHBsaWVkIG9ubHkgdG8g'
    'dGhlIFJlcGVhdGVyIHJvbGUsIHdoaWNoIGlzIG5vIGxvbmdlciBzdXBwb3J0ZWQuEs8BCgpMT0'
    'NBTF9PTkxZEAIavgHK8xi5AToKTG9jYWwgT25seUKqAUlnbm9yZXMgb2JzZXJ2ZWQgbWVzc2Fn'
    'ZXMgZnJvbSBmb3JlaWduIG1lc2hlcyB0aGF0IGFyZSBvcGVuIG9yIHRob3NlIHdoaWNoIGl0IG'
    'Nhbm5vdCBkZWNyeXB0LiBPbmx5IHJlYnJvYWRjYXN0cyBtZXNzYWdlcyBvbiB0aGUgbm9kZSdz'
    'IGxvY2FsIHByaW1hcnkgLyBzZWNvbmRhcnkgY2hhbm5lbHMuEsoBCgpLTk9XTl9PTkxZEAMauQ'
    'HK8xi0AToKS25vd24gT25seUKlAUlnbm9yZXMgb2JzZXJ2ZWQgbWVzc2FnZXMgZnJvbSBmb3Jl'
    'aWduIG1lc2hlcyBsaWtlIExvY2FsIE9ubHksIGJ1dCB0YWtlcyBpdCBhIHN0ZXAgZnVydGhlci'
    'BieSBhbHNvIGlnbm9yaW5nIG1lc3NhZ2VzIGZyb20gbm9kZXMgbm90IGFscmVhZHkgaW4gdGhl'
    'IG5vZGUncyBrbm93biBsaXN0LhJ8CgROT05FEAQacsrzGG46BE5vbmVCZkluaGliaXRzIGFsbC'
    'ByZWJyb2FkY2FzdHMsIGxpa2UgdGhlIENsaWVudCBNdXRlIHJvbGUuIE5vdCBhbGxvd2VkIG9u'
    'IHRoZSBSb3V0ZXIgYW5kIFJvdXRlciBMYXRlIHJvbGVzLhKZAgoSQ09SRV9QT1JUTlVNU19PTk'
    'xZEAUagALK8xj7AToSQ29yZSBQb3J0bnVtcyBPbmx5QuQBSWdub3JlcyBwYWNrZXRzIG9uIG5v'
    'bi1jb3JlIHBvcnRudW1zIHN1Y2ggYXMgUmFuZ2UgVGVzdCwgUEFYIENvdW50ZXIgYW5kIEFUQU'
    'ssIGFuZCBkb2VzIG5vdCByZWJyb2FkY2FzdCB0aGVtLiBDb3JlIHBvcnRudW1zIGluY2x1ZGUg'
    'VGV4dCwgUG9zaXRpb24sIE5vZGVJbmZvLCBUZWxlbWV0cnksIFJvdXRpbmcsIEFkbWluLCBXYX'
    'lwb2ludCwgVHJhY2Vyb3V0ZSBhbmQgU3RvcmUgYW5kIEZvcndhcmQuImkKCkJ1enplck1vZGUS'
    'DwoLQUxMX0VOQUJMRUQQABIMCghESVNBQkxFRBABEhYKEk5PVElGSUNBVElPTlNfT05MWRACEg'
    '8KC1NZU1RFTV9PTkxZEAMSEwoPRElSRUNUX01TR19PTkxZEAQahBEKDlBvc2l0aW9uQ29uZmln'
    'EpABChdwb3NpdGlvbl9icm9hZGNhc3Rfc2VjcxgBIAEoDUJYyvMYVCoBczoSQnJvYWRjYXN0IE'
    'ludGVydmFsQjtUaGUgbG9uZ2VzdCBhIG5vZGUgd2lsbCBnbyB3aXRob3V0IGJyb2FkY2FzdGlu'
    'ZyBhIHBvc2l0aW9uLlIVcG9zaXRpb25Ccm9hZGNhc3RTZWNzEl0KIHBvc2l0aW9uX2Jyb2FkY2'
    'FzdF9zbWFydF9lbmFibGVkGAIgASgIQhTK8xgQOg5TbWFydCBQb3NpdGlvblIdcG9zaXRpb25C'
    'cm9hZGNhc3RTbWFydEVuYWJsZWQSwQEKDmZpeGVkX3Bvc2l0aW9uGAMgASgIQpkByvMYlAE6Dk'
    'ZpeGVkIFBvc2l0aW9uQoEBVGhlIGxhc3Qga25vd24gbGF0aXR1ZGUsIGxvbmdpdHVkZSBhbmQg'
    'YWx0aXR1ZGUgYXJlIGJyb2FkY2FzdCBvdmVyIHRoZSBtZXNoIG9uIHRoZSBwb3NpdGlvbiBpbn'
    'RlcnZhbCwgcmF0aGVyIHRoYW4gYSBsaXZlIEdQUyBmaXguUg1maXhlZFBvc2l0aW9uEiMKC2dw'
    'c19lbmFibGVkGAQgASgIQgIYAVIKZ3BzRW5hYmxlZBJxChNncHNfdXBkYXRlX2ludGVydmFsGA'
    'UgASgNQkHK8xg9KgFzOg9VcGRhdGUgSW50ZXJ2YWxCJ0hvdyBvZnRlbiB0byB0cnkgdG8gZ2V0'
    'IGEgR1BTIHBvc2l0aW9uLlIRZ3BzVXBkYXRlSW50ZXJ2YWwSLAoQZ3BzX2F0dGVtcHRfdGltZR'
    'gGIAEoDUICGAFSDmdwc0F0dGVtcHRUaW1lEnkKDnBvc2l0aW9uX2ZsYWdzGAcgASgNQlLK8xhO'
    'Og5Qb3NpdGlvbiBGbGFnc0I8T3B0aW9uYWwgZmllbGRzIHRvIGluY2x1ZGUgd2hlbiBhc3NlbW'
    'JsaW5nIHBvc2l0aW9uIG1lc3NhZ2VzUg1wb3NpdGlvbkZsYWdzEkYKB3J4X2dwaW8YCCABKA1C'
    'LcrzGCkIAToQR1BTIFJlY2VpdmUgR1BJT0ITR1BJTyBwaW4gZm9yIEdQUyBSWFIGcnhHcGlvEk'
    'cKB3R4X2dwaW8YCSABKA1CLsrzGCoIAToRR1BTIFRyYW5zbWl0IEdQSU9CE0dQSU8gcGluIGZv'
    'ciBHUFMgVFhSBnR4R3BpbxKzAQogYnJvYWRjYXN0X3NtYXJ0X21pbmltdW1fZGlzdGFuY2UYCi'
    'ABKA1CasrzGGYqAW06EE1pbmltdW0gRGlzdGFuY2VCT1RoZSBtaW5pbXVtIGNoYW5nZSBpbiBk'
    'aXN0YW5jZSBiZWZvcmUgYSBzbWFydCBwb3NpdGlvbiBicm9hZGNhc3QgaXMgY29uc2lkZXJlZC'
    '5SHWJyb2FkY2FzdFNtYXJ0TWluaW11bURpc3RhbmNlEsMBCiVicm9hZGNhc3Rfc21hcnRfbWlu'
    'aW11bV9pbnRlcnZhbF9zZWNzGAsgASgNQnHK8xhtKgFzOhBNaW5pbXVtIEludGVydmFsQlZUaG'
    'Ugc2hvcnRlc3QgaW50ZXJ2YWwgYmV0d2VlbiBwb3NpdGlvbiB1cGRhdGVzIG9uY2UgdGhlIG1p'
    'bmltdW0gZGlzdGFuY2UgaGFzIGJlZW4gbWV0LlIhYnJvYWRjYXN0U21hcnRNaW5pbXVtSW50ZX'
    'J2YWxTZWNzElAKC2dwc19lbl9ncGlvGAwgASgNQjDK8xgsCAE6D0dQUyBFbmFibGUgR1BJT0IX'
    'R1BJTyBwaW4gZm9yIEdQUyBlbmFibGVSCWdwc0VuR3BpbxJUCghncHNfbW9kZRgNIAEoDjIpLm'
    '1lc2h0YXN0aWMuQ29uZmlnLlBvc2l0aW9uQ29uZmlnLkdwc01vZGVCDsrzGAo6CEdQUyBNb2Rl'
    'UgdncHNNb2RlItwECg1Qb3NpdGlvbkZsYWdzEgkKBVVOU0VUEAASYwoIQUxUSVRVREUQARpVyv'
    'MYUToIQWx0aXR1ZGVCRUluY2x1ZGUgYW4gYWx0aXR1ZGUgdmFsdWUgaW4gcG9zaXRpb24gcmVw'
    'b3J0cywgd2hlbiBvbmUgaXMgYXZhaWxhYmxlLhIyCgxBTFRJVFVERV9NU0wQAhogyvMYHDoaQW'
    'x0aXR1ZGUgaXMgTWVhbiBTZWEgTGV2ZWwSOQoSR0VPSURBTF9TRVBBUkFUSU9OEAQaIcrzGB06'
    'G0FsdGl0dWRlIEdlb2lkYWwgU2VwYXJhdGlvbhJVCgNET1AQCBpMyvMYSDoDRE9QQkFJbmNsdW'
    'RlIHRoZSBkaWx1dGlvbiBvZiBwcmVjaXNpb24gdmFsdWUuIFBET1AgaXMgdXNlZCBieSBkZWZh'
    'dWx0LhJgCgVIVkRPUBAQGlXK8xhROgtIRE9QIC8gVkRPUEJCSWYgRE9QIGlzIHNldCwgc2VuZC'
    'BzZXBhcmF0ZSBIRE9QIGFuZCBWRE9QIHZhbHVlcyBpbnN0ZWFkIG9mIFBET1AuEikKCVNBVElO'
    'VklFVxAgGhrK8xgWOhROdW1iZXIgb2Ygc2F0ZWxsaXRlcxIhCgZTRVFfTk8QQBoVyvMYEToPU2'
    'VxdWVuY2UgbnVtYmVyEh8KCVRJTUVTVEFNUBCAARoPyvMYCzoJVGltZXN0YW1wEiMKB0hFQURJ'
    'TkcQgAIaFcrzGBE6D1ZlaGljbGUgaGVhZGluZxIfCgVTUEVFRBCABBoTyvMYDzoNVmVoaWNsZS'
    'BzcGVlZCJnCgdHcHNNb2RlEhwKCERJU0FCTEVEEAAaDsrzGAo6CERpc2FibGVkEhoKB0VOQUJM'
    'RUQQARoNyvMYCToHRW5hYmxlZBIiCgtOT1RfUFJFU0VOVBACGhHK8xgNOgtOb3QgUHJlc2VudB'
    'qCBwoLUG93ZXJDb25maWcSpAIKD2lzX3Bvd2VyX3NhdmluZxgBIAEoCEL7AcrzGPYBOgxQb3dl'
    'ciBTYXZpbmdC5QFXaWxsIHNsZWVwIGV2ZXJ5dGhpbmcgYXMgbXVjaCBhcyBwb3NzaWJsZSwgZm'
    '9yIHRoZSBUcmFja2VyIGFuZCBTZW5zb3Igcm9sZXMgdGhpcyBhbHNvIGluY2x1ZGVzIHRoZSBM'
    'b1JhIHJhZGlvLiBEb24ndCB1c2UgdGhpcyBzZXR0aW5nIGlmIHlvdSB3YW50IHRvIHVzZSB5b3'
    'VyIGRldmljZSB3aXRoIHRoZSBwaG9uZSBhcHBzIG9yIGFyZSB1c2luZyBhIGRldmljZSB3aXRo'
    'b3V0IGEgdXNlciBidXR0b24uUg1pc1Bvd2VyU2F2aW5nEukBCh5vbl9iYXR0ZXJ5X3NodXRkb3'
    'duX2FmdGVyX3NlY3MYAiABKA1CpAHK8xifASoBczoWU2h1dGRvd24gb24gUG93ZXIgTG9zc0KB'
    'AUhvdyBsb25nIGFmdGVyIGV4dGVybmFsIHBvd2VyIGlzIHJlbW92ZWQgYmVmb3JlIHRoZSBkZX'
    'ZpY2UgcG93ZXJzIG9mZi4gWmVybyB0byBkaXNhYmxlOyB2YWx1ZXMgdW5kZXIgMzAgc2Vjb25k'
    'cyBhcmUgcmFpc2VkIHRvIDMwLlIab25CYXR0ZXJ5U2h1dGRvd25BZnRlclNlY3MSSgoXYWRjX2'
    '11bHRpcGxpZXJfb3ZlcnJpZGUYAyABKAJCEsrzGA46DEFEQyBPdmVycmlkZVIVYWRjTXVsdGlw'
    'bGllck92ZXJyaWRlElQKE3dhaXRfYmx1ZXRvb3RoX3NlY3MYBCABKA1CJMrzGCAqAXM6G1dhaX'
    'QgZm9yIEJsdWV0b290aCBEdXJhdGlvblIRd2FpdEJsdWV0b290aFNlY3MSGQoIc2RzX3NlY3MY'
    'BiABKA1SB3Nkc1NlY3MSFwoHbHNfc2VjcxgHIAEoDVIGbHNTZWNzEiIKDW1pbl93YWtlX3NlY3'
    'MYCCABKA1SC21pbldha2VTZWNzEjsKGmRldmljZV9iYXR0ZXJ5X2luYV9hZGRyZXNzGAkgASgN'
    'UhdkZXZpY2VCYXR0ZXJ5SW5hQWRkcmVzcxIpChBwb3dlcm1vbl9lbmFibGVzGCAgASgEUg9wb3'
    'dlcm1vbkVuYWJsZXMa7wkKDU5ldHdvcmtDb25maWcSdgoMd2lmaV9lbmFibGVkGAEgASgIQlPK'
    '8xhPOgxXaUZpIEVuYWJsZWRCP0VuYWJsaW5nIFdpRmkgd2lsbCBkaXNhYmxlIHRoZSBCbHVldG'
    '9vdGggY29ubmVjdGlvbiB0byB0aGUgYXBwLlILd2lmaUVuYWJsZWQSSAoJd2lmaV9zc2lkGAMg'
    'ASgJQivK8xgnOgRTU0lEQh9XaUZpIG5ldHdvcmsgbmFtZSB0byBjb25uZWN0IHRvUgh3aWZpU3'
    'NpZBJLCgh3aWZpX3BzaxgEIAEoCUIwyvMYLDoIUGFzc3dvcmRCIFdpRmkgcGFzc3dvcmQgZm9y'
    'IGF1dGhlbnRpY2F0aW9uUgd3aWZpUHNrEmgKCm50cF9zZXJ2ZXIYBSABKAlCScrzGEU6Ck5UUC'
    'BTZXJ2ZXJCN05UUCBzZXJ2ZXIgYWRkcmVzcy4gRGVmYXVsdHMgdG8gbWVzaHRhc3RpYy5wb29s'
    'Lm50cC5vcmdSCW50cFNlcnZlchKNAQoLZXRoX2VuYWJsZWQYBiABKAhCbMrzGGg6EEV0aGVybm'
    'V0IEVuYWJsZWRCVE9uIEVTUDMyIGJvYXJkcywgZW5hYmxpbmcgRXRoZXJuZXQgd2lsbCBkaXNh'
    'YmxlIHRoZSBCbHVldG9vdGggY29ubmVjdGlvbiB0byB0aGUgYXBwLlIKZXRoRW5hYmxlZBJjCg'
    'xhZGRyZXNzX21vZGUYByABKA4yLC5tZXNodGFzdGljLkNvbmZpZy5OZXR3b3JrQ29uZmlnLkFk'
    'ZHJlc3NNb2RlQhLK8xgOOgxBZGRyZXNzIE1vZGVSC2FkZHJlc3NNb2RlEkwKC2lwdjRfY29uZm'
    'lnGAggASgLMisubWVzaHRhc3RpYy5Db25maWcuTmV0d29ya0NvbmZpZy5JcFY0Q29uZmlnUgpp'
    'cHY0Q29uZmlnEjsKDnJzeXNsb2dfc2VydmVyGAkgASgJQhTK8xgQOg5Sc3lzbG9nIFNlcnZlcl'
    'INcnN5c2xvZ1NlcnZlchKIAQoRZW5hYmxlZF9wcm90b2NvbHMYCiABKA1CW8rzGFc6EUVuYWJs'
    'ZWQgUHJvdG9jb2xzQjtFbmFibGUgYnJvYWRjYXN0aW5nIHBhY2tldHMgdmlhIFVEUCBvdmVyIH'
    'RoZSBsb2NhbCBuZXR3b3JrLlIFMi42LjBSEGVuYWJsZWRQcm90b2NvbHMSLwoMaXB2Nl9lbmFi'
    'bGVkGAsgASgIQgzK8xgIUgYyLjcuMTZSC2lwdjZFbmFibGVkGpIBCgpJcFY0Q29uZmlnEhgKAm'
    'lwGAEgASgHQgjK8xgEOgJJUFICaXASJwoHZ2F0ZXdheRgCIAEoB0INyvMYCToHR2F0ZXdheVIH'
    'Z2F0ZXdheRIkCgZzdWJuZXQYAyABKAdCDMrzGAg6BlN1Ym5ldFIGc3VibmV0EhsKA2RucxgEIA'
    'EoB0IJyvMYBToDRE5TUgNkbnMiPQoLQWRkcmVzc01vZGUSFAoEREhDUBAAGgrK8xgGOgRESENQ'
    'EhgKBlNUQVRJQxABGgzK8xgIOgZTdGF0aWMiVQoNUHJvdG9jb2xGbGFncxIcCgxOT19CUk9BRE'
    'NBU1QQABoKyvMYBjoETm9uZRImCg1VRFBfQlJPQURDQVNUEAEaE8rzGA86DVVEUCBCcm9hZGNh'
    'c3Qa2RQKDURpc3BsYXlDb25maWcSlwEKDnNjcmVlbl9vbl9zZWNzGAEgASgNQnHK8xhtKgFzOg'
    '1TY3JlZW4gb24gZm9yQllIb3cgbG9uZyB0aGUgc2NyZWVuIHJlbWFpbnMgb24gYWZ0ZXIgdGhl'
    'IHVzZXIgYnV0dG9uIGlzIHByZXNzZWQgb3IgbWVzc2FnZXMgYXJlIHJlY2VpdmVkLlIMc2NyZW'
    'VuT25TZWNzEm0KCmdwc19mb3JtYXQYAiABKA4yPi5tZXNodGFzdGljLkNvbmZpZy5EaXNwbGF5'
    'Q29uZmlnLkRlcHJlY2F0ZWRHcHNDb29yZGluYXRlRm9ybWF0Qg4YAcrzGAhaBjIuNy4xMFIJZ3'
    'BzRm9ybWF0EqYBChlhdXRvX3NjcmVlbl9jYXJvdXNlbF9zZWNzGAMgASgNQmvK8xhnKgFzOhFD'
    'YXJvdXNlbCBJbnRlcnZhbEJPQXV0b21hdGljYWxseSBtb3ZlcyB0byB0aGUgbmV4dCBzY3JlZW'
    '4gcGFnZSwgbGlrZSBhIGNhcm91c2VsLCBvbiB0aGlzIGludGVydmFsLlIWYXV0b1NjcmVlbkNh'
    'cm91c2VsU2VjcxKfAQoRY29tcGFzc19ub3J0aF90b3AYBCABKAhCcxgByvMYbToSQWx3YXlzIH'
    'BvaW50IG5vcnRoQlBUaGUgY29tcGFzcyBoZWFkaW5nIG9uIHRoZSBzY3JlZW4gb3V0c2lkZSBv'
    'ZiB0aGUgY2lyY2xlIHdpbGwgYWx3YXlzIHBvaW50IG5vcnRoLloFMi43LjFSD2NvbXBhc3NOb3'
    'J0aFRvcBJKCgtmbGlwX3NjcmVlbhgFIAEoCEIpyvMYJToLRmxpcCBTY3JlZW5CFkZsaXAgc2Ny'
    'ZWVuIHZlcnRpY2FsbHlSCmZsaXBTY3JlZW4SewoFdW5pdHMYBiABKA4yLS5tZXNodGFzdGljLk'
    'NvbmZpZy5EaXNwbGF5Q29uZmlnLkRpc3BsYXlVbml0c0I2yvMYMjoNRGlzcGxheSBVbml0c0Ih'
    'VW5pdHMgc2hvd24gb24gdGhlIGRldmljZSBzY3JlZW4uUgV1bml0cxJ5CgRvbGVkGAcgASgOMi'
    'kubWVzaHRhc3RpYy5Db25maWcuRGlzcGxheUNvbmZpZy5PbGVkVHlwZUI6yvMYNjoJT0xFRCBU'
    'eXBlQilPdmVycmlkZSBhdXRvbWF0aWMgT0xFRCBzY3JlZW4gZGV0ZWN0aW9uLlIEb2xlZBKDAQ'
    'oLZGlzcGxheW1vZGUYCCABKA4yLC5tZXNodGFzdGljLkNvbmZpZy5EaXNwbGF5Q29uZmlnLkRp'
    'c3BsYXlNb2RlQjPK8xgvOgxEaXNwbGF5IE1vZGVCH092ZXJyaWRlIGRlZmF1bHQgc2NyZWVuIG'
    'xheW91dC5SC2Rpc3BsYXltb2RlElsKDGhlYWRpbmdfYm9sZBgJIAEoCEI4yvMYNDoMQm9sZCBI'
    'ZWFkaW5nQiRCb2xkIHRoZSBoZWFkaW5nIHRleHQgb24gdGhlIHNjcmVlbi5SC2hlYWRpbmdCb2'
    'xkEo0BChV3YWtlX29uX3RhcF9vcl9tb3Rpb24YCiABKAhCW8rzGFc6HFdha2UgU2NyZWVuIG9u'
    'IHRhcCBvciBtb3Rpb25CN1JlcXVpcmVzIHRoYXQgdGhlcmUgYmUgYW4gYWNjZWxlcm9tZXRlci'
    'BvbiB5b3VyIGRldmljZS5SEXdha2VPblRhcE9yTW90aW9uEssBChNjb21wYXNzX29yaWVudGF0'
    'aW9uGAsgASgOMjMubWVzaHRhc3RpYy5Db25maWcuRGlzcGxheUNvbmZpZy5Db21wYXNzT3JpZW'
    '50YXRpb25CZcrzGGE6E0NvbXBhc3MgT3JpZW50YXRpb25CSkluZGljYXRlcyBob3cgdG8gcm90'
    'YXRlIG9yIGludmVydCB0aGUgY29tcGFzcyBvdXRwdXQgZm9yIGFjY3VyYXRlIGRpc3BsYXkuUh'
    'Jjb21wYXNzT3JpZW50YXRpb24SaQoNdXNlXzEyaF9jbG9jaxgMIAEoCEJFyvMYQToNMTIgSG91'
    'ciBDbG9ja0IoU2V0cyB0aGUgc2NyZWVuIGNsb2NrIGZvcm1hdCB0byAxMi1ob3VyLlIGMi41Lj'
    'IyUgt1c2UxMmhDbG9jaxI5ChJ1c2VfbG9uZ19ub2RlX25hbWUYDSABKAhCDMrzGAhSBjIuNy4x'
    'M1IPdXNlTG9uZ05vZGVOYW1lEkIKFmVuYWJsZV9tZXNzYWdlX2J1YmJsZXMYDiABKAhCDMrzGA'
    'hSBjIuNy4xOVIUZW5hYmxlTWVzc2FnZUJ1YmJsZXMiKwodRGVwcmVjYXRlZEdwc0Nvb3JkaW5h'
    'dGVGb3JtYXQSCgoGVU5VU0VEEAAiRgoMRGlzcGxheVVuaXRzEhgKBk1FVFJJQxAAGgzK8xgIOg'
    'ZNZXRyaWMSHAoISU1QRVJJQUwQARoOyvMYCjoISW1wZXJpYWwi8gEKCE9sZWRUeXBlEikKCU9M'
    'RURfQVVUTxAAGhrK8xgWOhREZXRlY3QgQXV0b21hdGljYWxseRIfCgxPTEVEX1NTRDEzMDYQAR'
    'oNyvMYCToHU1NEMTMwNhIdCgtPTEVEX1NIMTEwNhACGgzK8xgIOgZTSDExMDYSHQoLT0xFRF9T'
    'SDExMDcQAxoMyvMYCDoGU0gxMTA3Ei0KE09MRURfU0gxMTA3XzEyOF8xMjgQBBoUyvMYEDoOU0'
    'gxMTA3IDEyOHgxMjgSLQoTT0xFRF9TSDExMDdfUk9UQVRFRBAFGhTK8xgQOg5TSDExMDcgUm90'
    'YXRlZCLXAQoLRGlzcGxheU1vZGUSLwoHREVGQVVMVBAAGiLK8xgeOhxEZWZhdWx0IDEyOHg2NC'
    'BzY3JlZW4gbGF5b3V0EjIKCFRXT0NPTE9SEAEaJMrzGCA6Hk9wdGltaXplZCBmb3IgMiBjb2xv'
    'ciBkaXNwbGF5cxI5CghJTlZFUlRFRBACGivK8xgnOiVJbnZlcnRlZCB0b3AgYmFyIGZvciAyIG'
    'NvbG9yIGRpc3BsYXlzEigKBUNPTE9SEAMaHcrzGBk6F1RGVCBGdWxsIENvbG9yIERpc3BsYXlz'
    'IsACChJDb21wYXNzT3JpZW50YXRpb24SGAoJREVHUkVFU18wEAAaCcrzGAU6AzDCsBIaCgpERU'
    'dSRUVTXzkwEAEaCsrzGAY6BDkwwrASHAoLREVHUkVFU18xODAQAhoLyvMYBzoFMTgwwrASHAoL'
    'REVHUkVFU18yNzAQAxoLyvMYBzoFMjcwwrASKgoSREVHUkVFU18wX0lOVkVSVEVEEAQaEsrzGA'
    '46DDDCsCBJbnZlcnRlZBIsChNERUdSRUVTXzkwX0lOVkVSVEVEEAUaE8rzGA86DTkwwrAgSW52'
    'ZXJ0ZWQSLgoUREVHUkVFU18xODBfSU5WRVJURUQQBhoUyvMYEDoOMTgwwrAgSW52ZXJ0ZWQSLg'
    'oUREVHUkVFU18yNzBfSU5WRVJURUQQBxoUyvMYEDoOMjcwwrAgSW52ZXJ0ZWQajyMKCkxvUmFD'
    'b25maWcSiwEKCnVzZV9wcmVzZXQYASABKAhCbMrzGGg6ClVzZSBQcmVzZXRCWlVzZSB0aGUgbW'
    '9kZW0gcHJlc2V0IHNldHRpbmdzIGluc3RlYWQgb2YgYSBtYW51YWwgYmFuZHdpZHRoLCBzcHJl'
    'YWQgZmFjdG9yIGFuZCBjb2RpbmcgcmF0ZVIJdXNlUHJlc2V0ElsKDG1vZGVtX3ByZXNldBgCIA'
    'EoDjIpLm1lc2h0YXN0aWMuQ29uZmlnLkxvUmFDb25maWcuTW9kZW1QcmVzZXRCDcrzGAk6B1By'
    'ZXNldHNSC21vZGVtUHJlc2V0EjIKCWJhbmR3aWR0aBgDIAEoDUIUyvMYECoDa0h6OglCYW5kd2'
    'lkdGhSCWJhbmR3aWR0aBKDAQoNc3ByZWFkX2ZhY3RvchgEIAEoDUJeyvMYWhkAAAAAAAAUQCEA'
    'AAAAAAAoQDoNU3ByZWFkIEZhY3RvckI3TnVtYmVyIG9mIGNoaXJwcyBwZXIgc3ltYm9sLCBhcy'
    'AyIHJhaXNlZCB0byB0aGlzIHZhbHVlLlIMc3ByZWFkRmFjdG9yEq8BCgtjb2RpbmdfcmF0ZRgF'
    'IAEoDUKNAcrzGIgBOgtDb2RpbmcgUmF0ZUJ5RXJyb3ItY29ycmVjdGlvbiByZWR1bmRhbmN5LC'
    'BhcyB0aGUgZGVub21pbmF0b3Igb2YgNC9uLiBIaWdoZXIgdmFsdWVzIHN1cnZpdmUgbm9pc2ll'
    'ciBsaW5rcyBidXQgbWFrZSBldmVyeSBwYWNrZXQgbG9uZ2VyLlIKY29kaW5nUmF0ZRIpChBmcm'
    'VxdWVuY3lfb2Zmc2V0GAYgASgCUg9mcmVxdWVuY3lPZmZzZXQSfwoGcmVnaW9uGAcgASgOMigu'
    'bWVzaHRhc3RpYy5Db25maWcuTG9SYUNvbmZpZy5SZWdpb25Db2RlQj3K8xg5OgZSZWdpb25CL1'
    'RoZSByZWdpb24gd2hlcmUgeW91IHdpbGwgYmUgdXNpbmcgeW91ciByYWRpb3MuUgZyZWdpb24S'
    'pwEKCWhvcF9saW1pdBgIIAEoDUKJAcrzGIQBGQAAAAAAAAAAIQAAAAAAABxAOglIb3AgTGltaX'
    'RCSUhvdyBtYW55IHRpbWVzIGEgbWVzc2FnZSBtYXkgYmUgcmVwZWF0ZWQgYmVmb3JlIGl0IHN0'
    'b3BzIGJlaW5nIGZvcndhcmRlZC5KGmhvcHN8dHRsfHJhbmdlfHJlYnJvYWRjYXN0Ughob3BMaW'
    '1pdBKPAQoKdHhfZW5hYmxlZBgJIAEoCEJwyvMYbDoQVHJhbnNtaXQgRW5hYmxlZEJYQWxsb3cg'
    'dGhlIExvUmEgcmFkaW8gdG8gdHJhbnNtaXQuIFR1cm4gb2ZmIHdoaWxlIGhvdC1zd2FwcGluZy'
    'BhbnRlbm5hcyBvciBiZW5jaCB0ZXN0aW5nLlIJdHhFbmFibGVkEtcBCgh0eF9wb3dlchgKIAEo'
    'BUK7AcrzGLYBGQAAAAAAAAAAIQAAAAAAAEJAKgNkQm06DlRyYW5zbWl0IFBvd2VyQnhSYWRpby'
    'B0cmFuc21pdCBwb3dlci4gTGVhdmUgYXQgemVybyB0byB1c2UgdGhlIGhpZ2hlc3QgbGV2ZWwg'
    'bGVnYWwgZm9yIHRoZSByZWdpb24sIHdoaWNoIGlzIHdoYXQgbW9zdCByYWRpb3Mgc2hvdWxkIH'
    'VzZS5KE3R4fHBvd2VyfGRibXxvdXRwdXRSB3R4UG93ZXIS5AEKC2NoYW5uZWxfbnVtGAsgASgN'
    'QsIByvMYvQE6DkZyZXF1ZW5jeSBTbG90QqoBWW91ciBub2RlJ3Mgb3BlcmF0aW5nIGZyZXF1ZW'
    '5jeSBpcyBjYWxjdWxhdGVkIGJhc2VkIG9uIHRoZSByZWdpb24sIG1vZGVtIHByZXNldCwgYW5k'
    'IHRoaXMgZmllbGQuIFdoZW4gMCwgdGhlIHJlZ2lvbiBwaWNrcyB0aGUgc2xvdCwgdXN1YWxseS'
    'Bmcm9tIHRoZSBwcmltYXJ5IGNoYW5uZWwgbmFtZS5SCmNoYW5uZWxOdW0SSQoTb3ZlcnJpZGVf'
    'ZHV0eV9jeWNsZRgMIAEoCEIZyvMYFToTT3ZlcnJpZGUgRHV0eSBDeWNsZVIRb3ZlcnJpZGVEdX'
    'R5Q3ljbGUSfwoWc3gxMjZ4X3J4X2Jvb3N0ZWRfZ2FpbhgNIAEoCEJKyvMYRjoPUlggQm9vc3Rl'
    'ZCBHYWluQjNFbmFibGUgUlggYm9vc3RlZCBnYWluIG1vZGUgb24gU1gxMjZ4LWJhc2VkIHJhZG'
    'lvcy5SE3N4MTI2eFJ4Qm9vc3RlZEdhaW4STAoSb3ZlcnJpZGVfZnJlcXVlbmN5GA4gASgCQh3K'
    '8xgZKgNNSHo6EkZyZXF1ZW5jeSBPdmVycmlkZVIRb3ZlcnJpZGVGcmVxdWVuY3kSPQoPcGFfZm'
    'FuX2Rpc2FibGVkGA8gASgIQhXK8xgROg9QQSBGYW4gRGlzYWJsZWRSDXBhRmFuRGlzYWJsZWQS'
    'PgoPaWdub3JlX2luY29taW5nGGcgAygNQhXK8xgROg9JZ25vcmUgSW5jb21pbmdSDmlnbm9yZU'
    'luY29taW5nEoUBCgtpZ25vcmVfbXF0dBhoIAEoCEJkyvMYYDoLSWdub3JlIE1RVFRCUUlnbm9y'
    'ZSBwYWNrZXRzIHJlY2VpdmVkIG92ZXIgTG9SYSB0aGF0IHRyYXZlbGxlZCB2aWEgTVFUVCBhbn'
    'l3aGVyZSBvbiB0aGVpciBwYXRoLlIKaWdub3JlTXF0dBI7ChFjb25maWdfb2tfdG9fbXF0dBhp'
    'IAEoCEIQyvMYDDoKT0sgdG8gTVFUVFIOY29uZmlnT2tUb01xdHQSWgoMZmVtX2xuYV9tb2RlGG'
    'ogASgOMioubWVzaHRhc3RpYy5Db25maWcuTG9SYUNvbmZpZy5GRU1fTE5BX01vZGVCDMrzGAhS'
    'BjIuNy4yMFIKZmVtTG5hTW9kZRImCg9zZXJpYWxfaGFsX29ubHkYayABKAhSDXNlcmlhbEhhbE'
    '9ubHkihgsKClJlZ2lvbkNvZGUSJAoFVU5TRVQQABoZyvMYFToTUGxlYXNlIHNldCBhIHJlZ2lv'
    'bhIbCgJVUxABGhPK8xgPOg1Vbml0ZWQgU3RhdGVzEicKBkVVXzQzMxACGhvK8xgXOhVFdXJvcG'
    'VhbiBVbmlvbiA0MzNNSHoSJwoGRVVfODY4EAMaG8rzGBc6FUV1cm9wZWFuIFVuaW9uIDg2OE1I'
    'ehITCgJDThAEGgvK8xgHOgVDaGluYRITCgJKUBAFGgvK8xgHOgVKYXBhbhImCgNBTloQBhodyv'
    'MYGToXQXVzdHJhbGlhIC8gTmV3IFplYWxhbmQSEwoCS1IQBxoLyvMYBzoFS29yZWESFAoCVFcQ'
    'CBoMyvMYCDoGVGFpd2FuEhQKAlJVEAkaDMrzGAg6BlJ1c3NpYRITCgJJThAKGgvK8xgHOgVJbm'
    'RpYRIkCgZOWl84NjUQCxoYyvMYFDoSTmV3IFplYWxhbmQgODY1TUh6EhYKAlRIEAwaDsrzGAo6'
    'CFRoYWlsYW5kEhoKB0xPUkFfMjQQDRoNyvMYCToHMi40IEdIehIgCgZVQV80MzMQDhoUyvMYED'
    'oOVWtyYWluZSA0MzNNSHoSIgoGVUFfODY4EA8aFggByvMYEDoOVWtyYWluZSA4NjhNSHoSIQoG'
    'TVlfNDMzEBAaFcrzGBE6D01hbGF5c2lhIDQzM01IehIhCgZNWV85MTkQERoVyvMYEToPTWFsYX'
    'lzaWEgOTE5TUh6EiIKBlNHXzkyMxASGhbK8xgSOhBTaW5nYXBvcmUgOTIzTUh6EiQKBlBIXzQz'
    'MxATGhjK8xgUOhJQaGlsaXBwaW5lcyA0MzNNSHoSJAoGUEhfODY4EBQaGMrzGBQ6ElBoaWxpcH'
    'BpbmVzIDg2OE1IehIkCgZQSF85MTUQFRoYyvMYFDoSUGhpbGlwcGluZXMgOTE1TUh6EjEKB0FO'
    'Wl80MzMQFhokyvMYIDoeQXVzdHJhbGlhIC8gTmV3IFplYWxhbmQgNDMzTUh6EiMKBktaXzQzMx'
    'AXGhfK8xgTOhFLYXpha2hzdGFuIDQzM01IehIjCgZLWl84NjMQGBoXyvMYEzoRS2F6YWtoc3Rh'
    'biA4NjNNSHoSHgoGTlBfODY1EBkaEsrzGA46DE5lcGFsIDg2NU1IehIfCgZCUl85MDIQGhoTyv'
    'MYDzoNQnJhemlsIDkwMk1IehIsCgdJVFUxXzJNEBsaH8rzGBs6GUlUVSBSZWdpb24gMSAvIEFt'
    'YXRldXIgMm0SLAoHSVRVMl8yTRAcGh/K8xgbOhlJVFUgUmVnaW9uIDIgLyBBbWF0ZXVyIDJtEi'
    'cKBkVVXzg2NhAdGhvK8xgXOhVFdXJvcGVhbiBVbmlvbiA4NjZNSHoSJwoGRVVfODc0EB4aG8rz'
    'GBc6FUV1cm9wZWFuIFVuaW9uIDg3NE1IehInCgZFVV85MTcQHxobyvMYFzoVRXVyb3BlYW4gVW'
    '5pb24gOTE3TUh6EjIKCEVVX05fODY4ECAaJMrzGCA6HkV1cm9wZWFuIFVuaW9uIDg2OE1IeiAo'
    'TmFycm93KRIsCgdJVFUzXzJNECEaH8rzGBs6GUlUVSBSZWdpb24gMyAvIEFtYXRldXIgMm0SMA'
    'oJSVRVMV83MENNECIaIcrzGB06G0lUVSBSZWdpb24gMSAvIEFtYXRldXIgNzBjbRIwCglJVFUy'
    'XzcwQ00QIxohyvMYHTobSVRVIFJlZ2lvbiAyIC8gQW1hdGV1ciA3MGNtEjAKCUlUVTNfNzBDTR'
    'AkGiHK8xgdOhtJVFUgUmVnaW9uIDMgLyBBbWF0ZXVyIDcwY20SMgoKSVRVMl8xMjVDTRAlGiLK'
    '8xgeOhxJVFUgUmVnaW9uIDIgLyBBbWF0ZXVyIDEuMjVtItkFCgtNb2RlbVByZXNldBI4CglMT0'
    '5HX0ZBU1QQABopyvMYJToRTG9uZyBSYW5nZSAtIEZhc3RKEGxvbmdmYXN0fGRlZmF1bHQSKAoJ'
    'TE9OR19TTE9XEAEaGQgByvMYEzoRTG9uZyBSYW5nZSAtIFNsb3cSMgoOVkVSWV9MT05HX1NMT1'
    'cQAhoeCAHK8xgYOhZWZXJ5IExvbmcgUmFuZ2UgLSBTbG93EioKC01FRElVTV9TTE9XEAMaGcrz'
    'GBU6E01lZGl1bSBSYW5nZSAtIFNsb3cSKgoLTUVESVVNX0ZBU1QQBBoZyvMYFToTTWVkaXVtIF'
    'JhbmdlIC0gRmFzdBIoCgpTSE9SVF9TTE9XEAUaGMrzGBQ6ElNob3J0IFJhbmdlIC0gU2xvdxIo'
    'CgpTSE9SVF9GQVNUEAYaGMrzGBQ6ElNob3J0IFJhbmdlIC0gRmFzdBIuCg1MT05HX01PREVSQV'
    'RFEAcaG8rzGBc6FUxvbmcgUmFuZ2UgLSBNb2RlcmF0ZRIqCgtTSE9SVF9UVVJCTxAIGhnK8xgV'
    'OhNTaG9ydCBSYW5nZSAtIFR1cmJvEigKCkxPTkdfVFVSQk8QCRoYyvMYFDoSTG9uZyBSYW5nZS'
    'AtIFR1cmJvEiAKCUxJVEVfRkFTVBAKGhHK8xgNOgtMaXRlIC0gRmFzdBIgCglMSVRFX1NMT1cQ'
    'CxoRyvMYDToLTGl0ZSAtIFNsb3cSJAoLTkFSUk9XX0ZBU1QQDBoTyvMYDzoNTmFycm93IC0gRm'
    'FzdBIkCgtOQVJST1dfU0xPVxANGhPK8xgPOg1OYXJyb3cgLSBTbG93EiAKCVRJTllfRkFTVBAO'
    'GhHK8xgNOgtUaW55IC0gRmFzdBIgCglUSU5ZX1NMT1cQDxoRyvMYDToLVGlueSAtIFNsb3cSLA'
    'oMTUVESVVNX1RVUkJPEBAaGsrzGBY6FE1lZGl1bSBSYW5nZSAtIFR1cmJvIjoKDEZFTV9MTkFf'
    'TW9kZRIMCghESVNBQkxFRBAAEgsKB0VOQUJMRUQQARIPCgtOT1RfUFJFU0VOVBACGssDCg9CbH'
    'VldG9vdGhDb25maWcSUQoHZW5hYmxlZBgBIAEoCEI3yvMYMzoRQmx1ZXRvb3RoIEVuYWJsZWRC'
    'HkVuYWJsZSBCbHVldG9vdGggb24gdGhlIGRldmljZVIHZW5hYmxlZBJyCgRtb2RlGAIgASgOMi'
    '4ubWVzaHRhc3RpYy5Db25maWcuQmx1ZXRvb3RoQ29uZmlnLlBhaXJpbmdNb2RlQi7K8xgqOgxQ'
    'YWlyaW5nIE1vZGVCGkJsdWV0b290aCBwYWlyaW5nIHN0cmF0ZWd5UgRtb2RlEnkKCWZpeGVkX3'
    'BpbhgDIAEoDUJcyvMYWDoJRml4ZWQgUGluQktGaXhlZCBQSU4gZm9yIEJsdWV0b290aCBwYWly'
    'aW5nLiBVc2VkIHdoZW4gcGFpcmluZyBtb2RlIGlzIHNldCB0byBmaXhlZCBQSU5SCGZpeGVkUG'
    'luInYKC1BhaXJpbmdNb2RlEiAKClJBTkRPTV9QSU4QABoQyvMYDDoKUmFuZG9tIFBJThIeCglG'
    'SVhFRF9QSU4QARoPyvMYCzoJRml4ZWQgUElOEiUKBk5PX1BJThACGhnK8xgVOhNObyBQSU4gKE'
    'p1c3QgV29ya3MpGt4MCg5TZWN1cml0eUNvbmZpZxKnAQoKcHVibGljX2tleRgBIAEoDEKHAcrz'
    'GIIBOgpQdWJsaWMgS2V5QnRHZW5lcmF0ZWQgZnJvbSB5b3VyIHByaXZhdGUga2V5IGFuZCBzZW'
    '50IG91dCB0byBvdGhlciBub2RlcyBvbiB0aGUgbWVzaCB0byBhbGxvdyB0aGVtIHRvIGNvbXB1'
    'dGUgYSBzaGFyZWQgc2VjcmV0IGtleVIJcHVibGljS2V5EmQKC3ByaXZhdGVfa2V5GAIgASgMQk'
    'PK8xg/OgtQcml2YXRlIEtleUIwVXNlZCB0byBjcmVhdGUgYSBzaGFyZWQga2V5IHdpdGggYSBy'
    'ZW1vdGUgZGV2aWNlUgpwcml2YXRlS2V5EncKCWFkbWluX2tleRgDIAMoDEJayvMYVjoJQWRtaW'
    '4gS2V5QklQdWJsaWMga2V5cyAodXAgdG8gdGhyZWUpIGF1dGhvcml6ZWQgdG8gc2VuZCBhZG1p'
    'biBtZXNzYWdlcyB0byB0aGlzIG5vZGUuUghhZG1pbktleRKtAQoKaXNfbWFuYWdlZBgEIAEoCE'
    'KNAcrzGIgBOg5NYW5hZ2VkIERldmljZUJ2U2V0dGluZ3MgYXJlIGNoYW5nZWQgYnkgYSBtZXNo'
    'IGFkbWluaXN0cmF0b3IgdXNpbmcgYW4gYWRtaW4ga2V5LCBub3QgZnJvbSB0aGUgbG9jYWwgYX'
    'BwLiBOZWVkcyBhdCBsZWFzdCBvbmUgYWRtaW4ga2V5LlIJaXNNYW5hZ2VkEmAKDnNlcmlhbF9l'
    'bmFibGVkGAUgASgIQjnK8xg1Og5TZXJpYWwgQ29uc29sZUIjU2VyaWFsIENvbnNvbGUgb3Zlci'
    'B0aGUgU3RyZWFtIEFQSS5SDXNlcmlhbEVuYWJsZWQSqQEKFWRlYnVnX2xvZ19hcGlfZW5hYmxl'
    'ZBgGIAEoCEJ2yvMYcjoKRGVidWcgTG9nc0JkT3V0cHV0IGxpdmUgZGVidWcgbG9nZ2luZyBvdm'
    'VyIHNlcmlhbCwgdmlldyBhbmQgZXhwb3J0IHBvc2l0aW9uLXJlZGFjdGVkIGRldmljZSBsb2dz'
    'IG92ZXIgQmx1ZXRvb3RoLlISZGVidWdMb2dBcGlFbmFibGVkEjIKFWFkbWluX2NoYW5uZWxfZW'
    '5hYmxlZBgIIAEoCFITYWRtaW5DaGFubmVsRW5hYmxlZBJ8ChdwYWNrZXRfc2lnbmF0dXJlX3Bv'
    'bGljeRgJIAEoDjI3Lm1lc2h0YXN0aWMuQ29uZmlnLlNlY3VyaXR5Q29uZmlnLlBhY2tldFNpZ2'
    '5hdHVyZVBvbGljeUILyvMYB1IFMi44LjBSFXBhY2tldFNpZ25hdHVyZVBvbGljeSLSBAoVUGFj'
    'a2V0U2lnbmF0dXJlUG9saWN5EsUBCiJQQUNLRVRfU0lHTkFUVVJFX1BPTElDWV9DT01QQVRJQk'
    'xFEAAanAHK8xiXATocQ29tcGF0aWJsZSAtIEFjY2VwdCBVbnNpZ25lZEJ3QWNjZXB0IHVuc2ln'
    'bmVkIHRyYWZmaWMgZm9yIG1heGltdW0gY29tcGF0aWJpbGl0eS4gQSBzaWduYXR1cmUgdGhhdC'
    'BjYW4gYmUgY2hlY2tlZCBhbmQgaXMgd3Jvbmcgc3RpbGwgZHJvcHMgdGhlIHBhY2tldC4SrAEK'
    'IFBBQ0tFVF9TSUdOQVRVUkVfUE9MSUNZX0JBTEFOQ0VEEAEahQHK8xiAATofQmFsYW5jZWQgLS'
    'BQcmVmZXIgQXV0aGVudGljYXRlZEJdUHJlZmVyIGF1dGhlbnRpY2F0ZWQgcGFja2V0cywgYnV0'
    'IHN0aWxsIGFjY2VwdCB1bnNpZ25lZCB0cmFmZmljIGZyb20gbm9kZXMgbm90IGtub3duIHRvIH'
    'NpZ24uEsEBCh5QQUNLRVRfU0lHTkFUVVJFX1BPTElDWV9TVFJJQ1QQAhqcAcrzGJcBOh9TdHJp'
    'Y3QgLSBSZXF1aXJlIEF1dGhlbnRpY2F0aW9uQnRBY2NlcHQgb25seSBwYWNrZXRzIHdpdGggYS'
    'B2ZXJpZmllZCBzaWduYXR1cmUgb3Igc3VjY2Vzc2Z1bCBQS0kgZGVjcnlwdGlvbi4gUGFja2V0'
    'cyBmcm9tIG9sZGVyIG5vZGVzIG1heSBiZSBpZ25vcmVkLhoSChBTZXNzaW9ua2V5Q29uZmlnQh'
    'EKD3BheWxvYWRfdmFyaWFudA==');
