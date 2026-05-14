// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D42-A: MeshCore path overlay (app-local).
//
// Captures the rendered shape of a single saved or active path so the
// map screen can draw it as a polyline + hop markers. Path bytes are
// opaque routing identifiers (each byte is the first byte of the
// receiving repeater's 32-byte ed25519 pubkey, per upstream firmware
// behaviour), so per-hop geographic coordinates come from the local
// contact list - never from the path bytes themselves. Hops with no
// matching contact (or no `hasLocation` on the matched contact) are
// surfaced with `latLng == null` so the map can omit them from the
// polyline without "guessing" a position.
//
// Privacy:
//   - Hop labels are 2-char hex (one byte). The full pubkey is never
//     part of a label.
//   - Hop `displayName` is set ONLY when the resolver matched a
//     contact whose name is already user-visible in the contacts
//     list. We never invent a name from the byte.
//   - Bytes themselves are surfaced as the same 2-char hex label.

import 'dart:typed_data';

import 'package:latlong2/latlong.dart';

import '../core/safe_lat_lng.dart';
import '../services/meshcore/protocol/meshcore_messages.dart';
import '../services/meshcore/storage/meshcore_message_store.dart';
import '../services/meshcore/storage/meshcore_path_history_store.dart';
import 'meshcore_contact.dart';

/// What kind of path the overlay represents. The map can show the
/// `source` as a small chip if useful.
enum MeshCorePathOverlaySource {
  /// Built from the contact's live firmware path (or pathOverrideBytes).
  active,

  /// Built from a saved entry in the per-contact D39-A path history.
  history,

  /// D42-B-A: inferred from the newest valid app-local evidence
  /// (D39 saved entries + persisted inbound message paths). Never
  /// auto-activated — the user explicitly opted in via the Contact
  /// Detail "Show inferred path" action.
  inferred,
}

extension MeshCorePathOverlaySourceWire on MeshCorePathOverlaySource {
  String get wire {
    switch (this) {
      case MeshCorePathOverlaySource.active:
        return 'active';
      case MeshCorePathOverlaySource.history:
        return 'history';
      case MeshCorePathOverlaySource.inferred:
        return 'inferred';
    }
  }
}

/// One hop on a rendered path overlay.
class MeshCorePathOverlayHop {
  /// The wire byte for this hop (0..255).
  final int byte;

  /// 2-char lowercase hex label suitable for a marker badge.
  final String label;

  /// Resolved position when a local contact with matching pubkey
  /// prefix AND a known location was found. Null otherwise; the map
  /// MUST NOT render a marker for null-position hops.
  final LatLng? latLng;

  /// Display name from the resolved contact, when present. Already
  /// user-visible. Null when no contact matched or the matched
  /// contact has no name.
  final String? displayName;

  const MeshCorePathOverlayHop({
    required this.byte,
    required this.label,
    this.latLng,
    this.displayName,
  });

  bool get hasLocation => latLng != null;

  @override
  String toString() =>
      'MeshCorePathOverlayHop(byte=$byte, label=$label, '
      'hasLocation=$hasLocation)'; // lint-allow: hardcoded-string
}

/// A single in-flight path overlay. Held by the
/// `meshCorePathOverlayProvider` and consumed by `MeshCoreMapScreen`.
class MeshCorePathOverlay {
  /// Origin endpoint - typically the local device. Null when the
  /// local device has no known location.
  final LatLng? originLatLng;

  /// Target endpoint - the contact at the far end of the path. Null
  /// when the target contact has no known location.
  final LatLng? targetLatLng;

  /// Ordered hop list, origin → target. Hops with `latLng == null`
  /// are surfaced but omitted from the rendered polyline.
  final List<MeshCorePathOverlayHop> hops;

  /// Where this overlay was built from.
  final MeshCorePathOverlaySource source;

  /// Contact pubkey hex this overlay belongs to. Used by widgets to
  /// re-resolve when the contact list updates.
  final String contactPubKeyHex;

  /// True when the source bytes came from `MeshCoreContact
  /// .pathOverrideBytes` (D34c-B-A forced override) rather than the
  /// live firmware path. The map may surface a small "Forced" chip.
  final bool isForced;

  const MeshCorePathOverlay({
    required this.originLatLng,
    required this.targetLatLng,
    required this.hops,
    required this.source,
    required this.contactPubKeyHex,
    this.isForced = false,
  });

  /// Number of resolved (renderable) hops.
  int get knownHopCount => hops.where((h) => h.hasLocation).length;

  /// Total hops in the path, regardless of resolution.
  int get totalHopCount => hops.length;

  /// True iff there is enough coordinate data to draw at least one
  /// polyline segment. Used to gate the "No path data to show on
  /// map" snackbar.
  bool get hasDrawableData {
    final pts = drawablePoints();
    return pts.length >= 2;
  }

  /// Compute the polyline points the map should draw. Filters out
  /// hops with null `latLng`. Includes `originLatLng` and
  /// `targetLatLng` when present.
  List<LatLng> drawablePoints() {
    final pts = <LatLng>[];
    if (originLatLng != null) pts.add(originLatLng!);
    for (final h in hops) {
      if (h.latLng != null) pts.add(h.latLng!);
    }
    if (targetLatLng != null) pts.add(targetLatLng!);
    return pts;
  }

  // ---------------------------------------------------------------------------
  // Pure resolvers
  // ---------------------------------------------------------------------------

  /// Build an overlay from a contact's live firmware path (or its
  /// `pathOverrideBytes` when that field is non-null). Returns null
  /// for flood paths (no fixed route).
  static MeshCorePathOverlay? fromContact({
    required MeshCoreContact target,
    required List<MeshCoreContact> contacts,
    required MeshCoreSelfInfo? selfInfo,
  }) {
    // Flood path - no overlay possible. pathOverride takes precedence.
    final override = target.pathOverride;
    final overrideBytes = target.pathOverrideBytes;
    final Uint8List? bytes;
    final bool isForced;
    if (override != null) {
      if (override < 0) {
        // pathOverride == -1 is "Force Flood" - no fixed path.
        return null;
      }
      // override >= 0: prefer the explicit forced bytes when present.
      if (overrideBytes != null) {
        bytes = overrideBytes;
        isForced = true;
      } else {
        // Force Direct (override == 0) with no bytes - draw self→target.
        bytes = Uint8List(0);
        isForced = true;
      }
    } else {
      if (target.pathLength < 0) return null;
      // pathLength >= 0: use the live firmware path bytes.
      bytes = target.path;
      isForced = false;
    }

    return _resolve(
      target: target,
      contacts: contacts,
      selfInfo: selfInfo,
      hopBytes: bytes,
      source: MeshCorePathOverlaySource.active,
      isForced: isForced,
    );
  }

  /// Build an overlay from a saved [hopBytes] sequence (D39-A path
  /// history entry).
  static MeshCorePathOverlay? fromHistory({
    required MeshCoreContact target,
    required List<MeshCoreContact> contacts,
    required MeshCoreSelfInfo? selfInfo,
    required Uint8List hopBytes,
  }) {
    if (hopBytes.length > 64) return null;
    return _resolve(
      target: target,
      contacts: contacts,
      selfInfo: selfInfo,
      hopBytes: hopBytes,
      source: MeshCorePathOverlaySource.history,
      isForced: false,
    );
  }

  /// D42-B-A: build an overlay from inferred [hopBytes]. Mirrors
  /// [fromHistory] but flags the resulting overlay as
  /// [MeshCorePathOverlaySource.inferred]. The caller is expected to
  /// have produced [hopBytes] via [inferRecentPathBytes] (or an
  /// equivalent pure pipeline); this factory does no inference work
  /// itself.
  static MeshCorePathOverlay? fromInferred({
    required MeshCoreContact target,
    required List<MeshCoreContact> contacts,
    required MeshCoreSelfInfo? selfInfo,
    required Uint8List hopBytes,
  }) {
    if (hopBytes.length > 64) return null;
    return _resolve(
      target: target,
      contacts: contacts,
      selfInfo: selfInfo,
      hopBytes: hopBytes,
      source: MeshCorePathOverlaySource.inferred,
      isForced: false,
    );
  }

  static MeshCorePathOverlay _resolve({
    required MeshCoreContact target,
    required List<MeshCoreContact> contacts,
    required MeshCoreSelfInfo? selfInfo,
    required Uint8List hopBytes,
    required MeshCorePathOverlaySource source,
    required bool isForced,
  }) {
    // Build a byte → best-contact map (collision tiebreaker = newest
    // lastSeen). Empty / no-location contacts are skipped during the
    // lookup, not pre-filtered, so collisions still pick the most
    // recent local entry.
    final byByte = <int, MeshCoreContact>{};
    for (final c in contacts) {
      if (c.publicKey.isEmpty) continue;
      if (!c.hasLocation) continue;
      final b = c.publicKey.first;
      final prev = byByte[b];
      if (prev == null || c.lastSeen.isAfter(prev.lastSeen)) {
        byByte[b] = c;
      }
    }

    final hops = <MeshCorePathOverlayHop>[];
    for (final b in hopBytes) {
      final match = byByte[b];
      hops.add(
        MeshCorePathOverlayHop(
          byte: b,
          label: _hex2(b),
          latLng: match != null
              ? _meshcoreLatLng(match.latitude, match.longitude)
              : null,
          displayName: match?.displayName.isNotEmpty == true
              ? match!.displayName
              : null,
        ),
      );
    }

    final origin = _selfLatLng(selfInfo);
    final targetLatLng = _meshcoreLatLng(target.latitude, target.longitude);

    return MeshCorePathOverlay(
      originLatLng: origin,
      targetLatLng: targetLatLng,
      hops: List.unmodifiable(hops),
      source: source,
      contactPubKeyHex: target.publicKeyHex,
      isForced: isForced,
    );
  }

  static LatLng? _selfLatLng(MeshCoreSelfInfo? info) {
    if (info == null) return null;
    final rawLat = info.latitude;
    final rawLng = info.longitude;
    if (rawLat == null || rawLng == null) return null;
    // SELF_INFO encodes lat/lon as int32 in 1e7 scale (matches
    // `MeshCoreContactInfo.latitudeDegrees` / `longitudeDegrees`).
    return _meshcoreLatLng(rawLat / 1e7, rawLng / 1e7);
  }

  // MeshCore-specific LatLng guard. Domain rule, NOT a global LatLng
  // policy: the firmware encodes "no GPS fix" as (0, 0), so we map
  // exact-zero to null to avoid drawing a polyline through Null Island.
  // All other validation (NaN, in-range) is delegated to safeLatLng.
  static LatLng? _meshcoreLatLng(num? lat, num? lng) {
    final ll = safeLatLng(lat, lng);
    if (ll == null) return null;
    if (ll.latitude == 0.0 && ll.longitude == 0.0) return null;
    return ll;
  }

  static String _hex2(int byte) =>
      byte.toRadixString(16).padLeft(2, '0').toLowerCase();
}

// ---------------------------------------------------------------------------
// D42-B-A: passive path inference (recency-based, pure)
// ---------------------------------------------------------------------------

/// Provenance of an inferred path candidate. Surfaced from the pure
/// helper so tests (and any future diagnostics surface) can pin which
/// evidence source the winning bytes came from. Not rendered in the
/// UI in this slice — the map only consumes the resulting overlay.
enum MeshCoreInferenceEvidence {
  /// The winning bytes came from a D39 saved-path history entry.
  savedHistory,

  /// The winning bytes came from a persisted inbound contact message
  /// (its `pathBytes` + `pathLength` fields).
  inboundMessage,
}

/// Pure return shape of [inferRecentPathBytes]. Carries the winning
/// hop bytes plus the timestamp + evidence source that made it win —
/// enough for tests to assert provenance without rebuilding an
/// overlay.
class MeshCoreInferredPath {
  final Uint8List hopBytes;
  final DateTime asOf;
  final MeshCoreInferenceEvidence evidence;

  const MeshCoreInferredPath({
    required this.hopBytes,
    required this.asOf,
    required this.evidence,
  });

  @override
  String toString() =>
      'MeshCoreInferredPath(hops=${hopBytes.length}, '
      // lint-allow: hardcoded-string — diagnostic only, never user-visible.
      'asOf=$asOf, evidence=${evidence.name})';
}

const int _kMeshCoreInferenceMaxPathBytes = 64;

/// D42-B-A: pure recency-based path inference. Returns the newest
/// valid candidate's hop bytes + provenance, or `null` when no
/// candidate passes the validity filter.
///
/// Inputs are pre-loaded by the caller; this function does no I/O.
///
/// Validity:
///   - For D39 [savedEntries]: `bytes.isNotEmpty` and
///     `bytes.length <= 64`. (The D39 store already enforces this
///     at parse time; the helper re-checks defensively.)
///   - For [storedMessages]: `!isOutgoing`, `pathBytes.isNotEmpty`,
///     `pathBytes.length <= 64`, `pathLength != null`,
///     `pathLength > 0` (skip flood = -1 and 0-hop direct).
///
/// Selection: candidate with the maximum recency timestamp
///   (`lastUsedAt` for saved entries, `timestamp` for messages).
///
/// Tie-break (deterministic when timestamps are equal to the
/// millisecond):
///   1. Saved-history wins over inbound-message.
///   2. Shorter hop count wins.
///   3. Lexical byte order ascending wins.
MeshCoreInferredPath? inferRecentPathBytes({
  required Iterable<MeshCorePathHistoryEntry> savedEntries,
  required Iterable<MeshCoreStoredMessage> storedMessages,
}) {
  final candidates = <_InferenceCandidate>[];

  for (final e in savedEntries) {
    final b = e.bytes;
    if (b.isEmpty) continue;
    if (b.length > _kMeshCoreInferenceMaxPathBytes) continue;
    candidates.add(
      _InferenceCandidate(
        bytes: b,
        asOf: e.lastUsedAt,
        evidence: MeshCoreInferenceEvidence.savedHistory,
      ),
    );
  }

  for (final m in storedMessages) {
    if (m.isOutgoing) continue;
    final pl = m.pathLength;
    if (pl == null || pl <= 0) continue;
    final b = m.pathBytes;
    if (b.isEmpty) continue;
    if (b.length > _kMeshCoreInferenceMaxPathBytes) continue;
    candidates.add(
      _InferenceCandidate(
        bytes: b,
        asOf: m.timestamp,
        evidence: MeshCoreInferenceEvidence.inboundMessage,
      ),
    );
  }

  if (candidates.isEmpty) return null;

  candidates.sort(_compareCandidates);
  final winner = candidates.first;
  return MeshCoreInferredPath(
    hopBytes: Uint8List.fromList(winner.bytes),
    asOf: winner.asOf,
    evidence: winner.evidence,
  );
}

/// Internal struct so the helper isn't iterating two parallel lists.
class _InferenceCandidate {
  final Uint8List bytes;
  final DateTime asOf;
  final MeshCoreInferenceEvidence evidence;

  const _InferenceCandidate({
    required this.bytes,
    required this.asOf,
    required this.evidence,
  });
}

/// Strict-total ordering: most-recent first, then the three-tier
/// deterministic tie-break.
int _compareCandidates(_InferenceCandidate a, _InferenceCandidate b) {
  // 1. Recency descending.
  final tsCmp = b.asOf.compareTo(a.asOf);
  if (tsCmp != 0) return tsCmp;
  // 2. Saved history beats inbound message.
  final aSaved = a.evidence == MeshCoreInferenceEvidence.savedHistory;
  final bSaved = b.evidence == MeshCoreInferenceEvidence.savedHistory;
  if (aSaved != bSaved) return aSaved ? -1 : 1;
  // 3. Shorter hop count wins.
  final lenCmp = a.bytes.length.compareTo(b.bytes.length);
  if (lenCmp != 0) return lenCmp;
  // 4. Lexical byte order ascending wins.
  final n = a.bytes.length;
  for (var i = 0; i < n; i++) {
    final c = a.bytes[i].compareTo(b.bytes[i]);
    if (c != 0) return c;
  }
  return 0;
}
