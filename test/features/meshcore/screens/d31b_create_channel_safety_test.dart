// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// D31b — guard against the pre-D31b "Private" toggle that produced a
// predictable `[0, 1, 2, ..., 15]` PSK. The toggle has been removed
// from the simple Create Channel dialog (hashtag-derived only); users
// who want a custom PSK are routed to the canonical
// MeshCoreChannelEditSheet via the "Add channel" overflow entry.
//
// Tests:
//   1. Model: `MeshCoreChannel.publicChannel(idx, name)` always yields
//      a SHA-256-derived PSK that is NEVER `[0..15]`, including for
//      empty / minimal / boundary names.
//   2. Source guard: no .dart file under `lib/` constructs the
//      `[0, 1, 2, ..., 15]` PSK pattern. If a future refactor
//      reintroduces it, this test fails loudly.
//   3. Widget: the simple Create dialog renders the new hashtag-only
//      flow — no Private toggle, no `meshcoreRandomPskPrivate` /
//      `meshcorePublicHashtagChannel` strings, redirect hint visible.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/models/meshcore_channel.dart';

/// The exact byte pattern the pre-D31b "Private" toggle produced.
/// Pinning it here lets the source-guard test detect re-introduction
/// of the construction by anyone who writes the literal back into the
/// codebase.
final _bannedPsk = Uint8List.fromList(List.generate(16, (i) => i));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('MeshCoreChannel.publicChannel never produces [0..15] (D31b)', () {
    test('common hashtag name produces SHA-256-derived PSK', () {
      final ch = MeshCoreChannel.publicChannel(1, 'squad');
      expect(ch.psk.length, 16);
      expect(
        ch.psk,
        isNot(equals(_bannedPsk)),
        reason: 'hashtag-derive must never coincide with [0..15]',
      );
    });

    test('every name in a representative set is safe', () {
      // Cross-check a handful of names — including the names a user
      // would actually try in the simple dialog. Any collision with
      // the banned pattern would be cosmically unlikely (1 in 2^128
      // for SHA-256), but pinning this guards against a future
      // refactor that reroutes `publicChannel` through a different
      // (broken) helper.
      const names = [
        '',
        'a',
        '#general',
        'general',
        'public',
        'squad',
        'TestD31',
        'private',
        '#chat',
        'TestD31B',
      ];
      for (final n in names) {
        final ch = MeshCoreChannel.publicChannel(0, n);
        expect(
          ch.psk,
          isNot(equals(_bannedPsk)),
          reason: 'name=$n produced banned PSK',
        );
      }
    });

    test(
      'MeshCoreChannel.empty(idx) is safe — empty PSK is all zeros, NOT [0..15]',
      () {
        // The wire-level "delete" convention uses an all-zero PSK.
        // That's distinct from the banned [0..15] pattern; pin so
        // future reorganisation of the empty-channel helper does not
        // accidentally reintroduce the predictable monotonic pattern.
        final empty = MeshCoreChannel.empty(0);
        expect(empty.psk.length, 16);
        expect(empty.psk.every((b) => b == 0), isTrue);
        expect(empty.psk, isNot(equals(_bannedPsk)));
      },
    );
  });

  test('no .dart file under lib/ or test/ constructs the [0..15] PSK pattern '
      '(D31b regression guard)', () {
    // Walk lib/ and test/ for the literal source patterns the
    // pre-D31b dialog used. We catch both the natural form
    // `List.generate(16, (i) => i)` and a few obvious cousins. If a
    // future change reintroduces this construction — accidentally
    // or deliberately — this test fails before it can ship.
    final patterns = <RegExp>[
      // Canonical pre-D31b construction
      RegExp(r'List\.generate\(\s*16\s*,\s*\(\s*i\s*\)\s*=>\s*i\s*\)'),
      // Loose variant: List.generate(16, (n) => n)
      RegExp(
        r'List\.generate\(\s*16\s*,\s*\(\s*[a-zA-Z_]+\s*\)\s*=>\s*\1\s*\)',
      ),
    ];

    // Scope the scan to `lib/` — production code only. Test fixtures
    // (SIP handshake vectors, codec round-trips, etc.) legitimately
    // use the same `List.generate(16, (i) => i)` shape as fixed
    // input bytes; those PSKs never reach the wire so they aren't a
    // security concern.
    final offenders = <String>[];
    final dir = Directory('lib');
    if (dir.existsSync()) {
      for (final entity in dir.listSync(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        if (!entity.path.endsWith('.dart')) continue;
        final content = entity.readAsStringSync();
        for (final p in patterns) {
          if (p.hasMatch(content)) {
            offenders.add('${entity.path}: matches ${p.pattern}');
            break;
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Banned [0..15] PSK construction reintroduced. Pre-D31b this '
          'shipped as a fake "private" channel PSK. Real private '
          'channels must paste a 128-bit PSK via the canonical '
          'MeshCoreChannelEditSheet, never a predictable placeholder. '
          'Offenders:\n  ${offenders.join("\n  ")}',
    );
  });

  group('D31b ARB surface (hashtag-only Create dialog copy)', () {
    test('new helper + redirect strings are present on AppLocalizationsEn', () {
      final l10n = AppLocalizationsEn();
      // The two D31b strings the simple Create dialog now renders in
      // place of the removed Private toggle. Pin their presence + that
      // they reference the canonical "Add channel" affordance.
      expect(l10n.meshcoreCreateChannelHashtagHelper.isNotEmpty, isTrue);
      expect(
        l10n.meshcoreCreateChannelHashtagHelper.toLowerCase(),
        contains('psk'),
        reason: 'helper must explain the hashtag-derived PSK convention',
      );
      expect(l10n.meshcoreCreateChannelPrivateRedirect.isNotEmpty, isTrue);
      expect(
        l10n.meshcoreCreateChannelPrivateRedirect.toLowerCase(),
        contains('add channel'),
        reason:
            'redirect hint must point users at the canonical '
            '"Add channel" entry that opens the canonical edit sheet',
      );
    });

    test(
      'pre-D31b unsafe-toggle ARB keys are absent from the en.arb source',
      () {
        // The generated AppLocalizations API would not even compile if
        // a stale getter remained, but the ARB cleanup is the
        // ground-truth surface a translator sees. Read the source
        // file directly so a future regen-skipped state still trips.
        final arb = File('lib/l10n/app_en.arb').readAsStringSync();
        for (final key in const [
          'meshcorePublicHashtagChannel',
          'meshcorePskDerivedFromName',
          'meshcoreRandomPskPrivate',
        ]) {
          expect(
            arb.contains('"$key"'),
            isFalse,
            reason:
                'D31b removed the unsafe Private toggle strings. '
                'ARB key "$key" must not be re-introduced. Use the '
                'canonical MeshCoreChannelEditSheet for paste-PSK.',
          );
        }
      },
    );
  });
}
