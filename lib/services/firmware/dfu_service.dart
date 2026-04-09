// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:io';

import 'package:nordic_dfu/nordic_dfu.dart';

import '../../core/logging.dart';
import 'firmware_models.dart';

/// Wraps the Nordic DFU library for performing BLE firmware updates
/// on nRF52840-based Meshtastic devices.
class DfuService {
  final NordicDfu _nordicDfu = NordicDfu();

  /// Performs a Nordic DFU firmware transfer.
  ///
  /// [deviceAddress] is the BLE address/UUID of the device to update.
  /// On Android this is the MAC address; on iOS this is the peripheral UUID.
  ///
  /// [firmwarePath] is the local path to the Nordic DFU `.zip` package.
  ///
  /// [onStateChanged] reports state transitions during the DFU process.
  Future<void> performDfu({
    required String deviceAddress,
    required String firmwarePath,
    required void Function(DfuState state) onStateChanged,
  }) async {
    AppLogging.firmware(
      'Starting Nordic DFU: device=$deviceAddress, firmware=$firmwarePath',
    );

    try {
      await _nordicDfu.startDfu(
        deviceAddress,
        firmwarePath,
        fileInAsset: false,
        forceDfu: false,
        numberOfPackets: 10,
        darwinParameters: const DarwinParameters(
          alternativeAdvertisingNameEnabled: true,
        ),
        dfuEventHandler: DfuEventHandler(
          onProgressChanged:
              (address, percent, speed, avgSpeed, currentPart, partsTotal) {
                AppLogging.firmware('DFU progress: $percent%');
                onStateChanged(
                  DfuTransferring(
                    percent: percent,
                    speed: speed,
                    avgSpeed: avgSpeed,
                    currentPart: currentPart,
                    totalParts: partsTotal,
                  ),
                );
              },
          onDfuCompleted: (address) {
            AppLogging.firmware('DFU completed for $address');
            onStateChanged(const DfuComplete());
          },
          onDfuAborted: (address) {
            AppLogging.firmware('DFU aborted for $address');
            onStateChanged(const DfuFailed(error: 'DFU was aborted'));
          },
          onError: (address, error, errorType, message) {
            AppLogging.firmware(
              'DFU error: type=$errorType, error=$error, message=$message',
            );
            onStateChanged(DfuFailed(error: message));
          },
          onDeviceConnecting: (address) {
            AppLogging.firmware('DFU: Connecting to $address');
          },
          onDeviceConnected: (address) {
            AppLogging.firmware('DFU: Connected to $address');
          },
          onEnablingDfuMode: (address) {
            AppLogging.firmware('DFU: Enabling DFU mode on $address');
          },
          onDfuProcessStarting: (address) {
            AppLogging.firmware('DFU: Process starting for $address');
            onStateChanged(const DfuTransferring(percent: 0));
          },
          onDfuProcessStarted: (address) {
            AppLogging.firmware('DFU: Process started for $address');
          },
          onFirmwareValidating: (address) {
            AppLogging.firmware('DFU: Validating firmware on $address');
          },
        ),
      );
    } catch (e) {
      AppLogging.firmware('DFU exception: $e');
      onStateChanged(DfuFailed(error: e.toString()));
    }
  }

  /// Cleans up a downloaded firmware file.
  Future<void> cleanupFirmwareFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        AppLogging.firmware('Cleaned up firmware file: $path');
      }
    } catch (e) {
      AppLogging.firmware('Error cleaning up firmware file: $e');
    }
  }
}
