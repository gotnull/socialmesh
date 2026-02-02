// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../../core/logging.dart';
import '../../providers/connection_providers.dart' as conn;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/transport.dart';
import '../../core/theme.dart';
import '../../core/widgets/connecting_content.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../models/mesh_device.dart';
import '../../services/meshcore/meshcore_detector.dart';
import '../../providers/meshcore_providers.dart';
import '../../utils/permissions.dart';
import '../../utils/snackbar.dart';
import '../../providers/app_providers.dart';
import '../../services/storage/storage_service.dart';
import '../../generated/meshtastic/config.pbenum.dart' as config_pbenum;
import 'widgets/connecting_animation.dart';
import '../../core/widgets/loading_indicator.dart';
import '../device/region_selection_screen.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  final bool isOnboarding;
  final bool isInline;

  const ScannerScreen({
    super.key,
    this.isOnboarding = false,
    this.isInline = false,
  });

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final List<DeviceInfo> _devices = [];
  bool _scanning = false;
  bool _connecting = false;
  bool _autoReconnecting = false;
  String? _errorMessage;
  String? _savedDeviceNotFoundName;
  bool _showPairingInvalidationHint = false;
  String? _savedDeviceId;
  String? _savedDeviceName;
  TransportType? _savedDeviceTransportType;

  @override
  void initState() {
    super.initState();
    AppLogging.connection(
      '📡 SCANNER: initState - isOnboarding=${widget.isOnboarding}, isInline=${widget.isInline}, hashCode=$hashCode',
    );

    // Check if we're being shown because auto-reconnect failed
    // In that case, we should immediately show the "device not found" banner
    final autoReconnectState = ref.read(autoReconnectStateProvider);
    final deviceState = ref.read(conn.deviceConnectionProvider);

    // Check if pairing was invalidated (factory reset, device replaced, etc.)
    // Show the pairing hint immediately so user knows to forget in Bluetooth settings
    if (deviceState.isTerminalInvalidated) {
      AppLogging.connection('📡 SCANNER: Shown after pairing invalidation');
      _showPairingInvalidationHint = true;
    } else if (autoReconnectState == AutoReconnectState.failed &&
        deviceState.reason == conn.DisconnectReason.deviceNotFound) {
      AppLogging.connection(
        '📡 SCANNER: Shown after auto-reconnect failed with deviceNotFound',
      );
      // Get saved device name to show in banner
      ref.read(settingsServiceProvider.future).then((settings) {
        if (mounted) {
          setState(() {
            _savedDeviceNotFoundName =
                settings.lastDeviceName ?? 'Your saved device';
          });
        }
      });
    }

    // Skip auto-reconnect during onboarding or inline - user needs to select device
    if (widget.isOnboarding || widget.isInline) {
      AppLogging.connection(
        '📡 SCANNER: Onboarding/inline mode - starting manual scan',
      );
      _startScan();
    } else {
      AppLogging.connection('📡 SCANNER: Normal mode - trying auto-reconnect');
      _tryAutoReconnect();
    }
  }

  @override
  void dispose() {
    AppLogging.connection('📡 SCANNER: dispose - hashCode=$hashCode');
    super.dispose();
  }

  Future<void> _tryAutoReconnect() async {
    // Check if auto-reconnect already failed (e.g., user cancelled PIN during app init)
    // In that case, don't retry - just show the scanner
    final autoReconnectState = ref.read(autoReconnectStateProvider);
    final deviceState = ref.read(conn.deviceConnectionProvider);

    AppLogging.connection(
      '📡 SCANNER: _tryAutoReconnect - autoReconnectState=$autoReconnectState, '
      'deviceState=${deviceState.state}, reason=${deviceState.reason}',
    );

    if (autoReconnectState == AutoReconnectState.failed) {
      AppLogging.connection(
        '📡 SCANNER: Auto-reconnect already failed, skipping to scan',
      );
      _startScan();
      return;
    }

    // CRITICAL: Check the global userDisconnected flag
    final userDisconnected = ref.read(userDisconnectedProvider);
    if (userDisconnected) {
      AppLogging.connection(
        '📡 SCANNER: User manually disconnected (global flag), skipping auto-reconnect',
      );
      _startScan();
      return;
    }

    // If user manually disconnected, don't auto-reconnect - just show scanner
    if (deviceState.reason == conn.DisconnectReason.userDisconnected) {
      AppLogging.connection(
        '📡 SCANNER: User manually disconnected, skipping auto-reconnect',
      );
      _startScan();
      return;
    }

    // Wait for settings service to initialize
    final SettingsService settingsService;
    try {
      settingsService = await ref.read(settingsServiceProvider.future);
    } catch (e) {
      AppLogging.connection('📡 SCANNER: Failed to load settings service: $e');
      _startScan();
      return;
    }

    // Check if auto-reconnect is enabled
    if (!settingsService.autoReconnect) {
      AppLogging.connection('📡 SCANNER: Auto-reconnect disabled in settings');
      _startScan();
      return;
    }

    final lastDeviceId = settingsService.lastDeviceId;
    final lastDeviceType = settingsService.lastDeviceType;
    final lastDeviceName = settingsService.lastDeviceName;

    _updateSavedDeviceMeta(
      savedDeviceId: lastDeviceId,
      savedDeviceName: lastDeviceName,
      savedDeviceType: _transportTypeFromString(lastDeviceType),
    );

    if (lastDeviceId == null || lastDeviceType == null) {
      AppLogging.connection('📡 SCANNER: No saved device, starting scan');
      _startScan();
      return;
    }

    if (!mounted) return;

    setState(() {
      _autoReconnecting = true;
    });

    AppLogging.connection(
      '📡 SCANNER: Auto-reconnect looking for device $lastDeviceId ($lastDeviceType)',
    );

    try {
      // NOTE: Don't clear userDisconnected flag here - only clear it when user
      // explicitly taps on a device to connect in _connect()

      // Start scanning to find the last device
      final transport = ref.read(transportProvider);
      final scanStream = transport.scan(timeout: const Duration(seconds: 5));
      DeviceInfo? lastDevice;

      await for (final device in scanStream) {
        if (!mounted) break;
        AppLogging.connection(
          '📡 SCANNER: Auto-reconnect found ${device.id} (looking for $lastDeviceId)',
        );
        if (device.id == lastDeviceId) {
          // Use stored name if scan didn't provide one
          if (device.name.isEmpty || device.name == 'Unknown') {
            lastDevice = DeviceInfo(
              id: device.id,
              name: lastDeviceName ?? device.name,
              type: device.type,
              rssi: device.rssi,
            );
          } else {
            lastDevice = device;
          }
          break;
        }
      }

      if (!mounted) return;

      if (lastDevice != null) {
        AppLogging.connection(
          '📡 SCANNER: Auto-reconnect device found, connecting...',
        );
        // Found the device, try to connect
        await _connectToDevice(lastDevice, isAutoReconnect: true);
      } else {
        AppLogging.connection(
          '📡 SCANNER: Auto-reconnect device not found, starting regular scan',
        );
        // Device not found, start regular scan and show info message
        setState(() {
          _autoReconnecting = false;
          _savedDeviceNotFoundName = lastDeviceName ?? 'your saved device';
        });
        _startScan();
      }
    } catch (e) {
      AppLogging.connection('📡 SCANNER: Auto-reconnect failed: $e');
      if (mounted) {
        setState(() {
          _autoReconnecting = false;
        });
        _startScan();
      }
    }
  }

  Future<void> _startScan() async {
    if (_scanning) {
      AppLogging.connection(
        '📡 SCANNER: _startScan called but already scanning',
      );
      return;
    }

    // Check if user just manually disconnected - need extra time for device
    // to start advertising again after we released the BLE connection
    final userJustDisconnected = ref.read(userDisconnectedProvider);
    AppLogging.connection(
      '📡 SCANNER: Starting 10s scan... (userJustDisconnected=$userJustDisconnected)',
    );

    // Get saved device info before scan to check if it was found afterward
    try {
      final settingsService = await ref.read(settingsServiceProvider.future);
      _updateSavedDeviceMeta(
        savedDeviceId: settingsService.lastDeviceId,
        savedDeviceName: settingsService.lastDeviceName,
        savedDeviceType: _transportTypeFromString(
          settingsService.lastDeviceType,
        ),
      );
    } catch (e) {
      AppLogging.connection('📡 SCANNER: Failed to load saved device info: $e');
    }

    setState(() {
      _scanning = true;
      _devices.clear();
      _errorMessage = null;
      _showPairingInvalidationHint = false;
    });

    try {
      // Aggressive BLE cleanup to handle devices that were just disconnected
      // from another app (like Meshtastic). iOS/Android cache BLE state and
      // may not immediately see newly-available devices.
      AppLogging.connection('📡 SCANNER: Aggressive BLE cleanup starting...');

      // 1. Wait for any active scans to fully complete BEFORE stopping
      // This is critical because background connection scans may still be running
      // and their finally blocks call stopScan() which would kill our scan
      if (userJustDisconnected) {
        try {
          // First check if there's an active scan
          final isCurrentlyScanning = await FlutterBluePlus.isScanning.first;
          if (isCurrentlyScanning) {
            AppLogging.connection(
              '📡 SCANNER: Active scan detected, waiting for it to complete...',
            );
            // Wait for the active scan to finish (up to 6 seconds for a 5s scan)
            await FlutterBluePlus.isScanning
                .firstWhere((scanning) => !scanning)
                .timeout(
                  const Duration(seconds: 6),
                  onTimeout: () {
                    AppLogging.connection(
                      '📡 SCANNER: Timeout waiting for scan, forcing stop',
                    );
                    return false;
                  },
                );
            AppLogging.connection(
              '📡 SCANNER: Previous scan completed naturally',
            );
            // Extra delay to let the scan's finally block complete
            await Future.delayed(const Duration(milliseconds: 500));
          }
        } catch (e) {
          AppLogging.connection(
            '📡 SCANNER: Error waiting for scan completion: $e',
          );
        }
      }

      // 2. Now stop any lingering scan state
      try {
        await FlutterBluePlus.stopScan();
        AppLogging.connection('📡 SCANNER: Stopped existing scan');
      } catch (e) {
        AppLogging.connection('📡 SCANNER: stopScan error (ignoring): $e');
      }

      // 3. Clean up ALL system devices if user just disconnected
      // When user manually disconnects, the device we just released may still
      // have stale BLE state. Clean up everything to ensure fresh scan.
      if (userJustDisconnected) {
        AppLogging.connection(
          '📡 SCANNER: User just disconnected - cleaning all system devices',
        );
        try {
          final systemDevices = await FlutterBluePlus.systemDevices([]);
          for (final device in systemDevices) {
            try {
              if (Platform.isAndroid) {
                await device.clearGattCache();
              }
              if (device.isConnected) {
                await device.disconnect();
              }
            } catch (e) {
              // Ignore individual device errors
            }
          }
          AppLogging.connection(
            '📡 SCANNER: Cleaned ${systemDevices.length} system devices',
          );
        } catch (e) {
          AppLogging.connection('📡 SCANNER: System devices cleanup error: $e');
        }
      }

      // 4. Try to disconnect any stale connections to our saved device
      // This helps when the device was connected to another app
      if (_savedDeviceId != null) {
        try {
          // Check system devices (works on both iOS and Android)
          final systemDevices = await FlutterBluePlus.systemDevices([]);
          for (final device in systemDevices) {
            if (device.remoteId.toString() == _savedDeviceId) {
              AppLogging.connection(
                '📡 SCANNER: Found saved device in system devices, forcing cleanup...',
              );
              try {
                // On Android, clear the GATT cache to force fresh discovery
                if (Platform.isAndroid) {
                  await device.clearGattCache();
                  AppLogging.connection(
                    '📡 SCANNER: Cleared GATT cache (Android)',
                  );
                }
                await device.disconnect();
                AppLogging.connection(
                  '📡 SCANNER: Disconnected stale connection to saved device',
                );
              } catch (e) {
                AppLogging.connection(
                  '📡 SCANNER: Cleanup error (ignoring): $e',
                );
              }
            }
          }

          // Android: Also check bonded devices for stale connections
          if (Platform.isAndroid) {
            try {
              final bondedDevices = await FlutterBluePlus.bondedDevices;
              for (final device in bondedDevices) {
                if (device.remoteId.toString() == _savedDeviceId) {
                  AppLogging.connection(
                    '📡 SCANNER: Found saved device in bonded devices, cleaning up...',
                  );
                  try {
                    await device.clearGattCache();
                    if (device.isConnected) {
                      await device.disconnect();
                    }
                    AppLogging.connection(
                      '📡 SCANNER: Cleaned up bonded device',
                    );
                  } catch (e) {
                    AppLogging.connection(
                      '📡 SCANNER: Bonded device cleanup error (ignoring): $e',
                    );
                  }
                }
              }
            } catch (e) {
              AppLogging.connection(
                '📡 SCANNER: bondedDevices error (ignoring): $e',
              );
            }
          }
        } catch (e) {
          AppLogging.connection(
            '📡 SCANNER: systemDevices error (ignoring): $e',
          );
        }
      }

      // 5. Wait for BLE subsystem to fully reset
      // - Android needs longer due to GATT cache clearing
      // - After user manual disconnect, the device needs extra time to start
      //   advertising again since we just released the BLE connection
      int resetDelay = Platform.isAndroid ? 1500 : 1000;
      if (userJustDisconnected) {
        // Extra time for the device to transition to advertising mode
        resetDelay += 1000;
        AppLogging.connection(
          '📡 SCANNER: User just disconnected, adding extra delay',
        );
      }
      AppLogging.connection(
        '📡 SCANNER: Waiting ${resetDelay}ms for BLE to fully reset...',
      );
      await Future.delayed(Duration(milliseconds: resetDelay));

      if (!mounted) {
        AppLogging.connection('📡 SCANNER: Widget unmounted during delay');
        return;
      }

      final transport = ref.read(transportProvider);
      final showAllDevices = ref.read(showAllBleDevicesProvider);
      AppLogging.connection(
        '📡 SCANNER: Starting transport.scan(scanAll: $showAllDevices)...',
      );
      final scanStream = transport.scan(
        timeout: const Duration(seconds: 10),
        scanAll: showAllDevices,
      );

      await for (final device in scanStream) {
        if (!mounted) {
          AppLogging.connection('📡 SCANNER: Widget unmounted during scan');
          break;
        }
        AppLogging.connection(
          '📡 SCANNER: Found device ${device.id} (${device.name})',
        );
        setState(() {
          // Avoid duplicates
          final index = _devices.indexWhere((d) => d.id == device.id);
          if (index >= 0) {
            _devices[index] = device;
          } else {
            _devices.add(device);
          }
        });
      }
      AppLogging.connection(
        '📡 SCANNER: Scan stream completed, found ${_devices.length} devices',
      );

      // After scan completes, check if saved device was found
      // If not, show info banner that it may be connected elsewhere
      if (mounted && _savedDeviceId != null) {
        final savedDeviceFound = _devices.any((d) => d.id == _savedDeviceId);
        if (!savedDeviceFound && _devices.isNotEmpty) {
          // Found other devices but not the saved one - likely connected elsewhere
          AppLogging.connection(
            '📡 SCANNER: Saved device $_savedDeviceId not found, may be connected elsewhere',
          );
          setState(() {
            _savedDeviceNotFoundName = _savedDeviceName ?? 'Your saved device';
          });
        }
      }
    } catch (e) {
      AppLogging.connection('📡 SCANNER: Scan error: $e');
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        setState(() {
          _errorMessage = message;
          _showPairingInvalidationHint = false;
        });
      }
    } finally {
      AppLogging.connection('📡 SCANNER: Scan finally block, mounted=$mounted');
      if (mounted) {
        setState(() {
          _scanning = false;
        });
      }
    }
  }

  Future<void> _openBluetoothSettings() async {
    final opened = await PermissionHelper().openBluetoothSettings();
    if (!mounted) return;
    if (!opened) {
      showErrorSnackBar(
        context,
        'Could not open Bluetooth Settings. Please open Settings > Bluetooth manually.',
      );
    }
  }

  void _updateSavedDeviceMeta({
    String? savedDeviceId,
    String? savedDeviceName,
    TransportType? savedDeviceType,
  }) {
    _savedDeviceId = savedDeviceId;
    _savedDeviceName = savedDeviceName;
    _savedDeviceTransportType = savedDeviceType;
  }

  TransportType _transportTypeFromString(String? type) {
    if (type == 'usb') {
      return TransportType.usb;
    }
    return TransportType.ble;
  }

  /// Build the list of devices to display in the scanner.
  ///
  /// By default, only shows devices with recognized protocols (Meshtastic, MeshCore).
  /// Unknown devices are only shown when "Show all BLE devices" dev mode is enabled.
  List<DeviceInfo> _buildDisplayDevices({bool showAllDevices = false}) {
    List<DeviceInfo> devices;

    if (showAllDevices) {
      // Dev mode: show all scanned devices
      devices = [..._devices];
    } else {
      // Normal mode: filter to only recognized protocols
      devices = _devices.where((device) {
        final protocol = device.detectProtocol().protocolType;
        return protocol == MeshProtocolType.meshtastic ||
            protocol == MeshProtocolType.meshcore;
      }).toList();
    }

    // Add saved device placeholder if scanning and not found
    if ((_scanning || _autoReconnecting) &&
        _savedDeviceId != null &&
        devices.every((d) => d.id != _savedDeviceId)) {
      final placeholder = _savedDevicePlaceholder();
      if (placeholder != null) {
        devices.insert(0, placeholder);
      }
    }
    return devices;
  }

  DeviceInfo? _savedDevicePlaceholder() {
    if (_savedDeviceId == null) return null;
    final name = _savedDeviceName ?? 'Saved Device';
    final type = _savedDeviceTransportType ?? TransportType.ble;
    return DeviceInfo(id: _savedDeviceId!, name: name, type: type);
  }

  Future<void> _connect(DeviceInfo device) async {
    HapticFeedback.mediumImpact();
    AppLogging.connection(
      '📡 SCANNER: User tapped to connect to ${device.id} (${device.name})',
    );

    // Detect protocol from device info
    final detection = device.detectProtocol();
    AppLogging.connection(
      '📡 SCANNER: Detected protocol: ${detection.protocolType} (confidence: ${detection.confidence})',
    );

    // Route connection based on detected protocol
    switch (detection.protocolType) {
      case MeshProtocolType.meshcore:
        await _connectMeshCore(device, detection);
        return;
      case MeshProtocolType.meshtastic:
        // Continue with Meshtastic connect below
        break;
      case MeshProtocolType.unknown:
        // Should not reach here - unknown devices go through warning dialog
        // But if we do, show error and don't attempt Meshtastic connect
        AppLogging.connection('📡 SCANNER: Unknown protocol - not connecting');
        if (mounted) {
          showErrorSnackBar(
            context,
            'Unknown device protocol - cannot connect',
          );
        }
        return;
    }

    // Clear userDisconnected flag since user is explicitly connecting
    // This allows auto-reconnect to work for this new device
    ref.read(userDisconnectedProvider.notifier).setUserDisconnected(false);
    ref.read(conn.deviceConnectionProvider.notifier).clearUserDisconnected();
    // Set state to manualConnecting to prevent auto-reconnect to the OLD saved device
    // if this manual connection fails (e.g., device is already connected to another phone)
    ref
        .read(autoReconnectStateProvider.notifier)
        .setState(AutoReconnectState.manualConnecting);
    await _connectToDevice(device, isAutoReconnect: false);
  }

  /// Connect to a MeshCore device.
  ///
  /// MeshCore uses Nordic UART Service (6e400001-b5a3-f393-e0a9-e50e24dcca9e)
  /// with TX (6e400002) and RX (6e400003) characteristics.
  Future<void> _connectMeshCore(
    DeviceInfo device,
    ProtocolDetectionResult detection,
  ) async {
    AppLogging.connection(
      '📡 SCANNER: MeshCore device detected - ${detection.reason}',
    );

    if (!mounted) return;

    if (_connecting) {
      AppLogging.connection(
        '📡 SCANNER: _connectMeshCore called but already connecting',
      );
      return;
    }

    setState(() {
      _connecting = true;
      _errorMessage = null;
    });

    try {
      // Stop any running Meshtastic ProtocolService to prevent state mixing.
      // MeshCore and Meshtastic are mutually exclusive - only one protocol
      // can be active at a time. Stopping ProtocolService ensures:
      // - No "Requesting position" errors from Meshtastic polling
      // - No stale Meshtastic state interfering with MeshCore UI
      final protocol = ref.read(protocolServiceProvider);
      protocol.stop();
      AppLogging.connection(
        '📡 SCANNER: Stopped Meshtastic ProtocolService for MeshCore connect',
      );

      // Use ConnectionCoordinator to handle MeshCore connection
      final coordinator = ref.read(connectionCoordinatorProvider);
      final result = await coordinator.connect(device: device);

      if (!mounted) return;

      if (!result.success) {
        // Connection failed
        setState(() {
          _connecting = false;
          _errorMessage = result.errorMessage ?? 'MeshCore connection failed';
        });
        showErrorSnackBar(
          context,
          result.errorMessage ?? 'MeshCore connection failed',
        );
        return;
      }

      // Connection succeeded - save device for auto-reconnect (with protocol)
      final settingsService = await ref.read(settingsServiceProvider.future);
      await settingsService.setLastDevice(
        device.id,
        'ble',
        deviceName: device.name,
        protocol: 'meshcore',
      );

      // Update connected device provider
      ref.read(connectedDeviceProvider.notifier).setState(device);

      // Mark as paired in device connection provider
      // For MeshCore, we use the nodeId from MeshDeviceInfo
      // Pass isMeshCore=true so it sets up the correct state listener
      final nodeIdHex = result.deviceInfo?.nodeId ?? '0';
      final nodeNumParsed = int.tryParse(nodeIdHex, radix: 16);
      ref
          .read(conn.deviceConnectionProvider.notifier)
          .markAsPaired(device, nodeNumParsed, isMeshCore: true);

      // Clear userDisconnected flag
      ref.read(userDisconnectedProvider.notifier).setUserDisconnected(false);
      ref.read(conn.deviceConnectionProvider.notifier).clearUserDisconnected();

      // Reset auto-reconnect state
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.idle);

      // CRITICAL: Invalidate linkStatusProvider to force UI rebuild.
      // This ensures activeProtocolProvider sees MeshCore as connected
      // and AppRootShell routes to MeshCoreShell instead of MainShell.
      ref.invalidate(linkStatusProvider);

      AppLogging.connection(
        '📡 SCANNER: MeshCore connected successfully: ${result.deviceInfo?.displayName}',
      );

      setState(() {
        _connecting = false;
      });

      if (!mounted) return;

      // Navigate based on context (same as Meshtastic flow)
      final isFromNeedsScanner =
          ref.read(appInitProvider) == AppInitState.needsScanner;

      if (widget.isOnboarding) {
        Navigator.of(context).pop(device);
        return;
      }

      if (isFromNeedsScanner) {
        // At root level from needsScanner - update app state to initialized
        ref.read(appInitProvider.notifier).setInitialized();
      } else if (!widget.isInline) {
        // Navigate to main app
        Navigator.of(context).pushReplacementNamed('/main');
      }
      // If inline, don't navigate - let connection state trigger rebuild
    } catch (e, stack) {
      AppLogging.connection('📡 SCANNER: MeshCore connection error: $e');
      FirebaseCrashlytics.instance.recordError(e, stack);

      if (!mounted) return;

      setState(() {
        _connecting = false;
        _errorMessage = 'Connection failed: $e';
      });
      showErrorSnackBar(context, 'MeshCore connection failed: $e');
    }
  }

  Future<void> _connectToDevice(
    DeviceInfo device, {
    required bool isAutoReconnect,
  }) async {
    if (_connecting) {
      AppLogging.connection(
        '📡 SCANNER: _connectToDevice called but already connecting',
      );
      return;
    }

    AppLogging.connection(
      '📡 SCANNER: _connectToDevice ${device.id} (${device.name}), isAutoReconnect=$isAutoReconnect',
    );

    setState(() {
      _connecting = true;
      _autoReconnecting = isAutoReconnect;
      _showPairingInvalidationHint = false;
    });

    try {
      final transport = ref.read(transportProvider);

      AppLogging.connection('📡 SCANNER: Calling transport.connect()...');
      await transport.connect(device);
      AppLogging.connection(
        '📡 SCANNER: transport.connect() returned, state=${transport.state}',
      );

      if (!mounted) return;

      ref.read(connectedDeviceProvider.notifier).setState(device);

      // Save device for auto-reconnect (with protocol for future reconnect routing)
      final settingsServiceAsync = ref.read(settingsServiceProvider);
      final settingsService = settingsServiceAsync.value;
      if (settingsService != null) {
        final deviceType = device.type == TransportType.ble ? 'ble' : 'usb';
        await settingsService.setLastDevice(
          device.id,
          deviceType,
          deviceName: device.name,
          protocol: 'meshtastic',
        );
      }

      // Clear all previous device data before starting new connection
      // This follows the Meshtastic iOS approach of always fetching fresh data from the device
      await clearDeviceDataBeforeConnect(ref);

      // Start protocol service and wait for configuration
      final protocol = ref.read(protocolServiceProvider);
      AppLogging.debug(
        '🟡 Scanner screen - protocol instance: ${protocol.hashCode}',
      );

      // Set device info for hardware model inference (for devices like T1000-E that return UNSET)
      protocol.setDeviceName(device.name);
      protocol.setBleModelNumber(transport.bleModelNumber);
      protocol.setBleManufacturerName(transport.bleManufacturerName);

      await protocol.start();

      // Verify protocol actually received configuration from device
      // If PIN was cancelled or authentication failed, myNodeNum will be null
      if (protocol.myNodeNum == null) {
        AppLogging.debug(
          '🔴 Scanner: No config received - authentication may have failed',
        );
        await transport.disconnect();
        throw Exception(
          'Connection failed - please try again and enter the PIN when prompted',
        );
      }

      // Mark connection as fully established in the device connection provider
      // This is required for route guards to allow access to device config screens
      ref
          .read(conn.deviceConnectionProvider.notifier)
          .markAsPaired(device, protocol.myNodeNum);

      // Start phone GPS location updates
      // This sends phone GPS to mesh for devices without GPS hardware
      final locationService = ref.read(locationServiceProvider);
      await locationService.startLocationUpdates();

      if (!mounted) return;

      // If onboarding, return the device and let onboarding handle navigation
      if (widget.isOnboarding) {
        Navigator.of(context).pop(device);
        return;
      }

      // ALWAYS check the actual device region - firmware updates can reset it!
      // Don't assume "connected before = region configured" - that's wrong.
      final settings = await ref.read(settingsServiceProvider.future);

      AppLogging.debug(
        '🔍 Checking device region (always check - firmware may have reset it)...',
      );

      bool needsRegionSetup = false;

      // Always check region from device - firmware updates can reset it
      {
        config_pbenum.Config_LoRaConfig_RegionCode? region =
            protocol.currentRegion;
        AppLogging.debug('🔍 Initial region: ${region?.name ?? "null"}');

        // If region not available yet, wait for loraConfigStream with proper timeout
        // This handles the timing issue where config arrives after our initial check
        if (region == null ||
            region == config_pbenum.Config_LoRaConfig_RegionCode.UNSET) {
          AppLogging.debug('🔍 Waiting for LoRa config stream...');
          try {
            // Subscribe to stream FIRST, then request config
            final configFuture = protocol.loraConfigStream.first.timeout(
              const Duration(seconds: 8),
              onTimeout: () {
                AppLogging.debug('⏱️ LoRa config timeout');
                throw TimeoutException('LoRa config timeout');
              },
            );

            // Request LoRa config
            await protocol.getLoRaConfig();

            // Wait for response
            final loraConfig = await configFuture;
            region = loraConfig.region;
            AppLogging.debug('✅ Received LoRa config - region: ${region.name}');
          } catch (e) {
            AppLogging.debug('⚠️ Error getting LoRa config: $e');
            // Fall back to checking currentRegion one more time
            region = protocol.currentRegion;
            AppLogging.debug('🔍 Fallback region: ${region?.name ?? "null"}');
          }
        }

        AppLogging.nodes('Final region decision: ${region?.name ?? "null"}');

        // Need region setup if region is UNSET (not configured on device)
        // This can happen on fresh install OR after firmware update/reset
        if (region == null ||
            region == config_pbenum.Config_LoRaConfig_RegionCode.UNSET) {
          needsRegionSetup = true;
          AppLogging.debug('⚠️ Region is UNSET - need to configure!');
        } else {
          // Device has a valid region - mark as configured
          await settings.setRegionConfigured(true);
          AppLogging.debug(
            '✅ Region ${region.name} detected, marked as configured',
          );
        }
      }

      if (!mounted) return;

      // Check current app state - if we're shown from needsScanner, update provider
      final appState = ref.read(appInitProvider);
      final isFromNeedsScanner = appState == AppInitState.needsScanner;

      final regionState = ref.read(regionConfigProvider);
      final sessionId = ref
          .read(conn.deviceConnectionProvider)
          .connectionSessionId;
      final shouldShowRegionPicker =
          needsRegionSetup &&
          regionState.connectionSessionId == sessionId &&
          regionState.applyStatus != RegionApplyStatus.applying &&
          regionState.applyStatus != RegionApplyStatus.applied &&
          regionState.applyStatus != RegionApplyStatus.failed;

      if (shouldShowRegionPicker) {
        // Navigate to region selection
        // CRITICAL: isInitialSetup should ONLY be true during genuine first-time onboarding
        // After factory reset, user is experienced and screen should pop immediately
        // Use widget.isOnboarding (true only during onboarding flow, false for factory reset)
        // Use direct MaterialPageRoute to bypass route guard protection
        // The region save causes device reboot, which momentarily disconnects.
        // Route guard would show "Device Required" screen during this brief disconnect.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (context) =>
                RegionSelectionScreen(isInitialSetup: widget.isOnboarding),
          ),
        );
      } else if (needsRegionSetup) {
        AppLogging.app(
          'REGION_FLOW choose=${regionState.regionChoice?.name ?? "null"} session=$sessionId status=${regionState.applyStatus.name} reason=region_picker_suppressed',
        );
        // Keep user on main flow; require explicit reconnect to retry
        if (isFromNeedsScanner) {
          ref.read(appInitProvider.notifier).setInitialized();
        } else if (!widget.isInline) {
          Navigator.of(context).pushReplacementNamed('/main');
        }
      } else if (isFromNeedsScanner) {
        // We're at the root level from needsScanner - update app state to initialized
        // This will cause _AppRouter to show MainShell
        ref.read(appInitProvider.notifier).setInitialized();
      } else if (!widget.isInline) {
        // Navigate to main app (only if not inline - inline will auto-rebuild)
        Navigator.of(context).pushReplacementNamed('/main');
      }
      // If inline (shown within MainShell), don't navigate - just let the
      // connection state change trigger MainShell to rebuild and show main content

      // Reset auto-reconnect state to idle on successful manual connection
      // This clears any previous failed state from auto-reconnect attempts
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.idle);

      // Ensure offline queue is initialized and process any pending messages
      final queue = ref.read(offlineQueueProvider);
      queue.processQueueIfNeeded();

      // Success - don't reset _connecting, let navigation handle the transition
      return;
    } catch (e, stack) {
      if (!mounted) return;

      // Log error to Crashlytics ONLY for unexpected errors
      // Don't log expected errors like timeouts (device busy/connected elsewhere),
      // pairing/auth errors which are user-recoverable, or GATT errors (133)
      // which happen when device is connected to another phone or cache is stale
      final errorStr = e.toString().toLowerCase();
      final isExpectedError =
          errorStr.contains('timed out') ||
          errorStr.contains('timeout') ||
          errorStr.contains('pairing') ||
          errorStr.contains('bonding') ||
          errorStr.contains('pin') ||
          errorStr.contains('authentication') ||
          errorStr.contains('disconnected during') ||
          errorStr.contains('gatt_error') ||
          errorStr.contains('android-code: 133') ||
          errorStr.contains('device is disconnected') ||
          errorStr.contains('discovery failed');
      if (!isExpectedError) {
        try {
          await FirebaseCrashlytics.instance.recordError(e, stack);
        } catch (_) {}
      }

      // Force cleanup on error to ensure clean state for retry
      try {
        final transport = ref.read(transportProvider);
        await transport.disconnect();
      } catch (_) {
        // Continue on cleanup errors
      }

      // Also stop any active BLE scan
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {
        // Continue
      }

      if (!mounted) return;

      final sanitizedMessage = e.toString().replaceFirst('Exception: ', '');
      final pairingInvalidation = conn.isPairingInvalidationError(e);
      final pairingMessage =
          'Your phone removed the stored pairing info for this device. Return to Settings > Bluetooth, forget "Meshtastic_XXXX", and try again.';

      // Provide user-friendly error messages for common BLE errors
      final errorLower = e.toString().toLowerCase();
      final isTimeout =
          errorLower.contains('timed out') || errorLower.contains('timeout');
      final isGattError =
          errorLower.contains('gatt_error') ||
          errorLower.contains('android-code: 133');
      final isDiscoveryFailed = errorLower.contains('discovery failed');
      final isDeviceDisconnected = errorLower.contains(
        'device is disconnected',
      );

      String userMessage;
      if (pairingInvalidation) {
        userMessage = pairingMessage;
      } else if (isGattError || isDiscoveryFailed) {
        // GATT_ERROR 133 can happen when:
        // - Device was previously paired with another app (stale bond)
        // - Device is connected to another phone
        // - BLE cache is corrupted
        userMessage =
            'Connection failed. This can happen if the device was previously '
            'paired with another app. Go to Settings > Bluetooth, find the '
            'Meshtastic device, tap "Forget", then try again.';
      } else if (isTimeout) {
        userMessage =
            'Connection timed out. The device may be out of range, powered off, '
            'or connected to another phone.';
      } else if (isDeviceDisconnected) {
        userMessage =
            'The device disconnected unexpectedly. It may have gone out of range '
            'or lost power.';
      } else {
        userMessage = sanitizedMessage;
      }

      // Reset auto-reconnect state to idle since manual connection failed
      // This prevents the auto-reconnect manager from trying to reconnect
      // to the OLD saved device after the user's manual attempt failed
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.idle);

      // Only reset connecting state on error
      setState(() {
        _connecting = false;
        _autoReconnecting = false;
        _errorMessage = userMessage;
        _showPairingInvalidationHint = pairingInvalidation || isGattError;
      });

      // If auto-reconnect failed, start regular scan
      if (isAutoReconnect) {
        _startScan();
      }
    }
  }

  Widget _buildConnectingContent() {
    final statusInfo = _autoReconnecting
        ? ConnectionStatusInfo.autoReconnecting(context.accentColor)
        : ConnectionStatusInfo.connecting(context.accentColor);

    return ConnectingContent(
      statusInfo: statusInfo,
      showMeshNode: true,
      showCancel: _autoReconnecting,
      accentColor: context.accentColor,
      onCancel: () {
        setState(() {
          _connecting = false;
          _autoReconnecting = false;
        });
        _startScan();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // When connecting, use EXACT same structure as onboarding
    if (_connecting) {
      return Scaffold(
        backgroundColor: context.background,
        body: Stack(
          children: [
            // Background - Beautiful parallax floating icons
            const Positioned.fill(child: ConnectingAnimationBackground()),
            // Content in SafeArea - EXACT same as onboarding
            SafeArea(child: Center(child: _buildConnectingContent())),
          ],
        ),
        bottomNavigationBar: Consumer(
          builder: (context, ref, child) {
            final appVersionAsync = ref.watch(appVersionProvider);
            final versionText = appVersionAsync.when(
              data: (version) => 'Version v$version',
              loading: () => 'Socialmesh',
              error: (_, _) => 'Socialmesh',
            );

            return Container(
              color: context.background,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      versionText,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '© 2026 Socialmesh. All rights reserved.',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textTertiary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    return HelpTourController(
      topicId: 'device_connection',
      stepKeys: const {},
      child: GlassScaffold(
        leading: widget.isOnboarding
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: context.textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        titleWidget: Text(
          widget.isOnboarding ? 'Connect Device' : 'Devices',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        actions: [
          IcoHelpAppBarButton(
            topicId: 'device_connection',
            autoTrigger: widget.isOnboarding,
          ),
        ],
        bottomNavigationBar: Consumer(
          builder: (context, ref, child) {
            final appVersionAsync = ref.watch(appVersionProvider);
            final versionText = appVersionAsync.when(
              data: (version) => 'Socialmesh v$version',
              loading: () => 'Socialmesh',
              error: (_, _) => 'Socialmesh',
            );

            return Container(
              color: context.background,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      versionText,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '© 2026 Socialmesh. All rights reserved.',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textTertiary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Info banner when saved device wasn't found
                if (_savedDeviceNotFoundName != null)
                  Container(
                    padding: const EdgeInsets.all(24),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange.shade700,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_savedDeviceNotFoundName not found',
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'If another app is connected to this device, disconnect from it first. Only one app can use Bluetooth at a time.',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: Colors.orange.shade700,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _savedDeviceNotFoundName = null),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.errorRed.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppTheme.errorRed,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: AppTheme.errorRed),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: AppTheme.errorRed),
                          onPressed: () => setState(() {
                            _errorMessage = null;
                            _showPairingInvalidationHint = false;
                          }),
                          iconSize: 20,
                        ),
                      ],
                    ),
                  ),

                if (_showPairingInvalidationHint)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: context.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.accentColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bluetooth pairing was removed. Forget “Meshtastic” in Settings > Bluetooth and reconnect to continue.',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: _openBluetoothSettings,
                              icon: Icon(
                                Icons.bluetooth_rounded,
                                size: 16,
                                color: context.textPrimary,
                              ),
                              label: Text(
                                'Bluetooth Settings',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: context.textPrimary,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                  horizontal: 10,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _errorMessage = null;
                                  _showPairingInvalidationHint = false;
                                });
                                _startScan();
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                  horizontal: 10,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Retry Scan',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: context.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                if (_scanning)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: context.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.accentColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        LoadingIndicator(size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Scanning for nearby devices',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _devices.isEmpty
                                    ? 'Looking for Meshtastic devices...'
                                    : '${_devices.length} ${_devices.length == 1 ? 'device' : 'devices'} found so far',
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Dev mode toggle: Show all BLE devices
                if (kDebugMode)
                  Consumer(
                    builder: (context, ref, child) {
                      final showAllDevices = ref.watch(
                        showAllBleDevicesProvider,
                      );
                      return Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.purple.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.developer_mode,
                              color: Colors.purple,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Show all BLE devices',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    showAllDevices
                                        ? 'Scanning all devices (dev mode)'
                                        : 'Filtering by Meshtastic UUID',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: showAllDevices,
                              onChanged: _scanning
                                  ? null
                                  : (value) async {
                                      final storage = await ref.read(
                                        settingsServiceProvider.future,
                                      );
                                      await storage.setShowAllBleDevices(value);
                                      ref.invalidate(settingsServiceProvider);
                                      if (mounted) {
                                        _startScan();
                                      }
                                    },
                              activeColor: Colors.purple,
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                // Device list header and count - wrapped in Consumer for filtering
                Consumer(
                  builder: (context, ref, child) {
                    final showAllDevices = ref.watch(showAllBleDevicesProvider);
                    final filteredDevices = _buildDisplayDevices(
                      showAllDevices: showAllDevices,
                    );
                    if (filteredDevices.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Text(
                            'Available Devices',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.textSecondary,

                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${filteredDevices.length}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.accentColor,
                              ),
                            ),
                          ),
                          Spacer(),
                          TextButton.icon(
                            onPressed: _scanning ? null : _startScan,
                            icon: Icon(Icons.refresh, size: 16),
                            label: Text(
                              'Retry Scan',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 10,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                if (_devices.isEmpty && !_scanning)
                  Center(
                    child: Column(
                      children: [
                        SizedBox(height: 100),
                        Icon(
                          Icons.bluetooth_searching,
                          size: 80,
                          color: context.textTertiary,
                        ),
                        SizedBox(height: 24),
                        Text(
                          'No devices found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: context.textSecondary,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Make sure Bluetooth is enabled and\nyour Meshtastic device is powered on',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: context.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _startScan,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Scan Again'),
                        ),
                      ],
                    ),
                  )
                else
                  Consumer(
                    builder: (context, ref, child) {
                      final showAllDevices = ref.watch(
                        showAllBleDevicesProvider,
                      );
                      // Build filtered device list based on dev mode
                      final filteredDevices = _buildDisplayDevices(
                        showAllDevices: showAllDevices,
                      );
                      return Column(
                        children: filteredDevices.map((device) {
                          final detection = device.detectProtocol();
                          final isUnknown =
                              detection.protocolType ==
                              MeshProtocolType.unknown;
                          return Column(
                            children: [
                              _DeviceCard(
                                device: device,
                                protocolType: detection.protocolType,
                                showDebugInfo: showAllDevices,
                                onTap: () {
                                  // Allow unknown devices only in dev mode
                                  if (isUnknown && !showAllDevices) {
                                    return;
                                  }
                                  if (isUnknown) {
                                    // Show warning dialog for unknown devices
                                    _showUnknownDeviceWarning(
                                      context,
                                      device,
                                      detection,
                                    );
                                  } else {
                                    _connect(device);
                                  }
                                },
                              ),
                              if (device.rssi != null)
                                _DeviceDetailsTable(
                                  device: device,
                                  showAdvertisementData: showAllDevices,
                                ),
                            ],
                          );
                        }).toList(),
                      );
                    },
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showUnknownDeviceWarning(
    BuildContext context,
    DeviceInfo device,
    ProtocolDetectionResult detection,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Unknown Protocol', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This device was not detected as Meshtastic or MeshCore.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.cardAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detection: ${detection.reason}',
                    style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                  Text(
                    'Confidence: ${(detection.confidence * 100).toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This device cannot be connected automatically. '
              'Only Meshtastic and MeshCore devices are supported.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final DeviceInfo device;
  final MeshProtocolType protocolType;
  final bool showDebugInfo;
  final VoidCallback onTap;

  const _DeviceCard({
    required this.device,
    required this.onTap,
    this.protocolType = MeshProtocolType.meshtastic,
    this.showDebugInfo = false,
  });

  @override
  Widget build(BuildContext context) {
    final signalBars = _calculateSignalBars(device.rssi);
    final isUnknown = protocolType == MeshProtocolType.unknown;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: context.accentColor.withValues(alpha: 0.2),
          highlightColor: context.accentColor.withValues(alpha: 0.1),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isUnknown && showDebugInfo
                    ? Colors.orange.withValues(alpha: 0.5)
                    : context.border,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    device.type == TransportType.ble
                        ? Icons.bluetooth
                        : Icons.usb,
                    color: isUnknown && showDebugInfo
                        ? Colors.orange
                        : context.accentColor,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            device.type == TransportType.ble
                                ? 'Bluetooth'
                                : 'USB',
                            style: TextStyle(
                              fontSize: 14,
                              color: context.textTertiary,
                            ),
                          ),
                          // Always show protocol badge for Meshtastic/MeshCore
                          // Show for unknown devices only in debug mode
                          if (protocolType != MeshProtocolType.unknown ||
                              showDebugInfo) ...[
                            const SizedBox(width: 8),
                            _ProtocolBadge(protocolType: protocolType),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (device.rssi != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < 4; i++)
                        Container(
                          width: 4,
                          height: 4 + (i * 4).toDouble(),
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(
                            color: i < signalBars
                                ? context.accentColor
                                : context.textTertiary.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                    ],
                  ),
                SizedBox(width: 4),
                Icon(Icons.chevron_right, color: context.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _calculateSignalBars(int? rssi) {
    if (rssi == null) return 0;
    if (rssi >= -60) return 4;
    if (rssi >= -70) return 3;
    if (rssi >= -80) return 2;
    if (rssi >= -90) return 1;
    return 0;
  }
}

/// Protocol type badge for device cards
class _ProtocolBadge extends StatelessWidget {
  final MeshProtocolType protocolType;

  const _ProtocolBadge({required this.protocolType});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (protocolType) {
      MeshProtocolType.meshtastic => ('Meshtastic', Colors.green),
      MeshProtocolType.meshcore => ('MeshCore', Colors.blue),
      MeshProtocolType.unknown => ('Unknown', Colors.orange),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _DeviceDetailsTable extends StatelessWidget {
  final DeviceInfo device;
  final bool showAdvertisementData;

  const _DeviceDetailsTable({
    required this.device,
    this.showAdvertisementData = false,
  });

  @override
  Widget build(BuildContext context) {
    final details = <(String, String)>[
      ('Device Name', device.name),
      if (device.address != null) ('Address', device.address!),
      (
        'Connection Type',
        device.type == TransportType.ble
            ? 'Bluetooth Low Energy'
            : 'USB Serial',
      ),
      if (device.rssi != null) ('Signal Strength', '${device.rssi} dBm'),
      // Advertisement data (dev mode only)
      if (showAdvertisementData && device.serviceUuids.isNotEmpty)
        (
          'Service UUIDs',
          device.serviceUuids.isEmpty ? 'None' : device.serviceUuids.join('\n'),
        ),
      if (showAdvertisementData && device.manufacturerData.isNotEmpty)
        (
          'Manufacturer Data',
          device.manufacturerData.entries
              .map(
                (e) =>
                    '0x${e.key.toRadixString(16).padLeft(4, '0')}: '
                    '[${e.value.length} bytes]',
              )
              .join('\n'),
        ),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 16, top: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          children: details.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isOdd = index % 2 == 1;

            return Container(
              decoration: BoxDecoration(
                color: isOdd ? context.cardAlt : context.background,
                border: Border(
                  bottom: index < details.length - 1
                      ? BorderSide(color: context.border, width: 1)
                      : BorderSide.none,
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(color: context.border, width: 1),
                          ),
                        ),
                        child: Text(
                          item.$1,
                          style: TextStyle(
                            fontSize: 14,
                            color: context.textTertiary,

                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        child: Text(
                          item.$2,
                          style: TextStyle(
                            fontSize: 14,
                            color: context.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
