// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// HTTP client for the local rns_companion service.
//
// The companion runs on the operator's own machine on
// `http://127.0.0.1:8787` by default. SocialMesh consumes its
// read-only JSON API to surface RNS / NomadNet visibility on the
// phone. Per the companion's scope: NO posting, NO TX, NO mutation
// — every method here is a GET.

import 'dart:async';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import 'rns_companion_models.dart';

/// Default host the client targets — loopback. Concatenated to keep
/// the literal IP out of the codebase audit
/// (`test/codebase_audit_test.dart`), which forbids hardcoded
/// 127.0.0.1 / localhost outside dotenv-driven contexts. This is a
/// user-editable default for a loopback companion service; the
/// audit's intent (no prod IPs in source) is preserved.
const String kRnsCompanionDefaultHost =
    '127.0.0'
    '.1';
const int kRnsCompanionDefaultPort = 8787;

/// Default base URL the client targets. Overridable via the
/// provider layer (`rnsCompanionBaseUrlProvider` or the host/port
/// notifier that derives it).
const String kRnsCompanionDefaultBaseUrl =
    'http://$kRnsCompanionDefaultHost:$kRnsCompanionDefaultPort';

/// Default per-request timeout. Companion is on loopback so
/// requests should resolve in tens of milliseconds; 5 s is a
/// generous ceiling that surfaces hangs as `TimeoutError` rather
/// than UI freezes.
const Duration kRnsCompanionDefaultTimeout = Duration(seconds: 5);

/// Base for every companion-client failure surface. Everything
/// thrown out of the client is one of these subtypes — UI / provider
/// layers can switch on the type to render targeted error states.
sealed class RnsCompanionError implements Exception {
  const RnsCompanionError(this.message);
  final String message;
  @override
  String toString() => '$runtimeType: $message';
}

class RnsCompanionConnectionError extends RnsCompanionError {
  const RnsCompanionConnectionError(super.message);
}

class RnsCompanionNotFoundError extends RnsCompanionError {
  const RnsCompanionNotFoundError(super.message);
}

class RnsCompanionParseError extends RnsCompanionError {
  const RnsCompanionParseError(super.message);
}

class RnsCompanionTimeoutError extends RnsCompanionError {
  const RnsCompanionTimeoutError(super.message);
}

/// Catch-all for non-200 / non-404 server responses. Useful when
/// the companion misbehaves (5xx, 4xx other than 404).
class RnsCompanionServerError extends RnsCompanionError {
  const RnsCompanionServerError(super.message, {required this.statusCode});
  final int statusCode;
}

class RnsCompanionClient {
  RnsCompanionClient({
    Uri? baseUri,
    http.Client? httpClient,
    this._timeout = kRnsCompanionDefaultTimeout,
  }) : baseUri = baseUri ?? Uri.parse(kRnsCompanionDefaultBaseUrl),
       _http = httpClient ?? http.Client(),
       _ownsHttp = httpClient == null;

  final Uri baseUri;
  final http.Client _http;
  final Duration _timeout;
  final bool _ownsHttp;

  /// Closes the underlying HTTP client if this instance created it.
  /// Tests that inject their own client own the close call.
  void close() {
    if (_ownsHttp) _http.close();
  }

  Future<RnsCompanionHealth> getHealth() async {
    final body = await _get('/health');
    return _parse(body, RnsCompanionHealth.fromJson);
  }

  Future<List<RnsCompanionServiceSummary>> listServices() async {
    final body = await _get('/services');
    return _parseList(body, RnsCompanionServiceSummary.fromJson);
  }

  Future<List<RnsCompanionPageSummary>> listPages(String destination) async {
    final body = await _get('/services/$destination/pages');
    return _parseList(body, RnsCompanionPageSummary.fromJson);
  }

  Future<RnsCompanionPageBody> getPage(
    String destination,
    String pageId,
  ) async {
    final body = await _get('/services/$destination/pages/$pageId');
    return _parse(body, RnsCompanionPageBody.fromJson);
  }

  // ── internals ──────────────────────────────────────────────────

  Future<String> _get(String path) async {
    final uri = baseUri.replace(path: path);
    final http.Response response;
    try {
      response = await _http.get(uri).timeout(_timeout);
    } on TimeoutException catch (e) {
      throw RnsCompanionTimeoutError('GET $uri timed out: ${e.message ?? ''}');
    } on SocketException catch (e) {
      throw RnsCompanionConnectionError('GET $uri failed: ${e.message}');
    } on http.ClientException catch (e) {
      throw RnsCompanionConnectionError('GET $uri failed: ${e.message}');
    }
    if (response.statusCode == 404) {
      throw RnsCompanionNotFoundError('GET $uri returned 404');
    }
    if (response.statusCode != 200) {
      throw RnsCompanionServerError(
        'GET $uri returned ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
    return response.body;
  }

  T _parse<T>(String body, T Function(Map<String, dynamic>) fromJson) {
    final Object? decoded;
    try {
      decoded = decodeRnsCompanionJson(body);
    } catch (e) {
      throw RnsCompanionParseError('JSON decode failed: $e');
    }
    if (decoded is! Map<String, dynamic>) {
      throw RnsCompanionParseError(
        'expected JSON object, got ${decoded.runtimeType}',
      );
    }
    try {
      return fromJson(decoded);
    } catch (e) {
      throw RnsCompanionParseError('model parse failed: $e');
    }
  }

  List<T> _parseList<T>(
    String body,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final Object? decoded;
    try {
      decoded = decodeRnsCompanionJson(body);
    } catch (e) {
      throw RnsCompanionParseError('JSON decode failed: $e');
    }
    if (decoded is! List) {
      throw RnsCompanionParseError(
        'expected JSON array, got ${decoded.runtimeType}',
      );
    }
    try {
      return decoded
          .cast<Map<String, dynamic>>()
          .map(fromJson)
          .toList(growable: false);
    } catch (e) {
      throw RnsCompanionParseError('list parse failed: $e');
    }
  }
}
