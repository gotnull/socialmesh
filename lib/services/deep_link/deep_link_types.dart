// SPDX-License-Identifier: GPL-3.0-or-later

/// All supported deep link types in Socialmesh.
///
/// Each type corresponds to a specific feature/screen that can be
/// reached via deep link. The `invalid` type is used for malformed
/// links that should fail gracefully.
enum DeepLinkType {
  /// Node sharing: socialmesh://node/{base64} or https://socialmesh.app/share/node/{id}
  node,

  /// Channel import: socialmesh://channel/{base64} or socialmesh://channel/id:{firestoreId} or https://socialmesh.app/share/channel/{id}
  channel,

  /// User profile: socialmesh://profile/{displayName} or https://socialmesh.app/share/profile/{displayName}
  profile,

  /// Widget marketplace: socialmesh://widget/{widgetId} or https://socialmesh.app/share/widget/{id}
  widget,

  /// Social post: socialmesh://post/{postId} or https://socialmesh.app/share/post/{id}
  post,

  /// Map location: socialmesh://location?lat=X&lng=Y or https://socialmesh.app/share/location?...
  location,

  /// Automation template: socialmesh://automation/{base64} or https://socialmesh.app/share/automation/{id}
  automation,

  /// Channel invite: socialmesh://channel-invite/{inviteId}#t={secret}
  /// or https://socialmesh.app/share/channel/{inviteId}#t={secret}
  channelInvite,

  /// Invalid/unrecognized deep link - routes to fallback
  invalid,
}

/// Represents a fully parsed and validated deep link.
///
/// This is the canonical model for all deep links in the app.
/// All deep link handlers receive this type after parsing.
class ParsedDeepLink {
  const ParsedDeepLink({
    required this.type,
    required this.originalUri,
    this.nodeNum,
    this.nodeLongName,
    this.nodeShortName,
    this.nodeUserId,
    this.nodeLatitude,
    this.nodeLongitude,
    this.nodeFirestoreId,
    this.channelBase64Data,
    this.channelFirestoreId,
    this.profileDisplayName,
    this.widgetId,
    this.widgetBase64Data,
    this.widgetFirestoreId,
    this.postId,
    this.locationLatitude,
    this.locationLongitude,
    this.locationLabel,
    this.automationBase64Data,
    this.automationFirestoreId,
    this.channelInviteId,
    this.channelInviteSecret,
    this.validationErrors = const [],
  });

  /// The type of deep link.
  final DeepLinkType type;

  /// The original URI string that was parsed.
  final String originalUri;

  // Node-specific fields
  final int? nodeNum;
  final String? nodeLongName;
  final String? nodeShortName;
  final String? nodeUserId;
  final double? nodeLatitude;
  final double? nodeLongitude;
  final String? nodeFirestoreId;

  // Channel-specific fields
  final String? channelBase64Data;

  /// Firestore document ID for cloud-stored shared channels
  final String? channelFirestoreId;

  // Profile-specific fields
  final String? profileDisplayName;

  // Widget-specific fields
  /// Marketplace widget ID (Firestore document ID)
  final String? widgetId;

  /// Base64-encoded widget schema for direct sharing (QR code/deep link)
  final String? widgetBase64Data;

  /// Firestore document ID for cloud-stored shared widgets
  final String? widgetFirestoreId;

  // Post-specific fields
  final String? postId;

  // Location-specific fields
  final double? locationLatitude;
  final double? locationLongitude;
  final String? locationLabel;

  // Automation-specific fields
  final String? automationBase64Data;
  final String? automationFirestoreId;

  // Channel invite fields
  /// Invite ID from the URL path
  final String? channelInviteId;

  /// Invite secret from the URL fragment (#t=...)
  final String? channelInviteSecret;

  /// Validation errors encountered during parsing.
  /// Empty list means the deep link is valid.
  final List<String> validationErrors;

  /// Whether this deep link is valid and can be routed.
  bool get isValid => type != DeepLinkType.invalid && validationErrors.isEmpty;

  /// Whether this node link needs to fetch data from Firestore.
  bool get needsFirestoreFetch =>
      type == DeepLinkType.node && nodeFirestoreId != null && nodeNum == null;

  /// Whether this node link has complete data for local processing.
  bool get hasCompleteNodeData => type == DeepLinkType.node && nodeNum != null;

  /// Whether this widget link has base64 data for direct import.
  bool get hasWidgetBase64Data =>
      type == DeepLinkType.widget && widgetBase64Data != null;

  /// Whether this widget link needs to fetch data from Firestore.
  bool get hasWidgetFirestoreId =>
      type == DeepLinkType.widget && widgetFirestoreId != null;

  /// Whether this channel link has base64 data for direct import.
  bool get hasChannelBase64Data =>
      type == DeepLinkType.channel && channelBase64Data != null;

  /// Whether this channel link needs to fetch data from Firestore.
  bool get hasChannelFirestoreId =>
      type == DeepLinkType.channel && channelFirestoreId != null;

  /// Whether this is a complete channel invite link.
  bool get hasChannelInvite =>
      type == DeepLinkType.channelInvite &&
      channelInviteId != null &&
      channelInviteSecret != null;

  /// Create an invalid deep link with errors.
  factory ParsedDeepLink.invalid(String originalUri, List<String> errors) {
    return ParsedDeepLink(
      type: DeepLinkType.invalid,
      originalUri: originalUri,
      validationErrors: errors,
    );
  }

  /// Create a copy with updated node data (after Firestore fetch).
  ParsedDeepLink copyWithNodeData({
    int? nodeNum,
    String? nodeLongName,
    String? nodeShortName,
    String? nodeUserId,
    double? nodeLatitude,
    double? nodeLongitude,
  }) {
    return ParsedDeepLink(
      type: type,
      originalUri: originalUri,
      nodeNum: nodeNum ?? this.nodeNum,
      nodeLongName: nodeLongName ?? this.nodeLongName,
      nodeShortName: nodeShortName ?? this.nodeShortName,
      nodeUserId: nodeUserId ?? this.nodeUserId,
      nodeLatitude: nodeLatitude ?? this.nodeLatitude,
      nodeLongitude: nodeLongitude ?? this.nodeLongitude,
      nodeFirestoreId: nodeFirestoreId,
      channelBase64Data: channelBase64Data,
      channelFirestoreId: channelFirestoreId,
      profileDisplayName: profileDisplayName,
      widgetId: widgetId,
      widgetFirestoreId: widgetFirestoreId,
      postId: postId,
      locationLatitude: locationLatitude,
      automationBase64Data: automationBase64Data,
      automationFirestoreId: automationFirestoreId,
      channelInviteId: channelInviteId,
      channelInviteSecret: channelInviteSecret,
      locationLongitude: locationLongitude,
      locationLabel: locationLabel,
      validationErrors: validationErrors,
    );
  }

  @override
  String toString() {
    return 'ParsedDeepLink(type: $type, uri: $originalUri, valid: $isValid, errors: $validationErrors)';
  }
}

/// Result of a deep link routing operation.
class DeepLinkRouteResult {
  const DeepLinkRouteResult({
    required this.routeName,
    this.arguments,
    this.requiresAuth = false,
    this.requiresDevice = false,
    this.fallbackMessage,
  });

  /// The route name to navigate to.
  final String routeName;

  /// Arguments to pass to the route.
  final Map<String, dynamic>? arguments;

  /// Whether this route requires authentication.
  final bool requiresAuth;

  /// Whether this route requires a connected device.
  final bool requiresDevice;

  /// Message to show if navigation fails.
  final String? fallbackMessage;

  /// Fallback route when the primary route cannot be reached.
  static const DeepLinkRouteResult fallback = DeepLinkRouteResult(
    routeName: '/main',
    fallbackMessage: 'Unable to open link',
  );

  @override
  String toString() {
    return 'DeepLinkRouteResult(route: $routeName, args: $arguments)';
  }
}
