// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'package:flutter/services.dart';

/// Client-side profanity checker using banned_words.json
/// This is a FAST pre-check before server validation
class ProfanityChecker {
  static ProfanityChecker? _instance;
  Map<String, List<RegExp>>? _patterns;
  Map<String, String>? _severities;
  bool _isLoaded = false;

  ProfanityChecker._();

  static ProfanityChecker get instance {
    _instance ??= ProfanityChecker._();
    return _instance!;
  }

  /// Load banned words from assets
  Future<void> load() async {
    if (_isLoaded) return;

    try {
      final jsonString = await rootBundle.loadString(
        'assets/banned_words.json',
      );
      final data = json.decode(jsonString) as Map<String, dynamic>;
      final categories = data['categories'] as Map<String, dynamic>;

      _patterns = {};
      _severities = {};

      for (final entry in categories.entries) {
        final category = entry.key;
        final config = entry.value as Map<String, dynamic>;
        final severity = config['severity'] as String;
        final words = (config['words'] as List).cast<String>();
        final patterns = (config['patterns'] as List).cast<String>();

        _severities![category] = severity;

        final categoryPatterns = <RegExp>[];

        // Convert simple words to regex with word boundaries
        for (final word in words) {
          final escaped = RegExp.escape(word);
          categoryPatterns.add(RegExp('\\b$escaped\\b', caseSensitive: false));
        }

        // Add complex patterns
        for (final pattern in patterns) {
          try {
            categoryPatterns.add(RegExp(pattern, caseSensitive: false));
          } catch (e) {
            // Skip invalid patterns
          }
        }

        _patterns![category] = categoryPatterns;
      }

      _isLoaded = true;
    } catch (e) {
      // If load fails, still mark as loaded to avoid repeated attempts
      _isLoaded = true;
      _patterns = {};
      _severities = {};
    }
  }

  /// Check text for profanity
  /// Returns null if clean, error message if contains profanity
  String? check(String text) {
    if (!_isLoaded || _patterns == null || _severities == null) {
      return null; // Not loaded yet, allow through
    }

    if (text.trim().isEmpty) return null;

    final flaggedCategories = <String>[];
    var highestSeverity = '';

    for (final entry in _patterns!.entries) {
      final category = entry.key;
      final patterns = entry.value;

      for (final pattern in patterns) {
        if (pattern.hasMatch(text)) {
          flaggedCategories.add(category);
          final severity = _severities![category] ?? 'low';
          if (_compareSeverity(severity, highestSeverity) > 0) {
            highestSeverity = severity;
          }
          break; // Only one match per category needed
        }
      }
    }

    if (flaggedCategories.isEmpty) return null;

    // Critical and high severity = reject immediately
    if (highestSeverity == 'critical' || highestSeverity == 'high') {
      return 'Contains inappropriate content';
    }

    return null; // Medium/low severity passes client check, server will review
  }

  int _compareSeverity(String a, String b) {
    const order = {'low': 1, 'medium': 2, 'high': 3, 'critical': 4};
    return (order[a] ?? 0) - (order[b] ?? 0);
  }

  /// Check if text contains critical profanity (should be rejected)
  bool containsCriticalProfanity(String text) {
    return check(text) != null;
  }
}
