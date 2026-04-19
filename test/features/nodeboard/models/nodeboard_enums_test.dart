// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodeboard/models/nodeboard_enums.dart';

void main() {
  group('BoardVisibility', () {
    test('round-trip all values', () {
      for (final v in BoardVisibility.values) {
        expect(BoardVisibility.fromJson(v.toJson()), v);
      }
    });

    test('public_ serializes as "public"', () {
      expect(BoardVisibility.public_.toJson(), 'public');
    });

    test('private_ serializes as "private"', () {
      expect(BoardVisibility.private_.toJson(), 'private');
    });
  });

  group('SectionVisibility', () {
    test('round-trip all values', () {
      for (final v in SectionVisibility.values) {
        expect(SectionVisibility.fromJson(v.toJson()), v);
      }
    });
  });

  group('PostingPolicy', () {
    test('round-trip all values', () {
      for (final v in PostingPolicy.values) {
        expect(PostingPolicy.fromJson(v.toJson()), v);
      }
    });

    test('unknown defaults to authenticatedUsers', () {
      expect(
        PostingPolicy.fromJson('garbage'),
        PostingPolicy.authenticatedUsers,
      );
    });
  });

  group('BodyFormat', () {
    test('round-trip all values', () {
      for (final v in BodyFormat.values) {
        expect(BodyFormat.fromJson(v.toJson()), v);
      }
    });

    test('unknown defaults to plaintext', () {
      expect(BodyFormat.fromJson('html'), BodyFormat.plaintext);
    });
  });

  group('StyleMode', () {
    test('round-trip all values', () {
      for (final v in StyleMode.values) {
        expect(StyleMode.fromJson(v.toJson()), v);
      }
    });
  });
}
