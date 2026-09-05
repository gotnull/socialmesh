// This is a generated file - do not edit.
//
// Generated from meshtastic/module_config.proto.

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

@$core.Deprecated('Use remoteHardwarePinTypeDescriptor instead')
const RemoteHardwarePinType$json = {
  '1': 'RemoteHardwarePinType',
  '2': [
    {'1': 'UNKNOWN', '2': 0},
    {'1': 'DIGITAL_READ', '2': 1},
    {'1': 'DIGITAL_WRITE', '2': 2},
  ],
};

/// Descriptor for `RemoteHardwarePinType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List remoteHardwarePinTypeDescriptor = $convert.base64Decode(
    'ChVSZW1vdGVIYXJkd2FyZVBpblR5cGUSCwoHVU5LTk9XThAAEhAKDERJR0lUQUxfUkVBRBABEh'
    'EKDURJR0lUQUxfV1JJVEUQAg==');

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig$json = {
  '1': 'ModuleConfig',
  '2': [
    {
      '1': 'mqtt',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.MQTTConfig',
      '9': 0,
      '10': 'mqtt'
    },
    {
      '1': 'serial',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.SerialConfig',
      '9': 0,
      '10': 'serial'
    },
    {
      '1': 'external_notification',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.ExternalNotificationConfig',
      '9': 0,
      '10': 'externalNotification'
    },
    {
      '1': 'store_forward',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.StoreForwardConfig',
      '9': 0,
      '10': 'storeForward'
    },
    {
      '1': 'range_test',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.RangeTestConfig',
      '9': 0,
      '10': 'rangeTest'
    },
    {
      '1': 'telemetry',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.TelemetryConfig',
      '9': 0,
      '10': 'telemetry'
    },
    {
      '1': 'canned_message',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.CannedMessageConfig',
      '9': 0,
      '10': 'cannedMessage'
    },
    {
      '1': 'audio',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.AudioConfig',
      '9': 0,
      '10': 'audio'
    },
    {
      '1': 'remote_hardware',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.RemoteHardwareConfig',
      '9': 0,
      '10': 'remoteHardware'
    },
    {
      '1': 'neighbor_info',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.NeighborInfoConfig',
      '9': 0,
      '10': 'neighborInfo'
    },
    {
      '1': 'ambient_lighting',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.AmbientLightingConfig',
      '9': 0,
      '10': 'ambientLighting'
    },
    {
      '1': 'detection_sensor',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.DetectionSensorConfig',
      '9': 0,
      '10': 'detectionSensor'
    },
    {
      '1': 'paxcounter',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.PaxcounterConfig',
      '9': 0,
      '10': 'paxcounter'
    },
    {
      '1': 'statusmessage',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.StatusMessageConfig',
      '9': 0,
      '10': 'statusmessage'
    },
    {
      '1': 'traffic_management',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.TrafficManagementConfig',
      '9': 0,
      '10': 'trafficManagement'
    },
    {
      '1': 'tak',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.TAKConfig',
      '9': 0,
      '10': 'tak'
    },
    {
      '1': 'mesh_beacon',
      '3': 17,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.MeshBeaconConfig',
      '9': 0,
      '10': 'meshBeacon'
    },
  ],
  '3': [
    ModuleConfig_MQTTConfig$json,
    ModuleConfig_MapReportSettings$json,
    ModuleConfig_RemoteHardwareConfig$json,
    ModuleConfig_NeighborInfoConfig$json,
    ModuleConfig_DetectionSensorConfig$json,
    ModuleConfig_AudioConfig$json,
    ModuleConfig_PaxcounterConfig$json,
    ModuleConfig_TrafficManagementConfig$json,
    ModuleConfig_SerialConfig$json,
    ModuleConfig_ExternalNotificationConfig$json,
    ModuleConfig_StoreForwardConfig$json,
    ModuleConfig_RangeTestConfig$json,
    ModuleConfig_TelemetryConfig$json,
    ModuleConfig_CannedMessageConfig$json,
    ModuleConfig_AmbientLightingConfig$json,
    ModuleConfig_StatusMessageConfig$json,
    ModuleConfig_MeshBeaconConfig$json,
    ModuleConfig_TAKConfig$json
  ],
  '8': [
    {'1': 'payload_variant'},
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_MQTTConfig$json = {
  '1': 'MQTTConfig',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '10': 'enabled'},
    {'1': 'address', '3': 2, '4': 1, '5': 9, '10': 'address'},
    {'1': 'username', '3': 3, '4': 1, '5': 9, '10': 'username'},
    {'1': 'password', '3': 4, '4': 1, '5': 9, '10': 'password'},
    {
      '1': 'encryption_enabled',
      '3': 5,
      '4': 1,
      '5': 8,
      '10': 'encryptionEnabled'
    },
    {
      '1': 'json_enabled',
      '3': 6,
      '4': 1,
      '5': 8,
      '8': {'3': true},
      '10': 'jsonEnabled',
    },
    {'1': 'tls_enabled', '3': 7, '4': 1, '5': 8, '10': 'tlsEnabled'},
    {'1': 'root', '3': 8, '4': 1, '5': 9, '10': 'root'},
    {
      '1': 'proxy_to_client_enabled',
      '3': 9,
      '4': 1,
      '5': 8,
      '10': 'proxyToClientEnabled'
    },
    {
      '1': 'map_reporting_enabled',
      '3': 10,
      '4': 1,
      '5': 8,
      '10': 'mapReportingEnabled'
    },
    {
      '1': 'map_report_settings',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.MapReportSettings',
      '10': 'mapReportSettings'
    },
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_MapReportSettings$json = {
  '1': 'MapReportSettings',
  '2': [
    {
      '1': 'publish_interval_secs',
      '3': 1,
      '4': 1,
      '5': 13,
      '10': 'publishIntervalSecs'
    },
    {
      '1': 'position_precision',
      '3': 2,
      '4': 1,
      '5': 13,
      '10': 'positionPrecision'
    },
    {
      '1': 'should_report_location',
      '3': 3,
      '4': 1,
      '5': 8,
      '10': 'shouldReportLocation'
    },
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_RemoteHardwareConfig$json = {
  '1': 'RemoteHardwareConfig',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '10': 'enabled'},
    {
      '1': 'allow_undefined_pin_access',
      '3': 2,
      '4': 1,
      '5': 8,
      '10': 'allowUndefinedPinAccess'
    },
    {
      '1': 'available_pins',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.meshtastic.RemoteHardwarePin',
      '10': 'availablePins'
    },
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_NeighborInfoConfig$json = {
  '1': 'NeighborInfoConfig',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '10': 'enabled'},
    {'1': 'update_interval', '3': 2, '4': 1, '5': 13, '10': 'updateInterval'},
    {
      '1': 'transmit_over_lora',
      '3': 3,
      '4': 1,
      '5': 8,
      '10': 'transmitOverLora'
    },
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_DetectionSensorConfig$json = {
  '1': 'DetectionSensorConfig',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '10': 'enabled'},
    {
      '1': 'minimum_broadcast_secs',
      '3': 2,
      '4': 1,
      '5': 13,
      '10': 'minimumBroadcastSecs'
    },
    {
      '1': 'state_broadcast_secs',
      '3': 3,
      '4': 1,
      '5': 13,
      '10': 'stateBroadcastSecs'
    },
    {'1': 'send_bell', '3': 4, '4': 1, '5': 8, '10': 'sendBell'},
    {'1': 'name', '3': 5, '4': 1, '5': 9, '10': 'name'},
    {'1': 'monitor_pin', '3': 6, '4': 1, '5': 13, '10': 'monitorPin'},
    {
      '1': 'detection_trigger_type',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.ModuleConfig.DetectionSensorConfig.TriggerType',
      '10': 'detectionTriggerType'
    },
    {'1': 'use_pullup', '3': 8, '4': 1, '5': 8, '10': 'usePullup'},
  ],
  '4': [ModuleConfig_DetectionSensorConfig_TriggerType$json],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_DetectionSensorConfig_TriggerType$json = {
  '1': 'TriggerType',
  '2': [
    {'1': 'LOGIC_LOW', '2': 0},
    {'1': 'LOGIC_HIGH', '2': 1},
    {'1': 'FALLING_EDGE', '2': 2},
    {'1': 'RISING_EDGE', '2': 3},
    {'1': 'EITHER_EDGE_ACTIVE_LOW', '2': 4},
    {'1': 'EITHER_EDGE_ACTIVE_HIGH', '2': 5},
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_AudioConfig$json = {
  '1': 'AudioConfig',
  '2': [
    {'1': 'codec2_enabled', '3': 1, '4': 1, '5': 8, '10': 'codec2Enabled'},
    {'1': 'ptt_pin', '3': 2, '4': 1, '5': 13, '10': 'pttPin'},
    {
      '1': 'bitrate',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.ModuleConfig.AudioConfig.Audio_Baud',
      '10': 'bitrate'
    },
    {'1': 'i2s_ws', '3': 4, '4': 1, '5': 13, '10': 'i2sWs'},
    {'1': 'i2s_sd', '3': 5, '4': 1, '5': 13, '10': 'i2sSd'},
    {'1': 'i2s_din', '3': 6, '4': 1, '5': 13, '10': 'i2sDin'},
    {'1': 'i2s_sck', '3': 7, '4': 1, '5': 13, '10': 'i2sSck'},
  ],
  '4': [ModuleConfig_AudioConfig_Audio_Baud$json],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_AudioConfig_Audio_Baud$json = {
  '1': 'Audio_Baud',
  '2': [
    {'1': 'CODEC2_DEFAULT', '2': 0},
    {'1': 'CODEC2_3200', '2': 1},
    {'1': 'CODEC2_2400', '2': 2},
    {'1': 'CODEC2_1600', '2': 3},
    {'1': 'CODEC2_1400', '2': 4},
    {'1': 'CODEC2_1300', '2': 5},
    {'1': 'CODEC2_1200', '2': 6},
    {'1': 'CODEC2_700', '2': 7},
    {'1': 'CODEC2_700B', '2': 8},
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_PaxcounterConfig$json = {
  '1': 'PaxcounterConfig',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '10': 'enabled'},
    {
      '1': 'paxcounter_update_interval',
      '3': 2,
      '4': 1,
      '5': 13,
      '10': 'paxcounterUpdateInterval'
    },
    {'1': 'wifi_threshold', '3': 3, '4': 1, '5': 5, '10': 'wifiThreshold'},
    {'1': 'ble_threshold', '3': 4, '4': 1, '5': 5, '10': 'bleThreshold'},
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_TrafficManagementConfig$json = {
  '1': 'TrafficManagementConfig',
  '2': [
    {
      '1': 'position_min_interval_secs',
      '3': 4,
      '4': 1,
      '5': 13,
      '10': 'positionMinIntervalSecs'
    },
    {
      '1': 'nodeinfo_direct_response_max_hops',
      '3': 6,
      '4': 1,
      '5': 13,
      '10': 'nodeinfoDirectResponseMaxHops'
    },
    {
      '1': 'rate_limit_window_secs',
      '3': 8,
      '4': 1,
      '5': 13,
      '10': 'rateLimitWindowSecs'
    },
    {
      '1': 'rate_limit_max_packets',
      '3': 9,
      '4': 1,
      '5': 13,
      '10': 'rateLimitMaxPackets'
    },
    {
      '1': 'unknown_packet_threshold',
      '3': 11,
      '4': 1,
      '5': 13,
      '10': 'unknownPacketThreshold'
    },
  ],
  '9': [
    {'1': 1, '2': 2},
    {'1': 2, '2': 3},
    {'1': 3, '2': 4},
    {'1': 5, '2': 6},
    {'1': 7, '2': 8},
    {'1': 10, '2': 11},
    {'1': 12, '2': 13},
    {'1': 13, '2': 14},
    {'1': 14, '2': 15},
  ],
  '10': [
    'enabled',
    'position_dedup_enabled',
    'position_precision_bits',
    'nodeinfo_direct_response',
    'rate_limit_enabled',
    'drop_unknown_enabled',
    'exhaust_hop_telemetry',
    'exhaust_hop_position',
    'router_preserve_hops'
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_SerialConfig$json = {
  '1': 'SerialConfig',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '10': 'enabled'},
    {'1': 'echo', '3': 2, '4': 1, '5': 8, '10': 'echo'},
    {'1': 'rxd', '3': 3, '4': 1, '5': 13, '10': 'rxd'},
    {'1': 'txd', '3': 4, '4': 1, '5': 13, '10': 'txd'},
    {
      '1': 'baud',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.ModuleConfig.SerialConfig.Serial_Baud',
      '10': 'baud'
    },
    {'1': 'timeout', '3': 6, '4': 1, '5': 13, '10': 'timeout'},
    {
      '1': 'mode',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.ModuleConfig.SerialConfig.Serial_Mode',
      '10': 'mode'
    },
    {
      '1': 'override_console_serial_port',
      '3': 8,
      '4': 1,
      '5': 8,
      '10': 'overrideConsoleSerialPort'
    },
  ],
  '4': [
    ModuleConfig_SerialConfig_Serial_Baud$json,
    ModuleConfig_SerialConfig_Serial_Mode$json
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_SerialConfig_Serial_Baud$json = {
  '1': 'Serial_Baud',
  '2': [
    {'1': 'BAUD_DEFAULT', '2': 0},
    {'1': 'BAUD_110', '2': 1},
    {'1': 'BAUD_300', '2': 2},
    {'1': 'BAUD_600', '2': 3},
    {'1': 'BAUD_1200', '2': 4},
    {'1': 'BAUD_2400', '2': 5},
    {'1': 'BAUD_4800', '2': 6},
    {'1': 'BAUD_9600', '2': 7},
    {'1': 'BAUD_19200', '2': 8},
    {'1': 'BAUD_38400', '2': 9},
    {'1': 'BAUD_57600', '2': 10},
    {'1': 'BAUD_115200', '2': 11},
    {'1': 'BAUD_230400', '2': 12},
    {'1': 'BAUD_460800', '2': 13},
    {'1': 'BAUD_576000', '2': 14},
    {'1': 'BAUD_921600', '2': 15},
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_SerialConfig_Serial_Mode$json = {
  '1': 'Serial_Mode',
  '2': [
    {'1': 'DEFAULT', '2': 0},
    {'1': 'SIMPLE', '2': 1},
    {'1': 'PROTO', '2': 2},
    {'1': 'TEXTMSG', '2': 3},
    {'1': 'NMEA', '2': 4},
    {'1': 'CALTOPO', '2': 5},
    {'1': 'WS85', '2': 6},
    {'1': 'VE_DIRECT', '2': 7},
    {'1': 'MS_CONFIG', '2': 8},
    {'1': 'LOG', '2': 9},
    {'1': 'LOGTEXT', '2': 10},
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_ExternalNotificationConfig$json = {
  '1': 'ExternalNotificationConfig',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '10': 'enabled'},
    {'1': 'output_ms', '3': 2, '4': 1, '5': 13, '10': 'outputMs'},
    {'1': 'output', '3': 3, '4': 1, '5': 13, '10': 'output'},
    {'1': 'output_vibra', '3': 8, '4': 1, '5': 13, '10': 'outputVibra'},
    {'1': 'output_buzzer', '3': 9, '4': 1, '5': 13, '10': 'outputBuzzer'},
    {'1': 'active', '3': 4, '4': 1, '5': 8, '10': 'active'},
    {'1': 'alert_message', '3': 5, '4': 1, '5': 8, '10': 'alertMessage'},
    {
      '1': 'alert_message_vibra',
      '3': 10,
      '4': 1,
      '5': 8,
      '10': 'alertMessageVibra'
    },
    {
      '1': 'alert_message_buzzer',
      '3': 11,
      '4': 1,
      '5': 8,
      '10': 'alertMessageBuzzer'
    },
    {'1': 'alert_bell', '3': 6, '4': 1, '5': 8, '10': 'alertBell'},
    {'1': 'alert_bell_vibra', '3': 12, '4': 1, '5': 8, '10': 'alertBellVibra'},
    {
      '1': 'alert_bell_buzzer',
      '3': 13,
      '4': 1,
      '5': 8,
      '10': 'alertBellBuzzer'
    },
    {'1': 'use_pwm', '3': 7, '4': 1, '5': 8, '10': 'usePwm'},
    {'1': 'nag_timeout', '3': 14, '4': 1, '5': 13, '10': 'nagTimeout'},
    {'1': 'use_i2s_as_buzzer', '3': 15, '4': 1, '5': 8, '10': 'useI2sAsBuzzer'},
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_StoreForwardConfig$json = {
  '1': 'StoreForwardConfig',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '10': 'enabled'},
    {'1': 'heartbeat', '3': 2, '4': 1, '5': 8, '10': 'heartbeat'},
    {'1': 'records', '3': 3, '4': 1, '5': 13, '10': 'records'},
    {
      '1': 'history_return_max',
      '3': 4,
      '4': 1,
      '5': 13,
      '10': 'historyReturnMax'
    },
    {
      '1': 'history_return_window',
      '3': 5,
      '4': 1,
      '5': 13,
      '10': 'historyReturnWindow'
    },
    {'1': 'is_server', '3': 6, '4': 1, '5': 8, '10': 'isServer'},
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_RangeTestConfig$json = {
  '1': 'RangeTestConfig',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '10': 'enabled'},
    {'1': 'sender', '3': 2, '4': 1, '5': 13, '10': 'sender'},
    {'1': 'save', '3': 3, '4': 1, '5': 8, '10': 'save'},
    {'1': 'clear_on_reboot', '3': 4, '4': 1, '5': 8, '10': 'clearOnReboot'},
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_TelemetryConfig$json = {
  '1': 'TelemetryConfig',
  '2': [
    {
      '1': 'device_update_interval',
      '3': 1,
      '4': 1,
      '5': 13,
      '10': 'deviceUpdateInterval'
    },
    {
      '1': 'environment_update_interval',
      '3': 2,
      '4': 1,
      '5': 13,
      '10': 'environmentUpdateInterval'
    },
    {
      '1': 'environment_measurement_enabled',
      '3': 3,
      '4': 1,
      '5': 8,
      '10': 'environmentMeasurementEnabled'
    },
    {
      '1': 'environment_screen_enabled',
      '3': 4,
      '4': 1,
      '5': 8,
      '10': 'environmentScreenEnabled'
    },
    {
      '1': 'environment_display_fahrenheit',
      '3': 5,
      '4': 1,
      '5': 8,
      '10': 'environmentDisplayFahrenheit'
    },
    {
      '1': 'air_quality_enabled',
      '3': 6,
      '4': 1,
      '5': 8,
      '10': 'airQualityEnabled'
    },
    {
      '1': 'air_quality_interval',
      '3': 7,
      '4': 1,
      '5': 13,
      '10': 'airQualityInterval'
    },
    {
      '1': 'power_measurement_enabled',
      '3': 8,
      '4': 1,
      '5': 8,
      '10': 'powerMeasurementEnabled'
    },
    {
      '1': 'power_update_interval',
      '3': 9,
      '4': 1,
      '5': 13,
      '10': 'powerUpdateInterval'
    },
    {
      '1': 'power_screen_enabled',
      '3': 10,
      '4': 1,
      '5': 8,
      '10': 'powerScreenEnabled'
    },
    {
      '1': 'health_measurement_enabled',
      '3': 11,
      '4': 1,
      '5': 8,
      '10': 'healthMeasurementEnabled'
    },
    {
      '1': 'health_update_interval',
      '3': 12,
      '4': 1,
      '5': 13,
      '10': 'healthUpdateInterval'
    },
    {
      '1': 'health_screen_enabled',
      '3': 13,
      '4': 1,
      '5': 8,
      '10': 'healthScreenEnabled'
    },
    {
      '1': 'device_telemetry_enabled',
      '3': 14,
      '4': 1,
      '5': 8,
      '10': 'deviceTelemetryEnabled'
    },
    {
      '1': 'air_quality_screen_enabled',
      '3': 15,
      '4': 1,
      '5': 8,
      '10': 'airQualityScreenEnabled'
    },
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_CannedMessageConfig$json = {
  '1': 'CannedMessageConfig',
  '2': [
    {'1': 'rotary1_enabled', '3': 1, '4': 1, '5': 8, '10': 'rotary1Enabled'},
    {
      '1': 'inputbroker_pin_a',
      '3': 2,
      '4': 1,
      '5': 13,
      '10': 'inputbrokerPinA'
    },
    {
      '1': 'inputbroker_pin_b',
      '3': 3,
      '4': 1,
      '5': 13,
      '10': 'inputbrokerPinB'
    },
    {
      '1': 'inputbroker_pin_press',
      '3': 4,
      '4': 1,
      '5': 13,
      '10': 'inputbrokerPinPress'
    },
    {
      '1': 'inputbroker_event_cw',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.ModuleConfig.CannedMessageConfig.InputEventChar',
      '10': 'inputbrokerEventCw'
    },
    {
      '1': 'inputbroker_event_ccw',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.ModuleConfig.CannedMessageConfig.InputEventChar',
      '10': 'inputbrokerEventCcw'
    },
    {
      '1': 'inputbroker_event_press',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.ModuleConfig.CannedMessageConfig.InputEventChar',
      '10': 'inputbrokerEventPress'
    },
    {'1': 'updown1_enabled', '3': 8, '4': 1, '5': 8, '10': 'updown1Enabled'},
    {
      '1': 'enabled',
      '3': 9,
      '4': 1,
      '5': 8,
      '8': {'3': true},
      '10': 'enabled',
    },
    {
      '1': 'allow_input_source',
      '3': 10,
      '4': 1,
      '5': 9,
      '8': {'3': true},
      '10': 'allowInputSource',
    },
    {'1': 'send_bell', '3': 11, '4': 1, '5': 8, '10': 'sendBell'},
  ],
  '4': [ModuleConfig_CannedMessageConfig_InputEventChar$json],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_CannedMessageConfig_InputEventChar$json = {
  '1': 'InputEventChar',
  '2': [
    {'1': 'NONE', '2': 0},
    {'1': 'UP', '2': 17},
    {'1': 'DOWN', '2': 18},
    {'1': 'LEFT', '2': 19},
    {'1': 'RIGHT', '2': 20},
    {'1': 'SELECT', '2': 10},
    {'1': 'BACK', '2': 27},
    {'1': 'CANCEL', '2': 24},
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_AmbientLightingConfig$json = {
  '1': 'AmbientLightingConfig',
  '2': [
    {'1': 'led_state', '3': 1, '4': 1, '5': 8, '10': 'ledState'},
    {'1': 'current', '3': 2, '4': 1, '5': 13, '10': 'current'},
    {'1': 'red', '3': 3, '4': 1, '5': 13, '10': 'red'},
    {'1': 'green', '3': 4, '4': 1, '5': 13, '10': 'green'},
    {'1': 'blue', '3': 5, '4': 1, '5': 13, '10': 'blue'},
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_StatusMessageConfig$json = {
  '1': 'StatusMessageConfig',
  '2': [
    {'1': 'node_status', '3': 1, '4': 1, '5': 9, '10': 'nodeStatus'},
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_MeshBeaconConfig$json = {
  '1': 'MeshBeaconConfig',
  '2': [
    {'1': 'flags', '3': 1, '4': 1, '5': 13, '10': 'flags'},
    {
      '1': 'broadcast_message',
      '3': 4,
      '4': 1,
      '5': 9,
      '10': 'broadcastMessage'
    },
    {
      '1': 'broadcast_offer_channel',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ChannelSettings',
      '10': 'broadcastOfferChannel'
    },
    {
      '1': 'broadcast_offer_region',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.LoRaConfig.RegionCode',
      '10': 'broadcastOfferRegion'
    },
    {
      '1': 'broadcast_offer_preset',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.LoRaConfig.ModemPreset',
      '9': 0,
      '10': 'broadcastOfferPreset',
      '17': true
    },
    {
      '1': 'broadcast_interval_secs',
      '3': 11,
      '4': 1,
      '5': 13,
      '10': 'broadcastIntervalSecs'
    },
    {
      '1': 'broadcast_targets',
      '3': 13,
      '4': 3,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.MeshBeaconConfig.BroadcastTarget',
      '10': 'broadcastTargets'
    },
  ],
  '3': [ModuleConfig_MeshBeaconConfig_BroadcastTarget$json],
  '4': [ModuleConfig_MeshBeaconConfig_Flags$json],
  '8': [
    {'1': '_broadcast_offer_preset'},
  ],
  '9': [
    {'1': 3, '2': 4},
    {'1': 8, '2': 9},
    {'1': 9, '2': 10},
    {'1': 10, '2': 11},
  ],
  '10': [
    'broadcast_send_as_node',
    'broadcast_on_channel',
    'broadcast_on_region',
    'broadcast_on_preset'
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_MeshBeaconConfig_BroadcastTarget$json = {
  '1': 'BroadcastTarget',
  '2': [
    {
      '1': 'preset',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.LoRaConfig.ModemPreset',
      '9': 0,
      '10': 'preset',
      '17': true
    },
    {
      '1': 'region',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Config.LoRaConfig.RegionCode',
      '10': 'region'
    },
    {
      '1': 'channel_index',
      '3': 4,
      '4': 1,
      '5': 13,
      '9': 1,
      '10': 'channelIndex',
      '17': true
    },
  ],
  '8': [
    {'1': '_preset'},
    {'1': '_channel_index'},
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_MeshBeaconConfig_Flags$json = {
  '1': 'Flags',
  '2': [
    {'1': 'FLAG_NONE', '2': 0},
    {'1': 'FLAG_LISTEN_ENABLED', '2': 1},
    {'1': 'FLAG_BROADCAST_ENABLED', '2': 2},
    {'1': 'FLAG_LEGACY_SPLIT', '2': 4},
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_TAKConfig$json = {
  '1': 'TAKConfig',
  '2': [
    {
      '1': 'team',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Team',
      '10': 'team'
    },
    {
      '1': 'role',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.MemberRole',
      '10': 'role'
    },
  ],
};

/// Descriptor for `ModuleConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List moduleConfigDescriptor = $convert.base64Decode(
    'CgxNb2R1bGVDb25maWcSOQoEbXF0dBgBIAEoCzIjLm1lc2h0YXN0aWMuTW9kdWxlQ29uZmlnLk'
    '1RVFRDb25maWdIAFIEbXF0dBI/CgZzZXJpYWwYAiABKAsyJS5tZXNodGFzdGljLk1vZHVsZUNv'
    'bmZpZy5TZXJpYWxDb25maWdIAFIGc2VyaWFsEmoKFWV4dGVybmFsX25vdGlmaWNhdGlvbhgDIA'
    'EoCzIzLm1lc2h0YXN0aWMuTW9kdWxlQ29uZmlnLkV4dGVybmFsTm90aWZpY2F0aW9uQ29uZmln'
    'SABSFGV4dGVybmFsTm90aWZpY2F0aW9uElIKDXN0b3JlX2ZvcndhcmQYBCABKAsyKy5tZXNodG'
    'FzdGljLk1vZHVsZUNvbmZpZy5TdG9yZUZvcndhcmRDb25maWdIAFIMc3RvcmVGb3J3YXJkEkkK'
    'CnJhbmdlX3Rlc3QYBSABKAsyKC5tZXNodGFzdGljLk1vZHVsZUNvbmZpZy5SYW5nZVRlc3RDb2'
    '5maWdIAFIJcmFuZ2VUZXN0EkgKCXRlbGVtZXRyeRgGIAEoCzIoLm1lc2h0YXN0aWMuTW9kdWxl'
    'Q29uZmlnLlRlbGVtZXRyeUNvbmZpZ0gAUgl0ZWxlbWV0cnkSVQoOY2FubmVkX21lc3NhZ2UYBy'
    'ABKAsyLC5tZXNodGFzdGljLk1vZHVsZUNvbmZpZy5DYW5uZWRNZXNzYWdlQ29uZmlnSABSDWNh'
    'bm5lZE1lc3NhZ2USPAoFYXVkaW8YCCABKAsyJC5tZXNodGFzdGljLk1vZHVsZUNvbmZpZy5BdW'
    'Rpb0NvbmZpZ0gAUgVhdWRpbxJYCg9yZW1vdGVfaGFyZHdhcmUYCSABKAsyLS5tZXNodGFzdGlj'
    'Lk1vZHVsZUNvbmZpZy5SZW1vdGVIYXJkd2FyZUNvbmZpZ0gAUg5yZW1vdGVIYXJkd2FyZRJSCg'
    '1uZWlnaGJvcl9pbmZvGAogASgLMisubWVzaHRhc3RpYy5Nb2R1bGVDb25maWcuTmVpZ2hib3JJ'
    'bmZvQ29uZmlnSABSDG5laWdoYm9ySW5mbxJbChBhbWJpZW50X2xpZ2h0aW5nGAsgASgLMi4ubW'
    'VzaHRhc3RpYy5Nb2R1bGVDb25maWcuQW1iaWVudExpZ2h0aW5nQ29uZmlnSABSD2FtYmllbnRM'
    'aWdodGluZxJbChBkZXRlY3Rpb25fc2Vuc29yGAwgASgLMi4ubWVzaHRhc3RpYy5Nb2R1bGVDb2'
    '5maWcuRGV0ZWN0aW9uU2Vuc29yQ29uZmlnSABSD2RldGVjdGlvblNlbnNvchJLCgpwYXhjb3Vu'
    'dGVyGA0gASgLMikubWVzaHRhc3RpYy5Nb2R1bGVDb25maWcuUGF4Y291bnRlckNvbmZpZ0gAUg'
    'pwYXhjb3VudGVyElQKDXN0YXR1c21lc3NhZ2UYDiABKAsyLC5tZXNodGFzdGljLk1vZHVsZUNv'
    'bmZpZy5TdGF0dXNNZXNzYWdlQ29uZmlnSABSDXN0YXR1c21lc3NhZ2USYQoSdHJhZmZpY19tYW'
    '5hZ2VtZW50GA8gASgLMjAubWVzaHRhc3RpYy5Nb2R1bGVDb25maWcuVHJhZmZpY01hbmFnZW1l'
    'bnRDb25maWdIAFIRdHJhZmZpY01hbmFnZW1lbnQSNgoDdGFrGBAgASgLMiIubWVzaHRhc3RpYy'
    '5Nb2R1bGVDb25maWcuVEFLQ29uZmlnSABSA3RhaxJMCgttZXNoX2JlYWNvbhgRIAEoCzIpLm1l'
    'c2h0YXN0aWMuTW9kdWxlQ29uZmlnLk1lc2hCZWFjb25Db25maWdIAFIKbWVzaEJlYWNvbhrKAw'
    'oKTVFUVENvbmZpZxIYCgdlbmFibGVkGAEgASgIUgdlbmFibGVkEhgKB2FkZHJlc3MYAiABKAlS'
    'B2FkZHJlc3MSGgoIdXNlcm5hbWUYAyABKAlSCHVzZXJuYW1lEhoKCHBhc3N3b3JkGAQgASgJUg'
    'hwYXNzd29yZBItChJlbmNyeXB0aW9uX2VuYWJsZWQYBSABKAhSEWVuY3J5cHRpb25FbmFibGVk'
    'EiUKDGpzb25fZW5hYmxlZBgGIAEoCEICGAFSC2pzb25FbmFibGVkEh8KC3Rsc19lbmFibGVkGA'
    'cgASgIUgp0bHNFbmFibGVkEhIKBHJvb3QYCCABKAlSBHJvb3QSNQoXcHJveHlfdG9fY2xpZW50'
    'X2VuYWJsZWQYCSABKAhSFHByb3h5VG9DbGllbnRFbmFibGVkEjIKFW1hcF9yZXBvcnRpbmdfZW'
    '5hYmxlZBgKIAEoCFITbWFwUmVwb3J0aW5nRW5hYmxlZBJaChNtYXBfcmVwb3J0X3NldHRpbmdz'
    'GAsgASgLMioubWVzaHRhc3RpYy5Nb2R1bGVDb25maWcuTWFwUmVwb3J0U2V0dGluZ3NSEW1hcF'
    'JlcG9ydFNldHRpbmdzGqwBChFNYXBSZXBvcnRTZXR0aW5ncxIyChVwdWJsaXNoX2ludGVydmFs'
    'X3NlY3MYASABKA1SE3B1Ymxpc2hJbnRlcnZhbFNlY3MSLQoScG9zaXRpb25fcHJlY2lzaW9uGA'
    'IgASgNUhFwb3NpdGlvblByZWNpc2lvbhI0ChZzaG91bGRfcmVwb3J0X2xvY2F0aW9uGAMgASgI'
    'UhRzaG91bGRSZXBvcnRMb2NhdGlvbhqzAQoUUmVtb3RlSGFyZHdhcmVDb25maWcSGAoHZW5hYm'
    'xlZBgBIAEoCFIHZW5hYmxlZBI7ChphbGxvd191bmRlZmluZWRfcGluX2FjY2VzcxgCIAEoCFIX'
    'YWxsb3dVbmRlZmluZWRQaW5BY2Nlc3MSRAoOYXZhaWxhYmxlX3BpbnMYAyADKAsyHS5tZXNodG'
    'FzdGljLlJlbW90ZUhhcmR3YXJlUGluUg1hdmFpbGFibGVQaW5zGoUBChJOZWlnaGJvckluZm9D'
    'b25maWcSGAoHZW5hYmxlZBgBIAEoCFIHZW5hYmxlZBInCg91cGRhdGVfaW50ZXJ2YWwYAiABKA'
    '1SDnVwZGF0ZUludGVydmFsEiwKEnRyYW5zbWl0X292ZXJfbG9yYRgDIAEoCFIQdHJhbnNtaXRP'
    'dmVyTG9yYRqHBAoVRGV0ZWN0aW9uU2Vuc29yQ29uZmlnEhgKB2VuYWJsZWQYASABKAhSB2VuYW'
    'JsZWQSNAoWbWluaW11bV9icm9hZGNhc3Rfc2VjcxgCIAEoDVIUbWluaW11bUJyb2FkY2FzdFNl'
    'Y3MSMAoUc3RhdGVfYnJvYWRjYXN0X3NlY3MYAyABKA1SEnN0YXRlQnJvYWRjYXN0U2VjcxIbCg'
    'lzZW5kX2JlbGwYBCABKAhSCHNlbmRCZWxsEhIKBG5hbWUYBSABKAlSBG5hbWUSHwoLbW9uaXRv'
    'cl9waW4YBiABKA1SCm1vbml0b3JQaW4ScAoWZGV0ZWN0aW9uX3RyaWdnZXJfdHlwZRgHIAEoDj'
    'I6Lm1lc2h0YXN0aWMuTW9kdWxlQ29uZmlnLkRldGVjdGlvblNlbnNvckNvbmZpZy5UcmlnZ2Vy'
    'VHlwZVIUZGV0ZWN0aW9uVHJpZ2dlclR5cGUSHQoKdXNlX3B1bGx1cBgIIAEoCFIJdXNlUHVsbH'
    'VwIogBCgtUcmlnZ2VyVHlwZRINCglMT0dJQ19MT1cQABIOCgpMT0dJQ19ISUdIEAESEAoMRkFM'
    'TElOR19FREdFEAISDwoLUklTSU5HX0VER0UQAxIaChZFSVRIRVJfRURHRV9BQ1RJVkVfTE9XEA'
    'QSGwoXRUlUSEVSX0VER0VfQUNUSVZFX0hJR0gQBRqiAwoLQXVkaW9Db25maWcSJQoOY29kZWMy'
    'X2VuYWJsZWQYASABKAhSDWNvZGVjMkVuYWJsZWQSFwoHcHR0X3BpbhgCIAEoDVIGcHR0UGluEk'
    'kKB2JpdHJhdGUYAyABKA4yLy5tZXNodGFzdGljLk1vZHVsZUNvbmZpZy5BdWRpb0NvbmZpZy5B'
    'dWRpb19CYXVkUgdiaXRyYXRlEhUKBmkyc193cxgEIAEoDVIFaTJzV3MSFQoGaTJzX3NkGAUgAS'
    'gNUgVpMnNTZBIXCgdpMnNfZGluGAYgASgNUgZpMnNEaW4SFwoHaTJzX3NjaxgHIAEoDVIGaTJz'
    'U2NrIqcBCgpBdWRpb19CYXVkEhIKDkNPREVDMl9ERUZBVUxUEAASDwoLQ09ERUMyXzMyMDAQAR'
    'IPCgtDT0RFQzJfMjQwMBACEg8KC0NPREVDMl8xNjAwEAMSDwoLQ09ERUMyXzE0MDAQBBIPCgtD'
    'T0RFQzJfMTMwMBAFEg8KC0NPREVDMl8xMjAwEAYSDgoKQ09ERUMyXzcwMBAHEg8KC0NPREVDMl'
    '83MDBCEAgatgEKEFBheGNvdW50ZXJDb25maWcSGAoHZW5hYmxlZBgBIAEoCFIHZW5hYmxlZBI8'
    'ChpwYXhjb3VudGVyX3VwZGF0ZV9pbnRlcnZhbBgCIAEoDVIYcGF4Y291bnRlclVwZGF0ZUludG'
    'VydmFsEiUKDndpZmlfdGhyZXNob2xkGAMgASgFUg13aWZpVGhyZXNob2xkEiMKDWJsZV90aHJl'
    'c2hvbGQYBCABKAVSDGJsZVRocmVzaG9sZBq7BAoXVHJhZmZpY01hbmFnZW1lbnRDb25maWcSOw'
    'oacG9zaXRpb25fbWluX2ludGVydmFsX3NlY3MYBCABKA1SF3Bvc2l0aW9uTWluSW50ZXJ2YWxT'
    'ZWNzEkgKIW5vZGVpbmZvX2RpcmVjdF9yZXNwb25zZV9tYXhfaG9wcxgGIAEoDVIdbm9kZWluZm'
    '9EaXJlY3RSZXNwb25zZU1heEhvcHMSMwoWcmF0ZV9saW1pdF93aW5kb3dfc2VjcxgIIAEoDVIT'
    'cmF0ZUxpbWl0V2luZG93U2VjcxIzChZyYXRlX2xpbWl0X21heF9wYWNrZXRzGAkgASgNUhNyYX'
    'RlTGltaXRNYXhQYWNrZXRzEjgKGHVua25vd25fcGFja2V0X3RocmVzaG9sZBgLIAEoDVIWdW5r'
    'bm93blBhY2tldFRocmVzaG9sZEoECAEQAkoECAIQA0oECAMQBEoECAUQBkoECAcQCEoECAoQC0'
    'oECAwQDUoECA0QDkoECA4QD1IHZW5hYmxlZFIWcG9zaXRpb25fZGVkdXBfZW5hYmxlZFIXcG9z'
    'aXRpb25fcHJlY2lzaW9uX2JpdHNSGG5vZGVpbmZvX2RpcmVjdF9yZXNwb25zZVIScmF0ZV9saW'
    '1pdF9lbmFibGVkUhRkcm9wX3Vua25vd25fZW5hYmxlZFIVZXhoYXVzdF9ob3BfdGVsZW1ldHJ5'
    'UhRleGhhdXN0X2hvcF9wb3NpdGlvblIUcm91dGVyX3ByZXNlcnZlX2hvcHMa7AUKDFNlcmlhbE'
    'NvbmZpZxIYCgdlbmFibGVkGAEgASgIUgdlbmFibGVkEhIKBGVjaG8YAiABKAhSBGVjaG8SEAoD'
    'cnhkGAMgASgNUgNyeGQSEAoDdHhkGAQgASgNUgN0eGQSRQoEYmF1ZBgFIAEoDjIxLm1lc2h0YX'
    'N0aWMuTW9kdWxlQ29uZmlnLlNlcmlhbENvbmZpZy5TZXJpYWxfQmF1ZFIEYmF1ZBIYCgd0aW1l'
    'b3V0GAYgASgNUgd0aW1lb3V0EkUKBG1vZGUYByABKA4yMS5tZXNodGFzdGljLk1vZHVsZUNvbm'
    'ZpZy5TZXJpYWxDb25maWcuU2VyaWFsX01vZGVSBG1vZGUSPwocb3ZlcnJpZGVfY29uc29sZV9z'
    'ZXJpYWxfcG9ydBgIIAEoCFIZb3ZlcnJpZGVDb25zb2xlU2VyaWFsUG9ydCKKAgoLU2VyaWFsX0'
    'JhdWQSEAoMQkFVRF9ERUZBVUxUEAASDAoIQkFVRF8xMTAQARIMCghCQVVEXzMwMBACEgwKCEJB'
    'VURfNjAwEAMSDQoJQkFVRF8xMjAwEAQSDQoJQkFVRF8yNDAwEAUSDQoJQkFVRF80ODAwEAYSDQ'
    'oJQkFVRF85NjAwEAcSDgoKQkFVRF8xOTIwMBAIEg4KCkJBVURfMzg0MDAQCRIOCgpCQVVEXzU3'
    'NjAwEAoSDwoLQkFVRF8xMTUyMDAQCxIPCgtCQVVEXzIzMDQwMBAMEg8KC0JBVURfNDYwODAwEA'
    '0SDwoLQkFVRF81NzYwMDAQDhIPCgtCQVVEXzkyMTYwMBAPIpMBCgtTZXJpYWxfTW9kZRILCgdE'
    'RUZBVUxUEAASCgoGU0lNUExFEAESCQoFUFJPVE8QAhILCgdURVhUTVNHEAMSCAoETk1FQRAEEg'
    'sKB0NBTFRPUE8QBRIICgRXUzg1EAYSDQoJVkVfRElSRUNUEAcSDQoJTVNfQ09ORklHEAgSBwoD'
    'TE9HEAkSCwoHTE9HVEVYVBAKGqwEChpFeHRlcm5hbE5vdGlmaWNhdGlvbkNvbmZpZxIYCgdlbm'
    'FibGVkGAEgASgIUgdlbmFibGVkEhsKCW91dHB1dF9tcxgCIAEoDVIIb3V0cHV0TXMSFgoGb3V0'
    'cHV0GAMgASgNUgZvdXRwdXQSIQoMb3V0cHV0X3ZpYnJhGAggASgNUgtvdXRwdXRWaWJyYRIjCg'
    '1vdXRwdXRfYnV6emVyGAkgASgNUgxvdXRwdXRCdXp6ZXISFgoGYWN0aXZlGAQgASgIUgZhY3Rp'
    'dmUSIwoNYWxlcnRfbWVzc2FnZRgFIAEoCFIMYWxlcnRNZXNzYWdlEi4KE2FsZXJ0X21lc3NhZ2'
    'VfdmlicmEYCiABKAhSEWFsZXJ0TWVzc2FnZVZpYnJhEjAKFGFsZXJ0X21lc3NhZ2VfYnV6emVy'
    'GAsgASgIUhJhbGVydE1lc3NhZ2VCdXp6ZXISHQoKYWxlcnRfYmVsbBgGIAEoCFIJYWxlcnRCZW'
    'xsEigKEGFsZXJ0X2JlbGxfdmlicmEYDCABKAhSDmFsZXJ0QmVsbFZpYnJhEioKEWFsZXJ0X2Jl'
    'bGxfYnV6emVyGA0gASgIUg9hbGVydEJlbGxCdXp6ZXISFwoHdXNlX3B3bRgHIAEoCFIGdXNlUH'
    'dtEh8KC25hZ190aW1lb3V0GA4gASgNUgpuYWdUaW1lb3V0EikKEXVzZV9pMnNfYXNfYnV6emVy'
    'GA8gASgIUg51c2VJMnNBc0J1enplchrlAQoSU3RvcmVGb3J3YXJkQ29uZmlnEhgKB2VuYWJsZW'
    'QYASABKAhSB2VuYWJsZWQSHAoJaGVhcnRiZWF0GAIgASgIUgloZWFydGJlYXQSGAoHcmVjb3Jk'
    'cxgDIAEoDVIHcmVjb3JkcxIsChJoaXN0b3J5X3JldHVybl9tYXgYBCABKA1SEGhpc3RvcnlSZX'
    'R1cm5NYXgSMgoVaGlzdG9yeV9yZXR1cm5fd2luZG93GAUgASgNUhNoaXN0b3J5UmV0dXJuV2lu'
    'ZG93EhsKCWlzX3NlcnZlchgGIAEoCFIIaXNTZXJ2ZXIafwoPUmFuZ2VUZXN0Q29uZmlnEhgKB2'
    'VuYWJsZWQYASABKAhSB2VuYWJsZWQSFgoGc2VuZGVyGAIgASgNUgZzZW5kZXISEgoEc2F2ZRgD'
    'IAEoCFIEc2F2ZRImCg9jbGVhcl9vbl9yZWJvb3QYBCABKAhSDWNsZWFyT25SZWJvb3Qa9gYKD1'
    'RlbGVtZXRyeUNvbmZpZxI0ChZkZXZpY2VfdXBkYXRlX2ludGVydmFsGAEgASgNUhRkZXZpY2VV'
    'cGRhdGVJbnRlcnZhbBI+ChtlbnZpcm9ubWVudF91cGRhdGVfaW50ZXJ2YWwYAiABKA1SGWVudm'
    'lyb25tZW50VXBkYXRlSW50ZXJ2YWwSRgofZW52aXJvbm1lbnRfbWVhc3VyZW1lbnRfZW5hYmxl'
    'ZBgDIAEoCFIdZW52aXJvbm1lbnRNZWFzdXJlbWVudEVuYWJsZWQSPAoaZW52aXJvbm1lbnRfc2'
    'NyZWVuX2VuYWJsZWQYBCABKAhSGGVudmlyb25tZW50U2NyZWVuRW5hYmxlZBJECh5lbnZpcm9u'
    'bWVudF9kaXNwbGF5X2ZhaHJlbmhlaXQYBSABKAhSHGVudmlyb25tZW50RGlzcGxheUZhaHJlbm'
    'hlaXQSLgoTYWlyX3F1YWxpdHlfZW5hYmxlZBgGIAEoCFIRYWlyUXVhbGl0eUVuYWJsZWQSMAoU'
    'YWlyX3F1YWxpdHlfaW50ZXJ2YWwYByABKA1SEmFpclF1YWxpdHlJbnRlcnZhbBI6Chlwb3dlcl'
    '9tZWFzdXJlbWVudF9lbmFibGVkGAggASgIUhdwb3dlck1lYXN1cmVtZW50RW5hYmxlZBIyChVw'
    'b3dlcl91cGRhdGVfaW50ZXJ2YWwYCSABKA1SE3Bvd2VyVXBkYXRlSW50ZXJ2YWwSMAoUcG93ZX'
    'Jfc2NyZWVuX2VuYWJsZWQYCiABKAhSEnBvd2VyU2NyZWVuRW5hYmxlZBI8ChpoZWFsdGhfbWVh'
    'c3VyZW1lbnRfZW5hYmxlZBgLIAEoCFIYaGVhbHRoTWVhc3VyZW1lbnRFbmFibGVkEjQKFmhlYW'
    'x0aF91cGRhdGVfaW50ZXJ2YWwYDCABKA1SFGhlYWx0aFVwZGF0ZUludGVydmFsEjIKFWhlYWx0'
    'aF9zY3JlZW5fZW5hYmxlZBgNIAEoCFITaGVhbHRoU2NyZWVuRW5hYmxlZBI4ChhkZXZpY2VfdG'
    'VsZW1ldHJ5X2VuYWJsZWQYDiABKAhSFmRldmljZVRlbGVtZXRyeUVuYWJsZWQSOwoaYWlyX3F1'
    'YWxpdHlfc2NyZWVuX2VuYWJsZWQYDyABKAhSF2FpclF1YWxpdHlTY3JlZW5FbmFibGVkGpoGCh'
    'NDYW5uZWRNZXNzYWdlQ29uZmlnEicKD3JvdGFyeTFfZW5hYmxlZBgBIAEoCFIOcm90YXJ5MUVu'
    'YWJsZWQSKgoRaW5wdXRicm9rZXJfcGluX2EYAiABKA1SD2lucHV0YnJva2VyUGluQRIqChFpbn'
    'B1dGJyb2tlcl9waW5fYhgDIAEoDVIPaW5wdXRicm9rZXJQaW5CEjIKFWlucHV0YnJva2VyX3Bp'
    'bl9wcmVzcxgEIAEoDVITaW5wdXRicm9rZXJQaW5QcmVzcxJtChRpbnB1dGJyb2tlcl9ldmVudF'
    '9jdxgFIAEoDjI7Lm1lc2h0YXN0aWMuTW9kdWxlQ29uZmlnLkNhbm5lZE1lc3NhZ2VDb25maWcu'
    'SW5wdXRFdmVudENoYXJSEmlucHV0YnJva2VyRXZlbnRDdxJvChVpbnB1dGJyb2tlcl9ldmVudF'
    '9jY3cYBiABKA4yOy5tZXNodGFzdGljLk1vZHVsZUNvbmZpZy5DYW5uZWRNZXNzYWdlQ29uZmln'
    'LklucHV0RXZlbnRDaGFyUhNpbnB1dGJyb2tlckV2ZW50Q2N3EnMKF2lucHV0YnJva2VyX2V2ZW'
    '50X3ByZXNzGAcgASgOMjsubWVzaHRhc3RpYy5Nb2R1bGVDb25maWcuQ2FubmVkTWVzc2FnZUNv'
    'bmZpZy5JbnB1dEV2ZW50Q2hhclIVaW5wdXRicm9rZXJFdmVudFByZXNzEicKD3VwZG93bjFfZW'
    '5hYmxlZBgIIAEoCFIOdXBkb3duMUVuYWJsZWQSHAoHZW5hYmxlZBgJIAEoCEICGAFSB2VuYWJs'
    'ZWQSMAoSYWxsb3dfaW5wdXRfc291cmNlGAogASgJQgIYAVIQYWxsb3dJbnB1dFNvdXJjZRIbCg'
    'lzZW5kX2JlbGwYCyABKAhSCHNlbmRCZWxsImMKDklucHV0RXZlbnRDaGFyEggKBE5PTkUQABIG'
    'CgJVUBAREggKBERPV04QEhIICgRMRUZUEBMSCQoFUklHSFQQFBIKCgZTRUxFQ1QQChIICgRCQU'
    'NLEBsSCgoGQ0FOQ0VMEBgaigEKFUFtYmllbnRMaWdodGluZ0NvbmZpZxIbCglsZWRfc3RhdGUY'
    'ASABKAhSCGxlZFN0YXRlEhgKB2N1cnJlbnQYAiABKA1SB2N1cnJlbnQSEAoDcmVkGAMgASgNUg'
    'NyZWQSFAoFZ3JlZW4YBCABKA1SBWdyZWVuEhIKBGJsdWUYBSABKA1SBGJsdWUaNgoTU3RhdHVz'
    'TWVzc2FnZUNvbmZpZxIfCgtub2RlX3N0YXR1cxgBIAEoCVIKbm9kZVN0YXR1cxrkBwoQTWVzaE'
    'JlYWNvbkNvbmZpZxIUCgVmbGFncxgBIAEoDVIFZmxhZ3MSKwoRYnJvYWRjYXN0X21lc3NhZ2UY'
    'BCABKAlSEGJyb2FkY2FzdE1lc3NhZ2USUwoXYnJvYWRjYXN0X29mZmVyX2NoYW5uZWwYBSABKA'
    'syGy5tZXNodGFzdGljLkNoYW5uZWxTZXR0aW5nc1IVYnJvYWRjYXN0T2ZmZXJDaGFubmVsEl4K'
    'FmJyb2FkY2FzdF9vZmZlcl9yZWdpb24YBiABKA4yKC5tZXNodGFzdGljLkNvbmZpZy5Mb1JhQ2'
    '9uZmlnLlJlZ2lvbkNvZGVSFGJyb2FkY2FzdE9mZmVyUmVnaW9uEmQKFmJyb2FkY2FzdF9vZmZl'
    'cl9wcmVzZXQYByABKA4yKS5tZXNodGFzdGljLkNvbmZpZy5Mb1JhQ29uZmlnLk1vZGVtUHJlc2'
    'V0SABSFGJyb2FkY2FzdE9mZmVyUHJlc2V0iAEBEjYKF2Jyb2FkY2FzdF9pbnRlcnZhbF9zZWNz'
    'GAsgASgNUhVicm9hZGNhc3RJbnRlcnZhbFNlY3MSZgoRYnJvYWRjYXN0X3RhcmdldHMYDSADKA'
    'syOS5tZXNodGFzdGljLk1vZHVsZUNvbmZpZy5NZXNoQmVhY29uQ29uZmlnLkJyb2FkY2FzdFRh'
    'cmdldFIQYnJvYWRjYXN0VGFyZ2V0cxriAQoPQnJvYWRjYXN0VGFyZ2V0EkYKBnByZXNldBgBIA'
    'EoDjIpLm1lc2h0YXN0aWMuQ29uZmlnLkxvUmFDb25maWcuTW9kZW1QcmVzZXRIAFIGcHJlc2V0'
    'iAEBEkAKBnJlZ2lvbhgCIAEoDjIoLm1lc2h0YXN0aWMuQ29uZmlnLkxvUmFDb25maWcuUmVnaW'
    '9uQ29kZVIGcmVnaW9uEigKDWNoYW5uZWxfaW5kZXgYBCABKA1IAVIMY2hhbm5lbEluZGV4iAEB'
    'QgkKB19wcmVzZXRCEAoOX2NoYW5uZWxfaW5kZXgiYgoFRmxhZ3MSDQoJRkxBR19OT05FEAASFw'
    'oTRkxBR19MSVNURU5fRU5BQkxFRBABEhoKFkZMQUdfQlJPQURDQVNUX0VOQUJMRUQQAhIVChFG'
    'TEFHX0xFR0FDWV9TUExJVBAEQhkKF19icm9hZGNhc3Rfb2ZmZXJfcHJlc2V0SgQIAxAESgQICB'
    'AJSgQICRAKSgQIChALUhZicm9hZGNhc3Rfc2VuZF9hc19ub2RlUhRicm9hZGNhc3Rfb25fY2hh'
    'bm5lbFITYnJvYWRjYXN0X29uX3JlZ2lvblITYnJvYWRjYXN0X29uX3ByZXNldBpdCglUQUtDb2'
    '5maWcSJAoEdGVhbRgBIAEoDjIQLm1lc2h0YXN0aWMuVGVhbVIEdGVhbRIqCgRyb2xlGAIgASgO'
    'MhYubWVzaHRhc3RpYy5NZW1iZXJSb2xlUgRyb2xlQhEKD3BheWxvYWRfdmFyaWFudA==');

@$core.Deprecated('Use remoteHardwarePinDescriptor instead')
const RemoteHardwarePin$json = {
  '1': 'RemoteHardwarePin',
  '2': [
    {'1': 'gpio_pin', '3': 1, '4': 1, '5': 13, '10': 'gpioPin'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'type',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.RemoteHardwarePinType',
      '10': 'type'
    },
  ],
};

/// Descriptor for `RemoteHardwarePin`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List remoteHardwarePinDescriptor = $convert.base64Decode(
    'ChFSZW1vdGVIYXJkd2FyZVBpbhIZCghncGlvX3BpbhgBIAEoDVIHZ3Bpb1BpbhISCgRuYW1lGA'
    'IgASgJUgRuYW1lEjUKBHR5cGUYAyABKA4yIS5tZXNodGFzdGljLlJlbW90ZUhhcmR3YXJlUGlu'
    'VHlwZVIEdHlwZQ==');
