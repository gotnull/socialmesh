// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import '../../generated/meshtastic/atak.pbenum.dart';

/// Maps Meshtastic TAKPacket Group proto fields to CoT attributes and back.
abstract final class TeamRoleMapper {
  /// Maps a [Team] enum to the standard TAK team name string.
  static String teamToName(Team team) => _teamNames[team] ?? 'Cyan';

  /// Maps a [MemberRole] enum to the standard TAK role name string.
  static String roleToName(MemberRole role) =>
      _roleNames[role] ?? 'Team Member';

  /// Maps a TAK team name string back to [Team] enum.
  static Team nameToTeam(String name) =>
      _teamByName[name.toLowerCase()] ?? Team.Cyan;

  /// Maps a TAK role name string back to [MemberRole] enum.
  static MemberRole nameToRole(String name) =>
      _roleByName[name.toLowerCase()] ?? MemberRole.TeamMember;

  /// Returns a CoT type suffix enrichment for the given [MemberRole].
  ///
  /// Base type is `a-f-G-U-C`. Role-specific suffixes:
  /// - Team Lead / HQ -> `-I` (command)
  /// - Medic -> `-M` (medical)
  /// - Sniper -> `-S` (sniper)
  /// - Forward Observer -> `-F` (FO)
  /// - RTO -> `-R` (RTO)
  /// - K9 -> `-K` (K9)
  /// - Team Member / Unspecified -> (no suffix)
  static String cotTypeSuffix(MemberRole role) {
    return switch (role) {
      MemberRole.TeamLead => '-I',
      MemberRole.HQ => '-I',
      MemberRole.Medic => '-M',
      MemberRole.Sniper => '-S',
      MemberRole.ForwardObserver => '-F',
      MemberRole.RTO => '-R',
      MemberRole.K9 => '-K',
      _ => '',
    };
  }

  /// Returns CoT __group attributes from a Meshtastic [Group] proto.
  static ({String teamName, String roleName, String cotTypeSuffix})
  groupToCoTAttributes(Team team, MemberRole role) {
    return (
      teamName: teamToName(team),
      roleName: roleToName(role),
      cotTypeSuffix: cotTypeSuffix(role),
    );
  }

  /// Returns Meshtastic Group proto fields from CoT __group attributes.
  static ({Team team, MemberRole role}) cotAttributesToGroup(
    String teamName,
    String roleName,
  ) {
    return (team: nameToTeam(teamName), role: nameToRole(roleName));
  }

  static const _teamNames = <Team, String>{
    Team.Unspecifed_Color: 'Cyan',
    Team.White: 'White',
    Team.Yellow: 'Yellow',
    Team.Orange: 'Orange',
    Team.Magenta: 'Magenta',
    Team.Red: 'Red',
    Team.Maroon: 'Maroon',
    Team.Purple: 'Purple',
    Team.Dark_Blue: 'Dark Blue',
    Team.Blue: 'Blue',
    Team.Cyan: 'Cyan',
    Team.Teal: 'Teal',
    Team.Green: 'Green',
    Team.Dark_Green: 'Dark Green',
    Team.Brown: 'Brown',
  };

  static const _roleNames = <MemberRole, String>{
    MemberRole.Unspecifed: 'Team Member',
    MemberRole.TeamMember: 'Team Member',
    MemberRole.TeamLead: 'Team Lead',
    MemberRole.HQ: 'HQ',
    MemberRole.Sniper: 'Sniper',
    MemberRole.Medic: 'Medic',
    MemberRole.ForwardObserver: 'Forward Observer',
    MemberRole.RTO: 'RTO',
    MemberRole.K9: 'K9',
  };

  // Reverse lookups — later entries win, so Cyan beats Unspecifed_Color
  // and TeamMember beats Unspecifed.
  static final _teamByName = <String, Team>{
    for (final entry in _teamNames.entries)
      entry.value.toLowerCase(): entry.key,
  };

  static final _roleByName = <String, MemberRole>{
    for (final entry in _roleNames.entries)
      entry.value.toLowerCase(): entry.key,
  };
}
