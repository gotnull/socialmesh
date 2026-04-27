// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Bottom sheet game picker for SIP Play.
///
/// Lists all registered games (currently just Tic-Tac-Toe) and, on
/// tap, sends a SIP Play `offer` envelope through the DM router to
/// the current session. The session's timeline then renders an
/// outgoing offer bubble; the receiver gets an inbound offer bubble
/// with Accept / Decline controls.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../providers/sip_dm_secure_router.dart';
import '../../../services/haptic_service.dart';
import '../../../services/protocol/sip/sip_dm.dart';
import '../../../services/protocol/sip/play/sip_play_codec.dart';
import '../../../services/protocol/sip/play/sip_play_constants.dart';
import '../../../services/protocol/sip/play/sip_play_payload.dart';
import '../../../services/protocol/sip/play/sip_play_registry.dart';
import '../../../utils/snackbar.dart';

/// Open the picker and, on user selection, send the offer envelope.
/// Caller is responsible for verifying that:
///   - the session is active,
///   - the peer advertises `dmPlayV1`,
///   - the peer is not blocked.
/// (The router re-checks these as defence-in-depth, but hiding the
/// composer mode entry point when those don't hold avoids a sheet
/// that immediately fails.)
void showSipPlayPicker({
  required BuildContext context,
  required WidgetRef ref,
  required int sessionTag,
}) {
  final l10n = context.l10n;
  AppBottomSheet.show<void>(
    context: context,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.sipPlayPickerTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          const SizedBox(height: AppTheme.spacing6),
          Text(
            l10n.sipPlayPickerSubtitle,
            style: TextStyle(
              fontSize: 13,
              color: context.textSecondary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          for (final descriptor in SipPlayRegistry.games)
            _GameRow(
              descriptor: descriptor,
              onTap: () {
                Navigator.of(context).pop();
                _sendOffer(
                  context: context,
                  ref: ref,
                  sessionTag: sessionTag,
                  gameType: descriptor.gameType,
                );
              },
            ),
          const SizedBox(height: AppTheme.spacing8),
        ],
      ),
    ),
  );
}

class _GameRow extends StatelessWidget {
  final SipPlayGameDescriptor descriptor;
  final VoidCallback onTap;
  const _GameRow({required this.descriptor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (label, body) = switch (descriptor.gameType) {
      SipPlayGameType.ticTacToe => (
        l10n.sipPlayGameTicTacToe,
        l10n.sipPlayGameTicTacToeDescription,
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacing12),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            border: Border.all(color: context.border.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(Icons.grid_3x3, size: 28, color: context.accentColor),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing2),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: context.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _sendOffer({
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
