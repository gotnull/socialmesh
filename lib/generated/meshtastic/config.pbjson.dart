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
    {'1': 'button_gpio', '3': 4, '4': 1, '5': 13, '10': 'buttonGpio'},
    {'1': 'buzzer_gpio', '3': 5, '4': 1, '5': 13, '10': 'buzzerGpio'},
    {
      '1': 'rebroadcast_mode',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.DeviceConfig.RebroadcastMode',
      '10': 'rebroadcastMode'
    },
    {
      '1': 'node_info_broadcast_secs',
      '3': 7,
      '4': 1,
      '5': 13,
      '10': 'nodeInfoBroadcastSecs'
    },
    {
      '1': 'double_tap_as_button_press',
      '3': 8,
      '4': 1,
      '5': 8,
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
      '10': 'disableTripleClick'
    },
    {'1': 'tzdef', '3': 11, '4': 1, '5': 9, '10': 'tzdef'},
    {
      '1': 'led_heartbeat_disabled',
      '3': 12,
      '4': 1,
      '5': 8,
      '10': 'ledHeartbeatDisabled'
    },
    {
      '1': 'buzzer_mode',
      '3': 13,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.DeviceConfig.BuzzerMode',
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
    {'1': 'CLIENT', '2': 0},
    {'1': 'CLIENT_MUTE', '2': 1},
    {'1': 'ROUTER', '2': 2},
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
    {'1': 'TRACKER', '2': 5},
    {'1': 'SENSOR', '2': 6},
    {'1': 'TAK', '2': 7},
    {'1': 'CLIENT_HIDDEN', '2': 8},
    {'1': 'LOST_AND_FOUND', '2': 9},
    {'1': 'TAK_TRACKER', '2': 10},
    {'1': 'ROUTER_LATE', '2': 11},
    {'1': 'CLIENT_BASE', '2': 12},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_DeviceConfig_RebroadcastMode$json = {
  '1': 'RebroadcastMode',
  '2': [
    {'1': 'ALL', '2': 0},
    {'1': 'ALL_SKIP_DECODING', '2': 1},
    {'1': 'LOCAL_ONLY', '2': 2},
    {'1': 'KNOWN_ONLY', '2': 3},
    {'1': 'NONE', '2': 4},
    {'1': 'CORE_PORTNUMS_ONLY', '2': 5},
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
      '10': 'positionBroadcastSecs'
    },
    {
      '1': 'position_broadcast_smart_enabled',
      '3': 2,
      '4': 1,
      '5': 8,
      '10': 'positionBroadcastSmartEnabled'
    },
    {'1': 'fixed_position', '3': 3, '4': 1, '5': 8, '10': 'fixedPosition'},
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
    {'1': 'position_flags', '3': 7, '4': 1, '5': 13, '10': 'positionFlags'},
    {'1': 'rx_gpio', '3': 8, '4': 1, '5': 13, '10': 'rxGpio'},
    {'1': 'tx_gpio', '3': 9, '4': 1, '5': 13, '10': 'txGpio'},
    {
      '1': 'broadcast_smart_minimum_distance',
      '3': 10,
      '4': 1,
      '5': 13,
      '10': 'broadcastSmartMinimumDistance'
    },
    {
      '1': 'broadcast_smart_minimum_interval_secs',
      '3': 11,
      '4': 1,
      '5': 13,
      '10': 'broadcastSmartMinimumIntervalSecs'
    },
    {'1': 'gps_en_gpio', '3': 12, '4': 1, '5': 13, '10': 'gpsEnGpio'},
    {
      '1': 'gps_mode',
      '3': 13,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.PositionConfig.GpsMode',
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
    {'1': 'ALTITUDE', '2': 1},
    {'1': 'ALTITUDE_MSL', '2': 2},
    {'1': 'GEOIDAL_SEPARATION', '2': 4},
    {'1': 'DOP', '2': 8},
    {'1': 'HVDOP', '2': 16},
    {'1': 'SATINVIEW', '2': 32},
    {'1': 'SEQ_NO', '2': 64},
    {'1': 'TIMESTAMP', '2': 128},
    {'1': 'HEADING', '2': 256},
    {'1': 'SPEED', '2': 512},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_PositionConfig_GpsMode$json = {
  '1': 'GpsMode',
  '2': [
    {'1': 'DISABLED', '2': 0},
    {'1': 'ENABLED', '2': 1},
    {'1': 'NOT_PRESENT', '2': 2},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_PowerConfig$json = {
  '1': 'PowerConfig',
  '2': [
    {'1': 'is_power_saving', '3': 1, '4': 1, '5': 8, '10': 'isPowerSaving'},
    {
      '1': 'on_battery_shutdown_after_secs',
      '3': 2,
      '4': 1,
      '5': 13,
      '10': 'onBatteryShutdownAfterSecs'
    },
    {
      '1': 'adc_multiplier_override',
      '3': 3,
      '4': 1,
      '5': 2,
      '10': 'adcMultiplierOverride'
    },
    {
      '1': 'wait_bluetooth_secs',
      '3': 4,
      '4': 1,
      '5': 13,
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
    {'1': 'wifi_enabled', '3': 1, '4': 1, '5': 8, '10': 'wifiEnabled'},
    {'1': 'wifi_ssid', '3': 3, '4': 1, '5': 9, '10': 'wifiSsid'},
    {'1': 'wifi_psk', '3': 4, '4': 1, '5': 9, '10': 'wifiPsk'},
    {'1': 'ntp_server', '3': 5, '4': 1, '5': 9, '10': 'ntpServer'},
    {'1': 'eth_enabled', '3': 6, '4': 1, '5': 8, '10': 'ethEnabled'},
    {
      '1': 'address_mode',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.NetworkConfig.AddressMode',
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
    {'1': 'rsyslog_server', '3': 9, '4': 1, '5': 9, '10': 'rsyslogServer'},
    {
      '1': 'enabled_protocols',
      '3': 10,
      '4': 1,
      '5': 13,
      '10': 'enabledProtocols'
    },
    {'1': 'ipv6_enabled', '3': 11, '4': 1, '5': 8, '10': 'ipv6Enabled'},
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
    {'1': 'ip', '3': 1, '4': 1, '5': 7, '10': 'ip'},
    {'1': 'gateway', '3': 2, '4': 1, '5': 7, '10': 'gateway'},
    {'1': 'subnet', '3': 3, '4': 1, '5': 7, '10': 'subnet'},
    {'1': 'dns', '3': 4, '4': 1, '5': 7, '10': 'dns'},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_NetworkConfig_AddressMode$json = {
  '1': 'AddressMode',
  '2': [
    {'1': 'DHCP', '2': 0},
    {'1': 'STATIC', '2': 1},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_NetworkConfig_ProtocolFlags$json = {
  '1': 'ProtocolFlags',
  '2': [
    {'1': 'NO_BROADCAST', '2': 0},
    {'1': 'UDP_BROADCAST', '2': 1},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_DisplayConfig$json = {
  '1': 'DisplayConfig',
  '2': [
    {'1': 'screen_on_secs', '3': 1, '4': 1, '5': 13, '10': 'screenOnSecs'},
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
    {'1': 'flip_screen', '3': 5, '4': 1, '5': 8, '10': 'flipScreen'},
    {
      '1': 'units',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.DisplayConfig.DisplayUnits',
      '10': 'units'
    },
    {
      '1': 'oled',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.DisplayConfig.OledType',
      '10': 'oled'
    },
    {
      '1': 'displaymode',
      '3': 8,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.DisplayConfig.DisplayMode',
      '10': 'displaymode'
    },
    {'1': 'heading_bold', '3': 9, '4': 1, '5': 8, '10': 'headingBold'},
    {
      '1': 'wake_on_tap_or_motion',
      '3': 10,
      '4': 1,
      '5': 8,
      '10': 'wakeOnTapOrMotion'
    },
    {
      '1': 'compass_orientation',
      '3': 11,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.DisplayConfig.CompassOrientation',
      '10': 'compassOrientation'
    },
    {'1': 'use_12h_clock', '3': 12, '4': 1, '5': 8, '10': 'use12hClock'},
    {
      '1': 'use_long_node_name',
      '3': 13,
      '4': 1,
      '5': 8,
      '10': 'useLongNodeName'
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
    {'1': 'METRIC', '2': 0},
    {'1': 'IMPERIAL', '2': 1},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_DisplayConfig_OledType$json = {
  '1': 'OledType',
  '2': [
    {'1': 'OLED_AUTO', '2': 0},
    {'1': 'OLED_SSD1306', '2': 1},
    {'1': 'OLED_SH1106', '2': 2},
    {'1': 'OLED_SH1107', '2': 3},
    {'1': 'OLED_SH1107_128_128', '2': 4},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_DisplayConfig_DisplayMode$json = {
  '1': 'DisplayMode',
  '2': [
    {'1': 'DEFAULT', '2': 0},
    {'1': 'TWOCOLOR', '2': 1},
    {'1': 'INVERTED', '2': 2},
    {'1': 'COLOR', '2': 3},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_DisplayConfig_CompassOrientation$json = {
  '1': 'CompassOrientation',
  '2': [
    {'1': 'DEGREES_0', '2': 0},
    {'1': 'DEGREES_90', '2': 1},
    {'1': 'DEGREES_180', '2': 2},
    {'1': 'DEGREES_270', '2': 3},
    {'1': 'DEGREES_0_INVERTED', '2': 4},
    {'1': 'DEGREES_90_INVERTED', '2': 5},
    {'1': 'DEGREES_180_INVERTED', '2': 6},
    {'1': 'DEGREES_270_INVERTED', '2': 7},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_LoRaConfig$json = {
  '1': 'LoRaConfig',
  '2': [
    {'1': 'use_preset', '3': 1, '4': 1, '5': 8, '10': 'usePreset'},
    {
      '1': 'modem_preset',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.LoRaConfig.ModemPreset',
      '10': 'modemPreset'
    },
    {'1': 'bandwidth', '3': 3, '4': 1, '5': 13, '10': 'bandwidth'},
    {'1': 'spread_factor', '3': 4, '4': 1, '5': 13, '10': 'spreadFactor'},
    {'1': 'coding_rate', '3': 5, '4': 1, '5': 13, '10': 'codingRate'},
    {'1': 'frequency_offset', '3': 6, '4': 1, '5': 2, '10': 'frequencyOffset'},
    {
      '1': 'region',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.LoRaConfig.RegionCode',
      '10': 'region'
    },
    {'1': 'hop_limit', '3': 8, '4': 1, '5': 13, '10': 'hopLimit'},
    {'1': 'tx_enabled', '3': 9, '4': 1, '5': 8, '10': 'txEnabled'},
    {'1': 'tx_power', '3': 10, '4': 1, '5': 5, '10': 'txPower'},
    {'1': 'channel_num', '3': 11, '4': 1, '5': 13, '10': 'channelNum'},
    {
      '1': 'override_duty_cycle',
      '3': 12,
      '4': 1,
      '5': 8,
      '10': 'overrideDutyCycle'
    },
    {
      '1': 'sx126x_rx_boosted_gain',
      '3': 13,
      '4': 1,
      '5': 8,
      '10': 'sx126xRxBoostedGain'
    },
    {
      '1': 'override_frequency',
      '3': 14,
      '4': 1,
      '5': 2,
      '10': 'overrideFrequency'
    },
    {'1': 'pa_fan_disabled', '3': 15, '4': 1, '5': 8, '10': 'paFanDisabled'},
    {'1': 'ignore_incoming', '3': 103, '4': 3, '5': 13, '10': 'ignoreIncoming'},
    {'1': 'ignore_mqtt', '3': 104, '4': 1, '5': 8, '10': 'ignoreMqtt'},
    {
      '1': 'config_ok_to_mqtt',
      '3': 105,
      '4': 1,
      '5': 8,
      '10': 'configOkToMqtt'
    },
  ],
  '4': [Config_LoRaConfig_RegionCode$json, Config_LoRaConfig_ModemPreset$json],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_LoRaConfig_RegionCode$json = {
  '1': 'RegionCode',
  '2': [
    {'1': 'UNSET', '2': 0},
    {'1': 'US', '2': 1},
    {'1': 'EU_433', '2': 2},
    {'1': 'EU_868', '2': 3},
    {'1': 'CN', '2': 4},
    {'1': 'JP', '2': 5},
    {'1': 'ANZ', '2': 6},
    {'1': 'KR', '2': 7},
    {'1': 'TW', '2': 8},
    {'1': 'RU', '2': 9},
    {'1': 'IN', '2': 10},
    {'1': 'NZ_865', '2': 11},
    {'1': 'TH', '2': 12},
    {'1': 'LORA_24', '2': 13},
    {'1': 'UA_433', '2': 14},
    {'1': 'UA_868', '2': 15},
    {'1': 'MY_433', '2': 16},
    {'1': 'MY_919', '2': 17},
    {'1': 'SG_923', '2': 18},
    {'1': 'PH_433', '2': 19},
    {'1': 'PH_868', '2': 20},
    {'1': 'PH_915', '2': 21},
    {'1': 'ANZ_433', '2': 22},
    {'1': 'KZ_433', '2': 23},
    {'1': 'KZ_863', '2': 24},
    {'1': 'NP_865', '2': 25},
    {'1': 'BR_902', '2': 26},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_LoRaConfig_ModemPreset$json = {
  '1': 'ModemPreset',
  '2': [
    {'1': 'LONG_FAST', '2': 0},
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
    {'1': 'MEDIUM_SLOW', '2': 3},
    {'1': 'MEDIUM_FAST', '2': 4},
    {'1': 'SHORT_SLOW', '2': 5},
    {'1': 'SHORT_FAST', '2': 6},
    {'1': 'LONG_MODERATE', '2': 7},
    {'1': 'SHORT_TURBO', '2': 8},
    {'1': 'LONG_TURBO', '2': 9},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_BluetoothConfig$json = {
  '1': 'BluetoothConfig',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '10': 'enabled'},
    {
      '1': 'mode',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.BluetoothConfig.PairingMode',
      '10': 'mode'
    },
    {'1': 'fixed_pin', '3': 3, '4': 1, '5': 13, '10': 'fixedPin'},
  ],
  '4': [Config_BluetoothConfig_PairingMode$json],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_BluetoothConfig_PairingMode$json = {
  '1': 'PairingMode',
  '2': [
    {'1': 'RANDOM_PIN', '2': 0},
    {'1': 'FIXED_PIN', '2': 1},
    {'1': 'NO_PIN', '2': 2},
  ],
};

@$core.Deprecated('Use configDescriptor instead')
const Config_SecurityConfig$json = {
  '1': 'SecurityConfig',
  '2': [
    {'1': 'public_key', '3': 1, '4': 1, '5': 12, '10': 'publicKey'},
    {'1': 'private_key', '3': 2, '4': 1, '5': 12, '10': 'privateKey'},
    {'1': 'admin_key', '3': 3, '4': 3, '5': 12, '10': 'adminKey'},
    {'1': 'is_managed', '3': 4, '4': 1, '5': 8, '10': 'isManaged'},
    {'1': 'serial_enabled', '3': 5, '4': 1, '5': 8, '10': 'serialEnabled'},
    {
      '1': 'debug_log_api_enabled',
      '3': 6,
      '4': 1,
      '5': 8,
      '10': 'debugLogApiEnabled'
    },
    {
      '1': 'admin_channel_enabled',
      '3': 8,
      '4': 1,
      '5': 8,
      '10': 'adminChannelEnabled'
    },
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
    'NvbmZpZ0gAUghkZXZpY2VVaRqrCAoMRGV2aWNlQ29uZmlnEjgKBHJvbGUYASABKA4yJC5tZXNo'
    'dGFzdGljLkNvbmZpZy5EZXZpY2VDb25maWcuUm9sZVIEcm9sZRIpCg5zZXJpYWxfZW5hYmxlZB'
    'gCIAEoCEICGAFSDXNlcmlhbEVuYWJsZWQSHwoLYnV0dG9uX2dwaW8YBCABKA1SCmJ1dHRvbkdw'
    'aW8SHwoLYnV6emVyX2dwaW8YBSABKA1SCmJ1enplckdwaW8SWgoQcmVicm9hZGNhc3RfbW9kZR'
    'gGIAEoDjIvLm1lc2h0YXN0aWMuQ29uZmlnLkRldmljZUNvbmZpZy5SZWJyb2FkY2FzdE1vZGVS'
    'D3JlYnJvYWRjYXN0TW9kZRI3Chhub2RlX2luZm9fYnJvYWRjYXN0X3NlY3MYByABKA1SFW5vZG'
    'VJbmZvQnJvYWRjYXN0U2VjcxI6Chpkb3VibGVfdGFwX2FzX2J1dHRvbl9wcmVzcxgIIAEoCFIW'
    'ZG91YmxlVGFwQXNCdXR0b25QcmVzcxIhCgppc19tYW5hZ2VkGAkgASgIQgIYAVIJaXNNYW5hZ2'
    'VkEjAKFGRpc2FibGVfdHJpcGxlX2NsaWNrGAogASgIUhJkaXNhYmxlVHJpcGxlQ2xpY2sSFAoF'
    'dHpkZWYYCyABKAlSBXR6ZGVmEjQKFmxlZF9oZWFydGJlYXRfZGlzYWJsZWQYDCABKAhSFGxlZE'
    'hlYXJ0YmVhdERpc2FibGVkEksKC2J1enplcl9tb2RlGA0gASgOMioubWVzaHRhc3RpYy5Db25m'
    'aWcuRGV2aWNlQ29uZmlnLkJ1enplck1vZGVSCmJ1enplck1vZGUi1AEKBFJvbGUSCgoGQ0xJRU'
    '5UEAASDwoLQ0xJRU5UX01VVEUQARIKCgZST1VURVIQAhIVCg1ST1VURVJfQ0xJRU5UEAMaAggB'
    'EhAKCFJFUEVBVEVSEAQaAggBEgsKB1RSQUNLRVIQBRIKCgZTRU5TT1IQBhIHCgNUQUsQBxIRCg'
    '1DTElFTlRfSElEREVOEAgSEgoOTE9TVF9BTkRfRk9VTkQQCRIPCgtUQUtfVFJBQ0tFUhAKEg8K'
    'C1JPVVRFUl9MQVRFEAsSDwoLQ0xJRU5UX0JBU0UQDCJzCg9SZWJyb2FkY2FzdE1vZGUSBwoDQU'
    'xMEAASFQoRQUxMX1NLSVBfREVDT0RJTkcQARIOCgpMT0NBTF9PTkxZEAISDgoKS05PV05fT05M'
    'WRADEggKBE5PTkUQBBIWChJDT1JFX1BPUlROVU1TX09OTFkQBSJpCgpCdXp6ZXJNb2RlEg8KC0'
    'FMTF9FTkFCTEVEEAASDAoIRElTQUJMRUQQARIWChJOT1RJRklDQVRJT05TX09OTFkQAhIPCgtT'
    'WVNURU1fT05MWRADEhMKD0RJUkVDVF9NU0dfT05MWRAEGvoGCg5Qb3NpdGlvbkNvbmZpZxI2Ch'
    'dwb3NpdGlvbl9icm9hZGNhc3Rfc2VjcxgBIAEoDVIVcG9zaXRpb25Ccm9hZGNhc3RTZWNzEkcK'
    'IHBvc2l0aW9uX2Jyb2FkY2FzdF9zbWFydF9lbmFibGVkGAIgASgIUh1wb3NpdGlvbkJyb2FkY2'
    'FzdFNtYXJ0RW5hYmxlZBIlCg5maXhlZF9wb3NpdGlvbhgDIAEoCFINZml4ZWRQb3NpdGlvbhIj'
    'CgtncHNfZW5hYmxlZBgEIAEoCEICGAFSCmdwc0VuYWJsZWQSLgoTZ3BzX3VwZGF0ZV9pbnRlcn'
    'ZhbBgFIAEoDVIRZ3BzVXBkYXRlSW50ZXJ2YWwSLAoQZ3BzX2F0dGVtcHRfdGltZRgGIAEoDUIC'
    'GAFSDmdwc0F0dGVtcHRUaW1lEiUKDnBvc2l0aW9uX2ZsYWdzGAcgASgNUg1wb3NpdGlvbkZsYW'
    'dzEhcKB3J4X2dwaW8YCCABKA1SBnJ4R3BpbxIXCgd0eF9ncGlvGAkgASgNUgZ0eEdwaW8SRwog'
    'YnJvYWRjYXN0X3NtYXJ0X21pbmltdW1fZGlzdGFuY2UYCiABKA1SHWJyb2FkY2FzdFNtYXJ0TW'
    'luaW11bURpc3RhbmNlElAKJWJyb2FkY2FzdF9zbWFydF9taW5pbXVtX2ludGVydmFsX3NlY3MY'
    'CyABKA1SIWJyb2FkY2FzdFNtYXJ0TWluaW11bUludGVydmFsU2VjcxIeCgtncHNfZW5fZ3Bpbx'
    'gMIAEoDVIJZ3BzRW5HcGlvEkQKCGdwc19tb2RlGA0gASgOMikubWVzaHRhc3RpYy5Db25maWcu'
    'UG9zaXRpb25Db25maWcuR3BzTW9kZVIHZ3BzTW9kZSKrAQoNUG9zaXRpb25GbGFncxIJCgVVTl'
    'NFVBAAEgwKCEFMVElUVURFEAESEAoMQUxUSVRVREVfTVNMEAISFgoSR0VPSURBTF9TRVBBUkFU'
    'SU9OEAQSBwoDRE9QEAgSCQoFSFZET1AQEBINCglTQVRJTlZJRVcQIBIKCgZTRVFfTk8QQBIOCg'
    'lUSU1FU1RBTVAQgAESDAoHSEVBRElORxCAAhIKCgVTUEVFRBCABCI1CgdHcHNNb2RlEgwKCERJ'
    'U0FCTEVEEAASCwoHRU5BQkxFRBABEg8KC05PVF9QUkVTRU5UEAIaoQMKC1Bvd2VyQ29uZmlnEi'
    'YKD2lzX3Bvd2VyX3NhdmluZxgBIAEoCFINaXNQb3dlclNhdmluZxJCCh5vbl9iYXR0ZXJ5X3No'
    'dXRkb3duX2FmdGVyX3NlY3MYAiABKA1SGm9uQmF0dGVyeVNodXRkb3duQWZ0ZXJTZWNzEjYKF2'
    'FkY19tdWx0aXBsaWVyX292ZXJyaWRlGAMgASgCUhVhZGNNdWx0aXBsaWVyT3ZlcnJpZGUSLgoT'
    'd2FpdF9ibHVldG9vdGhfc2VjcxgEIAEoDVIRd2FpdEJsdWV0b290aFNlY3MSGQoIc2RzX3NlY3'
    'MYBiABKA1SB3Nkc1NlY3MSFwoHbHNfc2VjcxgHIAEoDVIGbHNTZWNzEiIKDW1pbl93YWtlX3Nl'
    'Y3MYCCABKA1SC21pbldha2VTZWNzEjsKGmRldmljZV9iYXR0ZXJ5X2luYV9hZGRyZXNzGAkgAS'
    'gNUhdkZXZpY2VCYXR0ZXJ5SW5hQWRkcmVzcxIpChBwb3dlcm1vbl9lbmFibGVzGCAgASgEUg9w'
    'b3dlcm1vbkVuYWJsZXMa/QQKDU5ldHdvcmtDb25maWcSIQoMd2lmaV9lbmFibGVkGAEgASgIUg'
    't3aWZpRW5hYmxlZBIbCgl3aWZpX3NzaWQYAyABKAlSCHdpZmlTc2lkEhkKCHdpZmlfcHNrGAQg'
    'ASgJUgd3aWZpUHNrEh0KCm50cF9zZXJ2ZXIYBSABKAlSCW50cFNlcnZlchIfCgtldGhfZW5hYm'
    'xlZBgGIAEoCFIKZXRoRW5hYmxlZBJPCgxhZGRyZXNzX21vZGUYByABKA4yLC5tZXNodGFzdGlj'
    'LkNvbmZpZy5OZXR3b3JrQ29uZmlnLkFkZHJlc3NNb2RlUgthZGRyZXNzTW9kZRJMCgtpcHY0X2'
    'NvbmZpZxgIIAEoCzIrLm1lc2h0YXN0aWMuQ29uZmlnLk5ldHdvcmtDb25maWcuSXBWNENvbmZp'
    'Z1IKaXB2NENvbmZpZxIlCg5yc3lzbG9nX3NlcnZlchgJIAEoCVINcnN5c2xvZ1NlcnZlchIrCh'
    'FlbmFibGVkX3Byb3RvY29scxgKIAEoDVIQZW5hYmxlZFByb3RvY29scxIhCgxpcHY2X2VuYWJs'
    'ZWQYCyABKAhSC2lwdjZFbmFibGVkGmAKCklwVjRDb25maWcSDgoCaXAYASABKAdSAmlwEhgKB2'
    'dhdGV3YXkYAiABKAdSB2dhdGV3YXkSFgoGc3VibmV0GAMgASgHUgZzdWJuZXQSEAoDZG5zGAQg'
    'ASgHUgNkbnMiIwoLQWRkcmVzc01vZGUSCAoEREhDUBAAEgoKBlNUQVRJQxABIjQKDVByb3RvY2'
    '9sRmxhZ3MSEAoMTk9fQlJPQURDQVNUEAASEQoNVURQX0JST0FEQ0FTVBABGsMJCg1EaXNwbGF5'
    'Q29uZmlnEiQKDnNjcmVlbl9vbl9zZWNzGAEgASgNUgxzY3JlZW5PblNlY3MSYQoKZ3BzX2Zvcm'
    '1hdBgCIAEoDjI+Lm1lc2h0YXN0aWMuQ29uZmlnLkRpc3BsYXlDb25maWcuRGVwcmVjYXRlZEdw'
    'c0Nvb3JkaW5hdGVGb3JtYXRCAhgBUglncHNGb3JtYXQSOQoZYXV0b19zY3JlZW5fY2Fyb3VzZW'
    'xfc2VjcxgDIAEoDVIWYXV0b1NjcmVlbkNhcm91c2VsU2VjcxIuChFjb21wYXNzX25vcnRoX3Rv'
    'cBgEIAEoCEICGAFSD2NvbXBhc3NOb3J0aFRvcBIfCgtmbGlwX3NjcmVlbhgFIAEoCFIKZmxpcF'
    'NjcmVlbhJDCgV1bml0cxgGIAEoDjItLm1lc2h0YXN0aWMuQ29uZmlnLkRpc3BsYXlDb25maWcu'
    'RGlzcGxheVVuaXRzUgV1bml0cxI9CgRvbGVkGAcgASgOMikubWVzaHRhc3RpYy5Db25maWcuRG'
    'lzcGxheUNvbmZpZy5PbGVkVHlwZVIEb2xlZBJOCgtkaXNwbGF5bW9kZRgIIAEoDjIsLm1lc2h0'
    'YXN0aWMuQ29uZmlnLkRpc3BsYXlDb25maWcuRGlzcGxheU1vZGVSC2Rpc3BsYXltb2RlEiEKDG'
    'hlYWRpbmdfYm9sZBgJIAEoCFILaGVhZGluZ0JvbGQSMAoVd2FrZV9vbl90YXBfb3JfbW90aW9u'
    'GAogASgIUhF3YWtlT25UYXBPck1vdGlvbhJkChNjb21wYXNzX29yaWVudGF0aW9uGAsgASgOMj'
    'MubWVzaHRhc3RpYy5Db25maWcuRGlzcGxheUNvbmZpZy5Db21wYXNzT3JpZW50YXRpb25SEmNv'
    'bXBhc3NPcmllbnRhdGlvbhIiCg11c2VfMTJoX2Nsb2NrGAwgASgIUgt1c2UxMmhDbG9jaxIrCh'
    'J1c2VfbG9uZ19ub2RlX25hbWUYDSABKAhSD3VzZUxvbmdOb2RlTmFtZSIrCh1EZXByZWNhdGVk'
    'R3BzQ29vcmRpbmF0ZUZvcm1hdBIKCgZVTlVTRUQQACIoCgxEaXNwbGF5VW5pdHMSCgoGTUVUUk'
    'lDEAASDAoISU1QRVJJQUwQASJmCghPbGVkVHlwZRINCglPTEVEX0FVVE8QABIQCgxPTEVEX1NT'
    'RDEzMDYQARIPCgtPTEVEX1NIMTEwNhACEg8KC09MRURfU0gxMTA3EAMSFwoTT0xFRF9TSDExMD'
    'dfMTI4XzEyOBAEIkEKC0Rpc3BsYXlNb2RlEgsKB0RFRkFVTFQQABIMCghUV09DT0xPUhABEgwK'
    'CElOVkVSVEVEEAISCQoFQ09MT1IQAyK6AQoSQ29tcGFzc09yaWVudGF0aW9uEg0KCURFR1JFRV'
    'NfMBAAEg4KCkRFR1JFRVNfOTAQARIPCgtERUdSRUVTXzE4MBACEg8KC0RFR1JFRVNfMjcwEAMS'
    'FgoSREVHUkVFU18wX0lOVkVSVEVEEAQSFwoTREVHUkVFU185MF9JTlZFUlRFRBAFEhgKFERFR1'
    'JFRVNfMTgwX0lOVkVSVEVEEAYSGAoUREVHUkVFU18yNzBfSU5WRVJURUQQBxrkCQoKTG9SYUNv'
    'bmZpZxIdCgp1c2VfcHJlc2V0GAEgASgIUgl1c2VQcmVzZXQSTAoMbW9kZW1fcHJlc2V0GAIgAS'
    'gOMikubWVzaHRhc3RpYy5Db25maWcuTG9SYUNvbmZpZy5Nb2RlbVByZXNldFILbW9kZW1QcmVz'
    'ZXQSHAoJYmFuZHdpZHRoGAMgASgNUgliYW5kd2lkdGgSIwoNc3ByZWFkX2ZhY3RvchgEIAEoDV'
    'IMc3ByZWFkRmFjdG9yEh8KC2NvZGluZ19yYXRlGAUgASgNUgpjb2RpbmdSYXRlEikKEGZyZXF1'
    'ZW5jeV9vZmZzZXQYBiABKAJSD2ZyZXF1ZW5jeU9mZnNldBJACgZyZWdpb24YByABKA4yKC5tZX'
    'NodGFzdGljLkNvbmZpZy5Mb1JhQ29uZmlnLlJlZ2lvbkNvZGVSBnJlZ2lvbhIbCglob3BfbGlt'
    'aXQYCCABKA1SCGhvcExpbWl0Eh0KCnR4X2VuYWJsZWQYCSABKAhSCXR4RW5hYmxlZBIZCgh0eF'
    '9wb3dlchgKIAEoBVIHdHhQb3dlchIfCgtjaGFubmVsX251bRgLIAEoDVIKY2hhbm5lbE51bRIu'
    'ChNvdmVycmlkZV9kdXR5X2N5Y2xlGAwgASgIUhFvdmVycmlkZUR1dHlDeWNsZRIzChZzeDEyNn'
    'hfcnhfYm9vc3RlZF9nYWluGA0gASgIUhNzeDEyNnhSeEJvb3N0ZWRHYWluEi0KEm92ZXJyaWRl'
    'X2ZyZXF1ZW5jeRgOIAEoAlIRb3ZlcnJpZGVGcmVxdWVuY3kSJgoPcGFfZmFuX2Rpc2FibGVkGA'
    '8gASgIUg1wYUZhbkRpc2FibGVkEicKD2lnbm9yZV9pbmNvbWluZxhnIAMoDVIOaWdub3JlSW5j'
    'b21pbmcSHwoLaWdub3JlX21xdHQYaCABKAhSCmlnbm9yZU1xdHQSKQoRY29uZmlnX29rX3RvX2'
    '1xdHQYaSABKAhSDmNvbmZpZ09rVG9NcXR0Iq4CCgpSZWdpb25Db2RlEgkKBVVOU0VUEAASBgoC'
    'VVMQARIKCgZFVV80MzMQAhIKCgZFVV84NjgQAxIGCgJDThAEEgYKAkpQEAUSBwoDQU5aEAYSBg'
    'oCS1IQBxIGCgJUVxAIEgYKAlJVEAkSBgoCSU4QChIKCgZOWl84NjUQCxIGCgJUSBAMEgsKB0xP'
    'UkFfMjQQDRIKCgZVQV80MzMQDhIKCgZVQV84NjgQDxIKCgZNWV80MzMQEBIKCgZNWV85MTkQER'
    'IKCgZTR185MjMQEhIKCgZQSF80MzMQExIKCgZQSF84NjgQFBIKCgZQSF85MTUQFRILCgdBTlpf'
    'NDMzEBYSCgoGS1pfNDMzEBcSCgoGS1pfODYzEBgSCgoGTlBfODY1EBkSCgoGQlJfOTAyEBoivQ'
    'EKC01vZGVtUHJlc2V0Eg0KCUxPTkdfRkFTVBAAEhEKCUxPTkdfU0xPVxABGgIIARIWCg5WRVJZ'
    'X0xPTkdfU0xPVxACGgIIARIPCgtNRURJVU1fU0xPVxADEg8KC01FRElVTV9GQVNUEAQSDgoKU0'
    'hPUlRfU0xPVxAFEg4KClNIT1JUX0ZBU1QQBhIRCg1MT05HX01PREVSQVRFEAcSDwoLU0hPUlRf'
    'VFVSQk8QCBIOCgpMT05HX1RVUkJPEAkaxgEKD0JsdWV0b290aENvbmZpZxIYCgdlbmFibGVkGA'
    'EgASgIUgdlbmFibGVkEkIKBG1vZGUYAiABKA4yLi5tZXNodGFzdGljLkNvbmZpZy5CbHVldG9v'
    'dGhDb25maWcuUGFpcmluZ01vZGVSBG1vZGUSGwoJZml4ZWRfcGluGAMgASgNUghmaXhlZFBpbi'
    'I4CgtQYWlyaW5nTW9kZRIOCgpSQU5ET01fUElOEAASDQoJRklYRURfUElOEAESCgoGTk9fUElO'
    'EAIamgIKDlNlY3VyaXR5Q29uZmlnEh0KCnB1YmxpY19rZXkYASABKAxSCXB1YmxpY0tleRIfCg'
    'twcml2YXRlX2tleRgCIAEoDFIKcHJpdmF0ZUtleRIbCglhZG1pbl9rZXkYAyADKAxSCGFkbWlu'
    'S2V5Eh0KCmlzX21hbmFnZWQYBCABKAhSCWlzTWFuYWdlZBIlCg5zZXJpYWxfZW5hYmxlZBgFIA'
    'EoCFINc2VyaWFsRW5hYmxlZBIxChVkZWJ1Z19sb2dfYXBpX2VuYWJsZWQYBiABKAhSEmRlYnVn'
    'TG9nQXBpRW5hYmxlZBIyChVhZG1pbl9jaGFubmVsX2VuYWJsZWQYCCABKAhSE2FkbWluQ2hhbm'
    '5lbEVuYWJsZWQaEgoQU2Vzc2lvbmtleUNvbmZpZ0IRCg9wYXlsb2FkX3ZhcmlhbnQ=');
