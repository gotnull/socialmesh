// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/widgets/channel_key_field.dart';
import 'package:socialmesh/features/channels/channel_form_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';

// The Channels overflow menu opens ChannelFormScreen directly (no wizard)
// so a community's published channel name and pre-shared key can be
// entered by hand. This pins the form's new-channel mode: it renders with
// an editable key field, exposes the one-byte "Default (Simple)" size that
// the wizard hides, and accepts a typed one-byte key other than 0x01.
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

  testWidgets('new-channel mode renders the editable key field', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(const ChannelFormScreen(channelIndex: 3)));
    await tester.pumpAndSettle();

    expect(find.text(l10n.channelFormNewTitle), findsOneWidget);
    expect(find.byType(ChannelKeyField), findsOneWidget);
    expect(find.text(l10n.channelFormKeySizeDefault), findsOneWidget);
    expect(find.text(l10n.channelKeyEdit), findsOneWidget);
  });

  testWidgets(
    'a typed one-byte key is accepted after choosing the simple size',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrap(const ChannelFormScreen(channelIndex: 3)));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.channelFormKeySizeDefault));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.channelKeyEdit));
      await tester.pumpAndSettle();

      final field = find.byType(TextField).last;
      await tester.enterText(field, 'Ag==');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(l10n.channelKeyApply));
      await tester.pumpAndSettle();

      expect(find.text('Ag=='), findsOneWidget);
      expect(find.text(l10n.channelWizardKeyWrongLength(1, 1)), findsNothing);
      expect(find.text(l10n.channelFormInvalidBase64), findsNothing);
    },
  );
}
