// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q6: bundle service. Composes the pure payload builder + frame
// log + filesystem zip output. The Tools tile wraps this with the
// system share sheet.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/logging.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/meshcore_providers.dart';
import 'meshcore_diagnostics_bundle.dart';

class MeshCoreDiagnosticsBundleService {
  final Ref _ref;
  MeshCoreDiagnosticsBundleService(this._ref);

  // Generates a zip in the system temp directory and returns the
  // path. The caller is responsible for handing the path off to the
  // share sheet (or deleting it).
  //
  // Snapshot reads happen one after the other rather than via
  // `Future.wait` so the bundle reflects a consistent moment in
  // time; a parallel race could attribute the frame count to a
  // different snapshot than the rate-limiter window.
  Future<File> generate() async {
    final now = DateTime.now();

    final packageInfo = await PackageInfo.fromPlatform();

    final selfInfoState = _ref.read(meshCoreSelfInfoProvider);
    final selfInfo = selfInfoState.selfInfo;
    final linkStatus = _ref.read(linkStatusProvider);
    final capture = _ref.read(meshCoreCaptureProvider);
    final rateSnapshot = _ref.read(meshCoreChatTrafficProvider);

    // D-Q6: Crashlytics' SDK has no public read API for the user id
    // it stores. Use the signed-in FirebaseAuth UID as the support
    // cross-reference instead — it's the same identifier our backend
    // surfaces in bug reports and admin tickets. The pure builder
    // still names the slot `crashlyticsUserId` since that's the
    // canonical "support cross-reference" field.
    String? supportUserId;
    try {
      supportUserId = FirebaseAuth.instance.currentUser?.uid;
    } catch (e) {
      AppLogging.meshcore(
        'event=diagnostics.bundle.support_id_skipped reason=$e',
      );
      supportUserId = null;
    }

    final frameLogText = capture?.toCompactHexLog() ?? '';
    final frameCount = capture?.snapshot().length ?? 0;

    final payload = buildMeshCoreDiagnosticsPayload(
      now: now,
      appVersion: packageInfo.version,
      appBuildNumber: packageInfo.buildNumber,
      selfNodeName: selfInfo?.nodeName,
      selfPubKey: selfInfo?.pubKey,
      selfBatteryMv:
          null, // battery surfaces via a separate provider; leave for D-Q6 follow-up
      selfFreqKhz: selfInfo?.freqKhz,
      selfBandwidthHz: selfInfo?.bandwidthHz,
      selfSpreadingFactor: selfInfo?.spreadingFactor,
      selfCodingRate: selfInfo?.codingRate,
      selfTxPowerDbm: selfInfo?.txPowerDbm,
      linkProtocolName: linkStatus.protocol.name,
      linkStateName: linkStatus.status.name,
      frameCount: frameCount,
      rateLimiterCurrentWindowUsedBytes: rateSnapshot.currentWindowUsedBytes,
      rateLimiterWindowCapacityBytes: rateSnapshot.windowCapacityBytes,
      rateLimiterRemainingBytes: rateSnapshot.remainingBytes,
      rateLimiterCurrentWindowRejectedBytes:
          rateSnapshot.currentWindowRejectedBytes,
      rateLimiterPeakWindowUsage: rateSnapshot.peakWindowUsage,
      crashlyticsUserId: supportUserId,
    );

    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'bundle.json',
          const JsonEncoder.withIndent('  ').convert(payload),
        ),
      )
      ..addFile(ArchiveFile.string('frame-log.txt', frameLogText));

    final encoded = ZipEncoder().encode(archive);

    final dir = await getTemporaryDirectory();
    final ts = now.toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File('${dir.path}/socialmesh-meshcore-diag-$ts.zip');
    await file.writeAsBytes(encoded, flush: true);

    AppLogging.meshcore(
      'event=diagnostics.bundle.generated '
      'path_basename=${file.uri.pathSegments.last} '
      'frame_count=$frameCount '
      'bytes=${encoded.length}',
    );
    return file;
  }
}

final meshCoreDiagnosticsBundleServiceProvider =
    Provider<MeshCoreDiagnosticsBundleService>((ref) {
      return MeshCoreDiagnosticsBundleService(ref);
    });
