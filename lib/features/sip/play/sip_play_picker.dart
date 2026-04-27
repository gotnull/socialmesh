// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Public helper for sending a SIP Play `offer` envelope. The Play
// composer panel now renders one card per registered game directly
// (no intermediate picker bottom sheet), so this file is a single
// dispatch function — the per-game cards each call this on tap.
//
// Caller is responsible for verifying that:
//   - the session is active,
//   - the peer advertises `dmPlayV1`,
//   - the peer is not blocked.
// The router re-checks these as defence-in-depth, but hiding the
// composer mode entry point when those don't hold avoids a UI that
// immediately fails.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../providers/sip_dm_secure_router.dart';
import '../../../services/haptic_service.dart';
import '../../../services/protocol/sip/sip_dm.dart';
import '../../../services/protocol/sip/play/sip_play_codec.dart';
import '../../../services/protocol/sip/play/sip_play_constants.dart';
import '../../../services/protocol/sip/play/sip_play_payload.dart';
import '../../../utils/snackbar.dart';

/// Send a SIP Play `offer` envelope for [gameType] to the active DM
/// session [sessionTag]. Used by the per-game cards in
/// `_PlayComposerPanel`. Generates a fresh `u16` instanceId per
/// offer.
Future<void> sendSipPlayOffer({
  required BuildContext context,
  required WidgetRef ref,
  required int sessionTag,
  required SipPlayGameType gameType,
}) async {
  final l10n = context.l10n;
  final router = ref.read(sipDmRouterProvider);
  final haptics = ref.read(hapticServiceProvider);
  await haptics.trigger(HapticType.medium);

  // u16 instance id — random per offer, scoped to (sessionTag, peer).
  // Collisions are statistically negligible at conversation timescales
  // and the engine ignores envelopes whose instanceId doesn't match
  // an offer it has already locked, so a freak collision drops cleanly.
  final rng = math.Random.secure();
  final instanceId = rng.nextInt(0x10000);

  final envelope = SipPlayEnvelope(
    typeAndVersion: SipPlayConstants.envelopeTypeAndVersionV1,
    gameTypeCode: gameType.code,
    instanceId: instanceId,
    action: SipPlayAction.offer,
    seq: 0,
    gamePayload: Uint8List(0),
  );
  final bytes = SipPlayCodec.encode(envelope);
  if (bytes == null) {
    AppLogging.sipPlay('offer_encode_failed gameType=${gameType.name}');
    if (context.mounted) {
      showErrorSnackBar(context, l10n.sipDmSessionClosed);
    }
    return;
  }
  AppLogging.sipPlay(
    'offer_created instance=0x${instanceId.toRadixString(16)} '
    'gameType=${gameType.name} bytes=${bytes.length}',
  );

  final outcome = await router.sendPlay(
    sessionTag: sessionTag,
    playPayload: bytes,
  );
  if (!context.mounted) return;
  if (!outcome.isOk) {
    final message = switch (outcome.error) {
      SipDmSendError.peerBlocked => l10n.sipDmPeerBlocked,
      SipDmSendError.peerRateLimited => l10n.sipDmPeerRateLimited,
      SipDmSendError.budgetExhausted => l10n.sipDmBudgetExhausted,
      _ => l10n.sipDmSessionClosed,
    };
    showErrorSnackBar(context, message);
  }
}
