// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/logging.dart';

/// Permission helper for managing app permissions
class PermissionHelper {
  PermissionHelper();

  /// Request Bluetooth permissions
  Future<bool> requestBluetoothPermissions() async {
    try {
      final statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      final allGranted = statuses.values.every(
        (status) => status.isGranted || status.isLimited,
      );

      if (!allGranted) {
        AppLogging.permissions(
          '⚠️ Some Bluetooth permissions were not granted: $statuses',
        );
      }

      return allGranted;
    } catch (e) {
      AppLogging.permissions('⚠️ Error requesting Bluetooth permissions: $e');
      return false;
    }
  }

  /// Check if Bluetooth permissions are granted
  Future<bool> hasBluetoothPermissions() async {
    try {
      final bluetooth = await Permission.bluetooth.status;
      final bluetoothScan = await Permission.bluetoothScan.status;
      final bluetoothConnect = await Permission.bluetoothConnect.status;
      final location = await Permission.location.status;

      return (bluetooth.isGranted || bluetooth.isLimited) &&
          (bluetoothScan.isGranted || bluetoothScan.isLimited) &&
          (bluetoothConnect.isGranted || bluetoothConnect.isLimited) &&
          (location.isGranted || location.isLimited);
    } catch (e) {
      AppLogging.permissions('⚠️ Error checking Bluetooth permissions: $e');
      return false;
    }
  }

  /// Request camera permissions (for QR scanning)
  Future<bool> requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        AppLogging.permissions('⚠️ Camera permission not granted: $status');
      }
      return status.isGranted;
    } catch (e) {
      AppLogging.permissions('⚠️ Error requesting camera permission: $e');
      return false;
    }
  }

  /// Check if camera permission is granted
  Future<bool> hasCameraPermission() async {
    try {
      final status = await Permission.camera.status;
      return status.isGranted;
    } catch (e) {
      AppLogging.permissions('⚠️ Error checking camera permission: $e');
      return false;
    }
  }

  /// Request storage permissions
  Future<bool> requestStoragePermissions() async {
    try {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        AppLogging.permissions('⚠️ Storage permission not granted: $status');
      }
      return status.isGranted;
    } catch (e) {
      AppLogging.permissions('⚠️ Error requesting storage permission: $e');
      return false;
    }
  }

  /// Open app settings (platform)
  Future<void> goToAppSettings() async {
    await openAppSettings();
  }

  /// Open Bluetooth settings directly.
  /// Returns true if settings were opened successfully.
  /// iOS: Opens app settings (Apple doesn't provide documented API for Bluetooth settings)
  /// Android: Opens Bluetooth settings directly using native Intent
  Future<bool> openBluetoothSettings() async {
    try {
      if (Platform.isAndroid) {
        // Android: Use platform channel to open Bluetooth settings via Intent
        const platform = MethodChannel('com.socialmesh/settings');
        final result = await platform.invokeMethod('openBluetoothSettings');
        return result == true;
      } else if (Platform.isIOS) {
        // iOS doesn't provide a documented way to open Bluetooth settings
        // Open the app's settings page instead (official API)
        return await openAppSettings();
      }
    } catch (e) {
      AppLogging.ble('Failed to open Bluetooth settings: $e');
    }
    return false;
  }
}
