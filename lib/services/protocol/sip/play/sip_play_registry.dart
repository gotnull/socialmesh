// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'sip_play_constants.dart';

/// Static metadata for one registered game. The runtime registry
/// keeps the per-game payload budget here so the codec layer can
/// validate envelope sizes before invoking game-specific code.
///
/// Adding a new game means: assign a [SipPlayGameType] code, declare
/// its payload budget, add a [SipPlayGameDescriptor] entry to
/// [SipPlayRegistry.games]. The wire envelope itself does not need
/// a version bump.
class SipPlayGameDescriptor {
  /// The strongly-typed game id this descriptor handles.
  final SipPlayGameType gameType;

  /// User-visible label. UI can override via ARB key — this is a
  /// stable identifier for logs and unit tests.
  final String labelId;

  /// Maximum bytes the per-game `move` payload may occupy. Other
  /// actions (offer / accept / decline / resign) carry zero
  /// game-payload bytes by SIP Play v1 convention — they don't
  /// consume this budget.
  ///
  /// This must stay below
  /// `SipPlayConstants.maxEnvelopeBytes - SipPlayConstants.envelopeHeaderBytes`.
  final int maxMovePayloadBytes;

  const SipPlayGameDescriptor({
    required this.gameType,
    required this.labelId,
    required this.maxMovePayloadBytes,
  });
}

/// Read-only registry of known SIP Play games. Receivers consult
/// this to decide whether to render a normal game UI or a safe
/// "unsupported game" fallback.
abstract final class SipPlayRegistry {
  /// All games this build of the app understands. Order is irrelevant.
  static const List<SipPlayGameDescriptor> games = [
    SipPlayGameDescriptor(
      gameType: SipPlayGameType.ticTacToe,
      labelId: 'ticTacToe',
      // 1-byte move payload (mark nibble | cell nibble) — see
      // `ttt_codec.dart`.
      maxMovePayloadBytes: 1,
    ),
  ];

  /// Lookup by strongly-typed enum.
  static SipPlayGameDescriptor? descriptorFor(SipPlayGameType type) {
    for (final g in games) {
      if (g.gameType == type) return g;
    }
    return null;
  }

  /// Lookup by raw wire byte. Returns null for unknown / reserved
  /// game-type codes — receivers render the unsupported fallback in
  /// that case rather than crashing.
  static SipPlayGameDescriptor? descriptorForCode(int code) {
    final type = SipPlayGameType.fromCode(code);
    if (type == null) return null;
    return descriptorFor(type);
  }

  /// True iff [code] resolves to a game this build handles. Used by
  /// the engine to gate state mutations: an unknown game becomes a
  /// terminal `unsupported` instance state with no further actions
  /// applied.
  static bool isSupported(int code) => descriptorForCode(code) != null;
}
