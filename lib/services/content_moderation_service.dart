// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:socialmesh/core/logging.dart';

/// Service for content moderation - user-facing moderation status and controls.
///
/// Handles:
/// - Checking user's moderation status (strikes, suspensions)
/// - Acknowledging strikes
/// - Client-side text pre-screening before upload
/// - Sensitive content settings
class ContentModerationService {
  ContentModerationService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  }) : _firestoreOverride = firestore,
       _authOverride = auth,
       _functionsOverride = functions;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;
  final FirebaseFunctions? _functionsOverride;

  /// Lazy — avoids accessing FirebaseFirestore.instance before
  /// Firebase.initializeApp() has completed.
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  /// Lazy — avoids accessing FirebaseAuth.instance before
  /// Firebase.initializeApp() has completed.
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  /// Lazy — avoids accessing FirebaseFunctions.instance before
  /// Firebase.initializeApp() has completed.
  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  // ===========================================================================
  // MODERATION STATUS
  // ===========================================================================

  /// Get the current user's moderation status (strikes, warnings, suspension)
  Future<ModerationStatus> getModerationStatus() async {
    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('Must be signed in');
    }

    try {
      final result = await _functions
          .httpsCallable('getModerationStatus')
          .call({});
      final data = result.data as Map<String, dynamic>;

      final status = data['status'] as Map<String, dynamic>;
      final strikesData = data['strikes'] as List<dynamic>;

      return ModerationStatus(
        activeStrikes: status['activeStrikes'] as int? ?? 0,
        activeWarnings: status['activeWarnings'] as int? ?? 0,
        isSuspended: status['isSuspended'] as bool? ?? false,
        suspendedUntil: status['suspendedUntil'] != null
            ? DateTime.parse(status['suspendedUntil'] as String)
            : null,
        isPermanentlyBanned: status['isPermanentlyBanned'] as bool? ?? false,
        strikes: strikesData
            .map((s) => UserStrike.fromMap(s as Map<String, dynamic>))
            .toList(),
      );
    } catch (e) {
      AppLogging.social('Error getting moderation status: $e');
      rethrow;
    }
  }

  /// Stream the current user's moderation status from Firestore
  Stream<ModerationStatus?> watchModerationStatus() {
    final userId = _currentUserId;
    if (userId == null) {
      return Stream.value(null);
    }

    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data();
      final modStatus = data?['moderationStatus'] as Map<String, dynamic>?;
      if (modStatus == null) return ModerationStatus.clear();

      return ModerationStatus(
        activeStrikes: modStatus['activeStrikes'] as int? ?? 0,
        activeWarnings: modStatus['activeWarnings'] as int? ?? 0,
        isSuspended: modStatus['isSuspended'] as bool? ?? false,
        suspendedUntil: modStatus['suspendedUntil'] != null
            ? (modStatus['suspendedUntil'] as Timestamp).toDate()
            : null,
        isPermanentlyBanned: modStatus['isPermanentlyBanned'] as bool? ?? false,
        strikes:
            [], // Not included in snapshot, use getModerationStatus() for full data
      );
    });
  }

  /// Get unacknowledged strikes for the current user
  Future<List<UserStrike>> getUnacknowledgedStrikes() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    final snapshot = await _firestore
        .collection('user_strikes')
        .where('userId', isEqualTo: userId)
        .where('acknowledged', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => UserStrike.fromFirestore(doc)).toList();
  }

  /// Acknowledge a strike (user has seen and understood the warning)
  Future<void> acknowledgeStrike(String strikeId) async {
    try {
      await _functions.httpsCallable('acknowledgeStrike').call({
        'strikeId': strikeId,
      });
    } catch (e) {
      AppLogging.social('Error acknowledging strike: $e');
      rethrow;
    }
  }

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
          ? 'Flagged: ${flaggedCategories.map((c) => c.name).join(', ')}'
          : 'Text passed local moderation',
    );
  }

  // ===========================================================================
  // SENSITIVE CONTENT SETTINGS
  // ===========================================================================

  /// Get user's sensitive content preferences
  Future<SensitiveContentSettings> getSensitiveContentSettings() async {
    final userId = _currentUserId;
    if (userId == null) {
      return SensitiveContentSettings.defaultSettings();
    }

    final doc = await _firestore.collection('users').doc(userId).get();
    final settings =
        doc.data()?['sensitiveContentSettings'] as Map<String, dynamic>?;

    if (settings == null) {
      return SensitiveContentSettings.defaultSettings();
    }

    return SensitiveContentSettings.fromMap(settings);
  }

  /// Update user's sensitive content preferences
  Future<void> updateSensitiveContentSettings(
    SensitiveContentSettings settings,
  ) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('Must be signed in');
    }

    await _firestore.collection('users').doc(userId).set({
      'sensitiveContentSettings': settings.toMap(),
    }, SetOptions(merge: true));
  }

  /// Stream user's sensitive content settings
  Stream<SensitiveContentSettings> watchSensitiveContentSettings() {
    final userId = _currentUserId;
    if (userId == null) {
      return Stream.value(SensitiveContentSettings.defaultSettings());
    }

    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      final settings =
          doc.data()?['sensitiveContentSettings'] as Map<String, dynamic>?;
      if (settings == null) {
        return SensitiveContentSettings.defaultSettings();
      }
      return SensitiveContentSettings.fromMap(settings);
    });
  }

  // ===========================================================================
  // ADMIN FUNCTIONS
  // ===========================================================================

  /// Get the moderation queue (admin only)
  Future<List<ModerationQueueItem>> getModerationQueue({
    String? status,
    int limit = 50,
  }) async {
    try {
      final result = await _functions.httpsCallable('getModerationQueue').call({
        if (status != null) 'status': status,
        'limit': limit,
      });
      final items = result.data['items'] as List<dynamic>;
      return items
          .map(
            (item) => ModerationQueueItem.fromMap(item as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      AppLogging.social('Error getting moderation queue: $e');
      rethrow;
    }
  }

  /// Review a moderation queue item (admin only)
  Future<void> reviewModerationItem({
    required String itemId,
    required String action, // 'approve' or 'reject'
    String? notes,
  }) async {
    try {
      await _functions.httpsCallable('reviewModerationItem').call({
        'itemId': itemId,
        'action': action,
        if (notes != null) 'notes': notes,
      });
    } catch (e) {
      AppLogging.social('Error reviewing moderation item: $e');
      rethrow;
    }
  }
}

// =============================================================================
// DATA MODELS
// =============================================================================

/// User's current moderation status
class ModerationStatus {
  const ModerationStatus({
    required this.activeStrikes,
    required this.activeWarnings,
    required this.isSuspended,
    this.suspendedUntil,
    required this.isPermanentlyBanned,
    this.strikes = const [],
    this.unacknowledgedCount = 0,
    this.lastReason,
    this.history = const [],
  });

  factory ModerationStatus.clear() => const ModerationStatus(
    activeStrikes: 0,
    activeWarnings: 0,
    isSuspended: false,
    isPermanentlyBanned: false,
  );

  final int activeStrikes;
  final int activeWarnings;
  final bool isSuspended;
  final DateTime? suspendedUntil;
  final bool isPermanentlyBanned;
  final List<UserStrike> strikes;
  final int unacknowledgedCount;
  final String? lastReason;
  final List<ModerationHistoryItem> history;

  bool get isInGoodStanding =>
      activeStrikes == 0 && !isSuspended && !isPermanentlyBanned;

  bool get canPost => !isSuspended && !isPermanentlyBanned;

  String get statusMessage {
    if (isPermanentlyBanned) {
      return 'Your account has been permanently suspended.';
    }
    if (isSuspended && suspendedUntil != null) {
      final remaining = suspendedUntil!.difference(DateTime.now());
      if (remaining.inDays > 0) {
        return 'Your account is suspended for ${remaining.inDays} more day(s).';
      } else if (remaining.inHours > 0) {
        return 'Your account is suspended for ${remaining.inHours} more hour(s).';
      }
      return 'Your suspension will be lifted soon.';
    }
    if (activeStrikes > 0) {
      return 'You have $activeStrikes active strike(s). Further violations may result in suspension.';
    }
    if (activeWarnings > 0) {
      return 'You have $activeWarnings warning(s). Please review our community guidelines.';
    }
    return 'Your account is in good standing.';
  }
}

/// A strike or warning against a user
class UserStrike {
  const UserStrike({
    required this.id,
    required this.userId,
    required this.type,
    required this.reason,
    required this.createdAt,
    this.expiresAt,
    this.contentId,
    this.contentType,
    required this.acknowledged,
  });

  factory UserStrike.fromMap(Map<String, dynamic> map) {
    return UserStrike(
      id: map['id'] as String,
      userId: map['userId'] as String,
      type: map['type'] as String,
      reason: map['reason'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      expiresAt: map['expiresAt'] != null
          ? DateTime.parse(map['expiresAt'] as String)
          : null,
      contentId: map['contentId'] as String?,
      contentType: map['contentType'] as String?,
      acknowledged: map['acknowledged'] as bool? ?? false,
    );
  }

  factory UserStrike.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return UserStrike(
      id: doc.id,
      userId: data['userId'] as String,
      type: data['type'] as String,
      reason: data['reason'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: data['expiresAt'] != null
          ? (data['expiresAt'] as Timestamp).toDate()
          : null,
      contentId: data['contentId'] as String?,
      contentType: data['contentType'] as String?,
      acknowledged: data['acknowledged'] as bool? ?? false,
    );
  }

  final String id;
  final String userId;
  final String type; // 'warning', 'strike', 'suspension'
  final String reason;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? contentId;
  final String? contentType;
  final bool acknowledged;

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  String get typeDisplayName {
    switch (type) {
      case 'warning':
        return 'Warning';
      case 'strike':
        return 'Strike';
      case 'suspension':
        return 'Suspension';
      default:
        return type;
    }
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

/// User's sensitive content display preferences
class SensitiveContentSettings {
  const SensitiveContentSettings({
    required this.showSensitiveContent,
    required this.blurSensitiveMedia,
    required this.filterLevel,
  });

  factory SensitiveContentSettings.defaultSettings() =>
      const SensitiveContentSettings(
        showSensitiveContent: false,
        blurSensitiveMedia: true,
        filterLevel: SensitiveContentFilterLevel.standard,
      );

  factory SensitiveContentSettings.fromMap(Map<String, dynamic> map) {
    return SensitiveContentSettings(
      showSensitiveContent: map['showSensitiveContent'] as bool? ?? false,
      blurSensitiveMedia: map['blurSensitiveMedia'] as bool? ?? true,
      filterLevel: SensitiveContentFilterLevel.values.firstWhere(
        (e) => e.name == map['filterLevel'],
        orElse: () => SensitiveContentFilterLevel.standard,
      ),
    );
  }

  final bool showSensitiveContent;
  final bool blurSensitiveMedia;
  final SensitiveContentFilterLevel filterLevel;

  Map<String, dynamic> toMap() => {
    'showSensitiveContent': showSensitiveContent,
    'blurSensitiveMedia': blurSensitiveMedia,
    'filterLevel': filterLevel.name,
  };

  SensitiveContentSettings copyWith({
    bool? showSensitiveContent,
    bool? blurSensitiveMedia,
    SensitiveContentFilterLevel? filterLevel,
  }) => SensitiveContentSettings(
    showSensitiveContent: showSensitiveContent ?? this.showSensitiveContent,
    blurSensitiveMedia: blurSensitiveMedia ?? this.blurSensitiveMedia,
    filterLevel: filterLevel ?? this.filterLevel,
  );
}

/// Filter levels for sensitive content display
enum SensitiveContentFilterLevel {
  /// Don't show sensitive content at all
  strict,

  /// Show some sensitive content (default)
  standard,

  /// Show more sensitive content (opt-in)
  less,
}

/// An item in the moderation review queue
class ModerationQueueItem {
  const ModerationQueueItem({
    required this.id,
    required this.contentType,
    required this.contentId,
    required this.userId,
    this.contentUrl,
    this.textContent,
    required this.status,
    required this.createdAt,
    this.reviewedBy,
    this.reviewedAt,
  });

  factory ModerationQueueItem.fromMap(Map<String, dynamic> map) {
    return ModerationQueueItem(
      id: map['id'] as String,
      contentType: map['contentType'] as String,
      contentId: map['contentId'] as String,
      userId: map['userId'] as String,
      contentUrl: map['contentUrl'] as String?,
      textContent: map['textContent'] as String?,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      reviewedBy: map['reviewedBy'] as String?,
      reviewedAt: map['reviewedAt'] != null
          ? DateTime.parse(map['reviewedAt'] as String)
          : null,
    );
  }

  final String id;
  final String contentType; // 'story', 'post', 'comment', 'profile'
  final String contentId;
  final String userId;
  final String? contentUrl;
  final String? textContent;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime createdAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
}

// =============================================================================
// MODERATION HISTORY MODELS
// =============================================================================

/// Type of moderation action taken
enum ModerationActionType {
  warning,
  strike,
  suspension,
  cleared;

  String get displayName {
    switch (this) {
      case ModerationActionType.warning:
        return 'Warning';
      case ModerationActionType.strike:
        return 'Strike';
      case ModerationActionType.suspension:
        return 'Suspension';
      case ModerationActionType.cleared:
        return 'Cleared';
    }
  }
}

/// A single moderation history entry
class ModerationHistoryItem {
  const ModerationHistoryItem({
    required this.id,
    required this.type,
    required this.timestamp,
    this.reason,
    this.contentType,
    this.expiresAt,
    this.acknowledged = false,
  });

  factory ModerationHistoryItem.fromStrike(UserStrike strike) {
    ModerationActionType actionType;
    switch (strike.type) {
      case 'warning':
        actionType = ModerationActionType.warning;
      case 'strike':
        actionType = ModerationActionType.strike;
      case 'suspension':
        actionType = ModerationActionType.suspension;
      default:
        actionType = ModerationActionType.warning;
    }

    return ModerationHistoryItem(
      id: strike.id,
      type: actionType,
      timestamp: strike.createdAt,
      reason: strike.reason,
      contentType: strike.contentType,
      expiresAt: strike.expiresAt,
      acknowledged: strike.acknowledged,
    );
  }

  final String id;
  final ModerationActionType type;
  final DateTime timestamp;
  final String? reason;
  final String? contentType;
  final DateTime? expiresAt;
  final bool acknowledged;
}
