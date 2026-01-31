// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/services.dart';

/// Meshtastic protocol validation utilities
/// Based on Meshtastic firmware constraints

/// Maximum length for channel name (11 characters, no spaces)
const int maxChannelNameLength = 11;

/// Maximum length for user long name (39 bytes)
const int maxLongNameLength = 39;

/// Maximum length for user short name (4 characters, uppercase)
const int maxShortNameLength = 4;

/// Validates and sanitizes a channel name according to Meshtastic specs
/// - Max 11 characters
/// - No spaces (replaced with underscores)
/// - Alphanumeric and underscore only
String sanitizeChannelName(String name) {
  // Replace spaces with underscores
  var sanitized = name.replaceAll(' ', '_');

  // Remove any non-alphanumeric characters except underscore
  sanitized = sanitized.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');

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
    return 'Channel name cannot contain spaces';
  }

  if (name.length > maxChannelNameLength) {
    return 'Channel name must be $maxChannelNameLength characters or less';
  }

  if (!RegExp(r'^[a-zA-Z0-9_]*$').hasMatch(name)) {
    return 'Channel name can only contain letters, numbers, and underscores';
  }

  return null;
}

/// Validates and sanitizes a user long name
/// - Max 39 bytes
/// - Printable characters only
String sanitizeLongName(String name) {
  // Remove non-printable characters
  var sanitized = name.replaceAll(RegExp(r'[^\x20-\x7E]'), '');

  // Truncate to max length (byte-aware)
  while (sanitized.length > maxLongNameLength) {
    sanitized = sanitized.substring(0, sanitized.length - 1);
  }

  return sanitized.trim();
}

/// Validates a user long name
/// Returns null if valid, error message if invalid
String? validateLongName(String name) {
  if (name.isEmpty) {
    return 'Name is required';
  }

  if (name.length > maxLongNameLength) {
    return 'Name must be $maxLongNameLength characters or less';
  }

  return null;
}

/// Validates and sanitizes a user short name
/// - Max 4 characters
/// - Uppercase alphanumeric only
String sanitizeShortName(String name) {
  // Convert to uppercase
  var sanitized = name.toUpperCase();

  // Remove non-alphanumeric characters
  sanitized = sanitized.replaceAll(RegExp(r'[^A-Z0-9]'), '');

  // Truncate to max length
  if (sanitized.length > maxShortNameLength) {
    sanitized = sanitized.substring(0, maxShortNameLength);
  }

  return sanitized;
}

/// Validates a user short name
/// Returns null if valid, error message if invalid
String? validateShortName(String name) {
  if (name.isEmpty) {
    return 'Short name is required';
  }

  if (name.length > maxShortNameLength) {
    return 'Short name must be $maxShortNameLength characters or less';
  }

  if (!RegExp(r'^[A-Z0-9]*$').hasMatch(name.toUpperCase())) {
    return 'Short name can only contain letters and numbers';
  }

  return null;
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
final List<RegExp> _blockedPatterns = [
  // socialmesh variations
  RegExp(r'^social[-_.]?mesh', caseSensitive: false),
  RegExp(r'^socialmesh', caseSensitive: false),
  // gotnull variations
  RegExp(r'^got[-_.]?null', caseSensitive: false),
  // Official/verified impersonation
  RegExp(r'[-_.]?official$', caseSensitive: false),
  RegExp(r'[-_.]?verified$', caseSensitive: false),
  RegExp(r'[-_.]?real$', caseSensitive: false),
  RegExp(r'^real[-_.]?', caseSensitive: false),
  RegExp(r'^the[-_.]?real[-_.]?', caseSensitive: false),
  RegExp(r'^official[-_.]?', caseSensitive: false),
  // Admin/mod impersonation
  RegExp(r'[-_.]?admin', caseSensitive: false),
  RegExp(r'[-_.]?mod(?:erator)?$', caseSensitive: false),
  RegExp(r'^admin[-_.]?', caseSensitive: false),
  RegExp(r'^mod[-_.]?', caseSensitive: false),
  // Support impersonation
  RegExp(r'[-_.]?support$', caseSensitive: false),
  RegExp(r'^support[-_.]?', caseSensitive: false),
  RegExp(r'[-_.]?help$', caseSensitive: false),
  RegExp(r'^help[-_.]?', caseSensitive: false),
  // Meshtastic brand
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
    return 'Display name is required';
  }

  if (trimmed.length < 2) {
    return 'Display name must be at least 2 characters';
  }

  if (trimmed.length > 30) {
    return 'Display name must be 30 characters or less';
  }

  // Only letters, numbers, periods, underscores allowed
  if (!_validUsernameChars.hasMatch(trimmed)) {
    return 'Only letters, numbers, periods and underscores (no spaces)';
  }

  // Cannot start or end with a period
  if (trimmed.startsWith('.') || trimmed.endsWith('.')) {
    return 'Display name cannot start or end with a period';
  }

  // Cannot have consecutive periods
  if (trimmed.contains('..')) {
    return 'Display name cannot have consecutive periods';
  }

  // Cannot be only numbers
  if (RegExp(r'^[0-9]+$').hasMatch(trimmed)) {
    return 'Display name cannot be only numbers';
  }

  // Check reserved/blocked names
  if (!canUseDisplayName(trimmed, userId)) {
    return 'This display name is not available';
  }

  return null;
}
