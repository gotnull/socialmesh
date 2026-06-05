// This is a generated file - do not edit.
//
// Generated from meshtastic/atak.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class Team extends $pb.ProtobufEnum {
  ///
  ///  Unspecifed
  static const Team Unspecifed_Color =
      Team._(0, _omitEnumNames ? '' : 'Unspecifed_Color');

  ///
  ///  White
  static const Team White = Team._(1, _omitEnumNames ? '' : 'White');

  ///
  ///  Yellow
  static const Team Yellow = Team._(2, _omitEnumNames ? '' : 'Yellow');

  ///
  ///  Orange
  static const Team Orange = Team._(3, _omitEnumNames ? '' : 'Orange');

  ///
  ///  Magenta
  static const Team Magenta = Team._(4, _omitEnumNames ? '' : 'Magenta');

  ///
  ///  Red
  static const Team Red = Team._(5, _omitEnumNames ? '' : 'Red');

  ///
  ///  Maroon
  static const Team Maroon = Team._(6, _omitEnumNames ? '' : 'Maroon');

  ///
  ///  Purple
  static const Team Purple = Team._(7, _omitEnumNames ? '' : 'Purple');

  ///
  ///  Dark Blue
  static const Team Dark_Blue = Team._(8, _omitEnumNames ? '' : 'Dark_Blue');

  ///
  ///  Blue
  static const Team Blue = Team._(9, _omitEnumNames ? '' : 'Blue');

  ///
  ///  Cyan
  static const Team Cyan = Team._(10, _omitEnumNames ? '' : 'Cyan');

  ///
  ///  Teal
  static const Team Teal = Team._(11, _omitEnumNames ? '' : 'Teal');

  ///
  ///  Green
  static const Team Green = Team._(12, _omitEnumNames ? '' : 'Green');

  ///
  ///  Dark Green
  static const Team Dark_Green = Team._(13, _omitEnumNames ? '' : 'Dark_Green');

  ///
  ///  Brown
  static const Team Brown = Team._(14, _omitEnumNames ? '' : 'Brown');

  static const $core.List<Team> values = <Team>[
    Unspecifed_Color,
    White,
    Yellow,
    Orange,
    Magenta,
    Red,
    Maroon,
    Purple,
    Dark_Blue,
    Blue,
    Cyan,
    Teal,
    Green,
    Dark_Green,
    Brown,
  ];

  static final $core.List<Team?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 14);
  static Team? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Team._(super.value, super.name);
}

///
///  Role of the group member
class MemberRole extends $pb.ProtobufEnum {
  ///
  ///  Unspecifed
  static const MemberRole Unspecifed =
      MemberRole._(0, _omitEnumNames ? '' : 'Unspecifed');

  ///
  ///  Team Member
  static const MemberRole TeamMember =
      MemberRole._(1, _omitEnumNames ? '' : 'TeamMember');

  ///
  ///  Team Lead
  static const MemberRole TeamLead =
      MemberRole._(2, _omitEnumNames ? '' : 'TeamLead');

  ///
  ///  Headquarters
  static const MemberRole HQ = MemberRole._(3, _omitEnumNames ? '' : 'HQ');

  ///
  ///  Airsoft enthusiast
  static const MemberRole Sniper =
      MemberRole._(4, _omitEnumNames ? '' : 'Sniper');

  ///
  ///  Medic
  static const MemberRole Medic =
      MemberRole._(5, _omitEnumNames ? '' : 'Medic');

  ///
  ///  ForwardObserver
  static const MemberRole ForwardObserver =
      MemberRole._(6, _omitEnumNames ? '' : 'ForwardObserver');

  ///
  ///  Radio Telephone Operator
  static const MemberRole RTO = MemberRole._(7, _omitEnumNames ? '' : 'RTO');

  ///
  ///  Doggo
  static const MemberRole K9 = MemberRole._(8, _omitEnumNames ? '' : 'K9');

  static const $core.List<MemberRole> values = <MemberRole>[
    Unspecifed,
    TeamMember,
    TeamLead,
    HQ,
    Sniper,
    Medic,
    ForwardObserver,
    RTO,
    K9,
  ];

  static final $core.List<MemberRole?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 8);
  static MemberRole? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const MemberRole._(super.value, super.name);
}

///
///  CoT how field values.
///  Represents how the coordinates were generated.
class CotHow extends $pb.ProtobufEnum {
  ///
  ///  Unspecified
  static const CotHow CotHow_Unspecified =
      CotHow._(0, _omitEnumNames ? '' : 'CotHow_Unspecified');

  ///
  ///  Human entered
  static const CotHow CotHow_h_e =
      CotHow._(1, _omitEnumNames ? '' : 'CotHow_h_e');

  ///
  ///  Machine generated
  static const CotHow CotHow_m_g =
      CotHow._(2, _omitEnumNames ? '' : 'CotHow_m_g');

  ///
  ///  Human GPS/INS derived
  static const CotHow CotHow_h_g_i_g_o =
      CotHow._(3, _omitEnumNames ? '' : 'CotHow_h_g_i_g_o');

  ///
  ///  Machine relayed (imported from another system/gateway)
  static const CotHow CotHow_m_r =
      CotHow._(4, _omitEnumNames ? '' : 'CotHow_m_r');

  ///
  ///  Machine fused (corroborated from multiple sources)
  static const CotHow CotHow_m_f =
      CotHow._(5, _omitEnumNames ? '' : 'CotHow_m_f');

  ///
  ///  Machine predicted
  static const CotHow CotHow_m_p =
      CotHow._(6, _omitEnumNames ? '' : 'CotHow_m_p');

  ///
  ///  Machine simulated
  static const CotHow CotHow_m_s =
      CotHow._(7, _omitEnumNames ? '' : 'CotHow_m_s');

  static const $core.List<CotHow> values = <CotHow>[
    CotHow_Unspecified,
    CotHow_h_e,
    CotHow_m_g,
    CotHow_h_g_i_g_o,
    CotHow_m_r,
    CotHow_m_f,
    CotHow_m_p,
    CotHow_m_s,
  ];

  static final $core.List<CotHow?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 7);
  static CotHow? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const CotHow._(super.value, super.name);
}

///
///  Well-known CoT event types.
///  When the type is known, use the enum value for efficient encoding.
///  For unknown types, set cot_type_id to CotType_Other and populate cot_type_str.
class CotType extends $pb.ProtobufEnum {
  ///
  ///  Unknown or unmapped type, use cot_type_str
  static const CotType CotType_Other =
      CotType._(0, _omitEnumNames ? '' : 'CotType_Other');

  ///
  ///  a-f-G-U-C: Friendly ground unit combat
  static const CotType CotType_a_f_G_U_C =
      CotType._(1, _omitEnumNames ? '' : 'CotType_a_f_G_U_C');

  ///
  ///  a-f-G-U-C-I: Friendly ground unit combat infantry
  static const CotType CotType_a_f_G_U_C_I =
      CotType._(2, _omitEnumNames ? '' : 'CotType_a_f_G_U_C_I');

  ///
  ///  a-n-A-C-F: Neutral aircraft civilian fixed-wing
  static const CotType CotType_a_n_A_C_F =
      CotType._(3, _omitEnumNames ? '' : 'CotType_a_n_A_C_F');

  ///
  ///  a-n-A-C-H: Neutral aircraft civilian helicopter
  static const CotType CotType_a_n_A_C_H =
      CotType._(4, _omitEnumNames ? '' : 'CotType_a_n_A_C_H');

  ///
  ///  a-n-A-C: Neutral aircraft civilian
  static const CotType CotType_a_n_A_C =
      CotType._(5, _omitEnumNames ? '' : 'CotType_a_n_A_C');

  ///
  ///  a-f-A-M-H: Friendly aircraft military helicopter
  static const CotType CotType_a_f_A_M_H =
      CotType._(6, _omitEnumNames ? '' : 'CotType_a_f_A_M_H');

  ///
  ///  a-f-A-M: Friendly aircraft military
  static const CotType CotType_a_f_A_M =
      CotType._(7, _omitEnumNames ? '' : 'CotType_a_f_A_M');

  ///
  ///  a-f-A-M-F-F: Friendly aircraft military fixed-wing fighter
  static const CotType CotType_a_f_A_M_F_F =
      CotType._(8, _omitEnumNames ? '' : 'CotType_a_f_A_M_F_F');

  ///
  ///  a-f-A-M-H-A: Friendly aircraft military helicopter attack
  static const CotType CotType_a_f_A_M_H_A =
      CotType._(9, _omitEnumNames ? '' : 'CotType_a_f_A_M_H_A');

  ///
  ///  a-f-A-M-H-U-M: Friendly aircraft military helicopter utility medium
  static const CotType CotType_a_f_A_M_H_U_M =
      CotType._(10, _omitEnumNames ? '' : 'CotType_a_f_A_M_H_U_M');

  ///
  ///  a-h-A-M-F-F: Hostile aircraft military fixed-wing fighter
  static const CotType CotType_a_h_A_M_F_F =
      CotType._(11, _omitEnumNames ? '' : 'CotType_a_h_A_M_F_F');

  ///
  ///  a-h-A-M-H-A: Hostile aircraft military helicopter attack
  static const CotType CotType_a_h_A_M_H_A =
      CotType._(12, _omitEnumNames ? '' : 'CotType_a_h_A_M_H_A');

  ///
  ///  a-u-A-C: Unknown aircraft civilian
  static const CotType CotType_a_u_A_C =
      CotType._(13, _omitEnumNames ? '' : 'CotType_a_u_A_C');

  ///
  ///  t-x-d-d: Tasking delete/disconnect
  static const CotType CotType_t_x_d_d =
      CotType._(14, _omitEnumNames ? '' : 'CotType_t_x_d_d');

  ///
  ///  a-f-G-E-S-E: Friendly ground equipment sensor
  static const CotType CotType_a_f_G_E_S_E =
      CotType._(15, _omitEnumNames ? '' : 'CotType_a_f_G_E_S_E');

  ///
  ///  a-f-G-E-V-C: Friendly ground equipment vehicle
  static const CotType CotType_a_f_G_E_V_C =
      CotType._(16, _omitEnumNames ? '' : 'CotType_a_f_G_E_V_C');

  ///
  ///  a-f-S: Friendly sea
  static const CotType CotType_a_f_S =
      CotType._(17, _omitEnumNames ? '' : 'CotType_a_f_S');

  ///
  ///  a-f-A-M-F: Friendly aircraft military fixed-wing
  static const CotType CotType_a_f_A_M_F =
      CotType._(18, _omitEnumNames ? '' : 'CotType_a_f_A_M_F');

  ///
  ///  a-f-A-M-F-C-H: Friendly aircraft military fixed-wing cargo heavy
  static const CotType CotType_a_f_A_M_F_C_H =
      CotType._(19, _omitEnumNames ? '' : 'CotType_a_f_A_M_F_C_H');

  ///
  ///  a-f-A-M-F-U-L: Friendly aircraft military fixed-wing utility light
  static const CotType CotType_a_f_A_M_F_U_L =
      CotType._(20, _omitEnumNames ? '' : 'CotType_a_f_A_M_F_U_L');

  ///
  ///  a-f-A-M-F-L: Friendly aircraft military fixed-wing liaison
  static const CotType CotType_a_f_A_M_F_L =
      CotType._(21, _omitEnumNames ? '' : 'CotType_a_f_A_M_F_L');

  ///
  ///  a-f-A-M-F-P: Friendly aircraft military fixed-wing patrol
  static const CotType CotType_a_f_A_M_F_P =
      CotType._(22, _omitEnumNames ? '' : 'CotType_a_f_A_M_F_P');

  ///
  ///  a-f-A-C-H: Friendly aircraft civilian helicopter
  static const CotType CotType_a_f_A_C_H =
      CotType._(23, _omitEnumNames ? '' : 'CotType_a_f_A_C_H');

  ///
  ///  a-n-A-M-F-Q: Neutral aircraft military fixed-wing drone
  static const CotType CotType_a_n_A_M_F_Q =
      CotType._(24, _omitEnumNames ? '' : 'CotType_a_n_A_M_F_Q');

  ///
  ///  b-t-f: GeoChat message
  static const CotType CotType_b_t_f =
      CotType._(25, _omitEnumNames ? '' : 'CotType_b_t_f');

  ///
  ///  b-r-f-h-c: CASEVAC/MEDEVAC report
  static const CotType CotType_b_r_f_h_c =
      CotType._(26, _omitEnumNames ? '' : 'CotType_b_r_f_h_c');

  ///
  ///  b-a-o-pan: Ring the bell / alert all
  static const CotType CotType_b_a_o_pan =
      CotType._(27, _omitEnumNames ? '' : 'CotType_b_a_o_pan');

  ///
  ///  b-a-o-opn: Troops in contact
  static const CotType CotType_b_a_o_opn =
      CotType._(28, _omitEnumNames ? '' : 'CotType_b_a_o_opn');

  ///
  ///  b-a-o-can: Cancel alert
  static const CotType CotType_b_a_o_can =
      CotType._(29, _omitEnumNames ? '' : 'CotType_b_a_o_can');

  ///
  ///  b-a-o-tbl: 911 alert
  static const CotType CotType_b_a_o_tbl =
      CotType._(30, _omitEnumNames ? '' : 'CotType_b_a_o_tbl');

  ///
  ///  b-a-g: Geofence breach alert
  static const CotType CotType_b_a_g =
      CotType._(31, _omitEnumNames ? '' : 'CotType_b_a_g');

  ///
  ///  a-f-G: Friendly ground (generic)
  static const CotType CotType_a_f_G =
      CotType._(32, _omitEnumNames ? '' : 'CotType_a_f_G');

  ///
  ///  a-f-G-U: Friendly ground unit (generic)
  static const CotType CotType_a_f_G_U =
      CotType._(33, _omitEnumNames ? '' : 'CotType_a_f_G_U');

  ///
  ///  a-h-G: Hostile ground (generic)
  static const CotType CotType_a_h_G =
      CotType._(34, _omitEnumNames ? '' : 'CotType_a_h_G');

  ///
  ///  a-u-G: Unknown ground (generic)
  static const CotType CotType_a_u_G =
      CotType._(35, _omitEnumNames ? '' : 'CotType_a_u_G');

  ///
  ///  a-n-G: Neutral ground (generic)
  static const CotType CotType_a_n_G =
      CotType._(36, _omitEnumNames ? '' : 'CotType_a_n_G');

  ///
  ///  b-m-r: Route
  static const CotType CotType_b_m_r =
      CotType._(37, _omitEnumNames ? '' : 'CotType_b_m_r');

  ///
  ///  b-m-p-w: Route waypoint
  static const CotType CotType_b_m_p_w =
      CotType._(38, _omitEnumNames ? '' : 'CotType_b_m_p_w');

  ///
  ///  b-m-p-s-p-i: Self-position marker
  static const CotType CotType_b_m_p_s_p_i =
      CotType._(39, _omitEnumNames ? '' : 'CotType_b_m_p_s_p_i');

  ///
  ///  u-d-f: Freeform shape (line/polygon)
  static const CotType CotType_u_d_f =
      CotType._(40, _omitEnumNames ? '' : 'CotType_u_d_f');

  ///
  ///  u-d-r: Rectangle
  static const CotType CotType_u_d_r =
      CotType._(41, _omitEnumNames ? '' : 'CotType_u_d_r');

  ///
  ///  u-d-c-c: Circle
  static const CotType CotType_u_d_c_c =
      CotType._(42, _omitEnumNames ? '' : 'CotType_u_d_c_c');

  ///
  ///  u-rb-a: Range/bearing line
  static const CotType CotType_u_rb_a =
      CotType._(43, _omitEnumNames ? '' : 'CotType_u_rb_a');

  ///
  ///  a-h-A: Hostile aircraft (generic)
  static const CotType CotType_a_h_A =
      CotType._(44, _omitEnumNames ? '' : 'CotType_a_h_A');

  ///
  ///  a-u-A: Unknown aircraft (generic)
  static const CotType CotType_a_u_A =
      CotType._(45, _omitEnumNames ? '' : 'CotType_a_u_A');

  ///
  ///  a-f-A-M-H-Q: Friendly aircraft military helicopter observation
  static const CotType CotType_a_f_A_M_H_Q =
      CotType._(46, _omitEnumNames ? '' : 'CotType_a_f_A_M_H_Q');

  ///
  ///  a-f-A-C-F: Friendly aircraft civilian fixed-wing
  static const CotType CotType_a_f_A_C_F =
      CotType._(47, _omitEnumNames ? '' : 'CotType_a_f_A_C_F');

  ///
  ///  a-f-A-C: Friendly aircraft civilian (generic)
  static const CotType CotType_a_f_A_C =
      CotType._(48, _omitEnumNames ? '' : 'CotType_a_f_A_C');

  ///
  ///  a-f-A-C-L: Friendly aircraft civilian lighter-than-air
  static const CotType CotType_a_f_A_C_L =
      CotType._(49, _omitEnumNames ? '' : 'CotType_a_f_A_C_L');

  ///
  ///  a-f-A: Friendly aircraft (generic)
  static const CotType CotType_a_f_A =
      CotType._(50, _omitEnumNames ? '' : 'CotType_a_f_A');

  ///
  ///  a-f-A-M-H-C: Friendly aircraft military helicopter cargo
  static const CotType CotType_a_f_A_M_H_C =
      CotType._(51, _omitEnumNames ? '' : 'CotType_a_f_A_M_H_C');

  ///
  ///  a-n-A-M-F-F: Neutral aircraft military fixed-wing fighter
  static const CotType CotType_a_n_A_M_F_F =
      CotType._(52, _omitEnumNames ? '' : 'CotType_a_n_A_M_F_F');

  ///
  ///  a-u-A-C-F: Unknown aircraft civilian fixed-wing
  static const CotType CotType_a_u_A_C_F =
      CotType._(53, _omitEnumNames ? '' : 'CotType_a_u_A_C_F');

  ///
  ///  a-f-G-U-C-F-T-A: Friendly ground unit combat forces theater aviation
  static const CotType CotType_a_f_G_U_C_F_T_A =
      CotType._(54, _omitEnumNames ? '' : 'CotType_a_f_G_U_C_F_T_A');

  ///
  ///  a-f-G-U-C-V-S: Friendly ground unit combat vehicle support
  static const CotType CotType_a_f_G_U_C_V_S =
      CotType._(55, _omitEnumNames ? '' : 'CotType_a_f_G_U_C_V_S');

  ///
  ///  a-f-G-U-C-R-X: Friendly ground unit combat reconnaissance exploitation
  static const CotType CotType_a_f_G_U_C_R_X =
      CotType._(56, _omitEnumNames ? '' : 'CotType_a_f_G_U_C_R_X');

  ///
  ///  a-f-G-U-C-I-Z: Friendly ground unit combat infantry mechanized
  static const CotType CotType_a_f_G_U_C_I_Z =
      CotType._(57, _omitEnumNames ? '' : 'CotType_a_f_G_U_C_I_Z');

  ///
  ///  a-f-G-U-C-E-C-W: Friendly ground unit combat engineer construction wheeled
  static const CotType CotType_a_f_G_U_C_E_C_W =
      CotType._(58, _omitEnumNames ? '' : 'CotType_a_f_G_U_C_E_C_W');

  ///
  ///  a-f-G-U-C-I-L: Friendly ground unit combat infantry light
  static const CotType CotType_a_f_G_U_C_I_L =
      CotType._(59, _omitEnumNames ? '' : 'CotType_a_f_G_U_C_I_L');

  ///
  ///  a-f-G-U-C-R-O: Friendly ground unit combat reconnaissance other
  static const CotType CotType_a_f_G_U_C_R_O =
      CotType._(60, _omitEnumNames ? '' : 'CotType_a_f_G_U_C_R_O');

  ///
  ///  a-f-G-U-C-R-V: Friendly ground unit combat reconnaissance cavalry
  static const CotType CotType_a_f_G_U_C_R_V =
      CotType._(61, _omitEnumNames ? '' : 'CotType_a_f_G_U_C_R_V');

  ///
  ///  a-f-G-U-H: Friendly ground unit headquarters
  static const CotType CotType_a_f_G_U_H =
      CotType._(62, _omitEnumNames ? '' : 'CotType_a_f_G_U_H');

  ///
  ///  a-f-G-U-U-M-S-E: Friendly ground unit support medical surgical evacuation
  static const CotType CotType_a_f_G_U_U_M_S_E =
      CotType._(63, _omitEnumNames ? '' : 'CotType_a_f_G_U_U_M_S_E');

  ///
  ///  a-f-G-U-S-M-C: Friendly ground unit support maintenance collection
  static const CotType CotType_a_f_G_U_S_M_C =
      CotType._(64, _omitEnumNames ? '' : 'CotType_a_f_G_U_S_M_C');

  ///
  ///  a-f-G-E-S: Friendly ground equipment sensor (generic)
  static const CotType CotType_a_f_G_E_S =
      CotType._(65, _omitEnumNames ? '' : 'CotType_a_f_G_E_S');

  ///
  ///  a-f-G-E: Friendly ground equipment (generic)
  static const CotType CotType_a_f_G_E =
      CotType._(66, _omitEnumNames ? '' : 'CotType_a_f_G_E');

  ///
  ///  a-f-G-E-V-C-U: Friendly ground equipment vehicle utility
  static const CotType CotType_a_f_G_E_V_C_U =
      CotType._(67, _omitEnumNames ? '' : 'CotType_a_f_G_E_V_C_U');

  ///
  ///  a-f-G-E-V-C-ps: Friendly ground equipment vehicle public safety
  static const CotType CotType_a_f_G_E_V_C_ps =
      CotType._(68, _omitEnumNames ? '' : 'CotType_a_f_G_E_V_C_ps');

  ///
  ///  a-u-G-E-V: Unknown ground equipment vehicle
  static const CotType CotType_a_u_G_E_V =
      CotType._(69, _omitEnumNames ? '' : 'CotType_a_u_G_E_V');

  ///
  ///  a-f-S-N-N-R: Friendly sea surface non-naval rescue
  static const CotType CotType_a_f_S_N_N_R =
      CotType._(70, _omitEnumNames ? '' : 'CotType_a_f_S_N_N_R');

  ///
  ///  a-f-F-B: Friendly force boundary
  static const CotType CotType_a_f_F_B =
      CotType._(71, _omitEnumNames ? '' : 'CotType_a_f_F_B');

  ///
  ///  b-m-p-s-p-loc: Self-position location marker
  static const CotType CotType_b_m_p_s_p_loc =
      CotType._(72, _omitEnumNames ? '' : 'CotType_b_m_p_s_p_loc');

  ///
  ///  b-i-v: Imagery/video
  static const CotType CotType_b_i_v =
      CotType._(73, _omitEnumNames ? '' : 'CotType_b_i_v');

  ///
  ///  b-f-t-r: File transfer request
  static const CotType CotType_b_f_t_r =
      CotType._(74, _omitEnumNames ? '' : 'CotType_b_f_t_r');

  ///
  ///  b-f-t-a: File transfer acknowledgment
  static const CotType CotType_b_f_t_a =
      CotType._(75, _omitEnumNames ? '' : 'CotType_b_f_t_a');

  ///
  ///  u-d-f-m: Freehand telestration / annotation. Anchor at event point,
  ///  geometry carried via DrawnShape.vertices. May be truncated to
  ///  MAX_VERTICES by the sender.
  static const CotType CotType_u_d_f_m =
      CotType._(76, _omitEnumNames ? '' : 'CotType_u_d_f_m');

  ///
  ///  u-d-p: Closed polygon. Geometry carried via DrawnShape.vertices,
  ///  implicitly closed (receiver duplicates first vertex as needed).
  static const CotType CotType_u_d_p =
      CotType._(77, _omitEnumNames ? '' : 'CotType_u_d_p');

  ///
  ///  b-m-p-s-m: Spot map marker (colored dot at a point of interest).
  static const CotType CotType_b_m_p_s_m =
      CotType._(78, _omitEnumNames ? '' : 'CotType_b_m_p_s_m');

  ///
  ///  b-m-p-c: Checkpoint (intermediate route control point).
  static const CotType CotType_b_m_p_c =
      CotType._(79, _omitEnumNames ? '' : 'CotType_b_m_p_c');

  ///
  ///  u-r-b-c-c: Ranging circle (range rings centered on the event point).
  static const CotType CotType_u_r_b_c_c =
      CotType._(80, _omitEnumNames ? '' : 'CotType_u_r_b_c_c');

  ///
  ///  u-r-b-bullseye: Bullseye with configurable range rings and bearing
  ///  reference (magnetic / true / grid).
  static const CotType CotType_u_r_b_bullseye =
      CotType._(81, _omitEnumNames ? '' : 'CotType_u_r_b_bullseye');

  ///
  ///  a-f-G-E-V-A: Friendly armored vehicle, user-selectable self PLI.
  static const CotType CotType_a_f_G_E_V_A =
      CotType._(82, _omitEnumNames ? '' : 'CotType_a_f_G_E_V_A');

  ///
  ///  a-n-A: Neutral aircraft (friendly/hostile/unknown already present).
  static const CotType CotType_a_n_A =
      CotType._(83, _omitEnumNames ? '' : 'CotType_a_n_A');

  /// --- 2525 quick-drop: artillery (4) ----------------------------------
  static const CotType CotType_a_u_G_U_C_F =
      CotType._(84, _omitEnumNames ? '' : 'CotType_a_u_G_U_C_F');
  static const CotType CotType_a_n_G_U_C_F =
      CotType._(85, _omitEnumNames ? '' : 'CotType_a_n_G_U_C_F');
  static const CotType CotType_a_h_G_U_C_F =
      CotType._(86, _omitEnumNames ? '' : 'CotType_a_h_G_U_C_F');
  static const CotType CotType_a_f_G_U_C_F =
      CotType._(87, _omitEnumNames ? '' : 'CotType_a_f_G_U_C_F');

  /// --- 2525 quick-drop: building (4) -----------------------------------
  static const CotType CotType_a_u_G_I =
      CotType._(88, _omitEnumNames ? '' : 'CotType_a_u_G_I');
  static const CotType CotType_a_n_G_I =
      CotType._(89, _omitEnumNames ? '' : 'CotType_a_n_G_I');
  static const CotType CotType_a_h_G_I =
      CotType._(90, _omitEnumNames ? '' : 'CotType_a_h_G_I');
  static const CotType CotType_a_f_G_I =
      CotType._(91, _omitEnumNames ? '' : 'CotType_a_f_G_I');

  /// --- 2525 quick-drop: mine (4) ---------------------------------------
  static const CotType CotType_a_u_G_E_X_M =
      CotType._(92, _omitEnumNames ? '' : 'CotType_a_u_G_E_X_M');
  static const CotType CotType_a_n_G_E_X_M =
      CotType._(93, _omitEnumNames ? '' : 'CotType_a_n_G_E_X_M');
  static const CotType CotType_a_h_G_E_X_M =
      CotType._(94, _omitEnumNames ? '' : 'CotType_a_h_G_E_X_M');
  static const CotType CotType_a_f_G_E_X_M =
      CotType._(95, _omitEnumNames ? '' : 'CotType_a_f_G_E_X_M');

  /// --- 2525 quick-drop: ship (3; a-f-S already at 17) ------------------
  static const CotType CotType_a_u_S =
      CotType._(96, _omitEnumNames ? '' : 'CotType_a_u_S');
  static const CotType CotType_a_n_S =
      CotType._(97, _omitEnumNames ? '' : 'CotType_a_n_S');
  static const CotType CotType_a_h_S =
      CotType._(98, _omitEnumNames ? '' : 'CotType_a_h_S');

  /// --- 2525 quick-drop: sniper (4) -------------------------------------
  static const CotType CotType_a_u_G_U_C_I_d =
      CotType._(99, _omitEnumNames ? '' : 'CotType_a_u_G_U_C_I_d');
  static const CotType CotType_a_n_G_U_C_I_d =
      CotType._(100, _omitEnumNames ? '' : 'CotType_a_n_G_U_C_I_d');
  static const CotType CotType_a_h_G_U_C_I_d =
      CotType._(101, _omitEnumNames ? '' : 'CotType_a_h_G_U_C_I_d');
  static const CotType CotType_a_f_G_U_C_I_d =
      CotType._(102, _omitEnumNames ? '' : 'CotType_a_f_G_U_C_I_d');

  /// --- 2525 quick-drop: tank (4) ---------------------------------------
  static const CotType CotType_a_u_G_E_V_A_T =
      CotType._(103, _omitEnumNames ? '' : 'CotType_a_u_G_E_V_A_T');
  static const CotType CotType_a_n_G_E_V_A_T =
      CotType._(104, _omitEnumNames ? '' : 'CotType_a_n_G_E_V_A_T');
  static const CotType CotType_a_h_G_E_V_A_T =
      CotType._(105, _omitEnumNames ? '' : 'CotType_a_h_G_E_V_A_T');
  static const CotType CotType_a_f_G_E_V_A_T =
      CotType._(106, _omitEnumNames ? '' : 'CotType_a_f_G_E_V_A_T');

  /// --- 2525 quick-drop: troops (3; a-f-G-U-C-I already at 2) -----------
  static const CotType CotType_a_u_G_U_C_I =
      CotType._(107, _omitEnumNames ? '' : 'CotType_a_u_G_U_C_I');
  static const CotType CotType_a_n_G_U_C_I =
      CotType._(108, _omitEnumNames ? '' : 'CotType_a_n_G_U_C_I');
  static const CotType CotType_a_h_G_U_C_I =
      CotType._(109, _omitEnumNames ? '' : 'CotType_a_h_G_U_C_I');

  /// --- 2525 quick-drop: generic vehicle (3; a-u-G-E-V already at 69) ---
  static const CotType CotType_a_n_G_E_V =
      CotType._(110, _omitEnumNames ? '' : 'CotType_a_n_G_E_V');
  static const CotType CotType_a_h_G_E_V =
      CotType._(111, _omitEnumNames ? '' : 'CotType_a_h_G_E_V');
  static const CotType CotType_a_f_G_E_V =
      CotType._(112, _omitEnumNames ? '' : 'CotType_a_f_G_E_V');

  ///
  ///  b-m-p-w-GOTO: Go To / bloodhound navigation target.
  static const CotType CotType_b_m_p_w_GOTO =
      CotType._(113, _omitEnumNames ? '' : 'CotType_b_m_p_w_GOTO');

  ///
  ///  b-m-p-c-ip: Initial point (mission planning).
  static const CotType CotType_b_m_p_c_ip =
      CotType._(114, _omitEnumNames ? '' : 'CotType_b_m_p_c_ip');

  ///
  ///  b-m-p-c-cp: Contact point (mission planning).
  static const CotType CotType_b_m_p_c_cp =
      CotType._(115, _omitEnumNames ? '' : 'CotType_b_m_p_c_cp');

  ///
  ///  b-m-p-s-p-op: Observation post.
  static const CotType CotType_b_m_p_s_p_op =
      CotType._(116, _omitEnumNames ? '' : 'CotType_b_m_p_s_p_op');

  ///
  ///  u-d-v: 2D vehicle outline drawn on the map.
  static const CotType CotType_u_d_v =
      CotType._(117, _omitEnumNames ? '' : 'CotType_u_d_v');

  ///
  ///  u-d-v-m: 3D vehicle model reference.
  static const CotType CotType_u_d_v_m =
      CotType._(118, _omitEnumNames ? '' : 'CotType_u_d_v_m');

  ///
  ///  u-d-c-e: Non-circular ellipse (circle with distinct major/minor axes).
  static const CotType CotType_u_d_c_e =
      CotType._(119, _omitEnumNames ? '' : 'CotType_u_d_c_e');

  ///
  ///  b-i-x-i: Quick Pic geotagged image marker. The image itself does not
  ///  ride on LoRa; this event references the image via iconset metadata.
  static const CotType CotType_b_i_x_i =
      CotType._(120, _omitEnumNames ? '' : 'CotType_b_i_x_i');

  ///
  ///  b-t-f-d: GeoChat delivered receipt. Carried on the existing `chat`
  ///  payload_variant via GeoChat.receipt_for_uid + receipt_type.
  static const CotType CotType_b_t_f_d =
      CotType._(121, _omitEnumNames ? '' : 'CotType_b_t_f_d');

  ///
  ///  b-t-f-r: GeoChat read receipt. Same wire slot as b-t-f-d.
  static const CotType CotType_b_t_f_r =
      CotType._(122, _omitEnumNames ? '' : 'CotType_b_t_f_r');

  ///
  ///  b-a-o-c: Custom / generic emergency beacon.
  static const CotType CotType_b_a_o_c =
      CotType._(123, _omitEnumNames ? '' : 'CotType_b_a_o_c');

  ///
  ///  t-s: Task / engage request. Structured payload carried via the new
  ///  TaskRequest typed variant.
  static const CotType CotType_t_s =
      CotType._(124, _omitEnumNames ? '' : 'CotType_t_s');

  ///
  ///  m-t-t: TAKTALK voice/text chat message. Payload carried via the
  ///  TakTalkMessage typed variant (text, chatroom_id, lang, from_voice).
  static const CotType CotType_m_t_t =
      CotType._(125, _omitEnumNames ? '' : 'CotType_m_t_t');

  ///
  ///  y-: TAKTALK room/membership broadcast. Payload carried via the
  ///  TakTalkRoomData typed variant (sender_callsign, room_id, room_name,
  ///  participants). The CoT type literally has a trailing dash and no
  ///  second atom — not a typo.
  static const CotType CotType_y =
      CotType._(126, _omitEnumNames ? '' : 'CotType_y');

  static const $core.List<CotType> values = <CotType>[
    CotType_Other,
    CotType_a_f_G_U_C,
    CotType_a_f_G_U_C_I,
    CotType_a_n_A_C_F,
    CotType_a_n_A_C_H,
    CotType_a_n_A_C,
    CotType_a_f_A_M_H,
    CotType_a_f_A_M,
    CotType_a_f_A_M_F_F,
    CotType_a_f_A_M_H_A,
    CotType_a_f_A_M_H_U_M,
    CotType_a_h_A_M_F_F,
    CotType_a_h_A_M_H_A,
    CotType_a_u_A_C,
    CotType_t_x_d_d,
    CotType_a_f_G_E_S_E,
    CotType_a_f_G_E_V_C,
    CotType_a_f_S,
    CotType_a_f_A_M_F,
    CotType_a_f_A_M_F_C_H,
    CotType_a_f_A_M_F_U_L,
    CotType_a_f_A_M_F_L,
    CotType_a_f_A_M_F_P,
    CotType_a_f_A_C_H,
    CotType_a_n_A_M_F_Q,
    CotType_b_t_f,
    CotType_b_r_f_h_c,
    CotType_b_a_o_pan,
    CotType_b_a_o_opn,
    CotType_b_a_o_can,
    CotType_b_a_o_tbl,
    CotType_b_a_g,
    CotType_a_f_G,
    CotType_a_f_G_U,
    CotType_a_h_G,
    CotType_a_u_G,
    CotType_a_n_G,
    CotType_b_m_r,
    CotType_b_m_p_w,
    CotType_b_m_p_s_p_i,
    CotType_u_d_f,
    CotType_u_d_r,
    CotType_u_d_c_c,
    CotType_u_rb_a,
    CotType_a_h_A,
    CotType_a_u_A,
    CotType_a_f_A_M_H_Q,
    CotType_a_f_A_C_F,
    CotType_a_f_A_C,
    CotType_a_f_A_C_L,
    CotType_a_f_A,
    CotType_a_f_A_M_H_C,
    CotType_a_n_A_M_F_F,
    CotType_a_u_A_C_F,
    CotType_a_f_G_U_C_F_T_A,
    CotType_a_f_G_U_C_V_S,
    CotType_a_f_G_U_C_R_X,
    CotType_a_f_G_U_C_I_Z,
    CotType_a_f_G_U_C_E_C_W,
    CotType_a_f_G_U_C_I_L,
    CotType_a_f_G_U_C_R_O,
    CotType_a_f_G_U_C_R_V,
    CotType_a_f_G_U_H,
    CotType_a_f_G_U_U_M_S_E,
    CotType_a_f_G_U_S_M_C,
    CotType_a_f_G_E_S,
    CotType_a_f_G_E,
    CotType_a_f_G_E_V_C_U,
    CotType_a_f_G_E_V_C_ps,
    CotType_a_u_G_E_V,
    CotType_a_f_S_N_N_R,
    CotType_a_f_F_B,
    CotType_b_m_p_s_p_loc,
    CotType_b_i_v,
    CotType_b_f_t_r,
    CotType_b_f_t_a,
    CotType_u_d_f_m,
    CotType_u_d_p,
    CotType_b_m_p_s_m,
    CotType_b_m_p_c,
    CotType_u_r_b_c_c,
    CotType_u_r_b_bullseye,
    CotType_a_f_G_E_V_A,
    CotType_a_n_A,
    CotType_a_u_G_U_C_F,
    CotType_a_n_G_U_C_F,
    CotType_a_h_G_U_C_F,
    CotType_a_f_G_U_C_F,
    CotType_a_u_G_I,
    CotType_a_n_G_I,
    CotType_a_h_G_I,
    CotType_a_f_G_I,
    CotType_a_u_G_E_X_M,
    CotType_a_n_G_E_X_M,
    CotType_a_h_G_E_X_M,
    CotType_a_f_G_E_X_M,
    CotType_a_u_S,
    CotType_a_n_S,
    CotType_a_h_S,
    CotType_a_u_G_U_C_I_d,
    CotType_a_n_G_U_C_I_d,
    CotType_a_h_G_U_C_I_d,
    CotType_a_f_G_U_C_I_d,
    CotType_a_u_G_E_V_A_T,
    CotType_a_n_G_E_V_A_T,
    CotType_a_h_G_E_V_A_T,
    CotType_a_f_G_E_V_A_T,
    CotType_a_u_G_U_C_I,
    CotType_a_n_G_U_C_I,
    CotType_a_h_G_U_C_I,
    CotType_a_n_G_E_V,
    CotType_a_h_G_E_V,
    CotType_a_f_G_E_V,
    CotType_b_m_p_w_GOTO,
    CotType_b_m_p_c_ip,
    CotType_b_m_p_c_cp,
    CotType_b_m_p_s_p_op,
    CotType_u_d_v,
    CotType_u_d_v_m,
    CotType_u_d_c_e,
    CotType_b_i_x_i,
    CotType_b_t_f_d,
    CotType_b_t_f_r,
    CotType_b_a_o_c,
    CotType_t_s,
    CotType_m_t_t,
    CotType_y,
  ];

  static final $core.List<CotType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 126);
  static CotType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const CotType._(super.value, super.name);
}

///
///  Geopoint and altitude source
class GeoPointSource extends $pb.ProtobufEnum {
  ///
  ///  Unspecified
  static const GeoPointSource GeoPointSource_Unspecified =
      GeoPointSource._(0, _omitEnumNames ? '' : 'GeoPointSource_Unspecified');

  ///
  ///  GPS derived
  static const GeoPointSource GeoPointSource_GPS =
      GeoPointSource._(1, _omitEnumNames ? '' : 'GeoPointSource_GPS');

  ///
  ///  User entered
  static const GeoPointSource GeoPointSource_USER =
      GeoPointSource._(2, _omitEnumNames ? '' : 'GeoPointSource_USER');

  ///
  ///  Network/external
  static const GeoPointSource GeoPointSource_NETWORK =
      GeoPointSource._(3, _omitEnumNames ? '' : 'GeoPointSource_NETWORK');

  static const $core.List<GeoPointSource> values = <GeoPointSource>[
    GeoPointSource_Unspecified,
    GeoPointSource_GPS,
    GeoPointSource_USER,
    GeoPointSource_NETWORK,
  ];

  static final $core.List<GeoPointSource?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static GeoPointSource? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const GeoPointSource._(super.value, super.name);
}

///
///  Receipt discriminator. Set alongside cot_type_id = b-t-f-d (delivered)
///  or b-t-f-r (read). ReceiptType_None is the default for a normal chat
///  message (cot_type_id = b-t-f).
///
///  Receivers can detect a receipt by checking receipt_type != ReceiptType_None
///  without re-parsing the envelope cot_type_id.
class GeoChat_ReceiptType extends $pb.ProtobufEnum {
  static const GeoChat_ReceiptType ReceiptType_None =
      GeoChat_ReceiptType._(0, _omitEnumNames ? '' : 'ReceiptType_None');
  static const GeoChat_ReceiptType ReceiptType_Delivered =
      GeoChat_ReceiptType._(1, _omitEnumNames ? '' : 'ReceiptType_Delivered');
  static const GeoChat_ReceiptType ReceiptType_Read =
      GeoChat_ReceiptType._(2, _omitEnumNames ? '' : 'ReceiptType_Read');

  static const $core.List<GeoChat_ReceiptType> values = <GeoChat_ReceiptType>[
    ReceiptType_None,
    ReceiptType_Delivered,
    ReceiptType_Read,
  ];

  static final $core.List<GeoChat_ReceiptType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static GeoChat_ReceiptType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const GeoChat_ReceiptType._(super.value, super.name);
}

///
///  Shape kind discriminator. Drives receiver rendering and also controls
///  which optional fields below are meaningful.
class DrawnShape_Kind extends $pb.ProtobufEnum {
  ///
  ///  Unspecified (do not use on the wire)
  static const DrawnShape_Kind Kind_Unspecified =
      DrawnShape_Kind._(0, _omitEnumNames ? '' : 'Kind_Unspecified');

  ///
  ///  u-d-c-c: User-drawn circle (uses major/minor/angle, anchor = event point)
  static const DrawnShape_Kind Kind_Circle =
      DrawnShape_Kind._(1, _omitEnumNames ? '' : 'Kind_Circle');

  ///
  ///  u-d-r: User-drawn rectangle (uses vertices = 4 corners)
  static const DrawnShape_Kind Kind_Rectangle =
      DrawnShape_Kind._(2, _omitEnumNames ? '' : 'Kind_Rectangle');

  ///
  ///  u-d-f: User-drawn polyline (uses vertices, not closed)
  static const DrawnShape_Kind Kind_Freeform =
      DrawnShape_Kind._(3, _omitEnumNames ? '' : 'Kind_Freeform');

  ///
  ///  u-d-f-m: Freehand telestration / annotation (uses vertices, may be truncated)
  static const DrawnShape_Kind Kind_Telestration =
      DrawnShape_Kind._(4, _omitEnumNames ? '' : 'Kind_Telestration');

  ///
  ///  u-d-p: Closed polygon (uses vertices, implicitly closed)
  static const DrawnShape_Kind Kind_Polygon =
      DrawnShape_Kind._(5, _omitEnumNames ? '' : 'Kind_Polygon');

  ///
  ///  u-r-b-c-c: Ranging circle (major/minor/angle, stroke + optional fill)
  static const DrawnShape_Kind Kind_RangingCircle =
      DrawnShape_Kind._(6, _omitEnumNames ? '' : 'Kind_RangingCircle');

  ///
  ///  u-r-b-bullseye: Bullseye ring with range rings and bearing reference
  static const DrawnShape_Kind Kind_Bullseye =
      DrawnShape_Kind._(7, _omitEnumNames ? '' : 'Kind_Bullseye');

  ///
  ///  u-d-c-e: Ellipse with distinct major/minor axes (same storage as
  ///  Kind_Circle — uses major_cm/minor_cm/angle_deg — but receivers
  ///  render it as a non-circular ellipse rather than a round circle).
  static const DrawnShape_Kind Kind_Ellipse =
      DrawnShape_Kind._(8, _omitEnumNames ? '' : 'Kind_Ellipse');

  ///
  ///  u-d-v: 2D vehicle outline drawn on the map. Vertices carry the
  ///  outline polygon; receivers draw it as a filled polygon.
  static const DrawnShape_Kind Kind_Vehicle2D =
      DrawnShape_Kind._(9, _omitEnumNames ? '' : 'Kind_Vehicle2D');

  ///
  ///  u-d-v-m: 3D vehicle model reference. Same vertex polygon as
  ///  Kind_Vehicle2D; receivers that support 3D rendering extrude it.
  static const DrawnShape_Kind Kind_Vehicle3D =
      DrawnShape_Kind._(10, _omitEnumNames ? '' : 'Kind_Vehicle3D');

  static const $core.List<DrawnShape_Kind> values = <DrawnShape_Kind>[
    Kind_Unspecified,
    Kind_Circle,
    Kind_Rectangle,
    Kind_Freeform,
    Kind_Telestration,
    Kind_Polygon,
    Kind_RangingCircle,
    Kind_Bullseye,
    Kind_Ellipse,
    Kind_Vehicle2D,
    Kind_Vehicle3D,
  ];

  static final $core.List<DrawnShape_Kind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 10);
  static DrawnShape_Kind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const DrawnShape_Kind._(super.value, super.name);
}

///
///  Explicit stroke/fill/both discriminator.
///
///  ATAK's source XML distinguishes "stroke-only polyline" from "closed shape
///  with both stroke and fill" by the presence of the <fillColor> element.
///  Both states can hash to all-zero color fields, so we carry the signal
///  explicitly. Parser sets this from (sawStrokeColor, sawFillColor) at the
///  end of parse; builder uses it to decide which of <strokeColor> /
///  <fillColor> to emit in the reconstructed XML.
class DrawnShape_StyleMode extends $pb.ProtobufEnum {
  ///
  ///  Unspecified — receiver infers from which color fields are non-zero.
  static const DrawnShape_StyleMode StyleMode_Unspecified =
      DrawnShape_StyleMode._(0, _omitEnumNames ? '' : 'StyleMode_Unspecified');

  ///
  ///  Stroke only. No <fillColor> in the source XML. Used for polylines,
  ///  ranging lines, bullseye rings.
  static const DrawnShape_StyleMode StyleMode_StrokeOnly =
      DrawnShape_StyleMode._(1, _omitEnumNames ? '' : 'StyleMode_StrokeOnly');

  ///
  ///  Fill only. No <strokeColor> in the source XML. Rare but valid in
  ///  ATAK (solid region with no outline).
  static const DrawnShape_StyleMode StyleMode_FillOnly =
      DrawnShape_StyleMode._(2, _omitEnumNames ? '' : 'StyleMode_FillOnly');

  ///
  ///  Both stroke and fill present. Closed shapes: circle, rectangle,
  ///  polygon, ranging circle.
  static const DrawnShape_StyleMode StyleMode_StrokeAndFill =
      DrawnShape_StyleMode._(
          3, _omitEnumNames ? '' : 'StyleMode_StrokeAndFill');

  static const $core.List<DrawnShape_StyleMode> values = <DrawnShape_StyleMode>[
    StyleMode_Unspecified,
    StyleMode_StrokeOnly,
    StyleMode_FillOnly,
    StyleMode_StrokeAndFill,
  ];

  static final $core.List<DrawnShape_StyleMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static DrawnShape_StyleMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const DrawnShape_StyleMode._(super.value, super.name);
}

///
///  Marker kind. Used to pick sensible receiver defaults when the CoT type
///  alone is ambiguous (e.g. a-u-G could be a 2525 symbol or a custom icon
///  depending on the iconset path).
class Marker_Kind extends $pb.ProtobufEnum {
  ///
  ///  Unspecified — fall back to TAKPacketV2.cot_type_id
  static const Marker_Kind Kind_Unspecified =
      Marker_Kind._(0, _omitEnumNames ? '' : 'Kind_Unspecified');

  ///
  ///  b-m-p-s-m: Spot map marker
  static const Marker_Kind Kind_Spot =
      Marker_Kind._(1, _omitEnumNames ? '' : 'Kind_Spot');

  ///
  ///  b-m-p-w: Route waypoint
  static const Marker_Kind Kind_Waypoint =
      Marker_Kind._(2, _omitEnumNames ? '' : 'Kind_Waypoint');

  ///
  ///  b-m-p-c: Checkpoint
  static const Marker_Kind Kind_Checkpoint =
      Marker_Kind._(3, _omitEnumNames ? '' : 'Kind_Checkpoint');

  ///
  ///  b-m-p-s-p-i / b-m-p-s-p-loc: Self-position marker
  static const Marker_Kind Kind_SelfPosition =
      Marker_Kind._(4, _omitEnumNames ? '' : 'Kind_SelfPosition');

  ///
  ///  2525B/C military symbol (iconsetpath = COT_MAPPING_2525B/...)
  static const Marker_Kind Kind_Symbol2525 =
      Marker_Kind._(5, _omitEnumNames ? '' : 'Kind_Symbol2525');

  ///
  ///  COT_MAPPING_SPOTMAP icon (e.g. colored dot)
  static const Marker_Kind Kind_SpotMap =
      Marker_Kind._(6, _omitEnumNames ? '' : 'Kind_SpotMap');

  ///
  ///  Custom icon set (UUID/GroupName/filename.png)
  static const Marker_Kind Kind_CustomIcon =
      Marker_Kind._(7, _omitEnumNames ? '' : 'Kind_CustomIcon');

  ///
  ///  b-m-p-w-GOTO: Go To / bloodhound navigation waypoint.
  static const Marker_Kind Kind_GoToPoint =
      Marker_Kind._(8, _omitEnumNames ? '' : 'Kind_GoToPoint');

  ///
  ///  b-m-p-c-ip: Initial point (mission planning control point).
  static const Marker_Kind Kind_InitialPoint =
      Marker_Kind._(9, _omitEnumNames ? '' : 'Kind_InitialPoint');

  ///
  ///  b-m-p-c-cp: Contact point (mission planning control point).
  static const Marker_Kind Kind_ContactPoint =
      Marker_Kind._(10, _omitEnumNames ? '' : 'Kind_ContactPoint');

  ///
  ///  b-m-p-s-p-op: Observation post.
  static const Marker_Kind Kind_ObservationPost =
      Marker_Kind._(11, _omitEnumNames ? '' : 'Kind_ObservationPost');

  ///
  ///  b-i-x-i: Quick Pic geotagged image marker. iconset carries the
  ///  image reference (local filename or remote URL); the image itself
  ///  does not ride on the LoRa wire.
  static const Marker_Kind Kind_ImageMarker =
      Marker_Kind._(12, _omitEnumNames ? '' : 'Kind_ImageMarker');

  static const $core.List<Marker_Kind> values = <Marker_Kind>[
    Kind_Unspecified,
    Kind_Spot,
    Kind_Waypoint,
    Kind_Checkpoint,
    Kind_SelfPosition,
    Kind_Symbol2525,
    Kind_SpotMap,
    Kind_CustomIcon,
    Kind_GoToPoint,
    Kind_InitialPoint,
    Kind_ContactPoint,
    Kind_ObservationPost,
    Kind_ImageMarker,
  ];

  static final $core.List<Marker_Kind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 12);
  static Marker_Kind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Marker_Kind._(super.value, super.name);
}

///
///  Travel method for the route.
class Route_Method extends $pb.ProtobufEnum {
  ///
  ///  Unspecified / unknown
  static const Route_Method Method_Unspecified =
      Route_Method._(0, _omitEnumNames ? '' : 'Method_Unspecified');

  ///
  ///  Driving / vehicle
  static const Route_Method Method_Driving =
      Route_Method._(1, _omitEnumNames ? '' : 'Method_Driving');

  ///
  ///  Walking / foot
  static const Route_Method Method_Walking =
      Route_Method._(2, _omitEnumNames ? '' : 'Method_Walking');

  ///
  ///  Flying
  static const Route_Method Method_Flying =
      Route_Method._(3, _omitEnumNames ? '' : 'Method_Flying');

  ///
  ///  Swimming (individual)
  static const Route_Method Method_Swimming =
      Route_Method._(4, _omitEnumNames ? '' : 'Method_Swimming');

  ///
  ///  Watercraft (boat)
  static const Route_Method Method_Watercraft =
      Route_Method._(5, _omitEnumNames ? '' : 'Method_Watercraft');

  static const $core.List<Route_Method> values = <Route_Method>[
    Method_Unspecified,
    Method_Driving,
    Method_Walking,
    Method_Flying,
    Method_Swimming,
    Method_Watercraft,
  ];

  static final $core.List<Route_Method?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static Route_Method? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Route_Method._(super.value, super.name);
}

///
///  Route direction (infil = ingress, exfil = egress).
class Route_Direction extends $pb.ProtobufEnum {
  ///
  ///  Unspecified
  static const Route_Direction Direction_Unspecified =
      Route_Direction._(0, _omitEnumNames ? '' : 'Direction_Unspecified');

  ///
  ///  Infiltration (ingress)
  static const Route_Direction Direction_Infil =
      Route_Direction._(1, _omitEnumNames ? '' : 'Direction_Infil');

  ///
  ///  Exfiltration (egress)
  static const Route_Direction Direction_Exfil =
      Route_Direction._(2, _omitEnumNames ? '' : 'Direction_Exfil');

  static const $core.List<Route_Direction> values = <Route_Direction>[
    Direction_Unspecified,
    Direction_Infil,
    Direction_Exfil,
  ];

  static final $core.List<Route_Direction?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static Route_Direction? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Route_Direction._(super.value, super.name);
}

///
///  Line 3: precedence / urgency.
class CasevacReport_Precedence extends $pb.ProtobufEnum {
  static const CasevacReport_Precedence Precedence_Unspecified =
      CasevacReport_Precedence._(
          0, _omitEnumNames ? '' : 'Precedence_Unspecified');
  static const CasevacReport_Precedence Precedence_Urgent =
      CasevacReport_Precedence._(1, _omitEnumNames ? '' : 'Precedence_Urgent');
  static const CasevacReport_Precedence Precedence_UrgentSurgical =
      CasevacReport_Precedence._(
          2, _omitEnumNames ? '' : 'Precedence_UrgentSurgical');
  static const CasevacReport_Precedence Precedence_Priority =
      CasevacReport_Precedence._(
          3, _omitEnumNames ? '' : 'Precedence_Priority');
  static const CasevacReport_Precedence Precedence_Routine =
      CasevacReport_Precedence._(4, _omitEnumNames ? '' : 'Precedence_Routine');
  static const CasevacReport_Precedence Precedence_Convenience =
      CasevacReport_Precedence._(
          5, _omitEnumNames ? '' : 'Precedence_Convenience');

  static const $core.List<CasevacReport_Precedence> values =
      <CasevacReport_Precedence>[
    Precedence_Unspecified,
    Precedence_Urgent,
    Precedence_UrgentSurgical,
    Precedence_Priority,
    Precedence_Routine,
    Precedence_Convenience,
  ];

  static final $core.List<CasevacReport_Precedence?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static CasevacReport_Precedence? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const CasevacReport_Precedence._(super.value, super.name);
}

///
///  Line 7: HLZ marking method.
class CasevacReport_HlzMarking extends $pb.ProtobufEnum {
  static const CasevacReport_HlzMarking HlzMarking_Unspecified =
      CasevacReport_HlzMarking._(
          0, _omitEnumNames ? '' : 'HlzMarking_Unspecified');
  static const CasevacReport_HlzMarking HlzMarking_Panels =
      CasevacReport_HlzMarking._(1, _omitEnumNames ? '' : 'HlzMarking_Panels');
  static const CasevacReport_HlzMarking HlzMarking_PyroSignal =
      CasevacReport_HlzMarking._(
          2, _omitEnumNames ? '' : 'HlzMarking_PyroSignal');
  static const CasevacReport_HlzMarking HlzMarking_Smoke =
      CasevacReport_HlzMarking._(3, _omitEnumNames ? '' : 'HlzMarking_Smoke');
  static const CasevacReport_HlzMarking HlzMarking_None =
      CasevacReport_HlzMarking._(4, _omitEnumNames ? '' : 'HlzMarking_None');
  static const CasevacReport_HlzMarking HlzMarking_Other =
      CasevacReport_HlzMarking._(5, _omitEnumNames ? '' : 'HlzMarking_Other');

  static const $core.List<CasevacReport_HlzMarking> values =
      <CasevacReport_HlzMarking>[
    HlzMarking_Unspecified,
    HlzMarking_Panels,
    HlzMarking_PyroSignal,
    HlzMarking_Smoke,
    HlzMarking_None,
    HlzMarking_Other,
  ];

  static final $core.List<CasevacReport_HlzMarking?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static CasevacReport_HlzMarking? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const CasevacReport_HlzMarking._(super.value, super.name);
}

///
///  Line 6: security situation at the pickup zone.
class CasevacReport_Security extends $pb.ProtobufEnum {
  static const CasevacReport_Security Security_Unspecified =
      CasevacReport_Security._(0, _omitEnumNames ? '' : 'Security_Unspecified');
  static const CasevacReport_Security Security_NoEnemy =
      CasevacReport_Security._(1, _omitEnumNames ? '' : 'Security_NoEnemy');
  static const CasevacReport_Security Security_PossibleEnemy =
      CasevacReport_Security._(
          2, _omitEnumNames ? '' : 'Security_PossibleEnemy');
  static const CasevacReport_Security Security_EnemyInArea =
      CasevacReport_Security._(3, _omitEnumNames ? '' : 'Security_EnemyInArea');
  static const CasevacReport_Security Security_EnemyInArmedContact =
      CasevacReport_Security._(
          4, _omitEnumNames ? '' : 'Security_EnemyInArmedContact');

  static const $core.List<CasevacReport_Security> values =
      <CasevacReport_Security>[
    Security_Unspecified,
    Security_NoEnemy,
    Security_PossibleEnemy,
    Security_EnemyInArea,
    Security_EnemyInArmedContact,
  ];

  static final $core.List<CasevacReport_Security?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static CasevacReport_Security? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const CasevacReport_Security._(super.value, super.name);
}

class EmergencyAlert_Type extends $pb.ProtobufEnum {
  static const EmergencyAlert_Type Type_Unspecified =
      EmergencyAlert_Type._(0, _omitEnumNames ? '' : 'Type_Unspecified');
  static const EmergencyAlert_Type Type_Alert911 =
      EmergencyAlert_Type._(1, _omitEnumNames ? '' : 'Type_Alert911');
  static const EmergencyAlert_Type Type_RingTheBell =
      EmergencyAlert_Type._(2, _omitEnumNames ? '' : 'Type_RingTheBell');
  static const EmergencyAlert_Type Type_InContact =
      EmergencyAlert_Type._(3, _omitEnumNames ? '' : 'Type_InContact');
  static const EmergencyAlert_Type Type_GeoFenceBreached =
      EmergencyAlert_Type._(4, _omitEnumNames ? '' : 'Type_GeoFenceBreached');
  static const EmergencyAlert_Type Type_Custom =
      EmergencyAlert_Type._(5, _omitEnumNames ? '' : 'Type_Custom');
  static const EmergencyAlert_Type Type_Cancel =
      EmergencyAlert_Type._(6, _omitEnumNames ? '' : 'Type_Cancel');

  static const $core.List<EmergencyAlert_Type> values = <EmergencyAlert_Type>[
    Type_Unspecified,
    Type_Alert911,
    Type_RingTheBell,
    Type_InContact,
    Type_GeoFenceBreached,
    Type_Custom,
    Type_Cancel,
  ];

  static final $core.List<EmergencyAlert_Type?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 6);
  static EmergencyAlert_Type? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const EmergencyAlert_Type._(super.value, super.name);
}

class TaskRequest_Priority extends $pb.ProtobufEnum {
  static const TaskRequest_Priority Priority_Unspecified =
      TaskRequest_Priority._(0, _omitEnumNames ? '' : 'Priority_Unspecified');
  static const TaskRequest_Priority Priority_Low =
      TaskRequest_Priority._(1, _omitEnumNames ? '' : 'Priority_Low');
  static const TaskRequest_Priority Priority_Normal =
      TaskRequest_Priority._(2, _omitEnumNames ? '' : 'Priority_Normal');
  static const TaskRequest_Priority Priority_High =
      TaskRequest_Priority._(3, _omitEnumNames ? '' : 'Priority_High');
  static const TaskRequest_Priority Priority_Critical =
      TaskRequest_Priority._(4, _omitEnumNames ? '' : 'Priority_Critical');

  static const $core.List<TaskRequest_Priority> values = <TaskRequest_Priority>[
    Priority_Unspecified,
    Priority_Low,
    Priority_Normal,
    Priority_High,
    Priority_Critical,
  ];

  static final $core.List<TaskRequest_Priority?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static TaskRequest_Priority? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TaskRequest_Priority._(super.value, super.name);
}

class TaskRequest_Status extends $pb.ProtobufEnum {
  static const TaskRequest_Status Status_Unspecified =
      TaskRequest_Status._(0, _omitEnumNames ? '' : 'Status_Unspecified');
  static const TaskRequest_Status Status_Pending =
      TaskRequest_Status._(1, _omitEnumNames ? '' : 'Status_Pending');
  static const TaskRequest_Status Status_Acknowledged =
      TaskRequest_Status._(2, _omitEnumNames ? '' : 'Status_Acknowledged');
  static const TaskRequest_Status Status_InProgress =
      TaskRequest_Status._(3, _omitEnumNames ? '' : 'Status_InProgress');
  static const TaskRequest_Status Status_Completed =
      TaskRequest_Status._(4, _omitEnumNames ? '' : 'Status_Completed');
  static const TaskRequest_Status Status_Cancelled =
      TaskRequest_Status._(5, _omitEnumNames ? '' : 'Status_Cancelled');

  static const $core.List<TaskRequest_Status> values = <TaskRequest_Status>[
    Status_Unspecified,
    Status_Pending,
    Status_Acknowledged,
    Status_InProgress,
    Status_Completed,
    Status_Cancelled,
  ];

  static final $core.List<TaskRequest_Status?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static TaskRequest_Status? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TaskRequest_Status._(super.value, super.name);
}

///
///  Coarse sensor category, inferred from `model` on parse when the source
///  XML doesn't label it. Receivers that render differently per sensor
///  class (thermal overlay vs daylight cone) use this.
class SensorFov_SensorType extends $pb.ProtobufEnum {
  static const SensorFov_SensorType SensorType_Unspecified =
      SensorFov_SensorType._(0, _omitEnumNames ? '' : 'SensorType_Unspecified');
  static const SensorFov_SensorType SensorType_Camera =
      SensorFov_SensorType._(1, _omitEnumNames ? '' : 'SensorType_Camera');
  static const SensorFov_SensorType SensorType_Thermal =
      SensorFov_SensorType._(2, _omitEnumNames ? '' : 'SensorType_Thermal');
  static const SensorFov_SensorType SensorType_Laser =
      SensorFov_SensorType._(3, _omitEnumNames ? '' : 'SensorType_Laser');
  static const SensorFov_SensorType SensorType_Nvg =
      SensorFov_SensorType._(4, _omitEnumNames ? '' : 'SensorType_Nvg');
  static const SensorFov_SensorType SensorType_Rf =
      SensorFov_SensorType._(5, _omitEnumNames ? '' : 'SensorType_Rf');
  static const SensorFov_SensorType SensorType_Other =
      SensorFov_SensorType._(6, _omitEnumNames ? '' : 'SensorType_Other');

  static const $core.List<SensorFov_SensorType> values = <SensorFov_SensorType>[
    SensorType_Unspecified,
    SensorType_Camera,
    SensorType_Thermal,
    SensorType_Laser,
    SensorType_Nvg,
    SensorType_Rf,
    SensorType_Other,
  ];

  static final $core.List<SensorFov_SensorType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 6);
  static SensorFov_SensorType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SensorFov_SensorType._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
