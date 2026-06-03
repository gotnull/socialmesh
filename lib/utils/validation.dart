// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';

import 'package:flutter/services.dart';

// Meshtastic protocol validation utilities. Long/short name limits are byte
// counts because the firmware fields are length-prefixed UTF-8, so a 4-byte
// emoji exactly fills the 4-byte short_name slot.

/// Maximum length for channel name (11 characters, no spaces)
const int maxChannelNameLength = 11;

/// Maximum byte length of `User.long_name` (Meshtastic firmware caps at
/// 40 bytes including the trailing null).
const int maxLongNameLength = 39;

/// Maximum byte length of `User.short_name` (Meshtastic firmware caps at
/// 5 bytes including the trailing null). Emojis are allowed; one BMP-plane
/// emoji is 3 bytes UTF-8, one supplementary-plane emoji is 4 bytes.
const int maxShortNameLength = 4;

/// Validates and sanitizes a channel name according to Meshtastic specs
/// - Max 11 characters
/// - No spaces (replaced with underscores)
/// - Alphanumeric, underscore, and hyphen only
String sanitizeChannelName(String name) {
  // Replace spaces with underscores
  var sanitized = name.replaceAll(' ', '_');

  // Remove any non-alphanumeric characters except underscore and hyphen
  sanitized = sanitized.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '');

  // Truncate to max length
  if (sanitized.length > maxChannelNameLength) {
    sanitized = sanitized.substring(0, maxChannelNameLength);
  }

  return sanitized;
}

/// Validates a channel name
/// Returns null if valid, error message if invalid
String? validateChannelName(String name) {
  if (name.isEmpty) {
    return null; // Empty is allowed (uses default)
  }

  if (name.contains(' ')) {
    return 'Channel name cannot contain spaces'; // lint-allow: hardcoded-string
  }

  if (name.length > maxChannelNameLength) {
    return 'Channel name must be $maxChannelNameLength characters or less'; // lint-allow: hardcoded-string
  }

  if (!RegExp(r'^[a-zA-Z0-9_-]*$').hasMatch(name)) {
    return 'Channel name can only contain letters, numbers, underscores, and hyphens'; // lint-allow: hardcoded-string
  }

  return null;
}

/// UTF-8 byte length of [s].
int utf8ByteLength(String s) => utf8.encode(s).length;

/// Truncate [s] to at most [maxBytes] UTF-8 bytes, walking by Unicode rune so
/// a multi-byte character is never split. A single emoji is one rune, so
/// "🎉" (4 bytes) survives a 4-byte limit but "🎉A" does not.
String truncateUtf8(String s, int maxBytes) {
  if (utf8ByteLength(s) <= maxBytes) return s;
  final buf = StringBuffer();
  var bytes = 0;
  for (final rune in s.runes) {
    // lint-allow: no-raw-from-char-codes — String.runes yields valid scalars (pairs already decoded)
    final ch = String.fromCharCodes([rune]);
    final w = utf8ByteLength(ch);
    if (bytes + w > maxBytes) break;
    buf.write(ch);
    bytes += w;
  }
  return buf.toString();
}

/// Sanitize a user long name: trim whitespace and truncate to
/// [maxLongNameLength] UTF-8 bytes. Emojis and non-Latin scripts pass
/// through unchanged.
String sanitizeLongName(String name) =>
    truncateUtf8(name.trim(), maxLongNameLength);

/// Validates a user long name
/// Returns null if valid, error message if invalid
String? validateLongName(String name) {
  if (name.trim().isEmpty) {
    return 'Name is required'; // lint-allow: hardcoded-string
  }

  if (utf8ByteLength(name) > maxLongNameLength) {
    return 'Name must be $maxLongNameLength bytes or less'; // lint-allow: hardcoded-string
  }

  return null;
}

/// Sanitize a user short name: truncate to [maxShortNameLength] UTF-8 bytes.
/// No case conversion or charset filter — emojis and lowercase are allowed
/// to match the official Meshtastic-Apple companion app.
String sanitizeShortName(String name) => truncateUtf8(name, maxShortNameLength);

/// Validates a user short name
/// Returns null if valid, error message if invalid
String? validateShortName(String name) {
  if (name.isEmpty) {
    return 'Short name is required'; // lint-allow: hardcoded-string
  }

  if (utf8ByteLength(name) > maxShortNameLength) {
    return 'Short name must be $maxShortNameLength bytes or less'; // lint-allow: hardcoded-string
  }

  return null;
}

/// Text input formatter that limits input to [maxBytes] UTF-8 bytes.
/// Use this instead of `LengthLimitingTextInputFormatter` for protocol
/// fields that are length-bounded in bytes (e.g. Meshtastic short_name
/// is 4 bytes, which is exactly one supplementary-plane emoji).
class Utf8ByteLengthLimitingTextInputFormatter extends TextInputFormatter {
  Utf8ByteLengthLimitingTextInputFormatter(this.maxBytes);

  final int maxBytes;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (utf8ByteLength(newValue.text) <= maxBytes) return newValue;
    final truncated = truncateUtf8(newValue.text, maxBytes);
    return TextEditingValue(
      text: truncated,
      selection: TextSelection.collapsed(offset: truncated.length),
    );
  }
}

/// Text input formatter that converts text to uppercase
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

// =============================================================================
// DISPLAY NAME / USERNAME VALIDATION
// =============================================================================

/// The owner's Firebase UID - only this user can use reserved names and is verified
const String ownerUid = '9ltxJGViWHW5aj5HhLGmiVwkrLU2';

/// Check if a user ID is the app owner (always verified)
bool isAppOwner(String? userId) => userId == ownerUid;

/// Reserved display names that only the owner can claim
const Set<String> _reservedExactNames = {
  'gotnull',
  'socialmesh',
  'admin',
  'administrator',
  'support',
  'help',
  'info',
  'contact',
  'official',
  'verified',
  'mod',
  'moderator',
  'staff',
  'team',
  'root',
  'system',
  'bot',
  'api',
  'dev',
  'developer',
  'meshtastic',
  'mesh',
};

/// Blocked patterns - names matching these regexes are never allowed (except by owner)
/// Note: Brand patterns (socialmesh, gotnull, meshtastic) use optional separators
/// because the brand name itself should be blocked. Impersonation patterns (real,
/// official, admin, etc.) require a separator to avoid false positives on legitimate
/// names like "Play2BReal", "Modern", "Helpful", "Badminton", etc.
final List<RegExp> _blockedPatterns = [
  // socialmesh variations (brand name - no separator needed)
  RegExp(r'^social[-_.]?mesh', caseSensitive: false),
  RegExp(r'^socialmesh', caseSensitive: false),
  // gotnull variations (brand name - no separator needed)
  RegExp(r'^got[-_.]?null', caseSensitive: false),
  // Official/verified impersonation (require separator)
  RegExp(r'[-_.]official$', caseSensitive: false),
  RegExp(r'[-_.]verified$', caseSensitive: false),
  RegExp(r'[-_.]real$', caseSensitive: false),
  RegExp(r'^real[-_.]', caseSensitive: false),
  RegExp(
    r'^the[-_.]?real[-_.]?',
    caseSensitive: false,
  ), // "thereal" is specifically impersonation
  RegExp(r'^official[-_.]', caseSensitive: false),
  // Admin/mod impersonation (require separator + anchor)
  RegExp(r'[-_.]admin$', caseSensitive: false),
  RegExp(r'[-_.]mod(?:erator)?$', caseSensitive: false),
  RegExp(r'^admin[-_.]', caseSensitive: false),
  RegExp(r'^mod[-_.]', caseSensitive: false),
  // Support impersonation (require separator)
  RegExp(r'[-_.]support$', caseSensitive: false),
  RegExp(r'^support[-_.]', caseSensitive: false),
  RegExp(r'[-_.]help$', caseSensitive: false),
  RegExp(r'^help[-_.]', caseSensitive: false),
  // Meshtastic brand (brand name - no separator needed)
  RegExp(r'^meshtastic', caseSensitive: false),
];

/// Allowed characters: letters, numbers, periods, underscores
final RegExp _validUsernameChars = RegExp(r'^[a-zA-Z0-9._]+$');

/// Check if a display name is reserved (exact match)
bool isReservedDisplayName(String displayName) {
  return _reservedExactNames.contains(displayName.toLowerCase());
}

/// Check if a display name matches any blocked pattern
bool matchesBlockedPattern(String displayName) {
  final lowerName = displayName.toLowerCase();
  return _blockedPatterns.any((pattern) => pattern.hasMatch(lowerName));
}

/// Check if a user can use a specific display name
/// Returns true if the name is allowed for this user
bool canUseDisplayName(String displayName, String? userId) {
  // Owner can use any name
  if (isAppOwner(userId)) return true;

  final lowerName = displayName.toLowerCase();

  // Check exact reserved names
  if (_reservedExactNames.contains(lowerName)) {
    return false;
  }

  // Check blocked patterns
  if (matchesBlockedPattern(lowerName)) {
    return false;
  }

  return true;
}

/// Validates a display name for the social profile
/// Returns null if valid, error message if invalid
String? validateDisplayName(String name, {String? userId}) {
  final trimmed = name.trim();

  if (trimmed.isEmpty) {
    return 'Display name is required'; // lint-allow: hardcoded-string
  }

  if (trimmed.length < 2) {
    return 'Display name must be at least 2 characters'; // lint-allow: hardcoded-string
  }

  if (trimmed.length > 30) {
    return 'Display name must be 30 characters or less'; // lint-allow: hardcoded-string
  }

  // Only letters, numbers, periods, underscores allowed
  if (!_validUsernameChars.hasMatch(trimmed)) {
    return 'Only letters, numbers, periods and underscores (no spaces)'; // lint-allow: hardcoded-string
  }

  // Cannot start or end with a period
  if (trimmed.startsWith('.') || trimmed.endsWith('.')) {
    return 'Display name cannot start or end with a period'; // lint-allow: hardcoded-string
  }

  // Cannot have consecutive periods
  if (trimmed.contains('..')) {
    return 'Display name cannot have consecutive periods'; // lint-allow: hardcoded-string
  }

  // Cannot be only numbers
  if (RegExp(r'^[0-9]+$').hasMatch(trimmed)) {
    return 'Display name cannot be only numbers'; // lint-allow: hardcoded-string
  }

  // Check reserved/blocked names
  if (!canUseDisplayName(trimmed, userId)) {
    return 'This display name is not available'; // lint-allow: hardcoded-string
  }

  return null;
}
