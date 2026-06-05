// This is a generated file - do not edit.
//
// Generated from meshtastic/atak.proto.

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

@$core.Deprecated('Use teamDescriptor instead')
const Team$json = {
  '1': 'Team',
  '2': [
    {'1': 'Unspecifed_Color', '2': 0},
    {'1': 'White', '2': 1},
    {'1': 'Yellow', '2': 2},
    {'1': 'Orange', '2': 3},
    {'1': 'Magenta', '2': 4},
    {'1': 'Red', '2': 5},
    {'1': 'Maroon', '2': 6},
    {'1': 'Purple', '2': 7},
    {'1': 'Dark_Blue', '2': 8},
    {'1': 'Blue', '2': 9},
    {'1': 'Cyan', '2': 10},
    {'1': 'Teal', '2': 11},
    {'1': 'Green', '2': 12},
    {'1': 'Dark_Green', '2': 13},
    {'1': 'Brown', '2': 14},
  ],
};

/// Descriptor for `Team`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List teamDescriptor = $convert.base64Decode(
    'CgRUZWFtEhQKEFVuc3BlY2lmZWRfQ29sb3IQABIJCgVXaGl0ZRABEgoKBlllbGxvdxACEgoKBk'
    '9yYW5nZRADEgsKB01hZ2VudGEQBBIHCgNSZWQQBRIKCgZNYXJvb24QBhIKCgZQdXJwbGUQBxIN'
    'CglEYXJrX0JsdWUQCBIICgRCbHVlEAkSCAoEQ3lhbhAKEggKBFRlYWwQCxIJCgVHcmVlbhAMEg'
    '4KCkRhcmtfR3JlZW4QDRIJCgVCcm93bhAO');

@$core.Deprecated('Use memberRoleDescriptor instead')
const MemberRole$json = {
  '1': 'MemberRole',
  '2': [
    {'1': 'Unspecifed', '2': 0},
    {'1': 'TeamMember', '2': 1},
    {'1': 'TeamLead', '2': 2},
    {'1': 'HQ', '2': 3},
    {'1': 'Sniper', '2': 4},
    {'1': 'Medic', '2': 5},
    {'1': 'ForwardObserver', '2': 6},
    {'1': 'RTO', '2': 7},
    {'1': 'K9', '2': 8},
  ],
};

/// Descriptor for `MemberRole`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List memberRoleDescriptor = $convert.base64Decode(
    'CgpNZW1iZXJSb2xlEg4KClVuc3BlY2lmZWQQABIOCgpUZWFtTWVtYmVyEAESDAoIVGVhbUxlYW'
    'QQAhIGCgJIURADEgoKBlNuaXBlchAEEgkKBU1lZGljEAUSEwoPRm9yd2FyZE9ic2VydmVyEAYS'
    'BwoDUlRPEAcSBgoCSzkQCA==');

@$core.Deprecated('Use cotHowDescriptor instead')
const CotHow$json = {
  '1': 'CotHow',
  '2': [
    {'1': 'CotHow_Unspecified', '2': 0},
    {'1': 'CotHow_h_e', '2': 1},
    {'1': 'CotHow_m_g', '2': 2},
    {'1': 'CotHow_h_g_i_g_o', '2': 3},
    {'1': 'CotHow_m_r', '2': 4},
    {'1': 'CotHow_m_f', '2': 5},
    {'1': 'CotHow_m_p', '2': 6},
    {'1': 'CotHow_m_s', '2': 7},
  ],
};

/// Descriptor for `CotHow`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List cotHowDescriptor = $convert.base64Decode(
    'CgZDb3RIb3cSFgoSQ290SG93X1Vuc3BlY2lmaWVkEAASDgoKQ290SG93X2hfZRABEg4KCkNvdE'
    'hvd19tX2cQAhIUChBDb3RIb3dfaF9nX2lfZ19vEAMSDgoKQ290SG93X21fchAEEg4KCkNvdEhv'
    'd19tX2YQBRIOCgpDb3RIb3dfbV9wEAYSDgoKQ290SG93X21fcxAH');

@$core.Deprecated('Use cotTypeDescriptor instead')
const CotType$json = {
  '1': 'CotType',
  '2': [
    {'1': 'CotType_Other', '2': 0},
    {'1': 'CotType_a_f_G_U_C', '2': 1},
    {'1': 'CotType_a_f_G_U_C_I', '2': 2},
    {'1': 'CotType_a_n_A_C_F', '2': 3},
    {'1': 'CotType_a_n_A_C_H', '2': 4},
    {'1': 'CotType_a_n_A_C', '2': 5},
    {'1': 'CotType_a_f_A_M_H', '2': 6},
    {'1': 'CotType_a_f_A_M', '2': 7},
    {'1': 'CotType_a_f_A_M_F_F', '2': 8},
    {'1': 'CotType_a_f_A_M_H_A', '2': 9},
    {'1': 'CotType_a_f_A_M_H_U_M', '2': 10},
    {'1': 'CotType_a_h_A_M_F_F', '2': 11},
    {'1': 'CotType_a_h_A_M_H_A', '2': 12},
    {'1': 'CotType_a_u_A_C', '2': 13},
    {'1': 'CotType_t_x_d_d', '2': 14},
    {'1': 'CotType_a_f_G_E_S_E', '2': 15},
    {'1': 'CotType_a_f_G_E_V_C', '2': 16},
    {'1': 'CotType_a_f_S', '2': 17},
    {'1': 'CotType_a_f_A_M_F', '2': 18},
    {'1': 'CotType_a_f_A_M_F_C_H', '2': 19},
    {'1': 'CotType_a_f_A_M_F_U_L', '2': 20},
    {'1': 'CotType_a_f_A_M_F_L', '2': 21},
    {'1': 'CotType_a_f_A_M_F_P', '2': 22},
    {'1': 'CotType_a_f_A_C_H', '2': 23},
    {'1': 'CotType_a_n_A_M_F_Q', '2': 24},
    {'1': 'CotType_b_t_f', '2': 25},
    {'1': 'CotType_b_r_f_h_c', '2': 26},
    {'1': 'CotType_b_a_o_pan', '2': 27},
    {'1': 'CotType_b_a_o_opn', '2': 28},
    {'1': 'CotType_b_a_o_can', '2': 29},
    {'1': 'CotType_b_a_o_tbl', '2': 30},
    {'1': 'CotType_b_a_g', '2': 31},
    {'1': 'CotType_a_f_G', '2': 32},
    {'1': 'CotType_a_f_G_U', '2': 33},
    {'1': 'CotType_a_h_G', '2': 34},
    {'1': 'CotType_a_u_G', '2': 35},
    {'1': 'CotType_a_n_G', '2': 36},
    {'1': 'CotType_b_m_r', '2': 37},
    {'1': 'CotType_b_m_p_w', '2': 38},
    {'1': 'CotType_b_m_p_s_p_i', '2': 39},
    {'1': 'CotType_u_d_f', '2': 40},
    {'1': 'CotType_u_d_r', '2': 41},
    {'1': 'CotType_u_d_c_c', '2': 42},
    {'1': 'CotType_u_rb_a', '2': 43},
    {'1': 'CotType_a_h_A', '2': 44},
    {'1': 'CotType_a_u_A', '2': 45},
    {'1': 'CotType_a_f_A_M_H_Q', '2': 46},
    {'1': 'CotType_a_f_A_C_F', '2': 47},
    {'1': 'CotType_a_f_A_C', '2': 48},
    {'1': 'CotType_a_f_A_C_L', '2': 49},
    {'1': 'CotType_a_f_A', '2': 50},
    {'1': 'CotType_a_f_A_M_H_C', '2': 51},
    {'1': 'CotType_a_n_A_M_F_F', '2': 52},
    {'1': 'CotType_a_u_A_C_F', '2': 53},
    {'1': 'CotType_a_f_G_U_C_F_T_A', '2': 54},
    {'1': 'CotType_a_f_G_U_C_V_S', '2': 55},
    {'1': 'CotType_a_f_G_U_C_R_X', '2': 56},
    {'1': 'CotType_a_f_G_U_C_I_Z', '2': 57},
    {'1': 'CotType_a_f_G_U_C_E_C_W', '2': 58},
    {'1': 'CotType_a_f_G_U_C_I_L', '2': 59},
    {'1': 'CotType_a_f_G_U_C_R_O', '2': 60},
    {'1': 'CotType_a_f_G_U_C_R_V', '2': 61},
    {'1': 'CotType_a_f_G_U_H', '2': 62},
    {'1': 'CotType_a_f_G_U_U_M_S_E', '2': 63},
    {'1': 'CotType_a_f_G_U_S_M_C', '2': 64},
    {'1': 'CotType_a_f_G_E_S', '2': 65},
    {'1': 'CotType_a_f_G_E', '2': 66},
    {'1': 'CotType_a_f_G_E_V_C_U', '2': 67},
    {'1': 'CotType_a_f_G_E_V_C_ps', '2': 68},
    {'1': 'CotType_a_u_G_E_V', '2': 69},
    {'1': 'CotType_a_f_S_N_N_R', '2': 70},
    {'1': 'CotType_a_f_F_B', '2': 71},
    {'1': 'CotType_b_m_p_s_p_loc', '2': 72},
    {'1': 'CotType_b_i_v', '2': 73},
    {'1': 'CotType_b_f_t_r', '2': 74},
    {'1': 'CotType_b_f_t_a', '2': 75},
    {'1': 'CotType_u_d_f_m', '2': 76},
    {'1': 'CotType_u_d_p', '2': 77},
    {'1': 'CotType_b_m_p_s_m', '2': 78},
    {'1': 'CotType_b_m_p_c', '2': 79},
    {'1': 'CotType_u_r_b_c_c', '2': 80},
    {'1': 'CotType_u_r_b_bullseye', '2': 81},
    {'1': 'CotType_a_f_G_E_V_A', '2': 82},
    {'1': 'CotType_a_n_A', '2': 83},
    {'1': 'CotType_a_u_G_U_C_F', '2': 84},
    {'1': 'CotType_a_n_G_U_C_F', '2': 85},
    {'1': 'CotType_a_h_G_U_C_F', '2': 86},
    {'1': 'CotType_a_f_G_U_C_F', '2': 87},
    {'1': 'CotType_a_u_G_I', '2': 88},
    {'1': 'CotType_a_n_G_I', '2': 89},
    {'1': 'CotType_a_h_G_I', '2': 90},
    {'1': 'CotType_a_f_G_I', '2': 91},
    {'1': 'CotType_a_u_G_E_X_M', '2': 92},
    {'1': 'CotType_a_n_G_E_X_M', '2': 93},
    {'1': 'CotType_a_h_G_E_X_M', '2': 94},
    {'1': 'CotType_a_f_G_E_X_M', '2': 95},
    {'1': 'CotType_a_u_S', '2': 96},
    {'1': 'CotType_a_n_S', '2': 97},
    {'1': 'CotType_a_h_S', '2': 98},
    {'1': 'CotType_a_u_G_U_C_I_d', '2': 99},
    {'1': 'CotType_a_n_G_U_C_I_d', '2': 100},
    {'1': 'CotType_a_h_G_U_C_I_d', '2': 101},
    {'1': 'CotType_a_f_G_U_C_I_d', '2': 102},
    {'1': 'CotType_a_u_G_E_V_A_T', '2': 103},
    {'1': 'CotType_a_n_G_E_V_A_T', '2': 104},
    {'1': 'CotType_a_h_G_E_V_A_T', '2': 105},
    {'1': 'CotType_a_f_G_E_V_A_T', '2': 106},
    {'1': 'CotType_a_u_G_U_C_I', '2': 107},
    {'1': 'CotType_a_n_G_U_C_I', '2': 108},
    {'1': 'CotType_a_h_G_U_C_I', '2': 109},
    {'1': 'CotType_a_n_G_E_V', '2': 110},
    {'1': 'CotType_a_h_G_E_V', '2': 111},
    {'1': 'CotType_a_f_G_E_V', '2': 112},
    {'1': 'CotType_b_m_p_w_GOTO', '2': 113},
    {'1': 'CotType_b_m_p_c_ip', '2': 114},
    {'1': 'CotType_b_m_p_c_cp', '2': 115},
    {'1': 'CotType_b_m_p_s_p_op', '2': 116},
    {'1': 'CotType_u_d_v', '2': 117},
    {'1': 'CotType_u_d_v_m', '2': 118},
    {'1': 'CotType_u_d_c_e', '2': 119},
    {'1': 'CotType_b_i_x_i', '2': 120},
    {'1': 'CotType_b_t_f_d', '2': 121},
    {'1': 'CotType_b_t_f_r', '2': 122},
    {'1': 'CotType_b_a_o_c', '2': 123},
    {'1': 'CotType_t_s', '2': 124},
    {'1': 'CotType_m_t_t', '2': 125},
    {'1': 'CotType_y', '2': 126},
  ],
};

/// Descriptor for `CotType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List cotTypeDescriptor = $convert.base64Decode(
    'CgdDb3RUeXBlEhEKDUNvdFR5cGVfT3RoZXIQABIVChFDb3RUeXBlX2FfZl9HX1VfQxABEhcKE0'
    'NvdFR5cGVfYV9mX0dfVV9DX0kQAhIVChFDb3RUeXBlX2Ffbl9BX0NfRhADEhUKEUNvdFR5cGVf'
    'YV9uX0FfQ19IEAQSEwoPQ290VHlwZV9hX25fQV9DEAUSFQoRQ290VHlwZV9hX2ZfQV9NX0gQBh'
    'ITCg9Db3RUeXBlX2FfZl9BX00QBxIXChNDb3RUeXBlX2FfZl9BX01fRl9GEAgSFwoTQ290VHlw'
    'ZV9hX2ZfQV9NX0hfQRAJEhkKFUNvdFR5cGVfYV9mX0FfTV9IX1VfTRAKEhcKE0NvdFR5cGVfYV'
    '9oX0FfTV9GX0YQCxIXChNDb3RUeXBlX2FfaF9BX01fSF9BEAwSEwoPQ290VHlwZV9hX3VfQV9D'
    'EA0SEwoPQ290VHlwZV90X3hfZF9kEA4SFwoTQ290VHlwZV9hX2ZfR19FX1NfRRAPEhcKE0NvdF'
    'R5cGVfYV9mX0dfRV9WX0MQEBIRCg1Db3RUeXBlX2FfZl9TEBESFQoRQ290VHlwZV9hX2ZfQV9N'
    'X0YQEhIZChVDb3RUeXBlX2FfZl9BX01fRl9DX0gQExIZChVDb3RUeXBlX2FfZl9BX01fRl9VX0'
    'wQFBIXChNDb3RUeXBlX2FfZl9BX01fRl9MEBUSFwoTQ290VHlwZV9hX2ZfQV9NX0ZfUBAWEhUK'
    'EUNvdFR5cGVfYV9mX0FfQ19IEBcSFwoTQ290VHlwZV9hX25fQV9NX0ZfURAYEhEKDUNvdFR5cG'
    'VfYl90X2YQGRIVChFDb3RUeXBlX2Jfcl9mX2hfYxAaEhUKEUNvdFR5cGVfYl9hX29fcGFuEBsS'
    'FQoRQ290VHlwZV9iX2Ffb19vcG4QHBIVChFDb3RUeXBlX2JfYV9vX2NhbhAdEhUKEUNvdFR5cG'
    'VfYl9hX29fdGJsEB4SEQoNQ290VHlwZV9iX2FfZxAfEhEKDUNvdFR5cGVfYV9mX0cQIBITCg9D'
    'b3RUeXBlX2FfZl9HX1UQIRIRCg1Db3RUeXBlX2FfaF9HECISEQoNQ290VHlwZV9hX3VfRxAjEh'
    'EKDUNvdFR5cGVfYV9uX0cQJBIRCg1Db3RUeXBlX2JfbV9yECUSEwoPQ290VHlwZV9iX21fcF93'
    'ECYSFwoTQ290VHlwZV9iX21fcF9zX3BfaRAnEhEKDUNvdFR5cGVfdV9kX2YQKBIRCg1Db3RUeX'
    'BlX3VfZF9yECkSEwoPQ290VHlwZV91X2RfY19jECoSEgoOQ290VHlwZV91X3JiX2EQKxIRCg1D'
    'b3RUeXBlX2FfaF9BECwSEQoNQ290VHlwZV9hX3VfQRAtEhcKE0NvdFR5cGVfYV9mX0FfTV9IX1'
    'EQLhIVChFDb3RUeXBlX2FfZl9BX0NfRhAvEhMKD0NvdFR5cGVfYV9mX0FfQxAwEhUKEUNvdFR5'
    'cGVfYV9mX0FfQ19MEDESEQoNQ290VHlwZV9hX2ZfQRAyEhcKE0NvdFR5cGVfYV9mX0FfTV9IX0'
    'MQMxIXChNDb3RUeXBlX2Ffbl9BX01fRl9GEDQSFQoRQ290VHlwZV9hX3VfQV9DX0YQNRIbChdD'
    'b3RUeXBlX2FfZl9HX1VfQ19GX1RfQRA2EhkKFUNvdFR5cGVfYV9mX0dfVV9DX1ZfUxA3EhkKFU'
    'NvdFR5cGVfYV9mX0dfVV9DX1JfWBA4EhkKFUNvdFR5cGVfYV9mX0dfVV9DX0lfWhA5EhsKF0Nv'
    'dFR5cGVfYV9mX0dfVV9DX0VfQ19XEDoSGQoVQ290VHlwZV9hX2ZfR19VX0NfSV9MEDsSGQoVQ2'
    '90VHlwZV9hX2ZfR19VX0NfUl9PEDwSGQoVQ290VHlwZV9hX2ZfR19VX0NfUl9WED0SFQoRQ290'
    'VHlwZV9hX2ZfR19VX0gQPhIbChdDb3RUeXBlX2FfZl9HX1VfVV9NX1NfRRA/EhkKFUNvdFR5cG'
    'VfYV9mX0dfVV9TX01fQxBAEhUKEUNvdFR5cGVfYV9mX0dfRV9TEEESEwoPQ290VHlwZV9hX2Zf'
    'R19FEEISGQoVQ290VHlwZV9hX2ZfR19FX1ZfQ19VEEMSGgoWQ290VHlwZV9hX2ZfR19FX1ZfQ1'
    '9wcxBEEhUKEUNvdFR5cGVfYV91X0dfRV9WEEUSFwoTQ290VHlwZV9hX2ZfU19OX05fUhBGEhMK'
    'D0NvdFR5cGVfYV9mX0ZfQhBHEhkKFUNvdFR5cGVfYl9tX3Bfc19wX2xvYxBIEhEKDUNvdFR5cG'
    'VfYl9pX3YQSRITCg9Db3RUeXBlX2JfZl90X3IQShITCg9Db3RUeXBlX2JfZl90X2EQSxITCg9D'
    'b3RUeXBlX3VfZF9mX20QTBIRCg1Db3RUeXBlX3VfZF9wEE0SFQoRQ290VHlwZV9iX21fcF9zX2'
    '0QThITCg9Db3RUeXBlX2JfbV9wX2MQTxIVChFDb3RUeXBlX3Vfcl9iX2NfYxBQEhoKFkNvdFR5'
    'cGVfdV9yX2JfYnVsbHNleWUQURIXChNDb3RUeXBlX2FfZl9HX0VfVl9BEFISEQoNQ290VHlwZV'
    '9hX25fQRBTEhcKE0NvdFR5cGVfYV91X0dfVV9DX0YQVBIXChNDb3RUeXBlX2Ffbl9HX1VfQ19G'
    'EFUSFwoTQ290VHlwZV9hX2hfR19VX0NfRhBWEhcKE0NvdFR5cGVfYV9mX0dfVV9DX0YQVxITCg'
    '9Db3RUeXBlX2FfdV9HX0kQWBITCg9Db3RUeXBlX2Ffbl9HX0kQWRITCg9Db3RUeXBlX2FfaF9H'
    'X0kQWhITCg9Db3RUeXBlX2FfZl9HX0kQWxIXChNDb3RUeXBlX2FfdV9HX0VfWF9NEFwSFwoTQ2'
    '90VHlwZV9hX25fR19FX1hfTRBdEhcKE0NvdFR5cGVfYV9oX0dfRV9YX00QXhIXChNDb3RUeXBl'
    'X2FfZl9HX0VfWF9NEF8SEQoNQ290VHlwZV9hX3VfUxBgEhEKDUNvdFR5cGVfYV9uX1MQYRIRCg'
    '1Db3RUeXBlX2FfaF9TEGISGQoVQ290VHlwZV9hX3VfR19VX0NfSV9kEGMSGQoVQ290VHlwZV9h'
    'X25fR19VX0NfSV9kEGQSGQoVQ290VHlwZV9hX2hfR19VX0NfSV9kEGUSGQoVQ290VHlwZV9hX2'
    'ZfR19VX0NfSV9kEGYSGQoVQ290VHlwZV9hX3VfR19FX1ZfQV9UEGcSGQoVQ290VHlwZV9hX25f'
    'R19FX1ZfQV9UEGgSGQoVQ290VHlwZV9hX2hfR19FX1ZfQV9UEGkSGQoVQ290VHlwZV9hX2ZfR1'
    '9FX1ZfQV9UEGoSFwoTQ290VHlwZV9hX3VfR19VX0NfSRBrEhcKE0NvdFR5cGVfYV9uX0dfVV9D'
    'X0kQbBIXChNDb3RUeXBlX2FfaF9HX1VfQ19JEG0SFQoRQ290VHlwZV9hX25fR19FX1YQbhIVCh'
    'FDb3RUeXBlX2FfaF9HX0VfVhBvEhUKEUNvdFR5cGVfYV9mX0dfRV9WEHASGAoUQ290VHlwZV9i'
    'X21fcF93X0dPVE8QcRIWChJDb3RUeXBlX2JfbV9wX2NfaXAQchIWChJDb3RUeXBlX2JfbV9wX2'
    'NfY3AQcxIYChRDb3RUeXBlX2JfbV9wX3NfcF9vcBB0EhEKDUNvdFR5cGVfdV9kX3YQdRITCg9D'
    'b3RUeXBlX3VfZF92X20QdhITCg9Db3RUeXBlX3VfZF9jX2UQdxITCg9Db3RUeXBlX2JfaV94X2'
    'kQeBITCg9Db3RUeXBlX2JfdF9mX2QQeRITCg9Db3RUeXBlX2JfdF9mX3IQehITCg9Db3RUeXBl'
    'X2JfYV9vX2MQexIPCgtDb3RUeXBlX3RfcxB8EhEKDUNvdFR5cGVfbV90X3QQfRINCglDb3RUeX'
    'BlX3kQfg==');

@$core.Deprecated('Use geoPointSourceDescriptor instead')
const GeoPointSource$json = {
  '1': 'GeoPointSource',
  '2': [
    {'1': 'GeoPointSource_Unspecified', '2': 0},
    {'1': 'GeoPointSource_GPS', '2': 1},
    {'1': 'GeoPointSource_USER', '2': 2},
    {'1': 'GeoPointSource_NETWORK', '2': 3},
  ],
};

/// Descriptor for `GeoPointSource`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List geoPointSourceDescriptor = $convert.base64Decode(
    'Cg5HZW9Qb2ludFNvdXJjZRIeChpHZW9Qb2ludFNvdXJjZV9VbnNwZWNpZmllZBAAEhYKEkdlb1'
    'BvaW50U291cmNlX0dQUxABEhcKE0dlb1BvaW50U291cmNlX1VTRVIQAhIaChZHZW9Qb2ludFNv'
    'dXJjZV9ORVRXT1JLEAM=');

@$core.Deprecated('Use tAKPacketDescriptor instead')
const TAKPacket$json = {
  '1': 'TAKPacket',
  '2': [
    {'1': 'is_compressed', '3': 1, '4': 1, '5': 8, '10': 'isCompressed'},
    {
      '1': 'contact',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Contact',
      '10': 'contact'
    },
    {
      '1': 'group',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Group',
      '10': 'group'
    },
    {
      '1': 'status',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Status',
      '10': 'status'
    },
    {
      '1': 'pli',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.PLI',
      '9': 0,
      '10': 'pli'
    },
    {
      '1': 'chat',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.GeoChat',
      '9': 0,
      '10': 'chat'
    },
    {'1': 'detail', '3': 7, '4': 1, '5': 12, '9': 0, '10': 'detail'},
  ],
  '8': [
    {'1': 'payload_variant'},
  ],
};

/// Descriptor for `TAKPacket`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tAKPacketDescriptor = $convert.base64Decode(
    'CglUQUtQYWNrZXQSIwoNaXNfY29tcHJlc3NlZBgBIAEoCFIMaXNDb21wcmVzc2VkEi0KB2Nvbn'
    'RhY3QYAiABKAsyEy5tZXNodGFzdGljLkNvbnRhY3RSB2NvbnRhY3QSJwoFZ3JvdXAYAyABKAsy'
    'ES5tZXNodGFzdGljLkdyb3VwUgVncm91cBIqCgZzdGF0dXMYBCABKAsyEi5tZXNodGFzdGljLl'
    'N0YXR1c1IGc3RhdHVzEiMKA3BsaRgFIAEoCzIPLm1lc2h0YXN0aWMuUExJSABSA3BsaRIpCgRj'
    'aGF0GAYgASgLMhMubWVzaHRhc3RpYy5HZW9DaGF0SABSBGNoYXQSGAoGZGV0YWlsGAcgASgMSA'
    'BSBmRldGFpbEIRCg9wYXlsb2FkX3ZhcmlhbnQ=');

@$core.Deprecated('Use geoChatDescriptor instead')
const GeoChat$json = {
  '1': 'GeoChat',
  '2': [
    {'1': 'message', '3': 1, '4': 1, '5': 9, '10': 'message'},
    {'1': 'to', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'to', '17': true},
    {
      '1': 'to_callsign',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'toCallsign',
      '17': true
    },
    {'1': 'receipt_for_uid', '3': 4, '4': 1, '5': 9, '10': 'receiptForUid'},
    {
      '1': 'receipt_type',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.GeoChat.ReceiptType',
      '10': 'receiptType'
    },
    {'1': 'lang', '3': 6, '4': 1, '5': 9, '9': 2, '10': 'lang', '17': true},
    {
      '1': 'room_id',
      '3': 7,
      '4': 1,
      '5': 9,
      '9': 3,
      '10': 'roomId',
      '17': true
    },
    {
      '1': 'voice_profile_id',
      '3': 8,
      '4': 1,
      '5': 9,
      '9': 4,
      '10': 'voiceProfileId',
      '17': true
    },
  ],
  '4': [GeoChat_ReceiptType$json],
  '8': [
    {'1': '_to'},
    {'1': '_to_callsign'},
    {'1': '_lang'},
    {'1': '_room_id'},
    {'1': '_voice_profile_id'},
  ],
};

@$core.Deprecated('Use geoChatDescriptor instead')
const GeoChat_ReceiptType$json = {
  '1': 'ReceiptType',
  '2': [
    {'1': 'ReceiptType_None', '2': 0},
    {'1': 'ReceiptType_Delivered', '2': 1},
    {'1': 'ReceiptType_Read', '2': 2},
  ],
};

/// Descriptor for `GeoChat`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List geoChatDescriptor = $convert.base64Decode(
    'CgdHZW9DaGF0EhgKB21lc3NhZ2UYASABKAlSB21lc3NhZ2USEwoCdG8YAiABKAlIAFICdG+IAQ'
    'ESJAoLdG9fY2FsbHNpZ24YAyABKAlIAVIKdG9DYWxsc2lnbogBARImCg9yZWNlaXB0X2Zvcl91'
    'aWQYBCABKAlSDXJlY2VpcHRGb3JVaWQSQgoMcmVjZWlwdF90eXBlGAUgASgOMh8ubWVzaHRhc3'
    'RpYy5HZW9DaGF0LlJlY2VpcHRUeXBlUgtyZWNlaXB0VHlwZRIXCgRsYW5nGAYgASgJSAJSBGxh'
    'bmeIAQESHAoHcm9vbV9pZBgHIAEoCUgDUgZyb29tSWSIAQESLQoQdm9pY2VfcHJvZmlsZV9pZB'
    'gIIAEoCUgEUg52b2ljZVByb2ZpbGVJZIgBASJUCgtSZWNlaXB0VHlwZRIUChBSZWNlaXB0VHlw'
    'ZV9Ob25lEAASGQoVUmVjZWlwdFR5cGVfRGVsaXZlcmVkEAESFAoQUmVjZWlwdFR5cGVfUmVhZB'
    'ACQgUKA190b0IOCgxfdG9fY2FsbHNpZ25CBwoFX2xhbmdCCgoIX3Jvb21faWRCEwoRX3ZvaWNl'
    'X3Byb2ZpbGVfaWQ=');

@$core.Deprecated('Use groupDescriptor instead')
const Group$json = {
  '1': 'Group',
  '2': [
    {
      '1': 'role',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.MemberRole',
      '10': 'role'
    },
    {
      '1': 'team',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Team',
      '10': 'team'
    },
  ],
};

/// Descriptor for `Group`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List groupDescriptor = $convert.base64Decode(
    'CgVHcm91cBIqCgRyb2xlGAEgASgOMhYubWVzaHRhc3RpYy5NZW1iZXJSb2xlUgRyb2xlEiQKBH'
    'RlYW0YAiABKA4yEC5tZXNodGFzdGljLlRlYW1SBHRlYW0=');

@$core.Deprecated('Use statusDescriptor instead')
const Status$json = {
  '1': 'Status',
  '2': [
    {'1': 'battery', '3': 1, '4': 1, '5': 13, '10': 'battery'},
  ],
};

/// Descriptor for `Status`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List statusDescriptor =
    $convert.base64Decode('CgZTdGF0dXMSGAoHYmF0dGVyeRgBIAEoDVIHYmF0dGVyeQ==');

@$core.Deprecated('Use contactDescriptor instead')
const Contact$json = {
  '1': 'Contact',
  '2': [
    {'1': 'callsign', '3': 1, '4': 1, '5': 9, '10': 'callsign'},
    {'1': 'device_callsign', '3': 2, '4': 1, '5': 9, '10': 'deviceCallsign'},
  ],
};

/// Descriptor for `Contact`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List contactDescriptor = $convert.base64Decode(
    'CgdDb250YWN0EhoKCGNhbGxzaWduGAEgASgJUghjYWxsc2lnbhInCg9kZXZpY2VfY2FsbHNpZ2'
    '4YAiABKAlSDmRldmljZUNhbGxzaWdu');

@$core.Deprecated('Use pLIDescriptor instead')
const PLI$json = {
  '1': 'PLI',
  '2': [
    {'1': 'latitude_i', '3': 1, '4': 1, '5': 15, '10': 'latitudeI'},
    {'1': 'longitude_i', '3': 2, '4': 1, '5': 15, '10': 'longitudeI'},
    {'1': 'altitude', '3': 3, '4': 1, '5': 5, '10': 'altitude'},
    {'1': 'speed', '3': 4, '4': 1, '5': 13, '10': 'speed'},
    {'1': 'course', '3': 5, '4': 1, '5': 13, '10': 'course'},
  ],
};

/// Descriptor for `PLI`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pLIDescriptor = $convert.base64Decode(
    'CgNQTEkSHQoKbGF0aXR1ZGVfaRgBIAEoD1IJbGF0aXR1ZGVJEh8KC2xvbmdpdHVkZV9pGAIgAS'
    'gPUgpsb25naXR1ZGVJEhoKCGFsdGl0dWRlGAMgASgFUghhbHRpdHVkZRIUCgVzcGVlZBgEIAEo'
    'DVIFc3BlZWQSFgoGY291cnNlGAUgASgNUgZjb3Vyc2U=');

@$core.Deprecated('Use aircraftTrackDescriptor instead')
const AircraftTrack$json = {
  '1': 'AircraftTrack',
  '2': [
    {'1': 'icao', '3': 1, '4': 1, '5': 9, '10': 'icao'},
    {'1': 'registration', '3': 2, '4': 1, '5': 9, '10': 'registration'},
    {'1': 'flight', '3': 3, '4': 1, '5': 9, '10': 'flight'},
    {'1': 'aircraft_type', '3': 4, '4': 1, '5': 9, '10': 'aircraftType'},
    {'1': 'squawk', '3': 5, '4': 1, '5': 13, '10': 'squawk'},
    {'1': 'category', '3': 6, '4': 1, '5': 9, '10': 'category'},
    {'1': 'rssi_x10', '3': 7, '4': 1, '5': 17, '10': 'rssiX10'},
    {'1': 'gps', '3': 8, '4': 1, '5': 8, '10': 'gps'},
    {'1': 'cot_host_id', '3': 9, '4': 1, '5': 9, '10': 'cotHostId'},
  ],
};

/// Descriptor for `AircraftTrack`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List aircraftTrackDescriptor = $convert.base64Decode(
    'Cg1BaXJjcmFmdFRyYWNrEhIKBGljYW8YASABKAlSBGljYW8SIgoMcmVnaXN0cmF0aW9uGAIgAS'
    'gJUgxyZWdpc3RyYXRpb24SFgoGZmxpZ2h0GAMgASgJUgZmbGlnaHQSIwoNYWlyY3JhZnRfdHlw'
    'ZRgEIAEoCVIMYWlyY3JhZnRUeXBlEhYKBnNxdWF3axgFIAEoDVIGc3F1YXdrEhoKCGNhdGVnb3'
    'J5GAYgASgJUghjYXRlZ29yeRIZCghyc3NpX3gxMBgHIAEoEVIHcnNzaVgxMBIQCgNncHMYCCAB'
    'KAhSA2dwcxIeCgtjb3RfaG9zdF9pZBgJIAEoCVIJY290SG9zdElk');

@$core.Deprecated('Use cotGeoPointDescriptor instead')
const CotGeoPoint$json = {
  '1': 'CotGeoPoint',
  '2': [
    {'1': 'lat_delta_i', '3': 1, '4': 1, '5': 17, '10': 'latDeltaI'},
    {'1': 'lon_delta_i', '3': 2, '4': 1, '5': 17, '10': 'lonDeltaI'},
  ],
};

/// Descriptor for `CotGeoPoint`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cotGeoPointDescriptor = $convert.base64Decode(
    'CgtDb3RHZW9Qb2ludBIeCgtsYXRfZGVsdGFfaRgBIAEoEVIJbGF0RGVsdGFJEh4KC2xvbl9kZW'
    'x0YV9pGAIgASgRUglsb25EZWx0YUk=');

@$core.Deprecated('Use drawnShapeDescriptor instead')
const DrawnShape$json = {
  '1': 'DrawnShape',
  '2': [
    {
      '1': 'kind',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.DrawnShape.Kind',
      '10': 'kind'
    },
    {
      '1': 'style',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.DrawnShape.StyleMode',
      '10': 'style'
    },
    {'1': 'major_cm', '3': 3, '4': 1, '5': 13, '10': 'majorCm'},
    {'1': 'minor_cm', '3': 4, '4': 1, '5': 13, '10': 'minorCm'},
    {'1': 'angle_deg', '3': 5, '4': 1, '5': 13, '10': 'angleDeg'},
    {
      '1': 'stroke_color',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Team',
      '10': 'strokeColor'
    },
    {'1': 'stroke_argb', '3': 7, '4': 1, '5': 7, '10': 'strokeArgb'},
    {
      '1': 'stroke_weight_x10',
      '3': 8,
      '4': 1,
      '5': 13,
      '10': 'strokeWeightX10'
    },
    {
      '1': 'fill_color',
      '3': 9,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Team',
      '10': 'fillColor'
    },
    {'1': 'fill_argb', '3': 10, '4': 1, '5': 7, '10': 'fillArgb'},
    {'1': 'labels_on', '3': 11, '4': 1, '5': 8, '10': 'labelsOn'},
    {
      '1': 'vertex_lat_deltas',
      '3': 18,
      '4': 3,
      '5': 17,
      '10': 'vertexLatDeltas'
    },
    {
      '1': 'vertex_lon_deltas',
      '3': 19,
      '4': 3,
      '5': 17,
      '10': 'vertexLonDeltas'
    },
    {'1': 'truncated', '3': 13, '4': 1, '5': 8, '10': 'truncated'},
    {
      '1': 'bullseye_distance_dm',
      '3': 14,
      '4': 1,
      '5': 13,
      '10': 'bullseyeDistanceDm'
    },
    {
      '1': 'bullseye_bearing_ref',
      '3': 15,
      '4': 1,
      '5': 13,
      '10': 'bullseyeBearingRef'
    },
    {'1': 'bullseye_flags', '3': 16, '4': 1, '5': 13, '10': 'bullseyeFlags'},
    {'1': 'bullseye_uid_ref', '3': 17, '4': 1, '5': 9, '10': 'bullseyeUidRef'},
  ],
  '4': [DrawnShape_Kind$json, DrawnShape_StyleMode$json],
  '9': [
    {'1': 12, '2': 13},
  ],
};

@$core.Deprecated('Use drawnShapeDescriptor instead')
const DrawnShape_Kind$json = {
  '1': 'Kind',
  '2': [
    {'1': 'Kind_Unspecified', '2': 0},
    {'1': 'Kind_Circle', '2': 1},
    {'1': 'Kind_Rectangle', '2': 2},
    {'1': 'Kind_Freeform', '2': 3},
    {'1': 'Kind_Telestration', '2': 4},
    {'1': 'Kind_Polygon', '2': 5},
    {'1': 'Kind_RangingCircle', '2': 6},
    {'1': 'Kind_Bullseye', '2': 7},
    {'1': 'Kind_Ellipse', '2': 8},
    {'1': 'Kind_Vehicle2D', '2': 9},
    {'1': 'Kind_Vehicle3D', '2': 10},
  ],
};

@$core.Deprecated('Use drawnShapeDescriptor instead')
const DrawnShape_StyleMode$json = {
  '1': 'StyleMode',
  '2': [
    {'1': 'StyleMode_Unspecified', '2': 0},
    {'1': 'StyleMode_StrokeOnly', '2': 1},
    {'1': 'StyleMode_FillOnly', '2': 2},
    {'1': 'StyleMode_StrokeAndFill', '2': 3},
  ],
};

/// Descriptor for `DrawnShape`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List drawnShapeDescriptor = $convert.base64Decode(
    'CgpEcmF3blNoYXBlEi8KBGtpbmQYASABKA4yGy5tZXNodGFzdGljLkRyYXduU2hhcGUuS2luZF'
    'IEa2luZBI2CgVzdHlsZRgCIAEoDjIgLm1lc2h0YXN0aWMuRHJhd25TaGFwZS5TdHlsZU1vZGVS'
    'BXN0eWxlEhkKCG1ham9yX2NtGAMgASgNUgdtYWpvckNtEhkKCG1pbm9yX2NtGAQgASgNUgdtaW'
    '5vckNtEhsKCWFuZ2xlX2RlZxgFIAEoDVIIYW5nbGVEZWcSMwoMc3Ryb2tlX2NvbG9yGAYgASgO'
    'MhAubWVzaHRhc3RpYy5UZWFtUgtzdHJva2VDb2xvchIfCgtzdHJva2VfYXJnYhgHIAEoB1IKc3'
    'Ryb2tlQXJnYhIqChFzdHJva2Vfd2VpZ2h0X3gxMBgIIAEoDVIPc3Ryb2tlV2VpZ2h0WDEwEi8K'
    'CmZpbGxfY29sb3IYCSABKA4yEC5tZXNodGFzdGljLlRlYW1SCWZpbGxDb2xvchIbCglmaWxsX2'
    'FyZ2IYCiABKAdSCGZpbGxBcmdiEhsKCWxhYmVsc19vbhgLIAEoCFIIbGFiZWxzT24SKgoRdmVy'
    'dGV4X2xhdF9kZWx0YXMYEiADKBFSD3ZlcnRleExhdERlbHRhcxIqChF2ZXJ0ZXhfbG9uX2RlbH'
    'RhcxgTIAMoEVIPdmVydGV4TG9uRGVsdGFzEhwKCXRydW5jYXRlZBgNIAEoCFIJdHJ1bmNhdGVk'
    'EjAKFGJ1bGxzZXllX2Rpc3RhbmNlX2RtGA4gASgNUhJidWxsc2V5ZURpc3RhbmNlRG0SMAoUYn'
    'VsbHNleWVfYmVhcmluZ19yZWYYDyABKA1SEmJ1bGxzZXllQmVhcmluZ1JlZhIlCg5idWxsc2V5'
    'ZV9mbGFncxgQIAEoDVINYnVsbHNleWVGbGFncxIoChBidWxsc2V5ZV91aWRfcmVmGBEgASgJUg'
    '5idWxsc2V5ZVVpZFJlZiLiAQoES2luZBIUChBLaW5kX1Vuc3BlY2lmaWVkEAASDwoLS2luZF9D'
    'aXJjbGUQARISCg5LaW5kX1JlY3RhbmdsZRACEhEKDUtpbmRfRnJlZWZvcm0QAxIVChFLaW5kX1'
    'RlbGVzdHJhdGlvbhAEEhAKDEtpbmRfUG9seWdvbhAFEhYKEktpbmRfUmFuZ2luZ0NpcmNsZRAG'
    'EhEKDUtpbmRfQnVsbHNleWUQBxIQCgxLaW5kX0VsbGlwc2UQCBISCg5LaW5kX1ZlaGljbGUyRB'
    'AJEhIKDktpbmRfVmVoaWNsZTNEEAoidQoJU3R5bGVNb2RlEhkKFVN0eWxlTW9kZV9VbnNwZWNp'
    'ZmllZBAAEhgKFFN0eWxlTW9kZV9TdHJva2VPbmx5EAESFgoSU3R5bGVNb2RlX0ZpbGxPbmx5EA'
    'ISGwoXU3R5bGVNb2RlX1N0cm9rZUFuZEZpbGwQA0oECAwQDQ==');

@$core.Deprecated('Use markerDescriptor instead')
const Marker$json = {
  '1': 'Marker',
  '2': [
    {
      '1': 'kind',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Marker.Kind',
      '10': 'kind'
    },
    {
      '1': 'color',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Team',
      '10': 'color'
    },
    {'1': 'color_argb', '3': 3, '4': 1, '5': 7, '10': 'colorArgb'},
    {'1': 'readiness', '3': 4, '4': 1, '5': 8, '10': 'readiness'},
    {'1': 'parent_uid', '3': 5, '4': 1, '5': 9, '10': 'parentUid'},
    {'1': 'parent_type', '3': 6, '4': 1, '5': 9, '10': 'parentType'},
    {'1': 'parent_callsign', '3': 7, '4': 1, '5': 9, '10': 'parentCallsign'},
    {'1': 'iconset', '3': 8, '4': 1, '5': 9, '10': 'iconset'},
  ],
  '4': [Marker_Kind$json],
};

@$core.Deprecated('Use markerDescriptor instead')
const Marker_Kind$json = {
  '1': 'Kind',
  '2': [
    {'1': 'Kind_Unspecified', '2': 0},
    {'1': 'Kind_Spot', '2': 1},
    {'1': 'Kind_Waypoint', '2': 2},
    {'1': 'Kind_Checkpoint', '2': 3},
    {'1': 'Kind_SelfPosition', '2': 4},
    {'1': 'Kind_Symbol2525', '2': 5},
    {'1': 'Kind_SpotMap', '2': 6},
    {'1': 'Kind_CustomIcon', '2': 7},
    {'1': 'Kind_GoToPoint', '2': 8},
    {'1': 'Kind_InitialPoint', '2': 9},
    {'1': 'Kind_ContactPoint', '2': 10},
    {'1': 'Kind_ObservationPost', '2': 11},
    {'1': 'Kind_ImageMarker', '2': 12},
  ],
};

/// Descriptor for `Marker`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List markerDescriptor = $convert.base64Decode(
    'CgZNYXJrZXISKwoEa2luZBgBIAEoDjIXLm1lc2h0YXN0aWMuTWFya2VyLktpbmRSBGtpbmQSJg'
    'oFY29sb3IYAiABKA4yEC5tZXNodGFzdGljLlRlYW1SBWNvbG9yEh0KCmNvbG9yX2FyZ2IYAyAB'
    'KAdSCWNvbG9yQXJnYhIcCglyZWFkaW5lc3MYBCABKAhSCXJlYWRpbmVzcxIdCgpwYXJlbnRfdW'
    'lkGAUgASgJUglwYXJlbnRVaWQSHwoLcGFyZW50X3R5cGUYBiABKAlSCnBhcmVudFR5cGUSJwoP'
    'cGFyZW50X2NhbGxzaWduGAcgASgJUg5wYXJlbnRDYWxsc2lnbhIYCgdpY29uc2V0GAggASgJUg'
    'dpY29uc2V0IpgCCgRLaW5kEhQKEEtpbmRfVW5zcGVjaWZpZWQQABINCglLaW5kX1Nwb3QQARIR'
    'Cg1LaW5kX1dheXBvaW50EAISEwoPS2luZF9DaGVja3BvaW50EAMSFQoRS2luZF9TZWxmUG9zaX'
    'Rpb24QBBITCg9LaW5kX1N5bWJvbDI1MjUQBRIQCgxLaW5kX1Nwb3RNYXAQBhITCg9LaW5kX0N1'
    'c3RvbUljb24QBxISCg5LaW5kX0dvVG9Qb2ludBAIEhUKEUtpbmRfSW5pdGlhbFBvaW50EAkSFQ'
    'oRS2luZF9Db250YWN0UG9pbnQQChIYChRLaW5kX09ic2VydmF0aW9uUG9zdBALEhQKEEtpbmRf'
    'SW1hZ2VNYXJrZXIQDA==');

@$core.Deprecated('Use rangeAndBearingDescriptor instead')
const RangeAndBearing$json = {
  '1': 'RangeAndBearing',
  '2': [
    {
      '1': 'anchor',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.CotGeoPoint',
      '10': 'anchor'
    },
    {'1': 'anchor_uid', '3': 2, '4': 1, '5': 9, '10': 'anchorUid'},
    {'1': 'range_cm', '3': 3, '4': 1, '5': 13, '10': 'rangeCm'},
    {'1': 'bearing_cdeg', '3': 4, '4': 1, '5': 13, '10': 'bearingCdeg'},
    {
      '1': 'stroke_color',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Team',
      '10': 'strokeColor'
    },
    {'1': 'stroke_argb', '3': 6, '4': 1, '5': 7, '10': 'strokeArgb'},
    {
      '1': 'stroke_weight_x10',
      '3': 7,
      '4': 1,
      '5': 13,
      '10': 'strokeWeightX10'
    },
  ],
};

/// Descriptor for `RangeAndBearing`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rangeAndBearingDescriptor = $convert.base64Decode(
    'Cg9SYW5nZUFuZEJlYXJpbmcSLwoGYW5jaG9yGAEgASgLMhcubWVzaHRhc3RpYy5Db3RHZW9Qb2'
    'ludFIGYW5jaG9yEh0KCmFuY2hvcl91aWQYAiABKAlSCWFuY2hvclVpZBIZCghyYW5nZV9jbRgD'
    'IAEoDVIHcmFuZ2VDbRIhCgxiZWFyaW5nX2NkZWcYBCABKA1SC2JlYXJpbmdDZGVnEjMKDHN0cm'
    '9rZV9jb2xvchgFIAEoDjIQLm1lc2h0YXN0aWMuVGVhbVILc3Ryb2tlQ29sb3ISHwoLc3Ryb2tl'
    'X2FyZ2IYBiABKAdSCnN0cm9rZUFyZ2ISKgoRc3Ryb2tlX3dlaWdodF94MTAYByABKA1SD3N0cm'
    '9rZVdlaWdodFgxMA==');

@$core.Deprecated('Use routeDescriptor instead')
const Route$json = {
  '1': 'Route',
  '2': [
    {
      '1': 'method',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Route.Method',
      '10': 'method'
    },
    {
      '1': 'direction',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Route.Direction',
      '10': 'direction'
    },
    {'1': 'prefix', '3': 3, '4': 1, '5': 9, '10': 'prefix'},
    {
      '1': 'stroke_weight_x10',
      '3': 4,
      '4': 1,
      '5': 13,
      '10': 'strokeWeightX10'
    },
    {
      '1': 'links',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.meshtastic.Route.Link',
      '10': 'links'
    },
    {'1': 'truncated', '3': 6, '4': 1, '5': 8, '10': 'truncated'},
  ],
  '3': [Route_Link$json],
  '4': [Route_Method$json, Route_Direction$json],
};

@$core.Deprecated('Use routeDescriptor instead')
const Route_Link$json = {
  '1': 'Link',
  '2': [
    {
      '1': 'point',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.CotGeoPoint',
      '10': 'point'
    },
    {'1': 'uid', '3': 2, '4': 1, '5': 9, '10': 'uid'},
    {'1': 'callsign', '3': 3, '4': 1, '5': 9, '10': 'callsign'},
    {'1': 'link_type', '3': 4, '4': 1, '5': 13, '10': 'linkType'},
  ],
};

@$core.Deprecated('Use routeDescriptor instead')
const Route_Method$json = {
  '1': 'Method',
  '2': [
    {'1': 'Method_Unspecified', '2': 0},
    {'1': 'Method_Driving', '2': 1},
    {'1': 'Method_Walking', '2': 2},
    {'1': 'Method_Flying', '2': 3},
    {'1': 'Method_Swimming', '2': 4},
    {'1': 'Method_Watercraft', '2': 5},
  ],
};

@$core.Deprecated('Use routeDescriptor instead')
const Route_Direction$json = {
  '1': 'Direction',
  '2': [
    {'1': 'Direction_Unspecified', '2': 0},
    {'1': 'Direction_Infil', '2': 1},
    {'1': 'Direction_Exfil', '2': 2},
  ],
};

/// Descriptor for `Route`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List routeDescriptor = $convert.base64Decode(
    'CgVSb3V0ZRIwCgZtZXRob2QYASABKA4yGC5tZXNodGFzdGljLlJvdXRlLk1ldGhvZFIGbWV0aG'
    '9kEjkKCWRpcmVjdGlvbhgCIAEoDjIbLm1lc2h0YXN0aWMuUm91dGUuRGlyZWN0aW9uUglkaXJl'
    'Y3Rpb24SFgoGcHJlZml4GAMgASgJUgZwcmVmaXgSKgoRc3Ryb2tlX3dlaWdodF94MTAYBCABKA'
    '1SD3N0cm9rZVdlaWdodFgxMBIsCgVsaW5rcxgFIAMoCzIWLm1lc2h0YXN0aWMuUm91dGUuTGlu'
    'a1IFbGlua3MSHAoJdHJ1bmNhdGVkGAYgASgIUgl0cnVuY2F0ZWQagAEKBExpbmsSLQoFcG9pbn'
    'QYASABKAsyFy5tZXNodGFzdGljLkNvdEdlb1BvaW50UgVwb2ludBIQCgN1aWQYAiABKAlSA3Vp'
    'ZBIaCghjYWxsc2lnbhgDIAEoCVIIY2FsbHNpZ24SGwoJbGlua190eXBlGAQgASgNUghsaW5rVH'
    'lwZSKHAQoGTWV0aG9kEhYKEk1ldGhvZF9VbnNwZWNpZmllZBAAEhIKDk1ldGhvZF9Ecml2aW5n'
    'EAESEgoOTWV0aG9kX1dhbGtpbmcQAhIRCg1NZXRob2RfRmx5aW5nEAMSEwoPTWV0aG9kX1N3aW'
    '1taW5nEAQSFQoRTWV0aG9kX1dhdGVyY3JhZnQQBSJQCglEaXJlY3Rpb24SGQoVRGlyZWN0aW9u'
    'X1Vuc3BlY2lmaWVkEAASEwoPRGlyZWN0aW9uX0luZmlsEAESEwoPRGlyZWN0aW9uX0V4ZmlsEA'
    'I=');

@$core.Deprecated('Use casevacReportDescriptor instead')
const CasevacReport$json = {
  '1': 'CasevacReport',
  '2': [
    {
      '1': 'precedence',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.CasevacReport.Precedence',
      '10': 'precedence'
    },
    {'1': 'equipment_flags', '3': 2, '4': 1, '5': 13, '10': 'equipmentFlags'},
    {'1': 'litter_patients', '3': 3, '4': 1, '5': 13, '10': 'litterPatients'},
    {
      '1': 'ambulatory_patients',
      '3': 4,
      '4': 1,
      '5': 13,
      '10': 'ambulatoryPatients'
    },
    {
      '1': 'security',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.CasevacReport.Security',
      '10': 'security'
    },
    {
      '1': 'hlz_marking',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.CasevacReport.HlzMarking',
      '10': 'hlzMarking'
    },
    {'1': 'zone_marker', '3': 7, '4': 1, '5': 9, '10': 'zoneMarker'},
    {'1': 'us_military', '3': 8, '4': 1, '5': 13, '10': 'usMilitary'},
    {'1': 'us_civilian', '3': 9, '4': 1, '5': 13, '10': 'usCivilian'},
    {'1': 'non_us_military', '3': 10, '4': 1, '5': 13, '10': 'nonUsMilitary'},
    {'1': 'non_us_civilian', '3': 11, '4': 1, '5': 13, '10': 'nonUsCivilian'},
    {'1': 'epw', '3': 12, '4': 1, '5': 13, '10': 'epw'},
    {'1': 'child', '3': 13, '4': 1, '5': 13, '10': 'child'},
    {'1': 'terrain_flags', '3': 14, '4': 1, '5': 13, '10': 'terrainFlags'},
    {'1': 'frequency', '3': 15, '4': 1, '5': 9, '10': 'frequency'},
    {'1': 'title', '3': 16, '4': 1, '5': 9, '10': 'title'},
    {'1': 'medline_remarks', '3': 17, '4': 1, '5': 9, '10': 'medlineRemarks'},
    {'1': 'urgent_count', '3': 18, '4': 1, '5': 13, '10': 'urgentCount'},
    {
      '1': 'urgent_surgical_count',
      '3': 19,
      '4': 1,
      '5': 13,
      '10': 'urgentSurgicalCount'
    },
    {'1': 'priority_count', '3': 20, '4': 1, '5': 13, '10': 'priorityCount'},
    {'1': 'routine_count', '3': 21, '4': 1, '5': 13, '10': 'routineCount'},
    {
      '1': 'convenience_count',
      '3': 22,
      '4': 1,
      '5': 13,
      '10': 'convenienceCount'
    },
    {'1': 'equipment_detail', '3': 23, '4': 1, '5': 9, '10': 'equipmentDetail'},
    {
      '1': 'zone_protected_coord',
      '3': 24,
      '4': 1,
      '5': 9,
      '10': 'zoneProtectedCoord'
    },
    {
      '1': 'terrain_slope_dir',
      '3': 25,
      '4': 1,
      '5': 9,
      '10': 'terrainSlopeDir'
    },
    {
      '1': 'terrain_other_detail',
      '3': 26,
      '4': 1,
      '5': 9,
      '10': 'terrainOtherDetail'
    },
    {'1': 'marked_by', '3': 27, '4': 1, '5': 9, '10': 'markedBy'},
    {'1': 'obstacles', '3': 28, '4': 1, '5': 9, '10': 'obstacles'},
    {'1': 'winds_are_from', '3': 29, '4': 1, '5': 9, '10': 'windsAreFrom'},
    {'1': 'friendlies', '3': 30, '4': 1, '5': 9, '10': 'friendlies'},
    {'1': 'enemy', '3': 31, '4': 1, '5': 9, '10': 'enemy'},
    {'1': 'hlz_remarks', '3': 32, '4': 1, '5': 9, '10': 'hlzRemarks'},
    {
      '1': 'zmist',
      '3': 33,
      '4': 3,
      '5': 11,
      '6': '.meshtastic.ZMistEntry',
      '10': 'zmist'
    },
  ],
  '4': [
    CasevacReport_Precedence$json,
    CasevacReport_HlzMarking$json,
    CasevacReport_Security$json
  ],
};

@$core.Deprecated('Use casevacReportDescriptor instead')
const CasevacReport_Precedence$json = {
  '1': 'Precedence',
  '2': [
    {'1': 'Precedence_Unspecified', '2': 0},
    {'1': 'Precedence_Urgent', '2': 1},
    {'1': 'Precedence_UrgentSurgical', '2': 2},
    {'1': 'Precedence_Priority', '2': 3},
    {'1': 'Precedence_Routine', '2': 4},
    {'1': 'Precedence_Convenience', '2': 5},
  ],
};

@$core.Deprecated('Use casevacReportDescriptor instead')
const CasevacReport_HlzMarking$json = {
  '1': 'HlzMarking',
  '2': [
    {'1': 'HlzMarking_Unspecified', '2': 0},
    {'1': 'HlzMarking_Panels', '2': 1},
    {'1': 'HlzMarking_PyroSignal', '2': 2},
    {'1': 'HlzMarking_Smoke', '2': 3},
    {'1': 'HlzMarking_None', '2': 4},
    {'1': 'HlzMarking_Other', '2': 5},
  ],
};

@$core.Deprecated('Use casevacReportDescriptor instead')
const CasevacReport_Security$json = {
  '1': 'Security',
  '2': [
    {'1': 'Security_Unspecified', '2': 0},
    {'1': 'Security_NoEnemy', '2': 1},
    {'1': 'Security_PossibleEnemy', '2': 2},
    {'1': 'Security_EnemyInArea', '2': 3},
    {'1': 'Security_EnemyInArmedContact', '2': 4},
  ],
};

/// Descriptor for `CasevacReport`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List casevacReportDescriptor = $convert.base64Decode(
    'Cg1DYXNldmFjUmVwb3J0EkQKCnByZWNlZGVuY2UYASABKA4yJC5tZXNodGFzdGljLkNhc2V2YW'
    'NSZXBvcnQuUHJlY2VkZW5jZVIKcHJlY2VkZW5jZRInCg9lcXVpcG1lbnRfZmxhZ3MYAiABKA1S'
    'DmVxdWlwbWVudEZsYWdzEicKD2xpdHRlcl9wYXRpZW50cxgDIAEoDVIObGl0dGVyUGF0aWVudH'
    'MSLwoTYW1idWxhdG9yeV9wYXRpZW50cxgEIAEoDVISYW1idWxhdG9yeVBhdGllbnRzEj4KCHNl'
    'Y3VyaXR5GAUgASgOMiIubWVzaHRhc3RpYy5DYXNldmFjUmVwb3J0LlNlY3VyaXR5UghzZWN1cm'
    'l0eRJFCgtobHpfbWFya2luZxgGIAEoDjIkLm1lc2h0YXN0aWMuQ2FzZXZhY1JlcG9ydC5IbHpN'
    'YXJraW5nUgpobHpNYXJraW5nEh8KC3pvbmVfbWFya2VyGAcgASgJUgp6b25lTWFya2VyEh8KC3'
    'VzX21pbGl0YXJ5GAggASgNUgp1c01pbGl0YXJ5Eh8KC3VzX2NpdmlsaWFuGAkgASgNUgp1c0Np'
    'dmlsaWFuEiYKD25vbl91c19taWxpdGFyeRgKIAEoDVINbm9uVXNNaWxpdGFyeRImCg9ub25fdX'
    'NfY2l2aWxpYW4YCyABKA1SDW5vblVzQ2l2aWxpYW4SEAoDZXB3GAwgASgNUgNlcHcSFAoFY2hp'
    'bGQYDSABKA1SBWNoaWxkEiMKDXRlcnJhaW5fZmxhZ3MYDiABKA1SDHRlcnJhaW5GbGFncxIcCg'
    'lmcmVxdWVuY3kYDyABKAlSCWZyZXF1ZW5jeRIUCgV0aXRsZRgQIAEoCVIFdGl0bGUSJwoPbWVk'
    'bGluZV9yZW1hcmtzGBEgASgJUg5tZWRsaW5lUmVtYXJrcxIhCgx1cmdlbnRfY291bnQYEiABKA'
    '1SC3VyZ2VudENvdW50EjIKFXVyZ2VudF9zdXJnaWNhbF9jb3VudBgTIAEoDVITdXJnZW50U3Vy'
    'Z2ljYWxDb3VudBIlCg5wcmlvcml0eV9jb3VudBgUIAEoDVINcHJpb3JpdHlDb3VudBIjCg1yb3'
    'V0aW5lX2NvdW50GBUgASgNUgxyb3V0aW5lQ291bnQSKwoRY29udmVuaWVuY2VfY291bnQYFiAB'
    'KA1SEGNvbnZlbmllbmNlQ291bnQSKQoQZXF1aXBtZW50X2RldGFpbBgXIAEoCVIPZXF1aXBtZW'
    '50RGV0YWlsEjAKFHpvbmVfcHJvdGVjdGVkX2Nvb3JkGBggASgJUhJ6b25lUHJvdGVjdGVkQ29v'
    'cmQSKgoRdGVycmFpbl9zbG9wZV9kaXIYGSABKAlSD3RlcnJhaW5TbG9wZURpchIwChR0ZXJyYW'
    'luX290aGVyX2RldGFpbBgaIAEoCVISdGVycmFpbk90aGVyRGV0YWlsEhsKCW1hcmtlZF9ieRgb'
    'IAEoCVIIbWFya2VkQnkSHAoJb2JzdGFjbGVzGBwgASgJUglvYnN0YWNsZXMSJAoOd2luZHNfYX'
    'JlX2Zyb20YHSABKAlSDHdpbmRzQXJlRnJvbRIeCgpmcmllbmRsaWVzGB4gASgJUgpmcmllbmRs'
    'aWVzEhQKBWVuZW15GB8gASgJUgVlbmVteRIfCgtobHpfcmVtYXJrcxggIAEoCVIKaGx6UmVtYX'
    'JrcxIsCgV6bWlzdBghIAMoCzIWLm1lc2h0YXN0aWMuWk1pc3RFbnRyeVIFem1pc3QiqwEKClBy'
    'ZWNlZGVuY2USGgoWUHJlY2VkZW5jZV9VbnNwZWNpZmllZBAAEhUKEVByZWNlZGVuY2VfVXJnZW'
    '50EAESHQoZUHJlY2VkZW5jZV9VcmdlbnRTdXJnaWNhbBACEhcKE1ByZWNlZGVuY2VfUHJpb3Jp'
    'dHkQAxIWChJQcmVjZWRlbmNlX1JvdXRpbmUQBBIaChZQcmVjZWRlbmNlX0NvbnZlbmllbmNlEA'
    'UimwEKCkhsek1hcmtpbmcSGgoWSGx6TWFya2luZ19VbnNwZWNpZmllZBAAEhUKEUhsek1hcmtp'
    'bmdfUGFuZWxzEAESGQoVSGx6TWFya2luZ19QeXJvU2lnbmFsEAISFAoQSGx6TWFya2luZ19TbW'
    '9rZRADEhMKD0hsek1hcmtpbmdfTm9uZRAEEhQKEEhsek1hcmtpbmdfT3RoZXIQBSKSAQoIU2Vj'
    'dXJpdHkSGAoUU2VjdXJpdHlfVW5zcGVjaWZpZWQQABIUChBTZWN1cml0eV9Ob0VuZW15EAESGg'
    'oWU2VjdXJpdHlfUG9zc2libGVFbmVteRACEhgKFFNlY3VyaXR5X0VuZW15SW5BcmVhEAMSIAoc'
    'U2VjdXJpdHlfRW5lbXlJbkFybWVkQ29udGFjdBAE');

@$core.Deprecated('Use zMistEntryDescriptor instead')
const ZMistEntry$json = {
  '1': 'ZMistEntry',
  '2': [
    {'1': 'title', '3': 1, '4': 1, '5': 9, '10': 'title'},
    {'1': 'z', '3': 2, '4': 1, '5': 9, '10': 'z'},
    {'1': 'm', '3': 3, '4': 1, '5': 9, '10': 'm'},
    {'1': 'i', '3': 4, '4': 1, '5': 9, '10': 'i'},
    {'1': 's', '3': 5, '4': 1, '5': 9, '10': 's'},
    {'1': 't', '3': 6, '4': 1, '5': 9, '10': 't'},
  ],
};

/// Descriptor for `ZMistEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List zMistEntryDescriptor = $convert.base64Decode(
    'CgpaTWlzdEVudHJ5EhQKBXRpdGxlGAEgASgJUgV0aXRsZRIMCgF6GAIgASgJUgF6EgwKAW0YAy'
    'ABKAlSAW0SDAoBaRgEIAEoCVIBaRIMCgFzGAUgASgJUgFzEgwKAXQYBiABKAlSAXQ=');

@$core.Deprecated('Use emergencyAlertDescriptor instead')
const EmergencyAlert$json = {
  '1': 'EmergencyAlert',
  '2': [
    {
      '1': 'type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.EmergencyAlert.Type',
      '10': 'type'
    },
    {'1': 'authoring_uid', '3': 2, '4': 1, '5': 9, '10': 'authoringUid'},
    {
      '1': 'cancel_reference_uid',
      '3': 3,
      '4': 1,
      '5': 9,
      '10': 'cancelReferenceUid'
    },
  ],
  '4': [EmergencyAlert_Type$json],
};

@$core.Deprecated('Use emergencyAlertDescriptor instead')
const EmergencyAlert_Type$json = {
  '1': 'Type',
  '2': [
    {'1': 'Type_Unspecified', '2': 0},
    {'1': 'Type_Alert911', '2': 1},
    {'1': 'Type_RingTheBell', '2': 2},
    {'1': 'Type_InContact', '2': 3},
    {'1': 'Type_GeoFenceBreached', '2': 4},
    {'1': 'Type_Custom', '2': 5},
    {'1': 'Type_Cancel', '2': 6},
  ],
};

/// Descriptor for `EmergencyAlert`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List emergencyAlertDescriptor = $convert.base64Decode(
    'Cg5FbWVyZ2VuY3lBbGVydBIzCgR0eXBlGAEgASgOMh8ubWVzaHRhc3RpYy5FbWVyZ2VuY3lBbG'
    'VydC5UeXBlUgR0eXBlEiMKDWF1dGhvcmluZ191aWQYAiABKAlSDGF1dGhvcmluZ1VpZBIwChRj'
    'YW5jZWxfcmVmZXJlbmNlX3VpZBgDIAEoCVISY2FuY2VsUmVmZXJlbmNlVWlkIpYBCgRUeXBlEh'
    'QKEFR5cGVfVW5zcGVjaWZpZWQQABIRCg1UeXBlX0FsZXJ0OTExEAESFAoQVHlwZV9SaW5nVGhl'
    'QmVsbBACEhIKDlR5cGVfSW5Db250YWN0EAMSGQoVVHlwZV9HZW9GZW5jZUJyZWFjaGVkEAQSDw'
    'oLVHlwZV9DdXN0b20QBRIPCgtUeXBlX0NhbmNlbBAG');

@$core.Deprecated('Use taskRequestDescriptor instead')
const TaskRequest$json = {
  '1': 'TaskRequest',
  '2': [
    {'1': 'task_type', '3': 1, '4': 1, '5': 9, '10': 'taskType'},
    {'1': 'target_uid', '3': 2, '4': 1, '5': 9, '10': 'targetUid'},
    {'1': 'assignee_uid', '3': 3, '4': 1, '5': 9, '10': 'assigneeUid'},
    {
      '1': 'priority',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.TaskRequest.Priority',
      '10': 'priority'
    },
    {
      '1': 'status',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.TaskRequest.Status',
      '10': 'status'
    },
    {'1': 'note', '3': 6, '4': 1, '5': 9, '10': 'note'},
  ],
  '4': [TaskRequest_Priority$json, TaskRequest_Status$json],
};

@$core.Deprecated('Use taskRequestDescriptor instead')
const TaskRequest_Priority$json = {
  '1': 'Priority',
  '2': [
    {'1': 'Priority_Unspecified', '2': 0},
    {'1': 'Priority_Low', '2': 1},
    {'1': 'Priority_Normal', '2': 2},
    {'1': 'Priority_High', '2': 3},
    {'1': 'Priority_Critical', '2': 4},
  ],
};

@$core.Deprecated('Use taskRequestDescriptor instead')
const TaskRequest_Status$json = {
  '1': 'Status',
  '2': [
    {'1': 'Status_Unspecified', '2': 0},
    {'1': 'Status_Pending', '2': 1},
    {'1': 'Status_Acknowledged', '2': 2},
    {'1': 'Status_InProgress', '2': 3},
    {'1': 'Status_Completed', '2': 4},
    {'1': 'Status_Cancelled', '2': 5},
  ],
};

/// Descriptor for `TaskRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List taskRequestDescriptor = $convert.base64Decode(
    'CgtUYXNrUmVxdWVzdBIbCgl0YXNrX3R5cGUYASABKAlSCHRhc2tUeXBlEh0KCnRhcmdldF91aW'
    'QYAiABKAlSCXRhcmdldFVpZBIhCgxhc3NpZ25lZV91aWQYAyABKAlSC2Fzc2lnbmVlVWlkEjwK'
    'CHByaW9yaXR5GAQgASgOMiAubWVzaHRhc3RpYy5UYXNrUmVxdWVzdC5Qcmlvcml0eVIIcHJpb3'
    'JpdHkSNgoGc3RhdHVzGAUgASgOMh4ubWVzaHRhc3RpYy5UYXNrUmVxdWVzdC5TdGF0dXNSBnN0'
    'YXR1cxISCgRub3RlGAYgASgJUgRub3RlInUKCFByaW9yaXR5EhgKFFByaW9yaXR5X1Vuc3BlY2'
    'lmaWVkEAASEAoMUHJpb3JpdHlfTG93EAESEwoPUHJpb3JpdHlfTm9ybWFsEAISEQoNUHJpb3Jp'
    'dHlfSGlnaBADEhUKEVByaW9yaXR5X0NyaXRpY2FsEAQikAEKBlN0YXR1cxIWChJTdGF0dXNfVW'
    '5zcGVjaWZpZWQQABISCg5TdGF0dXNfUGVuZGluZxABEhcKE1N0YXR1c19BY2tub3dsZWRnZWQQ'
    'AhIVChFTdGF0dXNfSW5Qcm9ncmVzcxADEhQKEFN0YXR1c19Db21wbGV0ZWQQBBIUChBTdGF0dX'
    'NfQ2FuY2VsbGVkEAU=');

@$core.Deprecated('Use tAKEnvironmentDescriptor instead')
const TAKEnvironment$json = {
  '1': 'TAKEnvironment',
  '2': [
    {
      '1': 'temperature_c_x10',
      '3': 1,
      '4': 1,
      '5': 17,
      '10': 'temperatureCX10'
    },
    {
      '1': 'wind_direction_deg',
      '3': 2,
      '4': 1,
      '5': 13,
      '10': 'windDirectionDeg'
    },
    {'1': 'wind_speed_cm_s', '3': 3, '4': 1, '5': 13, '10': 'windSpeedCmS'},
  ],
};

/// Descriptor for `TAKEnvironment`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tAKEnvironmentDescriptor = $convert.base64Decode(
    'Cg5UQUtFbnZpcm9ubWVudBIqChF0ZW1wZXJhdHVyZV9jX3gxMBgBIAEoEVIPdGVtcGVyYXR1cm'
    'VDWDEwEiwKEndpbmRfZGlyZWN0aW9uX2RlZxgCIAEoDVIQd2luZERpcmVjdGlvbkRlZxIlCg93'
    'aW5kX3NwZWVkX2NtX3MYAyABKA1SDHdpbmRTcGVlZENtUw==');

@$core.Deprecated('Use sensorFovDescriptor instead')
const SensorFov$json = {
  '1': 'SensorFov',
  '2': [
    {
      '1': 'type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.SensorFov.SensorType',
      '10': 'type'
    },
    {'1': 'azimuth_deg', '3': 2, '4': 1, '5': 13, '10': 'azimuthDeg'},
    {
      '1': 'range_m',
      '3': 3,
      '4': 1,
      '5': 13,
      '9': 0,
      '10': 'rangeM',
      '17': true
    },
    {
      '1': 'fov_horizontal_deg',
      '3': 4,
      '4': 1,
      '5': 13,
      '10': 'fovHorizontalDeg'
    },
    {'1': 'fov_vertical_deg', '3': 5, '4': 1, '5': 13, '10': 'fovVerticalDeg'},
    {'1': 'elevation_deg', '3': 6, '4': 1, '5': 17, '10': 'elevationDeg'},
    {'1': 'roll_deg', '3': 7, '4': 1, '5': 17, '10': 'rollDeg'},
    {'1': 'model', '3': 8, '4': 1, '5': 9, '10': 'model'},
  ],
  '4': [SensorFov_SensorType$json],
  '8': [
    {'1': '_range_m'},
  ],
};

@$core.Deprecated('Use sensorFovDescriptor instead')
const SensorFov_SensorType$json = {
  '1': 'SensorType',
  '2': [
    {'1': 'SensorType_Unspecified', '2': 0},
    {'1': 'SensorType_Camera', '2': 1},
    {'1': 'SensorType_Thermal', '2': 2},
    {'1': 'SensorType_Laser', '2': 3},
    {'1': 'SensorType_Nvg', '2': 4},
    {'1': 'SensorType_Rf', '2': 5},
    {'1': 'SensorType_Other', '2': 6},
  ],
};

/// Descriptor for `SensorFov`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sensorFovDescriptor = $convert.base64Decode(
    'CglTZW5zb3JGb3YSNAoEdHlwZRgBIAEoDjIgLm1lc2h0YXN0aWMuU2Vuc29yRm92LlNlbnNvcl'
    'R5cGVSBHR5cGUSHwoLYXppbXV0aF9kZWcYAiABKA1SCmF6aW11dGhEZWcSHAoHcmFuZ2VfbRgD'
    'IAEoDUgAUgZyYW5nZU2IAQESLAoSZm92X2hvcml6b250YWxfZGVnGAQgASgNUhBmb3ZIb3Jpem'
    '9udGFsRGVnEigKEGZvdl92ZXJ0aWNhbF9kZWcYBSABKA1SDmZvdlZlcnRpY2FsRGVnEiMKDWVs'
    'ZXZhdGlvbl9kZWcYBiABKBFSDGVsZXZhdGlvbkRlZxIZCghyb2xsX2RlZxgHIAEoEVIHcm9sbE'
    'RlZxIUCgVtb2RlbBgIIAEoCVIFbW9kZWwiqgEKClNlbnNvclR5cGUSGgoWU2Vuc29yVHlwZV9V'
    'bnNwZWNpZmllZBAAEhUKEVNlbnNvclR5cGVfQ2FtZXJhEAESFgoSU2Vuc29yVHlwZV9UaGVybW'
    'FsEAISFAoQU2Vuc29yVHlwZV9MYXNlchADEhIKDlNlbnNvclR5cGVfTnZnEAQSEQoNU2Vuc29y'
    'VHlwZV9SZhAFEhQKEFNlbnNvclR5cGVfT3RoZXIQBkIKCghfcmFuZ2VfbQ==');

@$core.Deprecated('Use takTalkMessageDescriptor instead')
const TakTalkMessage$json = {
  '1': 'TakTalkMessage',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {'1': 'chatroom_id', '3': 2, '4': 1, '5': 9, '10': 'chatroomId'},
    {'1': 'lang', '3': 3, '4': 1, '5': 9, '10': 'lang'},
    {'1': 'from_voice', '3': 4, '4': 1, '5': 8, '10': 'fromVoice'},
  ],
};

/// Descriptor for `TakTalkMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List takTalkMessageDescriptor = $convert.base64Decode(
    'Cg5UYWtUYWxrTWVzc2FnZRISCgR0ZXh0GAEgASgJUgR0ZXh0Eh8KC2NoYXRyb29tX2lkGAIgAS'
    'gJUgpjaGF0cm9vbUlkEhIKBGxhbmcYAyABKAlSBGxhbmcSHQoKZnJvbV92b2ljZRgEIAEoCFIJ'
    'ZnJvbVZvaWNl');

@$core.Deprecated('Use takTalkRoomDataDescriptor instead')
const TakTalkRoomData$json = {
  '1': 'TakTalkRoomData',
  '2': [
    {
      '1': 'sender_callsign',
      '3': 1,
      '4': 1,
      '5': 9,
      '8': {'3': true},
      '10': 'senderCallsign',
    },
    {'1': 'room_id', '3': 2, '4': 1, '5': 9, '10': 'roomId'},
    {'1': 'room_name', '3': 3, '4': 1, '5': 9, '10': 'roomName'},
    {'1': 'participants', '3': 4, '4': 3, '5': 9, '10': 'participants'},
  ],
};

/// Descriptor for `TakTalkRoomData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List takTalkRoomDataDescriptor = $convert.base64Decode(
    'Cg9UYWtUYWxrUm9vbURhdGESKwoPc2VuZGVyX2NhbGxzaWduGAEgASgJQgIYAVIOc2VuZGVyQ2'
    'FsbHNpZ24SFwoHcm9vbV9pZBgCIAEoCVIGcm9vbUlkEhsKCXJvb21fbmFtZRgDIAEoCVIIcm9v'
    'bU5hbWUSIgoMcGFydGljaXBhbnRzGAQgAygJUgxwYXJ0aWNpcGFudHM=');

@$core.Deprecated('Use martiDescriptor instead')
const Marti$json = {
  '1': 'Marti',
  '2': [
    {'1': 'dest_callsign', '3': 1, '4': 3, '5': 9, '10': 'destCallsign'},
  ],
};

/// Descriptor for `Marti`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List martiDescriptor = $convert.base64Decode(
    'CgVNYXJ0aRIjCg1kZXN0X2NhbGxzaWduGAEgAygJUgxkZXN0Q2FsbHNpZ24=');

@$core.Deprecated('Use tAKPacketV2Descriptor instead')
const TAKPacketV2$json = {
  '1': 'TAKPacketV2',
  '2': [
    {
      '1': 'cot_type_id',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.CotType',
      '10': 'cotTypeId'
    },
    {
      '1': 'how',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.CotHow',
      '10': 'how'
    },
    {'1': 'callsign', '3': 3, '4': 1, '5': 9, '10': 'callsign'},
    {
      '1': 'team',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.Team',
      '10': 'team'
    },
    {
      '1': 'role',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.MemberRole',
      '10': 'role'
    },
    {'1': 'latitude_i', '3': 6, '4': 1, '5': 15, '10': 'latitudeI'},
    {'1': 'longitude_i', '3': 7, '4': 1, '5': 15, '10': 'longitudeI'},
    {'1': 'altitude', '3': 8, '4': 1, '5': 17, '10': 'altitude'},
    {'1': 'speed', '3': 9, '4': 1, '5': 13, '10': 'speed'},
    {'1': 'course', '3': 10, '4': 1, '5': 13, '10': 'course'},
    {'1': 'battery', '3': 11, '4': 1, '5': 13, '10': 'battery'},
    {
      '1': 'geo_src',
      '3': 12,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.GeoPointSource',
      '10': 'geoSrc'
    },
    {
      '1': 'alt_src',
      '3': 13,
      '4': 1,
      '5': 14,
      '6': '.meshtastic.GeoPointSource',
      '10': 'altSrc'
    },
    {'1': 'uid', '3': 14, '4': 1, '5': 9, '10': 'uid'},
    {'1': 'device_callsign', '3': 15, '4': 1, '5': 9, '10': 'deviceCallsign'},
    {'1': 'stale_seconds', '3': 16, '4': 1, '5': 13, '10': 'staleSeconds'},
    {'1': 'tak_version', '3': 17, '4': 1, '5': 9, '10': 'takVersion'},
    {'1': 'tak_device', '3': 18, '4': 1, '5': 9, '10': 'takDevice'},
    {'1': 'tak_platform', '3': 19, '4': 1, '5': 9, '10': 'takPlatform'},
    {'1': 'tak_os', '3': 20, '4': 1, '5': 9, '10': 'takOs'},
    {'1': 'endpoint', '3': 21, '4': 1, '5': 9, '10': 'endpoint'},
    {'1': 'phone', '3': 22, '4': 1, '5': 9, '10': 'phone'},
    {'1': 'cot_type_str', '3': 23, '4': 1, '5': 9, '10': 'cotTypeStr'},
    {'1': 'remarks', '3': 24, '4': 1, '5': 9, '10': 'remarks'},
    {
      '1': 'environment',
      '3': 25,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.TAKEnvironment',
      '9': 1,
      '10': 'environment',
      '17': true
    },
    {
      '1': 'sensor_fov',
      '3': 26,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.SensorFov',
      '9': 2,
      '10': 'sensorFov',
      '17': true
    },
    {
      '1': 'marti',
      '3': 29,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Marti',
      '9': 3,
      '10': 'marti',
      '17': true
    },
    {
      '1': 'chat',
      '3': 31,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.GeoChat',
      '9': 0,
      '10': 'chat'
    },
    {
      '1': 'aircraft',
      '3': 32,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.AircraftTrack',
      '9': 0,
      '10': 'aircraft'
    },
    {'1': 'raw_detail', '3': 33, '4': 1, '5': 12, '9': 0, '10': 'rawDetail'},
    {
      '1': 'shape',
      '3': 34,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.DrawnShape',
      '9': 0,
      '10': 'shape'
    },
    {
      '1': 'marker',
      '3': 35,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Marker',
      '9': 0,
      '10': 'marker'
    },
    {
      '1': 'rab',
      '3': 36,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.RangeAndBearing',
      '9': 0,
      '10': 'rab'
    },
    {
      '1': 'route',
      '3': 37,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.Route',
      '9': 0,
      '10': 'route'
    },
    {
      '1': 'casevac',
      '3': 38,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.CasevacReport',
      '9': 0,
      '10': 'casevac'
    },
    {
      '1': 'emergency',
      '3': 39,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.EmergencyAlert',
      '9': 0,
      '10': 'emergency'
    },
    {
      '1': 'task',
      '3': 40,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.TaskRequest',
      '9': 0,
      '10': 'task'
    },
    {
      '1': 'taktalk',
      '3': 41,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.TakTalkMessage',
      '9': 0,
      '10': 'taktalk'
    },
    {
      '1': 'taktalk_room',
      '3': 42,
      '4': 1,
      '5': 11,
      '6': '.meshtastic.TakTalkRoomData',
      '9': 0,
      '10': 'taktalkRoom'
    },
  ],
  '8': [
    {'1': 'payload_variant'},
    {'1': '_environment'},
    {'1': '_sensor_fov'},
    {'1': '_marti'},
  ],
  '9': [
    {'1': 27, '2': 28},
    {'1': 28, '2': 29},
    {'1': 30, '2': 31},
  ],
};

/// Descriptor for `TAKPacketV2`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tAKPacketV2Descriptor = $convert.base64Decode(
    'CgtUQUtQYWNrZXRWMhIzCgtjb3RfdHlwZV9pZBgBIAEoDjITLm1lc2h0YXN0aWMuQ290VHlwZV'
    'IJY290VHlwZUlkEiQKA2hvdxgCIAEoDjISLm1lc2h0YXN0aWMuQ290SG93UgNob3cSGgoIY2Fs'
    'bHNpZ24YAyABKAlSCGNhbGxzaWduEiQKBHRlYW0YBCABKA4yEC5tZXNodGFzdGljLlRlYW1SBH'
    'RlYW0SKgoEcm9sZRgFIAEoDjIWLm1lc2h0YXN0aWMuTWVtYmVyUm9sZVIEcm9sZRIdCgpsYXRp'
    'dHVkZV9pGAYgASgPUglsYXRpdHVkZUkSHwoLbG9uZ2l0dWRlX2kYByABKA9SCmxvbmdpdHVkZU'
    'kSGgoIYWx0aXR1ZGUYCCABKBFSCGFsdGl0dWRlEhQKBXNwZWVkGAkgASgNUgVzcGVlZBIWCgZj'
    'b3Vyc2UYCiABKA1SBmNvdXJzZRIYCgdiYXR0ZXJ5GAsgASgNUgdiYXR0ZXJ5EjMKB2dlb19zcm'
    'MYDCABKA4yGi5tZXNodGFzdGljLkdlb1BvaW50U291cmNlUgZnZW9TcmMSMwoHYWx0X3NyYxgN'
    'IAEoDjIaLm1lc2h0YXN0aWMuR2VvUG9pbnRTb3VyY2VSBmFsdFNyYxIQCgN1aWQYDiABKAlSA3'
    'VpZBInCg9kZXZpY2VfY2FsbHNpZ24YDyABKAlSDmRldmljZUNhbGxzaWduEiMKDXN0YWxlX3Nl'
    'Y29uZHMYECABKA1SDHN0YWxlU2Vjb25kcxIfCgt0YWtfdmVyc2lvbhgRIAEoCVIKdGFrVmVyc2'
    'lvbhIdCgp0YWtfZGV2aWNlGBIgASgJUgl0YWtEZXZpY2USIQoMdGFrX3BsYXRmb3JtGBMgASgJ'
    'Ugt0YWtQbGF0Zm9ybRIVCgZ0YWtfb3MYFCABKAlSBXRha09zEhoKCGVuZHBvaW50GBUgASgJUg'
    'hlbmRwb2ludBIUCgVwaG9uZRgWIAEoCVIFcGhvbmUSIAoMY290X3R5cGVfc3RyGBcgASgJUgpj'
    'b3RUeXBlU3RyEhgKB3JlbWFya3MYGCABKAlSB3JlbWFya3MSQQoLZW52aXJvbm1lbnQYGSABKA'
    'syGi5tZXNodGFzdGljLlRBS0Vudmlyb25tZW50SAFSC2Vudmlyb25tZW50iAEBEjkKCnNlbnNv'
    'cl9mb3YYGiABKAsyFS5tZXNodGFzdGljLlNlbnNvckZvdkgCUglzZW5zb3JGb3aIAQESLAoFbW'
    'FydGkYHSABKAsyES5tZXNodGFzdGljLk1hcnRpSANSBW1hcnRpiAEBEikKBGNoYXQYHyABKAsy'
    'Ey5tZXNodGFzdGljLkdlb0NoYXRIAFIEY2hhdBI3CghhaXJjcmFmdBggIAEoCzIZLm1lc2h0YX'
    'N0aWMuQWlyY3JhZnRUcmFja0gAUghhaXJjcmFmdBIfCgpyYXdfZGV0YWlsGCEgASgMSABSCXJh'
    'd0RldGFpbBIuCgVzaGFwZRgiIAEoCzIWLm1lc2h0YXN0aWMuRHJhd25TaGFwZUgAUgVzaGFwZR'
    'IsCgZtYXJrZXIYIyABKAsyEi5tZXNodGFzdGljLk1hcmtlckgAUgZtYXJrZXISLwoDcmFiGCQg'
    'ASgLMhsubWVzaHRhc3RpYy5SYW5nZUFuZEJlYXJpbmdIAFIDcmFiEikKBXJvdXRlGCUgASgLMh'
    'EubWVzaHRhc3RpYy5Sb3V0ZUgAUgVyb3V0ZRI1CgdjYXNldmFjGCYgASgLMhkubWVzaHRhc3Rp'
    'Yy5DYXNldmFjUmVwb3J0SABSB2Nhc2V2YWMSOgoJZW1lcmdlbmN5GCcgASgLMhoubWVzaHRhc3'
    'RpYy5FbWVyZ2VuY3lBbGVydEgAUgllbWVyZ2VuY3kSLQoEdGFzaxgoIAEoCzIXLm1lc2h0YXN0'
    'aWMuVGFza1JlcXVlc3RIAFIEdGFzaxI2Cgd0YWt0YWxrGCkgASgLMhoubWVzaHRhc3RpYy5UYW'
    'tUYWxrTWVzc2FnZUgAUgd0YWt0YWxrEkAKDHRha3RhbGtfcm9vbRgqIAEoCzIbLm1lc2h0YXN0'
    'aWMuVGFrVGFsa1Jvb21EYXRhSABSC3Rha3RhbGtSb29tQhEKD3BheWxvYWRfdmFyaWFudEIOCg'
    'xfZW52aXJvbm1lbnRCDQoLX3NlbnNvcl9mb3ZCCAoGX21hcnRpSgQIGxAcSgQIHBAdSgQIHhAf');
