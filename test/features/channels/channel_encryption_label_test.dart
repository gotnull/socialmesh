// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/theme.dart';
import 'package:socialmesh/features/channels/channel_encryption_label.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/models/mesh_models.dart';

void main() {
  final l10n = AppLocalizationsEn();

  testWidgets('each encryption state has its own label', (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(
      channelEncryptionLabel(captured, ChannelEncryption.none),
      l10n.channelsTileNoEncryption,
    );
    expect(
      channelEncryptionLabel(captured, ChannelEncryption.publicKey),
      l10n.channelsTileDefaultKey,
    );
    expect(
      channelEncryptionLabel(captured, ChannelEncryption.privateKey),
      l10n.channelsTileEncrypted,
    );
  });

  group('channelLockStyle', () {
    ChannelConfig channel({int precision = 0, bool uplink = false}) =>
        ChannelConfig(
          index: 0,
          name: '',
          psk: const [1],
          positionPrecision: precision,
          uplink: uplink,
        );

    test('a channel with its own key gets a green closed lock', () {
      final style = channelLockStyle(
        channel(precision: 32, uplink: true),
        ChannelEncryption.privateKey,
      );
      expect(style.icon, Icons.lock);
      expect(style.color, SemanticColors.success);
    });

    test('a public or open channel gets a yellow open lock', () {
      for (final encryption in [
        ChannelEncryption.publicKey,
        ChannelEncryption.none,
      ]) {
        final style = channelLockStyle(channel(precision: 13), encryption);
        expect(style.icon, Icons.lock_open);
        expect(style.color, SemanticColors.warning);
      }
    });

    test('precise location on a public channel turns it red', () {
      for (final precision in [17, 32]) {
        final style = channelLockStyle(
          channel(precision: precision),
          ChannelEncryption.publicKey,
        );
        expect(style.icon, Icons.lock_open);
        expect(style.color, SemanticColors.error);
      }
      expect(
        channelLockStyle(
          channel(precision: 16),
          ChannelEncryption.publicKey,
        ).color,
        SemanticColors.warning,
      );
    });

    test('precise location with MQTT uplink adds the warning badge', () {
      final style = channelLockStyle(
        channel(precision: 32, uplink: true),
        ChannelEncryption.publicKey,
      );
      expect(style.icon, Icons.no_encryption_gmailerrorred);
      expect(style.color, SemanticColors.error);
    });
  });
}
