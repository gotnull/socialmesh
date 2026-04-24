// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Regression guard: NodePet must NOT be a top-level drawer entry.
//
// Access to NodePet is now owned by NodeDex detail — the Companion card
// on the user's own node surfaces an "Open NodePet" action. The feature
// is discovered through NodeDex, not advertised in the global drawer.
// This test fails if anyone reintroduces a drawer tile.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NodePet drawer access (removed)', () {
    final mainShellFile = File('lib/features/navigation/main_shell.dart');

    late String source;

    setUpAll(() {
      expect(
        mainShellFile.existsSync(),
        true,
        reason: 'main_shell.dart must exist',
      );
      source = mainShellFile.readAsStringSync();
    });

    test('main_shell does not register a PetHomeScreen drawer item', () {
      expect(
        source.contains('PetHomeScreen()'),
        false,
        reason:
            'NodePet has been removed from the drawer. Access is now via '
            'NodeDex detail → Companion card. Do not reintroduce '
            'PetHomeScreen() as a DrawerMenuItem screen.',
      );
      expect(
        source.contains('l10n.petDrawerLabel'),
        false,
        reason:
            'petDrawerLabel must no longer be referenced — NodePet is not a '
            'top-level drawer entry.',
      );
    });

    test('main_shell does not import PetHomeScreen', () {
      expect(
        source.contains("import '../pet/screens/pet_home_screen.dart'"),
        false,
        reason:
            'PetHomeScreen is entered via NodeDex now; main_shell should '
            'not import it.',
      );
    });
  });
}
