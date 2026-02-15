// SPDX-License-Identifier: GPL-3.0-or-later

/// Static analysis guard: ensures no inline MeshPacket construction bypasses
/// the [MeshPacketBuilder] abstraction in protocol_service.dart, and that
/// the protocol service does not directly reference [MeshPacket_Priority.RELIABLE]
/// or set [wantAck] on packets (those belong exclusively in the builder).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Protocol service guardrail: no inline packet construction', () {
    late String source;

    setUpAll(() {
      final file = File('lib/services/protocol/protocol_service.dart');
      source = file.readAsStringSync();
    });

    test('protocol_service.dart does not contain pb.MeshPacket() construction', () {
      // MeshPacket() appears as a type annotation in method parameters
      // (e.g. `pb.MeshPacket packet`) which is fine. We only want to ban
      // construction: `pb.MeshPacket()` followed by `..` (cascade) or `;`.
      final constructionPattern = RegExp(
        r'pb\.MeshPacket\(\)\s*(\.\.|;)',
        multiLine: true,
      );

      final matches = constructionPattern.allMatches(source).toList();

      expect(
        matches,
        isEmpty,
        reason:
            'Found ${matches.length} inline pb.MeshPacket() construction(s) in '
            'protocol_service.dart. All packet construction must go through '
            'MeshPacketBuilder to enforce local/remote admin invariants. '
            'First match near: "${matches.isNotEmpty ? source.substring(matches.first.start, (matches.first.start + 80).clamp(0, source.length)) : "none"}"',
      );
    });

    test('protocol_service.dart does not reference MeshPacket_Priority.RELIABLE', () {
      final reliablePattern = RegExp(
        r'MeshPacket_Priority\.RELIABLE',
        multiLine: true,
      );

      final matches = reliablePattern.allMatches(source).toList();

      expect(
        matches,
        isEmpty,
        reason:
            'Found ${matches.length} reference(s) to MeshPacket_Priority.RELIABLE '
            'in protocol_service.dart. Priority assignment belongs exclusively in '
            'MeshPacketBuilder to prevent accidental RELIABLE on local admin packets.',
      );
    });

    test('protocol_service.dart does not set ..wantAck on packets', () {
      // Match `..wantAck = true` (the problematic pattern).
      // Parameter declarations like `bool wantAck = true` in method
      // signatures are fine — only cascade assignment on packets is banned.
      final wantAckPattern = RegExp(
        r'\.\.\s*wantAck\s*=\s*true',
        multiLine: true,
      );

      final matches = wantAckPattern.allMatches(source).toList();

      expect(
        matches,
        isEmpty,
        reason:
            'Found ${matches.length} instance(s) of ..wantAck = true in '
            'protocol_service.dart. Packet wantAck assignment belongs exclusively '
            'in MeshPacketBuilder. Use MeshPacketBuilder.userPayload(wantAck: true) '
            'for user payloads or MeshPacketBuilder.remoteAdmin() for remote admin.',
      );
    });
  });
}
