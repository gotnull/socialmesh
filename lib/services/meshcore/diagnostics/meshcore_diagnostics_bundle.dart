// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q6: pure payload builder for the MeshCore diagnostics bundle.
//
// Caller injects every snapshot the builder needs so this file stays
// free of Riverpod, file I/O, and Crashlytics imports. The service
// layer wires the live snapshots in.
//
// Privacy invariants (mirror docs/engineering/MESHCORE_OPEN_PARITY_AUDIT.md
// D-Q6 spec):
//   - NO chat / DM message bodies.
//   - NO full public keys — fingerprints only.
//   - NO admin / channel passwords or PSK bytes.
//   - NO GPS coordinates.
//   - Crashlytics identifier surfaces as a short prefix only.
//
// Schema version 1. Bump on any breaking field rename / removal so
// support tooling that parses the bundle can branch.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

const int kMeshCoreDiagnosticsBundleSchemaVersion = 1;

/// D-Q6: redact a public-key buffer to an 8-byte fingerprint of the
/// shape `XXXXXXXX…XXXXXXXX` where each X is a lowercase hex digit.
/// Mirrors `AppLogging.publicKeyFingerprint` so logs and the bundle
/// surface the same redaction.
String redactPubKeyFingerprint(Uint8List pubKey) {
  if (pubKey.length < 8) {
    return pubKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
  final head = pubKey
      .sublist(0, 4)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  final tail = pubKey
      .sublist(pubKey.length - 4)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return '$head…$tail';
}

/// D-Q6: redact a Crashlytics user identifier to its first 8 hex
/// characters. The Crashlytics console searches on the leading
/// substring so a prefix is enough to cross-reference a ticket.
String? redactCrashlyticsId(String? rawId) {
  if (rawId == null || rawId.isEmpty) return null;
  if (rawId.length <= 8) return rawId;
  return '${rawId.substring(0, 8)}…';
}

/// Pure payload builder. Returns a `Map<String, dynamic>` ready to
/// `jsonEncode(...)` into `bundle.json`.
Map<String, dynamic> buildMeshCoreDiagnosticsPayload({
  required DateTime now,
  required String appVersion,
  required String appBuildNumber,
  required String? selfNodeName,
  required Uint8List? selfPubKey,
  required int? selfBatteryMv,
  required int? selfFreqKhz,
  required int? selfBandwidthHz,
  required int? selfSpreadingFactor,
  required int? selfCodingRate,
  required int? selfTxPowerDbm,
  required String? linkProtocolName,
  required String? linkStateName,
  required int frameCount,
  required int rateLimiterCurrentWindowUsedBytes,
  required int rateLimiterWindowCapacityBytes,
  required int rateLimiterRemainingBytes,
  required int rateLimiterCurrentWindowRejectedBytes,
  required int rateLimiterPeakWindowUsage,
  required String? crashlyticsUserId,
}) {
  return <String, dynamic>{
    'schemaVersion': kMeshCoreDiagnosticsBundleSchemaVersion,
    'generatedAt': now.toIso8601String(),
    'app': <String, dynamic>{
      'version': appVersion,
      'buildNumber': appBuildNumber,
    },
    'platform': <String, dynamic>{
      'os': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
    },
    'selfInfo': <String, dynamic>{
      'name': selfNodeName,
      'pubKeyFingerprint': selfPubKey != null
          ? redactPubKeyFingerprint(selfPubKey)
          : null,
      'batteryMv': selfBatteryMv,
      'freqKhz': selfFreqKhz,
      'bandwidthHz': selfBandwidthHz,
      'spreadingFactor': selfSpreadingFactor,
      'codingRate': selfCodingRate,
      'txPowerDbm': selfTxPowerDbm,
    },
    'link': <String, dynamic>{
      'protocol': linkProtocolName,
      'state': linkStateName,
    },
    'frameLog': <String, dynamic>{
      'frameCount': frameCount,
      'attachment': 'frame-log.txt',
    },
    'rateLimiter': <String, dynamic>{
      'currentWindowUsedBytes': rateLimiterCurrentWindowUsedBytes,
      'windowCapacityBytes': rateLimiterWindowCapacityBytes,
      'remainingBytes': rateLimiterRemainingBytes,
      'currentWindowRejectedBytes': rateLimiterCurrentWindowRejectedBytes,
      'peakWindowUsage': rateLimiterPeakWindowUsage,
    },
    'crashlytics': <String, dynamic>{
      'userIdPrefix': redactCrashlyticsId(crashlyticsUserId),
    },
    'exclusions': <String, dynamic>{
      // D-Q6 explicitly excludes these fields to honor the privacy
      // invariants. Documented in-bundle so the support tooling
      // doesn't ask "why didn't you include X" each time.
      'chatBodies': 'Never included by design.',
      'fullPubKeys': 'Redacted to 8-byte fingerprints.',
      'passwords': 'Never included.',
      'channelPsks': 'Never included.',
      'gpsCoordinates': 'Never included.',
      'pathHistory':
          'Pending list-all helper on MeshCorePathHistoryStore (deferred).',
      'appLogger':
          'Use D44 AppLogScreen export — separate from this MeshCore bundle.',
    },
  };
}
