// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/utils/channel_display_name.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('channelDisplayName', () {
    test('keeps a channel name that is set', () {
      expect(channelDisplayName(l10n, index: 0, name: 'LongFast'), 'LongFast');
      expect(channelDisplayName(l10n, index: 3, name: 'Ops'), 'Ops');
    });

    test('names an unnamed primary channel', () {
      expect(
        channelDisplayName(l10n, index: 0, name: ''),
        l10n.channelsPrimaryChannelName,
      );
    });

    test('names an unnamed secondary channel by its index', () {
      expect(
        channelDisplayName(l10n, index: 2, name: ''),
        l10n.channelsDefaultChannelName(2),
      );
    });

    test('treats a whitespace-only name as unnamed', () {
      expect(
        channelDisplayName(l10n, index: 0, name: '   '),
        l10n.channelsPrimaryChannelName,
      );
    });

    test('uses the localised default in another locale', () {
      final de = lookupAppLocalizations(const Locale('de'));
      expect(
        channelDisplayName(de, index: 0, name: ''),
        de.channelsPrimaryChannelName,
      );
    });
  });
}
