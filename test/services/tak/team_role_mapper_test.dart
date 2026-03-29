// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/generated/meshtastic/atak.pbenum.dart';
import 'package:socialmesh/services/tak/team_role_mapper.dart';

void main() {
  group('TeamRoleMapper', () {
    group('teamToName', () {
      test('maps all 15 team values', () {
        expect(TeamRoleMapper.teamToName(Team.Unspecifed_Color), 'Cyan');
        expect(TeamRoleMapper.teamToName(Team.White), 'White');
        expect(TeamRoleMapper.teamToName(Team.Yellow), 'Yellow');
        expect(TeamRoleMapper.teamToName(Team.Orange), 'Orange');
        expect(TeamRoleMapper.teamToName(Team.Magenta), 'Magenta');
        expect(TeamRoleMapper.teamToName(Team.Red), 'Red');
        expect(TeamRoleMapper.teamToName(Team.Maroon), 'Maroon');
        expect(TeamRoleMapper.teamToName(Team.Purple), 'Purple');
        expect(TeamRoleMapper.teamToName(Team.Dark_Blue), 'Dark Blue');
        expect(TeamRoleMapper.teamToName(Team.Blue), 'Blue');
        expect(TeamRoleMapper.teamToName(Team.Cyan), 'Cyan');
        expect(TeamRoleMapper.teamToName(Team.Teal), 'Teal');
        expect(TeamRoleMapper.teamToName(Team.Green), 'Green');
        expect(TeamRoleMapper.teamToName(Team.Dark_Green), 'Dark Green');
        expect(TeamRoleMapper.teamToName(Team.Brown), 'Brown');
      });
    });

    group('roleToName', () {
      test('maps all 9 role values', () {
        expect(TeamRoleMapper.roleToName(MemberRole.Unspecifed), 'Team Member');
        expect(TeamRoleMapper.roleToName(MemberRole.TeamMember), 'Team Member');
        expect(TeamRoleMapper.roleToName(MemberRole.TeamLead), 'Team Lead');
        expect(TeamRoleMapper.roleToName(MemberRole.HQ), 'HQ');
        expect(TeamRoleMapper.roleToName(MemberRole.Sniper), 'Sniper');
        expect(TeamRoleMapper.roleToName(MemberRole.Medic), 'Medic');
        expect(
          TeamRoleMapper.roleToName(MemberRole.ForwardObserver),
          'Forward Observer',
        );
        expect(TeamRoleMapper.roleToName(MemberRole.RTO), 'RTO');
        expect(TeamRoleMapper.roleToName(MemberRole.K9), 'K9');
      });
    });

    group('nameToTeam', () {
      test('maps standard team names', () {
        expect(TeamRoleMapper.nameToTeam('Cyan'), Team.Cyan);
        expect(TeamRoleMapper.nameToTeam('White'), Team.White);
        expect(TeamRoleMapper.nameToTeam('Dark Blue'), Team.Dark_Blue);
        expect(TeamRoleMapper.nameToTeam('Dark Green'), Team.Dark_Green);
      });

      test('case insensitive', () {
        expect(TeamRoleMapper.nameToTeam('cyan'), Team.Cyan);
        expect(TeamRoleMapper.nameToTeam('YELLOW'), Team.Yellow);
        expect(TeamRoleMapper.nameToTeam('dark blue'), Team.Dark_Blue);
      });

      test('unknown name defaults to Cyan', () {
        expect(TeamRoleMapper.nameToTeam('Unknown'), Team.Cyan);
        expect(TeamRoleMapper.nameToTeam(''), Team.Cyan);
      });
    });

    group('nameToRole', () {
      test('maps standard role names', () {
        expect(TeamRoleMapper.nameToRole('Team Member'), MemberRole.TeamMember);
        expect(TeamRoleMapper.nameToRole('Team Lead'), MemberRole.TeamLead);
        expect(TeamRoleMapper.nameToRole('HQ'), MemberRole.HQ);
        expect(TeamRoleMapper.nameToRole('Medic'), MemberRole.Medic);
      });

      test('case insensitive', () {
        expect(TeamRoleMapper.nameToRole('team lead'), MemberRole.TeamLead);
        expect(TeamRoleMapper.nameToRole('MEDIC'), MemberRole.Medic);
      });

      test('unknown name defaults to TeamMember', () {
        expect(TeamRoleMapper.nameToRole('Unknown'), MemberRole.TeamMember);
        expect(TeamRoleMapper.nameToRole(''), MemberRole.TeamMember);
      });
    });

    group('cotTypeSuffix', () {
      test('TeamLead -> -I (command)', () {
        expect(TeamRoleMapper.cotTypeSuffix(MemberRole.TeamLead), '-I');
      });

      test('HQ -> -I (command)', () {
        expect(TeamRoleMapper.cotTypeSuffix(MemberRole.HQ), '-I');
      });

      test('Medic -> -M', () {
        expect(TeamRoleMapper.cotTypeSuffix(MemberRole.Medic), '-M');
      });

      test('Sniper -> -S', () {
        expect(TeamRoleMapper.cotTypeSuffix(MemberRole.Sniper), '-S');
      });

      test('ForwardObserver -> -F', () {
        expect(TeamRoleMapper.cotTypeSuffix(MemberRole.ForwardObserver), '-F');
      });

      test('RTO -> -R', () {
        expect(TeamRoleMapper.cotTypeSuffix(MemberRole.RTO), '-R');
      });

      test('K9 -> -K', () {
        expect(TeamRoleMapper.cotTypeSuffix(MemberRole.K9), '-K');
      });

      test('TeamMember -> empty', () {
        expect(TeamRoleMapper.cotTypeSuffix(MemberRole.TeamMember), '');
      });

      test('Unspecified -> empty', () {
        expect(TeamRoleMapper.cotTypeSuffix(MemberRole.Unspecifed), '');
      });
    });

    group('round-trip', () {
      test('all team values round-trip through name', () {
        for (final team in Team.values) {
          final name = TeamRoleMapper.teamToName(team);
          final recovered = TeamRoleMapper.nameToTeam(name);
          // Unspecifed_Color maps to 'Cyan' which maps back to Team.Cyan
          if (team == Team.Unspecifed_Color) {
            expect(recovered, Team.Cyan);
          } else {
            expect(recovered, team, reason: 'team $team should round-trip');
          }
        }
      });

      test('all role values round-trip through name', () {
        for (final role in MemberRole.values) {
          final name = TeamRoleMapper.roleToName(role);
          final recovered = TeamRoleMapper.nameToRole(name);
          // Unspecifed maps to 'Team Member' which maps back to TeamMember
          if (role == MemberRole.Unspecifed) {
            expect(recovered, MemberRole.TeamMember);
          } else {
            expect(recovered, role, reason: 'role $role should round-trip');
          }
        }
      });
    });

    group('groupToCoTAttributes / cotAttributesToGroup', () {
      test('Cyan TeamLead round-trips', () {
        final attrs = TeamRoleMapper.groupToCoTAttributes(
          Team.Cyan,
          MemberRole.TeamLead,
        );
        expect(attrs.teamName, 'Cyan');
        expect(attrs.roleName, 'Team Lead');
        expect(attrs.cotTypeSuffix, '-I');

        final group = TeamRoleMapper.cotAttributesToGroup(
          attrs.teamName,
          attrs.roleName,
        );
        expect(group.team, Team.Cyan);
        expect(group.role, MemberRole.TeamLead);
      });

      test('Yellow Medic round-trips', () {
        final attrs = TeamRoleMapper.groupToCoTAttributes(
          Team.Yellow,
          MemberRole.Medic,
        );
        expect(attrs.teamName, 'Yellow');
        expect(attrs.roleName, 'Medic');
        expect(attrs.cotTypeSuffix, '-M');

        final group = TeamRoleMapper.cotAttributesToGroup(
          attrs.teamName,
          attrs.roleName,
        );
        expect(group.team, Team.Yellow);
        expect(group.role, MemberRole.Medic);
      });
    });
  });
}
