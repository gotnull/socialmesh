// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import '../../core/logging.dart';

/// A TAK ↔ Meshtastic identity mapping entry.
class TakIdentity {
  /// Meshtastic node number (0 for TAK-only clients).
  final int nodeNum;

  /// TAK UID (e.g., 'MESHTASTIC-1A2B3C4D' or 'ANDROID-abc123').
  final String takUid;

  /// Callsign or display name.
  final String callsign;

  /// Manual callsign override (takes precedence over [callsign]).
  final String? overrideCallsign;

  /// First seen timestamp (ms since epoch).
  final int firstSeenMs;

  /// Last seen timestamp (ms since epoch).
  final int lastSeenMs;

  TakIdentity({
    required this.nodeNum,
    required this.takUid,
    required this.callsign,
    this.overrideCallsign,
    required this.firstSeenMs,
    required this.lastSeenMs,
  });

  /// The effective display callsign (override if set, else callsign).
  String get displayCallsign => overrideCallsign ?? callsign;

  /// Whether this identity is for a Meshtastic mesh node.
  bool get isMeshNode => nodeNum != 0;

  /// Returns a copy with updated fields.
  TakIdentity copyWith({
    int? nodeNum,
    String? takUid,
    String? callsign,
    String? overrideCallsign,
    int? firstSeenMs,
    int? lastSeenMs,
  }) {
    return TakIdentity(
      nodeNum: nodeNum ?? this.nodeNum,
      takUid: takUid ?? this.takUid,
      callsign: callsign ?? this.callsign,
      overrideCallsign: overrideCallsign ?? this.overrideCallsign,
      firstSeenMs: firstSeenMs ?? this.firstSeenMs,
      lastSeenMs: lastSeenMs ?? this.lastSeenMs,
    );
  }

  /// Converts to a database row map.
  Map<String, Object?> toMap() => {
    'node_num': nodeNum,
    'tak_uid': takUid,
    'callsign': callsign,
    'override_callsign': overrideCallsign,
    'first_seen_ms': firstSeenMs,
    'last_seen_ms': lastSeenMs,
  };

  /// Creates from a database row map.
  factory TakIdentity.fromMap(Map<String, Object?> map) => TakIdentity(
    nodeNum: map['node_num'] as int? ?? 0,
    takUid: map['tak_uid'] as String? ?? '',
    callsign: map['callsign'] as String? ?? '',
    overrideCallsign: map['override_callsign'] as String?,
    firstSeenMs: map['first_seen_ms'] as int? ?? 0,
    lastSeenMs: map['last_seen_ms'] as int? ?? 0,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TakIdentity &&
          nodeNum == other.nodeNum &&
          takUid == other.takUid &&
          callsign == other.callsign &&
          overrideCallsign == other.overrideCallsign;

  @override
  int get hashCode => Object.hash(nodeNum, takUid, callsign, overrideCallsign);

  @override
  String toString() =>
      'TakIdentity(nodeNum=$nodeNum, uid=$takUid, callsign=$displayCallsign)';
}

/// Callback to persist identity data.
typedef IdentityPersistCallback = Future<void> Function(TakIdentity identity);

/// Callback to load all persisted identities.
typedef IdentityLoadCallback = Future<List<TakIdentity>> Function();

/// Bidirectional identity registry for TAK ↔ Meshtastic mapping.
///
/// Maintains in-memory lookup maps with optional persistence callbacks.
class TakIdentityRegistry {
  final IdentityPersistCallback? _persist;
  final IdentityLoadCallback? _load;

  /// nodeNum -> TakIdentity
  final _byNodeNum = <int, TakIdentity>{};

  /// takUid -> TakIdentity
  final _byTakUid = <String, TakIdentity>{};

  /// callsign (lowercased) -> TakIdentity
  final _byCallsign = <String, TakIdentity>{};

  TakIdentityRegistry({
    IdentityPersistCallback? persist,
    IdentityLoadCallback? load,
  }) : _persist = persist,
       _load = load;

  /// Loads identities from persistence.
  Future<void> loadFromStorage() async {
    if (_load == null) return;
    final identities = await _load();
    for (final identity in identities) {
      _index(identity);
    }
    AppLogging.tak(
      'Identity: registry loaded ${identities.length} identities from database',
    );
  }

  /// Registers (or updates) a Meshtastic mesh node.
  Future<void> registerMeshNode(
    int nodeNum,
    String longName,
    String shortName,
  ) async {
    final nodeHex = nodeNum.toRadixString(16).toUpperCase().padLeft(8, '0');
    final takUid = 'MESHTASTIC-$nodeHex';
    final callsign = longName.isNotEmpty ? longName : shortName;
    final now = DateTime.now().millisecondsSinceEpoch;

    final existing = _byNodeNum[nodeNum];
    final identity = TakIdentity(
      nodeNum: nodeNum,
      takUid: takUid,
      callsign: callsign,
      overrideCallsign: existing?.overrideCallsign,
      firstSeenMs: existing?.firstSeenMs ?? now,
      lastSeenMs: now,
    );

    _index(identity);
    await _persist?.call(identity);

    AppLogging.tak(
      "Identity: registered mesh node 0x$nodeHex -> $takUid (callsign='$callsign')",
    );
  }

  /// Registers (or updates) a TAK client.
  Future<void> registerTakClient(String uid, String callsign) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final existing = _byTakUid[uid];
    final identity = TakIdentity(
      nodeNum: 0, // TAK clients have no mesh node number.
      takUid: uid,
      callsign: callsign,
      overrideCallsign: existing?.overrideCallsign,
      firstSeenMs: existing?.firstSeenMs ?? now,
      lastSeenMs: now,
    );

    _index(identity);
    await _persist?.call(identity);

    AppLogging.tak(
      "Identity: registered TAK client $uid -> callsign='$callsign'",
    );
  }

  /// Looks up identity by Meshtastic node number.
  TakIdentity? lookupByNodeNum(int nodeNum) => _byNodeNum[nodeNum];

  /// Looks up identity by TAK UID.
  TakIdentity? lookupByTakUid(String uid) => _byTakUid[uid];

  /// Looks up identity by callsign (case-insensitive).
  TakIdentity? lookupByCallsign(String callsign) =>
      _byCallsign[callsign.toLowerCase()];

  /// Sets a manual callsign override for a mesh node.
  Future<void> setCallsignOverride(int nodeNum, String customCallsign) async {
    final existing = _byNodeNum[nodeNum];
    if (existing == null) return;

    final oldCallsign = existing.displayCallsign;
    final updated = existing.copyWith(overrideCallsign: customCallsign);
    _index(updated);
    await _persist?.call(updated);

    AppLogging.tak(
      "Identity: callsign override for 0x${nodeNum.toRadixString(16).toUpperCase().padLeft(8, '0')}: '$oldCallsign' -> '$customCallsign'",
    );
  }

  /// All registered identities.
  List<TakIdentity> get allIdentities => _byTakUid.values.toList();

  /// Count of registered mesh nodes.
  int get meshNodeCount => _byNodeNum.values.where((i) => i.isMeshNode).length;

  /// Count of registered TAK clients.
  int get takClientCount => _byTakUid.values.where((i) => !i.isMeshNode).length;

  /// Clears all identities from memory.
  void clear() {
    _byNodeNum.clear();
    _byTakUid.clear();
    _byCallsign.clear();
  }

  // --- Internal ---

  void _index(TakIdentity identity) {
    // Remove old callsign index if the callsign changed.
    final oldByUid = _byTakUid[identity.takUid];
    if (oldByUid != null) {
      _byCallsign.remove(oldByUid.displayCallsign.toLowerCase());
    }

    if (identity.nodeNum != 0) {
      _byNodeNum[identity.nodeNum] = identity;
    }
    _byTakUid[identity.takUid] = identity;
    _byCallsign[identity.displayCallsign.toLowerCase()] = identity;
  }
}
