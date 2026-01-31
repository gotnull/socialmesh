// SPDX-License-Identifier: GPL-3.0-or-later
class NodeDisplayNameResolver {
  static final RegExp _bleDefaultPattern = RegExp(
    r'^Meshtastic_[0-9a-fA-F]{4}$',
  );
  static String resolve({
    required int nodeNum,
    String? longName,
    String? shortName,
    String? bleName,
    String? fallback,
  }) {
    final longResolved = sanitizeName(longName);
    if (longResolved != null) return longResolved;

    final shortResolved = sanitizeName(shortName);
    if (shortResolved != null) return shortResolved;

    final bleResolved = _normalizeBle(bleName);
    if (bleResolved != null) return bleResolved;

    return fallback ?? _hexFallback(nodeNum);
  }

  static bool isBleDefaultName(String? value) {
    final normalized = _normalize(value);
    if (normalized == null) return false;
    return _bleDefaultPattern.hasMatch(normalized);
  }

  static String? sanitizeName(String? value) {
    final normalized = _normalize(value);
    if (normalized == null) return null;
    if (_bleDefaultPattern.hasMatch(normalized)) return null;
    return normalized;
  }

  static String _hexFallback(int nodeNum) {
    return '!${nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}';
  }

  static String? _normalize(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _normalizeBle(String? value) {
    final normalized = _normalize(value);
    if (normalized == null) return null;
    if (_bleDefaultPattern.hasMatch(normalized)) return null;
    return normalized;
  }
}
