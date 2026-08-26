// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Teams drawer registration, pinned by source text like the other
// drawer-entry tests in this directory.
//
// Two invariants matter beyond "the entry exists":
//
//   1. Teams must NOT live in DrawerEnterpriseSection. That section
//      belongs to the custom-claims `orgs/` multi-tenancy system and is
//      gated on an orgId claim; Teams is backed by `license_orgs` and
//      its users will never hold that claim, so placing it there would
//      hide the feature from exactly the people it is for.
//
//   2. It must appear in BOTH shells. Organisation membership has
//      nothing to do with which radio protocol is active.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Teams drawer entry', () {
    late String mainShell;
    late String meshCoreShell;
    late String enterpriseSection;

    setUpAll(() {
      mainShell = File(
        'lib/features/navigation/main_shell.dart',
      ).readAsStringSync();
      meshCoreShell = File(
        'lib/features/navigation/meshcore_shell.dart',
      ).readAsStringSync();
      enterpriseSection = File(
        'lib/features/navigation/widgets/drawer_enterprise_section.dart',
      ).readAsStringSync();
    });

    test('main shell imports and renders the Teams entry', () {
      expect(
        mainShell.contains("import '../teams/presentation/teams_screen.dart';"),
        isTrue,
      );
      expect(mainShell.contains('label: l10n.navigationTeams'), isTrue);
      expect(mainShell.contains('screen: const TeamsScreen()'), isTrue);
    });

    test('the drawer id is the permanent one', () {
      // Drawer ids are a release contract: renaming one silently drops
      // the user's customised drawer ordering.
      expect(mainShell.contains("id: 'teams'"), isTrue);
    });

    test('it is gated on product visibility only', () {
      expect(
        mainShell.contains('if (AppFeatureFlags.isTeamsEnabled)'),
        isTrue,
        reason:
            'Teams visibility is a product flag. Who may READ organisation '
            'data is decided by firestore.rules, never by this gate.',
      );
    });

    test('MeshCore shell also exposes Teams', () {
      expect(
        meshCoreShell.contains(
          "import '../teams/presentation/teams_screen.dart';",
        ),
        isTrue,
      );
      expect(meshCoreShell.contains('label: l10n.navigationTeams'), isTrue);
      expect(
        meshCoreShell.contains('AppFeatureFlags.isTeamsEnabled'),
        isTrue,
        reason:
            'org membership is protocol-independent, so Teams must be '
            'reachable from the MeshCore shell too',
      );
    });

    test('Teams is NOT inside the enterprise (custom-claims) section', () {
      expect(
        enterpriseSection.contains('TeamsScreen'),
        isFalse,
        reason:
            'DrawerEnterpriseSection is gated on an orgId custom claim from '
            'the separate orgs/ namespace. Teams users hold no such claim.',
      );
      expect(enterpriseSection.contains('navigationTeams'), isFalse);
    });

    test('Teams does not claim a bottom tab', () {
      // The bottom nav is hard-capped at four; Teams is a drawer
      // destination.
      final tabProviders = File(
        'lib/features/navigation/providers/bottom_tab_providers.dart',
      ).readAsStringSync();
      expect(tabProviders.contains('teams'), isFalse);
    });
  });
}
