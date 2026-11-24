// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The Settings screen depends on too many services to pump whole, so this
// pins the wiring in source: a search that matches Clear Stale Nodes shows
// the same rows as the unfiltered list, including the After x Days slider
// that only appears while the setting is on.
void main() {
  late String flat;

  setUpAll(() {
    final file = File('lib/features/settings/settings_screen.dart');
    expect(file.existsSync(), true);
    flat = file.readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');
  });

  test('the search item and the full list share one tile builder', () {
    final item = flat.indexOf(
      'title: context.l10n.settingsTileClearStaleNodesTitle, '
      'subtitle: context.l10n.settingsTileClearStaleNodesSubtitle, '
      'keywords:',
    );
    expect(item, isNot(-1));
    final next = flat.indexOf('_SearchableSettingItem(', item);
    final body = flat.substring(item, next == -1 ? flat.length : next);
    expect(body.contains('tilesBuilder: _buildClearStaleNodesTiles'), true);
    expect(
      body.contains('switchBuilder:'),
      false,
      reason: 'a lone switch row hides the days slider',
    );
    expect(
      flat.contains(
        '..._buildClearStaleNodesTiles( context, settingsService, )',
      ),
      true,
      reason: 'the unfiltered list renders the same builder',
    );
  });

  test('search results render tilesBuilder in place of the plain row', () {
    final results = flat.indexOf('List<Widget> _buildSearchResultsSlivers(');
    expect(results, isNot(-1));
    final tiles = flat.indexOf(
      'if (item.tilesBuilder case final tiles?',
      results,
    );
    final row = flat.indexOf('else SettingsNavTile(', results);
    expect(tiles, isNot(-1));
    expect(row, isNot(-1));
    expect(tiles < row, true);
  });
}
