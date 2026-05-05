// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';

import '../../core/logging.dart';
import 'deep_link_types.dart';

/// Parses deep link URIs into typed [ParsedDeepLink] objects.
///
/// This is the single source of truth for all deep link parsing in the app.
/// It handles multiple URI formats for backwards compatibility:
///
/// **Custom Scheme (socialmesh://):**
/// - `socialmesh://node/{base64}` - Node from QR code
/// - `socialmesh://channel/{base64}` - Channel import (legacy)
/// - `socialmesh://channel/id:{firestoreId}` - Channel from cloud sharing
/// - `socialmesh://profile/{userId}` - User profile
/// - `socialmesh://widget/{widgetId}` - Widget detail
/// - `socialmesh://post/{postId}` - Post detail
/// - `socialmesh://location?lat=X&lng=Y&label=Z` - Map location
/// - `socialmesh://automation/{base64}` - Automation template
///
/// **Universal Links (https://socialmesh.app/share/...):**
/// - `https://socialmesh.app/share/node/{firestoreId}` - Node from web
/// - `https://socialmesh.app/share/channel/{firestoreId}` - Channel from web
/// - `https://socialmesh.app/share/profile/{userId}` - Profile from web
/// - `https://socialmesh.app/share/widget/{widgetId}` - Widget from web
/// - `https://socialmesh.app/share/post/{postId}` - Post from web
/// - `https://socialmesh.app/share/location?lat=X&lng=Y` - Location from web
/// - `https://socialmesh.app/share/automation/{automationId}` - Automation from web
///
/// **Legacy Formats:**
/// - `meshtastic://node/{base64}` - Legacy node format
/// - `https://meshtastic.org/e/#{urlEncodedBase64}` - Legacy channel format
class DeepLinkParser {
  const DeepLinkParser();

  /// Supported custom schemes.
  static const _supportedSchemes = ['socialmesh', 'meshtastic'];

  /// Supported web hosts.
  static const _supportedHosts = ['socialmesh.app'];

  /// Legacy channel host.
  static const _legacyChannelHost = 'meshtastic.org';

  /// Parse a URI string into a [ParsedDeepLink].
  ///
  /// This method never throws. Invalid or malformed URIs return a
  /// [ParsedDeepLink] with type [DeepLinkType.invalid].
  ParsedDeepLink parse(String uriString) {
    AppLogging.qr('🔗 Parser: Parsing URI: $uriString');

    if (uriString.isEmpty) {
      AppLogging.qr('🔗 Parser: ERROR - Empty URI');
      return ParsedDeepLink.invalid(uriString, ['Empty URI']);
    }

    try {
      final uri = Uri.parse(uriString);
      AppLogging.qr(
        '🔗 Parser: Parsed - scheme=${uri.scheme}, host=${uri.host}, '
        'path=${uri.path}, segments=${uri.pathSegments}, query=${uri.queryParameters}',
      );

      // Handle custom schemes (socialmesh://, meshtastic://)
      if (_supportedSchemes.contains(uri.scheme)) {
        AppLogging.qr('🔗 Parser: Routing to custom scheme handler');
        return _parseCustomScheme(uri, uriString);
      }

      // Handle universal links (https://socialmesh.app/...)
      if (uri.scheme == 'https' && _supportedHosts.contains(uri.host)) {
        AppLogging.qr('🔗 Parser: Routing to universal link handler');
        return _parseUniversalLink(uri, uriString);
      }

      // Handle legacy Meshtastic channel links
      if (uri.scheme == 'https' && uri.host == _legacyChannelHost) {
        AppLogging.qr('🔗 Parser: Routing to legacy channel handler');
        return _parseLegacyChannelLink(uri, uriString);
      }

      // Handle plain HTTP URLs with fragments (legacy fallback)
      if (uri.scheme == 'http' || uri.scheme == 'https') {
        if (uri.fragment.isNotEmpty) {
          AppLogging.qr('🔗 Parser: Routing to legacy fragment handler');
          return _parseLegacyChannelLink(uri, uriString);
        }
      }

      AppLogging.qr(
        'QR - 🔗 Parser: ERROR - Unsupported URI scheme: ${uri.scheme}',
      );
      return ParsedDeepLink.invalid(uriString, [
        'Unsupported URI scheme: ${uri.scheme}', // lint-allow: hardcoded-string
      ]);
    } catch (e) {
      AppLogging.qr('🔗 Parser: ERROR - Failed to parse URI: $e');
      return ParsedDeepLink.invalid(uriString, ['Failed to parse URI: $e']);
    }
  }

  /// Parse a custom scheme URI (socialmesh://, meshtastic://).
  ///
  /// Custom scheme URIs are parsed as: scheme://host/path
  /// For example: socialmesh://node/abc123
  /// - host = "node" (the link type)
  /// - path = "/abc123" (the data)
  ParsedDeepLink _parseCustomScheme(Uri uri, String original) {
    // For custom schemes, the "host" is actually the link type
    final type = uri.host;

    // The path contains the data (first path segment after the leading /)
    final segments = uri.pathSegments;
    final data = segments.isNotEmpty ? segments[0] : null;

    AppLogging.qr('🔗 Parser: Custom scheme - type=$type, data=$data');

    // Handle empty type
    if (type.isEmpty) {
      AppLogging.qr(
        'QR - 🔗 Parser: ERROR - Missing link type in custom scheme',
      );
      return ParsedDeepLink.invalid(original, ['Missing link type']);
    }

    switch (type) {
      case 'node':
        AppLogging.qr('🔗 Parser: Processing node link');
        return _parseNodeLink(data, uri.queryParameters, original);
      case 'channel':
        AppLogging.qr('🔗 Parser: Processing channel link');
        return _parseChannelLink(data, original);
      case 'profile':
        AppLogging.qr('🔗 Parser: Processing profile link');
        return _parseProfileLink(data, original);
      case 'widget':
        AppLogging.qr('🔗 Parser: Processing widget link');
        return _parseWidgetLink(data, original);
      case 'post':
        AppLogging.qr('🔗 Parser: Processing post link');
        return _parsePostLink(data, original);
      case 'location':
        AppLogging.qr('🔗 Parser: Processing location link');
        return _parseLocationLink(uri.queryParameters, original);
      case 'automation':
        AppLogging.qr('🔗 Parser: Processing automation link');
        return _parseAutomationLink(data, original);
      case 'channel-invite':
        AppLogging.qr('🔗 Parser: Processing channel invite link');
        return _parseChannelInviteLink(data, uri.fragment, original);
      case 'aether':
        AppLogging.qr('🔗 Parser: Processing aether flight link');
        return _parseAetherFlightLink(segments, original);
      case 'legal':
        // socialmesh://legal/terms or socialmesh://legal/privacy
        AppLogging.qr('🔗 Parser: Processing legal document link');
        final document = data; // 'terms' or 'privacy'
        if (document == null ||
            (document != 'terms' && document != 'privacy')) {
          return ParsedDeepLink.invalid(original, [
            'Invalid legal document type: $document', // lint-allow: hardcoded-string
          ]);
        }
        final anchor = uri.fragment.isNotEmpty ? uri.fragment : null;
        return ParsedDeepLink(
          type: DeepLinkType.legal,
          originalUri: original,
          legalDocument: document,
          legalSectionAnchor: anchor,
        );
      case 'purchase-return':
        // socialmesh://purchase-return?sessionId=XYZ
        // The sessionId alone never unlocks anything — it triggers the
        // confirmation-polling loop in ExternalPurchaseService, which
        // only succeeds after the Buy Me a Coffee webhook lands.
        AppLogging.qr('🔗 Parser: Processing purchase return link');
        final sessionId = uri.queryParameters['sessionId'];
        if (sessionId == null || sessionId.isEmpty) {
          return ParsedDeepLink.invalid(original, [
            'Missing sessionId in purchase-return link',
          ]);
        }
        return ParsedDeepLink(
          type: DeepLinkType.purchaseReturn,
          originalUri: original,
          purchaseSessionId: sessionId,
        );
      default:
        AppLogging.qr('🔗 Parser: ERROR - Unknown link type: $type');
        return ParsedDeepLink.invalid(original, ['Unknown link type: $type']);
    }
  }

  /// Parse a universal link (https://socialmesh.app/share/...).
  ParsedDeepLink _parseUniversalLink(Uri uri, String original) {
    final segments = uri.pathSegments;
    AppLogging.qr('🔗 Parser: Universal link - segments=$segments');

    // Handle legal document links: /terms and /privacy
    if (segments.length == 1 &&
        (segments[0] == 'terms' || segments[0] == 'privacy')) {
      final document = segments[0];
      // Extract optional section anchor from the fragment (e.g. #radio-compliance)
      final anchor = uri.fragment.isNotEmpty ? uri.fragment : null;
      AppLogging.qr(
        '🔗 Parser: Legal document link - document=$document, anchor=$anchor',
      );
      return ParsedDeepLink(
        type: DeepLinkType.legal,
        originalUri: original,
        legalDocument: document,
        legalSectionAnchor: anchor,
      );
    }

    // Handle Aether flight links: /aether/flight/{shareId}
    if (segments.isNotEmpty && segments[0] == 'aether') {
      AppLogging.qr('🔗 Parser: Aether flight universal link');
      return _parseAetherFlightLink(segments.sublist(1), original);
    }

    // Expect: /share/{type}/{id} or /share/{type}?params
    if (segments.isEmpty || segments[0] != 'share') {
      AppLogging.qr(
        'QR - 🔗 Parser: ERROR - Invalid web link path: ${uri.path}',
      );
      return ParsedDeepLink.invalid(original, [
        'Invalid web link path: ${uri.path}', // lint-allow: hardcoded-string
      ]);
    }

    if (segments.length < 2) {
      AppLogging.qr('🔗 Parser: ERROR - Missing link type in path');
      return ParsedDeepLink.invalid(original, ['Missing link type in path']);
    }

    final type = segments[1];
    final id = segments.length > 2 ? segments[2] : null;
    AppLogging.qr('🔗 Parser: Universal link - type=$type, id=$id');

    switch (type) {
      case 'node':
        // Web share links use Firestore doc ID
        if (id == null || id.isEmpty) {
          AppLogging.qr('🔗 Parser: ERROR - Missing node ID');
          return ParsedDeepLink.invalid(original, ['Missing node ID']);
        }
        AppLogging.qr(
          'QR - 🔗 Parser: Returning node link with firestoreId=$id',
        );
        return ParsedDeepLink(
          type: DeepLinkType.node,
          originalUri: original,
          nodeFirestoreId: id,
        );

      case 'profile':
        if (id == null || id.isEmpty) {
          AppLogging.qr('🔗 Parser: ERROR - Missing profile display name');
          return ParsedDeepLink.invalid(original, [
            'Missing profile display name', // lint-allow: hardcoded-string
          ]);
        }
        AppLogging.qr(
          'QR - 🔗 Parser: Returning profile link with displayName=$id',
        );
        return ParsedDeepLink(
          type: DeepLinkType.profile,
          originalUri: original,
          profileDisplayName: id,
        );

      case 'widget':
        if (id == null || id.isEmpty) {
          AppLogging.qr('🔗 Parser: ERROR - Missing widget ID');
          return ParsedDeepLink.invalid(original, ['Missing widget ID']);
        }
        AppLogging.qr(
          'QR - 🔗 Parser: Returning widget link with widgetId=$id',
        );
        return ParsedDeepLink(
          type: DeepLinkType.widget,
          originalUri: original,
          widgetId: id,
        );

      case 'post':
        if (id == null || id.isEmpty) {
          AppLogging.qr('🔗 Parser: ERROR - Missing post ID');
          return ParsedDeepLink.invalid(original, ['Missing post ID']);
        }
        AppLogging.qr('🔗 Parser: Returning post link with postId=$id');
        return ParsedDeepLink(
          type: DeepLinkType.post,
          originalUri: original,
          postId: id,
        );

      case 'location':
        AppLogging.qr('🔗 Parser: Processing location from query params');
        return _parseLocationLink(uri.queryParameters, original);

      case 'channel':
        // Check for invite fragment (#t=secret)
        if (id != null && id.isNotEmpty && uri.fragment.isNotEmpty) {
          AppLogging.qr(
            '🔗 Parser: Channel URL has fragment — treating as invite',
          );
          return _parseChannelInviteLink(id, uri.fragment, original);
        }
        // Web share links use Firestore doc ID
        if (id == null || id.isEmpty) {
          AppLogging.qr('🔗 Parser: ERROR - Missing channel ID');
          return ParsedDeepLink.invalid(original, ['Missing channel ID']);
        }
        AppLogging.qr('🔗 Parser: Returning channel link with firestoreId=$id');
        return ParsedDeepLink(
          type: DeepLinkType.channel,
          originalUri: original,
          channelFirestoreId: id,
        );

      case 'automation':
        // Web share links use Firestore doc ID
        if (id == null || id.isEmpty) {
          AppLogging.qr('🔗 Parser: ERROR - Missing automation ID');
          return ParsedDeepLink.invalid(original, ['Missing automation ID']);
        }
        AppLogging.qr(
          '🔗 Parser: Returning automation link with firestoreId=$id',
        );
        return ParsedDeepLink(
          type: DeepLinkType.automation,
          originalUri: original,
          automationFirestoreId: id,
        );

      default:
        return ParsedDeepLink.invalid(original, [
          'Unknown web link type: $type', // lint-allow: hardcoded-string
        ]);
    }
  }

  /// Parse legacy Meshtastic channel links.
  ParsedDeepLink _parseLegacyChannelLink(Uri uri, String original) {
    // Format: https://meshtastic.org/e/#{urlEncodedBase64}
    if (uri.fragment.isEmpty) {
      return ParsedDeepLink.invalid(original, [
        'No channel data in URL fragment', // lint-allow: hardcoded-string
      ]);
    }

    try {
      final base64Data = Uri.decodeComponent(uri.fragment);
      if (base64Data.isEmpty) {
        return ParsedDeepLink.invalid(original, ['Empty channel data']);
      }
      return ParsedDeepLink(
        type: DeepLinkType.channel,
        originalUri: original,
        channelBase64Data: base64Data,
      );
    } catch (e) {
      return ParsedDeepLink.invalid(original, [
        'Failed to decode channel data: $e', // lint-allow: hardcoded-string
      ]);
    }
  }

  /// Parse an Aether flight deep link.
  ///
  /// Handles both:
  /// - Custom scheme: `socialmesh://aether/flight/{shareId}` (segments = ['flight', '{shareId}'])
  /// - Universal link: `https://socialmesh.app/aether/flight/{shareId}` (segments = ['flight', '{shareId}'])
  ParsedDeepLink _parseAetherFlightLink(
    List<String> segments,
    String original,
  ) {
    // Expect: flight/{shareId}
    if (segments.isEmpty || segments[0] != 'flight') {
      AppLogging.qr(
        '\ud83d\udd17 Parser: ERROR - Expected aether/flight/{id}, '
        'got segments=$segments',
      );
      return ParsedDeepLink.invalid(original, [
        'Invalid Aether link path, expected /aether/flight/{shareId}', // lint-allow: hardcoded-string
      ]);
    }

    final shareId = segments.length > 1 ? segments[1] : null;
    if (shareId == null || shareId.isEmpty) {
      AppLogging.qr(
        '\ud83d\udd17 Parser: ERROR - Missing Aether flight share ID',
      );
      return ParsedDeepLink.invalid(original, [
        'Missing Aether flight share ID', // lint-allow: hardcoded-string
      ]);
    }

    AppLogging.qr(
      '\ud83d\udd17 Parser: Returning Aether flight link with shareId=$shareId',
    );
    return ParsedDeepLink(
      type: DeepLinkType.aetherFlight,
      originalUri: original,
      aetherFlightShareId: shareId,
    );
  }

  /// Parse a node deep link from path data.
  ParsedDeepLink _parseNodeLink(
    String? data,
    Map<String, String> queryParams,
    String original,
  ) {
    AppLogging.qr(
      '🔗 Parser: _parseNodeLink - data=$data, queryParams=$queryParams',
    );

    if (data == null || data.isEmpty) {
      AppLogging.qr('🔗 Parser: ERROR - Missing node data');
      return ParsedDeepLink(
        type: DeepLinkType.node,
        originalUri: original,
        validationErrors: ['Missing node data'],
      );
    }

    // Try to decode as base64 JSON (QR code format)
    try {
      final decoded = utf8.decode(base64Decode(data));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      AppLogging.qr('🔗 Parser: Decoded base64 JSON: $json');

      final nodeNum = json['nodeNum'] as int?;
      if (nodeNum == null) {
        AppLogging.qr(
          'QR - 🔗 Parser: ERROR - Missing nodeNum in decoded JSON',
        );
        return ParsedDeepLink(
          type: DeepLinkType.node,
          originalUri: original,
          validationErrors: ['Missing nodeNum in node data'],
        );
      }

      AppLogging.qr(
        'QR - 🔗 Parser: Returning node link with nodeNum=$nodeNum',
      );
      return ParsedDeepLink(
        type: DeepLinkType.node,
        originalUri: original,
        nodeNum: nodeNum,
        nodeLongName: json['longName'] as String?,
        nodeShortName: json['shortName'] as String?,
        nodeUserId: json['userId'] as String?,
        nodeLatitude: (json['lat'] as num?)?.toDouble(),
        nodeLongitude: (json['lon'] as num?)?.toDouble(),
      );
    } catch (e) {
      // Not valid base64 JSON - treat as Firestore document ID
      AppLogging.qr(
        '🔗 Parser: Node data is not base64 (error: $e), treating as Firestore ID: $data',
      );
      return ParsedDeepLink(
        type: DeepLinkType.node,
        originalUri: original,
        nodeFirestoreId: data,
      );
    }
  }

  /// Parse a channel deep link.
  ///
  /// Handles:
  /// - id:{firestoreId} - Cloud-stored channel from QR code sharing
  /// - Base64-encoded protobuf channel data (legacy/direct QR sharing)
  ParsedDeepLink _parseChannelLink(String? data, String original) {
    if (data == null || data.isEmpty) {
      return ParsedDeepLink(
        type: DeepLinkType.channel,
        originalUri: original,
        validationErrors: ['Missing channel data'],
      );
    }

    // Check for Firestore ID prefix (from cloud-stored channels)
    // Format: id:{firestoreId}
    if (data.startsWith('id:')) {
      final firestoreId = data.substring(3);
      if (firestoreId.isEmpty) {
        return ParsedDeepLink.invalid(original, [
          'Missing channel Firestore ID', // lint-allow: hardcoded-string
        ]);
      }
      AppLogging.qr('🔗 Parser: Detected Firestore channel ID: $firestoreId');
      return ParsedDeepLink(
        type: DeepLinkType.channel,
        originalUri: original,
        channelFirestoreId: firestoreId,
      );
    }

    // Try URL decoding in case it's URL-encoded
    String channelData = data;
    try {
      channelData = Uri.decodeComponent(data);
    } catch (_) {
      // Use raw data if decode fails
    }

    // Accept any non-empty data - the channel import screen will validate
    return ParsedDeepLink(
      type: DeepLinkType.channel,
      originalUri: original,
      channelBase64Data: channelData,
    );
  }

  /// Parse a profile deep link.
  ParsedDeepLink _parseProfileLink(String? data, String original) {
    AppLogging.qr('🔗 Parser: _parseProfileLink - data=$data');
    if (data == null || data.isEmpty) {
      AppLogging.qr('🔗 Parser: ERROR - Missing profile display name');
      return ParsedDeepLink(
        type: DeepLinkType.profile,
        originalUri: original,
        validationErrors: ['Missing profile display name'],
      );
    }
    AppLogging.qr(
      'QR - 🔗 Parser: Returning profile link with displayName=$data',
    );
    return ParsedDeepLink(
      type: DeepLinkType.profile,
      originalUri: original,
      profileDisplayName: data,
    );
  }

  /// Parse a widget deep link.
  /// Handles:
  /// - id:{firestoreId} - Cloud-stored widget from QR code sharing
  /// - Marketplace widget IDs (Firestore document IDs)
  /// - Base64-encoded widget schemas (legacy from QR code sharing)
  ParsedDeepLink _parseWidgetLink(String? data, String original) {
    if (data == null || data.isEmpty) {
      return ParsedDeepLink.invalid(original, ['Missing widget ID']);
    }

    // Check for Firestore ID prefix (from cloud-stored widgets)
    // Format: id:{firestoreId}
    if (data.startsWith('id:')) {
      final firestoreId = data.substring(3);
      if (firestoreId.isEmpty) {
        return ParsedDeepLink.invalid(original, [
          'Missing widget Firestore ID', // lint-allow: hardcoded-string
        ]);
      }
      AppLogging.qr('🔗 Parser: Detected Firestore widget ID: $firestoreId');
      return ParsedDeepLink(
        type: DeepLinkType.widget,
        originalUri: original,
        widgetFirestoreId: firestoreId,
      );
    }

    // Check if it's base64-encoded widget schema data (legacy)
    // Base64 data from share is typically longer and starts with 'ey' (base64 for '{')
    // Firestore IDs are typically 20-28 characters and alphanumeric
    if (_isBase64WidgetData(data)) {
      AppLogging.qr('🔗 Parser: Detected base64 widget schema');
      return ParsedDeepLink(
        type: DeepLinkType.widget,
        originalUri: original,
        widgetBase64Data: data,
      );
    }

    // Otherwise treat as marketplace widget ID
    return ParsedDeepLink(
      type: DeepLinkType.widget,
      originalUri: original,
      widgetId: data,
    );
  }

  /// Check if the data looks like base64-encoded widget schema.
  /// Base64 widget data is typically very long (1000+ chars) and
  /// starts with 'ey' which is base64 for '{"'
  bool _isBase64WidgetData(String data) {
    // Widget schemas are complex and result in long base64 strings
    // Firestore IDs are typically 20-28 characters
    if (data.length < 100) return false;

    // Try to decode and verify it's a widget schema
    try {
      // URL-safe base64 uses - and _ instead of + and /
      final normalized = data.replaceAll('-', '+').replaceAll('_', '/');
      // Add padding if needed
      final padded = normalized.padRight((normalized.length + 3) & ~3, '=');
      final decoded = utf8.decode(base64Decode(padded));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      // Check for required widget schema fields
      return json.containsKey('name') && json.containsKey('root');
    } catch (e) {
      return false;
    }
  }

  /// Parse a post deep link.
  ParsedDeepLink _parsePostLink(String? data, String original) {
    if (data == null || data.isEmpty) {
      return ParsedDeepLink.invalid(original, ['Missing post ID']);
    }
    return ParsedDeepLink(
      type: DeepLinkType.post,
      originalUri: original,
      postId: data,
    );
  }

  /// Parse a location deep link from query parameters.
  ParsedDeepLink _parseLocationLink(
    Map<String, String> params,
    String original,
  ) {
    final latStr = params['lat'];
    final lngStr = params['lng'];
    final errors = <String>[];

    double? lat;
    double? lng;

    // Validate latitude
    if (latStr == null) {
      errors.add('Missing latitude'); // lint-allow: hardcoded-string
    } else {
      lat = double.tryParse(latStr);
      if (lat == null) {
        errors.add('Invalid latitude'); // lint-allow: hardcoded-string
      } else if (lat < -90 || lat > 90) {
        errors.add(
          'Latitude out of range: $lat',
        ); // lint-allow: hardcoded-string
      }
    }

    // Validate longitude
    if (lngStr == null) {
      errors.add('Missing longitude'); // lint-allow: hardcoded-string
    } else {
      lng = double.tryParse(lngStr);
      if (lng == null) {
        errors.add('Invalid longitude'); // lint-allow: hardcoded-string
      } else if (lng < -180 || lng > 180) {
        errors.add(
          'Longitude out of range: $lng',
        ); // lint-allow: hardcoded-string
      }
    }

    return ParsedDeepLink(
      type: DeepLinkType.location,
      originalUri: original,
      locationLatitude: lat,
      locationLongitude: lng,
      locationLabel: params['label'],
      validationErrors: errors,
    );
  }

  /// Parse an automation deep link.
  ///
  /// Handles both formats:
  /// - Base64-encoded JSON (legacy QR codes): contains full automation data
  /// - Firestore document ID (web shares): short alphanumeric ID
  ParsedDeepLink _parseAutomationLink(String? data, String original) {
    if (data == null || data.isEmpty) {
      return ParsedDeepLink(
        type: DeepLinkType.automation,
        originalUri: original,
        validationErrors: ['Missing automation data'],
      );
    }

    // Try to decode as base64 JSON (legacy QR code format)
    try {
      // Restore URL-safe base64 to standard base64
      final standardBase64 = data.replaceAll('-', '+').replaceAll('_', '/');
      // Add padding if needed
      final padded = standardBase64.padRight(
        (standardBase64.length + 3) & ~3,
        '=',
      );
      final decoded = utf8.decode(base64Decode(padded));
      // Verify it's valid JSON (automation data is always a JSON object)
      final json = jsonDecode(decoded);
      if (json is Map<String, dynamic>) {
        AppLogging.qr(
          '🔗 Parser: Decoded automation base64 JSON: ${json['name'] ?? 'unnamed'}',
        );
        return ParsedDeepLink(
          type: DeepLinkType.automation,
          originalUri: original,
          automationBase64Data: data,
        );
      }
      // If not a JSON object, treat as Firestore ID
      throw FormatException('Not a valid automation JSON object');
    } catch (e) {
      // Not valid base64 JSON - treat as Firestore document ID
      AppLogging.qr(
        '🔗 Parser: Automation data is not base64 (error: $e), '
        'treating as Firestore ID: $data',
      );
      return ParsedDeepLink(
        type: DeepLinkType.automation,
        originalUri: original,
        automationFirestoreId: data,
      );
    }
  }

  /// Parse a channel invite link.
  ///
  /// Handles the #t=... fragment to extract the invite secret.
  /// Used for both:
  /// - `socialmesh://channel-invite/{inviteId}#t={secret}`
  /// - `https://socialmesh.app/share/channel/{inviteId}#t={secret}`
  ParsedDeepLink _parseChannelInviteLink(
    String? inviteId,
    String fragment,
    String original,
  ) {
    if (inviteId == null || inviteId.isEmpty) {
      return ParsedDeepLink.invalid(original, ['Missing invite ID']);
    }

    // Extract secret from fragment: "t=<secret>"
    String? secret;
    if (fragment.startsWith('t=')) {
      secret = fragment.substring(2);
    } else {
      // Try parsing as key-value pairs
      final parts = fragment.split('&');
      for (final part in parts) {
        if (part.startsWith('t=')) {
          secret = part.substring(2);
          break;
        }
      }
    }

    if (secret == null || secret.isEmpty) {
      AppLogging.qr('🔗 Parser: Channel invite missing secret in fragment');
      return ParsedDeepLink.invalid(original, [
        'Missing invite secret in URL fragment', // lint-allow: hardcoded-string
      ]);
    }

    AppLogging.qr(
      '🔗 Parser: Channel invite parsed — id=$inviteId, '
      'secret=<redacted ${secret.length} chars>',
    );

    return ParsedDeepLink(
      type: DeepLinkType.channelInvite,
      originalUri: original,
      channelInviteId: inviteId,
      channelInviteSecret: secret,
    );
  }
}

/// Singleton parser instance.
const deepLinkParser = DeepLinkParser();
