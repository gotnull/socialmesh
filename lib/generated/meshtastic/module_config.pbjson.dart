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
      '8': {},
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
    'NvbmZpZy5NZXNoQmVhY29uQ29uZmlnQgvK8xgHUgUyLjguMEgAUgptZXNoQmVhY29uGpQKCgpN'
    'UVRUQ29uZmlnEkEKB2VuYWJsZWQYASABKAhCJ8rzGCM6DE1RVFQgRW5hYmxlZEITRW5hYmxlIE'
    '1RVFQgZ2F0ZXdheVIHZW5hYmxlZBI8CgdhZGRyZXNzGAIgASgJQiLK8xgeOgdBZGRyZXNzQhNN'
    'UVRUIHNlcnZlciBhZGRyZXNzUgdhZGRyZXNzEjkKCHVzZXJuYW1lGAMgASgJQh3K8xgZOghVc2'
    'VybmFtZUINTVFUVCB1c2VybmFtZVIIdXNlcm5hbWUSOwoIcGFzc3dvcmQYBCABKAlCH8rzGBs6'
    'CFBhc3N3b3JkQg1NUVRUIHBhc3N3b3JkaAFSCHBhc3N3b3JkEsIBChJlbmNyeXB0aW9uX2VuYW'
    'JsZWQYBSABKAhCkgHK8xiNAToSRW5jcnlwdGlvbiBFbmFibGVkQndTZW5kIGVuY3J5cHRlZCBw'
    'YWNrZXRzIHRvIE1RVFQuIFdoZW4gb2ZmLCB0aGUgYnJva2VyIGFuZCBhbnlvbmUgd2hvIGNhbi'
    'BwdWJsaXNoIHRvIGl0IGFyZSB0cnVzdGVkIGxpa2UgY2hhbm5lbCBtZW1iZXJzLlIRZW5jcnlw'
    'dGlvbkVuYWJsZWQSfwoManNvbl9lbmFibGVkGAYgASgIQlwYAcrzGFY6E0pTT04gT3V0cHV0IE'
    'VuYWJsZWRCOFNlbmQgYW5kIHJlY2VpdmUgcGxhaW4gSlNPTiBjb3BpZXMgb2YgcGFja2V0cyBv'
    'dmVyIE1RVFQuWgUyLjguMFILanNvbkVuYWJsZWQSWAoLdGxzX2VuYWJsZWQYByABKAhCN8rzGD'
    'M6C1RMUyBFbmFibGVkQiRDb25uZWN0IHRvIHRoZSBNUVRUIHNlcnZlciBvdmVyIFRMUy5SCnRs'
    'c0VuYWJsZWQSNQoEcm9vdBgIIAEoCUIhyvMYHToKUm9vdCBUb3BpY0IPTVFUVCByb290IHRvcG'
    'ljUgRyb290EpEBChdwcm94eV90b19jbGllbnRfZW5hYmxlZBgJIAEoCEJayvMYVjoRTVFUVCBD'
    'bGllbnQgUHJveHlCQVV0aWxpemVzIHRoZSBuZXR3b3JrIGNvbm5lY3Rpb24gb24geW91ciBwaG'
    '9uZSB0byBjb25uZWN0IHRvIE1RVFQuUhRwcm94eVRvQ2xpZW50RW5hYmxlZBLFAgoVbWFwX3Jl'
    'cG9ydGluZ19lbmFibGVkGAogASgIQpACyvMYiwI6DU1hcCBSZXBvcnRpbmdC+QFZb3VyIG5vZG'
    'Ugd2lsbCBwZXJpb2RpY2FsbHkgc2VuZCBhbiB1bmVuY3J5cHRlZCBtYXAgcmVwb3J0IHBhY2tl'
    'dCB0byB0aGUgY29uZmlndXJlZCBNUVRUIHNlcnZlciwgdGhpcyBpbmNsdWRlcyBpZCwgc2hvcn'
    'QgYW5kIGxvbmcgbmFtZSwgYXBwcm94aW1hdGUgbG9jYXRpb24sIGhhcmR3YXJlIG1vZGVsLCBy'
    'b2xlLCBmaXJtd2FyZSB2ZXJzaW9uLCBMb1JhIHJlZ2lvbiwgbW9kZW0gcHJlc2V0IGFuZCBwcm'
    'ltYXJ5IGNoYW5uZWwgbmFtZS5SE21hcFJlcG9ydGluZ0VuYWJsZWQSWgoTbWFwX3JlcG9ydF9z'
    'ZXR0aW5ncxgLIAEoCzIqLm1lc2h0YXN0aWMuTW9kdWxlQ29uZmlnLk1hcFJlcG9ydFNldHRpbm'
    'dzUhFtYXBSZXBvcnRTZXR0aW5ncxqpAwoRTWFwUmVwb3J0U2V0dGluZ3MSkAEKFXB1Ymxpc2hf'
    'aW50ZXJ2YWxfc2VjcxgBIAEoDUJcyvMYWBkAAAAAACCsQCoBczoUTWFwIFB1Ymxpc2ggSW50ZX'
    'J2YWxCNEhvdyBvZnRlbiBhIG1hcCByZXBvcnQgaXMgcHVibGlzaGVkLiBNaW5pbXVtIDEgaG91'
    'ci5SE3B1Ymxpc2hJbnRlcnZhbFNlY3MSLQoScG9zaXRpb25fcHJlY2lzaW9uGAIgASgNUhFwb3'
    'NpdGlvblByZWNpc2lvbhLRAQoWc2hvdWxkX3JlcG9ydF9sb2NhdGlvbhgDIAEoCEKaAcrzGJUB'
    'OgxTaGFyZSBvbiBNYXBCfkNvbnNlbnQgdG8gcHVibGlzaCB0aGlzIG5vZGUncyBkZXRhaWxzIG'
    'FuZCBhcHByb3hpbWF0ZSBsb2NhdGlvbiB1bmVuY3J5cHRlZCB0byB0aGUgTVFUVCBtYXAuIE5v'
    'IG1hcCByZXBvcnQgaXMgc2VudCB3aXRob3V0IGl0LlIFMi42LjhSFHNob3VsZFJlcG9ydExvY2'
    'F0aW9uGrMBChRSZW1vdGVIYXJkd2FyZUNvbmZpZxIYCgdlbmFibGVkGAEgASgIUgdlbmFibGVk'
    'EjsKGmFsbG93X3VuZGVmaW5lZF9waW5fYWNjZXNzGAIgASgIUhdhbGxvd1VuZGVmaW5lZFBpbk'
    'FjY2VzcxJECg5hdmFpbGFibGVfcGlucxgDIAMoCzIdLm1lc2h0YXN0aWMuUmVtb3RlSGFyZHdh'
    'cmVQaW5SDWF2YWlsYWJsZVBpbnMasAQKEk5laWdoYm9ySW5mb0NvbmZpZxK7AQoHZW5hYmxlZB'
    'gBIAEoCEKgAcrzGJsBOhVOZWlnaGJvciBJbmZvIEVuYWJsZWRCgQFFbmFibGUgbmVpZ2hib3Ig'
    'aW5mbyBicm9hZGNhc3RpbmcuIFBlcmlvZGljYWxseSBzZW5kcyBpbmZvcm1hdGlvbiBhYm91dC'
    'BkaXJlY3RseS1oZWFyZCBuZWlnaGJvcnMgdG8gaGVscCB2aXN1YWxpemUgbWVzaCB0b3BvbG9n'
    'eS5SB2VuYWJsZWQSggEKD3VwZGF0ZV9pbnRlcnZhbBgCIAEoDUJZyvMYVRkAAAAAACDMQCoBcz'
    'oPVXBkYXRlIEludGVydmFsQjZIb3cgb2Z0ZW4gdG8gYnJvYWRjYXN0IG5laWdoYm9yIGluZm8u'
    'IE1pbmltdW0gNCBob3Vycy5SDnVwZGF0ZUludGVydmFsEtYBChJ0cmFuc21pdF9vdmVyX2xvcm'
    'EYAyABKAhCpwHK8xiiAToSVHJhbnNtaXQgb3ZlciBMb1JhQosBV2hldGhlciB0byB0cmFuc21p'
    'dCBuZWlnaGJvciBpbmZvIG92ZXIgTG9SYSBpbiBhZGRpdGlvbiB0byBNUVRUIGFuZCB0aGUgY2'
    '9ubmVjdGVkIGFwcC4gTm90IGF2YWlsYWJsZSBvbiBjaGFubmVscyB3aXRoIGRlZmF1bHQga2V5'
    'IGFuZCBuYW1lLlIQdHJhbnNtaXRPdmVyTG9yYRrcCwoVRGV0ZWN0aW9uU2Vuc29yQ29uZmlnEo'
    'wCCgdlbmFibGVkGAEgASgIQvEByvMY7AE6GERldGVjdGlvbiBTZW5zb3IgRW5hYmxlZELPAUVu'
    'YWJsZXMgdGhlIGRldGVjdGlvbiBzZW5zb3IgbW9kdWxlLCBpdCBuZWVkcyB0byBiZSBlbmFibG'
    'VkIG9uIGJvdGggdGhlIG5vZGUgd2l0aCB0aGUgc2Vuc29yLCBhbmQgYW55IG5vZGVzIHRoYXQg'
    'eW91IHdhbnQgdG8gcmVjZWl2ZSBkZXRlY3Rpb24gc2Vuc29yIHRleHQgbWVzc2FnZXMgb3Igdm'
    'lldyB0aGUgZGV0ZWN0aW9uIHNlbnNvciBsb2cgYW5kIGNoYXJ0LlIHZW5hYmxlZBKUAQoWbWlu'
    'aW11bV9icm9hZGNhc3Rfc2VjcxgCIAEoDUJeyvMYWioBczopTWluaW11bSB0aW1lIGJldHdlZW'
    '4gZGV0ZWN0aW9uIGJyb2FkY2FzdHNCKk1pbmltdW0gdGltZSBiZXR3ZWVuIGRldGVjdGlvbiBi'
    'cm9hZGNhc3RzLlIUbWluaW11bUJyb2FkY2FzdFNlY3MS0QEKFHN0YXRlX2Jyb2FkY2FzdF9zZW'
    'NzGAMgASgNQp4ByvMYmQEqAXM6GFN0YXRlIEJyb2FkY2FzdCBJbnRlcnZhbEJ6SG93IG9mdGVu'
    'IHRvIHNlbmQgdGhlIGRldGVjdGlvbiBzZW5zb3Igc3RhdGUgdG8gdGhlIG1lc2gsIHdoZXRoZX'
    'Igb3Igbm90IGFueXRoaW5nIHdhcyBkZXRlY3RlZC4gMCBzZW5kcyBvbmx5IG9uIGRldGVjdGlv'
    'bi5SEnN0YXRlQnJvYWRjYXN0U2VjcxKGAQoJc2VuZF9iZWxsGAQgASgIQmnK8xhlOglTZW5kIE'
    'JlbGxCWFNlbmQgQVNDSUkgYmVsbCB3aXRoIGFsZXJ0IG1lc3NhZ2UuIFVzZWZ1bCBmb3IgdHJp'
    'Z2dlcmluZyBleHRlcm5hbCBub3RpZmljYXRpb24gb24gYmVsbC5SCHNlbmRCZWxsEj0KBG5hbW'
    'UYBSABKAlCKcrzGCU6BE5hbWVCHVNlbnNvciBuYW1lIGZvciBtZXNoIG1lc3NhZ2VzUgRuYW1l'
    'EnYKC21vbml0b3JfcGluGAYgASgNQlXK8xhROhNHUElPIFBpbiB0byBtb25pdG9yQjpHUElPIH'
    'BpbiB3YXRjaGVkIGZvciBzdGF0ZSBjaGFuZ2VzLiAwIGRpc2FibGVzIHRoZSBtb2R1bGUuUgpt'
    'b25pdG9yUGluEpsBChZkZXRlY3Rpb25fdHJpZ2dlcl90eXBlGAcgASgOMjoubWVzaHRhc3RpYy'
    '5Nb2R1bGVDb25maWcuRGV0ZWN0aW9uU2Vuc29yQ29uZmlnLlRyaWdnZXJUeXBlQinK8xglOgxU'
    'cmlnZ2VyIFR5cGVCFVR5cGUgb2YgdHJpZ2dlciBldmVudFIUZGV0ZWN0aW9uVHJpZ2dlclR5cG'
    'UScwoKdXNlX3B1bGx1cBgIIAEoCEJUyvMYUDoUVXNlIEludGVybmFsIFB1bGwtdXBCOEVuYWJs'
    'ZSB0aGUgaW50ZXJuYWwgcHVsbC11cCByZXNpc3RvciBvbiB0aGUgbW9uaXRvciBwaW4uUgl1c2'
    'VQdWxsdXAi9QEKC1RyaWdnZXJUeXBlEhgKCUxPR0lDX0xPVxAAGgnK8xgFOgNMb3cSGgoKTE9H'
    'SUNfSElHSBABGgrK8xgGOgRIaWdoEiQKDEZBTExJTkdfRURHRRACGhLK8xgOOgxGYWxsaW5nIE'
    'VkZ2USIgoLUklTSU5HX0VER0UQAxoRyvMYDToLUmlzaW5nIEVkZ2USMQoWRUlUSEVSX0VER0Vf'
    'QUNUSVZFX0xPVxAEGhXK8xgROg9FaXRoZXIgRWRnZSBMb3cSMwoXRUlUSEVSX0VER0VfQUNUSV'
    'ZFX0hJR0gQBRoWyvMYEjoQRWl0aGVyIEVkZ2UgSGlnaBrsBwoLQXVkaW9Db25maWcSiQEKDmNv'
    'ZGVjMl9lbmFibGVkGAEgASgIQmLK8xheOg5Db2RlYzIgRW5hYmxlZEJMRW5hYmxlIENvZGVjMi'
    'BhdWRpbyBlbmNvZGluZy9kZWNvZGluZyBmb3Igdm9pY2UgY29tbXVuaWNhdGlvbiBvdmVyIHRo'
    'ZSBtZXNoLlINY29kZWMyRW5hYmxlZBJVCgdwdHRfcGluGAIgASgNQjzK8xg4OgdQVFQgUGluQi'
    '1QdXNoLXRvLXRhbGsgR1BJTyBwaW4gbnVtYmVyLiAwIHVzZXMgR1BJTyAzOS5SBnB0dFBpbhLT'
    'AQoHYml0cmF0ZRgDIAEoDjIvLm1lc2h0YXN0aWMuTW9kdWxlQ29uZmlnLkF1ZGlvQ29uZmlnLk'
    'F1ZGlvX0JhdWRChwHK8xiCAToHQml0cmF0ZUJ3VGhlIENvZGVjMiBiaXRyYXRlIHRvIHVzZS4g'
    'VGhlIHNhbXBsZSByYXRlIGlzIGFsd2F5cyA4IGtIei4gTG93ZXIgYml0cmF0ZXMgdXNlIGxlc3'
    'MgYmFuZHdpZHRoIGJ1dCByZWR1Y2UgYXVkaW8gcXVhbGl0eS5SB2JpdHJhdGUSMAoGaTJzX3dz'
    'GAQgASgNQhnK8xgVOhNJMlMgV29yZCBTZWxlY3QgUGluUgVpMnNXcxIsCgZpMnNfc2QYBSABKA'
    '1CFcrzGBE6D0kyUyBEYXRhIEluIFBpblIFaTJzU2QSLwoHaTJzX2RpbhgGIAEoDUIWyvMYEjoQ'
    'STJTIERhdGEgT3V0IFBpblIGaTJzRGluEiwKB2kyc19zY2sYByABKA1CE8rzGA86DUkyUyBDbG'
    '9jayBQaW5SBmkyc1NjayLkAgoKQXVkaW9fQmF1ZBIhCg5DT0RFQzJfREVGQVVMVBAAGg3K8xgJ'
    'OgdEZWZhdWx0Eh8KC0NPREVDMl8zMjAwEAEaDsrzGAo6CDMyMDAgYnBzEh8KC0NPREVDMl8yND'
    'AwEAIaDsrzGAo6CDI0MDAgYnBzEh8KC0NPREVDMl8xNjAwEAMaDsrzGAo6CDE2MDAgYnBzEh8K'
    'C0NPREVDMl8xNDAwEAQaDsrzGAo6CDE0MDAgYnBzEh8KC0NPREVDMl8xMzAwEAUaDsrzGAo6CD'
    'EzMDAgYnBzEh8KC0NPREVDMl8xMjAwEAYaDsrzGAo6CDEyMDAgYnBzEhIKCkNPREVDMl83MDAQ'
    'BxoCCAESEwoLQ09ERUMyXzcwMEIQCBoCCAESJQoLQ09ERUMyXzcwMEMQCRoUyvMYEDoONzAwIG'
    'JwcyAoNzAwQykSHQoKQ09ERUMyXzQ1MBAKGg3K8xgJOgc0NTAgYnBzGr4EChBQYXhjb3VudGVy'
    'Q29uZmlnEsgBCgdlbmFibGVkGAEgASgIQq0ByvMYqAE6E1BBWCBDb3VudGVyIEVuYWJsZWRCkA'
    'FXaGVuIGVuYWJsZWQsIHRoZSBQQVggQ291bnRlciBtb2R1bGUgY291bnRzIG5lYXJieSBXaUZp'
    'IGFuZCBCbHVldG9vdGggZGV2aWNlcy4gQm90aCBXaUZpIGFuZCBCbHVldG9vdGggbXVzdCBiZS'
    'BkaXNhYmxlZCBmb3IgUEFYIGNvdW50ZXIgdG8gd29yay5SB2VuYWJsZWQSiAEKGnBheGNvdW50'
    'ZXJfdXBkYXRlX2ludGVydmFsGAIgASgNQkrK8xhGKgFzOg9VcGRhdGUgSW50ZXJ2YWxCMEhvdy'
    'BvZnRlbiB0byBzZW5kIHRoZSBkZXZpY2UgY291bnRzIHRvIHRoZSBtZXNoLlIYcGF4Y291bnRl'
    'clVwZGF0ZUludGVydmFsEmsKDndpZmlfdGhyZXNob2xkGAMgASgFQkTK8xhAKgNkQm06DldpRm'
    'kgVGhyZXNob2xkQilSU1NJIHRocmVzaG9sZCBmb3IgY291bnRpbmcgV2lGaSBkZXZpY2VzLlIN'
    'd2lmaVRocmVzaG9sZBJnCg1ibGVfdGhyZXNob2xkGAQgASgFQkLK8xg+KgNkQm06DUJMRSBUaH'
    'Jlc2hvbGRCKFJTU0kgdGhyZXNob2xkIGZvciBjb3VudGluZyBCTEUgZGV2aWNlcy5SDGJsZVRo'
    'cmVzaG9sZBr0CAoXVHJhZmZpY01hbmFnZW1lbnRDb25maWcSpAEKGnBvc2l0aW9uX21pbl9pbn'
    'RlcnZhbF9zZWNzGAQgASgNQmfK8xhjKgFzOhlNaW5pbXVtIFBvc2l0aW9uIEludGVydmFsQkNQ'
    'b3NpdGlvbnMgZnJvbSB0aGUgc2FtZSBub2RlIGFycml2aW5nIHNvb25lciB0aGFuIHRoaXMgYX'
    'JlIGRyb3BwZWQuUhdwb3NpdGlvbk1pbkludGVydmFsU2VjcxKBAgohbm9kZWluZm9fZGlyZWN0'
    'X3Jlc3BvbnNlX21heF9ob3BzGAYgASgNQrYByvMYsQEhAAAAAAAACEA6GERpcmVjdCBOb2RlSW'
    '5mbyBNYXggSG9wc0KLAUFuc3dlciBOb2RlSW5mbyByZXF1ZXN0cyBmcm9tIGNhY2hlIGZvciBy'
    'ZXF1ZXN0b3JzIHdpdGhpbiB0aGlzIG1hbnkgaG9wcy4gQ2FwcGVkIGF0IDMgb24gcm91dGVycz'
    'sgb3RoZXIgcm9sZXMgYW5zd2VyIGRpcmVjdCBuZWlnaGJvcnMgb25seS5SHW5vZGVpbmZvRGly'
    'ZWN0UmVzcG9uc2VNYXhIb3BzEnoKFnJhdGVfbGltaXRfd2luZG93X3NlY3MYCCABKA1CRcrzGE'
    'EqAXM6EVJhdGUgTGltaXQgV2luZG93QilUaGUgdGltZSB3aW5kb3cgcGFja2V0cyBhcmUgY291'
    'bnRlZCBvdmVyLlITcmF0ZUxpbWl0V2luZG93U2VjcxKKAQoWcmF0ZV9saW1pdF9tYXhfcGFja2'
    'V0cxgJIAEoDUJVyvMYUSEAAAAAAABOQDoWUmF0ZSBMaW1pdCBNYXggUGFja2V0c0IuVGhlIG1v'
    'c3QgcGFja2V0cyBvbmUgbm9kZSBtYXkgc2VuZCBwZXIgd2luZG93LlITcmF0ZUxpbWl0TWF4UG'
    'Fja2V0cxKtAQoYdW5rbm93bl9wYWNrZXRfdGhyZXNob2xkGAsgASgNQnPK8xhvIQAAAAAAAE5A'
    'OhhVbmtub3duIFBhY2tldCBUaHJlc2hvbGRCSlVuZGVjcnlwdGFibGUgcGFja2V0cyBvbmUgbm'
    '9kZSBtYXkgc2VuZCBpbiA1IG1pbnV0ZXMgYmVmb3JlIGl0IGlzIGRyb3BwZWQuUhZ1bmtub3du'
    'UGFja2V0VGhyZXNob2xkSgQIARACSgQIAhADSgQIAxAESgQIBRAGSgQIBxAISgQIChALSgQIDB'
    'ANSgQIDRAOSgQIDhAPUgdlbmFibGVkUhZwb3NpdGlvbl9kZWR1cF9lbmFibGVkUhdwb3NpdGlv'
    'bl9wcmVjaXNpb25fYml0c1IYbm9kZWluZm9fZGlyZWN0X3Jlc3BvbnNlUhJyYXRlX2xpbWl0X2'
    'VuYWJsZWRSFGRyb3BfdW5rbm93bl9lbmFibGVkUhVleGhhdXN0X2hvcF90ZWxlbWV0cnlSFGV4'
    'aGF1c3RfaG9wX3Bvc2l0aW9uUhRyb3V0ZXJfcHJlc2VydmVfaG9wcxqkDQoMU2VyaWFsQ29uZm'
    'lnEkQKB2VuYWJsZWQYASABKAhCKsrzGCY6DlNlcmlhbCBFbmFibGVkQhRFbmFibGUgc2VyaWFs'
    'IG1vZHVsZVIHZW5hYmxlZBJmCgRlY2hvGAIgASgIQlLK8xhOOgRFY2hvQkZJZiBzZXQsIGFueS'
    'BwYWNrZXRzIHlvdSBzZW5kIHdpbGwgYmUgZWNob2VkIGJhY2sgb3ZlciB0aGUgc2VyaWFsIHBv'
    'cnQuUgRlY2hvEkIKA3J4ZBgDIAEoDUIwyvMYLDobUmVjZWl2ZSBkYXRhIChyeGQpIEdQSU8gcG'
    'luQg1SWCBwaW4gbnVtYmVyUgNyeGQSQwoDdHhkGAQgASgNQjHK8xgtOhxUcmFuc21pdCBkYXRh'
    'ICh0eGQpIEdQSU8gcGluQg1UWCBwaW4gbnVtYmVyUgN0eGQSYwoEYmF1ZBgFIAEoDjIxLm1lc2'
    'h0YXN0aWMuTW9kdWxlQ29uZmlnLlNlcmlhbENvbmZpZy5TZXJpYWxfQmF1ZEIcyvMYGDoEQmF1'
    'ZEIQU2VyaWFsIGJhdWQgcmF0ZVIEYmF1ZBKHAQoHdGltZW91dBgGIAEoDUJtyvMYaSoCbXM6B1'
    'RpbWVvdXRCWkhvdyBsb25nIHRvIHdhaXQgYmVmb3JlIHRyZWF0aW5nIHJlY2VpdmVkIHNlcmlh'
    'bCBkYXRhIGFzIGEgY29tcGxldGUgcGFja2V0LiAwIHVzZXMgMjUwIG1zLlIHdGltZW91dBJvCg'
    'Rtb2RlGAcgASgOMjEubWVzaHRhc3RpYy5Nb2R1bGVDb25maWcuU2VyaWFsQ29uZmlnLlNlcmlh'
    'bF9Nb2RlQijK8xgkOgRNb2RlQhxTZXJpYWwgbW9kdWxlIG9wZXJhdGlvbiBtb2RlUgRtb2RlEs'
    '4BChxvdmVycmlkZV9jb25zb2xlX3NlcmlhbF9wb3J0GAggASgIQowByvMYhwE6HE92ZXJyaWRl'
    'IENvbnNvbGUgU2VyaWFsIFBvcnRCZ1VzZSB0aGUgY29uc29sZSBzZXJpYWwgcG9ydCBmb3IgdG'
    'hlIFNlcmlhbCBtb2R1bGUuIE9ubHkgd29ya3MgaW4gb3V0cHV0IG1vZGVzIHN1Y2ggYXMgTk1F'
    'QSBhbmQgQ2FsVG9wby5SGW92ZXJyaWRlQ29uc29sZVNlcmlhbFBvcnQiogQKC1NlcmlhbF9CYX'
    'VkEh8KDEJBVURfREVGQVVMVBAAGg3K8xgJOgdEZWZhdWx0EhwKCEJBVURfMTEwEAEaDsrzGAo6'
    'CDExMCBCYXVkEhwKCEJBVURfMzAwEAIaDsrzGAo6CDMwMCBCYXVkEhwKCEJBVURfNjAwEAMaDs'
    'rzGAo6CDYwMCBCYXVkEh4KCUJBVURfMTIwMBAEGg/K8xgLOgkxMjAwIEJhdWQSHgoJQkFVRF8y'
    'NDAwEAUaD8rzGAs6CTI0MDAgQmF1ZBIeCglCQVVEXzQ4MDAQBhoPyvMYCzoJNDgwMCBCYXVkEh'
    '4KCUJBVURfOTYwMBAHGg/K8xgLOgk5NjAwIEJhdWQSIAoKQkFVRF8xOTIwMBAIGhDK8xgMOgox'
    'OTIwMCBCYXVkEiAKCkJBVURfMzg0MDAQCRoQyvMYDDoKMzg0MDAgQmF1ZBIgCgpCQVVEXzU3Nj'
    'AwEAoaEMrzGAw6CjU3NjAwIEJhdWQSIgoLQkFVRF8xMTUyMDAQCxoRyvMYDToLMTE1MjAwIEJh'
    'dWQSIgoLQkFVRF8yMzA0MDAQDBoRyvMYDToLMjMwNDAwIEJhdWQSIgoLQkFVRF80NjA4MDAQDR'
    'oRyvMYDToLNDYwODAwIEJhdWQSIgoLQkFVRF81NzYwMDAQDhoRyvMYDToLNTc2MDAwIEJhdWQS'
    'IgoLQkFVRF85MjE2MDAQDxoRyvMYDToLOTIxNjAwIEJhdWQihgIKC1NlcmlhbF9Nb2RlEhoKB0'
    'RFRkFVTFQQABoNyvMYCToHRGVmYXVsdBIYCgZTSU1QTEUQARoMyvMYCDoGU2ltcGxlEhoKBVBS'
    'T1RPEAIaD8rzGAs6CVByb3RvYnVmcxIfCgdURVhUTVNHEAMaEsrzGA46DFRleHQgTWVzc2FnZR'
    'IeCgROTUVBEAQaFMrzGBA6Dk5NRUEgUG9zaXRpb25zEhoKB0NBTFRPUE8QBRoNyvMYCToHQ2Fs'
    'VG9wbxIICgRXUzg1EAYSDQoJVkVfRElSRUNUEAcSDQoJTVNfQ09ORklHEAgSBwoDTE9HEAkSCw'
    'oHTE9HVEVYVBAKEgoKBk1PREJVUxALGuIOChpFeHRlcm5hbE5vdGlmaWNhdGlvbkNvbmZpZxJc'
    'CgdlbmFibGVkGAEgASgIQkLK8xg+Oh1FeHRlcm5hbCBOb3RpZmljYXRpb24gRW5hYmxlZEIdRW'
    '5hYmxlIGV4dGVybmFsIG5vdGlmaWNhdGlvbnNSB2VuYWJsZWQSagoJb3V0cHV0X21zGAIgASgN'
    'Qk3K8xhJKgJtczoUR1BJTyBPdXRwdXQgRHVyYXRpb25CLUluIEdQSU8gbW9kZSwgaG93IGxvbm'
    'cgdG8ga2VlcCB0aGUgb3V0cHV0IG9uLlIIb3V0cHV0TXMSewoGb3V0cHV0GAMgASgNQmPK8xhf'
    'Og9PdXRwdXQgcGluIEdQSU9CTEdQSU8gcGluIGRyaXZlbiBvbiBub3RpZmljYXRpb24uIERlZm'
    'F1bHRzIHRvIHRoZSBib2FyZCdzIEVYVF9OT1RJRllfT1VUIHBpbi5SBm91dHB1dBJaCgxvdXRw'
    'dXRfdmlicmEYCCABKA1CN8rzGDM6FU91dHB1dCBwaW4gdmlicmEgR1BJT0IaVmlicmF0aW9uIG'
    '1vdG9yIG91dHB1dCBwaW5SC291dHB1dFZpYnJhElQKDW91dHB1dF9idXp6ZXIYCSABKA1CL8rz'
    'GCs6Fk91dHB1dCBwaW4gYnV6emVyIEdQSU9CEUJ1enplciBvdXRwdXQgcGluUgxvdXRwdXRCdX'
    'p6ZXISeQoGYWN0aXZlGAQgASgIQmHK8xhdOgZBY3RpdmVCU0lmIGVuYWJsZWQsIHRoZSAnb3V0'
    'cHV0JyBQaW4gd2lsbCBiZSBwdWxsZWQgYWN0aXZlIGhpZ2gsIGRpc2FibGVkIG1lYW5zIGFjdG'
    'l2ZSBsb3cuUgZhY3RpdmUSZAoNYWxlcnRfbWVzc2FnZRgFIAEoCEI/yvMYOzoeQWxlcnQgd2hl'
    'biByZWNlaXZpbmcgYSBtZXNzYWdlQhlBbGVydCBvbiBpbmNvbWluZyBtZXNzYWdlUgxhbGVydE'
    '1lc3NhZ2USeAoTYWxlcnRfbWVzc2FnZV92aWJyYRgKIAEoCEJIyvMYRDoRVmlicmEgTW90b3Ig'
    'QWxlcnRCL0FsZXJ0IEdQSU8gdmlicmEgbW90b3Igd2hlbiByZWNlaXZpbmcgYSBtZXNzYWdlUh'
    'FhbGVydE1lc3NhZ2VWaWJyYRJ8ChRhbGVydF9tZXNzYWdlX2J1enplchgLIAEoCEJKyvMYRjoq'
    'QWxlcnQgR1BJTyBidXp6ZXIgd2hlbiByZWNlaXZpbmcgYSBtZXNzYWdlQhhCdXp6IG9uIGluY2'
    '9taW5nIG1lc3NhZ2VSEmFsZXJ0TWVzc2FnZUJ1enplchJZCgphbGVydF9iZWxsGAYgASgIQjrK'
    '8xg2OhtBbGVydCB3aGVuIHJlY2VpdmluZyBhIGJlbGxCF0FsZXJ0IG9uIGJlbGwgY2hhcmFjdG'
    'VyUglhbGVydEJlbGwSdwoQYWxlcnRfYmVsbF92aWJyYRgMIAEoCEJNyvMYSTosQWxlcnQgR1BJ'
    'TyB2aWJyYSBtb3RvciB3aGVuIHJlY2VpdmluZyBhIGJlbGxCGVZpYnJhdGUgb24gYmVsbCBjaG'
    'FyYWN0ZXJSDmFsZXJ0QmVsbFZpYnJhEnEKEWFsZXJ0X2JlbGxfYnV6emVyGA0gASgIQkXK8xhB'
    'OidBbGVydCBHUElPIGJ1enplciB3aGVuIHJlY2VpdmluZyBhIGJlbGxCFkJ1enogb24gYmVsbC'
    'BjaGFyYWN0ZXJSD2FsZXJ0QmVsbEJ1enplchL2AQoHdXNlX3B3bRgHIAEoCELcAcrzGNcBOg5V'
    'c2UgUFdNIEJ1enplckLEAVVzZSBhIFBXTSBvdXRwdXQgKGxpa2UgdGhlIFJBSyBCdXp6ZXIpIG'
    'ZvciB0dW5lcyBpbnN0ZWFkIG9mIGFuIG9uL29mZiBvdXRwdXQuIFRoaXMgd2lsbCBpZ25vcmUg'
    'dGhlIG91dHB1dCwgb3V0cHV0IGR1cmF0aW9uIGFuZCBhY3RpdmUgc2V0dGluZ3MgYW5kIHVzZS'
    'B0aGUgZGV2aWNlIGNvbmZpZyBidXp6ZXIgR1BJTyBvcHRpb24gaW5zdGVhZC5SBnVzZVB3bRJX'
    'CgtuYWdfdGltZW91dBgOIAEoDUI2yvMYMioBczoLTmFnIFRpbWVvdXRCIEhvdyBsb25nIHRoZS'
    'Bub3RpZmljYXRpb24gbGFzdHMuUgpuYWdUaW1lb3V0EtgBChF1c2VfaTJzX2FzX2J1enplchgP'
    'IAEoCEKsAcrzGKcBOhFVc2UgSTJTIEFzIEJ1enplckKRAUVuYWJsZXMgZGV2aWNlcyB3aXRoIG'
    '5hdGl2ZSBJMlMgYXVkaW8gb3V0cHV0IHRvIHVzZSB0aGUgUlRUVEwgb3ZlciBzcGVha2VyIGxp'
    'a2UgYSBidXp6ZXIuIFQtV2F0Y2ggUzMgYW5kIFQtRGVjayBmb3IgZXhhbXBsZSBoYXZlIHRoaX'
    'MgY2FwYWJpbGl0eS5SDnVzZUkyc0FzQnV6emVyGoYGChJTdG9yZUZvcndhcmRDb25maWcSYAoH'
    'ZW5hYmxlZBgBIAEoCEJGyvMYQjoZU3RvcmUgYW5kIEZvcndhcmQgRW5hYmxlZEIlRW5hYmxlcy'
    'B0aGUgc3RvcmUgYW5kIGZvcndhcmQgbW9kdWxlLlIHZW5hYmxlZBJoCgloZWFydGJlYXQYAiAB'
    'KAhCSsrzGEY6DlNlbmQgSGVhcnRiZWF0QjRTZW5kIGEgaGVhcnRiZWF0IHRvIGFkdmVydGlzZS'
    'B0aGUgc2VydmVyJ3MgcHJlc2VuY2UuUgloZWFydGJlYXQSfAoHcmVjb3JkcxgDIAEoDUJiyvMY'
    'XjoRTnVtYmVyIG9mIHJlY29yZHNCSU1heGltdW0gbnVtYmVyIG9mIG1lc3NhZ2VzIHRvIHN0b3'
    'JlLiAwIHVzZXMgdGhyZWUgcXVhcnRlcnMgb2YgZnJlZSBQU1JBTS5SB3JlY29yZHMSigEKEmhp'
    'c3RvcnlfcmV0dXJuX21heBgEIAEoDUJcyvMYWDoSSGlzdG9yeSBSZXR1cm4gTWF4QkJNYXhpbX'
    'VtIG51bWJlciBvZiBzdG9yZWQgbWVzc2FnZXMgcmV0dXJuZWQgcGVyIHJlcXVlc3QuIDAgdXNl'
    'cyAyNS5SEGhpc3RvcnlSZXR1cm5NYXgSlAEKFWhpc3RvcnlfcmV0dXJuX3dpbmRvdxgFIAEoDU'
    'JgyvMYXDoVSGlzdG9yeSBSZXR1cm4gV2luZG93QkNIb3cgZmFyIGJhY2ssIGluIG1pbnV0ZXMs'
    'IHN0b3JlZCBtZXNzYWdlcyBhcmUgcmV0dXJuZWQuIDAgdXNlcyAyNDAuUhNoaXN0b3J5UmV0dX'
    'JuV2luZG93EoEBCglpc19zZXJ2ZXIYBiABKAhCZMrzGGA6BlNlcnZlckJWRW5hYmxlIHRoaXMg'
    'ZGV2aWNlIGFzIGEgU3RvcmUgYW5kIEZvcndhcmQgc2VydmVyLiBSZXF1aXJlcyBhbiBFU1AzMi'
    'BkZXZpY2Ugd2l0aCBQU1JBTS5SCGlzU2VydmVyGrUDCg9SYW5nZVRlc3RDb25maWcSTAoHZW5h'
    'YmxlZBgBIAEoCEIyyvMYLjoSUmFuZ2UgVGVzdCBFbmFibGVkQhhFbmFibGUgcmFuZ2UgdGVzdC'
    'Btb2R1bGVSB2VuYWJsZWQSjQEKBnNlbmRlchgCIAEoDUJ1yvMYcSoBczoPU2VuZGVyIEludGVy'
    'dmFsQltUaGlzIGRldmljZSB3aWxsIHNlbmQgb3V0IHJhbmdlIHRlc3QgbWVzc2FnZXMgb24gdG'
    'hlIHNlbGVjdGVkIGludGVydmFsLiAwIGRpc2FibGVzIHNlbmRpbmcuUgZzZW5kZXISjQEKBHNh'
    'dmUYAyABKAhCecrzGHU6BFNhdmVCbVNhdmVzIGEgQ1NWIHdpdGggdGhlIHJhbmdlIHRlc3QgbW'
    'Vzc2FnZSBkZXRhaWxzLCBjdXJyZW50bHkgb25seSBhdmFpbGFibGUgb24gRVNQMzIgZGV2aWNl'
    'cyB3aXRoIGEgd2ViIHNlcnZlci5SBHNhdmUSNAoPY2xlYXJfb25fcmVib290GAQgASgIQgzK8x'
    'gIUgYyLjcuMTFSDWNsZWFyT25SZWJvb3Qa4A4KD1RlbGVtZXRyeUNvbmZpZxKIAQoWZGV2aWNl'
    'X3VwZGF0ZV9pbnRlcnZhbBgBIAEoDUJSyvMYTioBczoXRGV2aWNlIE1ldHJpY3MgSW50ZXJ2YW'
    'xCMEhvdyBvZnRlbiBkZXZpY2UgbWV0cmljcyBhcmUgc2VudCBvdmVyIHRoZSBtZXNoLlIUZGV2'
    'aWNlVXBkYXRlSW50ZXJ2YWwSnAEKG2Vudmlyb25tZW50X3VwZGF0ZV9pbnRlcnZhbBgCIAEoDU'
    'JcyvMYWCoBczocRW52aXJvbm1lbnQgTWV0cmljcyBJbnRlcnZhbEI1SG93IG9mdGVuIGVudmly'
    'b25tZW50IG1ldHJpY3MgYXJlIHNlbnQgb3ZlciB0aGUgbWVzaC5SGWVudmlyb25tZW50VXBkYX'
    'RlSW50ZXJ2YWwSiwEKH2Vudmlyb25tZW50X21lYXN1cmVtZW50X2VuYWJsZWQYAyABKAhCQ8rz'
    'GD86G0Vudmlyb25tZW50IE1ldHJpY3MgRW5hYmxlZEIgQ29sbGVjdCBlbnZpcm9ubWVudCBtZW'
    'FzdXJlbWVudHNSHWVudmlyb25tZW50TWVhc3VyZW1lbnRFbmFibGVkEpEBChplbnZpcm9ubWVu'
    'dF9zY3JlZW5fZW5hYmxlZBgEIAEoCEJTyvMYTzohU2hvdyBlbnZpcm9ubWVudCBvbiBkZXZpY2'
    'Ugc2NyZWVuQipEaXNwbGF5IGVudmlyb25tZW50IG1lYXN1cmVtZW50cyBvbiBkZXZpY2VSGGVu'
    'dmlyb25tZW50U2NyZWVuRW5hYmxlZBKBAQoeZW52aXJvbm1lbnRfZGlzcGxheV9mYWhyZW5oZW'
    'l0GAUgASgIQjvK8xg3OhJEaXNwbGF5IEZhaHJlbmhlaXRCIURpc3BsYXkgZW52aXJvbm1lbnQg'
    'aW4gRmFocmVuaGVpdFIcZW52aXJvbm1lbnREaXNwbGF5RmFocmVuaGVpdBJuChNhaXJfcXVhbG'
    'l0eV9lbmFibGVkGAYgASgIQj7K8xg6OhtBaXIgUXVhbGl0eSBNZXRyaWNzIEVuYWJsZWRCG0Nv'
    'bGxlY3QgYWlyIHF1YWxpdHkgbWV0cmljc1IRYWlyUXVhbGl0eUVuYWJsZWQSjgEKFGFpcl9xdW'
    'FsaXR5X2ludGVydmFsGAcgASgNQlzK8xhYKgFzOhxBaXIgUXVhbGl0eSBNZXRyaWNzIEludGVy'
    'dmFsQjVIb3cgb2Z0ZW4gYWlyIHF1YWxpdHkgbWV0cmljcyBhcmUgc2VudCBvdmVyIHRoZSBtZX'
    'NoLlISYWlyUXVhbGl0eUludGVydmFsEnIKGXBvd2VyX21lYXN1cmVtZW50X2VuYWJsZWQYCCAB'
    'KAhCNsrzGDI6GVBvd2VyIE1lYXN1cmVtZW50IEVuYWJsZWRCFUNvbGxlY3QgcG93ZXIgbWV0cm'
    'ljc1IXcG93ZXJNZWFzdXJlbWVudEVuYWJsZWQShAEKFXBvd2VyX3VwZGF0ZV9pbnRlcnZhbBgJ'
    'IAEoDUJQyvMYTCoBczoWUG93ZXIgTWV0cmljcyBJbnRlcnZhbEIvSG93IG9mdGVuIHBvd2VyIG'
    '1ldHJpY3MgYXJlIHNlbnQgb3ZlciB0aGUgbWVzaC5SE3Bvd2VyVXBkYXRlSW50ZXJ2YWwSZQoU'
    'cG93ZXJfc2NyZWVuX2VuYWJsZWQYCiABKAhCM8rzGC86DFBvd2VyIFNjcmVlbkIfRGlzcGxheS'
    'Bwb3dlciBtZXRyaWNzIG9uIGRldmljZVIScG93ZXJTY3JlZW5FbmFibGVkEjwKGmhlYWx0aF9t'
    'ZWFzdXJlbWVudF9lbmFibGVkGAsgASgIUhhoZWFsdGhNZWFzdXJlbWVudEVuYWJsZWQSNAoWaG'
    'VhbHRoX3VwZGF0ZV9pbnRlcnZhbBgMIAEoDVIUaGVhbHRoVXBkYXRlSW50ZXJ2YWwSMgoVaGVh'
    'bHRoX3NjcmVlbl9lbmFibGVkGA0gASgIUhNoZWFsdGhTY3JlZW5FbmFibGVkEtYBChhkZXZpY2'
    'VfdGVsZW1ldHJ5X2VuYWJsZWQYDiABKAhCmwHK8xiWAToYQnJvYWRjYXN0IERldmljZSBNZXRy'
    'aWNzQnJFbmFibGUgYnJvYWRjYXN0aW5nIGRldmljZSBtZXRyaWNzIHRvIHRoZSBtZXNoIG5ldH'
    'dvcmsuIFdoZW4gZGlzYWJsZWQsIG1ldHJpY3MgYXJlIG9ubHkgc2VudCB0byBjb25uZWN0ZWQg'
    'Y2xpZW50cy5SBjIuNy4xM1IWZGV2aWNlVGVsZW1ldHJ5RW5hYmxlZBKYAQoaYWlyX3F1YWxpdH'
    'lfc2NyZWVuX2VuYWJsZWQYDyABKAhCW8rzGFc6IVNob3cgYWlyIHF1YWxpdHkgb24gZGV2aWNl'
    'IHNjcmVlbkIqRGlzcGxheSBhaXIgcXVhbGl0eSBtZWFzdXJlbWVudHMgb24gZGV2aWNlUgYyLj'
    'cuMThSF2FpclF1YWxpdHlTY3JlZW5FbmFibGVkGpsLChNDYW5uZWRNZXNzYWdlQ29uZmlnElQK'
    'D3JvdGFyeTFfZW5hYmxlZBgBIAEoCEIryvMYJzoOUm90YXJ5IEVuY29kZXJCFUVuYWJsZSByb3'
    'RhcnkgZW5jb2RlclIOcm90YXJ5MUVuYWJsZWQSXAoRaW5wdXRicm9rZXJfcGluX2EYAiABKA1C'
    'MMrzGCw6BVBpbiBBQiNHUElPIHBpbiBmb3Igcm90YXJ5IGVuY29kZXIgQSBwb3J0LlIPaW5wdX'
    'Ricm9rZXJQaW5BElwKEWlucHV0YnJva2VyX3Bpbl9iGAMgASgNQjDK8xgsOgVQaW4gQkIjR1BJ'
    'TyBwaW4gZm9yIHJvdGFyeSBlbmNvZGVyIEIgcG9ydC5SD2lucHV0YnJva2VyUGluQhJrChVpbn'
    'B1dGJyb2tlcl9waW5fcHJlc3MYBCABKA1CN8rzGDM6CVByZXNzIFBpbkImR1BJTyBwaW4gZm9y'
    'IHRoZSBlbmNvZGVyIHByZXNzIGJ1dHRvbi5SE2lucHV0YnJva2VyUGluUHJlc3MSrwEKFGlucH'
    'V0YnJva2VyX2V2ZW50X2N3GAUgASgOMjsubWVzaHRhc3RpYy5Nb2R1bGVDb25maWcuQ2FubmVk'
    'TWVzc2FnZUNvbmZpZy5JbnB1dEV2ZW50Q2hhckJAyvMYPDoWQ2xvY2t3aXNlIFJvdGFyeSBFdm'
    'VudEIiSW5wdXQgZXZlbnQgZm9yIGNsb2Nrd2lzZSByb3RhdGlvblISaW5wdXRicm9rZXJFdmVu'
    'dEN3EsABChVpbnB1dGJyb2tlcl9ldmVudF9jY3cYBiABKA4yOy5tZXNodGFzdGljLk1vZHVsZU'
    'NvbmZpZy5DYW5uZWRNZXNzYWdlQ29uZmlnLklucHV0RXZlbnRDaGFyQk/K8xhLOh1Db3VudGVy'
    'Y2xvY2t3aXNlIFJvdGFyeSBFdmVudEIqSW5wdXQgZXZlbnQgZm9yIGNvdW50ZXItY2xvY2t3aX'
    'NlIHJvdGF0aW9uUhNpbnB1dGJyb2tlckV2ZW50Q2N3Eq0BChdpbnB1dGJyb2tlcl9ldmVudF9w'
    'cmVzcxgHIAEoDjI7Lm1lc2h0YXN0aWMuTW9kdWxlQ29uZmlnLkNhbm5lZE1lc3NhZ2VDb25maW'
    'cuSW5wdXRFdmVudENoYXJCOMrzGDQ6E0VuY29kZXIgUHJlc3MgRXZlbnRCHUlucHV0IGV2ZW50'
    'IGZvciBlbmNvZGVyIHByZXNzUhVpbnB1dGJyb2tlckV2ZW50UHJlc3MSYAoPdXBkb3duMV9lbm'
    'FibGVkGAggASgIQjfK8xgzOhRVcC9Eb3duL1NlbGVjdCBJbnB1dEIbRW5hYmxlIHVwL2Rvd24v'
    'c2VsZWN0IGlucHV0Ug51cGRvd24xRW5hYmxlZBInCgdlbmFibGVkGAkgASgIQg0YAcrzGAdaBT'
    'IuNy4wUgdlbmFibGVkEjsKEmFsbG93X2lucHV0X3NvdXJjZRgKIAEoCUINGAHK8xgHWgUyLjcu'
    'MFIQYWxsb3dJbnB1dFNvdXJjZRJPCglzZW5kX2JlbGwYCyABKAhCMsrzGC46CVNlbmQgQmVsbE'
    'IhU2VuZCBiZWxsIGNoYXJhY3RlciB3aXRoIG1lc3NhZ2VzUghzZW5kQmVsbCLGAQoOSW5wdXRF'
    'dmVudENoYXISFAoETk9ORRAAGgrK8xgGOgROb25lEhAKAlVQEBEaCMrzGAQ6AlVwEhQKBERPV0'
    '4QEhoKyvMYBjoERG93bhIUCgRMRUZUEBMaCsrzGAY6BExlZnQSFgoFUklHSFQQFBoLyvMYBzoF'
    'UmlnaHQSGAoGU0VMRUNUEAoaDMrzGAg6BlNlbGVjdBIUCgRCQUNLEBsaCsrzGAY6BEJhY2sSGA'
    'oGQ0FOQ0VMEBgaDMrzGAg6BkNhbmNlbBr4BAoVQW1iaWVudExpZ2h0aW5nQ29uZmlnEksKCWxl'
    'ZF9zdGF0ZRgBIAEoCEIuyvMYKjoJTEVEIFN0YXRlQh1UaGUgc3RhdGUgb2YgdGhlIExFRCAob2'
    '4vb2ZmKVIIbGVkU3RhdGUSfQoHY3VycmVudBgCIAEoDUJjyvMYXxkAAAAAAAAAACEAAAAAAAA/'
    'QDoHQ3VycmVudEIhRHJpdmUgY3VycmVudCBmb3IgdGhlIExFRCBvdXRwdXQuSh9sZWR8YnJpZ2'
    'h0bmVzc3xhbWJpZW50fGxpZ2h0aW5nUgdjdXJyZW50EoABCgNyZWQYAyABKA1CbsrzGGoZAAAA'
    'AAAAAAAhAAAAAADgb0A6A1JlZEIqVGhlIHJlZCBsZXZlbCBvZiB0aGUgYW1iaWVudCBsaWdodG'
    'luZyBMRUQuSiVjb2xvcnxjb2xvdXJ8cmdifGxlZHxhbWJpZW50fGxpZ2h0aW5nUgNyZWQSiAEK'
    'BWdyZWVuGAQgASgNQnLK8xhuGQAAAAAAAAAAIQAAAAAA4G9AOgVHcmVlbkIsVGhlIGdyZWVuIG'
    'xldmVsIG9mIHRoZSBhbWJpZW50IGxpZ2h0aW5nIExFRC5KJWNvbG9yfGNvbG91cnxyZ2J8bGVk'
    'fGFtYmllbnR8bGlnaHRpbmdSBWdyZWVuEoQBCgRibHVlGAUgASgNQnDK8xhsGQAAAAAAAAAAIQ'
    'AAAAAA4G9AOgRCbHVlQitUaGUgYmx1ZSBsZXZlbCBvZiB0aGUgYW1iaWVudCBsaWdodGluZyBM'
    'RUQuSiVjb2xvcnxjb2xvdXJ8cmdifGxlZHxhbWJpZW50fGxpZ2h0aW5nUgRibHVlGjYKE1N0YX'
    'R1c01lc3NhZ2VDb25maWcSHwoLbm9kZV9zdGF0dXMYASABKAlSCm5vZGVTdGF0dXMangoKEE1l'
    'c2hCZWFjb25Db25maWcSFAoFZmxhZ3MYASABKA1SBWZsYWdzEkgKHmJyb2FkY2FzdF9vZmZlcl'
    '9mcmVxdWVuY3lfc2xvdBgCIAEoDUgAUhticm9hZGNhc3RPZmZlckZyZXF1ZW5jeVNsb3SIAQES'
    'agoRYnJvYWRjYXN0X21lc3NhZ2UYBCABKAlCPcrzGDk6B01lc3NhZ2VCLk1lc3NhZ2UgZm9yIG'
    'JlYWNvbiBicm9hZGNhc3RzLCB1cCB0byA2MCBieXRlcy5SEGJyb2FkY2FzdE1lc3NhZ2USUwoX'
    'YnJvYWRjYXN0X29mZmVyX2NoYW5uZWwYBSABKAsyGy5tZXNodGFzdGljLkNoYW5uZWxTZXR0aW'
    '5nc1IVYnJvYWRjYXN0T2ZmZXJDaGFubmVsEl4KFmJyb2FkY2FzdF9vZmZlcl9yZWdpb24YBiAB'
    'KA4yKC5tZXNodGFzdGljLkNvbmZpZy5Mb1JhQ29uZmlnLlJlZ2lvbkNvZGVSFGJyb2FkY2FzdE'
    '9mZmVyUmVnaW9uEmQKFmJyb2FkY2FzdF9vZmZlcl9wcmVzZXQYByABKA4yKS5tZXNodGFzdGlj'
    'LkNvbmZpZy5Mb1JhQ29uZmlnLk1vZGVtUHJlc2V0SAFSFGJyb2FkY2FzdE9mZmVyUHJlc2V0iA'
    'EBEoQBChdicm9hZGNhc3RfaW50ZXJ2YWxfc2VjcxgLIAEoDUJMyvMYSBkAAAAAACCsQCoBczoI'
    'SW50ZXJ2YWxCMEhvdyBvZnRlbiBhIGJlYWNvbiBpcyBicm9hZGNhc3QuIE1pbmltdW0gMSBob3'
    'VyLlIVYnJvYWRjYXN0SW50ZXJ2YWxTZWNzEmYKEWJyb2FkY2FzdF90YXJnZXRzGA0gAygLMjku'
    'bWVzaHRhc3RpYy5Nb2R1bGVDb25maWcuTWVzaEJlYWNvbkNvbmZpZy5Ccm9hZGNhc3RUYXJnZX'
    'RSEGJyb2FkY2FzdFRhcmdldHMaoQIKD0Jyb2FkY2FzdFRhcmdldBJGCgZwcmVzZXQYASABKA4y'
    'KS5tZXNodGFzdGljLkNvbmZpZy5Mb1JhQ29uZmlnLk1vZGVtUHJlc2V0SABSBnByZXNldIgBAR'
    'JACgZyZWdpb24YAiABKA4yKC5tZXNodGFzdGljLkNvbmZpZy5Mb1JhQ29uZmlnLlJlZ2lvbkNv'
    'ZGVSBnJlZ2lvbhIoCg1jaGFubmVsX2luZGV4GAQgASgNSAFSDGNoYW5uZWxJbmRleIgBARIqCg'
    '5mcmVxdWVuY3lfc2xvdBgFIAEoDUgCUg1mcmVxdWVuY3lTbG90iAEBQgkKB19wcmVzZXRCEAoO'
    'X2NoYW5uZWxfaW5kZXhCEQoPX2ZyZXF1ZW5jeV9zbG90ImIKBUZsYWdzEg0KCUZMQUdfTk9ORR'
    'AAEhcKE0ZMQUdfTElTVEVOX0VOQUJMRUQQARIaChZGTEFHX0JST0FEQ0FTVF9FTkFCTEVEEAIS'
    'FQoRRkxBR19MRUdBQ1lfU1BMSVQQBEIhCh9fYnJvYWRjYXN0X29mZmVyX2ZyZXF1ZW5jeV9zbG'
    '90QhkKF19icm9hZGNhc3Rfb2ZmZXJfcHJlc2V0SgQIAxAESgQICBAJSgQICRAKSgQIChALUhZi'
    'cm9hZGNhc3Rfc2VuZF9hc19ub2RlUhRicm9hZGNhc3Rfb25fY2hhbm5lbFITYnJvYWRjYXN0X2'
    '9uX3JlZ2lvblITYnJvYWRjYXN0X29uX3ByZXNldBqWAQoJVEFLQ29uZmlnEkAKBHRlYW0YASAB'
    'KA4yEC5tZXNodGFzdGljLlRlYW1CGsrzGBY6BFRlYW1CDlRBSyB0ZWFtIGNvbG9yUgR0ZWFtEk'
    'cKBHJvbGUYAiABKA4yFi5tZXNodGFzdGljLk1lbWJlclJvbGVCG8rzGBc6BFJvbGVCD1RBSyBt'
    'ZW1iZXIgcm9sZVIEcm9sZUIRCg9wYXlsb2FkX3ZhcmlhbnQ=');

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
