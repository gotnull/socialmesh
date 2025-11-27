import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';

/// Permission helper for managing app permissions
class PermissionHelper {
  final Logger _logger;

  PermissionHelper({Logger? logger}) : _logger = logger ?? Logger();

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
        _logger.w('Some Bluetooth permissions were not granted: $statuses');
      }

      return allGranted;
    } catch (e) {
      _logger.e('Error requesting Bluetooth permissions: $e');
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
      _logger.e('Error checking Bluetooth permissions: $e');
      return false;
    }
  }

  /// Request camera permissions (for QR scanning)
  Future<bool> requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        _logger.w('Camera permission not granted: $status');
      }
      return status.isGranted;
    } catch (e) {
      _logger.e('Error requesting camera permission: $e');
      return false;
    }
  }

  /// Check if camera permission is granted
  Future<bool> hasCameraPermission() async {
    try {
      final status = await Permission.camera.status;
      return status.isGranted;
    } catch (e) {
      _logger.e('Error checking camera permission: $e');
      return false;
    }
  }

  /// Request storage permissions
  Future<bool> requestStoragePermissions() async {
    try {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        _logger.w('Storage permission not granted: $status');
      }
      return status.isGranted;
    } catch (e) {
      _logger.e('Error requesting storage permission: $e');
      return false;
    }
  }

  /// Open app settings
  Future<void> openAppSettings() async {
    await openAppSettings();
  }
}
