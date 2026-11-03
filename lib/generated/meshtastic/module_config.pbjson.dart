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
    {'1': 'MODBUS', '2': 11},
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
    'NvbmZpZy5NZXNoQmVhY29uQ29uZmlnQgvK8xgHUgUyLjguMEgAUgptZXNoQmVhY29uGucICgpN'
    'UVRUQ29uZmlnEkEKB2VuYWJsZWQYASABKAhCJ8rzGCM6DE1RVFQgRW5hYmxlZEITRW5hYmxlIE'
    '1RVFQgZ2F0ZXdheVIHZW5hYmxlZBI8CgdhZGRyZXNzGAIgASgJQiLK8xgeOgdBZGRyZXNzQhNN'
    'UVRUIHNlcnZlciBhZGRyZXNzUgdhZGRyZXNzEjkKCHVzZXJuYW1lGAMgASgJQh3K8xgZOghVc2'
    'VybmFtZUINTVFUVCB1c2VybmFtZVIIdXNlcm5hbWUSOQoIcGFzc3dvcmQYBCABKAlCHcrzGBk6'
    'CFBhc3N3b3JkQg1NUVRUIHBhc3N3b3JkUghwYXNzd29yZBJnChJlbmNyeXB0aW9uX2VuYWJsZW'
    'QYBSABKAhCOMrzGDQ6EkVuY3J5cHRpb24gRW5hYmxlZEIeU2VuZCBlbmNyeXB0ZWQgcGFja2V0'
    'cyB0byBNUVRUUhFlbmNyeXB0aW9uRW5hYmxlZBIwCgxqc29uX2VuYWJsZWQYBiABKAhCDRgByv'
    'MYB1oFMi44LjBSC2pzb25FbmFibGVkElgKC3Rsc19lbmFibGVkGAcgASgIQjfK8xgzOgtUTFMg'
    'RW5hYmxlZEIkQ29ubmVjdCB0byB0aGUgTVFUVCBzZXJ2ZXIgb3ZlciBUTFMuUgp0bHNFbmFibG'
    'VkEjUKBHJvb3QYCCABKAlCIcrzGB06ClJvb3QgVG9waWNCD01RVFQgcm9vdCB0b3BpY1IEcm9v'
    'dBKRAQoXcHJveHlfdG9fY2xpZW50X2VuYWJsZWQYCSABKAhCWsrzGFY6EU1RVFQgQ2xpZW50IF'
    'Byb3h5QkFVdGlsaXplcyB0aGUgbmV0d29yayBjb25uZWN0aW9uIG9uIHlvdXIgcGhvbmUgdG8g'
    'Y29ubmVjdCB0byBNUVRULlIUcHJveHlUb0NsaWVudEVuYWJsZWQSxQIKFW1hcF9yZXBvcnRpbm'
    'dfZW5hYmxlZBgKIAEoCEKQAsrzGIsCOg1NYXAgUmVwb3J0aW5nQvkBWW91ciBub2RlIHdpbGwg'
    'cGVyaW9kaWNhbGx5IHNlbmQgYW4gdW5lbmNyeXB0ZWQgbWFwIHJlcG9ydCBwYWNrZXQgdG8gdG'
    'hlIGNvbmZpZ3VyZWQgTVFUVCBzZXJ2ZXIsIHRoaXMgaW5jbHVkZXMgaWQsIHNob3J0IGFuZCBs'
    'b25nIG5hbWUsIGFwcHJveGltYXRlIGxvY2F0aW9uLCBoYXJkd2FyZSBtb2RlbCwgcm9sZSwgZm'
    'lybXdhcmUgdmVyc2lvbiwgTG9SYSByZWdpb24sIG1vZGVtIHByZXNldCBhbmQgcHJpbWFyeSBj'
    'aGFubmVsIG5hbWUuUhNtYXBSZXBvcnRpbmdFbmFibGVkEloKE21hcF9yZXBvcnRfc2V0dGluZ3'
    'MYCyABKAsyKi5tZXNodGFzdGljLk1vZHVsZUNvbmZpZy5NYXBSZXBvcnRTZXR0aW5nc1IRbWFw'
    'UmVwb3J0U2V0dGluZ3MaqQMKEU1hcFJlcG9ydFNldHRpbmdzEpABChVwdWJsaXNoX2ludGVydm'
    'FsX3NlY3MYASABKA1CXMrzGFgZAAAAAAAgrEAqAXM6FE1hcCBQdWJsaXNoIEludGVydmFsQjRI'
    'b3cgb2Z0ZW4gYSBtYXAgcmVwb3J0IGlzIHB1Ymxpc2hlZC4gTWluaW11bSAxIGhvdXIuUhNwdW'
    'JsaXNoSW50ZXJ2YWxTZWNzEi0KEnBvc2l0aW9uX3ByZWNpc2lvbhgCIAEoDVIRcG9zaXRpb25Q'
    'cmVjaXNpb24S0QEKFnNob3VsZF9yZXBvcnRfbG9jYXRpb24YAyABKAhCmgHK8xiVAToMU2hhcm'
    'Ugb24gTWFwQn5Db25zZW50IHRvIHB1Ymxpc2ggdGhpcyBub2RlJ3MgZGV0YWlscyBhbmQgYXBw'
    'cm94aW1hdGUgbG9jYXRpb24gdW5lbmNyeXB0ZWQgdG8gdGhlIE1RVFQgbWFwLiBObyBtYXAgcm'
    'Vwb3J0IGlzIHNlbnQgd2l0aG91dCBpdC5SBTIuNi44UhRzaG91bGRSZXBvcnRMb2NhdGlvbhqz'
    'AQoUUmVtb3RlSGFyZHdhcmVDb25maWcSGAoHZW5hYmxlZBgBIAEoCFIHZW5hYmxlZBI7ChphbG'
    'xvd191bmRlZmluZWRfcGluX2FjY2VzcxgCIAEoCFIXYWxsb3dVbmRlZmluZWRQaW5BY2Nlc3MS'
    'RAoOYXZhaWxhYmxlX3BpbnMYAyADKAsyHS5tZXNodGFzdGljLlJlbW90ZUhhcmR3YXJlUGluUg'
    '1hdmFpbGFibGVQaW5zGrAEChJOZWlnaGJvckluZm9Db25maWcSuwEKB2VuYWJsZWQYASABKAhC'
    'oAHK8xibAToVTmVpZ2hib3IgSW5mbyBFbmFibGVkQoEBRW5hYmxlIG5laWdoYm9yIGluZm8gYn'
    'JvYWRjYXN0aW5nLiBQZXJpb2RpY2FsbHkgc2VuZHMgaW5mb3JtYXRpb24gYWJvdXQgZGlyZWN0'
    'bHktaGVhcmQgbmVpZ2hib3JzIHRvIGhlbHAgdmlzdWFsaXplIG1lc2ggdG9wb2xvZ3kuUgdlbm'
    'FibGVkEoIBCg91cGRhdGVfaW50ZXJ2YWwYAiABKA1CWcrzGFUZAAAAAAAgzEAqAXM6D1VwZGF0'
    'ZSBJbnRlcnZhbEI2SG93IG9mdGVuIHRvIGJyb2FkY2FzdCBuZWlnaGJvciBpbmZvLiBNaW5pbX'
    'VtIDQgaG91cnMuUg51cGRhdGVJbnRlcnZhbBLWAQoSdHJhbnNtaXRfb3Zlcl9sb3JhGAMgASgI'
    'QqcByvMYogE6ElRyYW5zbWl0IG92ZXIgTG9SYUKLAVdoZXRoZXIgdG8gdHJhbnNtaXQgbmVpZ2'
    'hib3IgaW5mbyBvdmVyIExvUmEgaW4gYWRkaXRpb24gdG8gTVFUVCBhbmQgdGhlIGNvbm5lY3Rl'
    'ZCBhcHAuIE5vdCBhdmFpbGFibGUgb24gY2hhbm5lbHMgd2l0aCBkZWZhdWx0IGtleSBhbmQgbm'
    'FtZS5SEHRyYW5zbWl0T3ZlckxvcmEa3AsKFURldGVjdGlvblNlbnNvckNvbmZpZxKMAgoHZW5h'
    'YmxlZBgBIAEoCELxAcrzGOwBOhhEZXRlY3Rpb24gU2Vuc29yIEVuYWJsZWRCzwFFbmFibGVzIH'
    'RoZSBkZXRlY3Rpb24gc2Vuc29yIG1vZHVsZSwgaXQgbmVlZHMgdG8gYmUgZW5hYmxlZCBvbiBi'
    'b3RoIHRoZSBub2RlIHdpdGggdGhlIHNlbnNvciwgYW5kIGFueSBub2RlcyB0aGF0IHlvdSB3YW'
    '50IHRvIHJlY2VpdmUgZGV0ZWN0aW9uIHNlbnNvciB0ZXh0IG1lc3NhZ2VzIG9yIHZpZXcgdGhl'
    'IGRldGVjdGlvbiBzZW5zb3IgbG9nIGFuZCBjaGFydC5SB2VuYWJsZWQSlAEKFm1pbmltdW1fYn'
    'JvYWRjYXN0X3NlY3MYAiABKA1CXsrzGFoqAXM6KU1pbmltdW0gdGltZSBiZXR3ZWVuIGRldGVj'
    'dGlvbiBicm9hZGNhc3RzQipNaW5pbXVtIHRpbWUgYmV0d2VlbiBkZXRlY3Rpb24gYnJvYWRjYX'
    'N0cy5SFG1pbmltdW1Ccm9hZGNhc3RTZWNzEtEBChRzdGF0ZV9icm9hZGNhc3Rfc2VjcxgDIAEo'
    'DUKeAcrzGJkBKgFzOhhTdGF0ZSBCcm9hZGNhc3QgSW50ZXJ2YWxCekhvdyBvZnRlbiB0byBzZW'
    '5kIHRoZSBkZXRlY3Rpb24gc2Vuc29yIHN0YXRlIHRvIHRoZSBtZXNoLCB3aGV0aGVyIG9yIG5v'
    'dCBhbnl0aGluZyB3YXMgZGV0ZWN0ZWQuIDAgc2VuZHMgb25seSBvbiBkZXRlY3Rpb24uUhJzdG'
    'F0ZUJyb2FkY2FzdFNlY3MShgEKCXNlbmRfYmVsbBgEIAEoCEJpyvMYZToJU2VuZCBCZWxsQlhT'
    'ZW5kIEFTQ0lJIGJlbGwgd2l0aCBhbGVydCBtZXNzYWdlLiBVc2VmdWwgZm9yIHRyaWdnZXJpbm'
    'cgZXh0ZXJuYWwgbm90aWZpY2F0aW9uIG9uIGJlbGwuUghzZW5kQmVsbBI9CgRuYW1lGAUgASgJ'
    'QinK8xglOgROYW1lQh1TZW5zb3IgbmFtZSBmb3IgbWVzaCBtZXNzYWdlc1IEbmFtZRJ2Cgttb2'
    '5pdG9yX3BpbhgGIAEoDUJVyvMYUToTR1BJTyBQaW4gdG8gbW9uaXRvckI6R1BJTyBwaW4gd2F0'
    'Y2hlZCBmb3Igc3RhdGUgY2hhbmdlcy4gMCBkaXNhYmxlcyB0aGUgbW9kdWxlLlIKbW9uaXRvcl'
    'BpbhKbAQoWZGV0ZWN0aW9uX3RyaWdnZXJfdHlwZRgHIAEoDjI6Lm1lc2h0YXN0aWMuTW9kdWxl'
    'Q29uZmlnLkRldGVjdGlvblNlbnNvckNvbmZpZy5UcmlnZ2VyVHlwZUIpyvMYJToMVHJpZ2dlci'
    'BUeXBlQhVUeXBlIG9mIHRyaWdnZXIgZXZlbnRSFGRldGVjdGlvblRyaWdnZXJUeXBlEnMKCnVz'
    'ZV9wdWxsdXAYCCABKAhCVMrzGFA6FFVzZSBJbnRlcm5hbCBQdWxsLXVwQjhFbmFibGUgdGhlIG'
    'ludGVybmFsIHB1bGwtdXAgcmVzaXN0b3Igb24gdGhlIG1vbml0b3IgcGluLlIJdXNlUHVsbHVw'
    'IvUBCgtUcmlnZ2VyVHlwZRIYCglMT0dJQ19MT1cQABoJyvMYBToDTG93EhoKCkxPR0lDX0hJR0'
    'gQARoKyvMYBjoESGlnaBIkCgxGQUxMSU5HX0VER0UQAhoSyvMYDjoMRmFsbGluZyBFZGdlEiIK'
    'C1JJU0lOR19FREdFEAMaEcrzGA06C1Jpc2luZyBFZGdlEjEKFkVJVEhFUl9FREdFX0FDVElWRV'
    '9MT1cQBBoVyvMYEToPRWl0aGVyIEVkZ2UgTG93EjMKF0VJVEhFUl9FREdFX0FDVElWRV9ISUdI'
    'EAUaFsrzGBI6EEVpdGhlciBFZGdlIEhpZ2ga7AcKC0F1ZGlvQ29uZmlnEokBCg5jb2RlYzJfZW'
    '5hYmxlZBgBIAEoCEJiyvMYXjoOQ29kZWMyIEVuYWJsZWRCTEVuYWJsZSBDb2RlYzIgYXVkaW8g'
    'ZW5jb2RpbmcvZGVjb2RpbmcgZm9yIHZvaWNlIGNvbW11bmljYXRpb24gb3ZlciB0aGUgbWVzaC'
    '5SDWNvZGVjMkVuYWJsZWQSVQoHcHR0X3BpbhgCIAEoDUI8yvMYODoHUFRUIFBpbkItUHVzaC10'
    'by10YWxrIEdQSU8gcGluIG51bWJlci4gMCB1c2VzIEdQSU8gMzkuUgZwdHRQaW4S0wEKB2JpdH'
    'JhdGUYAyABKA4yLy5tZXNodGFzdGljLk1vZHVsZUNvbmZpZy5BdWRpb0NvbmZpZy5BdWRpb19C'
    'YXVkQocByvMYggE6B0JpdHJhdGVCd1RoZSBDb2RlYzIgYml0cmF0ZSB0byB1c2UuIFRoZSBzYW'
    '1wbGUgcmF0ZSBpcyBhbHdheXMgOCBrSHouIExvd2VyIGJpdHJhdGVzIHVzZSBsZXNzIGJhbmR3'
    'aWR0aCBidXQgcmVkdWNlIGF1ZGlvIHF1YWxpdHkuUgdiaXRyYXRlEjAKBmkyc193cxgEIAEoDU'
    'IZyvMYFToTSTJTIFdvcmQgU2VsZWN0IFBpblIFaTJzV3MSLAoGaTJzX3NkGAUgASgNQhXK8xgR'
    'Og9JMlMgRGF0YSBJbiBQaW5SBWkyc1NkEi8KB2kyc19kaW4YBiABKA1CFsrzGBI6EEkyUyBEYX'
    'RhIE91dCBQaW5SBmkyc0RpbhIsCgdpMnNfc2NrGAcgASgNQhPK8xgPOg1JMlMgQ2xvY2sgUGlu'
    'UgZpMnNTY2si5AIKCkF1ZGlvX0JhdWQSIQoOQ09ERUMyX0RFRkFVTFQQABoNyvMYCToHRGVmYX'
    'VsdBIfCgtDT0RFQzJfMzIwMBABGg7K8xgKOggzMjAwIGJwcxIfCgtDT0RFQzJfMjQwMBACGg7K'
    '8xgKOggyNDAwIGJwcxIfCgtDT0RFQzJfMTYwMBADGg7K8xgKOggxNjAwIGJwcxIfCgtDT0RFQz'
    'JfMTQwMBAEGg7K8xgKOggxNDAwIGJwcxIfCgtDT0RFQzJfMTMwMBAFGg7K8xgKOggxMzAwIGJw'
    'cxIfCgtDT0RFQzJfMTIwMBAGGg7K8xgKOggxMjAwIGJwcxISCgpDT0RFQzJfNzAwEAcaAggBEh'
    'MKC0NPREVDMl83MDBCEAgaAggBEiUKC0NPREVDMl83MDBDEAkaFMrzGBA6DjcwMCBicHMgKDcw'
    'MEMpEh0KCkNPREVDMl80NTAQChoNyvMYCToHNDUwIGJwcxq+BAoQUGF4Y291bnRlckNvbmZpZx'
    'LIAQoHZW5hYmxlZBgBIAEoCEKtAcrzGKgBOhNQQVggQ291bnRlciBFbmFibGVkQpABV2hlbiBl'
    'bmFibGVkLCB0aGUgUEFYIENvdW50ZXIgbW9kdWxlIGNvdW50cyBuZWFyYnkgV2lGaSBhbmQgQm'
    'x1ZXRvb3RoIGRldmljZXMuIEJvdGggV2lGaSBhbmQgQmx1ZXRvb3RoIG11c3QgYmUgZGlzYWJs'
    'ZWQgZm9yIFBBWCBjb3VudGVyIHRvIHdvcmsuUgdlbmFibGVkEogBChpwYXhjb3VudGVyX3VwZG'
    'F0ZV9pbnRlcnZhbBgCIAEoDUJKyvMYRioBczoPVXBkYXRlIEludGVydmFsQjBIb3cgb2Z0ZW4g'
    'dG8gc2VuZCB0aGUgZGV2aWNlIGNvdW50cyB0byB0aGUgbWVzaC5SGHBheGNvdW50ZXJVcGRhdG'
    'VJbnRlcnZhbBJrCg53aWZpX3RocmVzaG9sZBgDIAEoBUJEyvMYQCoDZEJtOg5XaUZpIFRocmVz'
    'aG9sZEIpUlNTSSB0aHJlc2hvbGQgZm9yIGNvdW50aW5nIFdpRmkgZGV2aWNlcy5SDXdpZmlUaH'
    'Jlc2hvbGQSZwoNYmxlX3RocmVzaG9sZBgEIAEoBUJCyvMYPioDZEJtOg1CTEUgVGhyZXNob2xk'
    'QihSU1NJIHRocmVzaG9sZCBmb3IgY291bnRpbmcgQkxFIGRldmljZXMuUgxibGVUaHJlc2hvbG'
    'Qa9AgKF1RyYWZmaWNNYW5hZ2VtZW50Q29uZmlnEqQBChpwb3NpdGlvbl9taW5faW50ZXJ2YWxf'
    'c2VjcxgEIAEoDUJnyvMYYyoBczoZTWluaW11bSBQb3NpdGlvbiBJbnRlcnZhbEJDUG9zaXRpb2'
    '5zIGZyb20gdGhlIHNhbWUgbm9kZSBhcnJpdmluZyBzb29uZXIgdGhhbiB0aGlzIGFyZSBkcm9w'
    'cGVkLlIXcG9zaXRpb25NaW5JbnRlcnZhbFNlY3MSgQIKIW5vZGVpbmZvX2RpcmVjdF9yZXNwb2'
    '5zZV9tYXhfaG9wcxgGIAEoDUK2AcrzGLEBIQAAAAAAAAhAOhhEaXJlY3QgTm9kZUluZm8gTWF4'
    'IEhvcHNCiwFBbnN3ZXIgTm9kZUluZm8gcmVxdWVzdHMgZnJvbSBjYWNoZSBmb3IgcmVxdWVzdG'
    '9ycyB3aXRoaW4gdGhpcyBtYW55IGhvcHMuIENhcHBlZCBhdCAzIG9uIHJvdXRlcnM7IG90aGVy'
    'IHJvbGVzIGFuc3dlciBkaXJlY3QgbmVpZ2hib3JzIG9ubHkuUh1ub2RlaW5mb0RpcmVjdFJlc3'
    'BvbnNlTWF4SG9wcxJ6ChZyYXRlX2xpbWl0X3dpbmRvd19zZWNzGAggASgNQkXK8xhBKgFzOhFS'
    'YXRlIExpbWl0IFdpbmRvd0IpVGhlIHRpbWUgd2luZG93IHBhY2tldHMgYXJlIGNvdW50ZWQgb3'
    'Zlci5SE3JhdGVMaW1pdFdpbmRvd1NlY3MSigEKFnJhdGVfbGltaXRfbWF4X3BhY2tldHMYCSAB'
    'KA1CVcrzGFEhAAAAAAAATkA6FlJhdGUgTGltaXQgTWF4IFBhY2tldHNCLlRoZSBtb3N0IHBhY2'
    'tldHMgb25lIG5vZGUgbWF5IHNlbmQgcGVyIHdpbmRvdy5SE3JhdGVMaW1pdE1heFBhY2tldHMS'
    'rQEKGHVua25vd25fcGFja2V0X3RocmVzaG9sZBgLIAEoDUJzyvMYbyEAAAAAAABOQDoYVW5rbm'
    '93biBQYWNrZXQgVGhyZXNob2xkQkpVbmRlY3J5cHRhYmxlIHBhY2tldHMgb25lIG5vZGUgbWF5'
    'IHNlbmQgaW4gNSBtaW51dGVzIGJlZm9yZSBpdCBpcyBkcm9wcGVkLlIWdW5rbm93blBhY2tldF'
    'RocmVzaG9sZEoECAEQAkoECAIQA0oECAMQBEoECAUQBkoECAcQCEoECAoQC0oECAwQDUoECA0Q'
    'DkoECA4QD1IHZW5hYmxlZFIWcG9zaXRpb25fZGVkdXBfZW5hYmxlZFIXcG9zaXRpb25fcHJlY2'
    'lzaW9uX2JpdHNSGG5vZGVpbmZvX2RpcmVjdF9yZXNwb25zZVIScmF0ZV9saW1pdF9lbmFibGVk'
    'UhRkcm9wX3Vua25vd25fZW5hYmxlZFIVZXhoYXVzdF9ob3BfdGVsZW1ldHJ5UhRleGhhdXN0X2'
    'hvcF9wb3NpdGlvblIUcm91dGVyX3ByZXNlcnZlX2hvcHMalAwKDFNlcmlhbENvbmZpZxJECgdl'
    'bmFibGVkGAEgASgIQirK8xgmOg5TZXJpYWwgRW5hYmxlZEIURW5hYmxlIHNlcmlhbCBtb2R1bG'
    'VSB2VuYWJsZWQSZgoEZWNobxgCIAEoCEJSyvMYTjoERWNob0JGSWYgc2V0LCBhbnkgcGFja2V0'
    'cyB5b3Ugc2VuZCB3aWxsIGJlIGVjaG9lZCBiYWNrIG92ZXIgdGhlIHNlcmlhbCBwb3J0LlIEZW'
    'NobxJCCgNyeGQYAyABKA1CMMrzGCw6G1JlY2VpdmUgZGF0YSAocnhkKSBHUElPIHBpbkINUlgg'
    'cGluIG51bWJlclIDcnhkEkMKA3R4ZBgEIAEoDUIxyvMYLTocVHJhbnNtaXQgZGF0YSAodHhkKS'
    'BHUElPIHBpbkINVFggcGluIG51bWJlclIDdHhkEmMKBGJhdWQYBSABKA4yMS5tZXNodGFzdGlj'
    'Lk1vZHVsZUNvbmZpZy5TZXJpYWxDb25maWcuU2VyaWFsX0JhdWRCHMrzGBg6BEJhdWRCEFNlcm'
    'lhbCBiYXVkIHJhdGVSBGJhdWQShwEKB3RpbWVvdXQYBiABKA1CbcrzGGkqAm1zOgdUaW1lb3V0'
    'QlpIb3cgbG9uZyB0byB3YWl0IGJlZm9yZSB0cmVhdGluZyByZWNlaXZlZCBzZXJpYWwgZGF0YS'
    'BhcyBhIGNvbXBsZXRlIHBhY2tldC4gMCB1c2VzIDI1MCBtcy5SB3RpbWVvdXQSbwoEbW9kZRgH'
    'IAEoDjIxLm1lc2h0YXN0aWMuTW9kdWxlQ29uZmlnLlNlcmlhbENvbmZpZy5TZXJpYWxfTW9kZU'
    'IoyvMYJDoETW9kZUIcU2VyaWFsIG1vZHVsZSBvcGVyYXRpb24gbW9kZVIEbW9kZRI/ChxvdmVy'
    'cmlkZV9jb25zb2xlX3NlcmlhbF9wb3J0GAggASgIUhlvdmVycmlkZUNvbnNvbGVTZXJpYWxQb3'
    'J0IqIECgtTZXJpYWxfQmF1ZBIfCgxCQVVEX0RFRkFVTFQQABoNyvMYCToHRGVmYXVsdBIcCghC'
    'QVVEXzExMBABGg7K8xgKOggxMTAgQmF1ZBIcCghCQVVEXzMwMBACGg7K8xgKOggzMDAgQmF1ZB'
    'IcCghCQVVEXzYwMBADGg7K8xgKOgg2MDAgQmF1ZBIeCglCQVVEXzEyMDAQBBoPyvMYCzoJMTIw'
    'MCBCYXVkEh4KCUJBVURfMjQwMBAFGg/K8xgLOgkyNDAwIEJhdWQSHgoJQkFVRF80ODAwEAYaD8'
    'rzGAs6CTQ4MDAgQmF1ZBIeCglCQVVEXzk2MDAQBxoPyvMYCzoJOTYwMCBCYXVkEiAKCkJBVURf'
    'MTkyMDAQCBoQyvMYDDoKMTkyMDAgQmF1ZBIgCgpCQVVEXzM4NDAwEAkaEMrzGAw6CjM4NDAwIE'
    'JhdWQSIAoKQkFVRF81NzYwMBAKGhDK8xgMOgo1NzYwMCBCYXVkEiIKC0JBVURfMTE1MjAwEAsa'
    'EcrzGA06CzExNTIwMCBCYXVkEiIKC0JBVURfMjMwNDAwEAwaEcrzGA06CzIzMDQwMCBCYXVkEi'
    'IKC0JBVURfNDYwODAwEA0aEcrzGA06CzQ2MDgwMCBCYXVkEiIKC0JBVURfNTc2MDAwEA4aEcrz'
    'GA06CzU3NjAwMCBCYXVkEiIKC0JBVURfOTIxNjAwEA8aEcrzGA06CzkyMTYwMCBCYXVkIoYCCg'
    'tTZXJpYWxfTW9kZRIaCgdERUZBVUxUEAAaDcrzGAk6B0RlZmF1bHQSGAoGU0lNUExFEAEaDMrz'
    'GAg6BlNpbXBsZRIaCgVQUk9UTxACGg/K8xgLOglQcm90b2J1ZnMSHwoHVEVYVE1TRxADGhLK8x'
    'gOOgxUZXh0IE1lc3NhZ2USHgoETk1FQRAEGhTK8xgQOg5OTUVBIFBvc2l0aW9ucxIaCgdDQUxU'
    'T1BPEAUaDcrzGAk6B0NhbFRvcG8SCAoEV1M4NRAGEg0KCVZFX0RJUkVDVBAHEg0KCU1TX0NPTk'
    'ZJRxAIEgcKA0xPRxAJEgsKB0xPR1RFWFQQChIKCgZNT0RCVVMQCxriDgoaRXh0ZXJuYWxOb3Rp'
    'ZmljYXRpb25Db25maWcSXAoHZW5hYmxlZBgBIAEoCEJCyvMYPjodRXh0ZXJuYWwgTm90aWZpY2'
    'F0aW9uIEVuYWJsZWRCHUVuYWJsZSBleHRlcm5hbCBub3RpZmljYXRpb25zUgdlbmFibGVkEmoK'
    'CW91dHB1dF9tcxgCIAEoDUJNyvMYSSoCbXM6FEdQSU8gT3V0cHV0IER1cmF0aW9uQi1JbiBHUE'
    'lPIG1vZGUsIGhvdyBsb25nIHRvIGtlZXAgdGhlIG91dHB1dCBvbi5SCG91dHB1dE1zEnsKBm91'
    'dHB1dBgDIAEoDUJjyvMYXzoPT3V0cHV0IHBpbiBHUElPQkxHUElPIHBpbiBkcml2ZW4gb24gbm'
    '90aWZpY2F0aW9uLiBEZWZhdWx0cyB0byB0aGUgYm9hcmQncyBFWFRfTk9USUZZX09VVCBwaW4u'
    'UgZvdXRwdXQSWgoMb3V0cHV0X3ZpYnJhGAggASgNQjfK8xgzOhVPdXRwdXQgcGluIHZpYnJhIE'
    'dQSU9CGlZpYnJhdGlvbiBtb3RvciBvdXRwdXQgcGluUgtvdXRwdXRWaWJyYRJUCg1vdXRwdXRf'
    'YnV6emVyGAkgASgNQi/K8xgrOhZPdXRwdXQgcGluIGJ1enplciBHUElPQhFCdXp6ZXIgb3V0cH'
    'V0IHBpblIMb3V0cHV0QnV6emVyEnkKBmFjdGl2ZRgEIAEoCEJhyvMYXToGQWN0aXZlQlNJZiBl'
    'bmFibGVkLCB0aGUgJ291dHB1dCcgUGluIHdpbGwgYmUgcHVsbGVkIGFjdGl2ZSBoaWdoLCBkaX'
    'NhYmxlZCBtZWFucyBhY3RpdmUgbG93LlIGYWN0aXZlEmQKDWFsZXJ0X21lc3NhZ2UYBSABKAhC'
    'P8rzGDs6HkFsZXJ0IHdoZW4gcmVjZWl2aW5nIGEgbWVzc2FnZUIZQWxlcnQgb24gaW5jb21pbm'
    'cgbWVzc2FnZVIMYWxlcnRNZXNzYWdlEngKE2FsZXJ0X21lc3NhZ2VfdmlicmEYCiABKAhCSMrz'
    'GEQ6EVZpYnJhIE1vdG9yIEFsZXJ0Qi9BbGVydCBHUElPIHZpYnJhIG1vdG9yIHdoZW4gcmVjZW'
    'l2aW5nIGEgbWVzc2FnZVIRYWxlcnRNZXNzYWdlVmlicmESfAoUYWxlcnRfbWVzc2FnZV9idXp6'
    'ZXIYCyABKAhCSsrzGEY6KkFsZXJ0IEdQSU8gYnV6emVyIHdoZW4gcmVjZWl2aW5nIGEgbWVzc2'
    'FnZUIYQnV6eiBvbiBpbmNvbWluZyBtZXNzYWdlUhJhbGVydE1lc3NhZ2VCdXp6ZXISWQoKYWxl'
    'cnRfYmVsbBgGIAEoCEI6yvMYNjobQWxlcnQgd2hlbiByZWNlaXZpbmcgYSBiZWxsQhdBbGVydC'
    'BvbiBiZWxsIGNoYXJhY3RlclIJYWxlcnRCZWxsEncKEGFsZXJ0X2JlbGxfdmlicmEYDCABKAhC'
    'TcrzGEk6LEFsZXJ0IEdQSU8gdmlicmEgbW90b3Igd2hlbiByZWNlaXZpbmcgYSBiZWxsQhlWaW'
    'JyYXRlIG9uIGJlbGwgY2hhcmFjdGVyUg5hbGVydEJlbGxWaWJyYRJxChFhbGVydF9iZWxsX2J1'
    'enplchgNIAEoCEJFyvMYQTonQWxlcnQgR1BJTyBidXp6ZXIgd2hlbiByZWNlaXZpbmcgYSBiZW'
    'xsQhZCdXp6IG9uIGJlbGwgY2hhcmFjdGVyUg9hbGVydEJlbGxCdXp6ZXIS9gEKB3VzZV9wd20Y'
    'ByABKAhC3AHK8xjXAToOVXNlIFBXTSBCdXp6ZXJCxAFVc2UgYSBQV00gb3V0cHV0IChsaWtlIH'
    'RoZSBSQUsgQnV6emVyKSBmb3IgdHVuZXMgaW5zdGVhZCBvZiBhbiBvbi9vZmYgb3V0cHV0LiBU'
    'aGlzIHdpbGwgaWdub3JlIHRoZSBvdXRwdXQsIG91dHB1dCBkdXJhdGlvbiBhbmQgYWN0aXZlIH'
    'NldHRpbmdzIGFuZCB1c2UgdGhlIGRldmljZSBjb25maWcgYnV6emVyIEdQSU8gb3B0aW9uIGlu'
    'c3RlYWQuUgZ1c2VQd20SVwoLbmFnX3RpbWVvdXQYDiABKA1CNsrzGDIqAXM6C05hZyBUaW1lb3'
    'V0QiBIb3cgbG9uZyB0aGUgbm90aWZpY2F0aW9uIGxhc3RzLlIKbmFnVGltZW91dBLYAQoRdXNl'
    'X2kyc19hc19idXp6ZXIYDyABKAhCrAHK8xinAToRVXNlIEkyUyBBcyBCdXp6ZXJCkQFFbmFibG'
    'VzIGRldmljZXMgd2l0aCBuYXRpdmUgSTJTIGF1ZGlvIG91dHB1dCB0byB1c2UgdGhlIFJUVFRM'
    'IG92ZXIgc3BlYWtlciBsaWtlIGEgYnV6emVyLiBULVdhdGNoIFMzIGFuZCBULURlY2sgZm9yIG'
    'V4YW1wbGUgaGF2ZSB0aGlzIGNhcGFiaWxpdHkuUg51c2VJMnNBc0J1enplchqGBgoSU3RvcmVG'
    'b3J3YXJkQ29uZmlnEmAKB2VuYWJsZWQYASABKAhCRsrzGEI6GVN0b3JlIGFuZCBGb3J3YXJkIE'
    'VuYWJsZWRCJUVuYWJsZXMgdGhlIHN0b3JlIGFuZCBmb3J3YXJkIG1vZHVsZS5SB2VuYWJsZWQS'
    'aAoJaGVhcnRiZWF0GAIgASgIQkrK8xhGOg5TZW5kIEhlYXJ0YmVhdEI0U2VuZCBhIGhlYXJ0Ym'
    'VhdCB0byBhZHZlcnRpc2UgdGhlIHNlcnZlcidzIHByZXNlbmNlLlIJaGVhcnRiZWF0EnwKB3Jl'
    'Y29yZHMYAyABKA1CYsrzGF46EU51bWJlciBvZiByZWNvcmRzQklNYXhpbXVtIG51bWJlciBvZi'
    'BtZXNzYWdlcyB0byBzdG9yZS4gMCB1c2VzIHRocmVlIHF1YXJ0ZXJzIG9mIGZyZWUgUFNSQU0u'
    'UgdyZWNvcmRzEooBChJoaXN0b3J5X3JldHVybl9tYXgYBCABKA1CXMrzGFg6Ekhpc3RvcnkgUm'
    'V0dXJuIE1heEJCTWF4aW11bSBudW1iZXIgb2Ygc3RvcmVkIG1lc3NhZ2VzIHJldHVybmVkIHBl'
    'ciByZXF1ZXN0LiAwIHVzZXMgMjUuUhBoaXN0b3J5UmV0dXJuTWF4EpQBChVoaXN0b3J5X3JldH'
    'Vybl93aW5kb3cYBSABKA1CYMrzGFw6FUhpc3RvcnkgUmV0dXJuIFdpbmRvd0JDSG93IGZhciBi'
    'YWNrLCBpbiBtaW51dGVzLCBzdG9yZWQgbWVzc2FnZXMgYXJlIHJldHVybmVkLiAwIHVzZXMgMj'
    'QwLlITaGlzdG9yeVJldHVybldpbmRvdxKBAQoJaXNfc2VydmVyGAYgASgIQmTK8xhgOgZTZXJ2'
    'ZXJCVkVuYWJsZSB0aGlzIGRldmljZSBhcyBhIFN0b3JlIGFuZCBGb3J3YXJkIHNlcnZlci4gUm'
    'VxdWlyZXMgYW4gRVNQMzIgZGV2aWNlIHdpdGggUFNSQU0uUghpc1NlcnZlchq1AwoPUmFuZ2VU'
    'ZXN0Q29uZmlnEkwKB2VuYWJsZWQYASABKAhCMsrzGC46ElJhbmdlIFRlc3QgRW5hYmxlZEIYRW'
    '5hYmxlIHJhbmdlIHRlc3QgbW9kdWxlUgdlbmFibGVkEo0BCgZzZW5kZXIYAiABKA1CdcrzGHEq'
    'AXM6D1NlbmRlciBJbnRlcnZhbEJbVGhpcyBkZXZpY2Ugd2lsbCBzZW5kIG91dCByYW5nZSB0ZX'
    'N0IG1lc3NhZ2VzIG9uIHRoZSBzZWxlY3RlZCBpbnRlcnZhbC4gMCBkaXNhYmxlcyBzZW5kaW5n'
    'LlIGc2VuZGVyEo0BCgRzYXZlGAMgASgIQnnK8xh1OgRTYXZlQm1TYXZlcyBhIENTViB3aXRoIH'
    'RoZSByYW5nZSB0ZXN0IG1lc3NhZ2UgZGV0YWlscywgY3VycmVudGx5IG9ubHkgYXZhaWxhYmxl'
    'IG9uIEVTUDMyIGRldmljZXMgd2l0aCBhIHdlYiBzZXJ2ZXIuUgRzYXZlEjQKD2NsZWFyX29uX3'
    'JlYm9vdBgEIAEoCEIMyvMYCFIGMi43LjExUg1jbGVhck9uUmVib290GoQOCg9UZWxlbWV0cnlD'
    'b25maWcSiAEKFmRldmljZV91cGRhdGVfaW50ZXJ2YWwYASABKA1CUsrzGE4qAXM6F0RldmljZS'
    'BNZXRyaWNzIEludGVydmFsQjBIb3cgb2Z0ZW4gZGV2aWNlIG1ldHJpY3MgYXJlIHNlbnQgb3Zl'
    'ciB0aGUgbWVzaC5SFGRldmljZVVwZGF0ZUludGVydmFsEpwBChtlbnZpcm9ubWVudF91cGRhdG'
    'VfaW50ZXJ2YWwYAiABKA1CXMrzGFgqAXM6HEVudmlyb25tZW50IE1ldHJpY3MgSW50ZXJ2YWxC'
    'NUhvdyBvZnRlbiBlbnZpcm9ubWVudCBtZXRyaWNzIGFyZSBzZW50IG92ZXIgdGhlIG1lc2guUh'
    'llbnZpcm9ubWVudFVwZGF0ZUludGVydmFsEosBCh9lbnZpcm9ubWVudF9tZWFzdXJlbWVudF9l'
    'bmFibGVkGAMgASgIQkPK8xg/OhtFbnZpcm9ubWVudCBNZXRyaWNzIEVuYWJsZWRCIENvbGxlY3'
    'QgZW52aXJvbm1lbnQgbWVhc3VyZW1lbnRzUh1lbnZpcm9ubWVudE1lYXN1cmVtZW50RW5hYmxl'
    'ZBKFAQoaZW52aXJvbm1lbnRfc2NyZWVuX2VuYWJsZWQYBCABKAhCR8rzGEM6FVNob3cgb24gZG'
    'V2aWNlIHNjcmVlbkIqRGlzcGxheSBlbnZpcm9ubWVudCBtZWFzdXJlbWVudHMgb24gZGV2aWNl'
    'UhhlbnZpcm9ubWVudFNjcmVlbkVuYWJsZWQSgQEKHmVudmlyb25tZW50X2Rpc3BsYXlfZmFocm'
    'VuaGVpdBgFIAEoCEI7yvMYNzoSRGlzcGxheSBGYWhyZW5oZWl0QiFEaXNwbGF5IGVudmlyb25t'
    'ZW50IGluIEZhaHJlbmhlaXRSHGVudmlyb25tZW50RGlzcGxheUZhaHJlbmhlaXQSbgoTYWlyX3'
    'F1YWxpdHlfZW5hYmxlZBgGIAEoCEI+yvMYOjobQWlyIFF1YWxpdHkgTWV0cmljcyBFbmFibGVk'
    'QhtDb2xsZWN0IGFpciBxdWFsaXR5IG1ldHJpY3NSEWFpclF1YWxpdHlFbmFibGVkEo4BChRhaX'
    'JfcXVhbGl0eV9pbnRlcnZhbBgHIAEoDUJcyvMYWCoBczocQWlyIFF1YWxpdHkgTWV0cmljcyBJ'
    'bnRlcnZhbEI1SG93IG9mdGVuIGFpciBxdWFsaXR5IG1ldHJpY3MgYXJlIHNlbnQgb3ZlciB0aG'
    'UgbWVzaC5SEmFpclF1YWxpdHlJbnRlcnZhbBJyChlwb3dlcl9tZWFzdXJlbWVudF9lbmFibGVk'
    'GAggASgIQjbK8xgyOhlQb3dlciBNZWFzdXJlbWVudCBFbmFibGVkQhVDb2xsZWN0IHBvd2VyIG'
    '1ldHJpY3NSF3Bvd2VyTWVhc3VyZW1lbnRFbmFibGVkEoQBChVwb3dlcl91cGRhdGVfaW50ZXJ2'
    'YWwYCSABKA1CUMrzGEwqAXM6FlBvd2VyIE1ldHJpY3MgSW50ZXJ2YWxCL0hvdyBvZnRlbiBwb3'
    'dlciBtZXRyaWNzIGFyZSBzZW50IG92ZXIgdGhlIG1lc2guUhNwb3dlclVwZGF0ZUludGVydmFs'
    'EmUKFHBvd2VyX3NjcmVlbl9lbmFibGVkGAogASgIQjPK8xgvOgxQb3dlciBTY3JlZW5CH0Rpc3'
    'BsYXkgcG93ZXIgbWV0cmljcyBvbiBkZXZpY2VSEnBvd2VyU2NyZWVuRW5hYmxlZBI8ChpoZWFs'
    'dGhfbWVhc3VyZW1lbnRfZW5hYmxlZBgLIAEoCFIYaGVhbHRoTWVhc3VyZW1lbnRFbmFibGVkEj'
    'QKFmhlYWx0aF91cGRhdGVfaW50ZXJ2YWwYDCABKA1SFGhlYWx0aFVwZGF0ZUludGVydmFsEjIK'
    'FWhlYWx0aF9zY3JlZW5fZW5hYmxlZBgNIAEoCFITaGVhbHRoU2NyZWVuRW5hYmxlZBLWAQoYZG'
    'V2aWNlX3RlbGVtZXRyeV9lbmFibGVkGA4gASgIQpsByvMYlgE6GEJyb2FkY2FzdCBEZXZpY2Ug'
    'TWV0cmljc0JyRW5hYmxlIGJyb2FkY2FzdGluZyBkZXZpY2UgbWV0cmljcyB0byB0aGUgbWVzaC'
    'BuZXR3b3JrLiBXaGVuIGRpc2FibGVkLCBtZXRyaWNzIGFyZSBvbmx5IHNlbnQgdG8gY29ubmVj'
    'dGVkIGNsaWVudHMuUgYyLjcuMTNSFmRldmljZVRlbGVtZXRyeUVuYWJsZWQSSQoaYWlyX3F1YW'
    'xpdHlfc2NyZWVuX2VuYWJsZWQYDyABKAhCDMrzGAhSBjIuNy4xOFIXYWlyUXVhbGl0eVNjcmVl'
    'bkVuYWJsZWQamwsKE0Nhbm5lZE1lc3NhZ2VDb25maWcSVAoPcm90YXJ5MV9lbmFibGVkGAEgAS'
    'gIQivK8xgnOg5Sb3RhcnkgRW5jb2RlckIVRW5hYmxlIHJvdGFyeSBlbmNvZGVyUg5yb3Rhcnkx'
    'RW5hYmxlZBJcChFpbnB1dGJyb2tlcl9waW5fYRgCIAEoDUIwyvMYLDoFUGluIEFCI0dQSU8gcG'
    'luIGZvciByb3RhcnkgZW5jb2RlciBBIHBvcnQuUg9pbnB1dGJyb2tlclBpbkESXAoRaW5wdXRi'
    'cm9rZXJfcGluX2IYAyABKA1CMMrzGCw6BVBpbiBCQiNHUElPIHBpbiBmb3Igcm90YXJ5IGVuY2'
    '9kZXIgQiBwb3J0LlIPaW5wdXRicm9rZXJQaW5CEmsKFWlucHV0YnJva2VyX3Bpbl9wcmVzcxgE'
    'IAEoDUI3yvMYMzoJUHJlc3MgUGluQiZHUElPIHBpbiBmb3IgdGhlIGVuY29kZXIgcHJlc3MgYn'
    'V0dG9uLlITaW5wdXRicm9rZXJQaW5QcmVzcxKvAQoUaW5wdXRicm9rZXJfZXZlbnRfY3cYBSAB'
    'KA4yOy5tZXNodGFzdGljLk1vZHVsZUNvbmZpZy5DYW5uZWRNZXNzYWdlQ29uZmlnLklucHV0RX'
    'ZlbnRDaGFyQkDK8xg8OhZDbG9ja3dpc2UgUm90YXJ5IEV2ZW50QiJJbnB1dCBldmVudCBmb3Ig'
    'Y2xvY2t3aXNlIHJvdGF0aW9uUhJpbnB1dGJyb2tlckV2ZW50Q3cSwAEKFWlucHV0YnJva2VyX2'
    'V2ZW50X2NjdxgGIAEoDjI7Lm1lc2h0YXN0aWMuTW9kdWxlQ29uZmlnLkNhbm5lZE1lc3NhZ2VD'
    'b25maWcuSW5wdXRFdmVudENoYXJCT8rzGEs6HUNvdW50ZXJjbG9ja3dpc2UgUm90YXJ5IEV2ZW'
    '50QipJbnB1dCBldmVudCBmb3IgY291bnRlci1jbG9ja3dpc2Ugcm90YXRpb25SE2lucHV0YnJv'
    'a2VyRXZlbnRDY3cSrQEKF2lucHV0YnJva2VyX2V2ZW50X3ByZXNzGAcgASgOMjsubWVzaHRhc3'
    'RpYy5Nb2R1bGVDb25maWcuQ2FubmVkTWVzc2FnZUNvbmZpZy5JbnB1dEV2ZW50Q2hhckI4yvMY'
    'NDoTRW5jb2RlciBQcmVzcyBFdmVudEIdSW5wdXQgZXZlbnQgZm9yIGVuY29kZXIgcHJlc3NSFW'
    'lucHV0YnJva2VyRXZlbnRQcmVzcxJgCg91cGRvd24xX2VuYWJsZWQYCCABKAhCN8rzGDM6FFVw'
    'L0Rvd24vU2VsZWN0IElucHV0QhtFbmFibGUgdXAvZG93bi9zZWxlY3QgaW5wdXRSDnVwZG93bj'
    'FFbmFibGVkEicKB2VuYWJsZWQYCSABKAhCDRgByvMYB1oFMi43LjBSB2VuYWJsZWQSOwoSYWxs'
    'b3dfaW5wdXRfc291cmNlGAogASgJQg0YAcrzGAdaBTIuNy4wUhBhbGxvd0lucHV0U291cmNlEk'
    '8KCXNlbmRfYmVsbBgLIAEoCEIyyvMYLjoJU2VuZCBCZWxsQiFTZW5kIGJlbGwgY2hhcmFjdGVy'
    'IHdpdGggbWVzc2FnZXNSCHNlbmRCZWxsIsYBCg5JbnB1dEV2ZW50Q2hhchIUCgROT05FEAAaCs'
    'rzGAY6BE5vbmUSEAoCVVAQERoIyvMYBDoCVXASFAoERE9XThASGgrK8xgGOgREb3duEhQKBExF'
    'RlQQExoKyvMYBjoETGVmdBIWCgVSSUdIVBAUGgvK8xgHOgVSaWdodBIYCgZTRUxFQ1QQChoMyv'
    'MYCDoGU2VsZWN0EhQKBEJBQ0sQGxoKyvMYBjoEQmFjaxIYCgZDQU5DRUwQGBoMyvMYCDoGQ2Fu'
    'Y2VsGvgEChVBbWJpZW50TGlnaHRpbmdDb25maWcSSwoJbGVkX3N0YXRlGAEgASgIQi7K8xgqOg'
    'lMRUQgU3RhdGVCHVRoZSBzdGF0ZSBvZiB0aGUgTEVEIChvbi9vZmYpUghsZWRTdGF0ZRJ9Cgdj'
    'dXJyZW50GAIgASgNQmPK8xhfGQAAAAAAAAAAIQAAAAAAAD9AOgdDdXJyZW50QiFEcml2ZSBjdX'
    'JyZW50IGZvciB0aGUgTEVEIG91dHB1dC5KH2xlZHxicmlnaHRuZXNzfGFtYmllbnR8bGlnaHRp'
    'bmdSB2N1cnJlbnQSgAEKA3JlZBgDIAEoDUJuyvMYahkAAAAAAAAAACEAAAAAAOBvQDoDUmVkQi'
    'pUaGUgcmVkIGxldmVsIG9mIHRoZSBhbWJpZW50IGxpZ2h0aW5nIExFRC5KJWNvbG9yfGNvbG91'
    'cnxyZ2J8bGVkfGFtYmllbnR8bGlnaHRpbmdSA3JlZBKIAQoFZ3JlZW4YBCABKA1CcsrzGG4ZAA'
    'AAAAAAAAAhAAAAAADgb0A6BUdyZWVuQixUaGUgZ3JlZW4gbGV2ZWwgb2YgdGhlIGFtYmllbnQg'
    'bGlnaHRpbmcgTEVELkolY29sb3J8Y29sb3VyfHJnYnxsZWR8YW1iaWVudHxsaWdodGluZ1IFZ3'
    'JlZW4ShAEKBGJsdWUYBSABKA1CcMrzGGwZAAAAAAAAAAAhAAAAAADgb0A6BEJsdWVCK1RoZSBi'
    'bHVlIGxldmVsIG9mIHRoZSBhbWJpZW50IGxpZ2h0aW5nIExFRC5KJWNvbG9yfGNvbG91cnxyZ2'
    'J8bGVkfGFtYmllbnR8bGlnaHRpbmdSBGJsdWUaNgoTU3RhdHVzTWVzc2FnZUNvbmZpZxIfCgtu'
    'b2RlX3N0YXR1cxgBIAEoCVIKbm9kZVN0YXR1cxqeCgoQTWVzaEJlYWNvbkNvbmZpZxIUCgVmbG'
    'FncxgBIAEoDVIFZmxhZ3MSSAoeYnJvYWRjYXN0X29mZmVyX2ZyZXF1ZW5jeV9zbG90GAIgASgN'
    'SABSG2Jyb2FkY2FzdE9mZmVyRnJlcXVlbmN5U2xvdIgBARJqChFicm9hZGNhc3RfbWVzc2FnZR'
    'gEIAEoCUI9yvMYOToHTWVzc2FnZUIuTWVzc2FnZSBmb3IgYmVhY29uIGJyb2FkY2FzdHMsIHVw'
    'IHRvIDYwIGJ5dGVzLlIQYnJvYWRjYXN0TWVzc2FnZRJTChdicm9hZGNhc3Rfb2ZmZXJfY2hhbm'
    '5lbBgFIAEoCzIbLm1lc2h0YXN0aWMuQ2hhbm5lbFNldHRpbmdzUhVicm9hZGNhc3RPZmZlckNo'
    'YW5uZWwSXgoWYnJvYWRjYXN0X29mZmVyX3JlZ2lvbhgGIAEoDjIoLm1lc2h0YXN0aWMuQ29uZm'
    'lnLkxvUmFDb25maWcuUmVnaW9uQ29kZVIUYnJvYWRjYXN0T2ZmZXJSZWdpb24SZAoWYnJvYWRj'
    'YXN0X29mZmVyX3ByZXNldBgHIAEoDjIpLm1lc2h0YXN0aWMuQ29uZmlnLkxvUmFDb25maWcuTW'
    '9kZW1QcmVzZXRIAVIUYnJvYWRjYXN0T2ZmZXJQcmVzZXSIAQEShAEKF2Jyb2FkY2FzdF9pbnRl'
    'cnZhbF9zZWNzGAsgASgNQkzK8xhIGQAAAAAAIKxAKgFzOghJbnRlcnZhbEIwSG93IG9mdGVuIG'
    'EgYmVhY29uIGlzIGJyb2FkY2FzdC4gTWluaW11bSAxIGhvdXIuUhVicm9hZGNhc3RJbnRlcnZh'
    'bFNlY3MSZgoRYnJvYWRjYXN0X3RhcmdldHMYDSADKAsyOS5tZXNodGFzdGljLk1vZHVsZUNvbm'
    'ZpZy5NZXNoQmVhY29uQ29uZmlnLkJyb2FkY2FzdFRhcmdldFIQYnJvYWRjYXN0VGFyZ2V0cxqh'
    'AgoPQnJvYWRjYXN0VGFyZ2V0EkYKBnByZXNldBgBIAEoDjIpLm1lc2h0YXN0aWMuQ29uZmlnLk'
    'xvUmFDb25maWcuTW9kZW1QcmVzZXRIAFIGcHJlc2V0iAEBEkAKBnJlZ2lvbhgCIAEoDjIoLm1l'
    'c2h0YXN0aWMuQ29uZmlnLkxvUmFDb25maWcuUmVnaW9uQ29kZVIGcmVnaW9uEigKDWNoYW5uZW'
    'xfaW5kZXgYBCABKA1IAVIMY2hhbm5lbEluZGV4iAEBEioKDmZyZXF1ZW5jeV9zbG90GAUgASgN'
    'SAJSDWZyZXF1ZW5jeVNsb3SIAQFCCQoHX3ByZXNldEIQCg5fY2hhbm5lbF9pbmRleEIRCg9fZn'
    'JlcXVlbmN5X3Nsb3QiYgoFRmxhZ3MSDQoJRkxBR19OT05FEAASFwoTRkxBR19MSVNURU5fRU5B'
    'QkxFRBABEhoKFkZMQUdfQlJPQURDQVNUX0VOQUJMRUQQAhIVChFGTEFHX0xFR0FDWV9TUExJVB'
    'AEQiEKH19icm9hZGNhc3Rfb2ZmZXJfZnJlcXVlbmN5X3Nsb3RCGQoXX2Jyb2FkY2FzdF9vZmZl'
    'cl9wcmVzZXRKBAgDEARKBAgIEAlKBAgJEApKBAgKEAtSFmJyb2FkY2FzdF9zZW5kX2FzX25vZG'
    'VSFGJyb2FkY2FzdF9vbl9jaGFubmVsUhNicm9hZGNhc3Rfb25fcmVnaW9uUhNicm9hZGNhc3Rf'
    'b25fcHJlc2V0GpYBCglUQUtDb25maWcSQAoEdGVhbRgBIAEoDjIQLm1lc2h0YXN0aWMuVGVhbU'
    'IayvMYFjoEVGVhbUIOVEFLIHRlYW0gY29sb3JSBHRlYW0SRwoEcm9sZRgCIAEoDjIWLm1lc2h0'
    'YXN0aWMuTWVtYmVyUm9sZUIbyvMYFzoEUm9sZUIPVEFLIG1lbWJlciByb2xlUgRyb2xlQhEKD3'
    'BheWxvYWRfdmFyaWFudA==');

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
