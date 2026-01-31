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
  ],
  '3': [
    ModuleConfig_MQTTConfig$json,
    ModuleConfig_MapReportSettings$json,
    ModuleConfig_RemoteHardwareConfig$json,
    ModuleConfig_NeighborInfoConfig$json,
    ModuleConfig_DetectionSensorConfig$json,
    ModuleConfig_AudioConfig$json,
    ModuleConfig_PaxcounterConfig$json,
    ModuleConfig_SerialConfig$json,
    ModuleConfig_ExternalNotificationConfig$json,
    ModuleConfig_StoreForwardConfig$json,
    ModuleConfig_RangeTestConfig$json,
    ModuleConfig_TelemetryConfig$json,
    ModuleConfig_CannedMessageConfig$json,
    ModuleConfig_AmbientLightingConfig$json,
    ModuleConfig_StatusMessageConfig$json
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
    {'1': 'json_enabled', '3': 6, '4': 1, '5': 8, '10': 'jsonEnabled'},
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
    'bmZpZy5TdGF0dXNNZXNzYWdlQ29uZmlnSABSDXN0YXR1c21lc3NhZ2UaxgMKCk1RVFRDb25maW'
    'cSGAoHZW5hYmxlZBgBIAEoCFIHZW5hYmxlZBIYCgdhZGRyZXNzGAIgASgJUgdhZGRyZXNzEhoK'
    'CHVzZXJuYW1lGAMgASgJUgh1c2VybmFtZRIaCghwYXNzd29yZBgEIAEoCVIIcGFzc3dvcmQSLQ'
    'oSZW5jcnlwdGlvbl9lbmFibGVkGAUgASgIUhFlbmNyeXB0aW9uRW5hYmxlZBIhCgxqc29uX2Vu'
    'YWJsZWQYBiABKAhSC2pzb25FbmFibGVkEh8KC3Rsc19lbmFibGVkGAcgASgIUgp0bHNFbmFibG'
    'VkEhIKBHJvb3QYCCABKAlSBHJvb3QSNQoXcHJveHlfdG9fY2xpZW50X2VuYWJsZWQYCSABKAhS'
    'FHByb3h5VG9DbGllbnRFbmFibGVkEjIKFW1hcF9yZXBvcnRpbmdfZW5hYmxlZBgKIAEoCFITbW'
    'FwUmVwb3J0aW5nRW5hYmxlZBJaChNtYXBfcmVwb3J0X3NldHRpbmdzGAsgASgLMioubWVzaHRh'
    'c3RpYy5Nb2R1bGVDb25maWcuTWFwUmVwb3J0U2V0dGluZ3NSEW1hcFJlcG9ydFNldHRpbmdzGq'
    'wBChFNYXBSZXBvcnRTZXR0aW5ncxIyChVwdWJsaXNoX2ludGVydmFsX3NlY3MYASABKA1SE3B1'
    'Ymxpc2hJbnRlcnZhbFNlY3MSLQoScG9zaXRpb25fcHJlY2lzaW9uGAIgASgNUhFwb3NpdGlvbl'
    'ByZWNpc2lvbhI0ChZzaG91bGRfcmVwb3J0X2xvY2F0aW9uGAMgASgIUhRzaG91bGRSZXBvcnRM'
    'b2NhdGlvbhqzAQoUUmVtb3RlSGFyZHdhcmVDb25maWcSGAoHZW5hYmxlZBgBIAEoCFIHZW5hYm'
    'xlZBI7ChphbGxvd191bmRlZmluZWRfcGluX2FjY2VzcxgCIAEoCFIXYWxsb3dVbmRlZmluZWRQ'
    'aW5BY2Nlc3MSRAoOYXZhaWxhYmxlX3BpbnMYAyADKAsyHS5tZXNodGFzdGljLlJlbW90ZUhhcm'
    'R3YXJlUGluUg1hdmFpbGFibGVQaW5zGoUBChJOZWlnaGJvckluZm9Db25maWcSGAoHZW5hYmxl'
    'ZBgBIAEoCFIHZW5hYmxlZBInCg91cGRhdGVfaW50ZXJ2YWwYAiABKA1SDnVwZGF0ZUludGVydm'
    'FsEiwKEnRyYW5zbWl0X292ZXJfbG9yYRgDIAEoCFIQdHJhbnNtaXRPdmVyTG9yYRqHBAoVRGV0'
    'ZWN0aW9uU2Vuc29yQ29uZmlnEhgKB2VuYWJsZWQYASABKAhSB2VuYWJsZWQSNAoWbWluaW11bV'
    '9icm9hZGNhc3Rfc2VjcxgCIAEoDVIUbWluaW11bUJyb2FkY2FzdFNlY3MSMAoUc3RhdGVfYnJv'
    'YWRjYXN0X3NlY3MYAyABKA1SEnN0YXRlQnJvYWRjYXN0U2VjcxIbCglzZW5kX2JlbGwYBCABKA'
    'hSCHNlbmRCZWxsEhIKBG5hbWUYBSABKAlSBG5hbWUSHwoLbW9uaXRvcl9waW4YBiABKA1SCm1v'
    'bml0b3JQaW4ScAoWZGV0ZWN0aW9uX3RyaWdnZXJfdHlwZRgHIAEoDjI6Lm1lc2h0YXN0aWMuTW'
    '9kdWxlQ29uZmlnLkRldGVjdGlvblNlbnNvckNvbmZpZy5UcmlnZ2VyVHlwZVIUZGV0ZWN0aW9u'
    'VHJpZ2dlclR5cGUSHQoKdXNlX3B1bGx1cBgIIAEoCFIJdXNlUHVsbHVwIogBCgtUcmlnZ2VyVH'
    'lwZRINCglMT0dJQ19MT1cQABIOCgpMT0dJQ19ISUdIEAESEAoMRkFMTElOR19FREdFEAISDwoL'
    'UklTSU5HX0VER0UQAxIaChZFSVRIRVJfRURHRV9BQ1RJVkVfTE9XEAQSGwoXRUlUSEVSX0VER0'
    'VfQUNUSVZFX0hJR0gQBRqiAwoLQXVkaW9Db25maWcSJQoOY29kZWMyX2VuYWJsZWQYASABKAhS'
    'DWNvZGVjMkVuYWJsZWQSFwoHcHR0X3BpbhgCIAEoDVIGcHR0UGluEkkKB2JpdHJhdGUYAyABKA'
    '4yLy5tZXNodGFzdGljLk1vZHVsZUNvbmZpZy5BdWRpb0NvbmZpZy5BdWRpb19CYXVkUgdiaXRy'
    'YXRlEhUKBmkyc193cxgEIAEoDVIFaTJzV3MSFQoGaTJzX3NkGAUgASgNUgVpMnNTZBIXCgdpMn'
    'NfZGluGAYgASgNUgZpMnNEaW4SFwoHaTJzX3NjaxgHIAEoDVIGaTJzU2NrIqcBCgpBdWRpb19C'
    'YXVkEhIKDkNPREVDMl9ERUZBVUxUEAASDwoLQ09ERUMyXzMyMDAQARIPCgtDT0RFQzJfMjQwMB'
    'ACEg8KC0NPREVDMl8xNjAwEAMSDwoLQ09ERUMyXzE0MDAQBBIPCgtDT0RFQzJfMTMwMBAFEg8K'
    'C0NPREVDMl8xMjAwEAYSDgoKQ09ERUMyXzcwMBAHEg8KC0NPREVDMl83MDBCEAgatgEKEFBheG'
    'NvdW50ZXJDb25maWcSGAoHZW5hYmxlZBgBIAEoCFIHZW5hYmxlZBI8ChpwYXhjb3VudGVyX3Vw'
    'ZGF0ZV9pbnRlcnZhbBgCIAEoDVIYcGF4Y291bnRlclVwZGF0ZUludGVydmFsEiUKDndpZmlfdG'
    'hyZXNob2xkGAMgASgFUg13aWZpVGhyZXNob2xkEiMKDWJsZV90aHJlc2hvbGQYBCABKAVSDGJs'
    'ZVRocmVzaG9sZBrsBQoMU2VyaWFsQ29uZmlnEhgKB2VuYWJsZWQYASABKAhSB2VuYWJsZWQSEg'
    'oEZWNobxgCIAEoCFIEZWNobxIQCgNyeGQYAyABKA1SA3J4ZBIQCgN0eGQYBCABKA1SA3R4ZBJF'
    'CgRiYXVkGAUgASgOMjEubWVzaHRhc3RpYy5Nb2R1bGVDb25maWcuU2VyaWFsQ29uZmlnLlNlcm'
    'lhbF9CYXVkUgRiYXVkEhgKB3RpbWVvdXQYBiABKA1SB3RpbWVvdXQSRQoEbW9kZRgHIAEoDjIx'
    'Lm1lc2h0YXN0aWMuTW9kdWxlQ29uZmlnLlNlcmlhbENvbmZpZy5TZXJpYWxfTW9kZVIEbW9kZR'
    'I/ChxvdmVycmlkZV9jb25zb2xlX3NlcmlhbF9wb3J0GAggASgIUhlvdmVycmlkZUNvbnNvbGVT'
    'ZXJpYWxQb3J0IooCCgtTZXJpYWxfQmF1ZBIQCgxCQVVEX0RFRkFVTFQQABIMCghCQVVEXzExMB'
    'ABEgwKCEJBVURfMzAwEAISDAoIQkFVRF82MDAQAxINCglCQVVEXzEyMDAQBBINCglCQVVEXzI0'
    'MDAQBRINCglCQVVEXzQ4MDAQBhINCglCQVVEXzk2MDAQBxIOCgpCQVVEXzE5MjAwEAgSDgoKQk'
    'FVRF8zODQwMBAJEg4KCkJBVURfNTc2MDAQChIPCgtCQVVEXzExNTIwMBALEg8KC0JBVURfMjMw'
    'NDAwEAwSDwoLQkFVRF80NjA4MDAQDRIPCgtCQVVEXzU3NjAwMBAOEg8KC0JBVURfOTIxNjAwEA'
    '8ikwEKC1NlcmlhbF9Nb2RlEgsKB0RFRkFVTFQQABIKCgZTSU1QTEUQARIJCgVQUk9UTxACEgsK'
    'B1RFWFRNU0cQAxIICgROTUVBEAQSCwoHQ0FMVE9QTxAFEggKBFdTODUQBhINCglWRV9ESVJFQ1'
    'QQBxINCglNU19DT05GSUcQCBIHCgNMT0cQCRILCgdMT0dURVhUEAoarAQKGkV4dGVybmFsTm90'
    'aWZpY2F0aW9uQ29uZmlnEhgKB2VuYWJsZWQYASABKAhSB2VuYWJsZWQSGwoJb3V0cHV0X21zGA'
    'IgASgNUghvdXRwdXRNcxIWCgZvdXRwdXQYAyABKA1SBm91dHB1dBIhCgxvdXRwdXRfdmlicmEY'
    'CCABKA1SC291dHB1dFZpYnJhEiMKDW91dHB1dF9idXp6ZXIYCSABKA1SDG91dHB1dEJ1enplch'
    'IWCgZhY3RpdmUYBCABKAhSBmFjdGl2ZRIjCg1hbGVydF9tZXNzYWdlGAUgASgIUgxhbGVydE1l'
    'c3NhZ2USLgoTYWxlcnRfbWVzc2FnZV92aWJyYRgKIAEoCFIRYWxlcnRNZXNzYWdlVmlicmESMA'
    'oUYWxlcnRfbWVzc2FnZV9idXp6ZXIYCyABKAhSEmFsZXJ0TWVzc2FnZUJ1enplchIdCgphbGVy'
    'dF9iZWxsGAYgASgIUglhbGVydEJlbGwSKAoQYWxlcnRfYmVsbF92aWJyYRgMIAEoCFIOYWxlcn'
    'RCZWxsVmlicmESKgoRYWxlcnRfYmVsbF9idXp6ZXIYDSABKAhSD2FsZXJ0QmVsbEJ1enplchIX'
    'Cgd1c2VfcHdtGAcgASgIUgZ1c2VQd20SHwoLbmFnX3RpbWVvdXQYDiABKA1SCm5hZ1RpbWVvdX'
    'QSKQoRdXNlX2kyc19hc19idXp6ZXIYDyABKAhSDnVzZUkyc0FzQnV6emVyGuUBChJTdG9yZUZv'
    'cndhcmRDb25maWcSGAoHZW5hYmxlZBgBIAEoCFIHZW5hYmxlZBIcCgloZWFydGJlYXQYAiABKA'
    'hSCWhlYXJ0YmVhdBIYCgdyZWNvcmRzGAMgASgNUgdyZWNvcmRzEiwKEmhpc3RvcnlfcmV0dXJu'
    'X21heBgEIAEoDVIQaGlzdG9yeVJldHVybk1heBIyChVoaXN0b3J5X3JldHVybl93aW5kb3cYBS'
    'ABKA1SE2hpc3RvcnlSZXR1cm5XaW5kb3cSGwoJaXNfc2VydmVyGAYgASgIUghpc1NlcnZlchp/'
    'Cg9SYW5nZVRlc3RDb25maWcSGAoHZW5hYmxlZBgBIAEoCFIHZW5hYmxlZBIWCgZzZW5kZXIYAi'
    'ABKA1SBnNlbmRlchISCgRzYXZlGAMgASgIUgRzYXZlEiYKD2NsZWFyX29uX3JlYm9vdBgEIAEo'
    'CFINY2xlYXJPblJlYm9vdBr2BgoPVGVsZW1ldHJ5Q29uZmlnEjQKFmRldmljZV91cGRhdGVfaW'
    '50ZXJ2YWwYASABKA1SFGRldmljZVVwZGF0ZUludGVydmFsEj4KG2Vudmlyb25tZW50X3VwZGF0'
    'ZV9pbnRlcnZhbBgCIAEoDVIZZW52aXJvbm1lbnRVcGRhdGVJbnRlcnZhbBJGCh9lbnZpcm9ubW'
    'VudF9tZWFzdXJlbWVudF9lbmFibGVkGAMgASgIUh1lbnZpcm9ubWVudE1lYXN1cmVtZW50RW5h'
    'YmxlZBI8ChplbnZpcm9ubWVudF9zY3JlZW5fZW5hYmxlZBgEIAEoCFIYZW52aXJvbm1lbnRTY3'
    'JlZW5FbmFibGVkEkQKHmVudmlyb25tZW50X2Rpc3BsYXlfZmFocmVuaGVpdBgFIAEoCFIcZW52'
    'aXJvbm1lbnREaXNwbGF5RmFocmVuaGVpdBIuChNhaXJfcXVhbGl0eV9lbmFibGVkGAYgASgIUh'
    'FhaXJRdWFsaXR5RW5hYmxlZBIwChRhaXJfcXVhbGl0eV9pbnRlcnZhbBgHIAEoDVISYWlyUXVh'
    'bGl0eUludGVydmFsEjoKGXBvd2VyX21lYXN1cmVtZW50X2VuYWJsZWQYCCABKAhSF3Bvd2VyTW'
    'Vhc3VyZW1lbnRFbmFibGVkEjIKFXBvd2VyX3VwZGF0ZV9pbnRlcnZhbBgJIAEoDVITcG93ZXJV'
    'cGRhdGVJbnRlcnZhbBIwChRwb3dlcl9zY3JlZW5fZW5hYmxlZBgKIAEoCFIScG93ZXJTY3JlZW'
    '5FbmFibGVkEjwKGmhlYWx0aF9tZWFzdXJlbWVudF9lbmFibGVkGAsgASgIUhhoZWFsdGhNZWFz'
    'dXJlbWVudEVuYWJsZWQSNAoWaGVhbHRoX3VwZGF0ZV9pbnRlcnZhbBgMIAEoDVIUaGVhbHRoVX'
    'BkYXRlSW50ZXJ2YWwSMgoVaGVhbHRoX3NjcmVlbl9lbmFibGVkGA0gASgIUhNoZWFsdGhTY3Jl'
    'ZW5FbmFibGVkEjgKGGRldmljZV90ZWxlbWV0cnlfZW5hYmxlZBgOIAEoCFIWZGV2aWNlVGVsZW'
    '1ldHJ5RW5hYmxlZBI7ChphaXJfcXVhbGl0eV9zY3JlZW5fZW5hYmxlZBgPIAEoCFIXYWlyUXVh'
    'bGl0eVNjcmVlbkVuYWJsZWQamgYKE0Nhbm5lZE1lc3NhZ2VDb25maWcSJwoPcm90YXJ5MV9lbm'
    'FibGVkGAEgASgIUg5yb3RhcnkxRW5hYmxlZBIqChFpbnB1dGJyb2tlcl9waW5fYRgCIAEoDVIP'
    'aW5wdXRicm9rZXJQaW5BEioKEWlucHV0YnJva2VyX3Bpbl9iGAMgASgNUg9pbnB1dGJyb2tlcl'
    'BpbkISMgoVaW5wdXRicm9rZXJfcGluX3ByZXNzGAQgASgNUhNpbnB1dGJyb2tlclBpblByZXNz'
    'Em0KFGlucHV0YnJva2VyX2V2ZW50X2N3GAUgASgOMjsubWVzaHRhc3RpYy5Nb2R1bGVDb25maW'
    'cuQ2FubmVkTWVzc2FnZUNvbmZpZy5JbnB1dEV2ZW50Q2hhclISaW5wdXRicm9rZXJFdmVudEN3'
    'Em8KFWlucHV0YnJva2VyX2V2ZW50X2NjdxgGIAEoDjI7Lm1lc2h0YXN0aWMuTW9kdWxlQ29uZm'
    'lnLkNhbm5lZE1lc3NhZ2VDb25maWcuSW5wdXRFdmVudENoYXJSE2lucHV0YnJva2VyRXZlbnRD'
    'Y3cScwoXaW5wdXRicm9rZXJfZXZlbnRfcHJlc3MYByABKA4yOy5tZXNodGFzdGljLk1vZHVsZU'
    'NvbmZpZy5DYW5uZWRNZXNzYWdlQ29uZmlnLklucHV0RXZlbnRDaGFyUhVpbnB1dGJyb2tlckV2'
    'ZW50UHJlc3MSJwoPdXBkb3duMV9lbmFibGVkGAggASgIUg51cGRvd24xRW5hYmxlZBIcCgdlbm'
    'FibGVkGAkgASgIQgIYAVIHZW5hYmxlZBIwChJhbGxvd19pbnB1dF9zb3VyY2UYCiABKAlCAhgB'
    'UhBhbGxvd0lucHV0U291cmNlEhsKCXNlbmRfYmVsbBgLIAEoCFIIc2VuZEJlbGwiYwoOSW5wdX'
    'RFdmVudENoYXISCAoETk9ORRAAEgYKAlVQEBESCAoERE9XThASEggKBExFRlQQExIJCgVSSUdI'
    'VBAUEgoKBlNFTEVDVBAKEggKBEJBQ0sQGxIKCgZDQU5DRUwQGBqKAQoVQW1iaWVudExpZ2h0aW'
    '5nQ29uZmlnEhsKCWxlZF9zdGF0ZRgBIAEoCFIIbGVkU3RhdGUSGAoHY3VycmVudBgCIAEoDVIH'
    'Y3VycmVudBIQCgNyZWQYAyABKA1SA3JlZBIUCgVncmVlbhgEIAEoDVIFZ3JlZW4SEgoEYmx1ZR'
    'gFIAEoDVIEYmx1ZRo2ChNTdGF0dXNNZXNzYWdlQ29uZmlnEh8KC25vZGVfc3RhdHVzGAEgASgJ'
    'Ugpub2RlU3RhdHVzQhEKD3BheWxvYWRfdmFyaWFudA==');

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
