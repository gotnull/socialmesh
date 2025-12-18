import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

  /// Maximum number of retry attempts for transient network errors
  static const int _maxRetries = 3;

  /// Initial delay between retries (doubles with each attempt)
  static const Duration _retryDelay = Duration(milliseconds: 500);

  /// Get the base URL from environment or use platform-specific fallback
  static String get _defaultBaseUrl {
    // First check .env configuration for explicit marketplace URL
    final envUrl = dotenv.env['MARKETPLACE_URL'];
    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl;
    }

    // Default to Firebase Cloud Functions
    return 'https://us-central1-social-mesh-app.cloudfunctions.net';
  }

  WidgetMarketplaceService({
    String? baseUrl,
    Logger? logger,
    http.Client? client,
  }) : baseUrl = baseUrl ?? _defaultBaseUrl,
       _logger = logger ?? Logger(),
       _client = client ?? http.Client();

  /// Execute a GET request with retry logic for transient failures
  Future<http.Response> _getWithRetry(
    Uri uri, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    Exception? lastException;

    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          final delay =
              _retryDelay * (1 << (attempt - 1)); // Exponential backoff
          await Future<void>.delayed(delay);
        }

        final response = await _client
            .get(uri)
            .timeout(
              timeout,
              onTimeout: () {
                throw TimeoutException(
                  'Request timed out after ${timeout.inSeconds}s',
                );
              },
            );
        return response;
      } on SocketException catch (e) {
        lastException = e;
        _logger.w('Socket error (attempt $attempt): $e');
      } on HttpException catch (e) {
        lastException = e;
        _logger.w('HTTP error (attempt $attempt): $e');
      } on http.ClientException catch (e) {
        lastException = e;
        _logger.w('Client error (attempt $attempt): $e');
      } on TimeoutException catch (e) {
        lastException = e;
        _logger.w('Timeout (attempt $attempt): $e');
      }
    }

    throw lastException ??
        Exception('Request failed after $_maxRetries attempts');
  }

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
        '$baseUrl/widgetsBrowse',
      ).replace(queryParameters: queryParams);

      final response = await _getWithRetry(uri);

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
      throw MarketplaceException('Failed to load widgets: $e');
    }
  }

  /// Get featured widgets
  Future<List<MarketplaceWidget>> getFeatured() async {
    try {
      final uri = Uri.parse('$baseUrl/widgetsFeatured');
      final response = await _getWithRetry(uri);

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
      throw MarketplaceException('Failed to load featured widgets: $e');
    }
  }

  /// Get widget details
  Future<MarketplaceWidget> getWidget(String id) async {
    try {
      final uri = Uri.parse('$baseUrl/widgetsGet/$id');
      final response = await _getWithRetry(uri);

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
      final uri = Uri.parse(
        '$baseUrl/widgetsDownload',
      ).replace(queryParameters: {'id': id});
      final response = await _getWithRetry(uri);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return WidgetSchema.fromJson(json);
      } else {
        throw MarketplaceException('Failed to download widget');
      }
    } catch (e) {
      if (e is MarketplaceException) rethrow;
      _logger.e('Download widget error: $e');
      throw MarketplaceException('Failed to download widget: $e');
    }
  }

  /// Upload widget to marketplace
  Future<MarketplaceWidget> uploadWidget(
    WidgetSchema widget,
    String authToken,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/widgetsUpload'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode(widget.toJson()),
          )
          .timeout(const Duration(seconds: 2));

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
      final response = await _client
          .post(
            Uri.parse(
              '$baseUrl/widgetsRate',
            ).replace(queryParameters: {'id': id}),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({'rating': rating}),
          )
          .timeout(const Duration(seconds: 2));

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
      final response = await _client
          .post(
            Uri.parse('$baseUrl/$id/report'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({'reason': reason}),
          )
          .timeout(const Duration(seconds: 2));

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

/// Widget categories - aligned with Firestore categories collection
class WidgetCategories {
  static const deviceStatus = 'device-status';
  static const metrics = 'metrics';
  static const charts = 'charts';
  static const mesh = 'mesh';
  static const location = 'location';
  static const weather = 'weather';
  static const utility = 'utility';
  static const other = 'other';

  static const all = [
    deviceStatus,
    metrics,
    charts,
    mesh,
    location,
    weather,
    utility,
    other,
  ];

  static String getDisplayName(String category) {
    switch (category) {
      case deviceStatus:
        return 'Device Status';
      case metrics:
        return 'Metrics';
      case charts:
        return 'Charts';
      case mesh:
        return 'Mesh Network';
      case location:
        return 'Location';
      case weather:
        return 'Weather';
      case utility:
        return 'Utility';
      case other:
        return 'Other';
      default:
        return category;
    }
  }
}
