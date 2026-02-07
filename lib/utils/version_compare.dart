// SPDX-License-Identifier: GPL-3.0-or-later

/// Semantic version comparison utilities for the What's New system.
///
/// Supports standard major.minor.patch format (e.g. "1.2.0").
/// Build metadata and pre-release suffixes are stripped before comparison.
class SemanticVersion implements Comparable<SemanticVersion> {
  final int major;
  final int minor;
  final int patch;

  const SemanticVersion(this.major, this.minor, this.patch);

  /// Parses a version string like "1.2.0" or "1.2.0+103".
  /// Returns null if the string cannot be parsed.
  static SemanticVersion? tryParse(String version) {
    // Strip build metadata (e.g. "+103") and pre-release (e.g. "-beta.1")
    final cleaned = version.split('+').first.split('-').first.trim();
    final parts = cleaned.split('.');
    if (parts.length < 2 || parts.length > 3) return null;

    final major = int.tryParse(parts[0]);
    final minor = int.tryParse(parts[1]);
    final patch = parts.length >= 3 ? int.tryParse(parts[2]) : 0;

    if (major == null || minor == null || patch == null) return null;
    if (major < 0 || minor < 0 || patch < 0) return null;

    return SemanticVersion(major, minor, patch);
  }

  /// Parses a version string, throwing [FormatException] on failure.
  factory SemanticVersion.parse(String version) {
    final result = tryParse(version);
    if (result == null) {
      throw FormatException('Invalid semantic version: "$version"');
    }
    return result;
  }

  /// Returns true if [this] version is strictly greater than [other].
  bool isNewerThan(SemanticVersion other) => compareTo(other) > 0;

  /// Returns true if [this] version is greater than or equal to [other].
  bool isAtLeast(SemanticVersion other) => compareTo(other) >= 0;

  @override
  int compareTo(SemanticVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SemanticVersion &&
          major == other.major &&
          minor == other.minor &&
          patch == other.patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}

/// Compares two version strings using semantic versioning rules.
///
/// Returns:
///   - positive if [a] is newer than [b]
///   - negative if [a] is older than [b]
///   - zero if they are equal
///
/// Returns null if either string cannot be parsed.
int? compareVersions(String a, String b) {
  final versionA = SemanticVersion.tryParse(a);
  final versionB = SemanticVersion.tryParse(b);
  if (versionA == null || versionB == null) return null;
  return versionA.compareTo(versionB);
}

/// Returns true if [currentVersion] is newer than [lastSeenVersion].
///
/// Returns false if either string cannot be parsed.
bool isVersionNewer(String currentVersion, String lastSeenVersion) {
  final current = SemanticVersion.tryParse(currentVersion);
  final lastSeen = SemanticVersion.tryParse(lastSeenVersion);
  if (current == null || lastSeen == null) return false;
  return current.isNewerThan(lastSeen);
}

/// Returns true if [currentVersion] is at least [minimumVersion].
///
/// Returns false if either string cannot be parsed.
bool isVersionAtLeast(String currentVersion, String minimumVersion) {
  final current = SemanticVersion.tryParse(currentVersion);
  final minimum = SemanticVersion.tryParse(minimumVersion);
  if (current == null || minimum == null) return false;
  return current.isAtLeast(minimum);
}
