// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/meshcore/contact_l10n.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/models/meshcore_contact.dart';

MeshCoreContact _contact(int type) {
  return MeshCoreContact(
    publicKey: Uint8List.fromList(List.generate(32, (i) => i)),
    name: 'TestNode',
    type: type,
    pathLength: 0,
    path: Uint8List(0),
    lastSeen: DateTime.now(),
  );
}

MeshCoreContact _contactWithPath({required int pathLength, int? pathOverride}) {
  return MeshCoreContact(
    publicKey: Uint8List.fromList(List.generate(32, (i) => i)),
    name: 'TestNode',
    type: MeshCoreAdvType.chat,
    pathLength: pathLength,
    path: Uint8List(0),
    pathOverride: pathOverride,
    lastSeen: DateTime.now(),
  );
}

void main() {
  final l10n = AppLocalizationsEn();

  group('MeshCoreContactL10n.localizedTypeLabel', () {
    test('chat → meshcoreChatNode', () {
      expect(
        _contact(MeshCoreAdvType.chat).localizedTypeLabel(l10n),
        l10n.meshcoreChatNode,
      );
    });

    test('repeater → meshcoreRepeaterNode', () {
      expect(
        _contact(MeshCoreAdvType.repeater).localizedTypeLabel(l10n),
        l10n.meshcoreRepeaterNode,
      );
    });

    test('room → meshcoreRoomNode', () {
      expect(
        _contact(MeshCoreAdvType.room).localizedTypeLabel(l10n),
        l10n.meshcoreRoomNode,
      );
    });

    test('sensor → meshcoreSensorNode', () {
      expect(
        _contact(MeshCoreAdvType.sensor).localizedTypeLabel(l10n),
        l10n.meshcoreSensorNode,
      );
    });

    test('unknown → meshcoreUnknown (fallback for unsupported types)', () {
      // The model's static label() uses the same fallback for unknown types;
      // this test pins the localized helper to the same defensive path so a
      // future protocol bump that introduces a new advert type doesn't fail
      // the UI silently.
      expect(_contact(99).localizedTypeLabel(l10n), l10n.meshcoreUnknown);
    });

    test(
      'static label() and localizedTypeLabel disagree on copy (intentional)',
      () {
        // The static label() returns the bare ASCII string 'Chat' for use in
        // toString/search. The localized version returns the richer "Chat
        // Node" copy used in user-facing surfaces. This test pins the
        // separation — if the static label is repurposed for display, this
        // test will fail and force a conscious decision.
        expect(MeshCoreAdvType.label(MeshCoreAdvType.chat), 'Chat');
        expect(
          _contact(MeshCoreAdvType.chat).localizedTypeLabel(l10n),
          isNot('Chat'),
        );
      },
    );
  });

  group('MeshCoreContactL10n.localizedPathLabel', () {
    test('pathLength: -1 (auto-flood) → meshcorePathFlood', () {
      expect(
        _contactWithPath(pathLength: -1).localizedPathLabel(l10n),
        l10n.meshcorePathFlood,
      );
    });

    test('pathLength: 0 (auto-direct) → meshcorePathDirect', () {
      expect(
        _contactWithPath(pathLength: 0).localizedPathLabel(l10n),
        l10n.meshcorePathDirect,
      );
    });

    test('pathLength: 3 (auto-hops) → meshcorePathHops with the count', () {
      expect(
        _contactWithPath(pathLength: 3).localizedPathLabel(l10n),
        l10n.meshcorePathHops(3),
      );
    });

    test('pathOverride wins over pathLength: -1 → meshcorePathFloodForced', () {
      // Auto-discovered direct path, but the user has forced flood. The
      // forced label must win to make the override visible.
      expect(
        _contactWithPath(
          pathLength: 0,
          pathOverride: -1,
        ).localizedPathLabel(l10n),
        l10n.meshcorePathFloodForced,
      );
    });

    test('pathOverride: 0 → meshcorePathDirectForced', () {
      expect(
        _contactWithPath(
          pathLength: -1,
          pathOverride: 0,
        ).localizedPathLabel(l10n),
        l10n.meshcorePathDirectForced,
      );
    });

    test(
      'pathOverride: 5 → meshcorePathHopsForced with the override count',
      () {
        expect(
          _contactWithPath(
            pathLength: 1,
            pathOverride: 5,
          ).localizedPathLabel(l10n),
          l10n.meshcorePathHopsForced(5),
        );
      },
    );
  });
}
