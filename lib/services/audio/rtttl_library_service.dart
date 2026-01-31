// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:flutter/services.dart';

/// Represents an RTTTL ringtone from the library
class RtttlLibraryItem {
  /// Display name (cleaned up, no extension)
  final String displayName;

  /// The tone name extracted from RTTTL (before first colon)
  final String toneName;

  /// Artist/source if available (parsed from filename)
  final String? artist;

  /// Full RTTTL string
  final String rtttl;

  /// Original filename (internal use)
  final String filename;

  /// Whether this is a built-in preset
  final bool isBuiltin;

  const RtttlLibraryItem({
    required this.displayName,
    required this.toneName,
    this.artist,
    required this.rtttl,
    required this.filename,
    this.isBuiltin = false,
  });

  /// Create from JSON map
  factory RtttlLibraryItem.fromJson(Map<String, dynamic> json) {
    return RtttlLibraryItem(
      displayName: json['displayName'] as String? ?? '',
      toneName: json['toneName'] as String? ?? '',
      artist: json['artist'] as String?,
      rtttl: json['rtttl'] as String? ?? '',
      filename: json['filename'] as String? ?? '',
      isBuiltin: json['builtin'] as bool? ?? false,
    );
  }

  /// Get a formatted title for display
  String get formattedTitle {
    // Always prefer displayName if it's meaningful (not empty and not just a number)
    if (displayName.isNotEmpty && !_isNumericOnly(displayName)) {
      return displayName;
    }
    // Fall back to formatted toneName, but only if it's meaningful
    if (toneName.isNotEmpty && !_isNumericOnly(toneName)) {
      return _formatToneName(toneName);
    }
    // Last resort: use whatever we have
    return displayName.isNotEmpty ? displayName : toneName;
  }

  static bool _isNumericOnly(String s) {
    return RegExp(r'^\d+$').hasMatch(s);
  }

  /// Get subtitle (artist or tone name if different from title)
  String? get subtitle {
    if (artist != null && artist!.isNotEmpty) {
      return artist;
    }
    return null;
  }

  static String _formatToneName(String name) {
    // Clean up common RTTTL tone name patterns
    return name.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

/// Service for loading and searching RTTTL tones from the JSON library
class RtttlLibraryService {
  static const _jsonPath = 'assets/rtttl_library.json';
  static const int maxRtttlLength = 230;

  List<RtttlLibraryItem>? _cachedTones;
  bool _loaded = false;

  /// Load the library from JSON
  Future<void> _ensureLoaded() async {
    if (_loaded) return;

    try {
      final jsonString = await rootBundle.loadString(_jsonPath);
      final data = json.decode(jsonString) as Map<String, dynamic>;

      final tonesList = data['tones'] as List<dynamic>? ?? [];
      _cachedTones = tonesList
          .map((t) => RtttlLibraryItem.fromJson(t as Map<String, dynamic>))
          .toList();

      _loaded = true;
    } catch (e) {
      _cachedTones = [];
      _loaded = true;
    }
  }

  /// Get all tones in the library (filtered to compatible length)
  Future<List<RtttlLibraryItem>> getAllTones() async {
    await _ensureLoaded();
    return (_cachedTones ?? [])
        .where((t) => t.rtttl.length <= maxRtttlLength)
        .toList();
  }

  /// Get the total count of compatible tones in the library
  Future<int> getToneCount() async {
    await _ensureLoaded();
    return (_cachedTones ?? [])
        .where((t) => t.rtttl.length <= maxRtttlLength)
        .length;
  }

  /// Get only built-in tones
  Future<List<RtttlLibraryItem>> getBuiltinTones() async {
    await _ensureLoaded();
    return (_cachedTones ?? [])
        .where((t) => t.isBuiltin && t.rtttl.length <= maxRtttlLength)
        .toList();
  }

  /// Search for RTTTL tones by query (only compatible length)
  /// Searches display name, artist, and tone name
  Future<List<RtttlLibraryItem>> search(String query, {int limit = 50}) async {
    if (query.trim().isEmpty) return [];

    await _ensureLoaded();
    final tones = (_cachedTones ?? []).where(
      (t) => t.rtttl.length <= maxRtttlLength,
    );
    final queryLower = query.toLowerCase();

    // Score-based results for better relevance
    final scoredResults = <(RtttlLibraryItem, int)>[];

    for (final item in tones) {
      // Calculate relevance score
      int score = 0;
      final displayLower = item.displayName.toLowerCase();
      final toneLower = item.toneName.toLowerCase();
      final artistLower = (item.artist ?? '').toLowerCase();

      // Exact match in display name (highest priority)
      if (displayLower == queryLower) {
        score = 100;
      }
      // Starts with query
      else if (displayLower.startsWith(queryLower)) {
        score = 80;
      }
      // Contains query in display name
      else if (displayLower.contains(queryLower)) {
        score = 60;
      }
      // Match in artist
      else if (artistLower.contains(queryLower)) {
        score = 50;
      }
      // Match in tone name
      else if (toneLower.contains(queryLower)) {
        score = 40;
      }

      if (score > 0) {
        // Boost built-in tones slightly
        if (item.isBuiltin) score += 5;
        scoredResults.add((item, score));
      }
    }

    // Sort by score (descending) then by name
    scoredResults.sort((a, b) {
      final scoreCompare = b.$2.compareTo(a.$2);
      if (scoreCompare != 0) return scoreCompare;
      return a.$1.displayName.compareTo(b.$1.displayName);
    });

    // Take top results
    return scoredResults.take(limit).map((r) => r.$1).toList();
  }

  /// Get popular/suggested RTTTL items (built-ins first, then some popular ones)
  Future<List<RtttlLibraryItem>> getSuggestions() async {
    await _ensureLoaded();
    final compatibleTones = (_cachedTones ?? []).where(
      (t) => t.rtttl.length <= maxRtttlLength,
    );

    // Return built-in tones as suggestions
    final builtins = compatibleTones.where((t) => t.isBuiltin).toList();

    // Add some popular non-builtin tones
    final popularNames = {
      'star wars',
      'mission impossible',
      'pink panther',
      'indiana jones',
      'tetris',
      'simpsons',
      'knight rider',
      'ghostbusters',
    };

    final popular = compatibleTones
        .where(
          (t) =>
              !t.isBuiltin &&
              popularNames.any(
                (name) =>
                    t.displayName.toLowerCase().contains(name) ||
                    (t.artist?.toLowerCase().contains(name) ?? false),
              ),
        )
        .take(10)
        .toList();

    return [...builtins, ...popular];
  }

  /// Get a random selection of RTTTL items for discovery
  Future<List<RtttlLibraryItem>> getRandomSelection({int count = 20}) async {
    await _ensureLoaded();
    final compatibleTones = (_cachedTones ?? [])
        .where((t) => t.rtttl.length <= maxRtttlLength)
        .toList();
    if (compatibleTones.isEmpty) return [];

    // Shuffle and take a sample (excluding built-ins for variety)
    final nonBuiltins = compatibleTones.where((t) => !t.isBuiltin).toList()
      ..shuffle();
    return nonBuiltins.take(count).toList();
  }

  /// Get total count of available tones
  Future<int> getTotalCount() async {
    await _ensureLoaded();
    return _cachedTones?.length ?? 0;
  }

  /// Get count of built-in tones
  Future<int> getBuiltinCount() async {
    await _ensureLoaded();
    return (_cachedTones ?? []).where((t) => t.isBuiltin).length;
  }

  /// Clear the cache and force reload
  void clearCache() {
    _cachedTones = null;
    _loaded = false;
  }
}
