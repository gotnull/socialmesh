// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Phase 3 Slice C - pins the contract for the MeshCore-side contact
// picker that the automation trigger + action editors open when the
// protocol-filter pill is set to MeshCore:
//
//   - Picker renders one tile per MeshCore contact.
//   - Tapping a tile returns a `MeshCoreContactSelection` whose
//     `nodeNumPrefix` is the first 4 pubkey bytes as big-endian
//     uint32 - the same int Slice A/D use to round-trip the
//     contact through `AutomationMessage.from` and the action
//     dispatch helper.
//   - Empty / no-match states surface the right copy.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/widgets/meshcore_contact_selector_sheet.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/providers/meshcore_message_providers.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';

final _l10n = AppLocalizationsEn();

MeshCoreContact _contact(String name, List<int> keyBytes) {
  final pubKey = Uint8List(32);
  for (var i = 0; i < keyBytes.length && i < 32; i++) {
    pubKey[i] = keyBytes[i];
  }
  return MeshCoreContact(
    publicKey: pubKey,
    name: name,
    type: MeshCoreAdvType.chat,
    pathLength: -1,
    path: Uint8List(0),
    lastSeen: DateTime(2026, 5, 20, 10),
  );
}

class _StubContactsNotifier extends MeshCoreContactsNotifier {
  _StubContactsNotifier(this._seed);
  final List<MeshCoreContact> _seed;
  @override
  MeshCoreContactsState build() =>
      MeshCoreContactsState(contacts: List.unmodifiable(_seed));
}

Widget _wrap({required List<MeshCoreContact> contacts, required Widget child}) {
  return ProviderScope(
    overrides: [
      meshCoreContactsProvider.overrideWith(
        () => _StubContactsNotifier(contacts),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  testWidgets('renders one tile per MeshCore contact', (tester) async {
    final contacts = [
      _contact('Alpha', [0xAA, 0xBB, 0xCC, 0xDD]),
      _contact('Bravo', [0x11, 0x22, 0x33, 0x44]),
    ];

    await tester.pumpWidget(
      _wrap(
        contacts: contacts,
        child: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => MeshCoreContactSelectorSheet.show(
                context,
                title: _l10n.meshcoreContactSelectorTitle,
              ),
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Bravo'), findsOneWidget);
    expect(find.text(_l10n.meshcoreContactSelectorTitle), findsOneWidget);
  });

  testWidgets(
    'selecting a contact returns its pubkey-prefix as nodeNumPrefix',
    (tester) async {
      final contact = _contact('Charlie', [0xDE, 0xAD, 0xBE, 0xEF]);
      MeshCoreContactSelection? result;

      await tester.pumpWidget(
        _wrap(
          contacts: [contact],
          child: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  result = await MeshCoreContactSelectorSheet.show(
                    context,
                    title: _l10n.meshcoreContactSelectorTitle,
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Charlie'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.displayName, 'Charlie');
      // 0xDE_AD_BE_EF as big-endian uint32. Matches
      // `meshCoreSenderIdFromKey` derivation so the selection
      // round-trips through Slice A's inbound `AutomationMessage.from`.
      expect(result!.nodeNumPrefix, meshCoreSenderIdFromKey(contact.publicKey));
    },
  );

  testWidgets('empty contacts list surfaces the empty-state copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        contacts: [],
        child: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => MeshCoreContactSelectorSheet.show(
                context,
                title: _l10n.meshcoreContactSelectorTitle,
              ),
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(_l10n.meshcoreContactSelectorEmpty), findsOneWidget);
  });

  testWidgets('search filters by name and short-circuits to no-matches copy', (
    tester,
  ) async {
    final contacts = [
      _contact('Alpha', [0xAA, 0xBB, 0xCC, 0xDD]),
      _contact('Bravo', [0x11, 0x22, 0x33, 0x44]),
    ];

    await tester.pumpWidget(
      _wrap(
        contacts: contacts,
        child: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => MeshCoreContactSelectorSheet.show(
                context,
                title: _l10n.meshcoreContactSelectorTitle,
              ),
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Filter to Bravo only.
    await tester.enterText(find.byType(TextField), 'bra');
    await tester.pumpAndSettle();
    expect(find.text('Bravo'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);

    // Filter to nothing.
    await tester.enterText(find.byType(TextField), 'xyzzy');
    await tester.pumpAndSettle();
    expect(find.text(_l10n.meshcoreContactSelectorNoMatches), findsOneWidget);
  });
}
