// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Polish pass after Phase 3 Slice C - pins that the trigger
// node-filter card shows the picked MeshCore contact's name (and
// pubkey-hex prefix) instead of the empty-state "Any Node" label
// when the trigger is pinned to MeshCore. The original Slice C
// implementation looked up the selection against the Meshtastic
// `availableNodes` list and silently fell through to the
// empty-state label when a MeshCore contact was picked, leaving
// the user with no visual confirmation their pick was saved.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/automations/models/automation.dart';
import 'package:socialmesh/features/automations/widgets/trigger_selector.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/providers/meshcore_message_providers.dart';

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

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: ThemeData.dark(),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets(
    'meshcore-pinned trigger with a picked contact shows the contact name (not Any Node)',
    (tester) async {
      final contact = _contact('TerryDev2', [0xAA, 0xBB, 0xCC, 0xDD]);
      final nodeNumPrefix = meshCoreSenderIdFromKey(contact.publicKey);

      final trigger = AutomationTrigger(
        type: TriggerType.messageReceived,
        config: {'protocolFilter': 'meshcore', 'nodeNum': nodeNumPrefix},
      );

      await tester.pumpWidget(
        _wrap(
          TriggerSelector(
            trigger: trigger,
            availableMeshCoreContacts: [contact],
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The picked contact's name surfaces in the node-filter card,
      // and the empty-state label is absent.
      expect(find.text('TerryDev2'), findsOneWidget);
      expect(find.text(_l10n.automationTriggerAnyNode), findsNothing);
      // The hex prefix shows as the subtitle (first 8 chars of the
      // pubkey hex).
      expect(find.text(contact.publicKeyHex.substring(0, 8)), findsOneWidget);
    },
  );

  testWidgets(
    'meshcore-pinned trigger with no picked contact still shows Any Node',
    (tester) async {
      const trigger = AutomationTrigger(
        type: TriggerType.messageReceived,
        config: {'protocolFilter': 'meshcore'},
      );

      await tester.pumpWidget(
        _wrap(
          TriggerSelector(
            trigger: trigger,
            availableMeshCoreContacts: const [],
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_l10n.automationTriggerAnyNode), findsOneWidget);
    },
  );

  testWidgets(
    'meshcore-pinned trigger whose contact is missing falls back gracefully',
    (tester) async {
      // Contact was picked at some past point but the contact has
      // since been removed from the roster. The label must not
      // crash - it falls through to Any Node since there's no
      // matching contact to resolve the prefix back to.
      const trigger = AutomationTrigger(
        type: TriggerType.messageReceived,
        config: {'protocolFilter': 'meshcore', 'nodeNum': 0x12345678},
      );

      await tester.pumpWidget(
        _wrap(
          TriggerSelector(
            trigger: trigger,
            availableMeshCoreContacts: const [],
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_l10n.automationTriggerAnyNode), findsOneWidget);
    },
  );
}
