// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Shared HTTP catch+log shape. Crashlytics issue [B aedf754f] was an
// IOClient.send funnel with no app frames - a SocketException / DNS
// failure / timeout escaping out of a Future at a callsite that did not
// wrap its http call. This helper makes the catch shape and log line
// uniform across all callsites so we never have to chase the same bug
// in five places.
//
// Policy: safety wrapper only. Failures here are reported via
// AppLogging.app(...) and surfaced to the caller as a typed HttpResult;
// they MUST NOT call FirebaseCrashlytics.recordError. Re-routing
// already-recovered failures back into Crashlytics rebuilds the noise
// this helper was designed to remove.

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../logging.dart';

sealed class HttpResult<T> {
  const HttpResult();
}

class HttpSuccess<T> extends HttpResult<T> {
  final T value;
  const HttpSuccess(this.value);
}

class HttpFailure<T> extends HttpResult<T> {
  final HttpFailureReason reason;
  final Object error;
  const HttpFailure(this.reason, this.error);
}

enum HttpFailureReason {
  // Socket-level failure: connection reset, DNS, ECONNREFUSED, EPIPE.
  socket,

  // package:http's transport-layer error wrapper.
  client,

  // Request did not complete within the caller's timeout.
  timeout,
}

Future<HttpResult<T>> safeHttpRequest<T>({
  required String surface,
  required Future<http.Response> Function() send,
  required T Function(http.Response response) decode,
}) async {
  final http.Response response;
  try {
    response = await send();
  } on SocketException catch (e) {
    AppLogging.app('[B aedf754f surface=$surface] SocketException: $e');
    return HttpFailure(HttpFailureReason.socket, e);
  } on http.ClientException catch (e) {
    AppLogging.app('[B aedf754f surface=$surface] ClientException: $e');
    return HttpFailure(HttpFailureReason.client, e);
  } on TimeoutException catch (e) {
    AppLogging.app('[B aedf754f surface=$surface] TimeoutException: $e');
    return HttpFailure(HttpFailureReason.timeout, e);
  }
  return HttpSuccess(decode(response));
}
