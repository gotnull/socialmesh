// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/help/help_article.dart';
import '../core/logging.dart';

/// Loads the article manifest and returns all articles sorted by category + order.
final helpArticlesProvider = FutureProvider<List<HelpArticle>>((ref) async {
  try {
    final jsonString = await rootBundle.loadString('assets/help/manifest.json');
    final data = json.decode(jsonString) as Map<String, dynamic>;
    final list = data['articles'] as List<dynamic>;

    final articles =
        list.map((item) {
          return HelpArticle.fromJson(item as Map<String, dynamic>);
        }).toList()..sort((a, b) {
          final catCmp = a.category.index.compareTo(b.category.index);
          if (catCmp != 0) return catCmp;
          return a.order.compareTo(b.order);
        });

    AppLogging.app('HelpArticles: Loaded ${articles.length} articles');
    return articles;
  } catch (e) {
    AppLogging.app('HelpArticles: Failed to load manifest: $e');
    return [];
  }
});

/// Loads the raw markdown content for a single article.
final helpArticleContentProvider = FutureProvider.family<String, String>((
  ref,
  filePath,
) async {
  try {
    return await rootBundle.loadString(filePath);
  } catch (e) {
    AppLogging.app('HelpArticles: Failed to load article $filePath: $e');
    return '# Error\n\nThis article could not be loaded.';
  }
});

/// State for tracking which articles the user has read.
class HelpArticleReadState {
  final Set<String> readArticleIds;

  const HelpArticleReadState({this.readArticleIds = const {}});

  bool isRead(String articleId) => readArticleIds.contains(articleId);

  int readCount(List<HelpArticle> articles) {
    return articles.where((a) => readArticleIds.contains(a.id)).length;
  }

  HelpArticleReadState copyWith({Set<String>? readArticleIds}) {
    return HelpArticleReadState(
      readArticleIds: readArticleIds ?? this.readArticleIds,
    );
  }
}

/// Notifier for managing article read state (persisted via SharedPreferences).
class HelpArticleReadNotifier extends Notifier<HelpArticleReadState> {
  static const String _prefKey = 'help_read_articles';

  @override
  HelpArticleReadState build() {
    _loadFromPreferences();
    return const HelpArticleReadState();
  }

  Future<void> _loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readIds = prefs.getStringList(_prefKey) ?? [];
      state = HelpArticleReadState(readArticleIds: readIds.toSet());
    } catch (e) {
      AppLogging.app('HelpArticleRead: Failed to load preferences: $e');
    }
  }

  Future<void> _saveToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefKey, state.readArticleIds.toList());
    } catch (e) {
      AppLogging.app('HelpArticleRead: Failed to save preferences: $e');
    }
  }

  /// Mark an article as read.
  void markRead(String articleId) {
    if (state.isRead(articleId)) return;
    state = state.copyWith(
      readArticleIds: {...state.readArticleIds, articleId},
    );
    _saveToPreferences();
  }

  /// Reset all read state.
  void resetAll() {
    state = const HelpArticleReadState();
    _saveToPreferences();
  }
}

final helpArticleReadProvider =
    NotifierProvider<HelpArticleReadNotifier, HelpArticleReadState>(
      HelpArticleReadNotifier.new,
    );
