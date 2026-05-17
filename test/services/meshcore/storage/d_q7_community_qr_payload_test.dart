// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q7 pure parser + derivation pins for the meshcore-open
// community-QR wire format. The parser returns a typed result
// rather than throwing so the UI can render a specific localised
// error per failure variant. Derivation tests use a known-fixed
// secret + tag to lock the HMAC-SHA256[:16] output byte-for-byte.

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_community_qr_payload.dart';

String _b64UrlNoPad(Uint8List bytes) {
  return base64Url.encode(bytes).replaceAll('=', '');
}

String _validPayload({
  int version = 1,
  String name = 'Backyard Mesh',
  Uint8List? secret,
}) {
  final s = secret ?? Uint8List.fromList(List<int>.generate(32, (i) => i + 1));
  return jsonEncode({
    'v': version,
    'type': 'meshcore_community',
    'name': name,
    'k': _b64UrlNoPad(s),
  });
}

void main() {
  group('parseMeshCoreCommunityPayload — success', () {
    test('valid payload returns a parsed result', () {
      final result = parseMeshCoreCommunityPayload(_validPayload());
      expect(result.isSuccess, isTrue);
      expect(result.payload, isNotNull);
      expect(result.payload!.name, 'Backyard Mesh');
      expect(result.payload!.version, 1);
      expect(result.payload!.secret, hasLength(32));
      expect(result.payload!.secret.first, 1);
      expect(result.payload!.secret.last, 32);
    });

    test('trims surrounding whitespace from the name', () {
      final result = parseMeshCoreCommunityPayload(
        _validPayload(name: '   Backyard Mesh  '),
      );
      expect(result.isSuccess, isTrue);
      expect(result.payload!.name, 'Backyard Mesh');
    });

    test('accepts base64url WITHOUT padding (wire-spec default)', () {
      // 32 bytes encodes to 43 base64url chars + 1 padding char ('='); the
      // upstream payload omits the padding.
      final result = parseMeshCoreCommunityPayload(_validPayload());
      expect(result.isSuccess, isTrue);
    });

    test('accepts base64url WITH explicit padding', () {
      final raw = jsonEncode({
        'v': 1,
        'type': 'meshcore_community',
        'name': 'Padded',
        'k': base64Url.encode(Uint8List(32)),
      });
      final result = parseMeshCoreCommunityPayload(raw);
      expect(result.isSuccess, isTrue);
    });
  });

  group('parseMeshCoreCommunityPayload — failure variants', () {
    test('non-JSON returns notJson', () {
      final result = parseMeshCoreCommunityPayload('not json at all');
      expect(result.error, MeshCoreCommunityParseError.notJson);
    });

    test('JSON array returns notJson', () {
      final result = parseMeshCoreCommunityPayload('[1, 2, 3]');
      expect(result.error, MeshCoreCommunityParseError.notJson);
    });

    test('wrong discriminator returns wrongType', () {
      final raw = jsonEncode({
        'v': 1,
        'type': 'meshcore_contact',
        'name': 'Spoof',
        'k': _b64UrlNoPad(Uint8List(32)),
      });
      final result = parseMeshCoreCommunityPayload(raw);
      expect(result.error, MeshCoreCommunityParseError.wrongType);
    });

    test('unsupported version returns unsupportedVersion', () {
      final result = parseMeshCoreCommunityPayload(_validPayload(version: 999));
      expect(result.error, MeshCoreCommunityParseError.unsupportedVersion);
    });

    test('missing name returns missingName', () {
      final raw = jsonEncode({
        'v': 1,
        'type': 'meshcore_community',
        'k': _b64UrlNoPad(Uint8List(32)),
      });
      final result = parseMeshCoreCommunityPayload(raw);
      expect(result.error, MeshCoreCommunityParseError.missingName);
    });

    test('non-string name returns missingName', () {
      final raw = jsonEncode({
        'v': 1,
        'type': 'meshcore_community',
        'name': 42,
        'k': _b64UrlNoPad(Uint8List(32)),
      });
      final result = parseMeshCoreCommunityPayload(raw);
      expect(result.error, MeshCoreCommunityParseError.missingName);
    });

    test('empty name returns emptyName', () {
      final result = parseMeshCoreCommunityPayload(_validPayload(name: ''));
      expect(result.error, MeshCoreCommunityParseError.emptyName);
    });

    test('whitespace-only name returns emptyName', () {
      final result = parseMeshCoreCommunityPayload(_validPayload(name: '   '));
      expect(result.error, MeshCoreCommunityParseError.emptyName);
    });

    test('missing secret returns missingSecret', () {
      final raw = jsonEncode({
        'v': 1,
        'type': 'meshcore_community',
        'name': 'No Secret',
      });
      final result = parseMeshCoreCommunityPayload(raw);
      expect(result.error, MeshCoreCommunityParseError.missingSecret);
    });

    test('non-string secret returns missingSecret', () {
      final raw = jsonEncode({
        'v': 1,
        'type': 'meshcore_community',
        'name': 'Wrong Type',
        'k': 12345,
      });
      final result = parseMeshCoreCommunityPayload(raw);
      expect(result.error, MeshCoreCommunityParseError.missingSecret);
    });

    test('bad base64url returns badSecretEncoding', () {
      final raw = jsonEncode({
        'v': 1,
        'type': 'meshcore_community',
        'name': 'Bad b64',
        'k': '!!!not base64!!!',
      });
      final result = parseMeshCoreCommunityPayload(raw);
      expect(result.error, MeshCoreCommunityParseError.badSecretEncoding);
    });

    test('wrong-length secret (16 bytes) returns badSecretLength', () {
      final raw = jsonEncode({
        'v': 1,
        'type': 'meshcore_community',
        'name': 'Short',
        'k': _b64UrlNoPad(Uint8List(16)),
      });
      final result = parseMeshCoreCommunityPayload(raw);
      expect(result.error, MeshCoreCommunityParseError.badSecretLength);
    });

    test('wrong-length secret (64 bytes) returns badSecretLength', () {
      final raw = jsonEncode({
        'v': 1,
        'type': 'meshcore_community',
        'name': 'Too long',
        'k': _b64UrlNoPad(Uint8List(64)),
      });
      final result = parseMeshCoreCommunityPayload(raw);
      expect(result.error, MeshCoreCommunityParseError.badSecretLength);
    });
  });

  group('deriveMeshCoreCommunityPsk', () {
    test('matches HMAC-SHA256[:16] of "channel:v1:<tag>"', () {
      // Spot-check against an independent inline HMAC so a future
      // refactor of the helper can't silently drift the wire-derived
      // PSKs for every existing community user.
      final secret = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));
      final got = deriveMeshCoreCommunityPsk(secret, '__public__');
      final reference = Hmac(
        sha256,
        secret,
      ).convert(utf8.encode('channel:v1:__public__')).bytes.sublist(0, 16);
      expect(got, equals(reference));
      expect(got.length, 16);
    });

    test('different tags produce different PSKs', () {
      final secret = Uint8List(32);
      final pubPsk = deriveMeshCoreCommunityPsk(secret, '__public__');
      final tagPsk = deriveMeshCoreCommunityPsk(secret, 'general');
      expect(pubPsk, isNot(equals(tagPsk)));
    });

    test('different secrets produce different PSKs', () {
      final s1 = Uint8List.fromList(List.generate(32, (i) => i));
      final s2 = Uint8List.fromList(List.generate(32, (i) => 32 - i));
      final p1 = deriveMeshCoreCommunityPsk(s1, 'general');
      final p2 = deriveMeshCoreCommunityPsk(s2, 'general');
      expect(p1, isNot(equals(p2)));
    });

    test('derivation is deterministic across repeated calls', () {
      final secret = Uint8List.fromList(List.generate(32, (i) => i * 3));
      final a = deriveMeshCoreCommunityPsk(secret, 'sweep');
      final b = deriveMeshCoreCommunityPsk(secret, 'sweep');
      expect(a, equals(b));
    });

    test('payload.derivePskFor matches the standalone helper', () {
      final payload = parseMeshCoreCommunityPayload(_validPayload()).payload!;
      final viaInstance = payload.derivePskFor('hiking');
      final viaHelper = deriveMeshCoreCommunityPsk(payload.secret, 'hiking');
      expect(viaInstance, equals(viaHelper));
    });
  });

  group('normaliseMeshCoreCommunityTag', () {
    test('strips a leading hash sign', () {
      expect(normaliseMeshCoreCommunityTag('#general'), 'general');
    });

    test('lower-cases the tag', () {
      expect(normaliseMeshCoreCommunityTag('General'), 'general');
    });

    test('trims surrounding whitespace before stripping hash', () {
      expect(normaliseMeshCoreCommunityTag('  #Hiking  '), 'hiking');
    });

    test('only strips a single leading hash, not embedded ones', () {
      expect(normaliseMeshCoreCommunityTag('##general'), '#general');
    });

    test('empty input returns empty string', () {
      expect(normaliseMeshCoreCommunityTag(''), '');
    });

    test('pure-whitespace input returns empty string', () {
      expect(normaliseMeshCoreCommunityTag('   '), '');
    });
  });

  group('kMeshCoreCommunityPublicTag constant', () {
    test('matches upstream channels.md literal "__public__"', () {
      expect(kMeshCoreCommunityPublicTag, '__public__');
    });
  });
}
