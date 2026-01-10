import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/logging.dart';
import '../models/social.dart';

/// Default signal TTL options in minutes.
class SignalTTL {
  static const int min15 = 15;
  static const int min30 = 30;
  static const int hour1 = 60;
  static const int hour6 = 360;
  static const int hour24 = 1440;

  static const int defaultTTL = hour1;

  static const List<int> options = [min15, min30, hour1, hour6, hour24];

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

/// A response to a signal.
/// Responses are stored locally in SQLite and synced to Firestore.
/// Only visible to users who have the signal locally (received via mesh).
class SignalResponse {
  final String id;
  final String signalId;
  final String content;
  final String authorId;
  final String? authorName;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isLocal; // true if created on this device

  const SignalResponse({
    required this.id,
    required this.signalId,
    required this.content,
    required this.authorId,
    this.authorName,
    required this.createdAt,
    required this.expiresAt,
    this.isLocal = true,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toFirestore() {
    return {
      'signalId': signalId,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  factory SignalResponse.fromFirestore(String id, Map<String, dynamic> data) {
    return SignalResponse(
      id: id,
      signalId: data['signalId'] as String,
      content: data['content'] as String,
      authorId: data['authorId'] as String,
      authorName: data['authorName'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      isLocal: false,
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
      createdAt: createdAt,
      expiresAt: expiresAt,
      isLocal: false,
    );
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
  static const _tableName = 'signals';
  static const _seenPacketsTable = 'seen_packets';
  static const _proximityTable = 'node_proximity';
  static const _responsesTable = 'responses';
  static const _maxLocalSignals = 200;
  static const _seenPacketTTLMinutes = 30;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Database? _db;
  final _uuid = const Uuid();

  /// Active Firestore response listeners keyed by signalId.
  /// Used to receive real-time response updates from other users.
  final Map<String, StreamSubscription<QuerySnapshot>> _responseListeners = {};

  /// Active Firestore comments listeners keyed by signalId.
  /// Used to receive real-time comments from posts/{signalId}/comments.
  final Map<String, StreamSubscription<QuerySnapshot>> _commentsListeners = {};

  /// Active Firestore post document listeners keyed by signalId.
  /// Used to receive real-time updates when cloud doc appears/changes (e.g. image upload completes).
  final Map<String, StreamSubscription<DocumentSnapshot>> _postListeners = {};

  /// Pending Firestore image updates that failed and need retry.
  /// Key: signalId, Value: (url, attemptCount, nextRetryTime)
  final Map<String, _PendingImageUpdate> _pendingImageUpdates = {};

  /// Timer for retrying pending image updates.
  Timer? _imageRetryTimer;

  /// Cached cloud responses keyed by signalId.
  final Map<String, List<SignalResponse>> _cloudResponses = {};

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
      version: 3,
      onCreate: (db, version) async {
        AppLogging.signals('Creating signals database v$version');
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        AppLogging.signals(
          'Upgrading signals database v$oldVersion -> v$newVersion',
        );
        if (oldVersion < 2) {
          await _createSeenPacketsTable(db);
          await _createProximityTable(db);
        }
        if (oldVersion < 3) {
          await _createResponsesTable(db);
        }
      },
    );

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
        imageState TEXT NOT NULL,
        imageLocalPath TEXT,
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

    await _createSeenPacketsTable(db);
    await _createProximityTable(db);
    await _createResponsesTable(db);
  }

  Future<void> _createSeenPacketsTable(Database db) async {
    // Seen packets table for deduplication
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_seenPacketsTable (
        packetHash TEXT PRIMARY KEY,
        receivedAt INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_seen_receivedAt '
      'ON $_seenPacketsTable(receivedAt)',
    );
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

  Future<void> _createResponsesTable(Database db) async {
    // Local responses to signals (ephemeral, no Firebase sync)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_responsesTable (
        id TEXT PRIMARY KEY,
        signalId TEXT NOT NULL,
        content TEXT NOT NULL,
        authorId TEXT NOT NULL,
        authorName TEXT,
        createdAt INTEGER NOT NULL,
        expiresAt INTEGER NOT NULL,
        FOREIGN KEY (signalId) REFERENCES $_tableName(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_responses_signalId '
      'ON $_responsesTable(signalId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_responses_expiresAt '
      'ON $_responsesTable(expiresAt)',
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
  String? get _currentUserId => _auth.currentUser?.uid;

  /// Check if user is authenticated.
  bool get isAuthenticated => _currentUserId != null;

  // ===========================================================================
  // DUPLICATE PACKET HANDLING
  // ===========================================================================

  /// Check if a signal with the given ID already exists in the signals table.
  /// Used for non-legacy signal deduplication (by signalId).
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

  /// Generate a hash for deduplication of LEGACY mesh packets (no signalId).
  String _generatePacketHash(int senderNodeId, String content, int ttlMinutes) {
    // Hash based on sender, content, and TTL to detect duplicates
    final data = '$senderNodeId:$content:$ttlMinutes';
    return data.hashCode.toRadixString(16);
  }

  /// Check if we've already seen this LEGACY packet (within TTL window).
  /// Only used for legacy signals that have no signalId.
  Future<bool> _hasSeenPacket(String packetHash) async {
    await init();

    final cutoff = DateTime.now()
        .subtract(Duration(minutes: _seenPacketTTLMinutes))
        .millisecondsSinceEpoch;

    final result = await _db!.query(
      _seenPacketsTable,
      where: 'packetHash = ? AND receivedAt > ?',
      whereArgs: [packetHash, cutoff],
    );

    return result.isNotEmpty;
  }

  /// Mark a packet as seen.
  Future<void> _markPacketSeen(String packetHash) async {
    await init();

    await _db!.insert(_seenPacketsTable, {
      'packetHash': packetHash,
      'receivedAt': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Clean up old seen packet entries.
  Future<void> _cleanupSeenPackets() async {
    await init();

    final cutoff = DateTime.now()
        .subtract(Duration(minutes: _seenPacketTTLMinutes))
        .millisecondsSinceEpoch;

    final deleted = await _db!.delete(
      _seenPacketsTable,
      where: 'receivedAt < ?',
      whereArgs: [cutoff],
    );

    if (deleted > 0) {
      AppLogging.signals('Cleaned up $deleted old seen packet entries');
    }
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
    String? imageLocalPath,
    PostAuthorSnapshot? authorSnapshot,
  }) async {
    await init();

    final now = DateTime.now();
    final expiresAt = now.add(Duration(minutes: ttlMinutes));
    final id = _uuid.v4();

    // Copy image to persistent storage if provided
    String? persistentImagePath;
    ImageState imageState = ImageState.none;
    if (imageLocalPath != null && imageLocalPath.isNotEmpty) {
      persistentImagePath = await _copyImageToPersistentStorage(
        imageLocalPath,
        id,
      );
      if (persistentImagePath != null) {
        imageState = ImageState.local;
        AppLogging.signals(
          'Image copied to persistent storage: $persistentImagePath',
        );
      } else {
        AppLogging.signals('Failed to copy image to persistent storage');
      }
    }

    final signal = Post(
      id: id,
      authorId: _currentUserId ?? 'anonymous',
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
      imageLocalPath: persistentImagePath,
    );

    AppLogging.signals(
      'Creating signal: id=$id, ttl=${ttlMinutes}m, '
      'hasImage=${persistentImagePath != null}, meshNode=$meshNodeId',
    );

    // Store locally first (mesh-first)
    await _saveSignalToDb(signal);

    // If authenticated and not already expired, also save to Firebase
    if (_currentUserId != null && !signal.isExpired) {
      try {
        await _saveSignalToFirebase(signal);
        await _markSignalSynced(signal.id);
        AppLogging.signals('Signal ${signal.id} synced to Firebase');
      } catch (e) {
        AppLogging.signals('Failed to sync signal to Firebase: $e');
        // Continue - local storage is primary
      }
    }

    // Broadcast over mesh if callback is configured
    // Include signalId for deterministic cloud matching
    if (onBroadcastSignal != null) {
      try {
        final packetId = await onBroadcastSignal!(
          id, // signalId for deterministic matching
          content,
          ttlMinutes,
          location?.latitude,
          location?.longitude,
        );
        if (packetId != null) {
          AppLogging.signals('Signal broadcast over mesh: packetId=$packetId');
        } else {
          AppLogging.signals('Signal not broadcast: mesh not connected');
        }
      } catch (e) {
        AppLogging.signals('Failed to broadcast signal over mesh: $e');
        // Continue - local storage is primary
      }
    }

    // Auto-upload image if authenticated and has local image
    if (_currentUserId != null &&
        persistentImagePath != null &&
        imageState == ImageState.local) {
      // Don't await - let upload happen in background
      _autoUploadImage(signal.id, persistentImagePath);
    }

    // Start listening for cloud responses and comments on this signal
    _startCommentsListener(signal.id);
    _startResponseListener(signal.id);

    return signal;
  }

  /// Auto-upload image to cloud in background.
  /// Updates local and cloud records with the image URL.
  Future<void> _autoUploadImage(String signalId, String localPath) async {
    AppLogging.signals('Auto-uploading image for signal $signalId');

    final url = await uploadSignalImage(signalId, localPath);
    if (url != null) {
      AppLogging.signals('Image auto-uploaded: $signalId -> $url');
    } else {
      AppLogging.signals('Image auto-upload failed for signal $signalId');
    }
  }

  /// Create a signal from a received mesh packet.
  ///
  /// If signalId is provided (new format), uses deterministic cloud lookup.
  /// If signalId is null (legacy format), treats as local-only signal.
  ///
  /// Includes duplicate detection to prevent processing the same packet twice.
  /// - Non-legacy (signalId provided): dedupe by signalId in signals table
  /// - Legacy (signalId null): dedupe by content hash in seen_packets table
  Future<Post?> createSignalFromMesh({
    required String content,
    required int senderNodeId,
    String? signalId, // null for legacy packets
    int ttlMinutes = SignalTTL.defaultTTL,
    PostLocation? location,
  }) async {
    await init();

    final isLegacySignal = signalId == null;

    // DEDUPLICATION LOGIC:
    // Non-legacy: check if signalId already exists in signals table
    // Legacy: check content hash in seen_packets table
    if (!isLegacySignal) {
      // Non-legacy: dedupe strictly by signalId
      if (await _hasSignalById(signalId)) {
        AppLogging.signals(
          '📋 Dedup: signalId $signalId already exists in DB -> ignore',
        );
        return null;
      }
      AppLogging.signals('📋 Dedup: accepting new signalId $signalId');
    } else {
      // Legacy: dedupe by content hash
      final packetHash = _generatePacketHash(senderNodeId, content, ttlMinutes);
      if (await _hasSeenPacket(packetHash)) {
        AppLogging.signals(
          '📋 Dedup: legacy hash $packetHash already seen -> ignore',
        );
        return null;
      }
      // Mark legacy packet as seen
      await _markPacketSeen(packetHash);
      AppLogging.signals(
        '📋 Dedup: accepting legacy signal (hash: $packetHash)',
      );
    }

    // Record node proximity
    await recordNodeProximity(senderNodeId);

    final now = DateTime.now();
    final expiresAt = now.add(Duration(minutes: ttlMinutes));

    // Determine signal ID:
    // - If signalId provided (new format): use it for cloud lookup
    // - If signalId null (legacy): generate local-only ID
    final effectiveSignalId = signalId ?? _uuid.v4();

    if (isLegacySignal) {
      AppLogging.signals(
        'Received LEGACY mesh signal (no id) from node $senderNodeId - '
        'treating as local-only',
      );
    } else {
      AppLogging.signals(
        'Received mesh signal with id=$signalId from node $senderNodeId',
      );
    }

    // For new-format signals, attempt deterministic cloud lookup
    String? cloudImageUrl;
    if (!isLegacySignal && _currentUserId != null) {
      final cloudSignal = await _lookupCloudSignal(effectiveSignalId);
      if (cloudSignal != null) {
        AppLogging.signals('Cloud doc found for signal $effectiveSignalId');
        if (cloudSignal.mediaUrls.isNotEmpty) {
          cloudImageUrl = cloudSignal.mediaUrls.first;
          AppLogging.signals('Cloud signal has image: $cloudImageUrl');
        }
      } else {
        AppLogging.signals(
          'Cloud doc NOT found for signal $effectiveSignalId - '
          'treating as text-only',
        );
      }
    }

    final signal = Post(
      id: effectiveSignalId,
      authorId: 'mesh_${senderNodeId.toRadixString(16)}',
      content: content,
      mediaUrls: cloudImageUrl != null ? [cloudImageUrl] : const [],
      location: location,
      nodeId: senderNodeId.toRadixString(16),
      createdAt: now,
      postMode: PostMode.signal,
      origin: SignalOrigin.mesh,
      expiresAt: expiresAt,
      meshNodeId: senderNodeId,
      imageState: cloudImageUrl != null ? ImageState.cloud : ImageState.none,
    );

    final contentPreview = content.length > 30
        ? '${content.substring(0, 30)}...'
        : content;

    AppLogging.signals(
      'Created local signal: id=${signal.id}, '
      'from=!${senderNodeId.toRadixString(16)}, '
      'ttl=${ttlMinutes}m, content="$contentPreview", '
      'legacy=$isLegacySignal, hasCloudImage=${cloudImageUrl != null}',
    );

    await _saveSignalToDb(signal);

    // If we have a cloud image, download and cache it locally
    if (cloudImageUrl != null && isImageUnlocked(signal)) {
      _downloadAndCacheImage(signal.id, cloudImageUrl);
    }

    // Start listening for cloud responses (only for non-legacy authenticated users)
    if (!isLegacySignal && _currentUserId != null) {
      _startCommentsListener(signal.id);
      _startResponseListener(signal.id);
      // Also listen for post doc updates (e.g. image upload completing)
      _startPostListener(signal.id);
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
      final mediaUrl = data['mediaUrl'] as String?; // legacy single field

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

      // Determine the best available cloud image URL
      // Priority: mediaUrls[0] > imageUrl > mediaUrl (legacy)
      String? cloudImageUrl;
      String usedField = 'none';

      if (signal.mediaUrls.isNotEmpty) {
        cloudImageUrl = signal.mediaUrls.first;
        usedField = 'mediaUrls';
      } else if (imageUrl != null && imageUrl.isNotEmpty) {
        cloudImageUrl = imageUrl;
        usedField = 'imageUrl';
      } else if (mediaUrl != null && mediaUrl.isNotEmpty) {
        cloudImageUrl = mediaUrl;
        usedField = 'mediaUrl (legacy)';
      }

      if (cloudImageUrl != null) {
        AppLogging.signals(
          '📷 Cloud image detected via $usedField: $cloudImageUrl',
        );
        // Return signal with the detected image URL
        return signal.copyWith(
          mediaUrls: [cloudImageUrl],
          imageState: ImageState.cloud,
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
      final signal = await getSignalById(signalId);
      if (signal != null) {
        final updated = signal.copyWith(
          imageLocalPath: localPath,
          mediaUrls: [imageUrl],
          imageState: ImageState.cloud,
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

    return rows.map((row) => _postFromDbMap(row)).toList();
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

    // Stop response listener for this signal
    _stopCommentsListener(signalId);
    _stopResponseListener(signalId);

    // Get signal to delete its image file
    final signal = await getSignalById(signalId);
    if (signal != null) {
      await _deleteSignalImage(signal.imageLocalPath);
    }

    // Delete cached cloud image if exists
    await _deleteCachedCloudImages([signalId]);

    // Delete responses for this signal
    await _db!.delete(
      _responsesTable,
      where: 'signalId = ?',
      whereArgs: [signalId],
    );

    await _db!.delete(_tableName, where: 'id = ?', whereArgs: [signalId]);

    // Also delete from Firebase if authenticated
    if (_currentUserId != null) {
      try {
        await _firestore.collection('posts').doc(signalId).delete();
        // Also delete cloud responses subcollection
        final responsesSnapshot = await _firestore
            .collection('responses')
            .doc(signalId)
            .collection('items')
            .get();
        for (final doc in responsesSnapshot.docs) {
          await doc.reference.delete();
        }
        await _firestore.collection('responses').doc(signalId).delete();
      } catch (e) {
        AppLogging.signals('Failed to delete signal from Firebase: $e');
      }
    }
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
      // Still cleanup expired responses even if no expired signals
      await _cleanupExpiredResponses();
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
      await _deleteSignalImage(imagePath);

      // Stop cloud listeners for this signal
      _stopCommentsListener(id);
      _stopResponseListener(id);
      _stopPostListener(id);

      expiredIds.add(id);
    }

    // Delete responses for expired signals
    if (expiredIds.isNotEmpty) {
      final placeholders = List.filled(expiredIds.length, '?').join(',');
      await _db!.rawDelete(
        'DELETE FROM $_responsesTable WHERE signalId IN ($placeholders)',
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

    AppLogging.signals(
      'Cleanup complete: removed $deletedCount expired signals',
    );

    // Also cleanup old seen packets, proximity data, and responses
    await _cleanupSeenPackets();
    await _cleanupOldProximityData();
    await _cleanupExpiredResponses();

    return deletedCount;
  }

  /// Clean up expired responses (those whose expiresAt has passed).
  Future<void> _cleanupExpiredResponses() async {
    await init();

    final now = DateTime.now().millisecondsSinceEpoch;
    final deleted = await _db!.delete(
      _responsesTable,
      where: 'expiresAt < ?',
      whereArgs: [now],
    );

    if (deleted > 0) {
      AppLogging.signals('Cleaned up $deleted expired responses');
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
  Future<String?> uploadSignalImage(String signalId, String localPath) async {
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

      AppLogging.signals('📷 UPLOAD START: signal $signalId, file=$localPath');

      // Step 1: Upload to Firebase Storage
      final ref = _storage.ref('signals/$currentUid/$signalId.jpg');
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
        '📷 STORAGE UPLOAD SUCCESS: signal $signalId, URL=$url',
      );

      // Step 2: Update Firestore FIRST (if not expired)
      // Only update allowed fields: mediaUrls, imageUrl, imageState
      if (!signal.isExpired) {
        final firestoreSuccess = await _updateFirestoreImageFields(
          signalId: signalId,
          url: url,
          authorId: signal.authorId,
          currentUid: currentUid,
        );

        if (firestoreSuccess) {
          // Step 3: Only update local DB after Firestore succeeds
          final updated = signal.copyWith(
            mediaUrls: [url],
            imageState: ImageState.cloud,
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
        final updated = signal.copyWith(
          mediaUrls: [pending.url],
          imageState: ImageState.cloud,
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
      AppLogging.signals(
        '📡 Comments listener: already active for $signalId',
      );
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
                .map((doc) =>
                    SignalResponse.fromFirestoreComment(doc.id, doc.data()))
                .toList();

            // Get latest timestamp for logging
            final latestCreatedAt = comments.isNotEmpty
                ? comments.last.createdAt.toIso8601String()
                : 'none';

            AppLogging.signals(
              '📡 Comments listener: snapshot for $signalId: '
              'docs=${snapshot.docs.length}, latestCreatedAt=$latestCreatedAt',
            );

            // Update cloud responses cache (replaces, not appends)
            _cloudResponses[signalId] = comments;

            // Update local DB comment count
            final signal = await getSignalById(signalId);
            if (signal != null &&
                signal.commentCount != comments.length) {
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

            // UI will refresh via periodic timer in signal_providers.dart
          },
          onError: (e, stackTrace) {
            AppLogging.signals(
              '📡 Comments listener ERROR for $signalId: $e\n'
              'StackTrace: $stackTrace\n'
              'UserId: $_currentUserId\n'
              'Path: posts/$signalId/comments',
            );
          },
        );

    _commentsListeners[signalId] = subscription;
    AppLogging.signals(
      '📡 Comments listener: subscription stored for $signalId '
      '(total active: ${_commentsListeners.length})',
    );
  }

  /// Start listening for cloud responses on a signal (DEPRECATED - use comments).
  /// Called when signal is created or received via mesh.
  void _startResponseListener(String signalId) {
    // Skip if not authenticated or already listening
    if (_currentUserId == null) return;
    if (_responseListeners.containsKey(signalId)) return;

    AppLogging.signals('Starting response listener for signal $signalId');

    final subscription = _firestore
        .collection('responses')
        .doc(signalId)
        .collection('items')
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt')
        .orderBy('createdAt')
        .snapshots()
        .listen(
          (snapshot) {
            final responses = snapshot.docs
                .map((doc) => SignalResponse.fromFirestore(doc.id, doc.data()))
                .where((r) => !r.isExpired)
                .toList();

            _cloudResponses[signalId] = responses;
            AppLogging.signals(
              'Cloud responses updated for $signalId: ${responses.length} responses',
            );
          },
          onError: (e) {
            AppLogging.signals('Response listener error for $signalId: $e');
          },
        );

    _responseListeners[signalId] = subscription;
  }

  /// Stop listening for cloud comments on a signal.
  /// Called when signal expires or is deleted.
  void _stopCommentsListener(String signalId) {
    final subscription = _commentsListeners.remove(signalId);
    if (subscription != null) {
      subscription.cancel();
      AppLogging.signals('📡 Stopped comments listener for signal $signalId');
    }
  }

  /// Stop all comments listeners (for cleanup on dispose).
  void _stopAllCommentsListeners() {
    for (final entry in _commentsListeners.entries) {
      entry.value.cancel();
      AppLogging.signals('📡 Stopped comments listener for signal ${entry.key}');
    }
    _commentsListeners.clear();
  }

  /// Stop listening for cloud responses on a signal.
  /// Called when signal expires or is deleted.
  void _stopResponseListener(String signalId) {
    final subscription = _responseListeners.remove(signalId);
    if (subscription != null) {
      subscription.cancel();
      AppLogging.signals('Stopped response listener for signal $signalId');
    }
    _cloudResponses.remove(signalId);
  }

  /// Stop all response listeners (for cleanup on dispose).
  void _stopAllResponseListeners() {
    for (final entry in _responseListeners.entries) {
      entry.value.cancel();
      AppLogging.signals('Stopped response listener for signal ${entry.key}');
    }
    _responseListeners.clear();
    _cloudResponses.clear();
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
  /// - If mediaUrls transitions from empty → non-empty → download image
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
              AppLogging.signals(
                '📡 Post listener: doc posts/$signalId does NOT exist yet - waiting',
              );
              return;
            }

            final data = snapshot.data()!;

            // Extract all relevant fields
            final mediaUrls = data['mediaUrls'] as List<dynamic>?;
            final imageUrl = data['imageUrl'] as String?;
            final mediaUrl = data['mediaUrl'] as String?;
            final cloudCommentCount = data['commentCount'] as int? ?? 0;

            // Determine best available cloud image URL
            String? cloudImageUrl;
            if (mediaUrls != null && mediaUrls.isNotEmpty) {
              cloudImageUrl = mediaUrls.first as String?;
            } else if (imageUrl != null && imageUrl.isNotEmpty) {
              cloudImageUrl = imageUrl;
            } else if (mediaUrl != null && mediaUrl.isNotEmpty) {
              cloudImageUrl = mediaUrl;
            }

            AppLogging.signals(
              '📡 Post listener: doc posts/$signalId exists: '
              'mediaUrls.length=${mediaUrls?.length ?? 0}, '
              'hasCloudImage=${cloudImageUrl != null}, '
              'commentCount=$cloudCommentCount',
            );

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

            // Handle image: check if cloud has image and we don't have it locally
            final hasLocalImage =
                signal.imageLocalPath != null &&
                signal.imageLocalPath!.isNotEmpty;

            if (cloudImageUrl != null && !hasLocalImage) {
              AppLogging.signals(
                '📡 Post listener: cloud image detected, local missing',
              );

              // Update signal with cloud URL
              updatedSignal = updatedSignal.copyWith(
                mediaUrls: [cloudImageUrl],
                imageState: ImageState.cloud,
              );
              needsUpdate = true;

              // Download if unlocked
              if (isImageUnlocked(signal)) {
                AppLogging.signals(
                  '📡 Post listener: downloading cloud image for $signalId',
                );
                // Save updated state first, then download
                await updateSignal(updatedSignal);
                needsUpdate = false; // Already saved
                await _downloadAndCacheImage(signalId, cloudImageUrl);
              } else {
                AppLogging.signals(
                  '📡 Post listener: cloud image URL saved, '
                  'waiting for proximity unlock',
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
          },
        );

    _postListeners[signalId] = subscription;
    AppLogging.signals(
      '📡 Post listener: subscription stored for $signalId '
      '(total active: ${_postListeners.length})',
    );
  }

  /// Stop listening for cloud signal document updates.
  void _stopPostListener(String signalId) {
    final subscription = _postListeners.remove(signalId);
    if (subscription != null) {
      subscription.cancel();
      AppLogging.signals('📡 Stopped post listener for signal $signalId');
    }
  }

  /// Stop all post listeners (for cleanup on dispose).
  void _stopAllPostListeners() {
    for (final entry in _postListeners.entries) {
      entry.value.cancel();
      AppLogging.signals('📡 Stopped post listener for signal ${entry.key}');
    }
    _postListeners.clear();
  }

  // ===========================================================================
  // RESPONSES (Local + cloud sync)
  // ===========================================================================

  /// Create a response to a signal.
  /// Stores locally in SQLite, syncs to Firestore for authenticated users.
  Future<SignalResponse?> createResponse({
    required String signalId,
    required String content,
    String? authorName,
  }) async {
    await init();

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
      authorId: _currentUserId ?? 'anonymous',
      authorName: authorName,
      createdAt: now,
      expiresAt: signal.expiresAt ?? now.add(const Duration(hours: 1)),
    );

    await _db!.insert(_responsesTable, {
      'id': response.id,
      'signalId': response.signalId,
      'content': response.content,
      'authorId': response.authorId,
      'authorName': response.authorName,
      'createdAt': response.createdAt.millisecondsSinceEpoch,
      'expiresAt': response.expiresAt.millisecondsSinceEpoch,
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
        'createdAt': FieldValue.serverTimestamp(),
        'origin': 'cloud',
      });

      // Update parent post's commentCount using transaction
      await _firestore.runTransaction((transaction) async {
        final postRef =
            _firestore.collection('posts').doc(response.signalId);
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

  /// Get responses for a signal.
  /// Merges local (SQLite) and cloud (Firestore) responses, deduplicates.
  Future<List<SignalResponse>> getResponses(String signalId) async {
    await init();

    final now = DateTime.now().millisecondsSinceEpoch;

    // Get local responses from SQLite
    final rows = await _db!.query(
      _responsesTable,
      where: 'signalId = ? AND expiresAt > ?',
      whereArgs: [signalId, now],
      orderBy: 'createdAt ASC',
    );

    final localResponses = rows
        .map(
          (row) => SignalResponse(
            id: row['id'] as String,
            signalId: row['signalId'] as String,
            content: row['content'] as String,
            authorId: row['authorId'] as String,
            authorName: row['authorName'] as String?,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              row['createdAt'] as int,
            ),
            expiresAt: DateTime.fromMillisecondsSinceEpoch(
              row['expiresAt'] as int,
            ),
            isLocal: true,
          ),
        )
        .toList();

    // Get cloud responses from cache
    final cloudResponses = _cloudResponses[signalId] ?? [];

    // Merge and deduplicate (local takes precedence)
    final localIds = localResponses.map((r) => r.id).toSet();
    final uniqueCloudResponses = cloudResponses
        .where((r) => !localIds.contains(r.id) && !r.isExpired)
        .toList();

    final merged = [...localResponses, ...uniqueCloudResponses];
    merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return merged;
  }

  /// Get response count for a signal.
  Future<int> getResponseCount(String signalId) async {
    await init();

    final now = DateTime.now().millisecondsSinceEpoch;
    final result = Sqflite.firstIntValue(
      await _db!.rawQuery(
        'SELECT COUNT(*) FROM $_responsesTable '
        'WHERE signalId = ? AND expiresAt > ?',
        [signalId, now],
      ),
    );

    return result ?? 0;
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
      'imageState': post.imageState.name,
      'imageLocalPath': post.imageLocalPath,
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
      imageState: ImageState.values.firstWhere(
        (e) => e.name == (map['imageState'] as String?),
        orElse: () => ImageState.none,
      ),
      imageLocalPath: map['imageLocalPath'] as String?,
    );
  }

  /// Close the database connection and clean up listeners.
  Future<void> close() async {
    _imageRetryTimer?.cancel();
    _imageRetryTimer = null;
    _pendingImageUpdates.clear();
    _stopAllCommentsListeners();
    _stopAllResponseListeners();
    _stopAllPostListeners();
    await _db?.close();
    _db = null;
    AppLogging.signals('SignalService database closed');
  }
}
