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
