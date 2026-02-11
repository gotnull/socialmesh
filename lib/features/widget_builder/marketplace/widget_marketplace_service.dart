// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants.dart';
import '../../../core/logging.dart';
import '../models/widget_schema.dart';

/// Service for interacting with the widget marketplace
class WidgetMarketplaceService {
  // Base URL for the marketplace API - configured via .env
  final String baseUrl;
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

    // Default to Firebase Cloud Functions from AppUrls
    return AppUrls.cloudFunctionsUrl;
  }

  WidgetMarketplaceService({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? _defaultBaseUrl,
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
        AppLogging.marketplace('⚠️ Socket error (attempt $attempt): $e');
      } on HttpException catch (e) {
        lastException = e;
        AppLogging.marketplace('⚠️ HTTP error (attempt $attempt): $e');
      } on http.ClientException catch (e) {
        lastException = e;
        AppLogging.marketplace('⚠️ Client error (attempt $attempt): $e');
      } on TimeoutException catch (e) {
        lastException = e;
        AppLogging.marketplace('⚠️ Timeout (attempt $attempt): $e');
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
        AppLogging.marketplace(
          '⚠️ Marketplace browse failed: ${response.statusCode}',
        );
        throw MarketplaceException(
          'Failed to load widgets: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is MarketplaceException) rethrow;
      AppLogging.marketplace('⚠️ Marketplace browse error: $e');
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
      AppLogging.marketplace('⚠️ Featured widgets error: $e');
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
      AppLogging.marketplace('⚠️ Get widget error: $e');
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
      AppLogging.marketplace('⚠️ Download widget error: $e');
      throw MarketplaceException('Failed to download widget: $e');
    }
  }

  /// Preview widget schema (does NOT increment install count)
  Future<WidgetSchema> previewWidget(String id) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/widgetsPreview',
      ).replace(queryParameters: {'id': id});
      final response = await _getWithRetry(uri);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return WidgetSchema.fromJson(json);
      } else {
        throw MarketplaceException('Failed to preview widget');
      }
    } catch (e) {
      if (e is MarketplaceException) rethrow;
      AppLogging.marketplace('⚠️ Preview widget error: $e');
      throw MarketplaceException('Failed to preview widget: $e');
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
      AppLogging.marketplace('⚠️ Upload widget error: $e');
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
      AppLogging.marketplace('⚠️ Rate widget error: $e');
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
      AppLogging.marketplace('⚠️ Report widget error: $e');
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

  /// Get pending widgets for review (admin only)
  Future<List<MarketplaceWidget>> getPendingWidgets(String authToken) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/widgetsAdminPending'),
            headers: {'Authorization': 'Bearer $authToken'},
          )
          .timeout(const Duration(seconds: 10));

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
      AppLogging.marketplace('⚠️ Get pending widgets error: $e');
      rethrow;
    }
  }

  /// Approve a widget (admin only)
  Future<void> approveWidget(String id, String authToken) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/widgetsApprove?id=$id'),
            headers: {'Authorization': 'Bearer $authToken'},
          )
          .timeout(const Duration(seconds: 10));

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
      AppLogging.marketplace('⚠️ Approve widget error: $e');
      rethrow;
    }
  }

  /// Reject a widget (admin only)
  Future<void> rejectWidget(String id, String reason, String authToken) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/widgetsReject?id=$id'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({'reason': reason}),
          )
          .timeout(const Duration(seconds: 10));

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
      AppLogging.marketplace('⚠️ Reject widget error: $e');
      rethrow;
    }
  }

  /// Get user's own widgets (My Submissions)
  Future<List<MarketplaceWidget>> getMyWidgets(String authToken) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/widgetsUserMine'),
            headers: {'Authorization': 'Bearer $authToken'},
          )
          .timeout(const Duration(seconds: 10));

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
      AppLogging.marketplace('⚠️ Get my widgets error: $e');
      rethrow;
    }
  }

  /// Submit widget for approval (promotes to marketplace)
  Future<MarketplaceWidget> submitWidget(
    WidgetSchema widget,
    String authToken,
  ) async {
    AppLogging.marketplace('───────────────────────────────────────────────');
    AppLogging.marketplace('🔄 submitWidget() - START');
    AppLogging.marketplace('───────────────────────────────────────────────');
    AppLogging.marketplace('Widget name: ${widget.name}');
    AppLogging.marketplace('Widget ID: ${widget.id}');
    AppLogging.marketplace('Auth token length: ${authToken.length}');
    AppLogging.marketplace('URL: $baseUrl/widgetsSubmit');

    try {
      final requestBody = jsonEncode(widget.toJson());
      AppLogging.marketplace(
        'Request body length: ${requestBody.length} chars',
      );
      AppLogging.marketplace(
        'Request body preview: ${requestBody.substring(0, requestBody.length > 200 ? 200 : requestBody.length)}...',
      );

      AppLogging.marketplace('📡 Sending POST request...');
      final response = await _client
          .post(
            Uri.parse('$baseUrl/widgetsSubmit'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: requestBody,
          )
          .timeout(const Duration(seconds: 10));

      AppLogging.marketplace('📬 Response received:');
      AppLogging.marketplace('   Status code: ${response.statusCode}');
      AppLogging.marketplace(
        '   Response body length: ${response.body.length}',
      );
      AppLogging.marketplace(
        '   Response body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}',
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        AppLogging.marketplace('✅ Submit successful (${response.statusCode})');
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final result = MarketplaceWidget.fromJson(json);
        AppLogging.marketplace('   Result widget ID: ${result.id}');
        AppLogging.marketplace('   Result status: ${result.status}');
        AppLogging.marketplace(
          '───────────────────────────────────────────────',
        );
        AppLogging.marketplace('🔄 submitWidget() - SUCCESS');
        AppLogging.marketplace(
          '───────────────────────────────────────────────',
        );
        return result;
      } else if (response.statusCode == 401) {
        AppLogging.marketplace('❌ 401 Unauthorized - Authentication required');
        throw MarketplaceException('Authentication required');
      } else if (response.statusCode == 409) {
        // Duplicate detected
        AppLogging.marketplace('⚠️ 409 Conflict - Duplicate detected');
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final duplicateName = json['duplicateName'] as String?;
        AppLogging.marketplace('   Duplicate name: $duplicateName');
        throw MarketplaceDuplicateException(
          'A similar widget already exists${duplicateName != null ? ': $duplicateName' : ''}',
          duplicateName: duplicateName,
        );
      } else {
        final body = response.body;
        AppLogging.marketplace(
          '❌ Unexpected status code: ${response.statusCode}',
        );
        AppLogging.marketplace('   Response body: $body');
        throw MarketplaceException('Failed to submit widget');
      }
    } catch (e, stackTrace) {
      if (e is MarketplaceException) {
        AppLogging.marketplace('⚠️ MarketplaceException in submitWidget: $e');
        rethrow;
      }
      AppLogging.marketplace('❌ Unexpected error in submitWidget: $e');
      AppLogging.marketplace('   Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Check for duplicate widget before submission
  Future<DuplicateCheckResult> checkDuplicate(
    WidgetSchema widget,
    String authToken,
  ) async {
    AppLogging.marketplace('───────────────────────────────────────────────');
    AppLogging.marketplace('🔄 checkDuplicate() - START');
    AppLogging.marketplace('───────────────────────────────────────────────');
    AppLogging.marketplace('Widget name: ${widget.name}');
    AppLogging.marketplace('URL: $baseUrl/widgetsCheckDuplicate');

    try {
      final requestBody = jsonEncode({
        'name': widget.name,
        'schema': widget.toJson(),
      });
      AppLogging.marketplace(
        'Request body length: ${requestBody.length} chars',
      );

      AppLogging.marketplace('📡 Sending POST request...');
      final response = await _client
          .post(
            Uri.parse('$baseUrl/widgetsCheckDuplicate'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: requestBody,
          )
          .timeout(const Duration(seconds: 5));

      AppLogging.marketplace('📬 Response received:');
      AppLogging.marketplace('   Status code: ${response.statusCode}');
      AppLogging.marketplace('   Response body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final result = DuplicateCheckResult.fromJson(json);
        AppLogging.marketplace('✅ Duplicate check result:');
        AppLogging.marketplace('   isDuplicate: ${result.isDuplicate}');
        AppLogging.marketplace('   duplicateName: ${result.duplicateName}');
        AppLogging.marketplace('   similarityScore: ${result.similarityScore}');
        AppLogging.marketplace(
          '───────────────────────────────────────────────',
        );
        AppLogging.marketplace('🔄 checkDuplicate() - SUCCESS');
        AppLogging.marketplace(
          '───────────────────────────────────────────────',
        );
        return result;
      } else {
        AppLogging.marketplace(
          '❌ Duplicate check failed with status: ${response.statusCode}',
        );
        throw MarketplaceException('Failed to check for duplicates');
      }
    } catch (e, stackTrace) {
      if (e is MarketplaceException) {
        AppLogging.marketplace('⚠️ MarketplaceException in checkDuplicate: $e');
        rethrow;
      }
      AppLogging.marketplace('⚠️ Check duplicate error: $e');
      AppLogging.marketplace('   Stack trace: $stackTrace');
      AppLogging.marketplace(
        '   Returning isDuplicate=false to allow submission',
      );
      // Return no duplicate on error to allow submission
      return DuplicateCheckResult(isDuplicate: false);
    }
  }

  /// Get pending widgets for admin review
  Future<List<MarketplaceWidget>> getPendingForAdmin(String authToken) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/widgetsAdminPending'),
            headers: {'Authorization': 'Bearer $authToken'},
          )
          .timeout(const Duration(seconds: 10));

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
      AppLogging.marketplace('⚠️ Get pending for admin error: $e');
      rethrow;
    }
  }
}

/// Result of duplicate check
class DuplicateCheckResult {
  final bool isDuplicate;
  final String? duplicateId;
  final String? duplicateName;
  final double? similarityScore;

  DuplicateCheckResult({
    required this.isDuplicate,
    this.duplicateId,
    this.duplicateName,
    this.similarityScore,
  });

  factory DuplicateCheckResult.fromJson(Map<String, dynamic> json) {
    return DuplicateCheckResult(
      isDuplicate: json['isDuplicate'] as bool? ?? false,
      duplicateId: json['duplicateId'] as String?,
      duplicateName: json['duplicateName'] as String?,
      similarityScore: (json['similarityScore'] as num?)?.toDouble(),
    );
  }
}

/// Exception for duplicate widget detection
class MarketplaceDuplicateException extends MarketplaceException {
  final String? duplicateName;

  MarketplaceDuplicateException(super.message, {this.duplicateName});
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
  final String? thumbnailUrl;
  final int installs;
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
    this.thumbnailUrl,
    required this.installs,
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
      thumbnailUrl: json['thumbnailUrl'] as String?,
      // Support both 'installs' and legacy 'downloads' field
      installs: json['installs'] as int? ?? json['downloads'] as int? ?? 0,
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'author': author,
      'authorId': authorId,
      'thumbnailUrl': thumbnailUrl,
      'installs': installs,
      'rating': rating,
      'ratingCount': ratingCount,
      'tags': tags,
      'category': category,
      'status': status,
      'isFeatured': isFeatured,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
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
