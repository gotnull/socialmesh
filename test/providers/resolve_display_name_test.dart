// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/providers/profile_providers.dart';

void main() {
  group('resolveDisplayNameFromParts', () {
    test('returns root displayName when set', () {
      final out = resolveDisplayNameFromParts(
        rootDisplayName: 'rootname',
        providers: const [
          (providerId: 'twitter.com', displayName: 'fuzz'),
          (providerId: 'google.com', displayName: 'Simon Cusumano'),
        ],
      );
      expect(out, 'rootname');
    });

    test('skips empty root displayName', () {
      final out = resolveDisplayNameFromParts(
        rootDisplayName: '',
        providers: const [
          (providerId: 'google.com', displayName: 'Simon Cusumano'),
        ],
      );
      expect(out, 'Simon Cusumano');
    });

    test('prefers Google over Twitter even when Twitter is listed first', () {
      // The developer-incident shape: provider order in the SDK had
      // Twitter's "fuzz" before Google's name; pre-fix code walked
      // the list in order and returned "fuzz". Precedence MUST flip
      // that around.
      final out = resolveDisplayNameFromParts(
        rootDisplayName: null,
        providers: const [
          (providerId: 'twitter.com', displayName: 'fuzz'),
          (providerId: 'apple.com', displayName: null),
          (providerId: 'github.com', displayName: 'Fuzz'),
          (providerId: 'google.com', displayName: 'Simon Cusumano'),
        ],
      );
      expect(out, 'Simon Cusumano');
    });

    test('falls through Google → Apple → GitHub → password → phone', () {
      expect(
        resolveDisplayNameFromParts(
          rootDisplayName: null,
          providers: const [
            (providerId: 'twitter.com', displayName: 'fuzz'),
            (providerId: 'github.com', displayName: 'GHName'),
            (providerId: 'apple.com', displayName: 'AppleName'),
          ],
        ),
        'AppleName',
      );

      expect(
        resolveDisplayNameFromParts(
          rootDisplayName: null,
          providers: const [
            (providerId: 'twitter.com', displayName: 'fuzz'),
            (providerId: 'github.com', displayName: 'GHName'),
            (providerId: 'password', displayName: 'PWName'),
          ],
        ),
        'GHName',
      );

      expect(
        resolveDisplayNameFromParts(
          rootDisplayName: null,
          providers: const [
            (providerId: 'twitter.com', displayName: 'fuzz'),
            (providerId: 'password', displayName: 'PWName'),
            (providerId: 'phone', displayName: 'PhoneName'),
          ],
        ),
        'PWName',
      );
    });

    test('falls back to Twitter only when nothing else has a name', () {
      final out = resolveDisplayNameFromParts(
        rootDisplayName: null,
        providers: const [
          (providerId: 'twitter.com', displayName: 'fuzz'),
          (providerId: 'apple.com', displayName: null),
          (providerId: 'github.com', displayName: null),
        ],
      );
      expect(out, 'fuzz');
    });

    test('falls back to unknown provider when no preference matches', () {
      final out = resolveDisplayNameFromParts(
        rootDisplayName: null,
        providers: const [
          (providerId: 'oidc.example', displayName: 'OidcName'),
        ],
      );
      expect(out, 'OidcName');
    });

    test('returns null when no provider has a displayName', () {
      final out = resolveDisplayNameFromParts(
        rootDisplayName: null,
        providers: const [
          (providerId: 'twitter.com', displayName: null),
          (providerId: 'google.com', displayName: null),
        ],
      );
      expect(out, isNull);
    });

    test('returns null when providers list is empty', () {
      final out = resolveDisplayNameFromParts(
        rootDisplayName: null,
        providers: const [],
      );
      expect(out, isNull);
    });
  });
}
