// SPDX-License-Identifier: GPL-3.0-or-later
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
/// - `socialmesh://channel/{base64}` - Channel import
/// - `socialmesh://profile/{userId}` - User profile
/// - `socialmesh://widget/{widgetId}` - Widget detail
/// - `socialmesh://post/{postId}` - Post detail
/// - `socialmesh://location?lat=X&lng=Y&label=Z` - Map location
/// - `socialmesh://automation/{base64}` - Automation template
///
/// **Universal Links (https://socialmesh.app/share/...):**
/// - `https://socialmesh.app/share/node/{firestoreId}` - Node from web
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
    if (uriString.isEmpty) {
      return ParsedDeepLink.invalid(uriString, ['Empty URI']);
    }

    try {
      final uri = Uri.parse(uriString);
      AppLogging.debug(
        '🔗 Parser: scheme=${uri.scheme}, host=${uri.host}, path=${uri.path}',
      );

      // Handle custom schemes (socialmesh://, meshtastic://)
      if (_supportedSchemes.contains(uri.scheme)) {
        return _parseCustomScheme(uri, uriString);
      }

      // Handle universal links (https://socialmesh.app/...)
      if (uri.scheme == 'https' && _supportedHosts.contains(uri.host)) {
        return _parseUniversalLink(uri, uriString);
      }

      // Handle legacy Meshtastic channel links
      if (uri.scheme == 'https' && uri.host == _legacyChannelHost) {
        return _parseLegacyChannelLink(uri, uriString);
      }

      // Handle plain HTTP URLs with fragments (legacy fallback)
      if (uri.scheme == 'http' || uri.scheme == 'https') {
        if (uri.fragment.isNotEmpty) {
          return _parseLegacyChannelLink(uri, uriString);
        }
      }

      return ParsedDeepLink.invalid(uriString, [
        'Unsupported URI scheme: ${uri.scheme}',
      ]);
    } catch (e) {
      AppLogging.debug('🔗 Parser: Failed to parse URI: $e');
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

    // Handle empty type
    if (type.isEmpty) {
      return ParsedDeepLink.invalid(original, ['Missing link type']);
    }

    switch (type) {
      case 'node':
        return _parseNodeLink(data, uri.queryParameters, original);
      case 'channel':
        return _parseChannelLink(data, original);
      case 'profile':
        return _parseProfileLink(data, original);
      case 'widget':
        return _parseWidgetLink(data, original);
      case 'post':
        return _parsePostLink(data, original);
      case 'location':
        return _parseLocationLink(uri.queryParameters, original);
      case 'automation':
        return _parseAutomationLink(data, original);
      default:
        return ParsedDeepLink.invalid(original, ['Unknown link type: $type']);
    }
  }

  /// Parse a universal link (https://socialmesh.app/share/...).
  ParsedDeepLink _parseUniversalLink(Uri uri, String original) {
    final segments = uri.pathSegments;

    // Expect: /share/{type}/{id} or /share/{type}?params
    if (segments.isEmpty || segments[0] != 'share') {
      return ParsedDeepLink.invalid(original, [
        'Invalid web link path: ${uri.path}',
      ]);
    }

    if (segments.length < 2) {
      return ParsedDeepLink.invalid(original, ['Missing link type in path']);
    }

    final type = segments[1];
    final id = segments.length > 2 ? segments[2] : null;

    switch (type) {
      case 'node':
        // Web share links use Firestore doc ID
        if (id == null || id.isEmpty) {
          return ParsedDeepLink.invalid(original, ['Missing node ID']);
        }
        return ParsedDeepLink(
          type: DeepLinkType.node,
          originalUri: original,
          nodeFirestoreId: id,
        );

      case 'profile':
        if (id == null || id.isEmpty) {
          return ParsedDeepLink.invalid(original, [
            'Missing profile display name',
          ]);
        }
        return ParsedDeepLink(
          type: DeepLinkType.profile,
          originalUri: original,
          profileDisplayName: id,
        );

      case 'widget':
        if (id == null || id.isEmpty) {
          return ParsedDeepLink.invalid(original, ['Missing widget ID']);
        }
        return ParsedDeepLink(
          type: DeepLinkType.widget,
          originalUri: original,
          widgetId: id,
        );

      case 'post':
        if (id == null || id.isEmpty) {
          return ParsedDeepLink.invalid(original, ['Missing post ID']);
        }
        return ParsedDeepLink(
          type: DeepLinkType.post,
          originalUri: original,
          postId: id,
        );

      case 'location':
        return _parseLocationLink(uri.queryParameters, original);

      case 'automation':
        // Web share links use Firestore doc ID
        if (id == null || id.isEmpty) {
          return ParsedDeepLink.invalid(original, ['Missing automation ID']);
        }
        return ParsedDeepLink(
          type: DeepLinkType.automation,
          originalUri: original,
          automationFirestoreId: id,
        );

      default:
        return ParsedDeepLink.invalid(original, [
          'Unknown web link type: $type',
        ]);
    }
  }

  /// Parse legacy Meshtastic channel links.
  ParsedDeepLink _parseLegacyChannelLink(Uri uri, String original) {
    // Format: https://meshtastic.org/e/#{urlEncodedBase64}
    if (uri.fragment.isEmpty) {
      return ParsedDeepLink.invalid(original, [
        'No channel data in URL fragment',
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
        'Failed to decode channel data: $e',
      ]);
    }
  }

  /// Parse a node deep link from path data.
  ParsedDeepLink _parseNodeLink(
    String? data,
    Map<String, String> queryParams,
    String original,
  ) {
    if (data == null || data.isEmpty) {
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

      final nodeNum = json['nodeNum'] as int?;
      if (nodeNum == null) {
        return ParsedDeepLink(
          type: DeepLinkType.node,
          originalUri: original,
          validationErrors: ['Missing nodeNum in node data'],
        );
      }

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
    } catch (_) {
      // Not valid base64 JSON - treat as Firestore document ID
      AppLogging.debug(
        '🔗 Parser: Node data is not base64, treating as Firestore ID',
      );
      return ParsedDeepLink(
        type: DeepLinkType.node,
        originalUri: original,
        nodeFirestoreId: data,
      );
    }
  }

  /// Parse a channel deep link.
  ParsedDeepLink _parseChannelLink(String? data, String original) {
    if (data == null || data.isEmpty) {
      return ParsedDeepLink(
        type: DeepLinkType.channel,
        originalUri: original,
        validationErrors: ['Missing channel data'],
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
    if (data == null || data.isEmpty) {
      return ParsedDeepLink(
        type: DeepLinkType.profile,
        originalUri: original,
        validationErrors: ['Missing profile display name'],
      );
    }
    return ParsedDeepLink(
      type: DeepLinkType.profile,
      originalUri: original,
      profileDisplayName: data,
    );
  }

  /// Parse a widget deep link.
  ParsedDeepLink _parseWidgetLink(String? data, String original) {
    if (data == null || data.isEmpty) {
      return ParsedDeepLink.invalid(original, ['Missing widget ID']);
    }
    return ParsedDeepLink(
      type: DeepLinkType.widget,
      originalUri: original,
      widgetId: data,
    );
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
      errors.add('Missing latitude');
    } else {
      lat = double.tryParse(latStr);
      if (lat == null) {
        errors.add('Invalid latitude');
      } else if (lat < -90 || lat > 90) {
        errors.add('Latitude out of range: $lat');
      }
    }

    // Validate longitude
    if (lngStr == null) {
      errors.add('Missing longitude');
    } else {
      lng = double.tryParse(lngStr);
      if (lng == null) {
        errors.add('Invalid longitude');
      } else if (lng < -180 || lng > 180) {
        errors.add('Longitude out of range: $lng');
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

  /// Parse an automation deep link from base64 data.
  ParsedDeepLink _parseAutomationLink(String? data, String original) {
    if (data == null || data.isEmpty) {
      return ParsedDeepLink(
        type: DeepLinkType.automation,
        originalUri: original,
        validationErrors: ['Missing automation data'],
      );
    }

    return ParsedDeepLink(
      type: DeepLinkType.automation,
      originalUri: original,
      automationBase64Data: data,
    );
  }
}

/// Singleton parser instance.
const deepLinkParser = DeepLinkParser();
