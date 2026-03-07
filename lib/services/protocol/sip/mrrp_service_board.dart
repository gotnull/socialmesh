// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// MRRP board.v1 service handler.
///
/// Short mesh bulletin board. In-memory post store bounded at 16 posts,
/// auto-expiring by TTL (max 24 hours). Rate-limited to 1 post per 60 s
/// per peer.
///
/// Actions:
/// - **list_recent** (0x0001): Return recent posts (max 8, filtered by since_hours).
/// - **post_short** (0x0002): Store a short text post (1-80 bytes).
/// - **get_post** (0x0003): Return a post by ID.
library;

import 'dart:typed_data';

import '../../../core/logging.dart';
import 'mrrp_constants.dart';
import 'mrrp_frame.dart';
import 'mrrp_service_handler.dart';
import 'mrrp_types.dart';

/// Maximum number of stored posts.
const int _maxPosts = 16;

/// Maximum post TTL in seconds (24 hours).
const int _maxPostTtlS = 86400;

/// Maximum post text length in bytes.
const int _maxPostTextBytes = 80;

/// Minimum post text length in bytes.
const int _minPostTextBytes = 1;

/// Rate limit: minimum seconds between posts from the same peer.
const int _postRateLimitS = 60;

/// Maximum posts returned in list_recent.
const int _maxListRecentPosts = 8;

/// A single bulletin board post.
class _BoardPost {
  final int postId;
  final int authorNodeId;
  final Uint8List text;
  final DateTime createdAt;
  final DateTime expiresAt;

  _BoardPost({
    required this.postId,
    required this.authorNodeId,
    required this.text,
    required this.createdAt,
    required this.expiresAt,
  });

  bool isExpiredAt(DateTime now) => now.isAfter(expiresAt);
}

/// board.v1 handler.
class MrrpServiceBoard implements MrrpServiceHandler {
  /// Injectable clock for testing.
  final DateTime Function()? _clock;

  /// Stored posts, keyed by post_id.
  final Map<int, _BoardPost> _posts = {};

  /// Rate limiter: peer node_id -> last post timestamp.
  final Map<int, DateTime> _lastPostTime = {};

  /// Next post ID (wrapping uint32).
  int _nextPostId = 1;

  MrrpServiceBoard({DateTime Function()? clock}) : _clock = clock;

  @override
  int get serviceId => MrrpServiceId.boardV1;

  @override
  Set<int> get supportedActions => const {
    BoardAction.listRecent,
    BoardAction.postShort,
    BoardAction.getPost,
  };

  DateTime _now() => _clock?.call() ?? DateTime.now();

  /// Number of non-expired posts. Visible for testing.
  int get postCount {
    final now = _now();
    return _posts.values.where((p) => !p.isExpiredAt(now)).length;
  }

  @override
  Future<MrrpFrame> handleRequest(MrrpFrame request, int senderNodeId) async {
    _purgeExpired();
    switch (request.actionId) {
      case BoardAction.listRecent:
        return _handleListRecent(request);
      case BoardAction.postShort:
        return _handlePostShort(request, senderNodeId);
      case BoardAction.getPost:
        return _handleGetPost(request);
      default:
        return _buildError(request, MrrpStatusCode.unsupported);
    }
  }

  // ---------------------------------------------------------------------------
  // list_recent
  // ---------------------------------------------------------------------------

  /// Request payload: since_hours(1) = 1 byte (0 = all).
  MrrpFrame _handleListRecent(MrrpFrame request) {
    int sinceHours = 0;
    if (request.payload.isNotEmpty) {
      sinceHours = request.payload[0];
    }

    final now = _now();
    final cutoff = sinceHours > 0
        ? now.subtract(Duration(hours: sinceHours))
        : DateTime.fromMillisecondsSinceEpoch(0);

    final recentPosts =
        _posts.values
            .where((p) => !p.isExpiredAt(now) && p.createdAt.isAfter(cutoff))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final limitedPosts = recentPosts.take(_maxListRecentPosts).toList();

    // Build response: post_count(1) + posts...
    // Each post: post_id(4) + author_node_id(4) + text_len(1) + text(N).
    final builder = BytesBuilder(copy: false);
    builder.addByte(limitedPosts.length);
    for (final post in limitedPosts) {
      final postIdBytes = Uint8List(4);
      ByteData.sublistView(
        postIdBytes,
      ).setUint32(0, post.postId, Endian.little);
      builder.add(postIdBytes);

      final nodeIdBytes = Uint8List(4);
      ByteData.sublistView(
        nodeIdBytes,
      ).setUint32(0, post.authorNodeId, Endian.little);
      builder.add(nodeIdBytes);

      builder.addByte(post.text.length);
      builder.add(post.text);
    }

    final payload = builder.toBytes();

    AppLogging.mrrp(
      'MRRP_SERVICE: board.v1 list_recent '
      '-> ${limitedPosts.length} posts, ${payload.length}B', // lint-allow: hardcoded-string
    );

    return _buildResponse(request, Uint8List.fromList(payload));
  }

  // ---------------------------------------------------------------------------
  // post_short
  // ---------------------------------------------------------------------------

  /// Request payload: ttl_s(2, LE) + text(N) — min 3 bytes.
  MrrpFrame _handlePostShort(MrrpFrame request, int senderNodeId) {
    if (request.payload.length < 3) {
      return _buildError(request, MrrpStatusCode.invalid);
    }

    final ttlS = ByteData.sublistView(
      request.payload,
    ).getUint16(0, Endian.little).clamp(1, _maxPostTtlS);
    final text = Uint8List.sublistView(request.payload, 2);

    if (text.length < _minPostTextBytes || text.length > _maxPostTextBytes) {
      return _buildError(request, MrrpStatusCode.invalid);
    }

    // Rate limit check.
    final now = _now();
    final lastPost = _lastPostTime[senderNodeId];
    if (lastPost != null &&
        now.difference(lastPost).inSeconds < _postRateLimitS) {
      AppLogging.mrrp(
        'MRRP_SERVICE: board.v1 post_short rate-limited, '
        'peer=${senderNodeId.toRadixString(16)}', // lint-allow: hardcoded-string
      );
      return _buildError(request, MrrpStatusCode.rateLimited);
    }

    // Evict oldest if at capacity.
    if (_posts.length >= _maxPosts) {
      final oldest = _posts.values.reduce(
        (a, b) => a.createdAt.isBefore(b.createdAt) ? a : b,
      );
      _posts.remove(oldest.postId);
    }

    final postId = _allocatePostId();
    final post = _BoardPost(
      postId: postId,
      authorNodeId: senderNodeId,
      text: Uint8List.fromList(text),
      createdAt: now,
      expiresAt: now.add(Duration(seconds: ttlS)),
    );
    _posts[postId] = post;
    _lastPostTime[senderNodeId] = now;

    AppLogging.mrrp(
      'MRRP_SERVICE: board.v1 post_short ${text.length}B '
      '-> post_id=0x${postId.toRadixString(16).padLeft(8, '0')}', // lint-allow: hardcoded-string
    );

    // Response: post_id(4).
    final payload = Uint8List(4);
    ByteData.sublistView(payload).setUint32(0, postId, Endian.little);
    return _buildResponse(request, payload);
  }

  // ---------------------------------------------------------------------------
  // get_post
  // ---------------------------------------------------------------------------

  /// Request payload: post_id(4, LE) = 4 bytes.
  MrrpFrame _handleGetPost(MrrpFrame request) {
    if (request.payload.length < 4) {
      return _buildError(request, MrrpStatusCode.invalid);
    }

    final postId = ByteData.sublistView(
      request.payload,
    ).getUint32(0, Endian.little);
    final post = _posts[postId];
    if (post == null || post.isExpiredAt(_now())) {
      return _buildError(request, MrrpStatusCode.notFound);
    }

    // Response: post_id(4) + author_node_id(4) + text_len(1) + text(N).
    final payload = Uint8List(4 + 4 + 1 + post.text.length);
    final bd = ByteData.sublistView(payload);
    bd.setUint32(0, post.postId, Endian.little);
    bd.setUint32(4, post.authorNodeId, Endian.little);
    payload[8] = post.text.length;
    payload.setRange(9, 9 + post.text.length, post.text);

    return _buildResponse(request, payload);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  int _allocatePostId() {
    final id = _nextPostId;
    _nextPostId = (_nextPostId + 1) & 0xFFFFFFFF;
    if (_nextPostId == 0) _nextPostId = 1;
    return id;
  }

  void _purgeExpired() {
    final now = _now();
    _posts.removeWhere((_, p) => p.isExpiredAt(now));
  }

  MrrpFrame _buildResponse(MrrpFrame request, Uint8List payload) {
    return MrrpFrame(
      versionMajor: MrrpConstants.mrrpVersionMajor,
      versionMinor: MrrpConstants.mrrpVersionMinor,
      msgType: MrrpMessageType.response,
      flags: MrrpFlags.isResponse,
      headerLen: MrrpConstants.mrrpHeaderMin,
      requestId: request.requestId,
      serviceId: serviceId,
      actionId: request.actionId,
      payloadLen: payload.length,
      payload: payload,
    );
  }

  MrrpFrame _buildError(MrrpFrame request, MrrpStatusCode status) {
    final payload = Uint8List(1)..[0] = status.code;
    return MrrpFrame(
      versionMajor: MrrpConstants.mrrpVersionMajor,
      versionMinor: MrrpConstants.mrrpVersionMinor,
      msgType: MrrpMessageType.error,
      flags: MrrpFlags.isResponse | MrrpFlags.isError,
      headerLen: MrrpConstants.mrrpHeaderMin,
      requestId: request.requestId,
      serviceId: serviceId,
      actionId: request.actionId,
      payloadLen: 1,
      payload: payload,
      headerExtensions: [
        MrrpTlvEntry(
          type: MrrpTlvType.statusCode.code,
          value: Uint8List.fromList([status.code]),
        ),
      ],
    );
  }
}
