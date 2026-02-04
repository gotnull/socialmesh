// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/logging.dart';
import '../models/social.dart';
import 'mesh_packet_dedupe_store.dart';
import 'social_activity_service.dart';

/// Default signal TTL options in minutes.
class SignalTTL {
  // static const int min1 = 1; // For testing
  static const int min15 = 15;
  static const int min30 = 30;
  static const int hour1 = 60;
  static const int hour6 = 360;
  static const int hour24 = 1440;

  static const int defaultTTL = hour1;

  static const List<int> options = [
    // min1, // For testing
    min15, min30, hour1, hour6, hour24,
  ];

  static String label(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    return '${hours}h';
  }
}

/// Image unlock rules for signals.
///
/// An image is "unlocked" (viewable/uploadable) when:
/// 1. User is authenticated (auth unlock), OR
/// 2. Sustained proximity: sender node has been seen within
///    [proximityThresholdMinutes] in the last [proximityWindowMinutes]
class ImageUnlockRules {
  /// Minimum time (minutes) a node must be "nearby" to unlock images.
  static const int proximityThresholdMinutes = 5;

  /// Window (minutes) to check for sustained proximity.
  static const int proximityWindowMinutes = 15;

  /// Maximum number of mesh hops considered "nearby" for image unlock.
  static const int maxHopsForProximity = 2;
}

/// A comment on a signal.
/// Comments are stored locally in SQLite and synced to Firestore.
/// Only visible to users who have the signal locally (received via mesh).
class SignalResponse {
  final String id;
  final String signalId;
  final String content;
  final String authorId;
  final String? authorName;
  final String? parentId; // For threaded replies - ID of parent response
  final int depth; // Thread depth (0 = top-level, computed from parentId chain)
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isLocal; // true if created on this device

  // Voting fields (maintained by Cloud Functions, read-only on client)
  final int score; // upvoteCount - downvoteCount
  final int upvoteCount;
  final int downvoteCount;
  final int replyCount; // Direct child replies count

  // User's current vote on this response (client-side state, not stored in response doc)
  final int myVote; // +1, -1, or 0 (no vote)

  // Soft delete support
  final bool isDeleted;

  const SignalResponse({
    required this.id,
    required this.signalId,
    required this.content,
    required this.authorId,
    this.authorName,
    this.parentId,
    this.depth = 0,
    required this.createdAt,
    required this.expiresAt,
    this.isLocal = true,
    this.score = 0,
    this.upvoteCount = 0,
    this.downvoteCount = 0,
    this.replyCount = 0,
    this.myVote = 0,
    this.isDeleted = false,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Display content - shows "[deleted]" for soft-deleted comments
  String get displayContent => isDeleted ? '[deleted]' : content;

  /// Copy with new values
  SignalResponse copyWith({
    String? id,
    String? signalId,
    String? content,
    String? authorId,
    String? authorName,
    String? parentId,
    int? depth,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isLocal,
    int? score,
    int? upvoteCount,
    int? downvoteCount,
    int? replyCount,
    int? myVote,
    bool? isDeleted,
  }) {
    return SignalResponse(
      id: id ?? this.id,
      signalId: signalId ?? this.signalId,
      content: content ?? this.content,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      parentId: parentId ?? this.parentId,
      depth: depth ?? this.depth,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isLocal: isLocal ?? this.isLocal,
      score: score ?? this.score,
      upvoteCount: upvoteCount ?? this.upvoteCount,
      downvoteCount: downvoteCount ?? this.downvoteCount,
      replyCount: replyCount ?? this.replyCount,
      myVote: myVote ?? this.myVote,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'signalId': signalId,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      if (parentId != null) 'parentId': parentId,
      'depth': depth,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'isDeleted': isDeleted,
      // Note: score, upvoteCount, downvoteCount, replyCount are maintained by Cloud Functions
      // Client should NOT write these fields - they're set to defaults on create
    };
  }

  factory SignalResponse.fromFirestore(String id, Map<String, dynamic> data) {
    return SignalResponse(
      id: id,
      signalId: data['signalId'] as String,
      content: data['content'] as String,
      authorId: data['authorId'] as String,
      authorName: data['authorName'] as String?,
      parentId: data['parentId'] as String?,
      depth: data['depth'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      isLocal: false,
      score: data['score'] as int? ?? 0,
      upvoteCount: data['upvoteCount'] as int? ?? 0,
      downvoteCount: data['downvoteCount'] as int? ?? 0,
      replyCount: data['replyCount'] as int? ?? 0,
      isDeleted: data['isDeleted'] as bool? ?? false,
    );
  }

  /// Factory from Firestore comment format (canonical posts/{signalId}/comments path).
  factory SignalResponse.fromFirestoreComment(
    String id,
    Map<String, dynamic> data,
  ) {
    // Comments store signalId in parent doc, not in each comment doc
    // createdAt uses server timestamp, expiresAt inherited from parent signal
    final createdAt = data['createdAt'] != null
        ? (data['createdAt'] as Timestamp).toDate()
        : DateTime.now();

    // For comments, expiresAt is optional (inherit from signal)
    // Use a reasonable default if not present
    final expiresAt = data['expiresAt'] != null
        ? (data['expiresAt'] as Timestamp).toDate()
        : createdAt.add(const Duration(hours: 24));

    return SignalResponse(
      id: id,
      signalId: data['signalId'] as String? ?? '',
      content: data['content'] as String? ?? '',
      authorId: data['authorId'] as String? ?? 'unknown',
      authorName: data['authorName'] as String?,
      parentId: data['parentId'] as String?,
      depth: data['depth'] as int? ?? 0,
      createdAt: createdAt,
      expiresAt: expiresAt,
      isLocal: false,
      score: data['score'] as int? ?? 0,
      upvoteCount: data['upvoteCount'] as int? ?? 0,
      downvoteCount: data['downvoteCount'] as int? ?? 0,
      replyCount: data['replyCount'] as int? ?? 0,
      isDeleted: data['isDeleted'] as bool? ?? false,
    );
  }
}

/// Represents a user's vote on a response.
/// Stored at posts/{postId}/comments/{commentId}/votes/{uid}
class ResponseVote {
  final String responseId;
  final String signalId;
  final String voterId;
  final int value; // +1 or -1 only
  final DateTime createdAt;
  final DateTime updatedAt;

  const ResponseVote({
    required this.responseId,
    required this.signalId,
    required this.voterId,
    required this.value,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ResponseVote.fromFirestore(
    String voterId,
    Map<String, dynamic> data,
  ) {
    return ResponseVote(
      responseId: data['responseId'] as String? ?? '',
      signalId: data['signalId'] as String? ?? '',
      voterId: voterId,
      value: data['value'] as int? ?? 0,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'responseId': responseId,
      'signalId': signalId,
      'value': value,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

/// Pending image update awaiting Firestore retry.
class _PendingImageUpdate {
  final String signalId;
  final String url;
  int attemptCount;
  DateTime nextRetryTime;

  _PendingImageUpdate({required this.signalId, required this.url})
    : attemptCount = 0,
      nextRetryTime = DateTime.now();

  /// Calculate next retry with exponential backoff (5s, 10s, 20s, 40s, capped at 60s).
  void scheduleRetry() {
    attemptCount++;
    final delaySeconds = (5 * (1 << (attemptCount - 1))).clamp(5, 60);
    nextRetryTime = DateTime.now().add(Duration(seconds: delaySeconds));
  }

  bool get isReady => DateTime.now().isAfter(nextRetryTime);

  /// Max 10 attempts before giving up.
  bool get shouldGiveUp => attemptCount >= 10;
}

/// Service for managing mesh signals with durable SQLite storage.
///
/// Signals are mesh-first ephemeral content that:
/// - Store locally in SQLite (ordered, TTL-aware)
/// - Send mesh packets immediately
/// - Optionally sync to Firebase when authenticated
/// - Auto-expire based on TTL
/// - Support image unlock rules (auth OR sustained proximity)
class SignalService {
  static const _dbName = 'signals.db';

  /// Optional injectable cloud lookup function for testing / override.
  /// Signature: `Future<Post?> Function(String signalId)?`
  final Future<Post?> Function(String signalId)? cloudLookupOverride;

  SignalService({this.cloudLookupOverride, MeshPacketDedupeStore? dedupeStore})
    : _dedupeStore = dedupeStore ?? MeshPacketDedupeStore();

  static const _tableName = 'signals';
  static const _proximityTable = 'node_proximity';
  static const _commentsTable = 'comments';
  static const _maxLocalSignals = 200;
  static const _meshPacketTTLMinutes = 30;

  final MeshPacketDedupeStore _dedupeStore;

  // Firebase instances are accessed lazily to avoid crashes when
  // Firebase isn't initialized yet (offline-first architecture)
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;

  Database? _db;
  final _uuid = const Uuid();

  /// Active Firestore comments listeners keyed by signalId.
  /// Used to receive real-time comments from posts/{signalId}/comments.
  final Map<String, StreamSubscription<QuerySnapshot>> _commentsListeners = {};

  /// Active Firestore post document listeners keyed by signalId.
  /// Used to receive real-time updates when cloud doc appears/changes (e.g. image upload completes).
  final Map<String, StreamSubscription<DocumentSnapshot>> _postListeners = {};

  /// Tracks whether we've observed a posts/{signalId} document exist at least once.
  /// This prevents aggressively deleting local signals when the cloud doc simply
  /// hasn't been created yet (e.g., sender will upload later). Only delete
  /// locally if we previously saw the document exist and then receive an
  /// explicit deletion (exists -> false).
  final Map<String, bool> _postDocumentSeen = {};

  /// Active Firestore vote listeners keyed by signalId.
  /// Used to receive real-time myVote updates from posts/{signalId}/comments/*/votes/{uid}.
  final Map<String, StreamSubscription<QuerySnapshot>> _voteListeners = {};

  /// Listener retry state (used when listeners error or disconnect).
  final Map<String, int> _listenerRetryCounts = {};
  final Map<String, Timer> _listenerRetryTimers = {};

  /// In-memory cache of user's votes keyed by signalId -> commentId -> value.
  final Map<String, Map<String, int>> _myVotesCache = {};

  /// Pending Firestore image updates that failed and need retry.
  /// Key: signalId, Value: (url, attemptCount, nextRetryTime)
  final Map<String, _PendingImageUpdate> _pendingImageUpdates = {};

  /// Auth token listener to reattach Firestore listeners on refresh.
  StreamSubscription<User?>? _authSubscription;
  String? _lastAuthUid;

  /// Timer for retrying pending image updates.
  Timer? _imageRetryTimer;

  /// Cached cloud comments keyed by signalId.
  final Map<String, List<SignalResponse>> _cloudComments = {};

  /// Stream controller for comment updates. Emits signalId when comments change.
  final _commentUpdateController = StreamController<String>.broadcast();

  /// Stream of comment updates. Emits the signalId when its comments are updated.
  Stream<String> get onCommentUpdate => _commentUpdateController.stream;

  @visibleForTesting
  void injectCloudCommentsForTest(
    String signalId,
    List<SignalResponse> comments,
  ) {
    _cloudComments[signalId] = comments;
    _commentUpdateController.add(signalId);
  }

  @visibleForTesting
  void setCloudCommentsForTesting(
    String signalId,
    List<SignalResponse> comments,
  ) {
    _cloudComments[signalId] = comments;
  }

  @visibleForTesting
  void setMyVotesForTesting(String signalId, Map<String, int> votes) {
    _myVotesCache[signalId] = Map<String, int>.from(votes);
  }

  @visibleForTesting
  Future<void> insertLocalCommentForTesting(SignalResponse response) async {
    await init();
    await _db!.insert(_commentsTable, {
      'id': response.id,
      'signalId': response.signalId,
      'content': response.content,
      'authorId': response.authorId,
      'authorName': response.authorName,
      'parentId': response.parentId,
      'depth': response.depth,
      'createdAt': response.createdAt.millisecondsSinceEpoch,
      'expiresAt': response.expiresAt.millisecondsSinceEpoch,
      'score': response.score,
      'upvoteCount': response.upvoteCount,
      'downvoteCount': response.downvoteCount,
      'replyCount': response.replyCount,
      'isDeleted': response.isDeleted ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Stream controller for remote signal deletions.
  /// Emits signalId when a signal is deleted remotely (by the author on another device).
  final _remoteDeleteController = StreamController<String>.broadcast();

  /// Stream of remote signal deletions.
  Stream<String> get onRemoteDelete => _remoteDeleteController.stream;

  /// Track node last-seen times for proximity-based image unlock.
  /// Key: nodeId, Value: DateTime of last proximity ping.
  final Map<int, List<DateTime>> _nodeProximityHistory = {};

  /// Callback to broadcast signal over mesh. Set by provider layer.
  /// Parameters: signalId, content, ttlMinutes, latitude, longitude
  /// Returns: packet ID or null if not connected
  Future<int?> Function(
    String signalId,
    String content,
    int ttlMinutes,
    double? latitude,
    double? longitude,
    bool hasImage,
  )?
  onBroadcastSignal;

  // ===========================================================================
  // INITIALIZATION
  // ===========================================================================

  /// Initialize the SQLite database.
  Future<void> init() async {
    if (_db != null) return;

    AppLogging.signals('Initializing SignalService database');

    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(documentsDir.path, _dbName);

    _db = await openDatabase(
      dbPath,
      version: 6,
      onCreate: (db, version) async {
        AppLogging.signals('Creating signals database v$version');
        await _createTables(db);
      },
    );
    await _dedupeStore.init();

    _startAuthListener();

    // Load proximity history from disk
    await _loadProximityHistory();

    // Start retry timer for pending image updates (every 10 seconds)
    _imageRetryTimer?.cancel();
    _imageRetryTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _processPendingImageUpdates(),
    );

    AppLogging.signals('SignalService initialized');
  }

  void _startAuthListener() {
    if (_authSubscription != null) return;
    if (Firebase.apps.isEmpty) {
      AppLogging.signals('📡 Auth listener skipped: Firebase not initialized');
      return;
    }

    _authSubscription = _auth.idTokenChanges().listen(
      (user) {
        final uid = user?.uid;
        final uidChanged = uid != _lastAuthUid;
        _lastAuthUid = uid;
        if (uidChanged || user != null) {
          AppLogging.signals(
            '📡 Auth token change detected (uid=${uid ?? "none"}), reattaching listeners',
          );
        }
        Future.microtask(() => handleAuthChanged());
      },
      onError: (e) {
        AppLogging.signals('📡 Auth token listener error: $e');
      },
    );
  }

  Future<void> _createTables(Database db) async {
    // Main signals table
    await db.execute('''
      CREATE TABLE $_tableName (
        id TEXT PRIMARY KEY,
        authorId TEXT NOT NULL,
        content TEXT NOT NULL,
        mediaUrls TEXT,
        locationLatitude REAL,
        locationLongitude REAL,
        locationName TEXT,
        nodeId TEXT,
        createdAt INTEGER NOT NULL,
        expiresAt INTEGER,
        commentCount INTEGER DEFAULT 0,
        likeCount INTEGER DEFAULT 0,
        authorSnapshotJson TEXT,
        postMode TEXT NOT NULL,
        origin TEXT NOT NULL,
        meshNodeId INTEGER,
        hopCount INTEGER,
        imageState TEXT NOT NULL,
        imageLocalPath TEXT,
        hasPendingCloudImage INTEGER DEFAULT 0,
        syncedToCloud INTEGER DEFAULT 0
      )
    ''');

    // Index for expiry queries
    await db.execute(
      'CREATE INDEX idx_signals_expiresAt ON $_tableName(expiresAt)',
    );

    // Index for mesh node queries
    await db.execute(
      'CREATE INDEX idx_signals_meshNodeId ON $_tableName(meshNodeId)',
    );

    await _createProximityTable(db);
    await _createCommentsTable(db);
  }

  Future<void> _createProximityTable(Database db) async {
    // Node proximity tracking for image unlock
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_proximityTable (
        nodeId INTEGER NOT NULL,
        seenAt INTEGER NOT NULL,
        PRIMARY KEY (nodeId, seenAt)
      )
    ''');
  }

  Future<void> _createCommentsTable(Database db) async {
    // Local comments cache for signals
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_commentsTable (
        id TEXT PRIMARY KEY,
        signalId TEXT NOT NULL,
        content TEXT NOT NULL,
        authorId TEXT NOT NULL,
        authorName TEXT,
        parentId TEXT,
        depth INTEGER DEFAULT 0,
        createdAt INTEGER NOT NULL,
        expiresAt INTEGER NOT NULL,
        score INTEGER DEFAULT 0,
        upvoteCount INTEGER DEFAULT 0,
        downvoteCount INTEGER DEFAULT 0,
        replyCount INTEGER DEFAULT 0,
        isDeleted INTEGER DEFAULT 0,
        FOREIGN KEY (signalId) REFERENCES $_tableName(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_comments_signalId '
      'ON $_commentsTable(signalId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_comments_expiresAt '
      'ON $_commentsTable(expiresAt)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_comments_parentId '
      'ON $_commentsTable(parentId)',
    );
  }

  Future<void> _loadProximityHistory() async {
    if (_db == null) return;

    final cutoff = DateTime.now()
        .subtract(Duration(minutes: ImageUnlockRules.proximityWindowMinutes))
        .millisecondsSinceEpoch;

    final rows = await _db!.query(
      _proximityTable,
      where: 'seenAt > ?',
      whereArgs: [cutoff],
    );

    _nodeProximityHistory.clear();
    for (final row in rows) {
      final nodeId = row['nodeId'] as int;
      final seenAt = DateTime.fromMillisecondsSinceEpoch(row['seenAt'] as int);
      _nodeProximityHistory.putIfAbsent(nodeId, () => []).add(seenAt);
    }

    AppLogging.signals(
      'Loaded proximity history for ${_nodeProximityHistory.length} nodes',
    );
  }

  /// Get current user ID or null if not authenticated.
  String? get _currentUserId {
    try {
      return _auth.currentUser?.uid;
    } catch (e) {
      // Firebase not initialized or other error - treat as unauthenticated
      return null;
    }
  }

  /// Check if user is authenticated.
  bool get isAuthenticated => _currentUserId != null;

  void _scheduleListenerRetry(String signalId, String kind) {
    if (_currentUserId == null) return;
    final key = '$kind:$signalId';
    final attempt = (_listenerRetryCounts[key] ?? 0) + 1;
    _listenerRetryCounts[key] = attempt;

    final delaySeconds = (2 * (1 << (attempt - 1))).clamp(2, 60);
    _listenerRetryTimers[key]?.cancel();
    _listenerRetryTimers[key] = Timer(Duration(seconds: delaySeconds), () {
      _listenerRetryTimers.remove(key);
      if (_currentUserId == null) return;
      AppLogging.signals(
        '📡 Listener retry: kind=$kind signalId=$signalId attempt=$attempt',
      );
      switch (kind) {
        case 'comments':
          _startCommentsListener(signalId);
          break;
        case 'post':
          _startPostListener(signalId);
          break;
        case 'votes':
          startVoteListener(signalId);
          break;
      }
    });

    AppLogging.signals(
      '📡 Listener retry scheduled: kind=$kind signalId=$signalId '
      'attempt=$attempt delay=${delaySeconds}s',
    );
  }

  void _clearListenerRetry(String signalId, String kind) {
    final key = '$kind:$signalId';
    _listenerRetryCounts.remove(key);
    _listenerRetryTimers.remove(key)?.cancel();
  }

  // ===========================================================================
  // NODE PROXIMITY TRACKING
  // ===========================================================================

  /// Record that a node was seen (for proximity-based image unlock).
  Future<void> recordNodeProximity(int nodeId) async {
    await init();

    final now = DateTime.now();

    // Add to in-memory cache
    _nodeProximityHistory.putIfAbsent(nodeId, () => []).add(now);

    // Trim old entries from memory
    final cutoff = now.subtract(
      Duration(minutes: ImageUnlockRules.proximityWindowMinutes),
    );
    _nodeProximityHistory[nodeId]?.removeWhere((t) => t.isBefore(cutoff));

    // Persist to database
    await _db!.insert(_proximityTable, {
      'nodeId': nodeId,
      'seenAt': now.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Check if a node has sustained proximity for image unlock.
  bool hasProximityUnlock(int nodeId) {
    final history = _nodeProximityHistory[nodeId];
    if (history == null || history.isEmpty) return false;

    final now = DateTime.now();
    final windowStart = now.subtract(
      Duration(minutes: ImageUnlockRules.proximityWindowMinutes),
    );
    final thresholdDuration = Duration(
      minutes: ImageUnlockRules.proximityThresholdMinutes,
    );

    // Count sightings within the window
    final recentSightings = history
        .where((t) => t.isAfter(windowStart))
        .toList();
    if (recentSightings.isEmpty) return false;

    // Check if we have sustained proximity (multiple sightings over threshold)
    final firstSighting = recentSightings.reduce(
      (a, b) => a.isBefore(b) ? a : b,
    );
    final lastSighting = recentSightings.reduce((a, b) => a.isAfter(b) ? a : b);

    final duration = lastSighting.difference(firstSighting);
    return duration >= thresholdDuration;
  }

  /// Check if image is unlocked for a signal.
  ///
  /// Returns true if:
  /// 1. User is authenticated, OR
  /// 2. Signal sender has sustained proximity
  bool isImageUnlocked(Post signal) {
    // Rule 1: Authenticated users can always view/upload images
    if (isAuthenticated) {
      AppLogging.signals(
        'Image unlocked for signal ${signal.id}: authenticated',
      );
      return true;
    }

    // Rule 2: Check sustained proximity for mesh signals
    if (signal.meshNodeId != null && hasProximityUnlock(signal.meshNodeId!)) {
      AppLogging.signals(
        'Image unlocked for signal ${signal.id}: '
        'proximity to node ${signal.meshNodeId}',
      );
      return true;
    }

    return false;
  }

  /// Copy an image from a temporary location to persistent app storage.
  /// Returns the new path or null if copy failed.
  Future<String?> _copyImageToPersistentStorage(
    String sourcePath,
    String signalId,
  ) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        AppLogging.signals('Source image file not found: $sourcePath');
        return null;
      }

      // Create signals/images directory in app documents
      final documentsDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(
        p.join(documentsDir.path, 'signals', 'images'),
      );
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      // Determine extension from source file
      final extension = p.extension(sourcePath).isNotEmpty
          ? p.extension(sourcePath)
          : '.jpg';
      final destPath = p.join(imagesDir.path, '$signalId$extension');

      // Copy file to persistent storage
      await sourceFile.copy(destPath);

      return destPath;
    } catch (e) {
      AppLogging.signals('Failed to copy image to persistent storage: $e');
      return null;
    }
  }

  /// Delete a signal's local image file if it exists.
  Future<void> _deleteSignalImage(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return;

    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        AppLogging.signals('Deleted signal image: $imagePath');
      }
    } catch (e) {
      AppLogging.signals('Failed to delete signal image: $e');
    }
  }

  /// Delete cached cloud images for a list of signal IDs.
  Future<void> _deleteCachedCloudImages(List<String> signalIds) async {
    if (signalIds.isEmpty) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory(p.join(appDir.path, 'signal_images'));

      if (!await cacheDir.exists()) return;

      for (final signalId in signalIds) {
        final cachedFile = File(p.join(cacheDir.path, '$signalId.jpg'));
        if (await cachedFile.exists()) {
          await cachedFile.delete();
          AppLogging.signals('Deleted cached cloud image for signal $signalId');
        }
      }
    } catch (e) {
      AppLogging.signals('Failed to delete cached cloud images: $e');
    }
  }

  // ===========================================================================
  // SIGNAL CREATION
  // ===========================================================================

  /// Create a new signal.
  ///
  /// 1. Creates local Post with postMode=signal
  /// 2. Stores in SQLite immediately
  /// 3. Optionally uploads to Firebase if authenticated AND not expired
  ///
  /// Returns the created Post/Signal.
  Future<Post> createSignal({
    required String content,
    int ttlMinutes = SignalTTL.defaultTTL,
    PostLocation? location,
    int? meshNodeId,
    List<String>? imageLocalPaths,
    PostAuthorSnapshot? authorSnapshot,
    // When false, do not attempt any cloud work (no Firestore/Storage calls)
    // Only broadcast over mesh and store locally.
    bool useCloud = true,
    // Sender's presence info at time of send (intent + short status)
    Map<String, dynamic>? presenceInfo,
  }) async {
    await init();

    final now = DateTime.now();
    final expiresAt = now.add(Duration(minutes: ttlMinutes));
    final id = _uuid.v4();

    // Copy images to persistent storage if provided
    final persistentImagePaths = <String>[];
    ImageState imageState = ImageState.none;

    if (imageLocalPaths != null && imageLocalPaths.isNotEmpty) {
      for (var i = 0; i < imageLocalPaths.length; i++) {
        final imagePath = imageLocalPaths[i];
        if (imagePath.isEmpty) continue;

        final persistentPath = await _copyImageToPersistentStorage(
          imagePath,
          '${id}_$i', // Unique ID for each image
        );

        if (persistentPath != null) {
          persistentImagePaths.add(persistentPath);
          AppLogging.signals(
            'Image $i copied to persistent storage: $persistentPath',
          );
        } else {
          AppLogging.signals('Failed to copy image $i to persistent storage');
        }
      }

      if (persistentImagePaths.isNotEmpty) {
        imageState = ImageState.local;
      }
    }

    final authorId =
        _currentUserId ??
        (meshNodeId != null
            ? 'mesh_${meshNodeId.toRadixString(16)}'
            : 'anonymous');

    final signal = Post(
      id: id,
      authorId: authorId,
      content: content,
      mediaUrls: const [],
      location: location,
      nodeId: meshNodeId?.toRadixString(16),
      createdAt: now,
      commentCount: 0,
      likeCount: 0,
      authorSnapshot: authorSnapshot,
      postMode: PostMode.signal,
      origin: SignalOrigin.mesh,
      expiresAt: expiresAt,
      meshNodeId: meshNodeId,
      imageState: imageState,
      imageLocalPath: persistentImagePaths.isNotEmpty
          ? persistentImagePaths.first
          : null,
      imageLocalPaths: persistentImagePaths,
      hasPendingCloudImage: persistentImagePaths.isNotEmpty,
      presenceInfo: presenceInfo,
    );

    AppLogging.signals(
      'Creating signal: id=$id, ttl=${ttlMinutes}m, '
      'imageCount=${persistentImagePaths.length}, meshNode=$meshNodeId',
    );

    // Store locally first (mesh-first)
    await _saveSignalToDb(signal);

    // Broadcast over mesh immediately (mesh-first). Include signalId
    // for deterministic cloud matching. This must NOT be blocked by cloud sync.
    if (onBroadcastSignal != null) {
      try {
        AppLogging.signals('SEND: broadcast started for ${signal.id}');
        // If this is mesh-only send (useCloud==false) then use a short timeout
        // so UI doesn't feel stuck waiting for ACKs.
        final hasImage = persistentImagePaths.isNotEmpty;
        int? packetId;
        if (!useCloud) {
          try {
            final broadcastFuture = Future<int?>.sync(() async {
              return await onBroadcastSignal!(
                id,
                content,
                ttlMinutes,
                location?.latitude,
                location?.longitude,
                hasImage,
              );
            });
            packetId = await broadcastFuture.timeout(
              const Duration(milliseconds: 1500),
              onTimeout: () => null,
            );
          } catch (e) {
            AppLogging.signals(
              'SEND: broadcast timeout/failed for ${signal.id}: $e',
            );
            packetId = null;
          }
        } else {
          packetId = await onBroadcastSignal!(
            id,
            content,
            ttlMinutes,
            location?.latitude,
            location?.longitude,
            hasImage,
          );
        }

        if (packetId != null) {
          AppLogging.signals(
            'SEND: broadcast completed packetId=$packetId for ${signal.id}',
          );
        } else {
          AppLogging.signals(
            'SEND: broadcast skipped (mesh not connected or timed out) for ${signal.id}',
          );
        }
      } catch (e, st) {
        AppLogging.signals('SEND: broadcast failed for ${signal.id}: $e\n$st');
      }
    }

    // Cloud sync should only happen if useCloud==true AND we have an auth'ed user.
    if (useCloud && _currentUserId != null && !signal.isExpired) {
      AppLogging.signals('SEND: cloud sync queued for ${signal.id}');
      // Fire-and-forget: schedule cloud save, then auto-upload images
      Future(() async {
        try {
          await _saveSignalToFirebase(signal);
          await _markSignalSynced(signal.id);
          AppLogging.signals('SEND: cloud sync success for ${signal.id}');

          // Now that signal exists in Firestore, upload images if needed
          if (persistentImagePaths.isNotEmpty &&
              imageState == ImageState.local) {
            AppLogging.signals(
              'SEND: images upload starting for ${signal.id} (${persistentImagePaths.length} images)',
            );
            await _autoUploadMultipleImages(signal.id, persistentImagePaths);
          }
        } catch (e, st) {
          AppLogging.signals(
            'SEND: cloud sync error for ${signal.id}: $e\n$st',
          );
        }
      });
    } else if (!useCloud) {
      AppLogging.signals(
        'SEND: cloud sync skipped (offline/unauth) for ${signal.id}',
      );
    }

    // Note: Image upload now happens inside cloud sync Future above
    // This ensures signal exists in Firestore before uploadSignalImage queries it
    if (useCloud &&
        _currentUserId != null &&
        persistentImagePaths.isNotEmpty &&
        imageState == ImageState.local) {
      // Image upload moved to cloud sync block above
    } else if (persistentImagePaths.isNotEmpty && !useCloud) {
      AppLogging.signals(
        'SEND: images suppressed for ${signal.id} (cloud unavailable)',
      );
      // If images are suppressed, make sure we don't attempt uploads or set imageState to local-only
      // imageState remains ImageState.local but we don't upload it.
    }

    // Start listening for cloud comments on this signal (non-blocking)
    if (useCloud) {
      _startCommentsListener(signal.id);
    } else {
      AppLogging.signals(
        'SEND: cloud listeners skipped for ${signal.id} (mesh-only)',
      );
    }

    return signal;
  }

  /// Auto-upload multiple images to cloud in background.
  /// Updates local and cloud records with all image URLs.
  Future<void> _autoUploadMultipleImages(
    String signalId,
    List<String> localPaths,
  ) async {
    AppLogging.signals(
      'Auto-uploading ${localPaths.length} images for signal $signalId',
    );

    final uploadedUrls = <String>[];
    for (var i = 0; i < localPaths.length; i++) {
      final localPath = localPaths[i];
      final url = await uploadSignalImage(
        signalId,
        localPath,
        storageSuffix: '_$i',
        skipFirestoreUpdate: true, // Batch update will handle Firestore
      );
      if (url != null) {
        uploadedUrls.add(url);
        AppLogging.signals('Image $i auto-uploaded: $signalId -> $url');
      } else {
        AppLogging.signals('Image $i auto-upload failed for signal $signalId');
      }
    }

    if (uploadedUrls.isNotEmpty) {
      AppLogging.signals(
        'Uploaded ${uploadedUrls.length}/${localPaths.length} images for $signalId',
      );

      // Update the signal with all uploaded URLs
      try {
        // Update Firestore
        await _firestore.collection('posts').doc(signalId).update({
          'mediaUrls': uploadedUrls,
          'imageState': 'uploaded',
        });

        // Update local database
        await init();
        await _db!.update(
          'signals',
          {
            'mediaUrls': jsonEncode(uploadedUrls), // Store as JSON
            'imageState': 'uploaded',
          },
          where: 'id = ?',
          whereArgs: [signalId],
        );

        AppLogging.signals(
          'Updated signal $signalId with ${uploadedUrls.length} mediaUrls',
        );
      } catch (e) {
        AppLogging.signals(
          'Failed to update signal $signalId with mediaUrls: $e',
        );
      }
    }
  }

  // ===========================================================================
  // IMAGE RESOLUTION (idempotent resolver triggered by events)
  // ===========================================================================

  final Set<String> _imageResolveInProgress = {};

  /// Resolve (download & cache) the signal image if needed.
  /// Safe to call repeatedly. No-op if already resolved or in progress.
  Future<void> resolveSignalImageIfNeeded(Post signal) async {
    await init(); // ensure DB is ready

    try {
      // Preconditions
      if (signal.mediaUrls.isEmpty) {
        return;
      }
      if (signal.imageLocalPath != null && signal.imageLocalPath!.isNotEmpty) {
        return;
      }
      if (_imageResolveInProgress.contains(signal.id)) {
        AppLogging.signals(
          'RESOLVE_IMAGE: already in progress for ${signal.id}',
        );
        return;
      }

      _imageResolveInProgress.add(signal.id);
      AppLogging.signals('RESOLVE_IMAGE_START signalId=${signal.id}');

      // Refresh latest local signal state
      final latest = await getSignalById(signal.id);
      if (latest == null) {
        AppLogging.signals(
          'RESOLVE_IMAGE: signal ${signal.id} not found locally',
        );
        return;
      }

      // If already downloaded by another actor in the meantime
      if (latest.imageLocalPath != null && latest.imageLocalPath!.isNotEmpty) {
        AppLogging.signals(
          'RESOLVE_IMAGE_OK signalId=${signal.id} (already present)',
        );
        return;
      }

      // If not unlocked yet, persist cloud metadata and wait for unlock
      final unlocked = isImageUnlocked(latest);
      final url = latest.mediaUrls.isNotEmpty ? latest.mediaUrls.first : null;
      if (url == null) {
        AppLogging.signals('RESOLVE_IMAGE: no mediaUrl for ${signal.id}');
        return;
      }

      if (!unlocked) {
        // Save cloud state so other triggers can pick it up
        final updated = latest.copyWith(
          mediaUrls: latest.mediaUrls,
          imageState: ImageState.cloud,
        );
        await updateSignal(updated);
        AppLogging.signals(
          'RESOLVE_IMAGE_PENDING_UNLOCK signalId=${signal.id}',
        );
        return;
      }

      // Perform download (this will update DB and notify UI via updateSignal)
      AppLogging.signals(
        'RESOLVE_IMAGE_DOWNLOAD_START signalId=${signal.id} url=$url',
      );
      try {
        await _downloadAndCacheImage(signal.id, url);
        AppLogging.signals('RESOLVE_IMAGE_OK signalId=${signal.id}');
      } catch (e, st) {
        AppLogging.signals(
          'RESOLVE_IMAGE_ERROR signalId=${signal.id} error=$e\n$st',
        );
      }
    } finally {
      _imageResolveInProgress.remove(signal.id);
    }
  }

  /// Create a signal from a received mesh packet."
  ///
  /// signalId is required for creating a signal.
  ///
  /// Includes duplicate detection to prevent processing the same packet twice.
  /// - Dedupe by signalId in signals table
  Future<Post?> createSignalFromMesh({
    required String content,
    required int senderNodeId,
    String? signalId,
    int? packetId,
    int ttlMinutes = SignalTTL.defaultTTL,
    PostLocation? location,
    int? hopCount,
    bool allowCloud = true,
    bool hasPendingCloudImage = false,
    Map<String, dynamic>? presenceInfo,
  }) async {
    await init();

    if (signalId == null || signalId.isEmpty) {
      AppLogging.signals(
        'RX_DROP missing_signalId packetId=${packetId ?? "none"} '
        'sender=${senderNodeId.toRadixString(16)}',
      );
      return null;
    }

    if (packetId != null) {
      final key = MeshPacketKey(
        packetType: 'signal',
        senderNodeId: senderNodeId,
        packetId: packetId,
      );

      final seen = await _dedupeStore.hasSeen(
        key,
        ttl: Duration(minutes: _meshPacketTTLMinutes),
      );

      if (seen) {
        AppLogging.signals(
          'DEDUP_DROP signalId=$signalId packetId=$packetId reason=metadata',
        );
        return null;
      }

      await _dedupeStore.markSeen(
        key,
        ttl: Duration(minutes: _meshPacketTTLMinutes),
      );
    }

    // DEDUPLICATION LOGIC:
    // Dedupe strictly by signalId in signals table
    if (await _hasSignalById(signalId)) {
      AppLogging.signals('DEDUP_DROP signalId=$signalId reason=exists_in_db');
      return null;
    }
    AppLogging.signals(
      'DEDUP_ACCEPT signalId=$signalId packetId=${packetId ?? "none"}',
    );

    // Record node proximity
    await recordNodeProximity(senderNodeId);

    final now = DateTime.now();
    final expiresAt = now.add(Duration(minutes: ttlMinutes));

    AppLogging.signals(
      'Received mesh signal with id=$signalId from node $senderNodeId',
    );

    // TRACE: parsed packet
    AppLogging.signals(
      'RECV: mesh packet parsed signalId=$signalId '
      'packetId=${packetId ?? "none"} sender=${senderNodeId.toRadixString(16)}',
    );

    // Immediately create a local signal and persist to DB (offline-first).
    // Cloud lookup and enrichment happen asynchronously afterwards and MUST NOT
    // block the receive path.
    final signal = Post(
      id: signalId,
      authorId: 'mesh_${senderNodeId.toRadixString(16)}',
      content: content,
      mediaUrls: const [],
      location: location,
      nodeId: senderNodeId.toRadixString(16),
      createdAt: now,
      postMode: PostMode.signal,
      origin: SignalOrigin.mesh,
      expiresAt: expiresAt,
      meshNodeId: senderNodeId,
      hopCount: hopCount,
      imageState: ImageState.none,
      hasPendingCloudImage: hasPendingCloudImage,
      presenceInfo: presenceInfo,
    );

    AppLogging.signals('SIGNAL_DB_INSERT_START signalId=${signal.id}');
    await _saveSignalToDb(signal);
    AppLogging.signals(
      'SIGNAL_DB_INSERT_OK signalId=${signal.id} '
      'packetId=${packetId ?? "none"}',
    );

    // Attach comments/post listeners and perform an async enrichment step
    // in the background. Do not await - fire-and-forget.
    if (allowCloud) {
      AppLogging.signals('RECV: starting post listener posts/${signal.id}');
      _startPostListener(signal.id);
      AppLogging.signals(
        'RECV: starting comments listener posts/${signal.id}/comments',
      );
      _startCommentsListener(signal.id);
      if (cloudLookupOverride != null) {
        Future(() async {
          try {
            final cloudSignal = await cloudLookupOverride!(signal.id);
            AppLogging.signals(
              'RECV: override lookup exists=${cloudSignal != null} mediaUrls=${cloudSignal?.mediaUrls.length ?? 0}',
            );
            if (cloudSignal != null && cloudSignal.mediaUrls.isNotEmpty) {
              final existing = await getSignalById(signal.id);
              if (existing != null) {
                final updated = existing.copyWith(
                  mediaUrls: cloudSignal.mediaUrls,
                  imageState: ImageState.cloud,
                  commentCount: cloudSignal.commentCount,
                  hasPendingCloudImage: false,
                );
                await updateSignal(updated);
                AppLogging.signals(
                  'RECV: override lookup updated local signal with ${cloudSignal.mediaUrls.length} cloud images for ${signal.id}',
                );
              }
            }
          } catch (e, st) {
            AppLogging.signals(
              'RECV: override lookup error for ${signal.id}: $e\n$st',
            );
          }
        });
      }
    } else {
      AppLogging.signals(
        'RECV: cloud listeners skipped for ${signal.id} (mesh-only debug)',
      );
    }

    return signal;
  }

  /// Lookup a signal in Firestore by its deterministic ID.
  /// Returns the cloud signal document if it exists, null otherwise.
  /// This is the ONLY way to match mesh signals to cloud data.
  Future<Post?> _lookupCloudSignal(String signalId) async {
    if (_currentUserId == null) return null;

    try {
      AppLogging.signals('Looking up cloud signal: posts/$signalId');

      final doc = await _firestore.collection('posts').doc(signalId).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data()!;

      // Debug: log cloud doc fields for diagnostics
      final docKeys = data.keys.toList()..sort();
      final imageState = data['imageState'] as String?;
      final mediaUrls = data['mediaUrls'] as List<dynamic>?;
      final imageUrl = data['imageUrl'] as String?;
      final mediaUrl = data['mediaUrl'] as String?;

      AppLogging.signals('📷 Cloud doc keys: $docKeys');
      AppLogging.signals(
        '📷 imageState=$imageState, '
        'mediaUrlsCount=${mediaUrls?.length ?? 0}, '
        'hasImageUrl=${imageUrl != null && imageUrl.isNotEmpty}, '
        'hasMediaUrl=${mediaUrl != null && mediaUrl.isNotEmpty}',
      );

      final signal = Post.fromFirestore(doc);

      // Verify it's a signal and not expired
      if (signal.postMode != PostMode.signal) {
        AppLogging.signals('Cloud doc exists but is not a signal');
        return null;
      }

      if (signal.isExpired) {
        AppLogging.signals('Cloud signal exists but is expired');
        return null;
      }

      // Determine cloud image URLs
      // Priority: mediaUrls (multi-image) > imageUrl > mediaUrl (fallback)
      List<String> cloudMediaUrls = [];
      String usedField = 'none';

      if (signal.mediaUrls.isNotEmpty) {
        cloudMediaUrls = signal.mediaUrls;
        usedField = 'mediaUrls (${cloudMediaUrls.length} images)';
      } else if (imageUrl != null && imageUrl.isNotEmpty) {
        cloudMediaUrls = [imageUrl];
        usedField = 'imageUrl';
      } else if (mediaUrl != null && mediaUrl.isNotEmpty) {
        cloudMediaUrls = [mediaUrl];
        usedField = 'mediaUrl (fallback)';
      }

      if (cloudMediaUrls.isNotEmpty) {
        AppLogging.signals('📷 Cloud images detected via $usedField');
        // Return signal with all detected image URLs
        return signal.copyWith(
          mediaUrls: cloudMediaUrls,
          imageState: ImageState.cloud,
          hasPendingCloudImage: false,
        );
      }

      return signal;
    } catch (e) {
      AppLogging.signals('Error looking up cloud signal $signalId: $e');
      return null;
    }
  }

  /// Download and cache a cloud image locally.
  /// Updates SQLite with imageState=cloud and local cached path.
  /// Notifies providers so UI can rerender.
  Future<void> _downloadAndCacheImage(String signalId, String imageUrl) async {
    AppLogging.signals(
      '📷 Downloading cloud image for signal $signalId from: $imageUrl',
    );

    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        AppLogging.signals(
          '📷 Image download failed: HTTP ${response.statusCode}',
        );
        return;
      }

      AppLogging.signals(
        '📷 Image downloaded: ${response.bodyBytes.length} bytes',
      );

      // Save to local cache directory
      final documentsDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory(p.join(documentsDir.path, 'signals', 'cache'));
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final localPath = p.join(cacheDir.path, '$signalId.jpg');
      await File(localPath).writeAsBytes(response.bodyBytes);

      // Update local signal with cached path and cloud state
      // Preserve existing mediaUrls - don't overwrite with single URL
      final signal = await getSignalById(signalId);
      if (signal != null) {
        final updated = signal.copyWith(
          imageLocalPath: localPath,
          // Keep existing mediaUrls if present, otherwise use the downloaded URL
          mediaUrls: signal.mediaUrls.isNotEmpty
              ? signal.mediaUrls
              : [imageUrl],
          imageState: ImageState.cloud,
          hasPendingCloudImage: false,
        );
        await updateSignal(updated);
        AppLogging.signals(
          '📷 Image cached locally: $localPath, '
          'SQLite updated with imageState=cloud',
        );

        // Notify the feed stream so UI can rerender with the image
        // This is done by the updateSignal call which triggers DB change
      } else {
        AppLogging.signals('📷 Warning: signal $signalId not found in DB');
      }
    } catch (e) {
      AppLogging.signals('📷 Failed to download/cache image: $e');
    }
  }

  // ===========================================================================
  // DUPLICATE SIGNAL DETECTION
  // ===========================================================================

  Future<bool> _hasSignalById(String signalId) async {
    await init();

    final result = await _db!.query(
      _tableName,
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [signalId],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  // ===========================================================================
  // DATABASE OPERATIONS
  // ===========================================================================

  /// Save signal to SQLite database.
  Future<void> _saveSignalToDb(Post signal) async {
    await init();

    final map = _postToDbMap(signal);
    await _db!.insert(
      _tableName,
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Enforce max signal limit
    await _enforceMaxSignals();
  }

  /// Enforce maximum number of local signals.
  Future<void> _enforceMaxSignals() async {
    final count = Sqflite.firstIntValue(
      await _db!.rawQuery('SELECT COUNT(*) FROM $_tableName'),
    );

    if (count != null && count > _maxLocalSignals) {
      // Delete oldest expired signals first, then oldest by creation
      final deleteCount = count - _maxLocalSignals;
      await _db!.rawDelete(
        '''
        DELETE FROM $_tableName WHERE id IN (
          SELECT id FROM $_tableName
          ORDER BY 
            CASE WHEN expiresAt < ? THEN 0 ELSE 1 END,
            createdAt ASC
          LIMIT ?
        )
      ''',
        [DateTime.now().millisecondsSinceEpoch, deleteCount],
      );

      AppLogging.signals(
        'Trimmed $deleteCount old signals to maintain max limit',
      );
    }
  }

  /// Mark a signal as synced to cloud.
  Future<void> _markSignalSynced(String signalId) async {
    await init();

    await _db!.update(
      _tableName,
      {'syncedToCloud': 1},
      where: 'id = ?',
      whereArgs: [signalId],
    );
  }

  /// Get all local signals (including expired, for complete state).
  Future<List<Post>> getAllLocalSignals() async {
    await init();

    final rows = await _db!.query(
      _tableName,
      orderBy: 'expiresAt ASC, createdAt DESC',
    );

    return rows.map((row) => _postFromDbMap(row)).toList();
  }

  /// Get active (non-expired) local signals.
  Future<List<Post>> getActiveSignals() async {
    await init();

    final now = DateTime.now().millisecondsSinceEpoch;

    final rows = await _db!.query(
      _tableName,
      where: 'expiresAt IS NULL OR expiresAt > ?',
      whereArgs: [now],
      orderBy: 'expiresAt ASC, createdAt DESC',
    );

    final signals = rows.map((row) => _postFromDbMap(row)).toList();

    // Ensure comment listeners are attached for all active signals
    if (_currentUserId != null) {
      for (final signal in signals) {
        if (!_commentsListeners.containsKey(signal.id)) {
          _startCommentsListener(signal.id);
        }
      }
    }

    return signals;
  }

  /// Get a signal by ID.
  Future<Post?> getSignalById(String signalId) async {
    await init();

    final rows = await _db!.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [signalId],
    );

    if (rows.isEmpty) return null;
    return _postFromDbMap(rows.first);
  }

  /// Get a signal by ID from cloud (Firebase).
  /// This is a fallback when the signal is not in local database.
  Future<Post?> getSignalFromCloudById(String signalId) async {
    return _lookupCloudSignal(signalId);
  }

  /// Save a signal to the local database.
  /// Used when caching cloud signals locally (e.g., from activity notifications).
  Future<void> saveSignalLocally(Post signal) async {
    await _saveSignalToDb(signal);
    // Start listeners for this signal
    if (_currentUserId != null) {
      _startCommentsListener(signal.id);
      _startPostListener(signal.id);
    }
  }

  /// Update a signal in the database.
  Future<void> updateSignal(Post signal) async {
    await init();

    await _db!.update(
      _tableName,
      _postToDbMap(signal),
      where: 'id = ?',
      whereArgs: [signal.id],
    );
  }

  /// Delete a signal by ID.
  Future<void> deleteSignal(String signalId) async {
    await init();

    AppLogging.signals('Deleting signal: $signalId');

    // Stop listeners for this signal
    _stopCommentsListener(signalId);
    _stopPostListener(signalId);

    // Get signal to delete its image file
    final signal = await getSignalById(signalId);
    if (signal != null) {
      await _deleteSignalImage(signal.imageLocalPath);
    }

    // Delete cached cloud image if exists
    await _deleteCachedCloudImages([signalId]);

    // Delete comments for this signal
    await _db!.delete(
      _commentsTable,
      where: 'signalId = ?',
      whereArgs: [signalId],
    );

    await _db!.delete(_tableName, where: 'id = ?', whereArgs: [signalId]);

    // Also delete from Firebase if authenticated
    if (_currentUserId != null) {
      try {
        // Delete the post document (this doesn't delete subcollections)
        await _firestore.collection('posts').doc(signalId).delete();

        // Delete all comments in the subcollection
        final commentsSnapshot = await _firestore
            .collection('posts')
            .doc(signalId)
            .collection('comments')
            .get();
        for (final doc in commentsSnapshot.docs) {
          // Delete votes subcollection for each comment
          final votesSnapshot = await doc.reference.collection('votes').get();
          for (final voteDoc in votesSnapshot.docs) {
            await voteDoc.reference.delete();
          }
          await doc.reference.delete();
        }

        // Delete images from Firebase Storage if they exist
        if (signal != null && signal.mediaUrls.isNotEmpty) {
          try {
            // Delete all images with suffixes (_0, _1, _2, _3)
            // Only attempt deletion for non-empty URLs
            for (var i = 0; i < signal.mediaUrls.length; i++) {
              final url = signal.mediaUrls[i];
              if (url.isEmpty) continue; // Skip empty URLs

              try {
                final ref = _storage.ref(
                  'signals/$_currentUserId/${signalId}_$i.jpg',
                );
                await ref.delete();
                AppLogging.signals(
                  'Deleted signal image $i from Storage: $signalId',
                );
              } catch (storageError) {
                // Only log if it's not a simple "not found" error
                if (storageError.toString().contains('object-not-found')) {
                  AppLogging.signals(
                    'Signal image $i already deleted: $signalId',
                  );
                } else {
                  AppLogging.signals(
                    'Failed to delete signal image $i from Storage: $storageError',
                  );
                }
              }
            }
          } catch (e) {
            AppLogging.signals('Error deleting signal images from Storage: $e');
          }
        }
      } catch (e) {
        AppLogging.signals('Failed to delete signal from Firebase: $e');
      }
    }
  }

  /// Delete a signal from local storage only (without touching Firebase).
  /// Used when handling remote deletions from Firestore listener.
  Future<void> _deleteSignalLocally(String signalId) async {
    await init();

    AppLogging.signals('Deleting signal locally (remote deletion): $signalId');

    // Get signal to delete its image file
    final signal = await getSignalById(signalId);
    if (signal != null) {
      await _deleteSignalImage(signal.imageLocalPath);
    }

    // Delete cached cloud image if exists
    await _deleteCachedCloudImages([signalId]);

    // Delete comments for this signal
    await _db!.delete(
      _commentsTable,
      where: 'signalId = ?',
      whereArgs: [signalId],
    );

    // Delete from local database
    await _db!.delete(_tableName, where: 'id = ?', whereArgs: [signalId]);

    AppLogging.signals('Signal $signalId deleted locally');
  }

  // ===========================================================================
  // EXPIRY CLEANUP
  // ===========================================================================

  /// Clean up expired signals.
  /// Called on app resume and periodically.
  Future<int> cleanupExpiredSignals() async {
    await init();

    final now = DateTime.now().millisecondsSinceEpoch;

    // Get expired signals with their image paths
    final expiredRows = await _db!.query(
      _tableName,
      columns: ['id', 'expiresAt', 'imageLocalPath'],
      where: 'expiresAt IS NOT NULL AND expiresAt <= ?',
      whereArgs: [now],
    );

    if (expiredRows.isEmpty) {
      // Still cleanup expired comments even if no expired signals
      await _cleanupExpiredComments();
      return 0;
    }

    // Delete image files and log each expiry
    final expiredIds = <String>[];
    for (final row in expiredRows) {
      final id = row['id'] as String;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        row['expiresAt'] as int,
      );
      final imagePath = row['imageLocalPath'] as String?;

      AppLogging.signals('Signal expired: id=$id, expiredAt=$expiresAt');
      AppLogging.signals('CLEANUP_DELETE signalId=$id reason=expired');
      await _deleteSignalImage(imagePath);

      // Delete from Firebase Storage if authenticated
      if (_currentUserId != null) {
        try {
          final ref = _storage.ref('signals/$_currentUserId/$id.jpg');
          await ref.delete();
          AppLogging.signals('Deleted expired signal image from Storage: $id');
        } catch (storageError) {
          // Ignore - image may not exist in Storage
          AppLogging.signals(
            'Storage deletion skipped for expired signal (may not exist): $id',
          );
        }
      }

      // Stop cloud listeners for this signal
      _stopCommentsListener(id);
      _stopPostListener(id);

      expiredIds.add(id);
    }

    // Delete comments for expired signals
    if (expiredIds.isNotEmpty) {
      final placeholders = List.filled(expiredIds.length, '?').join(',');
      await _db!.rawDelete(
        'DELETE FROM $_commentsTable WHERE signalId IN ($placeholders)',
        expiredIds,
      );
    }

    // Delete cached cloud images for expired signals
    await _deleteCachedCloudImages(expiredIds);

    // Delete expired signals
    final deletedCount = await _db!.delete(
      _tableName,
      where: 'expiresAt IS NOT NULL AND expiresAt <= ?',
      whereArgs: [now],
    );

    final remaining = Sqflite.firstIntValue(
      await _db!.rawQuery('SELECT COUNT(*) FROM $_tableName'),
    );
    AppLogging.signals(
      'Cleanup complete: removed $deletedCount expired signals, remaining=${remaining ?? 0}',
    );

    // Also cleanup old mesh packet entries, proximity data, and comments
    await _dedupeStore.cleanup(ttl: Duration(minutes: _meshPacketTTLMinutes));
    await _cleanupOldProximityData();
    await _cleanupExpiredComments();

    return deletedCount;
  }

  /// Clean up expired comments (those whose expiresAt has passed).
  Future<void> _cleanupExpiredComments() async {
    await init();

    final now = DateTime.now().millisecondsSinceEpoch;
    final deleted = await _db!.delete(
      _commentsTable,
      where: 'expiresAt < ?',
      whereArgs: [now],
    );

    if (deleted > 0) {
      AppLogging.signals('Cleaned up $deleted expired comments');
    }
  }

  /// Clean up old proximity tracking data.
  Future<void> _cleanupOldProximityData() async {
    await init();

    final cutoff = DateTime.now()
        .subtract(
          Duration(minutes: ImageUnlockRules.proximityWindowMinutes * 2),
        )
        .millisecondsSinceEpoch;

    final deleted = await _db!.delete(
      _proximityTable,
      where: 'seenAt < ?',
      whereArgs: [cutoff],
    );

    if (deleted > 0) {
      AppLogging.signals('Cleaned up $deleted old proximity entries');
    }
  }

  // ===========================================================================
  // CLOUD SYNC RETRY
  // ===========================================================================

  /// Handle auth changes by restarting listeners and retrying cloud lookups.
  /// Call this when auth state changes to avoid silent listener stalls.
  Future<void> handleAuthChanged() async {
    if (_currentUserId == null) {
      _stopAllCommentsListeners();
      _stopAllPostListeners();
      _stopAllVoteListeners();
      _cloudComments.clear();
      _myVotesCache.clear();
      _postDocumentSeen.clear();
      return;
    }

    await init();
    final signals = await getActiveSignals();
    for (final signal in signals) {
      _startCommentsListener(signal.id);
      _startPostListener(signal.id);
      startVoteListener(signal.id);
    }
    await retryCloudLookups();
  }

  /// Retry cloud lookups for signals that may have been received while offline.
  ///
  /// Scans active signals that:
  /// - Have no image (imageState == none)
  /// - Might have cloud data we couldn't fetch when offline
  ///
  /// For each, attempts to lookup cloud document and attach listeners.
  /// Called on app resume and when auth state changes.
  Future<int> retryCloudLookups() async {
    if (_currentUserId == null) {
      AppLogging.signals('📡 Cloud retry: skipping - not authenticated');
      return 0;
    }

    await init();

    final now = DateTime.now().millisecondsSinceEpoch;

    // Find active signals without images that might have cloud data
    final rows = await _db!.query(
      _tableName,
      where: '''
        (expiresAt IS NULL OR expiresAt > ?)
        AND (imageState IS NULL OR imageState = 'none')
        AND (imageLocalPath IS NULL OR imageLocalPath = '')
        AND (mediaUrls IS NULL OR mediaUrls = '[]')
      ''',
      whereArgs: [now],
    );

    if (rows.isEmpty) {
      AppLogging.signals('📡 Cloud retry: no signals need cloud lookup');
      return 0;
    }

    AppLogging.signals(
      '📡 Cloud retry: checking ${rows.length} signals for cloud data',
    );

    var updatedCount = 0;

    for (final row in rows) {
      final signal = _postFromDbMap(row);
      // Skip if already has a post listener
      if (_postListeners.containsKey(signal.id)) {
        continue;
      }

      // Attempt cloud lookup
      try {
        final cloudSignal = await _lookupCloudSignal(signal.id);

        if (cloudSignal != null && cloudSignal.mediaUrls.isNotEmpty) {
          AppLogging.signals(
            '📡 Cloud retry: found ${cloudSignal.mediaUrls.length} images for ${signal.id}',
          );

          // Update local signal with cloud data (all images)
          final updated = signal.copyWith(
            mediaUrls: cloudSignal.mediaUrls,
            imageState: ImageState.cloud,
            commentCount: cloudSignal.commentCount,
            hasPendingCloudImage: false,
          );
          await updateSignal(updated);
          updatedCount++;

          // Attempt idempotent resolver (downloads if unlocked)
          try {
            resolveSignalImageIfNeeded(updated);
          } catch (e) {
            AppLogging.signals(
              '📡 Cloud retry: resolver error for ${signal.id}: $e',
            );
          }
        }

        // Start listeners for ongoing updates (even if no image yet)
        _startPostListener(signal.id);
        if (!_commentsListeners.containsKey(signal.id)) {
          _startCommentsListener(signal.id);
        }

        // Also attempt to resolve any pending images for this signal
        if (signal.mediaUrls.isNotEmpty &&
            (signal.imageLocalPath == null || signal.imageLocalPath!.isEmpty)) {
          try {
            resolveSignalImageIfNeeded(signal);
          } catch (e) {
            AppLogging.signals(
              '📡 Cloud retry: resolver error for ${signal.id}: $e',
            );
          }
        }
      } catch (e) {
        AppLogging.signals('📡 Cloud retry: failed for ${signal.id}: $e');
      }
    }

    if (updatedCount > 0) {
      AppLogging.signals(
        '📡 Cloud retry complete: updated $updatedCount signals with cloud data',
      );
    }

    return updatedCount;
  }

  /// Attempt to resolve all pending images (download/cache) for signals
  /// that have cloud media URLs but no local cached file. Safe to call
  /// repeatedly; idempotent.
  Future<void> attemptResolveAllPendingImages() async {
    await init();

    final rows = await _db!.query(
      _tableName,
      where:
          'mediaUrls IS NOT NULL AND (imageLocalPath IS NULL OR imageLocalPath = "")',
    );

    for (final row in rows) {
      final signal = _postFromDbMap(row);
      if (signal.mediaUrls.isNotEmpty) {
        AppLogging.signals('RESOLVE_BATCH signalId=${signal.id}');
        // Fire-and-forget (resolver handles in-progress guard)
        Future.microtask(() => resolveSignalImageIfNeeded(signal));
      }
    }
  }

  // ===========================================================================
  // FIREBASE SYNC
  // ===========================================================================

  /// Save signal to Firebase.
  /// NEVER uploads expired signals.
  Future<void> _saveSignalToFirebase(Post signal) async {
    if (_currentUserId == null) return;

    // Critical check: never upload expired signals
    if (signal.isExpired) {
      AppLogging.signals(
        'Refusing to upload expired signal ${signal.id} to Firebase',
      );
      return;
    }

    await _firestore
        .collection('posts')
        .doc(signal.id)
        .set(signal.toFirestore());
  }

  /// Upload local image to Firebase Storage.
  /// Returns the download URL or null if failed.
  ///
  /// Only uploads if:
  /// 1. User is authenticated
  /// 2. Signal is NOT expired
  /// 3. Image unlock rules are satisfied
  ///
  /// Set [skipFirestoreUpdate] to true when doing batch uploads - the caller
  /// will handle the final Firestore update with all URLs.
  Future<String?> uploadSignalImage(
    String signalId,
    String localPath, {
    String storageSuffix = '',
    bool skipFirestoreUpdate = false,
  }) async {
    final currentUid = _currentUserId;
    if (currentUid == null) {
      AppLogging.signals('Cannot upload image: not authenticated');
      return null;
    }

    // Get the signal to check expiry and unlock rules
    final signal = await getSignalById(signalId);
    if (signal == null) {
      AppLogging.signals('Cannot upload image: signal not found');
      return null;
    }

    if (signal.isExpired) {
      AppLogging.signals(
        'Refusing to upload image for expired signal $signalId',
      );
      return null;
    }

    if (!isImageUnlocked(signal)) {
      AppLogging.signals(
        'Cannot upload image: unlock rules not satisfied for signal $signalId',
      );
      return null;
    }

    try {
      final file = File(localPath);
      if (!await file.exists()) {
        AppLogging.signals('📷 UPLOAD FAILED: file not found at $localPath');
        return null;
      }

      AppLogging.signals(
        '📷 UPLOAD START: signal $signalId$storageSuffix, file=$localPath',
      );

      // Step 1: Upload to Firebase Storage
      final ref = _storage.ref(
        'signals/$currentUid/$signalId$storageSuffix.jpg',
      );
      final uploadTask = ref.putFile(file);

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes * 100;
        AppLogging.signals(
          '📷 UPLOAD PROGRESS: ${progress.toStringAsFixed(1)}%',
        );
      });

      await uploadTask;
      final url = await ref.getDownloadURL();

      AppLogging.signals(
        '📷 STORAGE UPLOAD SUCCESS: signal $signalId$storageSuffix, URL=$url',
      );

      // Step 2: Validate image with Cloud Function
      try {
        final functions = FirebaseFunctions.instance;
        final result = await functions.httpsCallable('validateImages').call({
          'imageUrls': [url],
        });
        AppLogging.signals('📷 validateImages response: ${result.data}');

        final validationResult = result.data as Map<String, dynamic>;
        if (validationResult['passed'] == false) {
          AppLogging.signals(
            '📷 VALIDATION FAILED: ${validationResult['message']}',
          );
          // Delete the uploaded image
          try {
            await ref.delete();
            AppLogging.signals('📷 Deleted invalid image from storage');
          } catch (deleteError) {
            AppLogging.signals(
              '📷 Failed to delete invalid image: $deleteError',
            );
          }
          return null;
        }
        AppLogging.signals('📷 Image passed validation');
      } catch (e) {
        AppLogging.signals('📷 validateImages error: $e');
        // Validation service error - delete the image and reject
        try {
          await ref.delete();
          AppLogging.signals('📷 Deleted image after validation service error');
        } catch (deleteError) {
          AppLogging.signals('📷 Failed to delete image: $deleteError');
        }
        return null;
      }

      // Step 3: Update Firestore FIRST (if not expired)
      // Skip Firestore update during batch uploads - the final batch update will handle it
      if (!signal.isExpired && !skipFirestoreUpdate) {
        final firestoreSuccess = await _updateFirestoreImageFields(
          signalId: signalId,
          url: url,
          authorId: signal.authorId,
          currentUid: currentUid,
        );

        if (firestoreSuccess) {
          // Step 4: Only update local DB after Firestore succeeds
          // Preserve existing mediaUrls and add new one if not already present
          final existingUrls = signal.mediaUrls.toList();
          if (!existingUrls.contains(url)) {
            existingUrls.add(url);
          }
          final updated = signal.copyWith(
            mediaUrls: existingUrls.isEmpty ? [url] : existingUrls,
            imageState: ImageState.cloud,
            hasPendingCloudImage: false,
          );
          await updateSignal(updated);
          AppLogging.signals(
            '📷 LOCAL DB UPDATED: signal $signalId, imageState=cloud',
          );
          AppLogging.signals(
            '📷 UPLOAD COMPLETE: signal $signalId uploaded successfully',
          );
          return url;
        } else {
          // Firestore failed - queue for retry but return URL since Storage succeeded
          _queueImageRetry(signalId, url);
          AppLogging.signals(
            '📷 UPLOAD PARTIAL: signal $signalId storage OK, Firestore queued for retry',
          );
          return url;
        }
      } else {
        AppLogging.signals(
          '📷 FIRESTORE SKIP: signal $signalId expired, not writing to cloud',
        );
        return url;
      }
    } catch (e, stackTrace) {
      AppLogging.signals(
        '📷 UPLOAD FAILED: signal $signalId, error=$e\n$stackTrace',
      );
      return null;
    }
  }

  /// Update Firestore with image fields using update() to only touch allowed fields.
  /// Returns true on success, false on failure.
  Future<bool> _updateFirestoreImageFields({
    required String signalId,
    required String url,
    required String authorId,
    required String currentUid,
  }) async {
    // Diagnostic logging before write attempt
    AppLogging.signals(
      '📷 FIRESTORE PRE-WRITE DIAGNOSTIC:\n'
      '  - signalId: $signalId\n'
      '  - currentUid: $currentUid\n'
      '  - signal.authorId: $authorId\n'
      '  - uid == authorId: ${currentUid == authorId}\n'
      '  - fields to write: [mediaUrls, imageUrl, imageState]',
    );

    if (currentUid != authorId) {
      AppLogging.signals(
        '📷 FIRESTORE WRITE BLOCKED: uid mismatch! '
        'currentUid=$currentUid, authorId=$authorId',
      );
      return false;
    }

    try {
      // Use update() with ONLY the fields allowed by Firestore rules
      // Rules allow author to update: mediaUrls, imageState, imageUrl
      await _firestore.collection('posts').doc(signalId).update({
        'mediaUrls': [url],
        'imageUrl': url,
        'imageState': ImageState.cloud.name,
      });

      AppLogging.signals(
        '📷 FIRESTORE WRITE SUCCESS: posts/$signalId '
        'mediaUrls=[url], imageState=cloud',
      );
      return true;
    } catch (e) {
      AppLogging.signals(
        '📷 FIRESTORE WRITE FAILED: posts/$signalId, error=$e',
      );
      return false;
    }
  }

  /// Queue a failed Firestore image update for retry.
  void _queueImageRetry(String signalId, String url) {
    // Remove any existing retry for this signal
    _pendingImageUpdates.remove(signalId);

    final pending = _PendingImageUpdate(signalId: signalId, url: url);
    pending.scheduleRetry();
    _pendingImageUpdates[signalId] = pending;

    AppLogging.signals(
      '📷 RETRY QUEUED: signal $signalId, '
      'attempt ${pending.attemptCount}, '
      'next retry at ${pending.nextRetryTime.toIso8601String()}',
    );
  }

  /// Process pending image updates (called by timer).
  Future<void> _processPendingImageUpdates() async {
    if (_pendingImageUpdates.isEmpty) return;
    if (_currentUserId == null) return;

    final currentUid = _currentUserId!;
    final toRemove = <String>[];

    for (final entry in _pendingImageUpdates.entries) {
      final signalId = entry.key;
      final pending = entry.value;

      // Check if signal has expired
      final signal = await getSignalById(signalId);
      if (signal == null || signal.isExpired) {
        AppLogging.signals(
          '📷 RETRY CANCELLED: signal $signalId expired or deleted',
        );
        toRemove.add(signalId);
        continue;
      }

      // Check if we've exceeded max attempts
      if (pending.shouldGiveUp) {
        AppLogging.signals(
          '📷 RETRY ABANDONED: signal $signalId after ${pending.attemptCount} attempts',
        );
        toRemove.add(signalId);
        continue;
      }

      // Check if it's time to retry
      if (!pending.isReady) continue;

      AppLogging.signals(
        '📷 RETRY ATTEMPT ${pending.attemptCount + 1}: signal $signalId',
      );

      final success = await _updateFirestoreImageFields(
        signalId: signalId,
        url: pending.url,
        authorId: signal.authorId,
        currentUid: currentUid,
      );

      if (success) {
        // Update local DB now that Firestore succeeded
        // Preserve existing mediaUrls and add new one if not already present
        final existingUrls = signal.mediaUrls.toList();
        if (!existingUrls.contains(pending.url)) {
          existingUrls.add(pending.url);
        }
        final updated = signal.copyWith(
          mediaUrls: existingUrls.isEmpty ? [pending.url] : existingUrls,
          imageState: ImageState.cloud,
          hasPendingCloudImage: false,
        );
        await updateSignal(updated);
        AppLogging.signals(
          '📷 RETRY SUCCESS: signal $signalId, local DB updated',
        );
        toRemove.add(signalId);
      } else {
        // Schedule next retry with backoff
        pending.scheduleRetry();
        AppLogging.signals(
          '📷 RETRY FAILED: signal $signalId, '
          'attempt ${pending.attemptCount}, '
          'next retry at ${pending.nextRetryTime.toIso8601String()}',
        );
      }
    }

    // Remove completed/abandoned retries
    for (final signalId in toRemove) {
      _pendingImageUpdates.remove(signalId);
    }
  }

  /// Fetch signals from Firebase (for authenticated users).
  /// Only fetches non-expired signals.
  Future<List<Post>> fetchCloudSignals({int limit = 50}) async {
    if (_currentUserId == null) return [];

    try {
      final query = await _firestore
          .collection('posts')
          .where('postMode', isEqualTo: PostMode.signal.name)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .orderBy('expiresAt')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return query.docs.map((doc) => Post.fromFirestore(doc)).toList();
    } catch (e) {
      AppLogging.signals('Failed to fetch cloud signals: $e');
      return [];
    }
  }

  // ===========================================================================
  // RESPONSE CLOUD SYNC (Real-time sync for shared signals)
  // ===========================================================================

  /// Ensure the comments listener is active for a signal.
  /// Call this when viewing a signal detail screen to receive real-time updates.
  void ensureCommentsListener(String signalId) {
    _startCommentsListener(signalId);
    startVoteListener(signalId);
  }

  /// Start listening for cloud comments on a signal.
  /// Called when signal is created or received via mesh.
  /// Uses canonical path: posts/{signalId}/comments
  void _startCommentsListener(String signalId) {
    // Skip if not authenticated or already listening
    if (_currentUserId == null) {
      AppLogging.signals(
        '📡 Comments listener: skipping $signalId - not authenticated',
      );
      return;
    }
    if (_commentsListeners.containsKey(signalId)) {
      AppLogging.signals('📡 Comments listener: already active for $signalId');
      return;
    }

    AppLogging.signals(
      '📡 Comments listener: ATTACHING posts/$signalId/comments',
    );

    final subscription = _firestore
        .collection('posts')
        .doc(signalId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .limit(200)
        .snapshots()
        .listen(
          (snapshot) async {
            final comments = snapshot.docs
                .map(
                  (doc) =>
                      SignalResponse.fromFirestoreComment(doc.id, doc.data()),
                )
                .toList();

            // Get latest timestamp for logging
            final latestCreatedAt = comments.isNotEmpty
                ? comments.last.createdAt.toIso8601String()
                : 'none';

            AppLogging.signals(
              '📡 Comments listener: snapshot for $signalId: '
              'docs=${snapshot.docs.length}, latestCreatedAt=$latestCreatedAt',
            );

            // Update cloud comments cache (replaces, not appends)
            _cloudComments[signalId] = comments;

            // Notify listeners that comments have updated
            _commentUpdateController.add(signalId);

            // Persist cloud comments to local DB for offline access
            if (_db != null) {
              for (final comment in comments) {
                await _db!.insert(_commentsTable, {
                  'id': comment.id,
                  'signalId': comment.signalId,
                  'content': comment.content,
                  'authorId': comment.authorId,
                  'authorName': comment.authorName,
                  'parentId': comment.parentId,
                  'depth': comment.depth,
                  'createdAt': comment.createdAt.millisecondsSinceEpoch,
                  'expiresAt': comment.expiresAt.millisecondsSinceEpoch,
                  'score': comment.score,
                  'upvoteCount': comment.upvoteCount,
                  'downvoteCount': comment.downvoteCount,
                  'replyCount': comment.replyCount,
                  'isDeleted': comment.isDeleted ? 1 : 0,
                }, conflictAlgorithm: ConflictAlgorithm.replace);
              }
              AppLogging.signals(
                '📡 Comments listener: persisted ${comments.length} comments to local DB',
              );
            }

            // Update local DB comment count
            final signal = await getSignalById(signalId);
            if (signal != null && signal.commentCount != comments.length) {
              await _db!.update(
                _tableName,
                {'commentCount': comments.length},
                where: 'id = ?',
                whereArgs: [signalId],
              );
              AppLogging.signals(
                '📡 Comments listener: updated local commentCount to ${comments.length}',
              );
            }

            // Note: UI now refreshes via _commentUpdateController stream
          },
          onError: (e, stackTrace) {
            AppLogging.signals(
              '📡 Comments listener ERROR for $signalId: $e\n'
              'StackTrace: $stackTrace\n'
              'UserId: $_currentUserId\n'
              'Path: posts/$signalId/comments',
            );
            _commentsListeners.remove(signalId)?.cancel();
            _scheduleListenerRetry(signalId, 'comments');
          },
        );

    _commentsListeners[signalId] = subscription;
    _clearListenerRetry(signalId, 'comments');
    AppLogging.signals(
      '📡 Comments listener: subscription stored for $signalId '
      '(total active: ${_commentsListeners.length})',
    );
  }

  /// Stop listening for cloud comments on a signal.
  /// Called when signal expires or is deleted.
  void _stopCommentsListener(String signalId) {
    final subscription = _commentsListeners.remove(signalId);
    if (subscription != null) {
      subscription.cancel();
      AppLogging.signals('📡 Stopped comments listener for signal $signalId');
    }
    _clearListenerRetry(signalId, 'comments');
    // Also stop vote listener for this signal
    stopVoteListener(signalId);
  }

  /// Stop all comments listeners (for cleanup on dispose).
  void _stopAllCommentsListeners() {
    for (final entry in _commentsListeners.entries) {
      entry.value.cancel();
      _clearListenerRetry(entry.key, 'comments');
      AppLogging.signals(
        '📡 Stopped comments listener for signal ${entry.key}',
      );
    }
    _commentsListeners.clear();
  }

  // ===========================================================================
  // POST DOCUMENT CLOUD SYNC (Real-time sync for signal documents)
  // ===========================================================================

  /// Start listening for cloud signal document updates.
  /// Called when a mesh signal is received - listens for cloud doc to appear
  /// or be updated (e.g. image upload completes after initial mesh broadcast).
  ///
  /// Keeps listener active until signal expires or is deleted.
  /// On every snapshot:
  /// - If doc does not exist → wait (sender may still be uploading)
  /// - If doc exists → update local signal with cloud data
  /// - If mediaUrls transitions from empty → non-empty → start resolver
  /// - Update commentCount from cloud
  void _startPostListener(String signalId) {
    // Skip if not authenticated or already listening
    if (_currentUserId == null) {
      AppLogging.signals(
        '📡 Post listener: skipping $signalId - not authenticated',
      );
      return;
    }
    if (_postListeners.containsKey(signalId)) {
      AppLogging.signals('📡 Post listener: already active for $signalId');
      return;
    }

    AppLogging.signals('📡 Post listener: ATTACHING to posts/$signalId');

    final subscription = _firestore
        .collection('posts')
        .doc(signalId)
        .snapshots()
        .listen(
          (snapshot) async {
            AppLogging.signals(
              '📡 Post listener: snapshot received for $signalId, '
              'exists=${snapshot.exists}',
            );

            if (!snapshot.exists) {
              // If we have previously observed that this posts/$signalId doc
              // existed and now it does not, treat as a deletion by the author
              // and remove the local signal. However, if we've never seen the
              // doc exist yet, it may simply not have been uploaded yet (common
              // when receiving signals offline). In that case, do NOT delete;
              // wait for the doc to appear.
              final hadExisted = _postDocumentSeen[signalId] == true;

              // Check if we have this signal locally
              final localSignal = await getSignalById(signalId);

              if (!hadExisted) {
                AppLogging.signals(
                  '📡 Post listener: doc posts/$signalId does NOT exist yet - waiting (no prior presence)',
                );
                return;
              }

              if (localSignal != null) {
                AppLogging.signals(
                  '📡 Post listener: doc posts/$signalId DELETED by author - removing locally',
                );

                // Delete locally (without trying to delete from Firestore again)
                await _deleteSignalLocally(signalId);

                // Notify UI to remove from feed
                _remoteDeleteController.add(signalId);

                // Stop this listener
                _stopPostListener(signalId);
                _stopCommentsListener(signalId);
              } else {
                AppLogging.signals(
                  '📡 Post listener: doc posts/$signalId does NOT exist yet - waiting (no local signal)',
                );
              }

              return;
            }

            final data = snapshot.data()!;

            // Extract all relevant fields
            final mediaUrls = data['mediaUrls'] as List<dynamic>?;
            final imageUrl = data['imageUrl'] as String?;
            final mediaUrl = data['mediaUrl'] as String?;
            final cloudCommentCount = data['commentCount'] as int? ?? 0;

            // Determine cloud image URLs (support multiple images)
            List<String> cloudMediaUrls = [];
            if (mediaUrls != null && mediaUrls.isNotEmpty) {
              cloudMediaUrls = mediaUrls.map((e) => e as String).toList();
            } else if (imageUrl != null && imageUrl.isNotEmpty) {
              cloudMediaUrls = [imageUrl];
            } else if (mediaUrl != null && mediaUrl.isNotEmpty) {
              cloudMediaUrls = [mediaUrl];
            }

            AppLogging.signals(
              '📡 Post listener: doc posts/$signalId exists: '
              'mediaUrls.length=${cloudMediaUrls.length}, '
              'hasCloudImages=${cloudMediaUrls.isNotEmpty}, '
              'commentCount=$cloudCommentCount',
            );

            // Record that the cloud post document exists. This allows us to
            // detect later transitions to not-exist as deletions by the author.
            _postDocumentSeen[signalId] = true;

            // Get current local signal state
            final signal = await getSignalById(signalId);
            if (signal == null) {
              AppLogging.signals(
                '📡 Post listener: signal $signalId not found in local DB - '
                'may have been cleaned up',
              );
              return;
            }

            // Track what we need to update
            var needsUpdate = false;
            var updatedSignal = signal;

            // Update commentCount if changed
            if (signal.commentCount != cloudCommentCount) {
              AppLogging.signals(
                '📡 Post listener: updating commentCount '
                '${signal.commentCount} → $cloudCommentCount',
              );
              updatedSignal = updatedSignal.copyWith(
                commentCount: cloudCommentCount,
              );
              needsUpdate = true;
            }

            // Handle images: check if cloud has images and we don't have them locally
            final hasLocalImage =
                signal.imageLocalPath != null &&
                signal.imageLocalPath!.isNotEmpty;

            if (cloudMediaUrls.isNotEmpty && !hasLocalImage) {
              AppLogging.signals(
                '📡 Post listener: ${cloudMediaUrls.length} cloud images detected, local missing',
              );

              // Update signal with all cloud URLs + mark as cloud (persist)
              updatedSignal = updatedSignal.copyWith(
                mediaUrls: cloudMediaUrls,
                imageState: ImageState.cloud,
                hasPendingCloudImage: false,
              );
              needsUpdate = true;

              // Schedule resolver to perform download if allowed
              // This is idempotent and safe to call repeatedly.
              try {
                resolveSignalImageIfNeeded(updatedSignal);
              } catch (e) {
                AppLogging.signals(
                  '📡 Post listener: resolver error for $signalId: $e',
                );
              }
            }

            // Save any pending updates
            if (needsUpdate) {
              await updateSignal(updatedSignal);
              AppLogging.signals(
                '📡 Post listener: local signal $signalId updated',
              );
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            AppLogging.signals(
              '📡 Post listener ERROR for $signalId: $error\n$stackTrace',
            );
            _postListeners.remove(signalId)?.cancel();
            _scheduleListenerRetry(signalId, 'post');
          },
        );

    _postListeners[signalId] = subscription;
    _clearListenerRetry(signalId, 'post');
    AppLogging.signals(
      '📡 Post listener: subscription stored for $signalId '
      '(total active: ${_postListeners.length})',
    );
  }

  /// Stop listening for cloud signal document updates.
  void _stopPostListener(String signalId) {
    final subscription = _postListeners.remove(signalId);
    // Also clear any seen-state tracking
    _postDocumentSeen.remove(signalId);
    if (subscription != null) {
      subscription.cancel();
      AppLogging.signals('📡 Stopped post listener for signal $signalId');
    }
    _clearListenerRetry(signalId, 'post');
  }

  /// Stop all post listeners (for cleanup on dispose).
  void _stopAllPostListeners() {
    for (final entry in _postListeners.entries) {
      entry.value.cancel();
      _clearListenerRetry(entry.key, 'post');
      AppLogging.signals('📡 Stopped post listener for signal ${entry.key}');
    }
    _postListeners.clear();
    _postDocumentSeen.clear();
  }

  // ===========================================================================
  // COMMENTS (Local + cloud sync)
  // ===========================================================================

  /// Create a comment on a signal.
  /// Stores locally in SQLite, syncs to Firestore for authenticated users.
  /// Use [parentId] to create a reply to another comment (threaded).
  Future<SignalResponse?> createResponse({
    required String signalId,
    required String content,
    String? authorName,
    String? parentId,
  }) async {
    await init();

    AppLogging.signals(
      '📝 createResponse: signalId=$signalId, parentId=$parentId',
    );

    if (_currentUserId == null) {
      AppLogging.signals('Cannot create response: user not authenticated');
      return null;
    }

    // Get parent signal to inherit expiresAt
    final signal = await getSignalById(signalId);
    if (signal == null) {
      AppLogging.signals('Cannot create response: signal not found');
      return null;
    }

    if (signal.isExpired) {
      AppLogging.signals('Cannot create response: signal has expired');
      return null;
    }

    final id = _uuid.v4();
    final now = DateTime.now();
    final response = SignalResponse(
      id: id,
      signalId: signalId,
      content: content,
      authorId: _currentUserId!,
      authorName: authorName,
      parentId: parentId,
      createdAt: now,
      expiresAt: signal.expiresAt ?? now.add(const Duration(hours: 1)),
    );

    await _db!.insert(_commentsTable, {
      'id': response.id,
      'signalId': response.signalId,
      'content': response.content,
      'authorId': response.authorId,
      'authorName': response.authorName,
      'parentId': response.parentId,
      'depth': response.depth,
      'createdAt': response.createdAt.millisecondsSinceEpoch,
      'expiresAt': response.expiresAt.millisecondsSinceEpoch,
      'score': response.score,
      'upvoteCount': response.upvoteCount,
      'downvoteCount': response.downvoteCount,
      'replyCount': response.replyCount,
      'isDeleted': response.isDeleted ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Update comment count on parent signal
    final newCount = (signal.commentCount) + 1;
    await _db!.update(
      _tableName,
      {'commentCount': newCount},
      where: 'id = ?',
      whereArgs: [signalId],
    );

    AppLogging.signals('Created response for signal $signalId: ${response.id}');

    // Sync to Firestore for authenticated users (fire-and-forget)
    if (_currentUserId != null) {
      _syncResponseToFirestore(response);

      // Create activity for the appropriate user
      _createResponseActivity(
        response: response,
        signal: signal,
        parentId: parentId,
      );
    }

    return response;
  }

  /// Sync a response to Firestore using canonical comments path.
  /// Writes to posts/{signalId}/comments/{commentId} with serverTimestamp.
  void _syncResponseToFirestore(SignalResponse response) async {
    if (_currentUserId == null) {
      AppLogging.signals(
        '📡 Cannot sync comment: user not authenticated. '
        'SignalId: ${response.signalId}, CommentId: ${response.id}',
      );
      return;
    }

    try {
      // Write to canonical path: posts/{signalId}/comments/{commentId}
      await _firestore
          .collection('posts')
          .doc(response.signalId)
          .collection('comments')
          .doc(response.id)
          .set({
            'signalId': response.signalId,
            'content': response.content,
            'authorId': response.authorId,
            'authorName': response.authorName,
            if (response.parentId != null) 'parentId': response.parentId,
            'createdAt': FieldValue.serverTimestamp(),
            'origin': 'cloud',
          });

      // Update parent post's commentCount using transaction
      await _firestore.runTransaction((transaction) async {
        final postRef = _firestore.collection('posts').doc(response.signalId);
        final snapshot = await transaction.get(postRef);

        if (snapshot.exists) {
          final currentCount = snapshot.data()?['commentCount'] as int? ?? 0;
          transaction.update(postRef, {'commentCount': currentCount + 1});
        } else {
          // Post doesn't exist yet - create stub with commentCount
          transaction.set(postRef, {
            'commentCount': 1,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      });

      AppLogging.signals(
        '📡 Comment ${response.id} synced to posts/${response.signalId}/comments',
      );
    } catch (e, stackTrace) {
      AppLogging.signals(
        '📡 Failed to sync comment to Firestore: $e\n'
        'StackTrace: $stackTrace\n'
        'UserId: $_currentUserId\n'
        'SignalId: ${response.signalId}\n'
        'Path: posts/${response.signalId}/comments/${response.id}',
      );
    }
  }

  /// Create activity for a signal response (comment or reply).
  ///
  /// If [parentId] is null, creates signalComment activity for signal owner.
  /// If [parentId] is set, creates signalCommentReply activity for parent
  /// comment author.
  void _createResponseActivity({
    required SignalResponse response,
    required Post signal,
    String? parentId,
  }) async {
    AppLogging.signals(
      '📬 ACTIVITY_START: Creating activity for response ${response.id}\n'
      '  signalId: ${response.signalId}\n'
      '  signalAuthorId: ${signal.authorId}\n'
      '  responseAuthorId: ${response.authorId}\n'
      '  currentUserId: $_currentUserId\n'
      '  parentId: $parentId\n'
      '  isReply: ${parentId != null}',
    );

    try {
      final activityService = SocialActivityService(
        firestore: _firestore,
        auth: _auth,
      );

      // Truncate content preview to 100 chars
      final preview = response.content.length > 100
          ? '${response.content.substring(0, 100)}...'
          : response.content;

      AppLogging.signals(
        '📬 ACTIVITY_PREVIEW: "${preview.substring(0, preview.length.clamp(0, 50))}..."',
      );

      if (parentId != null) {
        // This is a reply - find the parent comment author
        AppLogging.signals(
          '📬 ACTIVITY_REPLY: Looking up parent comment $parentId',
        );
        final parentComment = await _getCommentById(
          response.signalId,
          parentId,
        );
        if (parentComment == null) {
          AppLogging.signals(
            '📬 ACTIVITY_SKIP: Parent comment $parentId not found',
          );
          return;
        }
        AppLogging.signals(
          '📬 ACTIVITY_PARENT_FOUND: authorId=${parentComment.authorId}',
        );
        if (parentComment.authorId == _currentUserId) {
          AppLogging.signals(
            '📬 ACTIVITY_SKIP: Not notifying self (replying to own comment)',
          );
          return;
        }
        AppLogging.signals(
          '📬 ACTIVITY_CREATE: signalCommentReply -> ${parentComment.authorId}\n'
          '  targetCollection: users/${parentComment.authorId}/activities',
        );
        await activityService.createSignalCommentReplyActivity(
          signalId: response.signalId,
          originalCommentAuthorId: parentComment.authorId,
          replyPreview: preview,
        );
        AppLogging.signals(
          '📬 ACTIVITY_SUCCESS: signalCommentReply created for ${parentComment.authorId}',
        );
      } else {
        // This is a top-level comment - notify signal owner
        // Resolve the real authorId - local DB may have mesh_ prefix for
        // signals received over mesh, but Firestore has the real authorId
        final realAuthorId = await _resolveSignalAuthorId(
          signal.id,
          signal.authorId,
        );

        if (realAuthorId == null) {
          AppLogging.signals(
            '📬 ACTIVITY_SKIP: Could not resolve real authorId for signal',
          );
          return;
        }

        if (realAuthorId == _currentUserId) {
          AppLogging.signals(
            '📬 ACTIVITY_SKIP: Not notifying self (commenting on own signal)',
          );
          return;
        }
        AppLogging.signals(
          '📬 ACTIVITY_CREATE: signalComment -> $realAuthorId\n'
          '  targetCollection: users/$realAuthorId/activities',
        );
        await activityService.createSignalCommentActivity(
          signalId: response.signalId,
          signalOwnerId: realAuthorId,
          commentPreview: preview,
        );
        AppLogging.signals(
          '📬 ACTIVITY_SUCCESS: signalComment created for $realAuthorId',
        );
      }
    } catch (e, stackTrace) {
      // Don't fail the response creation if activity creation fails
      AppLogging.signals(
        '📬 ACTIVITY_ERROR: Failed to create response activity\n'
        '  error: $e\n'
        '  stackTrace: $stackTrace',
      );
    }
  }

  /// Resolve the real authorId for a signal.
  ///
  /// Local DB may have mesh_ prefix for signals received over mesh, but
  /// Firestore has the real authorId from the original creator.
  /// Returns null if the signal has no real author (pure mesh signal).
  Future<String?> _resolveSignalAuthorId(
    String signalId,
    String localAuthorId,
  ) async {
    // If it's already a real Firebase UID, use it
    if (!localAuthorId.startsWith('mesh_')) {
      AppLogging.signals(
        '📬 AUTHOR_RESOLVE: Using local authorId (not mesh): $localAuthorId',
      );
      return localAuthorId;
    }

    AppLogging.signals(
      '📬 AUTHOR_RESOLVE: Local has mesh_ prefix, checking Firestore for '
      'real authorId',
    );

    try {
      final doc = await _firestore.collection('posts').doc(signalId).get();
      if (!doc.exists) {
        AppLogging.signals(
          '📬 AUTHOR_RESOLVE: Signal not in Firestore, no real author',
        );
        return null;
      }

      final data = doc.data()!;
      final firestoreAuthorId = data['authorId'] as String?;

      if (firestoreAuthorId == null) {
        AppLogging.signals('📬 AUTHOR_RESOLVE: Firestore doc has no authorId');
        return null;
      }

      if (firestoreAuthorId.startsWith('mesh_')) {
        AppLogging.signals(
          '📬 AUTHOR_RESOLVE: Firestore also has mesh_ authorId, '
          'no real user to notify',
        );
        return null;
      }

      AppLogging.signals(
        '📬 AUTHOR_RESOLVE: Found real authorId in Firestore: '
        '$firestoreAuthorId (local was: $localAuthorId)',
      );
      return firestoreAuthorId;
    } catch (e) {
      AppLogging.signals(
        '📬 AUTHOR_RESOLVE: Error fetching from Firestore: $e',
      );
      return null;
    }
  }

  /// Get a single comment by ID from local DB or cloud cache.
  Future<SignalResponse?> _getCommentById(
    String signalId,
    String commentId,
  ) async {
    AppLogging.signals(
      '📬 COMMENT_LOOKUP: signalId=$signalId, commentId=$commentId',
    );
    await init();

    // Check local DB first
    final rows = await _db!.query(
      _commentsTable,
      where: 'id = ? AND signalId = ?',
      whereArgs: [commentId, signalId],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      final row = rows.first;
      AppLogging.signals(
        '📬 COMMENT_FOUND: in local DB, authorId=${row['authorId']}',
      );
      return SignalResponse(
        id: row['id'] as String,
        signalId: row['signalId'] as String,
        content: row['content'] as String,
        authorId: row['authorId'] as String,
        authorName: row['authorName'] as String?,
        parentId: row['parentId'] as String?,
        depth: (row['depth'] as int?) ?? 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['createdAt'] as int),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(row['expiresAt'] as int),
      );
    }

    // Check cloud cache
    AppLogging.signals(
      '📬 COMMENT_LOOKUP: Not in local DB, checking cloud cache '
      '(${_cloudComments[signalId]?.length ?? 0} cached comments)',
    );
    final cloudComments = _cloudComments[signalId] ?? [];
    for (final comment in cloudComments) {
      if (comment.id == commentId) {
        AppLogging.signals(
          '📬 COMMENT_FOUND: in cloud cache, authorId=${comment.authorId}',
        );
        return comment;
      }
    }

    AppLogging.signals('📬 COMMENT_NOT_FOUND: $commentId');
    return null;
  }

  /// Get comments for a signal.
  /// Merges local (SQLite) and cloud (Firestore) comments, deduplicates.
  Future<List<SignalResponse>> getComments(String signalId) async {
    await init();

    final now = DateTime.now().millisecondsSinceEpoch;

    // Get local comments from SQLite
    final rows = await _db!.query(
      _commentsTable,
      where: 'signalId = ? AND expiresAt > ?',
      whereArgs: [signalId, now],
      orderBy: 'createdAt ASC',
    );

    // Get my votes from cache
    final myVotes = getMyVotesForSignal(signalId);

    final localComments = rows.map((row) {
      final id = row['id'] as String;
      return SignalResponse(
        id: id,
        signalId: row['signalId'] as String,
        content: row['content'] as String,
        authorId: row['authorId'] as String,
        authorName: row['authorName'] as String?,
        parentId: row['parentId'] as String?,
        depth: (row['depth'] as int?) ?? 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['createdAt'] as int),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(row['expiresAt'] as int),
        score: (row['score'] as int?) ?? 0,
        upvoteCount: (row['upvoteCount'] as int?) ?? 0,
        downvoteCount: (row['downvoteCount'] as int?) ?? 0,
        replyCount: (row['replyCount'] as int?) ?? 0,
        isDeleted: (row['isDeleted'] as int?) == 1,
        myVote: myVotes[id] ?? 0,
        isLocal: true,
      );
    }).toList();

    // Get cloud comments from cache (apply myVote)
    final cloudComments = (_cloudComments[signalId] ?? [])
        .map((r) => r.copyWith(myVote: myVotes[r.id] ?? 0))
        .toList();

    // Merge and deduplicate (local takes precedence)
    final localIds = localComments.map((r) => r.id).toSet();
    final uniqueCloudComments = cloudComments
        .where((r) => !localIds.contains(r.id) && !r.isExpired)
        .toList();

    final merged = [...localComments, ...uniqueCloudComments];
    merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Debug: log parentIds
    for (final r in merged) {
      if (r.parentId != null) {
        AppLogging.signals(
          '📝 Response ${r.id.substring(0, 8)} has parentId=${r.parentId?.substring(0, 8)}',
        );
      }
    }

    return merged;
  }

  /// Get comment count for a signal.
  Future<int> getCommentCount(String signalId) async {
    await init();

    final now = DateTime.now().millisecondsSinceEpoch;
    final result = Sqflite.firstIntValue(
      await _db!.rawQuery(
        'SELECT COUNT(*) FROM $_commentsTable '
        'WHERE signalId = ? AND expiresAt > ?',
        [signalId, now],
      ),
    );

    return result ?? 0;
  }

  // ===========================================================================
  // VOTING (Firestore-first - no local DB caching)
  // ===========================================================================

  /// Set a vote on a comment. Value should be 1 (upvote) or -1 (downvote).
  /// Writes directly to Firestore - Cloud Functions handle aggregation.
  Future<void> setVote({
    required String signalId,
    required String commentId,
    required int value,
  }) async {
    if (value != 1 && value != -1) {
      AppLogging.signals('Invalid vote value: $value (must be 1 or -1)');
      return;
    }

    final voterId = _currentUserId;
    if (voterId == null) {
      AppLogging.signals('Cannot vote: user not authenticated');
      return;
    }

    // Optimistic UI update
    _myVotesCache.putIfAbsent(signalId, () => {});
    _myVotesCache[signalId]![commentId] = value;
    _commentUpdateController.add(signalId);

    try {
      await _firestore
          .collection('posts')
          .doc(signalId)
          .collection('comments')
          .doc(commentId)
          .collection('votes')
          .doc(voterId)
          .set({
            'value': value,
            'voterId': voterId,
            'postId': signalId,
            'commentId': commentId,
            'createdAt': FieldValue.serverTimestamp(),
          });

      AppLogging.signals(
        '📊 Vote set: posts/$signalId/comments/$commentId/votes/$voterId = $value',
      );

      // Create activity for upvotes only (value == 1)
      // Downvotes don't create notifications
      if (value == 1) {
        _createVoteActivity(signalId: signalId, commentId: commentId);
      }
    } catch (e) {
      // Revert optimistic update on error
      _myVotesCache[signalId]?.remove(commentId);
      _commentUpdateController.add(signalId);
      AppLogging.signals('📊 Failed to set vote: $e');
      rethrow;
    }
  }

  /// Remove a vote from a comment.
  /// Deletes the vote doc from Firestore - Cloud Functions handle aggregation.
  Future<void> clearVote({
    required String signalId,
    required String commentId,
  }) async {
    final voterId = _currentUserId;
    if (voterId == null) {
      AppLogging.signals('Cannot clear vote: user not authenticated');
      return;
    }

    // Optimistic UI update
    final previousValue = _myVotesCache[signalId]?[commentId];
    _myVotesCache[signalId]?.remove(commentId);
    _commentUpdateController.add(signalId);

    try {
      await _firestore
          .collection('posts')
          .doc(signalId)
          .collection('comments')
          .doc(commentId)
          .collection('votes')
          .doc(voterId)
          .delete();

      AppLogging.signals(
        '📊 Vote cleared: posts/$signalId/comments/$commentId/votes/$voterId',
      );
    } catch (e) {
      // Revert optimistic update on error
      if (previousValue != null) {
        _myVotesCache.putIfAbsent(signalId, () => {});
        _myVotesCache[signalId]![commentId] = previousValue;
        _commentUpdateController.add(signalId);
      }
      AppLogging.signals('📊 Failed to clear vote: $e');
      rethrow;
    }
  }

  /// Create activity for an upvote on a signal response.
  ///
  /// Notifies the response author that someone upvoted their comment.
  void _createVoteActivity({
    required String signalId,
    required String commentId,
  }) async {
    AppLogging.signals(
      '📬 VOTE_ACTIVITY_START: Creating upvote activity\n'
      '  signalId: $signalId\n'
      '  commentId: $commentId\n'
      '  voterId: $_currentUserId',
    );

    try {
      // Get the comment to find its author
      final comment = await _getCommentById(signalId, commentId);
      if (comment == null) {
        AppLogging.signals(
          '📬 VOTE_ACTIVITY_SKIP: Comment $commentId not found',
        );
        return;
      }

      AppLogging.signals(
        '📬 VOTE_ACTIVITY_COMMENT: Found comment\n'
        '  authorId: ${comment.authorId}\n'
        '  authorName: ${comment.authorName}',
      );

      // Don't notify self-votes
      if (comment.authorId == _currentUserId) {
        AppLogging.signals(
          '📬 VOTE_ACTIVITY_SKIP: Not notifying self (upvoting own comment)',
        );
        return;
      }

      final activityService = SocialActivityService(
        firestore: _firestore,
        auth: _auth,
      );

      AppLogging.signals(
        '📬 VOTE_ACTIVITY_CREATE: signalResponseVote -> ${comment.authorId}\n'
        '  targetCollection: users/${comment.authorId}/activities',
      );

      await activityService.createSignalResponseVoteActivity(
        signalId: signalId,
        responseAuthorId: comment.authorId,
      );

      AppLogging.signals(
        '📬 VOTE_ACTIVITY_SUCCESS: signalResponseVote created for ${comment.authorId}',
      );
    } catch (e, stackTrace) {
      // Don't fail the vote if activity creation fails
      AppLogging.signals(
        '📬 VOTE_ACTIVITY_ERROR: Failed to create vote activity\n'
        '  error: $e\n'
        '  stackTrace: $stackTrace',
      );
    }
  }

  /// Get the user's vote for a comment from in-memory cache.
  /// Returns 1, -1, or 0 (no vote).
  int getMyVote(String signalId, String commentId) {
    return _myVotesCache[signalId]?[commentId] ?? 0;
  }

  /// Get all of the user's votes for a signal from in-memory cache.
  Map<String, int> getMyVotesForSignal(String signalId) {
    return Map.unmodifiable(_myVotesCache[signalId] ?? {});
  }

  /// Start listening for the current user's votes on a signal.
  /// Updates in-memory cache and notifies listeners when votes change.
  void startVoteListener(String signalId) {
    final voterId = _currentUserId;
    if (voterId == null) return;

    if (_voteListeners.containsKey(signalId)) {
      AppLogging.signals('📊 Vote listener already active for $signalId');
      return;
    }

    AppLogging.signals(
      '📊 Starting vote listener for posts/$signalId/comments/*/votes/$voterId',
    );

    // Query all vote docs for this user in this post's comments
    // Using collectionGroup requires postId and voterId fields in vote docs
    final subscription = _firestore
        .collectionGroup('votes')
        .where('postId', isEqualTo: signalId)
        .where('voterId', isEqualTo: voterId)
        .snapshots()
        .listen(
          (snapshot) {
            final newVotes = <String, int>{};
            for (final doc in snapshot.docs) {
              final data = doc.data();
              final commentId = data['commentId'] as String?;
              final value = data['value'] as int?;
              if (commentId != null && value != null) {
                newVotes[commentId] = value;
              }
            }

            _myVotesCache[signalId] = newVotes;
            _commentUpdateController.add(signalId);

            AppLogging.signals(
              '📊 Vote listener update for $signalId: ${newVotes.length} votes',
            );
          },
          onError: (e) {
            AppLogging.signals('📊 Vote listener error for $signalId: $e');
            _voteListeners.remove(signalId)?.cancel();
            _scheduleListenerRetry(signalId, 'votes');
          },
        );

    _voteListeners[signalId] = subscription;
    _clearListenerRetry(signalId, 'votes');
  }

  /// Stop listening for votes on a signal.
  void stopVoteListener(String signalId) {
    _voteListeners[signalId]?.cancel();
    _voteListeners.remove(signalId);
    _myVotesCache.remove(signalId);
    _clearListenerRetry(signalId, 'votes');
    AppLogging.signals('📊 Stopped vote listener for $signalId');
  }

  /// Stop all vote listeners.
  void _stopAllVoteListeners() {
    for (final subscription in _voteListeners.values) {
      subscription.cancel();
    }
    for (final signalId in _voteListeners.keys) {
      _clearListenerRetry(signalId, 'votes');
    }
    _voteListeners.clear();
    _myVotesCache.clear();
  }

  // ===========================================================================
  // DATABASE SERIALIZATION
  // ===========================================================================

  Map<String, dynamic> _postToDbMap(Post post) {
    return {
      'id': post.id,
      'authorId': post.authorId,
      'content': post.content,
      'mediaUrls': jsonEncode(post.mediaUrls),
      'locationLatitude': post.location?.latitude,
      'locationLongitude': post.location?.longitude,
      'locationName': post.location?.name,
      'nodeId': post.nodeId,
      'createdAt': post.createdAt.millisecondsSinceEpoch,
      'expiresAt': post.expiresAt?.millisecondsSinceEpoch,
      'commentCount': post.commentCount,
      'likeCount': post.likeCount,
      'authorSnapshotJson': post.authorSnapshot != null
          ? jsonEncode({
              'displayName': post.authorSnapshot!.displayName,
              'avatarUrl': post.authorSnapshot!.avatarUrl,
              'isVerified': post.authorSnapshot!.isVerified,
            })
          : null,
      'postMode': post.postMode.name,
      'origin': post.origin.name,
      'meshNodeId': post.meshNodeId,
      'hopCount': post.hopCount,
      'imageState': post.imageState.name,
      'imageLocalPath': post.imageLocalPath,
      'hasPendingCloudImage': post.hasPendingCloudImage ? 1 : 0,
    };
  }

  Post _postFromDbMap(Map<String, dynamic> map) {
    PostLocation? location;
    if (map['locationLatitude'] != null && map['locationLongitude'] != null) {
      location = PostLocation(
        latitude: (map['locationLatitude'] as num).toDouble(),
        longitude: (map['locationLongitude'] as num).toDouble(),
        name: map['locationName'] as String?,
      );
    }

    PostAuthorSnapshot? authorSnapshot;
    if (map['authorSnapshotJson'] != null) {
      final snapshotMap =
          jsonDecode(map['authorSnapshotJson'] as String)
              as Map<String, dynamic>;
      authorSnapshot = PostAuthorSnapshot(
        displayName: snapshotMap['displayName'] as String,
        avatarUrl: snapshotMap['avatarUrl'] as String?,
        isVerified: snapshotMap['isVerified'] as bool? ?? false,
      );
    }

    List<String> mediaUrls = const [];
    if (map['mediaUrls'] != null) {
      final decoded = jsonDecode(map['mediaUrls'] as String) as List<dynamic>;
      mediaUrls = decoded.map((e) => e as String).toList();
    }

    return Post(
      id: map['id'] as String,
      authorId: map['authorId'] as String,
      content: map['content'] as String? ?? '',
      mediaUrls: mediaUrls,
      location: location,
      nodeId: map['nodeId'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      expiresAt: map['expiresAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['expiresAt'] as int)
          : null,
      commentCount: map['commentCount'] as int? ?? 0,
      likeCount: map['likeCount'] as int? ?? 0,
      authorSnapshot: authorSnapshot,
      postMode: PostMode.values.firstWhere(
        (e) => e.name == (map['postMode'] as String?),
        orElse: () => PostMode.signal,
      ),
      origin: SignalOrigin.values.firstWhere(
        (e) => e.name == (map['origin'] as String?),
        orElse: () => SignalOrigin.mesh,
      ),
      meshNodeId: map['meshNodeId'] as int?,
      hopCount: map['hopCount'] as int?,
      imageState: ImageState.values.firstWhere(
        (e) => e.name == (map['imageState'] as String?),
        orElse: () => ImageState.none,
      ),
      imageLocalPath: map['imageLocalPath'] as String?,
      hasPendingCloudImage: (map['hasPendingCloudImage'] as int?) == 1
          ? true
          : false,
    );
  }

  /// Close the database connection and clean up listeners.
  Future<void> close() async {
    _authSubscription?.cancel();
    _authSubscription = null;
    _imageRetryTimer?.cancel();
    _imageRetryTimer = null;
    _pendingImageUpdates.clear();
    _stopAllCommentsListeners();
    _stopAllPostListeners();
    _stopAllVoteListeners();
    for (final timer in _listenerRetryTimers.values) {
      timer.cancel();
    }
    _listenerRetryTimers.clear();
    _listenerRetryCounts.clear();
    await _db?.close();
    _db = null;
    AppLogging.signals('SignalService database closed');
  }
}
