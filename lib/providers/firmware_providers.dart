// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../services/firmware/dfu_service.dart';
import '../services/firmware/firmware_api_service.dart';
import '../services/firmware/firmware_models.dart';
import '../services/firmware/hardware_architecture.dart';
import 'app_providers.dart';

/// Provides the firmware API service.
final firmwareApiServiceProvider = Provider<FirmwareApiService>((ref) {
  return FirmwareApiService();
});

/// Provides the DFU service.
final dfuServiceProvider = Provider<DfuService>((ref) {
  return DfuService();
});

/// Fetches the latest firmware release from GitHub.
final firmwareReleaseProvider =
    AsyncNotifierProvider<FirmwareReleaseNotifier, FirmwareRelease?>(
      FirmwareReleaseNotifier.new,
    );

/// Notifier that fetches the latest firmware release.
class FirmwareReleaseNotifier extends AsyncNotifier<FirmwareRelease?> {
  @override
  Future<FirmwareRelease?> build() async {
    final api = ref.read(firmwareApiServiceProvider);
    return api.fetchLatestRelease();
  }

  /// Force-refresh the release info.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }
}

/// Manages DFU state for in-app firmware updates.
final dfuStateProvider = NotifierProvider<DfuStateNotifier, DfuState>(
  DfuStateNotifier.new,
);

/// Notifier managing the DFU state machine.
///
/// State flow: idle → downloading → ready → enteringBootloader → transferring → complete
///                                                                            → failed
class DfuStateNotifier extends Notifier<DfuState> {
  String? _firmwarePath;

  @override
  DfuState build() => const DfuIdle();

  /// Starts the full DFU process: download firmware, enter DFU mode, transfer.
  ///
  /// [release] is the firmware release to install.
  /// [hwModelId] is the raw HardwareModel protobuf enum value.
  /// [deviceAddress] is the BLE address (MAC on Android, UUID on iOS).
  Future<void> startDfu({
    required FirmwareRelease release,
    required int hwModelId,
    required String deviceAddress,
  }) async {
    if (state is! DfuIdle && state is! DfuFailed && state is! DfuComplete) {
      return; // Already in progress
    }

    final architecture = architectureFromHwModel(hwModelId);
    if (!architecture.supportsNordicDfu) {
      state = const DfuFailed(
        error: 'This device does not support in-app firmware updates',
      );
      return;
    }

    final api = ref.read(firmwareApiServiceProvider);
    final dfuService = ref.read(dfuServiceProvider);
    final protocolService = ref.read(protocolServiceProvider);

    // Step 1: Find the architecture asset
    final archAsset = api.findArchitectureAsset(release, architecture);
    if (archAsset == null) {
      state = const DfuFailed(
        error: 'No firmware archive found for this architecture',
      );
      return;
    }

    // Step 2: Download and extract device-specific firmware
    state = const DfuDownloading(progress: 0);

    final firmwarePath = await api.downloadDeviceFirmware(
      archAsset: archAsset,
      hwModelId: hwModelId,
      onProgress: (progress) {
        state = DfuDownloading(progress: progress);
      },
    );

    if (firmwarePath == null) {
      state = const DfuFailed(
        error: 'Could not find firmware file for this device',
      );
      return;
    }

    _firmwarePath = firmwarePath;
    state = DfuReady(filePath: firmwarePath);

    // Step 3: Send enter-DFU-mode command to device
    state = const DfuEnteringBootloader();
    try {
      await protocolService.enterDfuMode();
      AppLogging.firmware('Enter DFU mode command sent');
    } catch (e) {
      AppLogging.firmware('Failed to enter DFU mode: $e');
      state = DfuFailed(error: 'Failed to enter DFU mode: $e');
      await _cleanup(dfuService);
      return;
    }

    // Step 4: Wait for device to reboot into bootloader
    // The device will disconnect and reappear as a DFU target.
    // nordic_dfu handles scanning for the bootloader.
    await Future<void>.delayed(const Duration(seconds: 3));

    // Step 5: Perform DFU transfer
    state = const DfuTransferring(percent: 0);

    await dfuService.performDfu(
      deviceAddress: deviceAddress,
      firmwarePath: firmwarePath,
      onStateChanged: (dfuState) {
        state = dfuState;
      },
    );

    // Cleanup firmware file after DFU
    await _cleanup(dfuService);
  }

  /// Resets to idle state (e.g., after dismissing completion/error).
  void reset() {
    state = const DfuIdle();
  }

  Future<void> _cleanup(DfuService dfuService) async {
    if (_firmwarePath != null) {
      await dfuService.cleanupFirmwareFile(_firmwarePath!);
      _firmwarePath = null;
    }
  }
}
