// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/logging.dart';
import 'firmware_models.dart';
import 'hardware_architecture.dart';

/// Service for fetching Meshtastic firmware releases and downloading
/// device-specific firmware files.
class FirmwareApiService {
  static const _githubReleasesUrl =
      'https://api.github.com/repos/meshtastic/firmware/releases/latest';

  /// Fetches the latest Meshtastic firmware release info from GitHub.
  Future<FirmwareRelease?> fetchLatestRelease() async {
    try {
      final response = await http
          .get(
            Uri.parse(_githubReleasesUrl),
            headers: {'Accept': 'application/vnd.github.v3+json'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        AppLogging.firmware(
          'GitHub releases API returned ${response.statusCode}',
        );
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;

      final tagName = data['tag_name'] as String? ?? '';
      final version =
          tagName.startsWith('v') ? tagName.substring(1) : tagName;

      final publishedAt = data['published_at'] as String?;
      final releaseDate =
          publishedAt != null ? DateTime.parse(publishedAt) : DateTime.now();

      // lint-allow: hardcoded-string
      final body = data['body'] as String? ?? '';
      final htmlUrl = data['html_url'] as String? ?? '';

      final rawAssets = data['assets'] as List<dynamic>? ?? [];
      final assets = rawAssets.map((a) {
        final asset = a as Map<String, dynamic>;
        return FirmwareAsset(
          name: asset['name'] as String? ?? '',
          downloadUrl: asset['browser_download_url'] as String? ?? '',
          sizeBytes: asset['size'] as int? ?? 0,
        );
      }).toList();

      return FirmwareRelease(
        version: version,
        tagName: tagName,
        releaseDate: releaseDate,
        releaseNotes: body,
        pageUrl: htmlUrl,
        assets: assets,
      );
    } catch (e) {
      AppLogging.firmware('Error fetching firmware release: $e');
      return null;
    }
  }

  /// Finds the firmware architecture zip asset for the given [architecture].
  ///
  /// Returns `null` if no matching asset is found in the release.
  FirmwareAsset? findArchitectureAsset(
    FirmwareRelease release,
    DeviceArchitecture architecture,
  ) {
    final prefix = architecture.firmwareAssetPrefix;
    if (prefix.isEmpty) return null;

    try {
      return release.assets.firstWhere(
        (a) => a.name.startsWith(prefix) && a.name.endsWith('.zip'),
      );
    } catch (_) {
      return null;
    }
  }

  /// Downloads the architecture zip and extracts the device-specific
  /// Nordic DFU package for the given [hwModelId].
  ///
  /// Returns the local file path to the extracted DFU `.zip` file,
  /// or `null` if the firmware file could not be found.
  ///
  /// [onProgress] reports download progress (0.0 to 1.0).
  Future<String?> downloadDeviceFirmware({
    required FirmwareAsset archAsset,
    required int hwModelId,
    required void Function(double progress) onProgress,
  }) async {
    final firmwareTarget = firmwareTargetFromHwModel(hwModelId);
    if (firmwareTarget == null) {
      AppLogging.firmware(
        'No firmware target mapping for hwModel=$hwModelId',
      );
      return null;
    }

    final tempDir = await getTemporaryDirectory();
    final archZipPath =
        '${tempDir.path}/firmware_arch_${DateTime.now().millisecondsSinceEpoch}.zip';

    try {
      // Download the architecture zip with progress tracking
      AppLogging.firmware(
        'Downloading ${archAsset.name} (${archAsset.sizeBytes} bytes)',
      );

      final request = http.Request('GET', Uri.parse(archAsset.downloadUrl));
      final streamedResponse =
          await request.send().timeout(const Duration(minutes: 5));

      if (streamedResponse.statusCode != 200) {
        AppLogging.firmware(
          'Download failed: HTTP ${streamedResponse.statusCode}',
        );
        return null;
      }

      final totalBytes = streamedResponse.contentLength ?? archAsset.sizeBytes;
      var receivedBytes = 0;
      final sink = File(archZipPath).openWrite();

      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress(receivedBytes / totalBytes);
        }
      }
      await sink.close();

      AppLogging.firmware(
        'Downloaded $receivedBytes bytes to $archZipPath',
      );

      // Extract the device-specific DFU zip from the architecture zip
      final archBytes = await File(archZipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(archBytes);

      // Look for the DFU zip matching this device target
      // Pattern: firmware-{target}-{version}.zip
      ArchiveFile? dfuFile;
      for (final file in archive.files) {
        if (file.name.contains('firmware-$firmwareTarget-') &&
            file.name.endsWith('.zip') &&
            !file.isFile == false) {
          if (file.isFile) {
            dfuFile = file;
            break;
          }
        }
      }

      if (dfuFile == null) {
        // Try a looser match — sometimes the target name differs slightly
        for (final file in archive.files) {
          if (file.isFile &&
              file.name.contains(firmwareTarget) &&
              file.name.endsWith('.zip')) {
            dfuFile = file;
            break;
          }
        }
      }

      if (dfuFile == null) {
        AppLogging.firmware(
          'DFU package for target "$firmwareTarget" not found in archive. '
          'Available: ${archive.files.where((f) => f.name.endsWith(".zip")).map((f) => f.name).toList()}',
        );
        return null;
      }

      // Write the DFU zip to a temp file
      final dfuZipPath =
          '${tempDir.path}/firmware_dfu_${DateTime.now().millisecondsSinceEpoch}.zip';
      final dfuBytes = dfuFile.content as List<int>;
      await File(dfuZipPath).writeAsBytes(dfuBytes);

      AppLogging.firmware(
        'Extracted DFU package: ${dfuFile.name} (${dfuBytes.length} bytes) → $dfuZipPath',
      );

      return dfuZipPath;
    } catch (e) {
      AppLogging.firmware('Error downloading/extracting firmware: $e');
      return null;
    } finally {
      // Clean up the architecture zip
      try {
        final archFile = File(archZipPath);
        if (await archFile.exists()) {
          await archFile.delete();
        }
      } catch (_) {}
    }
  }
}
