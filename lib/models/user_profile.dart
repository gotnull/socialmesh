import 'dart:convert';

/// Settings that should persist across app reinstalls
class UserPreferences {
  /// Theme mode: 0 = system, 1 = light, 2 = dark
  final int? themeModeIndex;

  /// Notification settings
  final bool? notificationsEnabled;
  final bool? newNodeNotificationsEnabled;
  final bool? directMessageNotificationsEnabled;
  final bool? channelMessageNotificationsEnabled;
  final bool? notificationSoundEnabled;
  final bool? notificationVibrationEnabled;

  /// Haptic feedback settings
  final bool? hapticFeedbackEnabled;
  final int? hapticIntensity;

  /// Animation settings
  final bool? animationsEnabled;
  final bool? animations3DEnabled;

  /// Canned responses (JSON-encoded list)
  final String? cannedResponsesJson;

  /// Tapback configs (JSON-encoded list)
  final String? tapbackConfigsJson;

  /// Selected ringtone
  final String? ringtoneRtttl;
  final String? ringtoneName;

  /// Splash mesh config
  final double? splashMeshSize;
  final String? splashMeshAnimationType;
  final double? splashMeshGlowIntensity;
  final double? splashMeshLineThickness;
  final double? splashMeshNodeSize;
  final int? splashMeshColorPreset;
  final bool? splashMeshUseAccelerometer;
  final double? splashMeshAccelSensitivity;
  final double? splashMeshAccelFriction;
  final String? splashMeshPhysicsMode;
  final bool? splashMeshEnableTouch;
  final bool? splashMeshEnablePullToStretch;
  final double? splashMeshTouchIntensity;
  final double? splashMeshStretchIntensity;

  /// Automations (JSON-encoded list)
  final String? automationsJson;

  /// IFTTT config (JSON-encoded)
  final String? iftttConfigJson;

  const UserPreferences({
    this.themeModeIndex,
    this.notificationsEnabled,
    this.newNodeNotificationsEnabled,
    this.directMessageNotificationsEnabled,
    this.channelMessageNotificationsEnabled,
    this.notificationSoundEnabled,
    this.notificationVibrationEnabled,
    this.hapticFeedbackEnabled,
    this.hapticIntensity,
    this.animationsEnabled,
    this.animations3DEnabled,
    this.cannedResponsesJson,
    this.tapbackConfigsJson,
    this.ringtoneRtttl,
    this.ringtoneName,
    this.splashMeshSize,
    this.splashMeshAnimationType,
    this.splashMeshGlowIntensity,
    this.splashMeshLineThickness,
    this.splashMeshNodeSize,
    this.splashMeshColorPreset,
    this.splashMeshUseAccelerometer,
    this.splashMeshAccelSensitivity,
    this.splashMeshAccelFriction,
    this.splashMeshPhysicsMode,
    this.splashMeshEnableTouch,
    this.splashMeshEnablePullToStretch,
    this.splashMeshTouchIntensity,
    this.splashMeshStretchIntensity,
    this.automationsJson,
    this.iftttConfigJson,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      themeModeIndex: json['themeModeIndex'] as int?,
      notificationsEnabled: json['notificationsEnabled'] as bool?,
      newNodeNotificationsEnabled: json['newNodeNotificationsEnabled'] as bool?,
      directMessageNotificationsEnabled:
          json['directMessageNotificationsEnabled'] as bool?,
      channelMessageNotificationsEnabled:
          json['channelMessageNotificationsEnabled'] as bool?,
      notificationSoundEnabled: json['notificationSoundEnabled'] as bool?,
      notificationVibrationEnabled:
          json['notificationVibrationEnabled'] as bool?,
      hapticFeedbackEnabled: json['hapticFeedbackEnabled'] as bool?,
      hapticIntensity: json['hapticIntensity'] as int?,
      animationsEnabled: json['animationsEnabled'] as bool?,
      animations3DEnabled: json['animations3DEnabled'] as bool?,
      cannedResponsesJson: json['cannedResponsesJson'] as String?,
      tapbackConfigsJson: json['tapbackConfigsJson'] as String?,
      ringtoneRtttl: json['ringtoneRtttl'] as String?,
      ringtoneName: json['ringtoneName'] as String?,
      splashMeshSize: (json['splashMeshSize'] as num?)?.toDouble(),
      splashMeshAnimationType: json['splashMeshAnimationType'] as String?,
      splashMeshGlowIntensity: (json['splashMeshGlowIntensity'] as num?)
          ?.toDouble(),
      splashMeshLineThickness: (json['splashMeshLineThickness'] as num?)
          ?.toDouble(),
      splashMeshNodeSize: (json['splashMeshNodeSize'] as num?)?.toDouble(),
      splashMeshColorPreset: json['splashMeshColorPreset'] as int?,
      splashMeshUseAccelerometer: json['splashMeshUseAccelerometer'] as bool?,
      splashMeshAccelSensitivity: (json['splashMeshAccelSensitivity'] as num?)
          ?.toDouble(),
      splashMeshAccelFriction: (json['splashMeshAccelFriction'] as num?)
          ?.toDouble(),
      splashMeshPhysicsMode: json['splashMeshPhysicsMode'] as String?,
      splashMeshEnableTouch: json['splashMeshEnableTouch'] as bool?,
      splashMeshEnablePullToStretch:
          json['splashMeshEnablePullToStretch'] as bool?,
      splashMeshTouchIntensity: (json['splashMeshTouchIntensity'] as num?)
          ?.toDouble(),
      splashMeshStretchIntensity: (json['splashMeshStretchIntensity'] as num?)
          ?.toDouble(),
      automationsJson: json['automationsJson'] as String?,
      iftttConfigJson: json['iftttConfigJson'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (themeModeIndex != null) 'themeModeIndex': themeModeIndex,
      if (notificationsEnabled != null)
        'notificationsEnabled': notificationsEnabled,
      if (newNodeNotificationsEnabled != null)
        'newNodeNotificationsEnabled': newNodeNotificationsEnabled,
      if (directMessageNotificationsEnabled != null)
        'directMessageNotificationsEnabled': directMessageNotificationsEnabled,
      if (channelMessageNotificationsEnabled != null)
        'channelMessageNotificationsEnabled':
            channelMessageNotificationsEnabled,
      if (notificationSoundEnabled != null)
        'notificationSoundEnabled': notificationSoundEnabled,
      if (notificationVibrationEnabled != null)
        'notificationVibrationEnabled': notificationVibrationEnabled,
      if (hapticFeedbackEnabled != null)
        'hapticFeedbackEnabled': hapticFeedbackEnabled,
      if (hapticIntensity != null) 'hapticIntensity': hapticIntensity,
      if (animationsEnabled != null) 'animationsEnabled': animationsEnabled,
      if (animations3DEnabled != null)
        'animations3DEnabled': animations3DEnabled,
      if (cannedResponsesJson != null)
        'cannedResponsesJson': cannedResponsesJson,
      if (tapbackConfigsJson != null) 'tapbackConfigsJson': tapbackConfigsJson,
      if (ringtoneRtttl != null) 'ringtoneRtttl': ringtoneRtttl,
      if (ringtoneName != null) 'ringtoneName': ringtoneName,
      if (splashMeshSize != null) 'splashMeshSize': splashMeshSize,
      if (splashMeshAnimationType != null)
        'splashMeshAnimationType': splashMeshAnimationType,
      if (splashMeshGlowIntensity != null)
        'splashMeshGlowIntensity': splashMeshGlowIntensity,
      if (splashMeshLineThickness != null)
        'splashMeshLineThickness': splashMeshLineThickness,
      if (splashMeshNodeSize != null) 'splashMeshNodeSize': splashMeshNodeSize,
      if (splashMeshColorPreset != null)
        'splashMeshColorPreset': splashMeshColorPreset,
      if (splashMeshUseAccelerometer != null)
        'splashMeshUseAccelerometer': splashMeshUseAccelerometer,
      if (splashMeshAccelSensitivity != null)
        'splashMeshAccelSensitivity': splashMeshAccelSensitivity,
      if (splashMeshAccelFriction != null)
        'splashMeshAccelFriction': splashMeshAccelFriction,
      if (splashMeshPhysicsMode != null)
        'splashMeshPhysicsMode': splashMeshPhysicsMode,
      if (splashMeshEnableTouch != null)
        'splashMeshEnableTouch': splashMeshEnableTouch,
      if (splashMeshEnablePullToStretch != null)
        'splashMeshEnablePullToStretch': splashMeshEnablePullToStretch,
      if (splashMeshTouchIntensity != null)
        'splashMeshTouchIntensity': splashMeshTouchIntensity,
      if (splashMeshStretchIntensity != null)
        'splashMeshStretchIntensity': splashMeshStretchIntensity,
      if (automationsJson != null) 'automationsJson': automationsJson,
      if (iftttConfigJson != null) 'iftttConfigJson': iftttConfigJson,
    };
  }

  UserPreferences copyWith({
    int? themeModeIndex,
    bool? notificationsEnabled,
    bool? newNodeNotificationsEnabled,
    bool? directMessageNotificationsEnabled,
    bool? channelMessageNotificationsEnabled,
    bool? notificationSoundEnabled,
    bool? notificationVibrationEnabled,
    bool? hapticFeedbackEnabled,
    int? hapticIntensity,
    bool? animationsEnabled,
    bool? animations3DEnabled,
    String? cannedResponsesJson,
    String? tapbackConfigsJson,
    String? ringtoneRtttl,
    String? ringtoneName,
    double? splashMeshSize,
    String? splashMeshAnimationType,
    double? splashMeshGlowIntensity,
    double? splashMeshLineThickness,
    double? splashMeshNodeSize,
    int? splashMeshColorPreset,
    bool? splashMeshUseAccelerometer,
    double? splashMeshAccelSensitivity,
    double? splashMeshAccelFriction,
    String? splashMeshPhysicsMode,
    bool? splashMeshEnableTouch,
    bool? splashMeshEnablePullToStretch,
    double? splashMeshTouchIntensity,
    double? splashMeshStretchIntensity,
    String? automationsJson,
    String? iftttConfigJson,
  }) {
    return UserPreferences(
      themeModeIndex: themeModeIndex ?? this.themeModeIndex,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      newNodeNotificationsEnabled:
          newNodeNotificationsEnabled ?? this.newNodeNotificationsEnabled,
      directMessageNotificationsEnabled:
          directMessageNotificationsEnabled ??
          this.directMessageNotificationsEnabled,
      channelMessageNotificationsEnabled:
          channelMessageNotificationsEnabled ??
          this.channelMessageNotificationsEnabled,
      notificationSoundEnabled:
          notificationSoundEnabled ?? this.notificationSoundEnabled,
      notificationVibrationEnabled:
          notificationVibrationEnabled ?? this.notificationVibrationEnabled,
      hapticFeedbackEnabled:
          hapticFeedbackEnabled ?? this.hapticFeedbackEnabled,
      hapticIntensity: hapticIntensity ?? this.hapticIntensity,
      animationsEnabled: animationsEnabled ?? this.animationsEnabled,
      animations3DEnabled: animations3DEnabled ?? this.animations3DEnabled,
      cannedResponsesJson: cannedResponsesJson ?? this.cannedResponsesJson,
      tapbackConfigsJson: tapbackConfigsJson ?? this.tapbackConfigsJson,
      ringtoneRtttl: ringtoneRtttl ?? this.ringtoneRtttl,
      ringtoneName: ringtoneName ?? this.ringtoneName,
      splashMeshSize: splashMeshSize ?? this.splashMeshSize,
      splashMeshAnimationType:
          splashMeshAnimationType ?? this.splashMeshAnimationType,
      splashMeshGlowIntensity:
          splashMeshGlowIntensity ?? this.splashMeshGlowIntensity,
      splashMeshLineThickness:
          splashMeshLineThickness ?? this.splashMeshLineThickness,
      splashMeshNodeSize: splashMeshNodeSize ?? this.splashMeshNodeSize,
      splashMeshColorPreset:
          splashMeshColorPreset ?? this.splashMeshColorPreset,
      splashMeshUseAccelerometer:
          splashMeshUseAccelerometer ?? this.splashMeshUseAccelerometer,
      splashMeshAccelSensitivity:
          splashMeshAccelSensitivity ?? this.splashMeshAccelSensitivity,
      splashMeshAccelFriction:
          splashMeshAccelFriction ?? this.splashMeshAccelFriction,
      splashMeshPhysicsMode:
          splashMeshPhysicsMode ?? this.splashMeshPhysicsMode,
      splashMeshEnableTouch:
          splashMeshEnableTouch ?? this.splashMeshEnableTouch,
      splashMeshEnablePullToStretch:
          splashMeshEnablePullToStretch ?? this.splashMeshEnablePullToStretch,
      splashMeshTouchIntensity:
          splashMeshTouchIntensity ?? this.splashMeshTouchIntensity,
      splashMeshStretchIntensity:
          splashMeshStretchIntensity ?? this.splashMeshStretchIntensity,
      automationsJson: automationsJson ?? this.automationsJson,
      iftttConfigJson: iftttConfigJson ?? this.iftttConfigJson,
    );
  }

  /// Check if any preferences are set
  bool get isEmpty =>
      themeModeIndex == null &&
      notificationsEnabled == null &&
      cannedResponsesJson == null &&
      tapbackConfigsJson == null &&
      ringtoneRtttl == null &&
      splashMeshSize == null;
}

/// User profile model for the Socialmesh ecosystem.
///
/// This represents a user's identity across the app, enabling:
/// - Profile display and customization
/// - Cloud sync when signed in
/// - QR-based profile sharing
/// - Social features and connections
class UserProfile {
  /// Unique identifier (matches Firebase Auth UID when signed in)
  final String id;

  /// Display name shown throughout the app
  final String displayName;

  /// Optional avatar image URL (local file path or cloud URL)
  final String? avatarUrl;

  /// Optional banner/header image URL (local file path or cloud URL)
  final String? bannerUrl;

  /// Short bio or status message
  final String? bio;

  /// Amateur radio callsign or mesh identifier
  final String? callsign;

  /// Email address (from Firebase Auth when signed in)
  final String? email;

  /// Optional website or link
  final String? website;

  /// Social media handles
  final ProfileSocialLinks? socialLinks;

  /// Favorite Meshtastic node ID (their primary device)
  final int? primaryNodeId;

  /// All Meshtastic node IDs linked to this profile
  final List<int> linkedNodeIds;

  /// User's preferred accent color index
  final int? accentColorIndex;

  /// IDs of marketplace widgets installed by the user
  final List<String> installedWidgetIds;

  /// User preferences that sync to cloud
  final UserPreferences? preferences;

  /// When the profile was created
  final DateTime createdAt;

  /// When the profile was last updated
  final DateTime updatedAt;

  /// Whether this profile has been synced to cloud
  final bool isSynced;

  /// Whether the user is verified (e.g., email verified, identity confirmed)
  final bool isVerified;

  // === Social counters (read-only, managed by Cloud Functions) ===

  /// Number of users following this profile
  final int followerCount;

  /// Number of users this profile follows
  final int followingCount;

  /// Number of posts created by this user
  final int postCount;

  const UserProfile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.bannerUrl,
    this.bio,
    this.callsign,
    this.email,
    this.website,
    this.socialLinks,
    this.primaryNodeId,
    this.linkedNodeIds = const [],
    this.accentColorIndex,
    this.installedWidgetIds = const [],
    this.preferences,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.isVerified = false,
    this.followerCount = 0,
    this.followingCount = 0,
    this.postCount = 0,
  });

  /// Create an empty/guest profile
  factory UserProfile.guest() {
    final now = DateTime.now();
    return UserProfile(
      id: 'guest_${now.millisecondsSinceEpoch}',
      displayName: 'Mesh User',
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create from Firebase Auth user
  factory UserProfile.fromFirebaseUser({
    required String uid,
    String? email,
    String? displayName,
    String? photoUrl,
  }) {
    final now = DateTime.now();
    return UserProfile(
      id: uid,
      displayName: displayName ?? email?.split('@').first ?? 'Mesh User',
      email: email,
      avatarUrl: photoUrl,
      createdAt: now,
      updatedAt: now,
      isSynced: true,
    );
  }

  /// Create from JSON
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      bannerUrl: json['bannerUrl'] as String?,
      bio: json['bio'] as String?,
      callsign: json['callsign'] as String?,
      email: json['email'] as String?,
      website: json['website'] as String?,
      socialLinks: json['socialLinks'] != null
          ? ProfileSocialLinks.fromJson(
              json['socialLinks'] as Map<String, dynamic>,
            )
          : null,
      primaryNodeId: json['primaryNodeId'] as int?,
      linkedNodeIds:
          (json['linkedNodeIds'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [],
      accentColorIndex: json['accentColorIndex'] as int?,
      installedWidgetIds:
          (json['installedWidgetIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      preferences: json['preferences'] != null
          ? UserPreferences.fromJson(
              json['preferences'] as Map<String, dynamic>,
            )
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isSynced: json['isSynced'] as bool? ?? false,
      isVerified: json['isVerified'] as bool? ?? false,
      followerCount: json['followerCount'] as int? ?? 0,
      followingCount: json['followingCount'] as int? ?? 0,
      postCount: json['postCount'] as int? ?? 0,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'bannerUrl': bannerUrl,
      'bio': bio,
      'callsign': callsign,
      'email': email,
      'website': website,
      'socialLinks': socialLinks?.toJson(),
      'primaryNodeId': primaryNodeId,
      'linkedNodeIds': linkedNodeIds,
      'accentColorIndex': accentColorIndex,
      'installedWidgetIds': installedWidgetIds,
      'preferences': preferences?.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isSynced': isSynced,
      'isVerified': isVerified,
      'followerCount': followerCount,
      'followingCount': followingCount,
      'postCount': postCount,
    };
  }

  /// Convert to JSON string
  String toJsonString() => jsonEncode(toJson());

  /// Create from JSON string
  factory UserProfile.fromJsonString(String jsonString) {
    return UserProfile.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  /// Create a copy with updated fields
  UserProfile copyWith({
    String? id,
    String? displayName,
    String? avatarUrl,
    String? bannerUrl,
    String? bio,
    String? callsign,
    String? email,
    String? website,
    ProfileSocialLinks? socialLinks,
    int? primaryNodeId,
    List<int>? linkedNodeIds,
    int? accentColorIndex,
    List<String>? installedWidgetIds,
    UserPreferences? preferences,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    bool? isVerified,
    int? followerCount,
    int? followingCount,
    int? postCount,
    bool clearAvatarUrl = false,
    bool clearBannerUrl = false,
    bool clearBio = false,
    bool clearCallsign = false,
    bool clearWebsite = false,
    bool clearSocialLinks = false,
    bool clearPrimaryNodeId = false,
  }) {
    return UserProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
      bannerUrl: clearBannerUrl ? null : (bannerUrl ?? this.bannerUrl),
      bio: clearBio ? null : (bio ?? this.bio),
      callsign: clearCallsign ? null : (callsign ?? this.callsign),
      email: email ?? this.email,
      website: clearWebsite ? null : (website ?? this.website),
      socialLinks: clearSocialLinks ? null : (socialLinks ?? this.socialLinks),
      primaryNodeId: clearPrimaryNodeId
          ? null
          : (primaryNodeId ?? this.primaryNodeId),
      linkedNodeIds: linkedNodeIds ?? this.linkedNodeIds,
      accentColorIndex: accentColorIndex ?? this.accentColorIndex,
      installedWidgetIds: installedWidgetIds ?? this.installedWidgetIds,
      preferences: preferences ?? this.preferences,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isSynced: isSynced ?? this.isSynced,
      isVerified: isVerified ?? this.isVerified,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      postCount: postCount ?? this.postCount,
    );
  }

  /// Whether this is a guest profile (not signed in)
  bool get isGuest => id.startsWith('guest_');

  /// Get initials for avatar fallback
  String get initials {
    final parts = displayName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
  }

  /// Get a display identifier (callsign if available, otherwise display name)
  String get displayIdentifier => callsign ?? displayName;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'UserProfile(id: $id, displayName: $displayName)';
}

/// Social media links for a user profile
class ProfileSocialLinks {
  final String? twitter;
  final String? mastodon;
  final String? github;
  final String? linkedin;
  final String? discord;
  final String? telegram;

  const ProfileSocialLinks({
    this.twitter,
    this.mastodon,
    this.github,
    this.linkedin,
    this.discord,
    this.telegram,
  });

  factory ProfileSocialLinks.fromJson(Map<String, dynamic> json) {
    return ProfileSocialLinks(
      twitter: json['twitter'] as String?,
      mastodon: json['mastodon'] as String?,
      github: json['github'] as String?,
      linkedin: json['linkedin'] as String?,
      discord: json['discord'] as String?,
      telegram: json['telegram'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'twitter': twitter,
      'mastodon': mastodon,
      'github': github,
      'linkedin': linkedin,
      'discord': discord,
      'telegram': telegram,
    };
  }

  ProfileSocialLinks copyWith({
    String? twitter,
    String? mastodon,
    String? github,
    String? linkedin,
    String? discord,
    String? telegram,
    bool clearTwitter = false,
    bool clearMastodon = false,
    bool clearGithub = false,
    bool clearLinkedin = false,
    bool clearDiscord = false,
    bool clearTelegram = false,
  }) {
    return ProfileSocialLinks(
      twitter: clearTwitter ? null : (twitter ?? this.twitter),
      mastodon: clearMastodon ? null : (mastodon ?? this.mastodon),
      github: clearGithub ? null : (github ?? this.github),
      linkedin: clearLinkedin ? null : (linkedin ?? this.linkedin),
      discord: clearDiscord ? null : (discord ?? this.discord),
      telegram: clearTelegram ? null : (telegram ?? this.telegram),
    );
  }

  /// Whether all links are empty
  bool get isEmpty =>
      twitter == null &&
      mastodon == null &&
      github == null &&
      linkedin == null &&
      discord == null &&
      telegram == null;

  /// Count of non-null links
  int get linkCount {
    var count = 0;
    if (twitter != null) count++;
    if (mastodon != null) count++;
    if (github != null) count++;
    if (linkedin != null) count++;
    if (discord != null) count++;
    if (telegram != null) count++;
    return count;
  }
}

/// Compact profile data for QR code sharing
class SharedProfileData {
  final String displayName;
  final String? callsign;
  final String? bio;
  final int? primaryNodeId;

  const SharedProfileData({
    required this.displayName,
    this.callsign,
    this.bio,
    this.primaryNodeId,
  });

  factory SharedProfileData.fromProfile(UserProfile profile) {
    return SharedProfileData(
      displayName: profile.displayName,
      callsign: profile.callsign,
      bio: profile.bio,
      primaryNodeId: profile.primaryNodeId,
    );
  }

  factory SharedProfileData.fromJson(Map<String, dynamic> json) {
    return SharedProfileData(
      displayName: json['n'] as String,
      callsign: json['c'] as String?,
      bio: json['b'] as String?,
      primaryNodeId: json['p'] as int?,
    );
  }

  /// Compact JSON for QR codes (short keys to reduce data size)
  Map<String, dynamic> toJson() {
    return {
      'n': displayName,
      if (callsign != null) 'c': callsign,
      if (bio != null) 'b': bio,
      if (primaryNodeId != null) 'p': primaryNodeId,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory SharedProfileData.fromJsonString(String jsonString) {
    return SharedProfileData.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }
}
