// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/canned_response.dart';
import 'package:socialmesh/l10n/l10n_utils.dart';

void main() {
  tearDown(() => setPreferredLocaleOverride(null));

  group('DefaultCannedResponses.localized in Portuguese', () {
    setUp(() => setPreferredLocaleOverride(const Locale('pt')));

    test('stock defaults frozen in English re-resolve to Portuguese', () {
      final stored = [
        CannedResponse(
          id: 'default_yes',
          text: 'Yes',
          sortOrder: 0,
          isDefault: true,
        ),
        CannedResponse(
          id: 'default_no',
          text: 'No',
          sortOrder: 1,
          isDefault: true,
        ),
      ];
      final localized = DefaultCannedResponses.localized(stored);
      expect(localized[0].text, 'Sim');
      expect(localized[1].text, 'Não');
      expect(localized[0].id, 'default_yes');
      expect(localized[0].sortOrder, 0);
    });

    test('legacy alert-bell label is localised, never left as the frozen '
        'English text', () {
      final stored = [
        CannedResponse(id: 'user-1', text: '\u{1F514} Alert Bell Character'),
      ];
      final localized = DefaultCannedResponses.localized(stored);
      expect(localized.single.text, '\u{1F514} Símbolo da campainha de alerta');
    });

    test('alert-bell label without the emoji prefix is also localised', () {
      final stored = [
        CannedResponse(id: 'user-2', text: 'Alert bell character'),
      ];
      final localized = DefaultCannedResponses.localized(stored);
      expect(localized.single.text, 'Símbolo da campainha de alerta');
    });

    test('edited default text is user content and is never rewritten', () {
      final stored = [
        CannedResponse(
          id: 'default_yes',
          text: 'Yes captain',
          sortOrder: 0,
          isDefault: true,
        ),
      ];
      final localized = DefaultCannedResponses.localized(stored);
      expect(localized.single.text, 'Yes captain');
    });

    test('genuine user-created replies are never rewritten', () {
      final stored = [
        CannedResponse(id: 'user-3', text: 'A caminho do repetidor'),
        CannedResponse(id: 'user-4', text: 'Sim senhor'),
      ];
      final localized = DefaultCannedResponses.localized(stored);
      expect(localized[0].text, 'A caminho do repetidor');
      expect(localized[1].text, 'Sim senhor');
    });

    test('defaults frozen in Portuguese re-resolve when switching back to '
        'English', () {
      setPreferredLocaleOverride(const Locale('en'));
      final stored = [
        CannedResponse(
          id: 'default_help',
          text: 'Preciso de ajuda',
          sortOrder: 0,
          isDefault: true,
        ),
      ];
      final localized = DefaultCannedResponses.localized(stored);
      expect(localized.single.text, 'Need help');
    });

    test('DefaultCannedResponses.all resolves in the active locale', () {
      final all = DefaultCannedResponses.all;
      expect(all.map((r) => r.text), containsAll(['Sim', 'Não', 'OK']));
      expect(all, hasLength(8));
    });
  });
}
