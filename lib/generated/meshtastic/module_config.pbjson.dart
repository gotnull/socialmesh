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
      '8': {},
      '9': 0,
      '10': 'statusmessage'
    },
    {
      '1': 'traffic_management',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.TrafficManagementConfig',
      '8': {},
      '9': 0,
      '10': 'trafficManagement'
    },
    {
      '1': 'tak',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.TAKConfig',
      '8': {},
      '9': 0,
      '10': 'tak'
    },
    {
      '1': 'mesh_beacon',
      '3': 17,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.ModuleConfig.MeshBeaconConfig',
      '8': {},
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
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '8': {}, '10': 'enabled'},
    {'1': 'address', '3': 2, '4': 1, '5': 9, '8': {}, '10': 'address'},
    {'1': 'username', '3': 3, '4': 1, '5': 9, '8': {}, '10': 'username'},
    {'1': 'password', '3': 4, '4': 1, '5': 9, '8': {}, '10': 'password'},
    {
      '1': 'encryption_enabled',
      '3': 5,
      '4': 1,
      '5': 8,
      '8': {},
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
    {'1': 'tls_enabled', '3': 7, '4': 1, '5': 8, '8': {}, '10': 'tlsEnabled'},
    {'1': 'root', '3': 8, '4': 1, '5': 9, '8': {}, '10': 'root'},
    {
      '1': 'proxy_to_client_enabled',
      '3': 9,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'proxyToClientEnabled'
    },
    {
      '1': 'map_reporting_enabled',
      '3': 10,
      '4': 1,
      '5': 8,
      '8': {},
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
      '8': {},
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
      '8': {},
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
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '8': {}, '10': 'enabled'},
    {
      '1': 'update_interval',
      '3': 2,
      '4': 1,
      '5': 13,
      '8': {},
      '10': 'updateInterval'
    },
    {
      '1': 'transmit_over_lora',
      '3': 3,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'transmitOverLora'
    },
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_DetectionSensorConfig$json = {
  '1': 'DetectionSensorConfig',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '8': {}, '10': 'enabled'},
    {
      '1': 'minimum_broadcast_secs',
      '3': 2,
      '4': 1,
      '5': 13,
      '8': {},
      '10': 'minimumBroadcastSecs'
    },
    {
      '1': 'state_broadcast_secs',
      '3': 3,
      '4': 1,
      '5': 13,
      '8': {},
      '10': 'stateBroadcastSecs'
    },
    {'1': 'send_bell', '3': 4, '4': 1, '5': 8, '8': {}, '10': 'sendBell'},
    {'1': 'name', '3': 5, '4': 1, '5': 9, '8': {}, '10': 'name'},
    {'1': 'monitor_pin', '3': 6, '4': 1, '5': 13, '8': {}, '10': 'monitorPin'},
    {
      '1': 'detection_trigger_type',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.ModuleConfig.DetectionSensorConfig.TriggerType',
      '8': {},
      '10': 'detectionTriggerType'
    },
    {'1': 'use_pullup', '3': 8, '4': 1, '5': 8, '8': {}, '10': 'usePullup'},
  ],
  '4': [ModuleConfig_DetectionSensorConfig_TriggerType$json],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_DetectionSensorConfig_TriggerType$json = {
  '1': 'TriggerType',
  '2': [
    {'1': 'LOGIC_LOW', '2': 0, '3': {}},
    {'1': 'LOGIC_HIGH', '2': 1, '3': {}},
    {'1': 'FALLING_EDGE', '2': 2, '3': {}},
    {'1': 'RISING_EDGE', '2': 3, '3': {}},
    {'1': 'EITHER_EDGE_ACTIVE_LOW', '2': 4, '3': {}},
    {'1': 'EITHER_EDGE_ACTIVE_HIGH', '2': 5, '3': {}},
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_AudioConfig$json = {
  '1': 'AudioConfig',
  '2': [
    {
      '1': 'codec2_enabled',
      '3': 1,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'codec2Enabled'
    },
    {'1': 'ptt_pin', '3': 2, '4': 1, '5': 13, '8': {}, '10': 'pttPin'},
    {
      '1': 'bitrate',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.ModuleConfig.AudioConfig.Audio_Baud',
      '8': {},
      '10': 'bitrate'
    },
    {'1': 'i2s_ws', '3': 4, '4': 1, '5': 13, '8': {}, '10': 'i2sWs'},
    {'1': 'i2s_sd', '3': 5, '4': 1, '5': 13, '8': {}, '10': 'i2sSd'},
    {'1': 'i2s_din', '3': 6, '4': 1, '5': 13, '8': {}, '10': 'i2sDin'},
    {'1': 'i2s_sck', '3': 7, '4': 1, '5': 13, '8': {}, '10': 'i2sSck'},
  ],
  '4': [ModuleConfig_AudioConfig_Audio_Baud$json],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_AudioConfig_Audio_Baud$json = {
  '1': 'Audio_Baud',
  '2': [
    {'1': 'CODEC2_DEFAULT', '2': 0, '3': {}},
    {'1': 'CODEC2_3200', '2': 1, '3': {}},
    {'1': 'CODEC2_2400', '2': 2, '3': {}},
    {'1': 'CODEC2_1600', '2': 3, '3': {}},
    {'1': 'CODEC2_1400', '2': 4, '3': {}},
    {'1': 'CODEC2_1300', '2': 5, '3': {}},
    {'1': 'CODEC2_1200', '2': 6, '3': {}},
    {
      '1': 'CODEC2_700',
      '2': 7,
      '3': {'1': true},
    },
    {
      '1': 'CODEC2_700B',
      '2': 8,
      '3': {'1': true},
    },
    {'1': 'CODEC2_700C', '2': 9, '3': {}},
    {'1': 'CODEC2_450', '2': 10, '3': {}},
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_PaxcounterConfig$json = {
  '1': 'PaxcounterConfig',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '8': {}, '10': 'enabled'},
    {
      '1': 'paxcounter_update_interval',
      '3': 2,
      '4': 1,
      '5': 13,
      '8': {},
      '10': 'paxcounterUpdateInterval'
    },
    {
      '1': 'wifi_threshold',
      '3': 3,
      '4': 1,
      '5': 5,
      '8': {},
      '10': 'wifiThreshold'
    },
    {
      '1': 'ble_threshold',
      '3': 4,
      '4': 1,
      '5': 5,
      '8': {},
      '10': 'bleThreshold'
    },
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
      '8': {},
      '10': 'positionMinIntervalSecs'
    },
    {
      '1': 'nodeinfo_direct_response_max_hops',
      '3': 6,
      '4': 1,
      '5': 13,
      '8': {},
      '10': 'nodeinfoDirectResponseMaxHops'
    },
    {
      '1': 'rate_limit_window_secs',
      '3': 8,
      '4': 1,
      '5': 13,
      '8': {},
      '10': 'rateLimitWindowSecs'
    },
    {
      '1': 'rate_limit_max_packets',
      '3': 9,
      '4': 1,
      '5': 13,
      '8': {},
      '10': 'rateLimitMaxPackets'
    },
    {
      '1': 'unknown_packet_threshold',
      '3': 11,
      '4': 1,
      '5': 13,
      '8': {},
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
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '8': {}, '10': 'enabled'},
    {'1': 'echo', '3': 2, '4': 1, '5': 8, '8': {}, '10': 'echo'},
    {'1': 'rxd', '3': 3, '4': 1, '5': 13, '8': {}, '10': 'rxd'},
    {'1': 'txd', '3': 4, '4': 1, '5': 13, '8': {}, '10': 'txd'},
    {
      '1': 'baud',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.ModuleConfig.SerialConfig.Serial_Baud',
      '8': {},
      '10': 'baud'
    },
    {'1': 'timeout', '3': 6, '4': 1, '5': 13, '8': {}, '10': 'timeout'},
    {
      '1': 'mode',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.ModuleConfig.SerialConfig.Serial_Mode',
      '8': {},
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
    {'1': 'BAUD_DEFAULT', '2': 0, '3': {}},
    {'1': 'BAUD_110', '2': 1, '3': {}},
    {'1': 'BAUD_300', '2': 2, '3': {}},
    {'1': 'BAUD_600', '2': 3, '3': {}},
    {'1': 'BAUD_1200', '2': 4, '3': {}},
    {'1': 'BAUD_2400', '2': 5, '3': {}},
    {'1': 'BAUD_4800', '2': 6, '3': {}},
    {'1': 'BAUD_9600', '2': 7, '3': {}},
    {'1': 'BAUD_19200', '2': 8, '3': {}},
    {'1': 'BAUD_38400', '2': 9, '3': {}},
    {'1': 'BAUD_57600', '2': 10, '3': {}},
    {'1': 'BAUD_115200', '2': 11, '3': {}},
    {'1': 'BAUD_230400', '2': 12, '3': {}},
    {'1': 'BAUD_460800', '2': 13, '3': {}},
    {'1': 'BAUD_576000', '2': 14, '3': {}},
    {'1': 'BAUD_921600', '2': 15, '3': {}},
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_SerialConfig_Serial_Mode$json = {
  '1': 'Serial_Mode',
  '2': [
    {'1': 'DEFAULT', '2': 0, '3': {}},
    {'1': 'SIMPLE', '2': 1, '3': {}},
    {'1': 'PROTO', '2': 2, '3': {}},
    {'1': 'TEXTMSG', '2': 3, '3': {}},
    {'1': 'NMEA', '2': 4, '3': {}},
    {'1': 'CALTOPO', '2': 5, '3': {}},
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
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '8': {}, '10': 'enabled'},
    {'1': 'output_ms', '3': 2, '4': 1, '5': 13, '8': {}, '10': 'outputMs'},
    {'1': 'output', '3': 3, '4': 1, '5': 13, '8': {}, '10': 'output'},
    {
      '1': 'output_vibra',
      '3': 8,
      '4': 1,
      '5': 13,
      '8': {},
      '10': 'outputVibra'
    },
    {
      '1': 'output_buzzer',
      '3': 9,
      '4': 1,
      '5': 13,
      '8': {},
      '10': 'outputBuzzer'
    },
    {'1': 'active', '3': 4, '4': 1, '5': 8, '8': {}, '10': 'active'},
    {
      '1': 'alert_message',
      '3': 5,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'alertMessage'
    },
    {
      '1': 'alert_message_vibra',
      '3': 10,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'alertMessageVibra'
    },
    {
      '1': 'alert_message_buzzer',
      '3': 11,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'alertMessageBuzzer'
    },
    {'1': 'alert_bell', '3': 6, '4': 1, '5': 8, '8': {}, '10': 'alertBell'},
    {
      '1': 'alert_bell_vibra',
      '3': 12,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'alertBellVibra'
    },
    {
      '1': 'alert_bell_buzzer',
      '3': 13,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'alertBellBuzzer'
    },
    {'1': 'use_pwm', '3': 7, '4': 1, '5': 8, '8': {}, '10': 'usePwm'},
    {'1': 'nag_timeout', '3': 14, '4': 1, '5': 13, '8': {}, '10': 'nagTimeout'},
    {
      '1': 'use_i2s_as_buzzer',
      '3': 15,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'useI2sAsBuzzer'
    },
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_StoreForwardConfig$json = {
  '1': 'StoreForwardConfig',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '8': {}, '10': 'enabled'},
    {'1': 'heartbeat', '3': 2, '4': 1, '5': 8, '8': {}, '10': 'heartbeat'},
    {'1': 'records', '3': 3, '4': 1, '5': 13, '8': {}, '10': 'records'},
    {
      '1': 'history_return_max',
      '3': 4,
      '4': 1,
      '5': 13,
      '8': {},
      '10': 'historyReturnMax'
    },
    {
      '1': 'history_return_window',
      '3': 5,
      '4': 1,
      '5': 13,
      '8': {},
      '10': 'historyReturnWindow'
    },
    {'1': 'is_server', '3': 6, '4': 1, '5': 8, '8': {}, '10': 'isServer'},
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_RangeTestConfig$json = {
  '1': 'RangeTestConfig',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '8': {}, '10': 'enabled'},
    {'1': 'sender', '3': 2, '4': 1, '5': 13, '8': {}, '10': 'sender'},
    {'1': 'save', '3': 3, '4': 1, '5': 8, '8': {}, '10': 'save'},
    {
      '1': 'clear_on_reboot',
      '3': 4,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'clearOnReboot'
    },
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
      '8': {},
      '10': 'deviceUpdateInterval'
    },
    {
      '1': 'environment_update_interval',
      '3': 2,
      '4': 1,
      '5': 13,
      '8': {},
      '10': 'environmentUpdateInterval'
    },
    {
      '1': 'environment_measurement_enabled',
      '3': 3,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'environmentMeasurementEnabled'
    },
    {
      '1': 'environment_screen_enabled',
      '3': 4,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'environmentScreenEnabled'
    },
    {
      '1': 'environment_display_fahrenheit',
      '3': 5,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'environmentDisplayFahrenheit'
    },
    {
      '1': 'air_quality_enabled',
      '3': 6,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'airQualityEnabled'
    },
    {
      '1': 'air_quality_interval',
      '3': 7,
      '4': 1,
      '5': 13,
      '8': {},
      '10': 'airQualityInterval'
    },
    {
      '1': 'power_measurement_enabled',
      '3': 8,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'powerMeasurementEnabled'
    },
    {
      '1': 'power_update_interval',
      '3': 9,
      '4': 1,
      '5': 13,
      '8': {},
      '10': 'powerUpdateInterval'
    },
    {
      '1': 'power_screen_enabled',
      '3': 10,
      '4': 1,
      '5': 8,
      '8': {},
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
      '8': {},
      '10': 'deviceTelemetryEnabled'
    },
    {
      '1': 'air_quality_screen_enabled',
      '3': 15,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'airQualityScreenEnabled'
    },
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_CannedMessageConfig$json = {
  '1': 'CannedMessageConfig',
  '2': [
    {
      '1': 'rotary1_enabled',
      '3': 1,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'rotary1Enabled'
    },
    {
      '1': 'inputbroker_pin_a',
      '3': 2,
      '4': 1,
      '5': 13,
      '8': {},
      '10': 'inputbrokerPinA'
    },
    {
      '1': 'inputbroker_pin_b',
      '3': 3,
      '4': 1,
      '5': 13,
      '8': {},
      '10': 'inputbrokerPinB'
    },
    {
      '1': 'inputbroker_pin_press',
      '3': 4,
      '4': 1,
      '5': 13,
      '8': {},
      '10': 'inputbrokerPinPress'
    },
    {
      '1': 'inputbroker_event_cw',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.ModuleConfig.CannedMessageConfig.InputEventChar',
      '8': {},
      '10': 'inputbrokerEventCw'
    },
    {
      '1': 'inputbroker_event_ccw',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.ModuleConfig.CannedMessageConfig.InputEventChar',
      '8': {},
      '10': 'inputbrokerEventCcw'
    },
    {
      '1': 'inputbroker_event_press',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.ModuleConfig.CannedMessageConfig.InputEventChar',
      '8': {},
      '10': 'inputbrokerEventPress'
    },
    {
      '1': 'updown1_enabled',
      '3': 8,
      '4': 1,
      '5': 8,
      '8': {},
      '10': 'updown1Enabled'
    },
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
    {'1': 'send_bell', '3': 11, '4': 1, '5': 8, '8': {}, '10': 'sendBell'},
  ],
  '4': [ModuleConfig_CannedMessageConfig_InputEventChar$json],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_CannedMessageConfig_InputEventChar$json = {
  '1': 'InputEventChar',
  '2': [
    {'1': 'NONE', '2': 0, '3': {}},
    {'1': 'UP', '2': 17, '3': {}},
    {'1': 'DOWN', '2': 18, '3': {}},
    {'1': 'LEFT', '2': 19, '3': {}},
    {'1': 'RIGHT', '2': 20, '3': {}},
    {'1': 'SELECT', '2': 10, '3': {}},
    {'1': 'BACK', '2': 27, '3': {}},
    {'1': 'CANCEL', '2': 24, '3': {}},
  ],
};

@$core.Deprecated('Use moduleConfigDescriptor instead')
const ModuleConfig_AmbientLightingConfig$json = {
  '1': 'AmbientLightingConfig',
  '2': [
    {'1': 'led_state', '3': 1, '4': 1, '5': 8, '8': {}, '10': 'ledState'},
    {'1': 'current', '3': 2, '4': 1, '5': 13, '8': {}, '10': 'current'},
    {'1': 'red', '3': 3, '4': 1, '5': 13, '8': {}, '10': 'red'},
    {'1': 'green', '3': 4, '4': 1, '5': 13, '8': {}, '10': 'green'},
    {'1': 'blue', '3': 5, '4': 1, '5': 13, '8': {}, '10': 'blue'},
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
      '1': 'broadcast_offer_frequency_slot',
      '3': 2,
      '4': 1,
      '5': 13,
      '9': 0,
      '10': 'broadcastOfferFrequencySlot',
      '17': true
    },
    {
      '1': 'broadcast_message',
      '3': 4,
      '4': 1,
      '5': 9,
      '8': {},
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
      '9': 1,
      '10': 'broadcastOfferPreset',
      '17': true
    },
    {
      '1': 'broadcast_interval_secs',
      '3': 11,
      '4': 1,
      '5': 13,
      '8': {},
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
    {'1': '_broadcast_offer_frequency_slot'},
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
    {
      '1': 'frequency_slot',
      '3': 5,
      '4': 1,
      '5': 13,
      '9': 2,
      '10': 'frequencySlot',
      '17': true
    },
  ],
  '8': [
    {'1': '_preset'},
    {'1': '_channel_index'},
    {'1': '_frequency_slot'},
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
      '8': {},
      '10': 'team'
    },
    {
      '1': 'role',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.MemberRole',
      '8': {},
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
    'pwYXhjb3VudGVyEmIKDXN0YXR1c21lc3NhZ2UYDiABKAsyLC5tZXNodGFzdGljLk1vZHVsZUNv'
    'bmZpZy5TdGF0dXNNZXNzYWdlQ29uZmlnQgzK8xgIUgYyLjcuMjBIAFINc3RhdHVzbWVzc2FnZR'
    'JuChJ0cmFmZmljX21hbmFnZW1lbnQYDyABKAsyMC5tZXNodGFzdGljLk1vZHVsZUNvbmZpZy5U'
    'cmFmZmljTWFuYWdlbWVudENvbmZpZ0ILyvMYB1IFMi44LjBIAFIRdHJhZmZpY01hbmFnZW1lbn'
    'QSQwoDdGFrGBAgASgLMiIubWVzaHRhc3RpYy5Nb2R1bGVDb25maWcuVEFLQ29uZmlnQgvK8xgH'
    'UgUyLjguMEgAUgN0YWsSWQoLbWVzaF9iZWFjb24YESABKAsyKS5tZXNodGFzdGljLk1vZHVsZU'
    'NvbmZpZy5NZXNoQmVhY29uQ29uZmlnQgvK8xgHUgUyLjguMEgAUgptZXNoQmVhY29uGvkICgpN'
    'UVRUQ29uZmlnEkEKB2VuYWJsZWQYASABKAhCJ8rzGCM6DE1RVFQgRW5hYmxlZEITRW5hYmxlIE'
    '1RVFQgZ2F0ZXdheVIHZW5hYmxlZBI8CgdhZGRyZXNzGAIgASgJQiLK8xgeOgdBZGRyZXNzQhNN'
    'UVRUIHNlcnZlciBhZGRyZXNzUgdhZGRyZXNzEjkKCHVzZXJuYW1lGAMgASgJQh3K8xgZOghVc2'
    'VybmFtZUINTVFUVCB1c2VybmFtZVIIdXNlcm5hbWUSOQoIcGFzc3dvcmQYBCABKAlCHcrzGBk6'
    'CFBhc3N3b3JkQg1NUVRUIHBhc3N3b3JkUghwYXNzd29yZBJnChJlbmNyeXB0aW9uX2VuYWJsZW'
    'QYBSABKAhCOMrzGDQ6EkVuY3J5cHRpb24gRW5hYmxlZEIeU2VuZCBlbmNyeXB0ZWQgcGFja2V0'
    'cyB0byBNUVRUUhFlbmNyeXB0aW9uRW5hYmxlZBIwCgxqc29uX2VuYWJsZWQYBiABKAhCDRgByv'
    'MYB1oFMi44LjBSC2pzb25FbmFibGVkEmoKC3Rsc19lbmFibGVkGAcgASgIQknK8xhFOgtUTFMg'
    'RW5hYmxlZEI2VExTIGlzIHJlcXVpcmVkIGZvciB0aGUgcHVibGljIE1lc2h0YXN0aWMgTVFUVC'
    'BzZXJ2ZXIuUgp0bHNFbmFibGVkEjUKBHJvb3QYCCABKAlCIcrzGB06ClJvb3QgVG9waWNCD01R'
    'VFQgcm9vdCB0b3BpY1IEcm9vdBKRAQoXcHJveHlfdG9fY2xpZW50X2VuYWJsZWQYCSABKAhCWs'
    'rzGFY6EU1RVFQgQ2xpZW50IFByb3h5QkFVdGlsaXplcyB0aGUgbmV0d29yayBjb25uZWN0aW9u'
    'IG9uIHlvdXIgcGhvbmUgdG8gY29ubmVjdCB0byBNUVRULlIUcHJveHlUb0NsaWVudEVuYWJsZW'
    'QSxQIKFW1hcF9yZXBvcnRpbmdfZW5hYmxlZBgKIAEoCEKQAsrzGIsCOg1NYXAgUmVwb3J0aW5n'
    'QvkBWW91ciBub2RlIHdpbGwgcGVyaW9kaWNhbGx5IHNlbmQgYW4gdW5lbmNyeXB0ZWQgbWFwIH'
    'JlcG9ydCBwYWNrZXQgdG8gdGhlIGNvbmZpZ3VyZWQgTVFUVCBzZXJ2ZXIsIHRoaXMgaW5jbHVk'
    'ZXMgaWQsIHNob3J0IGFuZCBsb25nIG5hbWUsIGFwcHJveGltYXRlIGxvY2F0aW9uLCBoYXJkd2'
    'FyZSBtb2RlbCwgcm9sZSwgZmlybXdhcmUgdmVyc2lvbiwgTG9SYSByZWdpb24sIG1vZGVtIHBy'
    'ZXNldCBhbmQgcHJpbWFyeSBjaGFubmVsIG5hbWUuUhNtYXBSZXBvcnRpbmdFbmFibGVkEloKE2'
    '1hcF9yZXBvcnRfc2V0dGluZ3MYCyABKAsyKi5tZXNodGFzdGljLk1vZHVsZUNvbmZpZy5NYXBS'
    'ZXBvcnRTZXR0aW5nc1IRbWFwUmVwb3J0U2V0dGluZ3MaiQMKEU1hcFJlcG9ydFNldHRpbmdzEn'
    'cKFXB1Ymxpc2hfaW50ZXJ2YWxfc2VjcxgBIAEoDUJDyvMYPyoBczoUTWFwIFB1Ymxpc2ggSW50'
    'ZXJ2YWxCJEhvdyBvZnRlbiBhIG1hcCByZXBvcnQgaXMgcHVibGlzaGVkLlITcHVibGlzaEludG'
    'VydmFsU2VjcxItChJwb3NpdGlvbl9wcmVjaXNpb24YAiABKA1SEXBvc2l0aW9uUHJlY2lzaW9u'
    'EssBChZzaG91bGRfcmVwb3J0X2xvY2F0aW9uGAMgASgIQpQByvMYjwE6D1JlcG9ydCBMb2NhdG'
    'lvbkJ1SSBoYXZlIHJlYWQgYW5kIHVuZGVyc3RhbmQgdGhlIGFib3ZlLiBJIHZvbHVudGFyaWx5'
    'IGNvbnNlbnQgdG8gdGhlIHVuZW5jcnlwdGVkIHRyYW5zbWlzc2lvbiBvZiBteSBub2RlIGRhdG'
    'EgdmlhIE1RVFQuUgUyLjYuOFIUc2hvdWxkUmVwb3J0TG9jYXRpb24aswEKFFJlbW90ZUhhcmR3'
    'YXJlQ29uZmlnEhgKB2VuYWJsZWQYASABKAhSB2VuYWJsZWQSOwoaYWxsb3dfdW5kZWZpbmVkX3'
    'Bpbl9hY2Nlc3MYAiABKAhSF2FsbG93VW5kZWZpbmVkUGluQWNjZXNzEkQKDmF2YWlsYWJsZV9w'
    'aW5zGAMgAygLMh0ubWVzaHRhc3RpYy5SZW1vdGVIYXJkd2FyZVBpblINYXZhaWxhYmxlUGlucx'
    'qMBAoSTmVpZ2hib3JJbmZvQ29uZmlnErsBCgdlbmFibGVkGAEgASgIQqAByvMYmwE6FU5laWdo'
    'Ym9yIEluZm8gRW5hYmxlZEKBAUVuYWJsZSBuZWlnaGJvciBpbmZvIGJyb2FkY2FzdGluZy4gUG'
    'VyaW9kaWNhbGx5IHNlbmRzIGluZm9ybWF0aW9uIGFib3V0IGRpcmVjdGx5LWhlYXJkIG5laWdo'
    'Ym9ycyB0byBoZWxwIHZpc3VhbGl6ZSBtZXNoIHRvcG9sb2d5LlIHZW5hYmxlZBJoCg91cGRhdG'
    'VfaW50ZXJ2YWwYAiABKA1CP8rzGDsqAXM6D1VwZGF0ZSBJbnRlcnZhbEIlSG93IG9mdGVuIHRv'
    'IGJyb2FkY2FzdCBuZWlnaGJvciBpbmZvLlIOdXBkYXRlSW50ZXJ2YWwSzQEKEnRyYW5zbWl0X2'
    '92ZXJfbG9yYRgDIAEoCEKeAcrzGJkBOhJUcmFuc21pdCBvdmVyIExvUmFCggFXaGV0aGVyIHRv'
    'IHRyYW5zbWl0IG5laWdoYm9yIGluZm8gb3ZlciBMb1JhIGluIGFkZGl0aW9uIHRvIE1RVFQgYW'
    '5kIFBob25lQVBJLiBOb3QgYXZhaWxhYmxlIG9uIGNoYW5uZWxzIHdpdGggZGVmYXVsdCBrZXkg'
    'YW5kIG5hbWUuUhB0cmFuc21pdE92ZXJMb3JhGuQLChVEZXRlY3Rpb25TZW5zb3JDb25maWcSjA'
    'IKB2VuYWJsZWQYASABKAhC8QHK8xjsAToYRGV0ZWN0aW9uIFNlbnNvciBFbmFibGVkQs8BRW5h'
    'YmxlcyB0aGUgZGV0ZWN0aW9uIHNlbnNvciBtb2R1bGUsIGl0IG5lZWRzIHRvIGJlIGVuYWJsZW'
    'Qgb24gYm90aCB0aGUgbm9kZSB3aXRoIHRoZSBzZW5zb3IsIGFuZCBhbnkgbm9kZXMgdGhhdCB5'
    'b3Ugd2FudCB0byByZWNlaXZlIGRldGVjdGlvbiBzZW5zb3IgdGV4dCBtZXNzYWdlcyBvciB2aW'
    'V3IHRoZSBkZXRlY3Rpb24gc2Vuc29yIGxvZyBhbmQgY2hhcnQuUgdlbmFibGVkEpQBChZtaW5p'
    'bXVtX2Jyb2FkY2FzdF9zZWNzGAIgASgNQl7K8xhaKgFzOilNaW5pbXVtIHRpbWUgYmV0d2Vlbi'
    'BkZXRlY3Rpb24gYnJvYWRjYXN0c0IqTWluaW11bSB0aW1lIGJldHdlZW4gZGV0ZWN0aW9uIGJy'
    'b2FkY2FzdHMuUhRtaW5pbXVtQnJvYWRjYXN0U2VjcxK1AQoUc3RhdGVfYnJvYWRjYXN0X3NlY3'
    'MYAyABKA1CggHK8xh+KgFzOhhTdGF0ZSBCcm9hZGNhc3QgSW50ZXJ2YWxCX0hvdyBvZnRlbiB0'
    'byBzZW5kIHRoZSBkZXRlY3Rpb24gc2Vuc29yIHN0YXRlIHRvIHRoZSBtZXNoLCB3aGV0aGVyIG'
    '9yIG5vdCBhbnl0aGluZyB3YXMgZGV0ZWN0ZWQuUhJzdGF0ZUJyb2FkY2FzdFNlY3MShgEKCXNl'
    'bmRfYmVsbBgEIAEoCEJpyvMYZToJU2VuZCBCZWxsQlhTZW5kIEFTQ0lJIGJlbGwgd2l0aCBhbG'
    'VydCBtZXNzYWdlLiBVc2VmdWwgZm9yIHRyaWdnZXJpbmcgZXh0ZXJuYWwgbm90aWZpY2F0aW9u'
    'IG9uIGJlbGwuUghzZW5kQmVsbBI9CgRuYW1lGAUgASgJQinK8xglOgROYW1lQh1TZW5zb3Igbm'
    'FtZSBmb3IgbWVzaCBtZXNzYWdlc1IEbmFtZRJfCgttb25pdG9yX3BpbhgGIAEoDUI+yvMYOjoT'
    'R1BJTyBQaW4gdG8gbW9uaXRvckIjR1BJTyBwaW4gd2F0Y2hlZCBmb3Igc3RhdGUgY2hhbmdlcy'
    '5SCm1vbml0b3JQaW4SmgEKFmRldGVjdGlvbl90cmlnZ2VyX3R5cGUYByABKA4yOi5tZXNodGFz'
    'dGljLk1vZHVsZUNvbmZpZy5EZXRlY3Rpb25TZW5zb3JDb25maWcuVHJpZ2dlclR5cGVCKMrzGC'
    'Q6C1RyaWdnZXJUeXBlQhVUeXBlIG9mIHRyaWdnZXIgZXZlbnRSFGRldGVjdGlvblRyaWdnZXJU'
    'eXBlEq4BCgp1c2VfcHVsbHVwGAggASgIQo4ByvMYiQE6FFVzZXMgcHVsbHVwIHJlc2lzdG9yQn'
    'FXaGV0aGVyIG9yIG5vdCB1c2UgSU5QVVRfUFVMTFVQIG1vZGUgZm9yIEdQSU8gcGluLiBPbmx5'
    'IGFwcGxpY2FibGUgaWYgdGhlIGJvYXJkIHVzZXMgcHVsbC11cCByZXNpc3RvcnMgb24gdGhlIH'
    'BpblIJdXNlUHVsbHVwIvUBCgtUcmlnZ2VyVHlwZRIYCglMT0dJQ19MT1cQABoJyvMYBToDTG93'
    'EhoKCkxPR0lDX0hJR0gQARoKyvMYBjoESGlnaBIkCgxGQUxMSU5HX0VER0UQAhoSyvMYDjoMRm'
    'FsbGluZyBFZGdlEiIKC1JJU0lOR19FREdFEAMaEcrzGA06C1Jpc2luZyBFZGdlEjEKFkVJVEhF'
    'Ul9FREdFX0FDVElWRV9MT1cQBBoVyvMYEToPRWl0aGVyIEVkZ2UgTG93EjMKF0VJVEhFUl9FRE'
    'dFX0FDVElWRV9ISUdIEAUaFsrzGBI6EEVpdGhlciBFZGdlIEhpZ2gasQcKC0F1ZGlvQ29uZmln'
    'EokBCg5jb2RlYzJfZW5hYmxlZBgBIAEoCEJiyvMYXjoOQ29kZWMyIEVuYWJsZWRCTEVuYWJsZS'
    'BDb2RlYzIgYXVkaW8gZW5jb2RpbmcvZGVjb2RpbmcgZm9yIHZvaWNlIGNvbW11bmljYXRpb24g'
    'b3ZlciB0aGUgbWVzaC5SDWNvZGVjMkVuYWJsZWQSRQoHcHR0X3BpbhgCIAEoDUIsyvMYKDoHUF'
    'RUIFBpbkIdUHVzaC10by10YWxrIEdQSU8gcGluIG51bWJlci5SBnB0dFBpbhLTAQoHYml0cmF0'
    'ZRgDIAEoDjIvLm1lc2h0YXN0aWMuTW9kdWxlQ29uZmlnLkF1ZGlvQ29uZmlnLkF1ZGlvX0JhdW'
    'RChwHK8xiCAToHQml0cmF0ZUJ3VGhlIENvZGVjMiBiaXRyYXRlIHRvIHVzZS4gVGhlIHNhbXBs'
    'ZSByYXRlIGlzIGFsd2F5cyA4IGtIei4gTG93ZXIgYml0cmF0ZXMgdXNlIGxlc3MgYmFuZHdpZH'
    'RoIGJ1dCByZWR1Y2UgYXVkaW8gcXVhbGl0eS5SB2JpdHJhdGUSIwoGaTJzX3dzGAQgASgNQgzK'
    '8xgIOgZJMlMgV1NSBWkyc1dzEiMKBmkyc19zZBgFIAEoDUIMyvMYCDoGSTJTIFNEUgVpMnNTZB'
    'ImCgdpMnNfZGluGAYgASgNQg3K8xgJOgdJMlMgRElOUgZpMnNEaW4SJgoHaTJzX3NjaxgHIAEo'
    'DUINyvMYCToHSTJTIFNDS1IGaTJzU2NrIt4CCgpBdWRpb19CYXVkEiEKDkNPREVDMl9ERUZBVU'
    'xUEAAaDcrzGAk6B0RlZmF1bHQSHwoLQ09ERUMyXzMyMDAQARoOyvMYCjoIMzIwMCBicHMSHwoL'
    'Q09ERUMyXzI0MDAQAhoOyvMYCjoIMjQwMCBicHMSHwoLQ09ERUMyXzE2MDAQAxoOyvMYCjoIMT'
    'YwMCBicHMSHwoLQ09ERUMyXzE0MDAQBBoOyvMYCjoIMTQwMCBicHMSHwoLQ09ERUMyXzEzMDAQ'
    'BRoOyvMYCjoIMTMwMCBicHMSHwoLQ09ERUMyXzEyMDAQBhoOyvMYCjoIMTIwMCBicHMSEgoKQ0'
    '9ERUMyXzcwMBAHGgIIARITCgtDT0RFQzJfNzAwQhAIGgIIARIfCgtDT0RFQzJfNzAwQxAJGg7K'
    '8xgKOgg3MDBDIGJwcxIdCgpDT0RFQzJfNDUwEAoaDcrzGAk6BzQ1MCBicHMa6QQKEFBheGNvdW'
    '50ZXJDb25maWcS3gEKB2VuYWJsZWQYASABKAhCwwHK8xi+AToTUEFYIENvdW50ZXIgRW5hYmxl'
    'ZEKmAVdoZW4gZW5hYmxlZCB0aGUgUEFYIENvdW50ZXIgbW9kdWxlIGNvdW50cyB0aGUgbnVtYm'
    'VyIG9mIHBlb3BsZSBwYXNzaW5nIGJ5IHVzaW5nIFdpRmkgYW5kIEJsdWV0b290aC4gQm90aCBX'
    'aUZJIGFuZCBCbHVldG9vdGggbXVzdCBiZSBkaXNhYmxlZCBmb3IgUEFYIGNvdW50ZXIgdG8gd2'
    '9yay5SB2VuYWJsZWQSnQEKGnBheGNvdW50ZXJfdXBkYXRlX2ludGVydmFsGAIgASgNQl/K8xhb'
    'KgFzOg9VcGRhdGUgSW50ZXJ2YWxCRUhvdyBvZnRlbiB3ZSBjYW4gc2VuZCBhIG1lc3NhZ2UgdG'
    '8gdGhlIG1lc2ggd2hlbiBwZW9wbGUgYXJlIGRldGVjdGVkLlIYcGF4Y291bnRlclVwZGF0ZUlu'
    'dGVydmFsEmsKDndpZmlfdGhyZXNob2xkGAMgASgFQkTK8xhAKgNkQm06DldpRmkgVGhyZXNob2'
    'xkQilSU1NJIHRocmVzaG9sZCBmb3IgY291bnRpbmcgV2lGaSBkZXZpY2VzLlINd2lmaVRocmVz'
    'aG9sZBJnCg1ibGVfdGhyZXNob2xkGAQgASgFQkLK8xg+KgNkQm06DUJMRSBUaHJlc2hvbGRCKF'
    'JTU0kgdGhyZXNob2xkIGZvciBjb3VudGluZyBCTEUgZGV2aWNlcy5SDGJsZVRocmVzaG9sZBrf'
    'BwoXVHJhZmZpY01hbmFnZW1lbnRDb25maWcSpAEKGnBvc2l0aW9uX21pbl9pbnRlcnZhbF9zZW'
    'NzGAQgASgNQmfK8xhjKgFzOhlNaW5pbXVtIFBvc2l0aW9uIEludGVydmFsQkNQb3NpdGlvbnMg'
    'ZnJvbSB0aGUgc2FtZSBub2RlIGFycml2aW5nIHNvb25lciB0aGFuIHRoaXMgYXJlIGRyb3BwZW'
    'QuUhdwb3NpdGlvbk1pbkludGVydmFsU2VjcxKXAQohbm9kZWluZm9fZGlyZWN0X3Jlc3BvbnNl'
    'X21heF9ob3BzGAYgASgNQk3K8xhJOhhEaXJlY3QgTm9kZUluZm8gTWF4IEhvcHNCLU9ubHkgYW'
    '5zd2VyIHJlcXVlc3RvcnMgd2l0aGluIHRoaXMgbWFueSBob3BzLlIdbm9kZWluZm9EaXJlY3RS'
    'ZXNwb25zZU1heEhvcHMSegoWcmF0ZV9saW1pdF93aW5kb3dfc2VjcxgIIAEoDUJFyvMYQSoBcz'
    'oRUmF0ZSBMaW1pdCBXaW5kb3dCKVRoZSB0aW1lIHdpbmRvdyBwYWNrZXRzIGFyZSBjb3VudGVk'
    'IG92ZXIuUhNyYXRlTGltaXRXaW5kb3dTZWNzEoEBChZyYXRlX2xpbWl0X21heF9wYWNrZXRzGA'
    'kgASgNQkzK8xhIOhZSYXRlIExpbWl0IE1heCBQYWNrZXRzQi5UaGUgbW9zdCBwYWNrZXRzIG9u'
    'ZSBub2RlIG1heSBzZW5kIHBlciB3aW5kb3cuUhNyYXRlTGltaXRNYXhQYWNrZXRzEosBChh1bm'
    'tub3duX3BhY2tldF90aHJlc2hvbGQYCyABKA1CUcrzGE06GFVua25vd24gUGFja2V0IFRocmVz'
    'aG9sZEIxSG93IG1hbnkgcGVyIHdpbmRvdyBiZWZvcmUgdGhlIHNlbmRlciBpcyBkcm9wcGVkLl'
    'IWdW5rbm93blBhY2tldFRocmVzaG9sZEoECAEQAkoECAIQA0oECAMQBEoECAUQBkoECAcQCEoE'
    'CAoQC0oECAwQDUoECA0QDkoECA4QD1IHZW5hYmxlZFIWcG9zaXRpb25fZGVkdXBfZW5hYmxlZF'
    'IXcG9zaXRpb25fcHJlY2lzaW9uX2JpdHNSGG5vZGVpbmZvX2RpcmVjdF9yZXNwb25zZVIScmF0'
    'ZV9saW1pdF9lbmFibGVkUhRkcm9wX3Vua25vd25fZW5hYmxlZFIVZXhoYXVzdF9ob3BfdGVsZW'
    '1ldHJ5UhRleGhhdXN0X2hvcF9wb3NpdGlvblIUcm91dGVyX3ByZXNlcnZlX2hvcHMa5QsKDFNl'
    'cmlhbENvbmZpZxJECgdlbmFibGVkGAEgASgIQirK8xgmOg5TZXJpYWwgRW5hYmxlZEIURW5hYm'
    'xlIHNlcmlhbCBtb2R1bGVSB2VuYWJsZWQSYAoEZWNobxgCIAEoCEJMyvMYSDoERWNob0JASWYg'
    'c2V0LCBhbnkgcGFja2V0cyB5b3Ugc2VuZCB3aWxsIGJlIGVjaG9lZCBiYWNrIHRvIHlvdXIgZG'
    'V2aWNlLlIEZWNobxJCCgNyeGQYAyABKA1CMMrzGCw6G1JlY2VpdmUgZGF0YSAocnhkKSBHUElP'
    'IHBpbkINUlggcGluIG51bWJlclIDcnhkEkMKA3R4ZBgEIAEoDUIxyvMYLTocVHJhbnNtaXQgZG'
    'F0YSAodHhkKSBHUElPIHBpbkINVFggcGluIG51bWJlclIDdHhkEmMKBGJhdWQYBSABKA4yMS5t'
    'ZXNodGFzdGljLk1vZHVsZUNvbmZpZy5TZXJpYWxDb25maWcuU2VyaWFsX0JhdWRCHMrzGBg6BE'
    'JhdWRCEFNlcmlhbCBiYXVkIHJhdGVSBGJhdWQSawoHdGltZW91dBgGIAEoDUJRyvMYTToHVGlt'
    'ZW91dEJCVGhlIGFtb3VudCBvZiB0aW1lIHRvIHdhaXQgYmVmb3JlIHdlIGNvbnNpZGVyIHlvdX'
    'IgcGFja2V0IGFzIGRvbmUuUgd0aW1lb3V0Em8KBG1vZGUYByABKA4yMS5tZXNodGFzdGljLk1v'
    'ZHVsZUNvbmZpZy5TZXJpYWxDb25maWcuU2VyaWFsX01vZGVCKMrzGCQ6BE1vZGVCHFNlcmlhbC'
    'Btb2R1bGUgb3BlcmF0aW9uIG1vZGVSBG1vZGUSPwocb3ZlcnJpZGVfY29uc29sZV9zZXJpYWxf'
    'cG9ydBgIIAEoCFIZb3ZlcnJpZGVDb25zb2xlU2VyaWFsUG9ydCKiBAoLU2VyaWFsX0JhdWQSHw'
    'oMQkFVRF9ERUZBVUxUEAAaDcrzGAk6B0RlZmF1bHQSHAoIQkFVRF8xMTAQARoOyvMYCjoIMTEw'
    'IEJhdWQSHAoIQkFVRF8zMDAQAhoOyvMYCjoIMzAwIEJhdWQSHAoIQkFVRF82MDAQAxoOyvMYCj'
    'oINjAwIEJhdWQSHgoJQkFVRF8xMjAwEAQaD8rzGAs6CTEyMDAgQmF1ZBIeCglCQVVEXzI0MDAQ'
    'BRoPyvMYCzoJMjQwMCBCYXVkEh4KCUJBVURfNDgwMBAGGg/K8xgLOgk0ODAwIEJhdWQSHgoJQk'
    'FVRF85NjAwEAcaD8rzGAs6CTk2MDAgQmF1ZBIgCgpCQVVEXzE5MjAwEAgaEMrzGAw6CjE5MjAw'
    'IEJhdWQSIAoKQkFVRF8zODQwMBAJGhDK8xgMOgozODQwMCBCYXVkEiAKCkJBVURfNTc2MDAQCh'
    'oQyvMYDDoKNTc2MDAgQmF1ZBIiCgtCQVVEXzExNTIwMBALGhHK8xgNOgsxMTUyMDAgQmF1ZBIi'
    'CgtCQVVEXzIzMDQwMBAMGhHK8xgNOgsyMzA0MDAgQmF1ZBIiCgtCQVVEXzQ2MDgwMBANGhHK8x'
    'gNOgs0NjA4MDAgQmF1ZBIiCgtCQVVEXzU3NjAwMBAOGhHK8xgNOgs1NzYwMDAgQmF1ZBIiCgtC'
    'QVVEXzkyMTYwMBAPGhHK8xgNOgs5MjE2MDAgQmF1ZCL6AQoLU2VyaWFsX01vZGUSGgoHREVGQV'
    'VMVBAAGg3K8xgJOgdEZWZhdWx0EhgKBlNJTVBMRRABGgzK8xgIOgZTaW1wbGUSGgoFUFJPVE8Q'
    'AhoPyvMYCzoJUHJvdG9idWZzEh8KB1RFWFRNU0cQAxoSyvMYDjoMVGV4dCBNZXNzYWdlEh4KBE'
    '5NRUEQBBoUyvMYEDoOTk1FQSBQb3NpdGlvbnMSGgoHQ0FMVE9QTxAFGg3K8xgJOgdDQUxUT1BP'
    'EggKBFdTODUQBhINCglWRV9ESVJFQ1QQBxINCglNU19DT05GSUcQCBIHCgNMT0cQCRILCgdMT0'
    'dURVhUEAoa4g4KGkV4dGVybmFsTm90aWZpY2F0aW9uQ29uZmlnElwKB2VuYWJsZWQYASABKAhC'
    'QsrzGD46HUV4dGVybmFsIE5vdGlmaWNhdGlvbiBFbmFibGVkQh1FbmFibGUgZXh0ZXJuYWwgbm'
    '90aWZpY2F0aW9uc1IHZW5hYmxlZBJqCglvdXRwdXRfbXMYAiABKA1CTcrzGEkqAm1zOhRHUElP'
    'IE91dHB1dCBEdXJhdGlvbkItSW4gR1BJTyBtb2RlLCBob3cgbG9uZyB0byBrZWVwIHRoZSBvdX'
    'RwdXQgb24uUghvdXRwdXRNcxJ7CgZvdXRwdXQYAyABKA1CY8rzGF86D091dHB1dCBwaW4gR1BJ'
    'T0JMR1BJTyBwaW4gZHJpdmVuIG9uIG5vdGlmaWNhdGlvbi4gRGVmYXVsdHMgdG8gdGhlIGJvYX'
    'JkJ3MgRVhUX05PVElGWV9PVVQgcGluLlIGb3V0cHV0EloKDG91dHB1dF92aWJyYRgIIAEoDUI3'
    'yvMYMzoVT3V0cHV0IHBpbiB2aWJyYSBHUElPQhpWaWJyYXRpb24gbW90b3Igb3V0cHV0IHBpbl'
    'ILb3V0cHV0VmlicmESVAoNb3V0cHV0X2J1enplchgJIAEoDUIvyvMYKzoWT3V0cHV0IHBpbiBi'
    'dXp6ZXIgR1BJT0IRQnV6emVyIG91dHB1dCBwaW5SDG91dHB1dEJ1enplchJ5CgZhY3RpdmUYBC'
    'ABKAhCYcrzGF06BkFjdGl2ZUJTSWYgZW5hYmxlZCwgdGhlICdvdXRwdXQnIFBpbiB3aWxsIGJl'
    'IHB1bGxlZCBhY3RpdmUgaGlnaCwgZGlzYWJsZWQgbWVhbnMgYWN0aXZlIGxvdy5SBmFjdGl2ZR'
    'JkCg1hbGVydF9tZXNzYWdlGAUgASgIQj/K8xg7Oh5BbGVydCB3aGVuIHJlY2VpdmluZyBhIG1l'
    'c3NhZ2VCGUFsZXJ0IG9uIGluY29taW5nIG1lc3NhZ2VSDGFsZXJ0TWVzc2FnZRJ4ChNhbGVydF'
    '9tZXNzYWdlX3ZpYnJhGAogASgIQkjK8xhEOhFWaWJyYSBNb3RvciBBbGVydEIvQWxlcnQgR1BJ'
    'TyB2aWJyYSBtb3RvciB3aGVuIHJlY2VpdmluZyBhIG1lc3NhZ2VSEWFsZXJ0TWVzc2FnZVZpYn'
    'JhEnwKFGFsZXJ0X21lc3NhZ2VfYnV6emVyGAsgASgIQkrK8xhGOipBbGVydCBHUElPIGJ1enpl'
    'ciB3aGVuIHJlY2VpdmluZyBhIG1lc3NhZ2VCGEJ1enogb24gaW5jb21pbmcgbWVzc2FnZVISYW'
    'xlcnRNZXNzYWdlQnV6emVyElkKCmFsZXJ0X2JlbGwYBiABKAhCOsrzGDY6G0FsZXJ0IHdoZW4g'
    'cmVjZWl2aW5nIGEgYmVsbEIXQWxlcnQgb24gYmVsbCBjaGFyYWN0ZXJSCWFsZXJ0QmVsbBJ3Ch'
    'BhbGVydF9iZWxsX3ZpYnJhGAwgASgIQk3K8xhJOixBbGVydCBHUElPIHZpYnJhIG1vdG9yIHdo'
    'ZW4gcmVjZWl2aW5nIGEgYmVsbEIZVmlicmF0ZSBvbiBiZWxsIGNoYXJhY3RlclIOYWxlcnRCZW'
    'xsVmlicmEScQoRYWxlcnRfYmVsbF9idXp6ZXIYDSABKAhCRcrzGEE6J0FsZXJ0IEdQSU8gYnV6'
    'emVyIHdoZW4gcmVjZWl2aW5nIGEgYmVsbEIWQnV6eiBvbiBiZWxsIGNoYXJhY3RlclIPYWxlcn'
    'RCZWxsQnV6emVyEvYBCgd1c2VfcHdtGAcgASgIQtwByvMY1wE6DlVzZSBQV00gQnV6emVyQsQB'
    'VXNlIGEgUFdNIG91dHB1dCAobGlrZSB0aGUgUkFLIEJ1enplcikgZm9yIHR1bmVzIGluc3RlYW'
    'Qgb2YgYW4gb24vb2ZmIG91dHB1dC4gVGhpcyB3aWxsIGlnbm9yZSB0aGUgb3V0cHV0LCBvdXRw'
    'dXQgZHVyYXRpb24gYW5kIGFjdGl2ZSBzZXR0aW5ncyBhbmQgdXNlIHRoZSBkZXZpY2UgY29uZm'
    'lnIGJ1enplciBHUElPIG9wdGlvbiBpbnN0ZWFkLlIGdXNlUHdtElcKC25hZ190aW1lb3V0GA4g'
    'ASgNQjbK8xgyKgFzOgtOYWcgVGltZW91dEIgSG93IGxvbmcgdGhlIG5vdGlmaWNhdGlvbiBsYX'
    'N0cy5SCm5hZ1RpbWVvdXQS2AEKEXVzZV9pMnNfYXNfYnV6emVyGA8gASgIQqwByvMYpwE6EVVz'
    'ZSBJMlMgQXMgQnV6emVyQpEBRW5hYmxlcyBkZXZpY2VzIHdpdGggbmF0aXZlIEkyUyBhdWRpby'
    'BvdXRwdXQgdG8gdXNlIHRoZSBSVFRUTCBvdmVyIHNwZWFrZXIgbGlrZSBhIGJ1enplci4gVC1X'
    'YXRjaCBTMyBhbmQgVC1EZWNrIGZvciBleGFtcGxlIGhhdmUgdGhpcyBjYXBhYmlsaXR5LlIOdX'
    'NlSTJzQXNCdXp6ZXIasAQKElN0b3JlRm9yd2FyZENvbmZpZxJgCgdlbmFibGVkGAEgASgIQkbK'
    '8xhCOhlTdG9yZSBhbmQgRm9yd2FyZCBFbmFibGVkQiVFbmFibGVzIHRoZSBzdG9yZSBhbmQgZm'
    '9yd2FyZCBtb2R1bGUuUgdlbmFibGVkEmgKCWhlYXJ0YmVhdBgCIAEoCEJKyvMYRjoOU2VuZCBI'
    'ZWFydGJlYXRCNFNlbmQgYSBoZWFydGJlYXQgdG8gYWR2ZXJ0aXNlIHRoZSBzZXJ2ZXIncyBwcm'
    'VzZW5jZS5SCWhlYXJ0YmVhdBIxCgdyZWNvcmRzGAMgASgNQhfK8xgTOhFOdW1iZXIgb2YgcmVj'
    'b3Jkc1IHcmVjb3JkcxJGChJoaXN0b3J5X3JldHVybl9tYXgYBCABKA1CGMrzGBQ6Ekhpc3Rvcn'
    'kgUmV0dXJuIE1heFIQaGlzdG9yeVJldHVybk1heBJPChVoaXN0b3J5X3JldHVybl93aW5kb3cY'
    'BSABKA1CG8rzGBc6FUhpc3RvcnkgUmV0dXJuIFdpbmRvd1ITaGlzdG9yeVJldHVybldpbmRvdx'
    'KBAQoJaXNfc2VydmVyGAYgASgIQmTK8xhgOgZTZXJ2ZXJCVkVuYWJsZSB0aGlzIGRldmljZSBh'
    'cyBhIFN0b3JlIGFuZCBGb3J3YXJkIHNlcnZlci4gUmVxdWlyZXMgYW4gRVNQMzIgZGV2aWNlIH'
    'dpdGggUFNSQU0uUghpc1NlcnZlchqgAwoPUmFuZ2VUZXN0Q29uZmlnEkwKB2VuYWJsZWQYASAB'
    'KAhCMsrzGC46ElJhbmdlIFRlc3QgRW5hYmxlZEIYRW5hYmxlIHJhbmdlIHRlc3QgbW9kdWxlUg'
    'dlbmFibGVkEnkKBnNlbmRlchgCIAEoDUJhyvMYXSoBczoPU2VuZGVyIEludGVydmFsQkdUaGlz'
    'IGRldmljZSB3aWxsIHNlbmQgb3V0IHJhbmdlIHRlc3QgbWVzc2FnZXMgb24gdGhlIHNlbGVjdG'
    'VkIGludGVydmFsLlIGc2VuZGVyEo0BCgRzYXZlGAMgASgIQnnK8xh1OgRTYXZlQm1TYXZlcyBh'
    'IENTViB3aXRoIHRoZSByYW5nZSB0ZXN0IG1lc3NhZ2UgZGV0YWlscywgY3VycmVudGx5IG9ubH'
    'kgYXZhaWxhYmxlIG9uIEVTUDMyIGRldmljZXMgd2l0aCBhIHdlYiBzZXJ2ZXIuUgRzYXZlEjQK'
    'D2NsZWFyX29uX3JlYm9vdBgEIAEoCEIMyvMYCFIGMi43LjExUg1jbGVhck9uUmVib290GoQOCg'
    '9UZWxlbWV0cnlDb25maWcSiAEKFmRldmljZV91cGRhdGVfaW50ZXJ2YWwYASABKA1CUsrzGE4q'
    'AXM6F0RldmljZSBNZXRyaWNzIEludGVydmFsQjBIb3cgb2Z0ZW4gZGV2aWNlIG1ldHJpY3MgYX'
    'JlIHNlbnQgb3ZlciB0aGUgbWVzaC5SFGRldmljZVVwZGF0ZUludGVydmFsEpwBChtlbnZpcm9u'
    'bWVudF91cGRhdGVfaW50ZXJ2YWwYAiABKA1CXMrzGFgqAXM6HEVudmlyb25tZW50IE1ldHJpY3'
    'MgSW50ZXJ2YWxCNUhvdyBvZnRlbiBlbnZpcm9ubWVudCBtZXRyaWNzIGFyZSBzZW50IG92ZXIg'
    'dGhlIG1lc2guUhllbnZpcm9ubWVudFVwZGF0ZUludGVydmFsEosBCh9lbnZpcm9ubWVudF9tZW'
    'FzdXJlbWVudF9lbmFibGVkGAMgASgIQkPK8xg/OhtFbnZpcm9ubWVudCBNZXRyaWNzIEVuYWJs'
    'ZWRCIENvbGxlY3QgZW52aXJvbm1lbnQgbWVhc3VyZW1lbnRzUh1lbnZpcm9ubWVudE1lYXN1cm'
    'VtZW50RW5hYmxlZBKFAQoaZW52aXJvbm1lbnRfc2NyZWVuX2VuYWJsZWQYBCABKAhCR8rzGEM6'
    'FVNob3cgb24gZGV2aWNlIHNjcmVlbkIqRGlzcGxheSBlbnZpcm9ubWVudCBtZWFzdXJlbWVudH'
    'Mgb24gZGV2aWNlUhhlbnZpcm9ubWVudFNjcmVlbkVuYWJsZWQSgQEKHmVudmlyb25tZW50X2Rp'
    'c3BsYXlfZmFocmVuaGVpdBgFIAEoCEI7yvMYNzoSRGlzcGxheSBGYWhyZW5oZWl0QiFEaXNwbG'
    'F5IGVudmlyb25tZW50IGluIEZhaHJlbmhlaXRSHGVudmlyb25tZW50RGlzcGxheUZhaHJlbmhl'
    'aXQSbgoTYWlyX3F1YWxpdHlfZW5hYmxlZBgGIAEoCEI+yvMYOjobQWlyIFF1YWxpdHkgTWV0cm'
    'ljcyBFbmFibGVkQhtDb2xsZWN0IGFpciBxdWFsaXR5IG1ldHJpY3NSEWFpclF1YWxpdHlFbmFi'
    'bGVkEo4BChRhaXJfcXVhbGl0eV9pbnRlcnZhbBgHIAEoDUJcyvMYWCoBczocQWlyIFF1YWxpdH'
    'kgTWV0cmljcyBJbnRlcnZhbEI1SG93IG9mdGVuIGFpciBxdWFsaXR5IG1ldHJpY3MgYXJlIHNl'
    'bnQgb3ZlciB0aGUgbWVzaC5SEmFpclF1YWxpdHlJbnRlcnZhbBJyChlwb3dlcl9tZWFzdXJlbW'
    'VudF9lbmFibGVkGAggASgIQjbK8xgyOhlQb3dlciBNZWFzdXJlbWVudCBFbmFibGVkQhVDb2xs'
    'ZWN0IHBvd2VyIG1ldHJpY3NSF3Bvd2VyTWVhc3VyZW1lbnRFbmFibGVkEoQBChVwb3dlcl91cG'
    'RhdGVfaW50ZXJ2YWwYCSABKA1CUMrzGEwqAXM6FlBvd2VyIE1ldHJpY3MgSW50ZXJ2YWxCL0hv'
    'dyBvZnRlbiBwb3dlciBtZXRyaWNzIGFyZSBzZW50IG92ZXIgdGhlIG1lc2guUhNwb3dlclVwZG'
    'F0ZUludGVydmFsEmUKFHBvd2VyX3NjcmVlbl9lbmFibGVkGAogASgIQjPK8xgvOgxQb3dlciBT'
    'Y3JlZW5CH0Rpc3BsYXkgcG93ZXIgbWV0cmljcyBvbiBkZXZpY2VSEnBvd2VyU2NyZWVuRW5hYm'
    'xlZBI8ChpoZWFsdGhfbWVhc3VyZW1lbnRfZW5hYmxlZBgLIAEoCFIYaGVhbHRoTWVhc3VyZW1l'
    'bnRFbmFibGVkEjQKFmhlYWx0aF91cGRhdGVfaW50ZXJ2YWwYDCABKA1SFGhlYWx0aFVwZGF0ZU'
    'ludGVydmFsEjIKFWhlYWx0aF9zY3JlZW5fZW5hYmxlZBgNIAEoCFITaGVhbHRoU2NyZWVuRW5h'
    'YmxlZBLWAQoYZGV2aWNlX3RlbGVtZXRyeV9lbmFibGVkGA4gASgIQpsByvMYlgE6GEJyb2FkY2'
    'FzdCBEZXZpY2UgTWV0cmljc0JyRW5hYmxlIGJyb2FkY2FzdGluZyBkZXZpY2UgbWV0cmljcyB0'
    'byB0aGUgbWVzaCBuZXR3b3JrLiBXaGVuIGRpc2FibGVkLCBtZXRyaWNzIGFyZSBvbmx5IHNlbn'
    'QgdG8gY29ubmVjdGVkIGNsaWVudHMuUgYyLjcuMTNSFmRldmljZVRlbGVtZXRyeUVuYWJsZWQS'
    'SQoaYWlyX3F1YWxpdHlfc2NyZWVuX2VuYWJsZWQYDyABKAhCDMrzGAhSBjIuNy4xOFIXYWlyUX'
    'VhbGl0eVNjcmVlbkVuYWJsZWQajAsKE0Nhbm5lZE1lc3NhZ2VDb25maWcSTgoPcm90YXJ5MV9l'
    'bmFibGVkGAEgASgIQiXK8xghOghSb3RhcnkgMUIVRW5hYmxlIHJvdGFyeSBlbmNvZGVyUg5yb3'
    'RhcnkxRW5hYmxlZBJcChFpbnB1dGJyb2tlcl9waW5fYRgCIAEoDUIwyvMYLDoFUGluIEFCI0dQ'
    'SU8gcGluIGZvciByb3RhcnkgZW5jb2RlciBBIHBvcnQuUg9pbnB1dGJyb2tlclBpbkESXAoRaW'
    '5wdXRicm9rZXJfcGluX2IYAyABKA1CMMrzGCw6BVBpbiBCQiNHUElPIHBpbiBmb3Igcm90YXJ5'
    'IGVuY29kZXIgQiBwb3J0LlIPaW5wdXRicm9rZXJQaW5CEmwKFWlucHV0YnJva2VyX3Bpbl9wcm'
    'VzcxgEIAEoDUI4yvMYNDoJUHJlc3MgUGluQidHUElPIHBpbiBmb3Igcm90YXJ5IGVuY29kZXIg'
    'UHJlc3MgcG9ydC5SE2lucHV0YnJva2VyUGluUHJlc3MSrwEKFGlucHV0YnJva2VyX2V2ZW50X2'
    'N3GAUgASgOMjsubWVzaHRhc3RpYy5Nb2R1bGVDb25maWcuQ2FubmVkTWVzc2FnZUNvbmZpZy5J'
    'bnB1dEV2ZW50Q2hhckJAyvMYPDoWQ2xvY2t3aXNlIFJvdGFyeSBFdmVudEIiSW5wdXQgZXZlbn'
    'QgZm9yIGNsb2Nrd2lzZSByb3RhdGlvblISaW5wdXRicm9rZXJFdmVudEN3EsEBChVpbnB1dGJy'
    'b2tlcl9ldmVudF9jY3cYBiABKA4yOy5tZXNodGFzdGljLk1vZHVsZUNvbmZpZy5DYW5uZWRNZX'
    'NzYWdlQ29uZmlnLklucHV0RXZlbnRDaGFyQlDK8xhMOh5Db3VudGVyIENsb2Nrd2lzZSBSb3Rh'
    'cnkgRXZlbnRCKklucHV0IGV2ZW50IGZvciBjb3VudGVyLWNsb2Nrd2lzZSByb3RhdGlvblITaW'
    '5wdXRicm9rZXJFdmVudENjdxKtAQoXaW5wdXRicm9rZXJfZXZlbnRfcHJlc3MYByABKA4yOy5t'
    'ZXNodGFzdGljLk1vZHVsZUNvbmZpZy5DYW5uZWRNZXNzYWdlQ29uZmlnLklucHV0RXZlbnRDaG'
    'FyQjjK8xg0OhNFbmNvZGVyIFByZXNzIEV2ZW50Qh1JbnB1dCBldmVudCBmb3IgZW5jb2RlciBw'
    'cmVzc1IVaW5wdXRicm9rZXJFdmVudFByZXNzElUKD3VwZG93bjFfZW5hYmxlZBgIIAEoCEIsyv'
    'MYKDoJVXAgRG93biAxQhtFbmFibGUgdXAvZG93bi9zZWxlY3QgaW5wdXRSDnVwZG93bjFFbmFi'
    'bGVkEicKB2VuYWJsZWQYCSABKAhCDRgByvMYB1oFMi43LjBSB2VuYWJsZWQSOwoSYWxsb3dfaW'
    '5wdXRfc291cmNlGAogASgJQg0YAcrzGAdaBTIuNy4wUhBhbGxvd0lucHV0U291cmNlEk8KCXNl'
    'bmRfYmVsbBgLIAEoCEIyyvMYLjoJU2VuZCBCZWxsQiFTZW5kIGJlbGwgY2hhcmFjdGVyIHdpdG'
    'ggbWVzc2FnZXNSCHNlbmRCZWxsIsYBCg5JbnB1dEV2ZW50Q2hhchIUCgROT05FEAAaCsrzGAY6'
    'BE5vbmUSEAoCVVAQERoIyvMYBDoCVXASFAoERE9XThASGgrK8xgGOgREb3duEhQKBExFRlQQEx'
    'oKyvMYBjoETGVmdBIWCgVSSUdIVBAUGgvK8xgHOgVSaWdodBIYCgZTRUxFQ1QQChoMyvMYCDoG'
    'U2VsZWN0EhQKBEJBQ0sQGxoKyvMYBjoEQmFjaxIYCgZDQU5DRUwQGBoMyvMYCDoGQ2FuY2VsGv'
    'gEChVBbWJpZW50TGlnaHRpbmdDb25maWcSSwoJbGVkX3N0YXRlGAEgASgIQi7K8xgqOglMRUQg'
    'U3RhdGVCHVRoZSBzdGF0ZSBvZiB0aGUgTEVEIChvbi9vZmYpUghsZWRTdGF0ZRJ9CgdjdXJyZW'
    '50GAIgASgNQmPK8xhfGQAAAAAAAAAAIQAAAAAAAD9AOgdDdXJyZW50QiFEcml2ZSBjdXJyZW50'
    'IGZvciB0aGUgTEVEIG91dHB1dC5KH2xlZHxicmlnaHRuZXNzfGFtYmllbnR8bGlnaHRpbmdSB2'
    'N1cnJlbnQSgAEKA3JlZBgDIAEoDUJuyvMYahkAAAAAAAAAACEAAAAAAOBvQDoDUmVkQipUaGUg'
    'cmVkIGxldmVsIG9mIHRoZSBhbWJpZW50IGxpZ2h0aW5nIExFRC5KJWNvbG9yfGNvbG91cnxyZ2'
    'J8bGVkfGFtYmllbnR8bGlnaHRpbmdSA3JlZBKIAQoFZ3JlZW4YBCABKA1CcsrzGG4ZAAAAAAAA'
    'AAAhAAAAAADgb0A6BUdyZWVuQixUaGUgZ3JlZW4gbGV2ZWwgb2YgdGhlIGFtYmllbnQgbGlnaH'
    'RpbmcgTEVELkolY29sb3J8Y29sb3VyfHJnYnxsZWR8YW1iaWVudHxsaWdodGluZ1IFZ3JlZW4S'
    'hAEKBGJsdWUYBSABKA1CcMrzGGwZAAAAAAAAAAAhAAAAAADgb0A6BEJsdWVCK1RoZSBibHVlIG'
    'xldmVsIG9mIHRoZSBhbWJpZW50IGxpZ2h0aW5nIExFRC5KJWNvbG9yfGNvbG91cnxyZ2J8bGVk'
    'fGFtYmllbnR8bGlnaHRpbmdSBGJsdWUaNgoTU3RhdHVzTWVzc2FnZUNvbmZpZxIfCgtub2RlX3'
    'N0YXR1cxgBIAEoCVIKbm9kZVN0YXR1cxrzCQoQTWVzaEJlYWNvbkNvbmZpZxIUCgVmbGFncxgB'
    'IAEoDVIFZmxhZ3MSSAoeYnJvYWRjYXN0X29mZmVyX2ZyZXF1ZW5jeV9zbG90GAIgASgNSABSG2'
    'Jyb2FkY2FzdE9mZmVyRnJlcXVlbmN5U2xvdIgBARJZChFicm9hZGNhc3RfbWVzc2FnZRgEIAEo'
    'CUIsyvMYKDoHTWVzc2FnZUIdTWVzc2FnZSBmb3IgYmVhY29uIGJyb2FkY2FzdHNSEGJyb2FkY2'
    'FzdE1lc3NhZ2USUwoXYnJvYWRjYXN0X29mZmVyX2NoYW5uZWwYBSABKAsyGy5tZXNodGFzdGlj'
    'LkNoYW5uZWxTZXR0aW5nc1IVYnJvYWRjYXN0T2ZmZXJDaGFubmVsEl4KFmJyb2FkY2FzdF9vZm'
    'Zlcl9yZWdpb24YBiABKA4yKC5tZXNodGFzdGljLkNvbmZpZy5Mb1JhQ29uZmlnLlJlZ2lvbkNv'
    'ZGVSFGJyb2FkY2FzdE9mZmVyUmVnaW9uEmQKFmJyb2FkY2FzdF9vZmZlcl9wcmVzZXQYByABKA'
    '4yKS5tZXNodGFzdGljLkNvbmZpZy5Mb1JhQ29uZmlnLk1vZGVtUHJlc2V0SAFSFGJyb2FkY2Fz'
    'dE9mZmVyUHJlc2V0iAEBEmsKF2Jyb2FkY2FzdF9pbnRlcnZhbF9zZWNzGAsgASgNQjPK8xgvKg'
    'FzOghJbnRlcnZhbEIgSG93IG9mdGVuIGEgYmVhY29uIGlzIGJyb2FkY2FzdC5SFWJyb2FkY2Fz'
    'dEludGVydmFsU2VjcxJmChFicm9hZGNhc3RfdGFyZ2V0cxgNIAMoCzI5Lm1lc2h0YXN0aWMuTW'
    '9kdWxlQ29uZmlnLk1lc2hCZWFjb25Db25maWcuQnJvYWRjYXN0VGFyZ2V0UhBicm9hZGNhc3RU'
    'YXJnZXRzGqECCg9Ccm9hZGNhc3RUYXJnZXQSRgoGcHJlc2V0GAEgASgOMikubWVzaHRhc3RpYy'
    '5Db25maWcuTG9SYUNvbmZpZy5Nb2RlbVByZXNldEgAUgZwcmVzZXSIAQESQAoGcmVnaW9uGAIg'
    'ASgOMigubWVzaHRhc3RpYy5Db25maWcuTG9SYUNvbmZpZy5SZWdpb25Db2RlUgZyZWdpb24SKA'
    'oNY2hhbm5lbF9pbmRleBgEIAEoDUgBUgxjaGFubmVsSW5kZXiIAQESKgoOZnJlcXVlbmN5X3Ns'
    'b3QYBSABKA1IAlINZnJlcXVlbmN5U2xvdIgBAUIJCgdfcHJlc2V0QhAKDl9jaGFubmVsX2luZG'
    'V4QhEKD19mcmVxdWVuY3lfc2xvdCJiCgVGbGFncxINCglGTEFHX05PTkUQABIXChNGTEFHX0xJ'
    'U1RFTl9FTkFCTEVEEAESGgoWRkxBR19CUk9BRENBU1RfRU5BQkxFRBACEhUKEUZMQUdfTEVHQU'
    'NZX1NQTElUEARCIQofX2Jyb2FkY2FzdF9vZmZlcl9mcmVxdWVuY3lfc2xvdEIZChdfYnJvYWRj'
    'YXN0X29mZmVyX3ByZXNldEoECAMQBEoECAgQCUoECAkQCkoECAoQC1IWYnJvYWRjYXN0X3Nlbm'
    'RfYXNfbm9kZVIUYnJvYWRjYXN0X29uX2NoYW5uZWxSE2Jyb2FkY2FzdF9vbl9yZWdpb25SE2Jy'
    'b2FkY2FzdF9vbl9wcmVzZXQalgEKCVRBS0NvbmZpZxJACgR0ZWFtGAEgASgOMhAubWVzaHRhc3'
    'RpYy5UZWFtQhrK8xgWOgRUZWFtQg5UQUsgdGVhbSBjb2xvclIEdGVhbRJHCgRyb2xlGAIgASgO'
    'MhYubWVzaHRhc3RpYy5NZW1iZXJSb2xlQhvK8xgXOgRSb2xlQg9UQUsgbWVtYmVyIHJvbGVSBH'
    'JvbGVCEQoPcGF5bG9hZF92YXJpYW50');

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
