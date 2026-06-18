// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Help Mode trust source: the "Help Circle".
///
/// Help Mode does NOT depend on the SIP Handshake product being live. The
/// PUBLIC trust source is an explicit, per-peer opt-in list (the Help Circle)
/// the user maintains from the node list / node detail. Same-channel, seen,
/// has-pubkey, or same-PSK is NEVER enough.
///
/// A completed SIP Handshake is kept as an OPTIONAL additional trust source for
/// internal builds where Handshake is enabled; it is never required for public
/// Help Mode.
///
/// The circle is persisted (SharedPreferences, local-only, no cloud) with a
/// small display snapshot so the list renders without the node being online.
/// Trust survives an app restart, unlike in-memory Handshake state.
///
/// Plan: docs/engineering/INCIDENT_MODE_SIP_MRRP_PLAN.md (trust model)
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/protocol/sip/sip_handshake.dart';

/// SharedPreferences key for the persisted Help Circle.
const String kIncidentHelpCirclePrefsKey = 'incident_help_circle_v1';

/// A peer in the Help Circle: node id plus a display snapshot so the list can
/// render even when the node is offline. No keys or sensitive data are stored.
class HelpCirclePeer {
  final int nodeId;
  final String displayName;
  final int addedAtMs;

  const HelpCirclePeer({
    required this.nodeId,
    required this.displayName,
    required this.addedAtMs,
  });

  Map<String, dynamic> toJson() => {
    'nodeId': nodeId,
    'displayName': displayName,
    'addedAtMs': addedAtMs,
  };

  factory HelpCirclePeer.fromJson(Map<String, dynamic> json) => HelpCirclePeer(
    nodeId: json['nodeId'] as int,
    displayName: (json['displayName'] as String?) ?? '',
    addedAtMs: (json['addedAtMs'] as int?) ?? 0,
  );
}

/// Pure trust gate for Help Mode. Trusted iff the node is in the Help [circle]
/// OR (optional, internal) it has completed the SIP Handshake. Same-channel /
/// seen / has-pubkey / same-PSK are NOT trusted.
bool incidentHelpTrustGate({
  required Set<int> circle,
  required SipHandshakeManager? handshake,
  required int nodeId,
}) {
  if (circle.contains(nodeId)) return true;
  return handshake != null &&
      handshake.getState(nodeId) == SipHandshakeState.accepted;
}

/// Persisted Help Circle. In-memory state is the synchronous source of truth
/// for the trust predicate and for the management UI.
class IncidentHelpTrustNotifier extends Notifier<List<HelpCirclePeer>> {
  // The in-flight initial load. Mutations await this first so a slow disk read
  // can never resolve after (and clobber) an add/remove the user just made.
  Future<void>? _ready;

  @override
  List<HelpCirclePeer> build() {
    // Fire-and-forget load; state updates when prefs resolve. Safe-by-default:
    // until loaded the circle is empty (nobody trusted). Mutations await
    // [_ready] so the load can never clobber an add/remove made right after open.
    _ready = reload();
    unawaited(_ready);
    return const [];
  }

  /// Reloads the circle from persistent storage. Returns when done.
  Future<void> reload() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kIncidentHelpCirclePrefsKey);
    if (raw == null || raw.isEmpty) {
      state = const [];
      return;
    }
    try {
      final list = (jsonDecode(raw) as List)
          .map(
            (e) => HelpCirclePeer.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList();
      state = list;
    } catch (_) {
      state = const [];
    }
  }

  /// Adds (or refreshes the display name of) a peer in the Help Circle.
  Future<void> trust(
    int nodeId, {
    required String displayName,
    int? nowMs,
  }) async {
    await _ready;
    final existing = state.where((p) => p.nodeId == nodeId).toList();
    final added = existing.isEmpty ? (nowMs ?? 0) : existing.first.addedAtMs;
    state = [
      for (final p in state)
        if (p.nodeId != nodeId) p,
      HelpCirclePeer(
        nodeId: nodeId,
        displayName: displayName,
        addedAtMs: added,
      ),
    ];
    await _persist();
  }

  /// Removes a peer from the Help Circle. Takes effect immediately for the
  /// in-memory predicate (new inbound/outbound), then persists.
  Future<void> untrust(int nodeId) async {
    await _ready;
    if (!state.any((p) => p.nodeId == nodeId)) return;
    state = state.where((p) => p.nodeId != nodeId).toList();
    await _persist();
  }

  /// Synchronous trust check against the in-memory circle.
  bool isTrusted(int nodeId) => state.any((p) => p.nodeId == nodeId);

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kIncidentHelpCirclePrefsKey,
      jsonEncode(state.map((p) => p.toJson()).toList()),
    );
  }
}

/// The Help Circle (persisted, in-memory cached), for the management UI.
final incidentHelpTrustProvider =
    NotifierProvider<IncidentHelpTrustNotifier, List<HelpCirclePeer>>(
      IncidentHelpTrustNotifier.new,
    );

/// Fast id-set view of the Help Circle for the trust predicate / hot path.
final incidentHelpTrustedIdsProvider = Provider<Set<int>>(
  (ref) => ref.watch(incidentHelpTrustProvider).map((p) => p.nodeId).toSet(),
);
