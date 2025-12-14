import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../models/widget_schema.dart';

/// Service for interacting with the widget marketplace
class WidgetMarketplaceService {
  // Base URL for the marketplace API - configured via .env
  final String baseUrl;
  final Logger _logger;
  final http.Client _client;

  /// Get the base URL from environment or use platform-specific fallback
  static String get _defaultBaseUrl {
    // First check .env configuration for explicit marketplace URL
    final envUrl = dotenv.env['MARKETPLACE_URL'];
    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl;
    }

    const productionUrl = 'https://api.socialmesh.app/widgets';

    // Check .env flag for local API usage
    final useLocalApi = dotenv.env['USE_LOCAL_API']?.toLowerCase() == 'true';
    if (useLocalApi) {
      final localHost = dotenv.env['LOCAL_API_HOST'] ?? '192.168.5.77';
      if (kIsWeb) {
        return 'http://localhost:3000/api/widgets';
      } else {
        return 'http://$localHost:3000/api/widgets';
      }
    }

    return productionUrl;
  }

  WidgetMarketplaceService({
    String? baseUrl,
    Logger? logger,
    http.Client? client,
  }) : baseUrl = baseUrl ?? _defaultBaseUrl,
       _logger = logger ?? Logger(),
       _client = client ?? http.Client();

  /// Browse widgets from marketplace
  Future<MarketplaceResponse> browse({
    int page = 1,
    int limit = 20,
    String? category,
    String? sortBy,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (category != null) 'category': category,
        if (sortBy != null) 'sort': sortBy,
        if (search != null) 'q': search,
      };

      final uri = Uri.parse(
        '$baseUrl/browse',
      ).replace(queryParameters: queryParams);

      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return MarketplaceResponse.fromJson(json);
      } else {
        _logger.e('Marketplace browse failed: ${response.statusCode}');
        throw MarketplaceException(
          'Failed to load widgets: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is MarketplaceException) rethrow;
      _logger.e('Marketplace browse error: $e');
      // Return mock data for offline/development
      return _getMockBrowseResponse();
    }
  }

  /// Get featured widgets
  Future<List<MarketplaceWidget>> getFeatured() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/featured'));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as List<dynamic>;
        return json
            .map(
              (item) =>
                  MarketplaceWidget.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      } else {
        throw MarketplaceException('Failed to load featured widgets');
      }
    } catch (e) {
      if (e is MarketplaceException) rethrow;
      _logger.e('Featured widgets error: $e');
      return _getMockFeatured();
    }
  }

  /// Get widget details
  Future<MarketplaceWidget> getWidget(String id) async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/$id'));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return MarketplaceWidget.fromJson(json);
      } else if (response.statusCode == 404) {
        throw MarketplaceException('Widget not found');
      } else {
        throw MarketplaceException('Failed to load widget');
      }
    } catch (e) {
      if (e is MarketplaceException) rethrow;
      _logger.e('Get widget error: $e');
      rethrow;
    }
  }

  /// Download widget schema
  Future<WidgetSchema> downloadWidget(String id) async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/$id/download'));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return WidgetSchema.fromJson(json);
      } else {
        throw MarketplaceException('Failed to download widget');
      }
    } catch (e) {
      if (e is MarketplaceException) rethrow;
      _logger.e('Download widget error: $e');
      // Return mock widget for offline/development
      final mockWidget = _getMockWidgetSchema(id);
      if (mockWidget != null) {
        return mockWidget;
      }
      throw MarketplaceException('Failed to download widget: $e');
    }
  }

  /// Get mock widget schema by ID (for offline/development)
  WidgetSchema? _getMockWidgetSchema(String id) {
    final mockSchemas = <String, Map<String, dynamic>>{
      'battery-gauge-pro': {
        'name': 'Battery Gauge Pro',
        'description': 'Beautiful animated battery indicator',
        'version': '1.2.0',
        'tags': ['battery', 'gauge', 'animated'],
        'root': {
          'type': 'column',
          'style': {
            'padding': 16,
            'spacing': 8,
            'backgroundColor': '#1E1E1E',
            'borderRadius': 12,
          },
          'children': [
            {
              'type': 'row',
              'style': {'mainAxisAlignment': 'spaceBetween'},
              'children': [
                {
                  'type': 'icon',
                  'iconName': 'battery_full',
                  'style': {'iconSize': 24, 'textColor': '#4ADE80'},
                },
                {
                  'type': 'text',
                  'text': 'Battery',
                  'style': {
                    'fontSize': 14,
                    'fontWeight': 'w600',
                    'textColor': '#FFFFFF',
                  },
                },
              ],
            },
            {
              'type': 'gauge',
              'binding': {'path': 'node.batteryLevel'},
              'gaugeType': 'radial',
              'gaugeMin': 0,
              'gaugeMax': 100,
              'gaugeColor': '#4ADE80',
              'style': {'width': 80, 'height': 80},
            },
            {
              'type': 'text',
              'binding': {'path': 'node.batteryLevel', 'format': '{value}%'},
              'style': {
                'fontSize': 28,
                'fontWeight': 'bold',
                'textColor': '#FFFFFF',
              },
            },
          ],
        },
      },
      'signal-radar': {
        'name': 'Signal Radar',
        'description': 'Animated radar-style signal strength visualization',
        'version': '1.0.0',
        'tags': ['signal', 'radar', 'animated'],
        'root': {
          'type': 'column',
          'style': {
            'padding': 16,
            'spacing': 12,
            'backgroundColor': '#1E1E1E',
            'borderRadius': 12,
          },
          'children': [
            {
              'type': 'row',
              'children': [
                {
                  'type': 'icon',
                  'iconName': 'radar',
                  'style': {'iconSize': 20, 'textColor': '#8B5CF6'},
                },
                {
                  'type': 'spacer',
                  'style': {'width': 8},
                },
                {
                  'type': 'text',
                  'text': 'Signal',
                  'style': {
                    'fontSize': 14,
                    'fontWeight': 'w600',
                    'textColor': '#FFFFFF',
                  },
                },
              ],
            },
            {
              'type': 'gauge',
              'binding': {'path': 'node.snr'},
              'gaugeType': 'radial',
              'gaugeMin': -20,
              'gaugeMax': 15,
              'gaugeColor': '#8B5CF6',
              'style': {'width': 80, 'height': 80},
            },
            {
              'type': 'row',
              'style': {'mainAxisAlignment': 'spaceBetween'},
              'children': [
                {
                  'type': 'text',
                  'binding': {'path': 'node.snr', 'format': '{value} dB'},
                  'style': {'fontSize': 14, 'textColor': '#FFFFFF'},
                },
                {
                  'type': 'text',
                  'binding': {'path': 'node.rssi', 'format': '{value} dBm'},
                  'style': {'fontSize': 14, 'textColor': '#808080'},
                },
              ],
            },
          ],
        },
      },
      'weather-station': {
        'name': 'Weather Station',
        'description': 'Complete weather display',
        'version': '2.0.0',
        'tags': ['weather', 'temperature', 'environment'],
        'root': {
          'type': 'column',
          'style': {
            'padding': 16,
            'spacing': 12,
            'backgroundColor': '#1E1E1E',
            'borderRadius': 12,
          },
          'children': [
            {
              'type': 'row',
              'children': [
                {
                  'type': 'icon',
                  'iconName': 'thermostat',
                  'style': {'iconSize': 20, 'textColor': '#F97316'},
                },
                {
                  'type': 'spacer',
                  'style': {'width': 8},
                },
                {
                  'type': 'text',
                  'text': 'Weather',
                  'style': {
                    'fontSize': 14,
                    'fontWeight': 'w600',
                    'textColor': '#FFFFFF',
                  },
                },
              ],
            },
            {
              'type': 'row',
              'style': {'mainAxisAlignment': 'spaceAround'},
              'children': [
                {
                  'type': 'column',
                  'style': {'alignment': 'center'},
                  'children': [
                    {
                      'type': 'text',
                      'binding': {
                        'path': 'node.temperature',
                        'format': '{value}°',
                      },
                      'style': {
                        'fontSize': 24,
                        'fontWeight': 'bold',
                        'textColor': '#EF4444',
                      },
                    },
                    {
                      'type': 'text',
                      'text': 'Temp',
                      'style': {'fontSize': 10, 'textColor': '#808080'},
                    },
                  ],
                },
                {
                  'type': 'column',
                  'style': {'alignment': 'center'},
                  'children': [
                    {
                      'type': 'text',
                      'binding': {
                        'path': 'node.humidity',
                        'format': '{value}%',
                      },
                      'style': {
                        'fontSize': 24,
                        'fontWeight': 'bold',
                        'textColor': '#06B6D4',
                      },
                    },
                    {
                      'type': 'text',
                      'text': 'Humidity',
                      'style': {'fontSize': 10, 'textColor': '#808080'},
                    },
                  ],
                },
              ],
            },
          ],
        },
      },
    };

    if (mockSchemas.containsKey(id)) {
      return WidgetSchema.fromJson(mockSchemas[id]!);
    }
    return null;
  }

  /// Upload widget to marketplace
  Future<MarketplaceWidget> uploadWidget(
    WidgetSchema widget,
    String authToken,
  ) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/upload'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(widget.toJson()),
      );

      if (response.statusCode == 201) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return MarketplaceWidget.fromJson(json);
      } else if (response.statusCode == 401) {
        throw MarketplaceException('Authentication required');
      } else {
        throw MarketplaceException('Failed to upload widget');
      }
    } catch (e) {
      if (e is MarketplaceException) rethrow;
      _logger.e('Upload widget error: $e');
      rethrow;
    }
  }

  /// Rate a widget
  Future<void> rateWidget(String id, int rating, String authToken) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/$id/rate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'rating': rating}),
      );

      if (response.statusCode != 200) {
        throw MarketplaceException('Failed to rate widget');
      }
    } catch (e) {
      if (e is MarketplaceException) rethrow;
      _logger.e('Rate widget error: $e');
      rethrow;
    }
  }

  /// Report a widget
  Future<void> reportWidget(String id, String reason, String authToken) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/$id/report'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'reason': reason}),
      );

      if (response.statusCode != 200) {
        throw MarketplaceException('Failed to report widget');
      }
    } catch (e) {
      if (e is MarketplaceException) rethrow;
      _logger.e('Report widget error: $e');
      rethrow;
    }
  }

  /// Search widgets
  Future<MarketplaceResponse> search(String query, {int page = 1}) async {
    return browse(page: page, search: query);
  }

  /// Get widgets by category
  Future<MarketplaceResponse> getByCategory(
    String category, {
    int page = 1,
  }) async {
    return browse(page: page, category: category);
  }

  /// Get popular widgets
  Future<MarketplaceResponse> getPopular({int page = 1}) async {
    return browse(page: page, sortBy: 'downloads');
  }

  /// Get newest widgets
  Future<MarketplaceResponse> getNewest({int page = 1}) async {
    return browse(page: page, sortBy: 'newest');
  }

  /// Get top rated widgets
  Future<MarketplaceResponse> getTopRated({int page = 1}) async {
    return browse(page: page, sortBy: 'rating');
  }

  // Mock data for offline/development
  MarketplaceResponse _getMockBrowseResponse() {
    return MarketplaceResponse(
      widgets: _getMockFeatured(),
      total: 5,
      page: 1,
      hasMore: false,
    );
  }

  List<MarketplaceWidget> _getMockFeatured() {
    return [
      MarketplaceWidget(
        id: 'battery-gauge-pro',
        name: 'Battery Gauge Pro',
        description:
            'Beautiful animated battery indicator with low power warnings',
        author: 'MeshMaster',
        authorId: 'user-123',
        version: '1.2.0',
        thumbnailUrl: null,
        downloads: 1250,
        rating: 4.8,
        ratingCount: 156,
        tags: ['battery', 'gauge', 'animated'],
        category: 'status',
        isFeatured: true,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        updatedAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      MarketplaceWidget(
        id: 'weather-station',
        name: 'Weather Station',
        description:
            'Complete weather display with temperature, humidity, and pressure',
        author: 'WeatherWizard',
        authorId: 'user-456',
        version: '2.0.0',
        thumbnailUrl: null,
        downloads: 890,
        rating: 4.5,
        ratingCount: 89,
        tags: ['weather', 'temperature', 'environment'],
        category: 'sensors',
        isFeatured: true,
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
        updatedAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
      MarketplaceWidget(
        id: 'signal-radar',
        name: 'Signal Radar',
        description: 'Animated radar-style signal strength visualization',
        author: 'RadioRanger',
        authorId: 'user-789',
        version: '1.0.0',
        thumbnailUrl: null,
        downloads: 567,
        rating: 4.3,
        ratingCount: 45,
        tags: ['signal', 'radar', 'animated'],
        category: 'connectivity',
        isFeatured: true,
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      MarketplaceWidget(
        id: 'node-compass',
        name: 'Node Compass',
        description: 'Shows direction and distance to selected node',
        author: 'NavigatorNick',
        authorId: 'user-101',
        version: '1.1.0',
        thumbnailUrl: null,
        downloads: 432,
        rating: 4.6,
        ratingCount: 67,
        tags: ['navigation', 'compass', 'direction'],
        category: 'navigation',
        isFeatured: true,
        createdAt: DateTime.now().subtract(const Duration(days: 45)),
        updatedAt: DateTime.now().subtract(const Duration(days: 8)),
      ),
      MarketplaceWidget(
        id: 'network-stats',
        name: 'Network Statistics',
        description:
            'Live mesh network statistics with packet counts and graphs',
        author: 'DataDave',
        authorId: 'user-202',
        version: '1.5.0',
        thumbnailUrl: null,
        downloads: 321,
        rating: 4.4,
        ratingCount: 34,
        tags: ['network', 'statistics', 'packets'],
        category: 'network',
        isFeatured: true,
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
        updatedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];
  }

  // ============ Admin Methods ============

  /// Get the base URL for admin endpoints (without /widgets suffix)
  String get _adminBaseUrl {
    // Remove /widgets suffix to get base API URL
    if (baseUrl.endsWith('/widgets')) {
      return '${baseUrl.substring(0, baseUrl.length - 8)}/admin';
    }
    return '$baseUrl/admin';
  }

  /// Get pending widgets for review (admin only)
  Future<List<MarketplaceWidget>> getPendingWidgets(String authToken) async {
    try {
      final response = await _client.get(
        Uri.parse('$_adminBaseUrl/pending'),
        headers: {'Authorization': 'Bearer $authToken'},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as List<dynamic>;
        return json
            .map(
              (item) =>
                  MarketplaceWidget.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      } else if (response.statusCode == 401) {
        throw MarketplaceException('Authentication required');
      } else if (response.statusCode == 403) {
        throw MarketplaceException('Admin access required');
      } else {
        throw MarketplaceException('Failed to get pending widgets');
      }
    } catch (e) {
      if (e is MarketplaceException) rethrow;
      _logger.e('Get pending widgets error: $e');
      rethrow;
    }
  }

  /// Approve a widget (admin only)
  Future<void> approveWidget(String id, String authToken) async {
    try {
      final response = await _client.post(
        Uri.parse('$_adminBaseUrl/widgets/$id/approve'),
        headers: {'Authorization': 'Bearer $authToken'},
      );

      if (response.statusCode != 200) {
        if (response.statusCode == 401) {
          throw MarketplaceException('Authentication required');
        } else if (response.statusCode == 403) {
          throw MarketplaceException('Admin access required');
        } else {
          throw MarketplaceException('Failed to approve widget');
        }
      }
    } catch (e) {
      if (e is MarketplaceException) rethrow;
      _logger.e('Approve widget error: $e');
      rethrow;
    }
  }

  /// Reject a widget (admin only)
  Future<void> rejectWidget(String id, String reason, String authToken) async {
    try {
      final response = await _client.post(
        Uri.parse('$_adminBaseUrl/widgets/$id/reject'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'reason': reason}),
      );

      if (response.statusCode != 200) {
        if (response.statusCode == 401) {
          throw MarketplaceException('Authentication required');
        } else if (response.statusCode == 403) {
          throw MarketplaceException('Admin access required');
        } else {
          throw MarketplaceException('Failed to reject widget');
        }
      }
    } catch (e) {
      if (e is MarketplaceException) rethrow;
      _logger.e('Reject widget error: $e');
      rethrow;
    }
  }

  /// Get user's own widgets (My Submissions)
  Future<List<MarketplaceWidget>> getMyWidgets(String authToken) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/user/mine'),
        headers: {'Authorization': 'Bearer $authToken'},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as List<dynamic>;
        return json
            .map(
              (item) =>
                  MarketplaceWidget.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      } else if (response.statusCode == 401) {
        throw MarketplaceException('Authentication required');
      } else {
        throw MarketplaceException('Failed to get your widgets');
      }
    } catch (e) {
      if (e is MarketplaceException) rethrow;
      _logger.e('Get my widgets error: $e');
      rethrow;
    }
  }
}

/// Response from marketplace browse/search
class MarketplaceResponse {
  final List<MarketplaceWidget> widgets;
  final int total;
  final int page;
  final bool hasMore;

  MarketplaceResponse({
    required this.widgets,
    required this.total,
    required this.page,
    required this.hasMore,
  });

  factory MarketplaceResponse.fromJson(Map<String, dynamic> json) {
    return MarketplaceResponse(
      widgets: (json['widgets'] as List<dynamic>)
          .map(
            (item) => MarketplaceWidget.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}

/// Widget listing from marketplace
class MarketplaceWidget {
  final String id;
  final String name;
  final String description;
  final String author;
  final String authorId;
  final String version;
  final String? thumbnailUrl;
  final int downloads;
  final double rating;
  final int ratingCount;
  final List<String> tags;
  final String category;
  final String status;
  final bool isFeatured;
  final DateTime createdAt;
  final DateTime updatedAt;

  MarketplaceWidget({
    required this.id,
    required this.name,
    required this.description,
    required this.author,
    required this.authorId,
    required this.version,
    this.thumbnailUrl,
    required this.downloads,
    required this.rating,
    required this.ratingCount,
    required this.tags,
    required this.category,
    this.status = 'approved',
    this.isFeatured = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MarketplaceWidget.fromJson(Map<String, dynamic> json) {
    return MarketplaceWidget(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      author: json['author'] as String,
      authorId: json['authorId'] as String,
      version: json['version'] as String? ?? '1.0.0',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      downloads: json['downloads'] as int? ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: json['ratingCount'] as int? ?? 0,
      tags:
          (json['tags'] as List<dynamic>?)?.map((t) => t as String).toList() ??
          [],
      category: json['category'] as String? ?? 'general',
      status: json['status'] as String? ?? 'approved',
      isFeatured: json['isFeatured'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }
}

/// Marketplace exception
class MarketplaceException implements Exception {
  final String message;
  MarketplaceException(this.message);

  @override
  String toString() => 'MarketplaceException: $message';
}

/// Widget categories
class WidgetCategories {
  static const status = 'status';
  static const sensors = 'sensors';
  static const connectivity = 'connectivity';
  static const navigation = 'navigation';
  static const network = 'network';
  static const messaging = 'messaging';
  static const general = 'general';

  static const all = [
    status,
    sensors,
    connectivity,
    navigation,
    network,
    messaging,
    general,
  ];

  static String getDisplayName(String category) {
    switch (category) {
      case status:
        return 'Status';
      case sensors:
        return 'Sensors';
      case connectivity:
        return 'Connectivity';
      case navigation:
        return 'Navigation';
      case network:
        return 'Network';
      case messaging:
        return 'Messaging';
      case general:
        return 'General';
      default:
        return category;
    }
  }
}
