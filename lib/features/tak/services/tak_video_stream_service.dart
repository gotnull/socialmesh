// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/logging.dart';
import '../models/video_stream.dart';

/// HTTP client for the TAK Gateway video stream registry API.
///
/// Wraps `/v1/tak/streams` endpoints with typed request/response models.
/// Uses the same auth token mechanism as [TakGatewayClient].
class TakVideoStreamService {
  static const Duration _timeout = Duration(seconds: 15);

  /// Base gateway URL (e.g., "https://tak.socialmesh.app").
  final String gatewayUrl;

  /// Callback to retrieve a fresh Firebase ID token.
  final Future<String?> Function() getAuthToken;

  final http.Client _client;

  TakVideoStreamService({
    required this.gatewayUrl,
    required this.getAuthToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Build the base URL for stream endpoints.
  String get _baseUrl {
    final url = gatewayUrl
        .replaceFirst(RegExp(r'^wss://'), 'https://')
        .replaceFirst(RegExp(r'^ws://'), 'http://');
    return '$url/v1/tak/streams';
  }

  /// Build authorization headers.
  Future<Map<String, String>> _authHeaders() async {
    final token = await getAuthToken();
    if (token == null) {
      throw TakVideoServiceException('Authentication required');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Register a new video stream.
  ///
  /// POST /v1/tak/streams
  Future<VideoStream> register(VideoStreamCreateRequest request) async {
    AppLogging.tak(
      'TakVideoStreamService: registering stream "${request.name}"',
    );
    try {
      final headers = await _authHeaders();
      final response = await _client
          .post(
            Uri.parse(_baseUrl),
            headers: headers,
            body: jsonEncode(request.toJson()),
          )
          .timeout(_timeout);

      if (response.statusCode == 201) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final stream = VideoStream.fromJson(
          json['stream'] as Map<String, dynamic>,
        );
        AppLogging.tak('TakVideoStreamService: registered stream ${stream.id}');
        return stream;
      }

      final error = _parseError(response);
      AppLogging.tak('TakVideoStreamService: register failed: $error');
      throw TakVideoServiceException(error);
    } on TakVideoServiceException {
      rethrow;
    } on http.ClientException catch (e) {
      throw TakVideoServiceException('Network error: $e');
    } catch (e) {
      if (e is TakVideoServiceException) rethrow;
      throw TakVideoServiceException('Failed to register stream: $e');
    }
  }

  /// List active video streams.
  ///
  /// GET /v1/tak/streams
  Future<List<VideoStream>> listStreams({
    String? status,
    String? tag,
    String? owner,
  }) async {
    AppLogging.tak('TakVideoStreamService: listing streams');
    try {
      final headers = await _authHeaders();
      final queryParams = <String, String>{};
      if (status != null) queryParams['status'] = status;
      if (tag != null) queryParams['tag'] = tag;
      if (owner != null) queryParams['owner'] = owner;

      final uri = Uri.parse(
        _baseUrl,
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final response = await _client
          .get(uri, headers: headers)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final streams = (json['streams'] as List<dynamic>)
            .map((s) => VideoStream.fromJson(s as Map<String, dynamic>))
            .toList();
        AppLogging.tak(
          'TakVideoStreamService: fetched ${streams.length} streams',
        );
        return streams;
      }

      final error = _parseError(response);
      AppLogging.tak('TakVideoStreamService: list failed: $error');
      throw TakVideoServiceException(error);
    } on TakVideoServiceException {
      rethrow;
    } on http.ClientException catch (e) {
      throw TakVideoServiceException('Network error: $e');
    } catch (e) {
      if (e is TakVideoServiceException) rethrow;
      throw TakVideoServiceException('Failed to list streams: $e');
    }
  }

  /// Get a single stream by ID.
  ///
  /// GET /v1/tak/streams/:id
  Future<VideoStream?> getStream(String streamId) async {
    AppLogging.tak('TakVideoStreamService: getting stream $streamId');
    try {
      final headers = await _authHeaders();
      final response = await _client
          .get(Uri.parse('$_baseUrl/$streamId'), headers: headers)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return VideoStream.fromJson(json['stream'] as Map<String, dynamic>);
      }
      if (response.statusCode == 404) return null;

      final error = _parseError(response);
      throw TakVideoServiceException(error);
    } on TakVideoServiceException {
      rethrow;
    } on http.ClientException catch (e) {
      throw TakVideoServiceException('Network error: $e');
    } catch (e) {
      if (e is TakVideoServiceException) rethrow;
      throw TakVideoServiceException('Failed to get stream: $e');
    }
  }

  /// Send heartbeat for a stream.
  ///
  /// PUT /v1/tak/streams/:id/heartbeat
  Future<VideoStream> heartbeat(
    String streamId, {
    VideoStreamHeartbeatRequest? update,
  }) async {
    try {
      final headers = await _authHeaders();
      final response = await _client
          .put(
            Uri.parse('$_baseUrl/$streamId/heartbeat'),
            headers: headers,
            body: update != null ? jsonEncode(update.toJson()) : '{}',
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return VideoStream.fromJson(json['stream'] as Map<String, dynamic>);
      }

      final error = _parseError(response);
      AppLogging.tak(
        'TakVideoStreamService: heartbeat failed for $streamId: $error',
      );
      throw TakVideoServiceException(error);
    } on TakVideoServiceException {
      rethrow;
    } on http.ClientException catch (e) {
      throw TakVideoServiceException('Network error: $e');
    } catch (e) {
      if (e is TakVideoServiceException) rethrow;
      throw TakVideoServiceException('Failed to heartbeat: $e');
    }
  }

  /// Delete/end a stream.
  ///
  /// DELETE /v1/tak/streams/:id
  Future<bool> deleteStream(String streamId) async {
    AppLogging.tak('TakVideoStreamService: deleting stream $streamId');
    try {
      final headers = await _authHeaders();
      final response = await _client
          .delete(Uri.parse('$_baseUrl/$streamId'), headers: headers)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        AppLogging.tak('TakVideoStreamService: deleted stream $streamId');
        return true;
      }
      if (response.statusCode == 404) return false;

      final error = _parseError(response);
      AppLogging.tak(
        'TakVideoStreamService: delete failed for $streamId: $error',
      );
      throw TakVideoServiceException(error);
    } on TakVideoServiceException {
      rethrow;
    } on http.ClientException catch (e) {
      throw TakVideoServiceException('Network error: $e');
    } catch (e) {
      if (e is TakVideoServiceException) rethrow;
      throw TakVideoServiceException('Failed to delete stream: $e');
    }
  }

  /// Parse error message from response body.
  String _parseError(http.Response response) {
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json['error'] as String? ?? 'HTTP ${response.statusCode}';
    } catch (_) {
      return 'HTTP ${response.statusCode}';
    }
  }

  /// Release resources.
  void dispose() {
    _client.close();
  }
}

/// Exception for video stream service errors.
class TakVideoServiceException implements Exception {
  final String message;
  const TakVideoServiceException(this.message);

  @override
  String toString() => 'TakVideoServiceException: $message';
}
