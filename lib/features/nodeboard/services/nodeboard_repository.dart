// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Coordinates API + cache for NodeBoard data.
// Implements stale-while-revalidate: returns cached data quickly,
// background-fetches fresh data, and updates cache on success.

import '../../../core/logging.dart';
import '../models/nodeboard.dart';
import '../models/nodeboard_enums.dart';
import '../models/nodeboard_reply.dart';
import '../models/nodeboard_section.dart';
import '../models/nodeboard_summary.dart';
import '../models/nodeboard_theme.dart';
import '../models/nodeboard_thread.dart';
import 'nodeboard_api_service.dart';
import 'nodeboard_cache_service.dart';

class NodeBoardRepository {
  final NodeBoardApiService _api;
  final NodeBoardCacheService _cache;

  NodeBoardRepository({required this._api, required this._cache});

  // -------------------------------------------------------------------------
  // Board reads
  // -------------------------------------------------------------------------

  Future<NodeBoard?> getBoardBySlug(String slug) async {
    AppLogging.nodeBoard('Repo getBoardBySlug: slug=$slug');
    try {
      final board = await _api.getBoardBySlug(slug);
      AppLogging.nodeBoard(
        'Repo getBoardBySlug: ${board != null ? '✅ found' : 'null (not found)'}',
      );
      return board;
    } catch (e) {
      AppLogging.nodeBoard('Repo getBoardBySlug: ❌ $e');
      return null;
    }
  }

  Future<NodeBoardSummary?> getBoardSummaryBySlug(String slug) async {
    AppLogging.nodeBoard('Repo getBoardSummaryBySlug: slug=$slug');
    // Return cache first if available
    final cached = await _cache.getCachedBoardSummary(slug);
    try {
      final fresh = await _api.getBoardSummaryBySlug(slug);
      if (fresh != null) {
        await _cache.cacheBoardSummary(fresh);
      }
      AppLogging.nodeBoard(
        'Repo getBoardSummaryBySlug: ✅ fresh=${fresh != null} cached=${cached != null}',
      );
      return fresh ?? cached;
    } catch (e) {
      AppLogging.nodeBoard(
        'Repo getBoardSummaryBySlug: ❌ API failed, returning cached=${cached != null}',
      );
      return cached;
    }
  }

  Future<NodeBoardSummary?> getBoardSummaryByNodeId(String nodeId) async {
    AppLogging.nodeBoard('Repo getBoardSummaryByNodeId: nodeId=$nodeId');
    try {
      final summary = await _api.getBoardSummaryByNodeId(nodeId);
      AppLogging.nodeBoard(
        'Repo getBoardSummaryByNodeId: ${summary != null ? '✅ found' : 'null'}',
      );
      return summary;
    } catch (e) {
      AppLogging.nodeBoard('Repo getBoardSummaryByNodeId: ❌ $e');
      return null;
    }
  }

  Future<List<NodeBoardSummary>> getMyBoards(String userId) async {
    AppLogging.nodeBoard('Repo getMyBoards: userId=$userId');
    final cached = await _cache.getCachedBoardSummaries();
    try {
      final fresh = await _api.getBoardsByUserId(userId);
      await _cache.cacheBoardSummaries(fresh);
      AppLogging.nodeBoard(
        'Repo getMyBoards: ✅ ${fresh.length} boards from API',
      );
      return fresh;
    } catch (e) {
      AppLogging.nodeBoard(
        'Repo getMyBoards: ❌ API failed, returning ${cached.length} cached',
      );
      return cached;
    }
  }

  Future<({List<NodeBoardSummary> boards, String? nextCursor, bool hasMore})>
  discoverBoards({int limit = 25, String? cursor}) async {
    AppLogging.nodeBoard('Repo discoverBoards: limit=$limit cursor=$cursor');
    try {
      final result = await _api.discoverBoards(limit: limit, cursor: cursor);
      await _cache.cacheBoardSummaries(result.boards);
      AppLogging.nodeBoard(
        'Repo discoverBoards: ✅ ${result.boards.length} boards',
      );
      return result;
    } catch (e) {
      AppLogging.nodeBoard('Repo discoverBoards: ❌ API failed');
      final cached = await _cache.getCachedBoardSummaries();
      AppLogging.nodeBoard(
        'Repo discoverBoards: returning ${cached.length} cached',
      );
      return (boards: cached, nextCursor: null, hasMore: false);
    }
  }

  // -------------------------------------------------------------------------
  // Board writes
  // -------------------------------------------------------------------------

  Future<NodeBoard> createBoard({
    required String slug,
    required String title,
    required String sysopName,
    String? tagline,
    String? description,
    BoardVisibility? visibility,
    String? themeId,
    String? welcomeText,
    String? ansiSplash,
    bool? isListedInNodeDex,
    bool? isGuestPostingAllowed,
    String? ownerNodeId,
    List<Map<String, String>>? defaultSections,
  }) async {
    AppLogging.nodeBoard('Repo createBoard: slug=$slug title=$title');
    return _api.createBoard(
      slug: slug,
      title: title,
      sysopName: sysopName,
      tagline: tagline,
      description: description,
      visibility: visibility,
      themeId: themeId,
      welcomeText: welcomeText,
      ansiSplash: ansiSplash,
      isListedInNodeDex: isListedInNodeDex,
      isGuestPostingAllowed: isGuestPostingAllowed,
      ownerNodeId: ownerNodeId,
      defaultSections: defaultSections,
    );
  }

  Future<NodeBoard> updateBoard(String boardId, Map<String, dynamic> updates) {
    AppLogging.nodeBoard('Repo updateBoard: boardId=$boardId');
    return _api.updateBoard(boardId, updates);
  }

  // -------------------------------------------------------------------------
  // Sections
  // -------------------------------------------------------------------------

  Future<List<NodeBoardSection>> getSections(String slug) async {
    AppLogging.nodeBoard('Repo getSections: slug=$slug');
    try {
      final sections = await _api.getSections(slug);
      AppLogging.nodeBoard('Repo getSections: ✅ ${sections.length} sections');
      return sections;
    } catch (e) {
      AppLogging.nodeBoard('Repo getSections: ❌ $e');
      return [];
    }
  }

  Future<NodeBoardSection> createSection(
    String boardId,
    Map<String, dynamic> input,
  ) {
    AppLogging.nodeBoard('Repo createSection: boardId=$boardId');
    return _api.createSection(boardId, input);
  }

  // -------------------------------------------------------------------------
  // Threads
  // -------------------------------------------------------------------------

  Future<({List<NodeBoardThread> threads, String? nextCursor, bool hasMore})>
  getThreads(
    String slug,
    String boardId,
    String sectionId, {
    int limit = 25,
    String? cursor,
  }) async {
    AppLogging.nodeBoard(
      'Repo getThreads: slug=$slug boardId=$boardId sectionId=$sectionId',
    );
    // Return cached threads on error
    try {
      final result = await _api.getThreads(
        slug,
        sectionId,
        limit: limit,
        cursor: cursor,
      );
      await _cache.cacheThreads(boardId, sectionId, result.threads);
      AppLogging.nodeBoard(
        'Repo getThreads: ✅ ${result.threads.length} threads from API',
      );
      return result;
    } catch (e) {
      AppLogging.nodeBoard('Repo getThreads: ❌ API failed');
      final cached = await _cache.getCachedThreads(sectionId);
      AppLogging.nodeBoard(
        'Repo getThreads: returning ${cached.length} cached',
      );
      return (threads: cached, nextCursor: null, hasMore: false);
    }
  }

  Future<
    ({
      NodeBoardThread thread,
      List<NodeBoardReply> replies,
      String? nextCursor,
      bool hasMore,
    })
  >
  getThreadDetail(String slug, String threadId, {String? cursor}) {
    AppLogging.nodeBoard('Repo getThreadDetail: slug=$slug threadId=$threadId');
    return _api.getThreadDetail(slug, threadId, cursor: cursor);
  }

  Future<NodeBoardThread> createThread(
    String slug,
    Map<String, dynamic> input,
  ) {
    AppLogging.nodeBoard('Repo createThread: slug=$slug');
    return _api.createThread(slug, input);
  }

  // -------------------------------------------------------------------------
  // Replies
  // -------------------------------------------------------------------------

  Future<NodeBoardReply> createReply(
    String slug,
    String threadId,
    Map<String, dynamic> input,
  ) {
    AppLogging.nodeBoard('Repo createReply: slug=$slug threadId=$threadId');
    return _api.createReply(slug, threadId, input);
  }

  // -------------------------------------------------------------------------
  // Moderation
  // -------------------------------------------------------------------------

  Future<void> pinThread(String boardId, String threadId, {bool pin = true}) {
    AppLogging.nodeBoard(
      'Repo mod pinThread: boardId=$boardId threadId=$threadId pin=$pin',
    );
    return _api.pinThread(boardId, threadId, pin: pin);
  }

  Future<void> lockThread(String boardId, String threadId, {bool lock = true}) {
    AppLogging.nodeBoard(
      'Repo mod lockThread: boardId=$boardId threadId=$threadId lock=$lock',
    );
    return _api.lockThread(boardId, threadId, lock: lock);
  }

  Future<void> deleteThread(String boardId, String threadId, {String? reason}) {
    AppLogging.nodeBoard(
      'Repo mod deleteThread: boardId=$boardId threadId=$threadId',
    );
    return _api.deleteThread(boardId, threadId, reason: reason);
  }

  Future<void> deleteReply(String boardId, String replyId, {String? reason}) {
    AppLogging.nodeBoard(
      'Repo mod deleteReply: boardId=$boardId replyId=$replyId',
    );
    return _api.deleteReply(boardId, replyId, reason: reason);
  }

  Future<void> lockSection(
    String boardId,
    String sectionId, {
    bool lock = true,
  }) {
    AppLogging.nodeBoard(
      'Repo mod lockSection: boardId=$boardId sectionId=$sectionId lock=$lock',
    );
    return _api.lockSection(boardId, sectionId, lock: lock);
  }

  // -------------------------------------------------------------------------
  // Read state
  // -------------------------------------------------------------------------

  Future<void> markBoardViewed(String slug) {
    AppLogging.nodeBoard('Repo markBoardViewed: slug=$slug');
    return _api.markBoardViewed(slug);
  }

  // -------------------------------------------------------------------------
  // Search
  // -------------------------------------------------------------------------

  Future<({List<Map<String, dynamic>> results, int total})> searchThreads(
    String slug,
    String query, {
    int limit = 25,
    int offset = 0,
  }) {
    AppLogging.nodeBoard('Repo search: slug=$slug q=$query limit=$limit');
    return _api.searchThreads(slug, query, limit: limit, offset: offset);
  }

  // -------------------------------------------------------------------------
  // Themes
  // -------------------------------------------------------------------------

  Future<List<NodeBoardTheme>> getThemes() {
    AppLogging.nodeBoard('Repo getThemes');
    return _api.getThemes();
  }
}
