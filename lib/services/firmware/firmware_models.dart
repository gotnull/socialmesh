// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// A firmware release from the Meshtastic GitHub repository.
class FirmwareRelease {
  final String version;
  final String tagName;
  final DateTime releaseDate;
  final String releaseNotes;
  final String pageUrl;
  final List<FirmwareAsset> assets;

  const FirmwareRelease({
    required this.version,
    required this.tagName,
    required this.releaseDate,
    required this.releaseNotes,
    required this.pageUrl,
    required this.assets,
  });
}

/// A downloadable asset within a firmware release.
class FirmwareAsset {
  final String name;
  final String downloadUrl;
  final int sizeBytes;

  const FirmwareAsset({
    required this.name,
    required this.downloadUrl,
    required this.sizeBytes,
  });
}

/// State of an in-app DFU (Device Firmware Update) operation.
sealed class DfuState {
  const DfuState();
}

/// No DFU operation in progress.
class DfuIdle extends DfuState {
  const DfuIdle();
}

/// Downloading the firmware archive from GitHub.
class DfuDownloading extends DfuState {
  final double progress;
  const DfuDownloading({required this.progress});
}

/// Firmware file extracted and ready for DFU.
class DfuReady extends DfuState {
  final String filePath;
  const DfuReady({required this.filePath});
}

/// Sending the admin command to enter DFU bootloader mode.
class DfuEnteringBootloader extends DfuState {
  const DfuEnteringBootloader();
}

/// Transferring firmware via Nordic DFU.
class DfuTransferring extends DfuState {
  final int percent;
  final double speed;
  final double avgSpeed;
  final int currentPart;
  final int totalParts;

  const DfuTransferring({
    required this.percent,
    this.speed = 0,
    this.avgSpeed = 0,
    this.currentPart = 1,
    this.totalParts = 1,
  });
}

/// DFU completed successfully — device is rebooting with new firmware.
class DfuComplete extends DfuState {
  const DfuComplete();
}

/// DFU failed with an error.
class DfuFailed extends DfuState {
  final String error;
  const DfuFailed({required this.error});
}
