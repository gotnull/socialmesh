// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:cloud_functions/cloud_functions.dart';
import 'package:socialmesh/core/logging.dart';

/// Client-side text pre-screening for profile fields before upload, with an
/// optional server check through the `checkTextContent` callable.
class ContentModerationService {
  ContentModerationService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  // ===========================================================================
  // CLIENT-SIDE TEXT PRE-SCREENING
  // ===========================================================================

  /// Pre-screen text content before uploading.
  /// This runs locally first for immediate feedback, then optionally
  /// calls the Cloud Function for more thorough analysis.
  Future<TextModerationResult> checkText(
    String text, {
    bool useServerCheck = false,
  }) async {
    // First, run local check for immediate feedback
    final localResult = _checkTextLocally(text);

    if (!localResult.passed) {
      return localResult;
    }

    // If local check passed and server check requested, validate server-side
    if (useServerCheck) {
      try {
        final result = await _functions.httpsCallable('checkTextContent').call({
          'text': text,
        });
        final data = Map<String, dynamic>.from(result.data as Map);
        return TextModerationResult(
          passed: data['passed'] as bool? ?? true,
          action: data['action'] as String? ?? 'approve',
          categories:
              (data['categories'] as List<dynamic>?)
                  ?.map(
                    (c) => ModerationCategory.fromMap(
                      Map<String, dynamic>.from(c as Map),
                    ),
                  )
                  .toList() ??
              [],
          details: data['details'] as String? ?? '',
        );
      } catch (e) {
        AppLogging.social('Server text check error: $e');
        // Fall back to local result if server check fails
        return localResult;
      }
    }

    return localResult;
  }

  /// Local text screening for immediate feedback
  TextModerationResult _checkTextLocally(String text) {
    if (text.isEmpty) {
      return TextModerationResult(
        passed: true,
        action: 'approve',
        categories: [],
        details: 'Empty text',
      );
    }

    final lowerText = text.toLowerCase();
    final flaggedCategories = <ModerationCategory>[];

    // Check for obvious violations (subset of server patterns)
    final patterns = {
      'violence': [
        RegExp(
          r'\b(kill|murder|shoot|stab|attack)\s+(you|him|her|them)',
          caseSensitive: false,
        ),
        RegExp(
          r'\b(death\s+threat|terrorist|terrorism)\b',
          caseSensitive: false,
        ),
      ],
      'hate': [
        RegExp(
          r'\b(n[i1]gg[ae3]r|f[a4]gg?[o0]t|k[i1]k[e3]|sp[i1]c|ch[i1]nk)\b',
          caseSensitive: false,
        ),
        RegExp(r'\b(heil\s+hitler|nazi|white\s+power)\b', caseSensitive: false),
      ],
      'illegal': [
        RegExp(
          r'\b(buy|sell|trade)\s+(drugs?|cocaine|heroin|meth|guns?|weapons?)\b',
          caseSensitive: false,
        ),
        RegExp(
          r'\b(h[i1]t\s*man|assassin\s+for\s+hire)\b',
          caseSensitive: false,
        ),
      ],
      'sexual': [
        RegExp(
          r'\b(child|underage|minor)\s+(porn|exploitation|abuse)\b',
          caseSensitive: false,
        ),
        RegExp(r'\bcp\b.*\b(trade|sell|buy)\b', caseSensitive: false),
      ],
    };

    for (final entry in patterns.entries) {
      for (final pattern in entry.value) {
        if (pattern.hasMatch(lowerText)) {
          flaggedCategories.add(
            ModerationCategory(
              name: entry.key,
              likelihood: 'VERY_LIKELY',
              score: 1.0,
            ),
          );
          break; // One match per category is enough
        }
      }
    }

    // Critical categories that should block immediately
    final criticalCategories = {'violence', 'hate', 'illegal', 'sexual'};
    final hasCritical = flaggedCategories.any(
      (c) => criticalCategories.contains(c.name) && c.score >= 0.9,
    );

    return TextModerationResult(
      passed: !hasCritical,
      action: hasCritical
          ? 'reject'
          : (flaggedCategories.isNotEmpty ? 'review' : 'approve'),
      categories: flaggedCategories,
      details: flaggedCategories.isNotEmpty
          ? 'Flagged: ${flaggedCategories.map((c) => c.name).join(', ')}' // lint-allow: hardcoded-string
          : 'Text passed local moderation',
    );
  }
}

/// Result of text content moderation
class TextModerationResult {
  const TextModerationResult({
    required this.passed,
    required this.action,
    required this.categories,
    required this.details,
  });

  final bool passed;
  final String action; // 'approve', 'flag', 'review', 'reject'
  final List<ModerationCategory> categories;
  final String details;
}

/// A flagged content category
class ModerationCategory {
  const ModerationCategory({
    required this.name,
    required this.likelihood,
    required this.score,
  });

  factory ModerationCategory.fromMap(Map<String, dynamic> map) {
    return ModerationCategory(
      name: map['name'] as String,
      likelihood: map['likelihood'] as String,
      score: (map['score'] as num).toDouble(),
    );
  }

  final String name;
  final String likelihood;
  final double score;
}
