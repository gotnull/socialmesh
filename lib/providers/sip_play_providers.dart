// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Riverpod providers for the SIP Play layer.
///
/// State is derived purely from the SIP DM session's history-entry
/// stream — see `sip_play_engine.dart` for the replay invariants.
/// These providers never mutate game state; they observe the entry
/// log and re-derive on each rebuild.
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/audio/sip_play_sound_service.dart';
import '../services/audio/sip_signal_synth_service.dart';
import '../services/protocol/sip/play/sip_play_constants.dart';
import '../services/protocol/sip/play/sip_play_engine.dart';
import '../services/protocol/sip/sip_dm.dart';
import 'sip_providers.dart';

/// Process-wide singleton for SIP Play / Handshake sound effects.
/// Keeps audio engines alive across screen pushes (so back-to-back
/// cues play smoothly). Disposed on container teardown.
final sipPlaySoundServiceProvider = Provider<SipPlaySoundService>((ref) {
  final svc = SipPlaySoundService();
  ref.onDispose(svc.dispose);
  return svc;
});

/// Process-wide singleton for the SIP Signal local synthesis service
/// (musical phrase + Morse). Receivers and senders both use this for
/// preview / replay; no audio samples ever travel on the wire.
final sipSignalSynthServiceProvider = Provider<SipSignalSynthService>((ref) {
  final svc = SipSignalSynthService();
  ref.onDispose(svc.dispose);
  return svc;
});

/// Latest [SipPlayInstanceState] for a given `(sessionTag, instanceId)`
/// pair, or null when the SIP DM session is unknown / has no entries
/// for the given instance.
///
/// **Pure read.** Building this provider does not mutate any state in
/// the engine or the DM manager — see "engine must be pure replay" in
/// the Phase-12 review.
final sipPlayInstanceStateProvider =
    Provider.family<SipPlayInstanceState?, ({int sessionTag, int instanceId})>((
      ref,
      key,
    ) {
      // Watching `sipDmEpochProvider` so the derived state recomputes on
      // any DM history change (matches how text/sketch UI follows the
      // session). Cheap — the engine replay is O(N) over a small log.
      ref.watch(sipDmEpochProvider);

      final dm = ref.read(sipDmManagerProvider);
      if (dm == null) return null;

      final history = dm.getHistory(key.sessionTag);
      if (history == null) return null;

      final entries = <SipPlayEntry>[];
      for (final entry in history) {
        if (entry.contentType != SipDmContentType.play) continue;
        final payload = entry.payload;
        if (payload == null || payload.isEmpty) continue;
        final decoded = SipPlayEngine.decodeEntry(
          payload: Uint8List.fromList(payload),
          direction: entry.direction == SipDmDirection.outbound
              ? SipPlayEntryDirection.outbound
              : SipPlayEntryDirection.inbound,
        );
        if (decoded == null) continue;
        if (decoded.envelope.instanceId != key.instanceId) continue;
        entries.add(decoded);
      }

      if (entries.isEmpty) return null;
      return SipPlayEngine.replay(entries);
    });

/// All SIP Play instance ids present in a session's history, in the
/// order they were first offered. Used by the UI to dispatch each
/// `play` history entry to the right instance bubble.
final sipPlayInstanceIdsProvider = Provider.family<List<int>, int>((
  ref,
  sessionTag,
) {
  ref.watch(sipDmEpochProvider);
  final dm = ref.read(sipDmManagerProvider);
  if (dm == null) return const <int>[];
  final history = dm.getHistory(sessionTag);
  if (history == null) return const <int>[];

  final seen = <int>{};
  final out = <int>[];
  for (final entry in history) {
    if (entry.contentType != SipDmContentType.play) continue;
    final payload = entry.payload;
    if (payload == null || payload.isEmpty) continue;
    final decoded = SipPlayEngine.decodeEntry(
      payload: Uint8List.fromList(payload),
      direction: entry.direction == SipDmDirection.outbound
          ? SipPlayEntryDirection.outbound
          : SipPlayEntryDirection.inbound,
    );
    if (decoded == null) continue;
    final id = decoded.envelope.instanceId;
    if (seen.add(id)) out.add(id);
  }
  return out;
});

/// Best-effort mapping from a SIP DM history entry's payload to the
/// `(instanceId, action, seq)` triple it carries. Returns null when
/// the payload is not a valid SIP Play envelope — bubbles that hit
/// this null branch render the `sipPlayMalformedTitle` fallback.
({int instanceId, SipPlayAction action, int seq, int gameTypeCode})?
parsePlayHeaderForUi(Uint8List payload) {
  final result = SipPlayEngine.decodeEntry(
    payload: payload,
    direction: SipPlayEntryDirection.outbound,
  );
  if (result == null) return null;
  return (
    instanceId: result.envelope.instanceId,
    action: result.envelope.action,
    seq: result.envelope.seq,
    gameTypeCode: result.envelope.gameTypeCode,
  );
}
