// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Tests for W3.1 - NodeDex SIP integration.
//
// Covers:
// - NodeDexEntry SIP fields (constructor, copyWith, toJson, fromJson, merge)
// - SigilGenerator.generateFromPersonaId determinism
// - SipNodeDexBridge (markSipCapable, applyIdentityClaim, updateIdentityState,
//   findEntriesByPubkey, clearIdentity)

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';
import 'package:socialmesh/features/nodedex/services/sigil_generator.dart';
import 'package:socialmesh/providers/sip_nodedex_bridge.dart';
import 'package:socialmesh/services/protocol/sip/sip_types.dart';

/// Helper to build a minimal NodeDexEntry for testing.
NodeDexEntry _entry({
  int nodeNum = 0xABCD1234,
  bool? sipCapable,
  Uint8List? sipPubkey,
  Uint8List? sipPersonaId,
  SipIdentityState? sipIdentityState,
  String? sipDisplayName,
  SigilData? sigil,
}) {
  final now = DateTime(2024, 6, 15);
  return NodeDexEntry(
    nodeNum: nodeNum,
    firstSeen: now,
    lastSeen: now,
    sipCapable: sipCapable,
    sipPubkey: sipPubkey,
    sipPersonaId: sipPersonaId,
    sipIdentityState: sipIdentityState,
    sipDisplayName: sipDisplayName,
    sigil: sigil,
  );
}

/// Helper: deterministic 32-byte pubkey.
Uint8List _pubkey([int seed = 0xAA]) =>
    Uint8List.fromList(List.generate(32, (i) => (seed + i) & 0xFF));

/// Helper: deterministic 16-byte persona_id.
Uint8List _personaId([int seed = 0xBB]) =>
    Uint8List.fromList(List.generate(16, (i) => (seed + i) & 0xFF));

void main() {
  // ===========================================================================
  // NodeDexEntry SIP fields
  // ===========================================================================

  group('NodeDexEntry SIP fields', () {
    test('constructor sets SIP fields', () {
      final pk = _pubkey();
      final pid = _personaId();
      final entry = _entry(
        sipCapable: true,
        sipPubkey: pk,
        sipPersonaId: pid,
        sipIdentityState: SipIdentityState.verifiedTofu,
        sipDisplayName: 'Alice', // lint-allow: hardcoded-string
      );

      expect(entry.sipCapable, isTrue);
      expect(entry.sipPubkey, pk);
      expect(entry.sipPersonaId, pid);
      expect(entry.sipIdentityState, SipIdentityState.verifiedTofu);
      expect(entry.sipDisplayName, 'Alice'); // lint-allow: hardcoded-string
    });

    test('constructor defaults SIP fields to null', () {
      final entry = _entry();
      expect(entry.sipCapable, isNull);
      expect(entry.sipPubkey, isNull);
      expect(entry.sipPersonaId, isNull);
      expect(entry.sipIdentityState, isNull);
      expect(entry.sipDisplayName, isNull);
    });

    test('copyWith sets SIP fields', () {
      final entry = _entry();
      final pk = _pubkey();
      final pid = _personaId();
      final updated = entry.copyWith(
        sipCapable: true,
        sipPubkey: pk,
        sipPersonaId: pid,
        sipIdentityState: SipIdentityState.pinned,
        sipDisplayName: 'Bob', // lint-allow: hardcoded-string
      );

      expect(updated.sipCapable, isTrue);
      expect(updated.sipPubkey, pk);
      expect(updated.sipPersonaId, pid);
      expect(updated.sipIdentityState, SipIdentityState.pinned);
      expect(updated.sipDisplayName, 'Bob'); // lint-allow: hardcoded-string
    });

    test('copyWith clears SIP fields', () {
      final entry = _entry(
        sipCapable: true,
        sipPubkey: _pubkey(),
        sipPersonaId: _personaId(),
        sipIdentityState: SipIdentityState.verifiedTofu,
        sipDisplayName: 'Alice', // lint-allow: hardcoded-string
      );

      final cleared = entry.copyWith(
        clearSipCapable: true,
        clearSipPubkey: true,
        clearSipPersonaId: true,
        clearSipIdentityState: true,
        clearSipDisplayName: true,
      );

      expect(cleared.sipCapable, isNull);
      expect(cleared.sipPubkey, isNull);
      expect(cleared.sipPersonaId, isNull);
      expect(cleared.sipIdentityState, isNull);
      expect(cleared.sipDisplayName, isNull);
    });

    test('toJson includes SIP fields', () {
      final pk = _pubkey();
      final pid = _personaId();
      final entry = _entry(
        sipCapable: true,
        sipPubkey: pk,
        sipPersonaId: pid,
        sipIdentityState: SipIdentityState.verifiedTofu,
        sipDisplayName: 'Charlie', // lint-allow: hardcoded-string
      );

      final json = entry.toJson();
      expect(json['sip_cap'], isTrue);
      expect(json['sip_pk'], base64Encode(pk));
      expect(json['sip_pid'], base64Encode(pid));
      expect(json['sip_st'], 'verifiedTofu'); // lint-allow: hardcoded-string
      expect(json['sip_dn'], 'Charlie'); // lint-allow: hardcoded-string
    });

    test('toJson omits null SIP fields', () {
      final entry = _entry();
      final json = entry.toJson();
      expect(json.containsKey('sip_cap'), isFalse);
      expect(json.containsKey('sip_pk'), isFalse);
      expect(json.containsKey('sip_pid'), isFalse);
      expect(json.containsKey('sip_st'), isFalse);
      expect(json.containsKey('sip_dn'), isFalse);
    });

    test('fromJson round-trips SIP fields', () {
      final pk = _pubkey();
      final pid = _personaId();
      final entry = _entry(
        sipCapable: true,
        sipPubkey: pk,
        sipPersonaId: pid,
        sipIdentityState: SipIdentityState.pinned,
        sipDisplayName: 'Dave', // lint-allow: hardcoded-string
      );

      final json = entry.toJson();
      final restored = NodeDexEntry.fromJson(json);

      expect(restored.sipCapable, isTrue);
      expect(restored.sipPubkey, pk);
      expect(restored.sipPersonaId, pid);
      expect(restored.sipIdentityState, SipIdentityState.pinned);
      expect(restored.sipDisplayName, 'Dave'); // lint-allow: hardcoded-string
    });

    test('fromJson handles missing SIP fields gracefully', () {
      // Simulate a pre-SIP JSON (no sip_* fields).
      final json = _entry().toJson();
      json.remove('sip_cap');
      json.remove('sip_pk');
      json.remove('sip_pid');
      json.remove('sip_st');
      json.remove('sip_dn');

      final restored = NodeDexEntry.fromJson(json);
      expect(restored.sipCapable, isNull);
      expect(restored.sipPubkey, isNull);
      expect(restored.sipPersonaId, isNull);
      expect(restored.sipIdentityState, isNull);
      expect(restored.sipDisplayName, isNull);
    });

    test('fromJson handles unknown identity state gracefully', () {
      final json = _entry().toJson();
      json['sip_st'] = 'future_unknown_state'; // lint-allow: hardcoded-string
      final restored = NodeDexEntry.fromJson(json);
      expect(restored.sipIdentityState, isNull);
    });

    test('mergeWith prefers more recently seen SIP data', () {
      final pk1 = _pubkey(0x11);
      final pid1 = _personaId(0x11);
      final pk2 = _pubkey(0x22);
      final pid2 = _personaId(0x22);

      final older = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 1, 1),
        sipCapable: true,
        sipPubkey: pk1,
        sipPersonaId: pid1,
        sipIdentityState: SipIdentityState.verifiedTofu,
        sipDisplayName: 'OldName', // lint-allow: hardcoded-string
      );

      final newer = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        sipCapable: true,
        sipPubkey: pk2,
        sipPersonaId: pid2,
        sipIdentityState: SipIdentityState.pinned,
        sipDisplayName: 'NewName', // lint-allow: hardcoded-string
      );

      final merged = older.mergeWith(newer);
      expect(merged.sipPubkey, pk2);
      expect(merged.sipPersonaId, pid2);
      expect(merged.sipIdentityState, SipIdentityState.pinned);
      expect(merged.sipDisplayName, 'NewName'); // lint-allow: hardcoded-string
    });

    test('mergeWith falls back to non-null SIP data', () {
      final pk = _pubkey();
      final pid = _personaId();
      final withSip = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 1, 1),
        sipCapable: true,
        sipPubkey: pk,
        sipPersonaId: pid,
        sipIdentityState: SipIdentityState.verifiedTofu,
      );

      final withoutSip = NodeDexEntry(
        nodeNum: 42,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
      );

      // Newer entry has no SIP data; should fall back to older's data.
      final merged = withoutSip.mergeWith(withSip);
      expect(merged.sipCapable, isTrue);
      expect(merged.sipPubkey, pk);
      expect(merged.sipPersonaId, pid);
      expect(merged.sipIdentityState, SipIdentityState.verifiedTofu);
    });

    test('equality includes SIP fields', () {
      final a = _entry(
        sipCapable: true,
        sipIdentityState: SipIdentityState.pinned,
        sipDisplayName: 'Test', // lint-allow: hardcoded-string
      );
      final b = _entry(
        sipCapable: true,
        sipIdentityState: SipIdentityState.pinned,
        sipDisplayName: 'Test', // lint-allow: hardcoded-string
      );
      final c = _entry(
        sipCapable: true,
        sipIdentityState: SipIdentityState.changedKey,
        sipDisplayName: 'Test', // lint-allow: hardcoded-string
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  // ===========================================================================
  // SigilGenerator.generateFromPersonaId
  // ===========================================================================

  group('SigilGenerator.generateFromPersonaId', () {
    test('produces deterministic sigil from persona_id', () {
      final pid = _personaId(0xAA);
      final s1 = SigilGenerator.generateFromPersonaId(pid);
      final s2 = SigilGenerator.generateFromPersonaId(pid);

      expect(s1.vertices, s2.vertices);
      expect(s1.rotation, s2.rotation);
      expect(s1.innerRings, s2.innerRings);
      expect(s1.drawRadials, s2.drawRadials);
      expect(s1.centerDot, s2.centerDot);
      expect(s1.symmetryFold, s2.symmetryFold);
      expect(s1.primaryColor, s2.primaryColor);
      expect(s1.secondaryColor, s2.secondaryColor);
      expect(s1.tertiaryColor, s2.tertiaryColor);
    });

    test('different persona_ids produce different sigils', () {
      final s1 = SigilGenerator.generateFromPersonaId(_personaId(0x01));
      final s2 = SigilGenerator.generateFromPersonaId(_personaId(0x99));

      // At least one visual parameter should differ.
      final differ =
          s1.vertices != s2.vertices ||
          s1.rotation != s2.rotation ||
          s1.innerRings != s2.innerRings ||
          s1.primaryColor != s2.primaryColor;
      expect(differ, isTrue);
    });

    test('persona_id sigil differs from node_num sigil', () {
      final nodeNum = 0xABCD1234;
      final pid = _personaId(0xCC); // different seed, so different 4 bytes

      final fromNode = SigilGenerator.generate(nodeNum);
      final fromPid = SigilGenerator.generateFromPersonaId(pid);

      // Should differ at least in some visual parameter.
      final differ =
          fromNode.vertices != fromPid.vertices ||
          fromNode.rotation != fromPid.rotation ||
          fromNode.primaryColor != fromPid.primaryColor ||
          fromNode.innerRings != fromPid.innerRings;
      expect(differ, isTrue);
    });

    test('colorsForPersonaId returns consistent colors', () {
      final pid = _personaId(0x55);
      final (p1, s1, t1) = SigilGenerator.colorsForPersonaId(pid);
      final (p2, s2, t2) = SigilGenerator.colorsForPersonaId(pid);

      expect(p1, p2);
      expect(s1, s2);
      expect(t1, t2);
    });

    test('same first 4 bytes produce same sigil regardless of rest', () {
      final pid1 = Uint8List.fromList([
        0xDE,
        0xAD,
        0xBE,
        0xEF,
        ...List.filled(12, 0x00),
      ]);
      final pid2 = Uint8List.fromList([
        0xDE,
        0xAD,
        0xBE,
        0xEF,
        ...List.filled(12, 0xFF),
      ]);

      final s1 = SigilGenerator.generateFromPersonaId(pid1);
      final s2 = SigilGenerator.generateFromPersonaId(pid2);

      expect(s1.vertices, s2.vertices);
      expect(s1.rotation, s2.rotation);
      expect(s1.primaryColor, s2.primaryColor);
    });
  });

  // ===========================================================================
  // SipNodeDexBridge
  // ===========================================================================

  group('SipNodeDexBridge', () {
    group('markSipCapable', () {
      test('marks non-SIP entry as sip_capable', () {
        final entry = _entry();
        final result = SipNodeDexBridge.markSipCapable(entry);

        expect(result.entry.sipCapable, isTrue);
        expect(result.stateChanged, isTrue);
        expect(result.sigilChanged, isFalse);
      });

      test('no-op when already sip_capable', () {
        final entry = _entry(sipCapable: true);
        final result = SipNodeDexBridge.markSipCapable(entry);

        expect(result.entry.sipCapable, isTrue);
        expect(result.stateChanged, isFalse);
      });
    });

    group('applyIdentityClaim', () {
      test('applies identity with TOFU state', () {
        final entry = _entry();
        final pk = _pubkey();
        final pid = _personaId();

        final result = SipNodeDexBridge.applyIdentityClaim(
          entry: entry,
          pubkey: pk,
          personaId: pid,
          identityState: SipIdentityState.verifiedTofu,
          displayName: 'Alice', // lint-allow: hardcoded-string
        );

        expect(result.entry.sipCapable, isTrue);
        expect(result.entry.sipPubkey, pk);
        expect(result.entry.sipPersonaId, pid);
        expect(result.entry.sipIdentityState, SipIdentityState.verifiedTofu);
        expect(
          result.entry.sipDisplayName,
          'Alice',
        ); // lint-allow: hardcoded-string
        expect(result.sigilChanged, isTrue);
        expect(result.stateChanged, isTrue);
      });

      test('regenerates sigil from persona_id', () {
        final entry = _entry();
        final pid = _personaId(0x42);

        final result = SipNodeDexBridge.applyIdentityClaim(
          entry: entry,
          pubkey: _pubkey(),
          personaId: pid,
          identityState: SipIdentityState.verifiedTofu,
        );

        final expectedSigil = SigilGenerator.generateFromPersonaId(pid);
        expect(result.entry.sigil!.vertices, expectedSigil.vertices);
        expect(result.entry.sigil!.rotation, expectedSigil.rotation);
        expect(result.entry.sigil!.primaryColor, expectedSigil.primaryColor);
        expect(result.sigilChanged, isTrue);
      });

      test('does not regenerate sigil when persona_id unchanged', () {
        final pid = _personaId();
        final existingSigil = SigilGenerator.generateFromPersonaId(pid);
        final entry = _entry(
          sipCapable: true,
          sipPersonaId: pid,
          sipIdentityState: SipIdentityState.verifiedTofu,
          sigil: existingSigil,
        );

        final result = SipNodeDexBridge.applyIdentityClaim(
          entry: entry,
          pubkey: _pubkey(),
          personaId: pid,
          identityState: SipIdentityState.pinned,
        );

        expect(result.sigilChanged, isFalse);
        expect(result.stateChanged, isTrue);
      });

      test('applies identity without display name', () {
        final entry = _entry();
        final result = SipNodeDexBridge.applyIdentityClaim(
          entry: entry,
          pubkey: _pubkey(),
          personaId: _personaId(),
          identityState: SipIdentityState.verifiedTofu,
        );

        expect(result.entry.sipDisplayName, isNull);
      });
    });

    group('updateIdentityState', () {
      test('updates state from TOFU to pinned', () {
        final entry = _entry(
          sipCapable: true,
          sipIdentityState: SipIdentityState.verifiedTofu,
        );

        final result = SipNodeDexBridge.updateIdentityState(
          entry: entry,
          newState: SipIdentityState.pinned,
        );

        expect(result.entry.sipIdentityState, SipIdentityState.pinned);
        expect(result.stateChanged, isTrue);
      });

      test('no-op when state unchanged', () {
        final entry = _entry(
          sipCapable: true,
          sipIdentityState: SipIdentityState.pinned,
        );

        final result = SipNodeDexBridge.updateIdentityState(
          entry: entry,
          newState: SipIdentityState.pinned,
        );

        expect(result.stateChanged, isFalse);
      });

      test('sets changedKey state', () {
        final entry = _entry(
          sipCapable: true,
          sipIdentityState: SipIdentityState.verifiedTofu,
        );

        final result = SipNodeDexBridge.updateIdentityState(
          entry: entry,
          newState: SipIdentityState.changedKey,
        );

        expect(result.entry.sipIdentityState, SipIdentityState.changedKey);
        expect(result.stateChanged, isTrue);
      });
    });

    group('findEntriesByPubkey', () {
      test('finds entries with matching pubkey', () {
        final pk = _pubkey(0x42);
        final entries = <int, NodeDexEntry>{
          1: _entry(nodeNum: 1, sipPubkey: pk),
          2: _entry(nodeNum: 2, sipPubkey: _pubkey(0x99)),
          3: _entry(nodeNum: 3, sipPubkey: pk),
          4: _entry(nodeNum: 4),
        };

        final matches = SipNodeDexBridge.findEntriesByPubkey(entries, pk);
        expect(matches.length, 2);
        expect(matches.map((e) => e.nodeNum).toSet(), {1, 3});
      });

      test('returns empty list when no matches', () {
        final entries = <int, NodeDexEntry>{
          1: _entry(nodeNum: 1),
          2: _entry(nodeNum: 2, sipPubkey: _pubkey(0x99)),
        };

        final matches = SipNodeDexBridge.findEntriesByPubkey(
          entries,
          _pubkey(0x42),
        );
        expect(matches, isEmpty);
      });
    });

    group('clearIdentity', () {
      test('clears all SIP fields', () {
        final entry = _entry(
          sipCapable: true,
          sipPubkey: _pubkey(),
          sipPersonaId: _personaId(),
          sipIdentityState: SipIdentityState.pinned,
          sipDisplayName: 'Alice', // lint-allow: hardcoded-string
        );

        final result = SipNodeDexBridge.clearIdentity(entry);

        expect(result.entry.sipCapable, isNull);
        expect(result.entry.sipPubkey, isNull);
        expect(result.entry.sipPersonaId, isNull);
        expect(result.entry.sipIdentityState, isNull);
        expect(result.entry.sipDisplayName, isNull);
        expect(result.sigilChanged, isTrue);
        expect(result.stateChanged, isTrue);
      });

      test('reverts sigil to node_num based', () {
        final nodeNum = 0xDEAD;
        final entry = _entry(
          nodeNum: nodeNum,
          sipCapable: true,
          sipPersonaId: _personaId(),
          sigil: SigilGenerator.generateFromPersonaId(_personaId()),
        );

        final result = SipNodeDexBridge.clearIdentity(entry);
        final expectedSigil = SigilGenerator.generate(nodeNum);
        expect(result.entry.sigil!.vertices, expectedSigil.vertices);
        expect(result.entry.sigil!.rotation, expectedSigil.rotation);
        expect(result.entry.sigil!.primaryColor, expectedSigil.primaryColor);
      });
    });
  });
}
