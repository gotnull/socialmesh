// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Pins the Phase 11 SipDmSendError → snackbar copy mapping at every
/// UI consumer.
///
/// Hard rules:
///
///   - `SipDmSendError.peerBlocked` MUST map to
///     `l10n.sipDmPeerBlocked` (the unblock-aware copy). Falling
///     through to a generic "session closed" snackbar would hide the
///     reason and the recovery path from the user.
///   - `SipDmSendError.peerRateLimited` MUST map to
///     `l10n.sipDmPeerRateLimited` (the per-peer token-bucket copy)
///     and remain DISTINCT from `sipDmBudgetExhausted` — they're
///     different limiters with different recovery times.
///   - `SipDmSendError.budgetExhausted` MUST keep mapping to the
///     existing `l10n.sipDmBudgetExhausted` (global airtime budget).
///
/// These three error variants have to be handled by every code path
/// that surfaces a `SipDmSendError` to the user — currently:
///
///   - `lib/features/sip/sip_dm_screen.dart` `_showSendError`
///   - `lib/features/sip/sketch/sip_ink_composer.dart` `_showSendError`
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Extract the `_showSendError` method body from a Dart source by
/// brace-matching from the first occurrence. Throws (not `expect`)
/// so it's safe to call from group setup as well as test bodies.
String _extractShowSendErrorBody(String src) {
  // Match the method signature, not the call site, so the brace
  // scan starts at the method's opening `{`.
  final sigMatch = RegExp(r'void\s+_showSendError\s*\(').firstMatch(src);
  if (sigMatch == null) {
    throw StateError('_showSendError method definition must exist in source');
  }
  final start = sigMatch.start;
  final searchStart = src.indexOf('{', start);
  if (searchStart < 0) {
    throw StateError('opening brace of _showSendError not found');
  }
  var depth = 0;
  for (var i = searchStart; i < src.length; i += 1) {
    final ch = src[i];
    if (ch == '{') depth += 1;
    if (ch == '}') {
      depth -= 1;
      if (depth == 0) return src.substring(start, i + 1);
    }
  }
  throw StateError('closing brace of _showSendError not found');
}

void main() {
  group('sip_dm_screen.dart _showSendError mapping', () {
    final src = File('lib/features/sip/sip_dm_screen.dart').readAsStringSync();
    final body = _extractShowSendErrorBody(src);

    test('peerBlocked → sipDmPeerBlocked (the unblock-aware copy)', () {
      expect(
        RegExp(
          r'SipDmSendError\.peerBlocked\s*=>\s*l10n\.sipDmPeerBlocked',
        ).hasMatch(body),
        isTrue,
        reason:
            'peerBlocked must surface the dedicated copy that points '
            'the user toward the SIP Hub Blocked section unblock path',
      );
    });

    test('peerRateLimited → sipDmPeerRateLimited (per-peer bucket)', () {
      expect(
        RegExp(
          r'SipDmSendError\.peerRateLimited\s*=>\s*l10n\.sipDmPeerRateLimited',
        ).hasMatch(body),
        isTrue,
        reason:
            'peerRateLimited has its own copy — distinct from the '
            'global airtime budgetExhausted snackbar',
      );
    });

    test('budgetExhausted → sipDmBudgetExhausted (global airtime cap)', () {
      expect(
        RegExp(
          r'SipDmSendError\.budgetExhausted\s*=>\s*l10n\.sipDmBudgetExhausted',
        ).hasMatch(body),
        isTrue,
        reason:
            'budgetExhausted must keep mapping to the existing global '
            'airtime budget copy — not the per-peer one',
      );
    });

    test('peerRateLimited and budgetExhausted map to DIFFERENT '
        'localizations', () {
      // Defence-in-depth: ensure the two limiter snackbars never
      // converge to the same key. Per-peer vs. global have very
      // different recovery semantics.
      final peerArm = RegExp(
        r'SipDmSendError\.peerRateLimited\s*=>\s*l10n\.(\w+)',
      ).firstMatch(body);
      final globalArm = RegExp(
        r'SipDmSendError\.budgetExhausted\s*=>\s*l10n\.(\w+)',
      ).firstMatch(body);
      expect(peerArm, isNotNull);
      expect(globalArm, isNotNull);
      expect(
        peerArm!.group(1),
        isNot(equals(globalArm!.group(1))),
        reason: 'per-peer and global limiter copies must remain separate',
      );
    });
  });

  group('sip_ink_composer.dart _showSendError mapping', () {
    final src = File(
      'lib/features/sip/sketch/sip_ink_composer.dart',
    ).readAsStringSync();
    final body = _extractShowSendErrorBody(src);

    test('peerBlocked → sipDmPeerBlocked (shared copy with text DM)', () {
      expect(
        RegExp(
          r'SipDmSendError\.peerBlocked\s*=>\s*l10n\.sipDmPeerBlocked',
        ).hasMatch(body),
        isTrue,
        reason:
            'sketch send must use the same peerBlocked copy as text '
            'DM — sketch-specific text would confuse users about the '
            'underlying state',
      );
    });

    test('peerRateLimited → sipDmPeerRateLimited (shared copy)', () {
      expect(
        RegExp(
          r'SipDmSendError\.peerRateLimited\s*=>\s*l10n\.sipDmPeerRateLimited',
        ).hasMatch(body),
        isTrue,
      );
    });

    test('budgetExhausted → sipDmBudgetExhausted (unchanged)', () {
      expect(
        RegExp(
          r'SipDmSendError\.budgetExhausted\s*=>\s*l10n\.sipDmBudgetExhausted',
        ).hasMatch(body),
        isTrue,
      );
    });
  });

  group('ARB key vocabulary', () {
    final arb = File('lib/l10n/app_en.arb').readAsStringSync();

    test('sipDmPeerBlocked exists in app_en.arb', () {
      expect(arb.contains('"sipDmPeerBlocked"'), isTrue);
    });

    test('sipDmPeerRateLimited exists in app_en.arb', () {
      expect(arb.contains('"sipDmPeerRateLimited"'), isTrue);
    });

    test('sipDmBudgetExhausted is unchanged (global airtime)', () {
      // Reading the literal value pins the global-airtime semantics
      // so a future translator pass doesn't accidentally redefine
      // it as the per-peer copy.
      expect(arb.contains('"sipDmBudgetExhausted"'), isTrue);
      expect(
        arb.contains('mesh bandwidth limit reached'),
        isTrue,
        reason:
            'budgetExhausted copy should remain the airtime/bandwidth '
            'message — not the per-peer "slow down" one',
      );
    });
  });
}
