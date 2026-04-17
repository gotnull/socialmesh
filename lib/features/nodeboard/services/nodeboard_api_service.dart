// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// HTTP client for the NodeBoard REST API.

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants.dart';
import '../../../core/logging.dart';
import '../models/nodeboard.dart';
import '../models/nodeboard_enums.dart';
import '../models/nodeboard_reply.dart';
import '../models/nodeboard_section.dart';
import '../models/nodeboard_summary.dart';
import '../models/nodeboard_theme.dart';
import '../models/nodeboard_thread.dart';

class NodeBoardApiService {
  final http.Client _client;
  final Future<String?> Function() _getIdToken;

  NodeBoardApiService({
    http.Client? client,
    required Future<String?> Function() getIdToken,
  }) : _client = client ?? http.Client(),
       _getIdToken = getIdToken;

  String get _baseUrl => AppUrls.nodeBoardApiUrl;

  /// Every request is bounded by this timeout. Offline or flaky mesh
  /// gateways otherwise hang requests until the underlying socket aborts,
  /// which can stall the UI for the OS TCP timeout window.
  static const Duration _httpTimeout = Duration(seconds: 15);

  Future<http.Response> _get(Uri url, {Map<String, String>? headers}) =>
      _client.get(url, headers: headers).timeout(_httpTimeout);

  Future<http.Response> _post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) => _client.post(url, headers: headers, body: body).timeout(_httpTimeout);

  Future<http.Response> _patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) => _client.patch(url, headers: headers, body: body).timeout(_httpTimeout);

  Future<Map<String, String>> _writeHeaders() async {
    final token = await _getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, String>> _readHeaders() async {
    final token = await _getIdToken();
    return {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // -------------------------------------------------------------------------
  // Board endpoints
  // -------------------------------------------------------------------------

  Future<NodeBoard?> getBoardBySlug(String slug) async {
    AppLogging.nodeBoard('API getBoardBySlug: slug=$slug');
    final headers = await _readHeaders();
    final response = await _get(
      Uri.parse('$_baseUrl/api/boards/$slug'),
      headers: headers,
    );
    if (response.statusCode == 404) {
      AppLogging.nodeBoard('API getBoardBySlug: 404 not found');
      return null;
    }
    _checkResponse(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final board = NodeBoard.fromJson(json['board'] as Map<String, dynamic>);
    AppLogging.nodeBoard('API getBoardBySlug: ✅ board=${board.id}');
    return board;
  }

  Future<NodeBoardSummary?> getBoardSummaryBySlug(String slug) async {
    AppLogging.nodeBoard('API getBoardSummaryBySlug: slug=$slug');
    final response = await _get(
      Uri.parse('$_baseUrl/api/boards/$slug/summary'),
    );
    if (response.statusCode == 404) {
      AppLogging.nodeBoard('API getBoardSummaryBySlug: 404 not found');
      return null;
    }
    _checkResponse(response);
    final summary = NodeBoardSummary.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    AppLogging.nodeBoard('API getBoardSummaryBySlug: ✅ slug=${summary.slug}');
    return summary;
  }

  Future<NodeBoardSummary?> getBoardSummaryByNodeId(String nodeId) async {
    AppLogging.nodeBoard('API getBoardSummaryByNodeId: nodeId=$nodeId');
    final response = await _get(
      Uri.parse('$_baseUrl/api/boards/by-node/$nodeId/summary'),
    );
    if (response.statusCode == 404) {
      AppLogging.nodeBoard('API getBoardSummaryByNodeId: 404 not found');
      return null;
    }
    _checkResponse(response);
    final summary = NodeBoardSummary.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    AppLogging.nodeBoard('API getBoardSummaryByNodeId: ✅ slug=${summary.slug}');
    return summary;
  }

  Future<List<NodeBoardSummary>> getBoardsByUserId(String userId) async {
    AppLogging.nodeBoard('API getBoardsByUserId: userId=$userId');
    final headers = await _readHeaders();
    final response = await _get(
      Uri.parse('$_baseUrl/api/boards/by-user/$userId'),
      headers: headers,
    );
    _checkResponse(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final list = json['boards'] as List<dynamic>;
    final boards = list
        .map((e) => NodeBoardSummary.fromJson(e as Map<String, dynamic>))
        .toList();
    AppLogging.nodeBoard('API getBoardsByUserId: ✅ ${boards.length} boards');
    return boards;
  }

  Future<({List<NodeBoardSummary> boards, String? nextCursor, bool hasMore})>
  discoverBoards({int limit = 25, String? cursor}) async {
    AppLogging.nodeBoard('API discoverBoards: limit=$limit cursor=$cursor');
    final params = <String, String>{'limit': '$limit'};
    if (cursor != null) params['cursor'] = cursor;

    final response = await _get(
      Uri.parse('$_baseUrl/api/boards').replace(queryParameters: params),
    );
    _checkResponse(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'] as List<dynamic>;
    final cursorObj = json['cursor'] as Map<String, dynamic>;

    final boards = data
        .map((e) => NodeBoardSummary.fromJson(e as Map<String, dynamic>))
        .toList();
    AppLogging.nodeBoard(
      'API discoverBoards: ✅ ${boards.length} boards hasMore=${cursorObj['hasMore']}',
    );
    return (
      boards: boards,
      nextCursor: cursorObj['next'] as String?,
      hasMore: cursorObj['hasMore'] as bool,
    );
  }

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
    final headers = await _writeHeaders();
    final body = <String, dynamic>{
      'slug': slug,
      'title': title,
      'sysopName': sysopName,
      if (tagline != null) 'tagline': tagline,
      if (description != null) 'description': description,
      if (visibility != null) 'visibility': visibility.toJson(),
      if (themeId != null) 'themeId': themeId,
      if (welcomeText != null) 'welcomeText': welcomeText,
      if (ansiSplash != null) 'ansiSplash': ansiSplash,
      if (isListedInNodeDex != null) 'isListedInNodeDex': isListedInNodeDex,
      if (isGuestPostingAllowed != null)
        'isGuestPostingAllowed': isGuestPostingAllowed,
      if (ownerNodeId != null) 'ownerNodeId': ownerNodeId,
      if (defaultSections != null) 'defaultSections': defaultSections,
    };

    AppLogging.nodeBoard('API createBoard: slug=$slug title=$title');
    final response = await _post(
      Uri.parse('$_baseUrl/api/boards'),
      headers: headers,
      body: jsonEncode(body),
    );
    _checkResponse(response);
    final board = NodeBoard.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    AppLogging.nodeBoard('API createBoard: ✅ id=${board.id}');
    return board;
  }

  Future<NodeBoard> updateBoard(
    String boardId,
    Map<String, dynamic> updates,
  ) async {
    AppLogging.nodeBoard(
      'API updateBoard: boardId=$boardId keys=${updates.keys.toList()}',
    );
    final headers = await _writeHeaders();
    final response = await _patch(
      Uri.parse('$_baseUrl/api/boards/$boardId'),
      headers: headers,
      body: jsonEncode(updates),
    );
    _checkResponse(response);
    final board = NodeBoard.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    AppLogging.nodeBoard('API updateBoard: ✅ id=${board.id}');
    return board;
  }

  // -------------------------------------------------------------------------
  // Section endpoints
  // -------------------------------------------------------------------------

  Future<List<NodeBoardSection>> getSections(String slug) async {
    AppLogging.nodeBoard('API getSections: slug=$slug');
    final headers = await _readHeaders();
    final response = await _get(
      Uri.parse('$_baseUrl/api/boards/$slug/sections'),
      headers: headers,
    );
    _checkResponse(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final list = json['sections'] as List<dynamic>;
    final sections = list
        .map((e) => NodeBoardSection.fromJson(e as Map<String, dynamic>))
        .toList();
    AppLogging.nodeBoard('API getSections: ✅ ${sections.length} sections');
    return sections;
  }

  Future<NodeBoardSection> createSection(
    String boardId,
    Map<String, dynamic> input,
  ) async {
    AppLogging.nodeBoard('API createSection: boardId=$boardId input=$input');
    final headers = await _writeHeaders();
    final response = await _post(
      Uri.parse('$_baseUrl/api/boards/$boardId/sections'),
      headers: headers,
      body: jsonEncode(input),
    );
    _checkResponse(response);
    final section = NodeBoardSection.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    AppLogging.nodeBoard('API createSection: ✅ id=${section.id}');
    return section;
  }

  // -------------------------------------------------------------------------
  // Thread endpoints
  // -------------------------------------------------------------------------

  Future<({List<NodeBoardThread> threads, String? nextCursor, bool hasMore})>
  getThreads(
    String slug,
    String sectionId, {
    int limit = 25,
    String? cursor,
  }) async {
    AppLogging.nodeBoard(
      'API getThreads: slug=$slug sectionId=$sectionId limit=$limit cursor=$cursor',
    );
    final headers = await _readHeaders();
    final params = <String, String>{'limit': '$limit'};
    if (cursor != null) params['cursor'] = cursor;

    final response = await _get(
      Uri.parse(
        '$_baseUrl/api/boards/$slug/sections/$sectionId/threads',
      ).replace(queryParameters: params),
      headers: headers,
    );
    _checkResponse(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'] as List<dynamic>;
    final cursorObj = json['cursor'] as Map<String, dynamic>;

    final threads = data
        .map((e) => NodeBoardThread.fromJson(e as Map<String, dynamic>))
        .toList();
    AppLogging.nodeBoard(
      'API getThreads: ✅ ${threads.length} threads hasMore=${cursorObj['hasMore']}',
    );
    return (
      threads: threads,
      nextCursor: cursorObj['next'] as String?,
      hasMore: cursorObj['hasMore'] as bool,
    );
  }

  Future<
    ({
      NodeBoardThread thread,
      List<NodeBoardReply> replies,
      String? nextCursor,
      bool hasMore,
    })
  >
  getThreadDetail(String slug, String threadId, {String? cursor}) async {
    AppLogging.nodeBoard(
      'API getThreadDetail: slug=$slug threadId=$threadId cursor=$cursor',
    );
    final headers = await _readHeaders();
    final params = <String, String>{};
    if (cursor != null) params['cursor'] = cursor;

    final uri = Uri.parse('$_baseUrl/api/boards/$slug/threads/$threadId');
    final response = await _get(
      params.isNotEmpty ? uri.replace(queryParameters: params) : uri,
      headers: headers,
    );
    _checkResponse(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;

    final thread = NodeBoardThread.fromJson(
      json['thread'] as Map<String, dynamic>,
    );
    final repliesObj = json['replies'] as Map<String, dynamic>;
    final repliesData = repliesObj['data'] as List<dynamic>;
    final cursorObj = repliesObj['cursor'] as Map<String, dynamic>;

    final replies = repliesData
        .map((e) => NodeBoardReply.fromJson(e as Map<String, dynamic>))
        .toList();
    AppLogging.nodeBoard(
      'API getThreadDetail: ✅ thread=${thread.id} ${replies.length} replies',
    );
    return (
      thread: thread,
      replies: replies,
      nextCursor: cursorObj['next'] as String?,
      hasMore: cursorObj['hasMore'] as bool,
    );
  }

  Future<NodeBoardThread> createThread(
    String slug,
    Map<String, dynamic> input,
  ) async {
    AppLogging.nodeBoard(
      'API createThread: slug=$slug sectionId=${input['sectionId']}',
    );
    final headers = await _writeHeaders();
    final response = await _post(
      Uri.parse('$_baseUrl/api/boards/$slug/threads'),
      headers: headers,
      body: jsonEncode(input),
    );
    _checkResponse(response);
    final thread = NodeBoardThread.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    AppLogging.nodeBoard('API createThread: ✅ id=${thread.id}');
    return thread;
  }

  // -------------------------------------------------------------------------
  // Reply endpoints
  // -------------------------------------------------------------------------

  Future<NodeBoardReply> createReply(
    String slug,
    String threadId,
    Map<String, dynamic> input,
  ) async {
    AppLogging.nodeBoard('API createReply: slug=$slug threadId=$threadId');
    final headers = await _writeHeaders();
    final response = await _post(
      Uri.parse('$_baseUrl/api/boards/$slug/threads/$threadId/replies'),
      headers: headers,
      body: jsonEncode(input),
    );
    _checkResponse(response);
    final reply = NodeBoardReply.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    AppLogging.nodeBoard('API createReply: ✅ id=${reply.id}');
    return reply;
  }

  // -------------------------------------------------------------------------
  // Moderation endpoints
  // -------------------------------------------------------------------------

  Future<void> pinThread(String boardId, String threadId, {bool pin = true}) {
    AppLogging.nodeBoard(
      'API mod pinThread: boardId=$boardId threadId=$threadId pin=$pin',
    );
    return _modAction(boardId, 'pin-thread', {
      'threadId': threadId,
      'pin': pin,
    });
  }

  Future<void> lockThread(String boardId, String threadId, {bool lock = true}) {
    AppLogging.nodeBoard(
      'API mod lockThread: boardId=$boardId threadId=$threadId lock=$lock',
    );
    return _modAction(boardId, 'lock-thread', {
      'threadId': threadId,
      'lock': lock,
    });
  }

  Future<void> deleteThread(String boardId, String threadId, {String? reason}) {
    AppLogging.nodeBoard(
      'API mod deleteThread: boardId=$boardId threadId=$threadId',
    );
    return _modAction(boardId, 'delete-thread', {
      'threadId': threadId,
      if (reason != null) 'reason': reason,
    });
  }

  Future<void> deleteReply(String boardId, String replyId, {String? reason}) {
    AppLogging.nodeBoard(
      'API mod deleteReply: boardId=$boardId replyId=$replyId',
    );
    return _modAction(boardId, 'delete-reply', {
      'replyId': replyId,
      if (reason != null) 'reason': reason,
    });
  }

  Future<void> lockSection(
    String boardId,
    String sectionId, {
    bool lock = true,
  }) {
    AppLogging.nodeBoard(
      'API mod lockSection: boardId=$boardId sectionId=$sectionId lock=$lock',
    );
    return _modAction(boardId, 'lock-section', {
      'sectionId': sectionId,
      'lock': lock,
    });
  }

  Future<void> _modAction(
    String boardId,
    String action,
    Map<String, dynamic> body,
  ) async {
    final headers = await _writeHeaders();
    final response = await _post(
      Uri.parse('$_baseUrl/api/boards/$boardId/mod/$action'),
      headers: headers,
      body: jsonEncode(body),
    );
    _checkResponse(response);
    AppLogging.nodeBoard('API mod $action: ✅');
  }

  // -------------------------------------------------------------------------
  // Read state
  // -------------------------------------------------------------------------

  Future<void> markBoardViewed(String slug) async {
    AppLogging.nodeBoard('API markBoardViewed: slug=$slug');
    final headers = await _writeHeaders();
    final response = await _post(
      Uri.parse('$_baseUrl/api/boards/$slug/read-state'),
      headers: headers,
    );
    _checkResponse(response);
    AppLogging.nodeBoard('API markBoardViewed: ✅');
  }

  // -------------------------------------------------------------------------
  // Search
  // -------------------------------------------------------------------------

  Future<({List<Map<String, dynamic>> results, int total})> searchThreads(
    String slug,
    String query, {
    int limit = 25,
    int offset = 0,
  }) async {
    AppLogging.nodeBoard(
      'API search: slug=$slug q=$query limit=$limit offset=$offset',
    );
    final headers = await _readHeaders();
    final params = {'q': query, 'limit': '$limit', 'offset': '$offset'};

    final response = await _get(
      Uri.parse(
        '$_baseUrl/api/boards/$slug/search',
      ).replace(queryParameters: params),
      headers: headers,
    );
    _checkResponse(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;

    final results = (json['results'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final total = json['total'] as int;
    AppLogging.nodeBoard(
      'API search: ✅ ${results.length} results (total=$total)',
    );
    return (results: results, total: total);
  }

  // -------------------------------------------------------------------------
  // Themes
  // -------------------------------------------------------------------------

  Future<List<NodeBoardTheme>> getThemes() async {
    AppLogging.nodeBoard('API getThemes');
    final response = await _get(Uri.parse('$_baseUrl/api/themes'));
    _checkResponse(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final list = json['themes'] as List<dynamic>;
    final themes = list
        .map((e) => NodeBoardTheme.fromJson(e as Map<String, dynamic>))
        .toList();
    AppLogging.nodeBoard('API getThemes: ✅ ${themes.length} themes');
    return themes;
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  void _checkResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    String message;
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      message = json['error'] as String? ?? 'Unknown error';
    } catch (_) {
      message = 'HTTP ${response.statusCode}';
    }

    AppLogging.nodeBoard('API ❌ HTTP ${response.statusCode}: $message');
    throw NodeBoardApiException(response.statusCode, message);
  }
}

class NodeBoardApiException implements Exception {
  final int statusCode;
  final String message;

  const NodeBoardApiException(this.statusCode, this.message);

  @override
  String toString() => 'NodeBoardApiException($statusCode): $message';
}
