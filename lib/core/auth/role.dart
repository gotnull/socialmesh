// SPDX-License-Identifier: GPL-3.0-or-later

/// Enterprise RBAC roles.
///
/// Ordered by authority level: observer (lowest) to admin (highest).
/// Stored as Firebase custom claims string values.
///
/// Spec: RBAC.md (Sprint 007/W2.2).
enum Role implements Comparable<Role> {
  observer(0),
  operator(1),
  supervisor(2),
  admin(3);

  const Role(this.level);

  /// Authority level. Higher value = more authority.
  final int level;

  /// Returns true if this role has at least the authority of [other].
  bool hasAuthority(Role other) => level >= other.level;

  @override
  int compareTo(Role other) => level.compareTo(other.level);

  /// Parses a Firebase claim string to a [Role], or returns null.
  static Role? fromString(String? value) {
    if (value == null) return null;
    return Role.values.cast<Role?>().firstWhere(
      (r) => r!.name == value,
      orElse: () => null,
    );
  }
}
