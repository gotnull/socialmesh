// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The Settings screen depends on too many services to pump whole, so this
// pins the wiring in source, as the other settings_screen tests do: a search
// that matches Remote Administration shows the same live card as the
// unfiltered list (target node, node count, Admin Keys warning), not a plain
// row that hides whether remote admin is active.
void main() {
  late String flat;

  setUpAll(() {
    final file = File('lib/features/settings/settings_screen.dart');
    expect(file.existsSync(), true);
    flat = file.readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');
  });

  test('the Remote Administration search item renders the live selector', () {
    final item = flat.indexOf(
      'title: context.l10n.settingsSearchRemoteAdminTitle',
    );
    expect(item, isNot(-1));
    final next = flat.indexOf('_SearchableSettingItem(', item);
    final body = flat.substring(item, next == -1 ? flat.length : next);
    expect(
      body.contains(
        'sectionBuilder: (context, ref) => _adminableNodeCount(ref) == 0 '
        '? null : _buildRemoteAdminSelector(context, ref)',
      ),
      true,
      reason:
          'search must show the same card as the unfiltered list, and '
          'fall back to the plain row only when no node can be administered',
    );
  });

  test('search results render a sectionBuilder before the plain rows', () {
    final results = flat.indexOf('List<Widget> _buildSearchResultsSlivers(');
    expect(results, isNot(-1));
    final builder = flat.indexOf(
      'items.first.sectionBuilder!(context, ref)',
      results,
    );
    final header = flat.indexOf(
      'SettingsListSectionHeader(title: section)',
      results,
    );
    expect(builder, isNot(-1));
    expect(builder < header, true);
  });

  test('the selector and the search share one adminable-node rule', () {
    expect(
      RegExp(r'node\.hasPublicKey').allMatches(flat).length,
      1,
      reason: 'the public-key filter lives only in _adminableNodeCount',
    );
  });
}
