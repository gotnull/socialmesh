// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Device Shop drawer entry', () {
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

    test('adds Device Shop to the public drawer Tools section', () {
      expect(
        source.contains('label: l10n.deviceShopTitle'),
        true,
        reason: 'Drawer entry should reuse the localized Device Shop title.',
      );
      expect(
        source.contains('screen: const DeviceShopScreen()'),
        true,
        reason: 'Device Shop drawer entry must navigate to DeviceShopScreen.',
      );
      expect(
        source.contains('sectionHeader: l10n.navigationSectionTools'),
        true,
        reason: 'Device Shop should live in the Tools drawer section.',
      );
    });
  });
}
