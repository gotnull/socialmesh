// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';

/// Represents a MeshCore contact.
///
/// In MeshCore, contacts are discovered via advertisements or exchanged
/// via contact codes (QR). Each contact has a public key and optional
/// display name.
@immutable
class MeshCoreContact {
  /// The contact's public key (hex encoded).
  final String publicKey;

  /// Display name, user-provided or derived from advert.
  final String? displayName;

  /// Timestamp when contact was first discovered.
  final DateTime? discoveredAt;

  /// Timestamp when contact was last seen (advert or message).
  final DateTime? lastSeen;

  /// Whether this contact is blocked.
  final bool isBlocked;

  /// Whether this contact is a favorite/pinned.
  final bool isFavorite;

  /// Notes/memo for this contact.
  final String? notes;

  const MeshCoreContact({
    required this.publicKey,
    this.displayName,
    this.discoveredAt,
    this.lastSeen,
    this.isBlocked = false,
    this.isFavorite = false,
    this.notes,
  });

  /// Returns a display-friendly name.
  String get name => displayName ?? publicKey.substring(0, 8);

  /// Whether this contact has been seen recently (within 30 minutes).
  bool get isRecentlySeen {
    if (lastSeen == null) return false;
    final age = DateTime.now().difference(lastSeen!);
    return age.inMinutes < 30;
  }

  MeshCoreContact copyWith({
    String? publicKey,
    String? displayName,
    DateTime? discoveredAt,
    DateTime? lastSeen,
    bool? isBlocked,
    bool? isFavorite,
    String? notes,
  }) {
    return MeshCoreContact(
      publicKey: publicKey ?? this.publicKey,
      displayName: displayName ?? this.displayName,
      discoveredAt: discoveredAt ?? this.discoveredAt,
      lastSeen: lastSeen ?? this.lastSeen,
      isBlocked: isBlocked ?? this.isBlocked,
      isFavorite: isFavorite ?? this.isFavorite,
      notes: notes ?? this.notes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeshCoreContact &&
          runtimeType == other.runtimeType &&
          publicKey == other.publicKey &&
          displayName == other.displayName &&
          discoveredAt == other.discoveredAt &&
          lastSeen == other.lastSeen &&
          isBlocked == other.isBlocked &&
          isFavorite == other.isFavorite &&
          notes == other.notes;

  @override
  int get hashCode => Object.hash(
    publicKey,
    displayName,
    discoveredAt,
    lastSeen,
    isBlocked,
    isFavorite,
    notes,
  );
}
