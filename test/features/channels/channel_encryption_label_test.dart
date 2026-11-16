// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
