// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/widgets/channel_key_field.dart';
import 'package:socialmesh/features/channels/channel_wizard_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';

// The Shared privacy level used to pin the key to the 0x01 default and hide
// the key field. Community channels publish other one-byte keys, so the
// field now shows on Shared and a typed one-byte key reaches the review
// step intact.
Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: child,
    ),
  );
}

void main() {
  final l10n = AppLocalizationsEn();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'Shared level shows the key field and keeps a typed one-byte key',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrap(const ChannelWizardScreen(channelIndex: 3)),
      );
      await tester.pumpAndSettle();

      // Step 0: name.
      await tester.enterText(find.byType(TextField).first, 'BayMesh');
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.channelWizardContinueButton));
      await tester.pumpAndSettle();

      // Step 1: Shared, then keep the default key on the warning sheet.
      await tester.tap(find.text(l10n.channelWizardPrivacySharedTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.channelWizardContinueButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.channelWizardDefaultKeyKeep));
      await tester.pumpAndSettle();

      // Step 2: the key field is present for Shared and accepts a
      // one-byte key other than the default.
      expect(find.byType(ChannelKeyField), findsOneWidget);
      await tester.tap(find.text(l10n.channelKeyEdit));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Ag==');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l10n.channelKeyApply));
      await tester.pumpAndSettle();
      expect(find.text(l10n.channelWizardKeyWrongLength(1, 1)), findsNothing);

      await tester.tap(find.text(l10n.channelWizardContinueButton));
      await tester.pumpAndSettle();

      // Step 3: review carries the typed key, not the 0x01 default.
      expect(find.textContaining('Ag=='), findsWidgets);
      expect(find.textContaining('AQ=='), findsNothing);
    },
  );
}
