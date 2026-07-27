// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport_path.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

void main() {
  group('classifyTransport', () {
    test('null returns unknown', () {
      expect(classifyTransport(null), TransportPath.unknown);
    });

    test('true returns mqtt', () {
      expect(classifyTransport(true), TransportPath.mqtt);
    });

    test('false returns rf', () {
      expect(classifyTransport(false), TransportPath.rf);
    });
  });

  group('TransportPath.localizedLabel', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final pt = lookupAppLocalizations(const Locale('pt'));

    test('rf label is RF in every locale', () {
      expect(TransportPath.rf.localizedLabel(en), 'RF');
      expect(TransportPath.rf.localizedLabel(pt), 'RF');
    });

    test('mqtt label is MQTT in every locale', () {
      expect(TransportPath.mqtt.localizedLabel(en), 'MQTT');
      expect(TransportPath.mqtt.localizedLabel(pt), 'MQTT');
    });

    test('unknown label is translated', () {
      expect(TransportPath.unknown.localizedLabel(en), 'Unknown');
      expect(TransportPath.unknown.localizedLabel(pt), 'Desconhecido');
    });

    test('every supported locale has non-empty transport labels', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = lookupAppLocalizations(locale);
        for (final path in TransportPath.values) {
          expect(
            path.localizedLabel(l10n).trim(),
            isNotEmpty,
            reason: 'empty ${path.name} label for $locale',
          );
        }
      }
    });
  });
}
