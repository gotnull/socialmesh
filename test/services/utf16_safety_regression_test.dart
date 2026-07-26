// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Regression coverage for the "Invalid argument(s): string is not well-formed
// UTF-16" crash in `_NativeParagraphBuilder.addText`. Each test feeds bytes
// containing a lone UTF-16 surrogate or NUL byte through one of the protocol
// ingress points, then asserts the resulting string is well-formed UTF-16
// (no lone surrogates, no NUL bytes) so it cannot crash Flutter's text shaper.

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodes/node_display_name_resolver.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_messages.dart';

bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;
bool _isLowSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;

bool isWellFormedUtf16(String s) {
  final units = s.codeUnits;
  for (var i = 0; i < units.length; i++) {
    final unit = units[i];
    if (_isHighSurrogate(unit)) {
      if (i + 1 >= units.length || !_isLowSurrogate(units[i + 1])) return false;
      i++;
    } else if (_isLowSurrogate(unit)) {
      return false;
    }
  }
  return true;
}

bool containsNul(String s) => s.codeUnits.contains(0);

/// Smoke test: feed [s] to the same ParagraphBuilder Flutter uses for
/// `Text(...)` and verify it does not throw. Mirrors the crashing call in
/// `_NativeParagraphBuilder.addText`.
void expectRendersWithoutCrash(String s) {
  final builder = ui.ParagraphBuilder(ui.ParagraphStyle());
  expect(() => builder.addText(s), returnsNormally);
}

void main() {
  group('MeshCore contact name ingress', () {
    test('lone high surrogate code unit in name bytes is sanitized', () {
      // D24.B: parseContact layout corrected to match the firmware's
      // contact-response writer:
      //   [0..31]    pub_key                      (32 bytes)
      //   [32]       adv_type                     (uint8)
      //   [33]       flags                        (uint8)
      //   [34]       path_len                     (uint8 / 0xFF flood)
      //   [35..98]   path                         (64 bytes)
      //   [99..130]  name                         (32 bytes null-padded)
      //   [131..134] last_advert_timestamp        (uint32 LE)
      //   [135..146] gps_lat / gps_lon / lastmod  (optional)
      //
      // The minimum-length parse path requires 135 bytes
      // (pubkey + type + flags + path_len + path + name +
      // last_advert_timestamp). Name lives at offset 99.
      final payload = Uint8List(135);
      payload[99] = 0x41; // 'A'
      payload[100] = 0xD8; // lone high surrogate code unit
      payload[101] = 0x42; // 'B'
      // Trailing bytes 102..130 stay 0 → null-terminated within the
      // 32-byte name slot.
      // [131..134] = last_advert_timestamp left at 0.

      final result = parseContact(payload);

      expect(result.isSuccess, isTrue);
      final name = result.value!.name;
      expect(isWellFormedUtf16(name), isTrue);
      expect(containsNul(name), isFalse);
      expectRendersWithoutCrash(name);
    });
  });

  group('MeshCore channel-info name ingress', () {
    test('lone low surrogate in name bytes is sanitized', () {
      // CHANNEL_INFO payload: idx(1) + name(32, null-terminated) + psk(16).
      final payload = Uint8List(49);
      payload[0] = 0x01;
      payload[1] = 0x4D; // 'M'
      payload[2] = 0xDC; // lone low surrogate code unit
      payload[3] = 0x4E; // 'N'
      // payload[4..32] stays 0 (null-terminated within the 32-byte slot).
      // payload[33..48] PSK = zero is fine.

      final result = parseChannelInfo(payload);

      expect(result.isSuccess, isTrue);
      final name = result.value!.name;
      expect(isWellFormedUtf16(name), isTrue);
      expect(containsNul(name), isFalse);
      expectRendersWithoutCrash(name);
    });
  });

  group('MeshCore buffer reader', () {
    test('readCString sanitizes lone surrogate code units', () {
      final reader = MeshCoreBufferReader(
        Uint8List.fromList([0x41, 0xDB, 0xFF, 0x42, 0x00, 0x99]),
      );
      final s = reader.readCString(6);
      expect(isWellFormedUtf16(s), isTrue);
      expect(containsNul(s), isFalse);
      expectRendersWithoutCrash(s);
    });

    test('readString strips trailing nuls and sanitizes surrogates', () {
      final reader = MeshCoreBufferReader(
        Uint8List.fromList([0x41, 0xD8, 0x00, 0x42, 0x00, 0x00]),
      );
      final s = reader.readString();
      expect(isWellFormedUtf16(s), isTrue);
      expect(containsNul(s), isFalse);
      expectRendersWithoutCrash(s);
    });
  });

  group('Meshtastic NodeInfo ingress: malformed UTF-8 in User.long_name', () {
    // A peer advertises a long_name whose bytes are not valid UTF-8. The
    // firmware defect behind CVE-2026-42566 produced exactly this by writing
    // a null terminator into the middle of a multibyte sequence, and clients
    // whose protobuf runtime rejects invalid UTF-8 entered a decode fail
    // and retry loop. The Dart runtime decodes with `allowMalformed: true`
    // instead, substituting U+FFFD. These tests pin that contract: if a
    // future protobuf release tightens it, they fail loudly here rather than
    // silently reintroducing the fail/retry loop at the transport layer.

    /// Build a `FromRadio.nodeInfo` frame whose `long_name` and `short_name`
    /// carry [nameBytes] verbatim. A Dart string cannot express invalid
    /// UTF-8, so the message is built valid and the placeholder is spliced
    /// out on the wire afterwards.
    Uint8List buildPoisonedNodeInfo(List<int> nameBytes) {
      final placeholder = 'Z' * nameBytes.length;
      final frame = pb.FromRadio()
        ..id = 1
        ..nodeInfo = (pb.NodeInfo()
          ..num = 0xA1B2C3D4
          ..user = (pb.User()
            ..id = '!a1b2c3d4'
            ..longName = placeholder
            ..shortName = placeholder));
      final bytes = frame.writeToBuffer().toList();
      final needle = utf8.encode(placeholder);

      var spliced = 0;
      for (var i = 0; i + needle.length <= bytes.length; i++) {
        var hit = true;
        for (var j = 0; j < needle.length; j++) {
          if (bytes[i + j] != needle[j]) {
            hit = false;
            break;
          }
        }
        if (hit) {
          bytes.setRange(i, i + needle.length, nameBytes);
          spliced++;
          i += needle.length - 1;
        }
      }
      expect(spliced, 2, reason: 'both name placeholders must be spliced');
      return Uint8List.fromList(bytes);
    }

    const vectors = <String, List<int>>{
      'truncated 2-byte sequence': [0xC3, 0x28, 0x41, 0x42],
      'UTF-8 encoded lone surrogate U+D800': [0xED, 0xA0, 0x80, 0x41],
      'overlong encoding': [0xC0, 0xAF, 0x41, 0x42],
      'five-byte start byte': [0xF8, 0x88, 0x80, 0x80],
      'bare continuation bytes': [0x80, 0x80, 0x80, 0x80],
      'sequence truncated at field end': [0x41, 0x42, 0x43, 0xF0],
      'CESU-8 surrogate pair': [0xED, 0xAF, 0xBF, 0xED],
    };

    vectors.forEach((label, nameBytes) {
      test('$label decodes without throwing and stays renderable', () {
        final frame = buildPoisonedNodeInfo(nameBytes);

        late pb.FromRadio decoded;
        expect(
          () => decoded = pb.FromRadio.fromBuffer(frame),
          returnsNormally,
          reason: 'protobuf must decode malformed UTF-8 rather than throw',
        );

        final longName = decoded.nodeInfo.user.longName;
        final shortName = decoded.nodeInfo.user.shortName;

        expect(isWellFormedUtf16(longName), isTrue);
        expect(isWellFormedUtf16(shortName), isTrue);
        expectRendersWithoutCrash(longName);
        expectRendersWithoutCrash(shortName);

        // The frame is still usable: the node number survives intact, so a
        // poisoned name never costs us the record it arrived on.
        expect(decoded.nodeInfo.num, 0xA1B2C3D4);
      });
    });

    test('a NUL written mid-sequence is stripped before display', () {
      // The firmware defect verbatim: 40-byte buffer, text cut at byte 39,
      // NUL written there, landing inside a 2-byte sequence.
      final name = utf8.encode('Repeater Montagne du Nord Cote dAzur ée');
      final poisoned = [...name.sublist(0, 39), 0x00];
      final decoded = pb.FromRadio.fromBuffer(buildPoisonedNodeInfo(poisoned));

      final raw = decoded.nodeInfo.user.longName;
      expect(containsNul(raw), isTrue, reason: 'NUL survives protobuf decode');

      final display = NodeDisplayNameResolver.resolve(
        nodeNum: decoded.nodeInfo.num,
        longName: raw,
      );
      expect(containsNul(display), isFalse);
      expect(isWellFormedUtf16(display), isTrue);
      expectRendersWithoutCrash(display);
    });
  });

  group('Avatar text never splits a UTF-16 surrogate pair', () {
    // Peer-supplied names are cut to a few characters for avatars and
    // markers. Slicing by code unit can land between the halves of a
    // surrogate pair, and the paragraph builder treats the resulting lone
    // surrogate as fatal. The cut position is attacker-chosen, so every
    // alignment has to be safe.
    const hostileNames = <String>[
      'A\u{1F4E1}\u{1F4E1} Base', // cut at 4 units lands mid-pair
      '\u{1F4E1}A\u{1F4E1} Base',
      'AB\u{1F4E1}\u{1F4E1}', // cut at 5 units lands mid-pair
      '\u{1F4E1}\u{1F4E1}\u{1F4E1}',
      'AB\u{1F1E6}\u{1F1FA}CD',
      '\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467} Family',
    ];

    for (final name in hostileNames) {
      test('resolveAvatarName is safe for ${name.codeUnits.length} units', () {
        final fromLong = NodeDisplayNameResolver.resolveAvatarName(
          nodeNum: 0xDEADBEEF,
          longName: name,
        );
        final fromShort = NodeDisplayNameResolver.resolveAvatarName(
          nodeNum: 0xDEADBEEF,
          shortName: name,
        );

        for (final value in [fromLong, fromShort]) {
          expect(isWellFormedUtf16(value), isTrue);
          expect(containsNul(value), isFalse);
          expectRendersWithoutCrash(value);
          expect(value.characters.length, lessThanOrEqualTo(4));
        }
      });

      test('MeshNode and Message avatar names are safe for "$name"', () {
        final node = MeshNode(nodeNum: 0xDEADBEEF, longName: name);
        final viaShortName = MeshNode(nodeNum: 0xDEADBEEF, shortName: name);
        final message = Message(
          from: 0xDEADBEEF,
          to: 0xFFFFFFFF,
          text: 'hi',
          senderLongName: name,
        );

        for (final value in [
          node.avatarName,
          viaShortName.avatarName,
          message.senderAvatarName,
        ]) {
          expect(isWellFormedUtf16(value), isTrue);
          expectRendersWithoutCrash(value);
        }
      });
    }

    test('an unbounded short name is capped rather than passed through', () {
      // Firmware caps short_name at 4 bytes but the wire format does not.
      final node = MeshNode(nodeNum: 1, shortName: 'A' * 200);
      expect(node.avatarName.characters.length, lessThanOrEqualTo(4));
    });

    test('ASCII names are untouched', () {
      expect(MeshNode(nodeNum: 1, shortName: 'BASE').avatarName, 'BASE');
      expect(MeshNode(nodeNum: 1, longName: 'Base Camp').avatarName, 'Base');
      expect(MeshNode(nodeNum: 0xABCD).avatarName, 'ABCD');
    });
  });

  group('Sanitizer is a no-op on already-clean strings', () {
    test('valid UTF-8 round-trips through utf8.decode unchanged', () {
      // Sanity check: well-formed multilingual text with emoji must not be
      // perturbed by any of the ingress sanitization wrappers we added.
      const input = 'Café 日本語 👨‍👩‍👧‍👦';
      final bytes = Uint8List.fromList(utf8.encode(input));
      final decoded = utf8.decode(bytes);
      expect(decoded, input);
      expect(isWellFormedUtf16(decoded), isTrue);
      expectRendersWithoutCrash(decoded);
    });
  });
}
