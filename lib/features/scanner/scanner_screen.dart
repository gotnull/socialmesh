// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../../core/logging.dart';
import '../../core/safety/error_handler.dart';
import '../../core/safety/lifecycle_mixin.dart';
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
import '../../core/widgets/status_banner.dart';
import '../../models/mesh_device.dart';
import '../../services/meshcore/meshcore_detector.dart';
import '../../providers/meshcore_providers.dart';
import '../../utils/permissions.dart';
import '../../utils/snackbar.dart';
import '../../providers/app_providers.dart';
import '../../services/storage/storage_service.dart';
import '../../generated/meshtastic/config.pbenum.dart' as config_pbenum;
import 'widgets/connecting_animation.dart';
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

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with LifecycleSafeMixin {
  final List<DeviceInfo> _devices = [];
  bool _scanning = false;
  bool _connecting = false;
  bool _autoReconnecting = false;
  String? _errorMessage;
  String? _savedDeviceNotFoundName;
  bool _showPairingInvalidationHint = false;
  bool _showAutoReconnectDisabledHint = false;
  String? _savedDeviceId;
  String? _savedDeviceName;
  TransportType? _savedDeviceTransportType;

  /// Subscription used to monitor background reconnect outcome when the
  /// Scanner defers to an active _performReconnect cycle.
  ProviderSubscription<AutoReconnectState>? _backgroundReconnectSub;

  /// Subscription used to wait for an in-flight disconnect to complete
  /// before starting a scan. This happens when the user taps Disconnect
  /// but the transport hasn't fully torn down by the time Scanner inits.
  ProviderSubscription<conn.DeviceConnectionState2>? _disconnectSub;

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
      AppErrorHandler.addBreadcrumb('Scanner: pairing invalidation detected');
      _showPairingInvalidationHint = true;
    } else if (autoReconnectState == AutoReconnectState.failed &&
        deviceState.reason == conn.DisconnectReason.authFailed) {
      // PIN/auth failure during auto-reconnect — the device was found and
      // BLE-connected but protocol configuration timed out (likely because
      // the system pairing/PIN dialog wasn't shown during background
      // reconnect). Show the same guidance as pairing invalidation so the
      // user knows to forget the device in Bluetooth settings and re-pair.
      AppLogging.connection(
        '📡 SCANNER: Shown after auto-reconnect PIN/auth failure',
      );
      AppErrorHandler.addBreadcrumb('Scanner: auth failure detected');
      _showPairingInvalidationHint = true;
      _errorMessage =
          'Authentication failed. The device may need to be re-paired. '
          'Go to Settings > Bluetooth, forget the Meshtastic device, '
          'then tap it below to reconnect.';
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

    // Check if we're shown because auto-reconnect is disabled (but user has paired before)
    // This happens when user explicitly disabled auto-reconnect in settings
    if (!widget.isOnboarding && !widget.isInline) {
      ref.read(settingsServiceProvider.future).then((settings) {
        if (mounted &&
            !settings.autoReconnect &&
            settings.lastDeviceId != null) {
          AppLogging.connection(
            '📡 SCANNER: Shown because auto-reconnect is disabled',
          );
          setState(() {
            _showAutoReconnectDisabledHint = true;
            _savedDeviceName = settings.lastDeviceName;
          });
        }
      });
    }

    // Defer BLE-triggering work (scan / auto-reconnect) to a post-frame
    // callback. This prevents a cosmetic duplicate-Scanner issue that occurs
    // during manual disconnect and factory reset:
    //
    //   1. setNeedsScanner() synchronously causes the OLD _AppRouter to
    //      rebuild, swapping AppRootShell → ScannerScreen #1 (initState runs)
    //   2. pushNamedAndRemoveUntil('/app', ...) creates a NEW _AppRouter
    //      which also mounts ScannerScreen #2 (initState runs)
    //   3. ScannerScreen #1 is disposed moments later when old routes are
    //      removed — but its initState already ran
    //
    // By deferring the scan start to a post-frame callback, Scanner #1 is
    // disposed before the callback fires (mounted == false → no-op), so
    // only Scanner #2 starts BLE operations. The synchronous state reads
    // above (hints, pairing invalidation) are harmless and stay in initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.isOnboarding || widget.isInline) {
        AppLogging.connection(
          '📡 SCANNER: Onboarding/inline mode - starting manual scan',
        );
        _startScan();
      } else {
        AppLogging.connection(
          '📡 SCANNER: Normal mode - trying auto-reconnect',
        );
        _tryAutoReconnect();
      }
    });
  }

  @override
  void dispose() {
    _backgroundReconnectSub?.close();
    _disconnectSub?.close();
    // If manualConnecting is still set when Scanner closes (e.g., user
    // backed out after a failed connection, or connection succeeded and
    // router swapped to MainShell), clear it so the auto-reconnect
    // manager can resume normal operation.
    try {
      final currentState = ref.read(autoReconnectStateProvider);
      if (currentState == AutoReconnectState.manualConnecting) {
        AppLogging.connection(
          '📡 SCANNER: dispose — clearing stale manualConnecting → idle',
        );
        ref
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.idle);
      }
    } catch (_) {
      // ref may be invalid if container is already disposing — ignore
    }
    AppLogging.connection('📡 SCANNER: dispose - hashCode=$hashCode');
    super.dispose();
  }

  /// Listens for the background reconnect to reach a terminal state
  /// (success or failed) so the Scanner can react without running its
  /// own duplicate scan.
  /// Listens for the transport to finish disconnecting so we can start
  /// scanning. This is needed when the user taps Disconnect in the device
  /// sheet — the Scanner may initialize before the transport is fully
  /// torn down (the disconnect is async). Once we see disconnected state,
  /// we start the normal scan flow.
  void _listenForDisconnectCompletion() {
    _disconnectSub?.close();
    _disconnectSub = ref.listenManual<conn.DeviceConnectionState2>(
      conn.deviceConnectionProvider,
      (previous, next) {
        if (next.state == conn.DevicePairingState.disconnected ||
            next.state == conn.DevicePairingState.neverPaired) {
          AppLogging.connection(
            '📡 SCANNER: Transport disconnect completed (${next.state}) '
            '— starting scan',
          );
          _disconnectSub?.close();
          _disconnectSub = null;
          if (!mounted) return;
          _startScan();
        }
      },
    );
  }

  void _listenForBackgroundReconnectOutcome() {
    _backgroundReconnectSub?.close();
    _backgroundReconnectSub = ref.listenManual<AutoReconnectState>(
      autoReconnectStateProvider,
      (previous, next) {
        AppLogging.connection(
          '📡 SCANNER: Background reconnect state changed: $previous -> $next',
        );
        if (next == AutoReconnectState.success) {
          _backgroundReconnectSub?.close();
          _backgroundReconnectSub = null;
          AppLogging.connection(
            '📡 SCANNER: Background reconnect succeeded — navigating to main',
          );
          if (!mounted) return;
          final appState = ref.read(appInitProvider);
          if (appState == AppInitState.needsScanner) {
            ref.read(appInitProvider.notifier).setReady();
          } else if (!widget.isInline) {
            _navigateToMain();
          }
        } else if (next == AutoReconnectState.failed ||
            next == AutoReconnectState.idle) {
          _backgroundReconnectSub?.close();
          _backgroundReconnectSub = null;
          AppLogging.connection(
            '📡 SCANNER: Background reconnect finished ($next) — '
            'falling through to manual scan',
          );
          if (!mounted) return;
          safeSetState(() {
            _autoReconnecting = false;
          });
          _startScan();
        }
      },
    );
  }

  /// Navigate to main app after successful connection.
  /// If Scanner was pushed on top of MainShell (e.g. from the
  /// TopStatusBanner "Connect" button), just pop back — MainShell
  /// will rebuild with the connected state automatically. If Scanner
  /// is the root route (pushed via /app after disconnect), set
  /// appInit to initialized so _AppRouter shows MainShell.
  void _navigateToMain() {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      AppLogging.connection(
        '📡 SCANNER: Popping back to previous screen (pushed from banner/route)',
      );
      navigator.pop();
    } else {
      AppLogging.connection(
        '📡 SCANNER: At root — setting appInit to initialized for _AppRouter',
      );
      ref.read(appInitProvider.notifier).setInitialized();
    }
  }

  Future<void> _tryAutoReconnect() async {
    // Capture providers BEFORE any await
    final autoReconnectState = ref.read(autoReconnectStateProvider);
    final deviceState = ref.read(conn.deviceConnectionProvider);
    final userDisconnected = ref.read(userDisconnectedProvider);
    final settingsFuture = ref.read(settingsServiceProvider.future);
    final transport = ref.read(transportProvider);

    AppLogging.connection(
      '📡 SCANNER: _tryAutoReconnect - autoReconnectState=$autoReconnectState, '
      'deviceState=${deviceState.state}, reason=${deviceState.reason}',
    );

    // CRITICAL: If a device is already connected or configuring, do NOT
    // scan or do BLE cleanup — that would disconnect the active connection
    // and create a cascade of reconnect cycles. This can happen when the
    // router shows the scanner while a connection is already live (e.g.
    // settings.lastDeviceId is null but the device is paired in memory).
    //
    // EXCEPTION: If the user explicitly disconnected (userDisconnected flag
    // is true), the transport disconnect may still be in flight when Scanner
    // initializes. In that case do NOT redirect to main — the user wants
    // to be here. The device state will transition to disconnected shortly;
    // just fall through and let _startScan() handle it once the transport
    // finishes tearing down.
    if ((deviceState.isConnected ||
            deviceState.state == conn.DevicePairingState.configuring) &&
        !userDisconnected) {
      AppLogging.connection(
        '📡 SCANNER: BLOCKED — device already ${deviceState.state}, '
        'navigating to main instead of scanning',
      );
      final appState = ref.read(appInitProvider);
      if (appState == AppInitState.needsScanner) {
        ref.read(appInitProvider.notifier).setReady();
      } else if (!widget.isInline) {
        _navigateToMain();
      }
      return;
    }

    // If user disconnected but transport hasn't finished yet, wait for it
    // before starting a scan (scanning while connected causes BLE errors).
    if (userDisconnected &&
        (deviceState.isConnected ||
            deviceState.state == conn.DevicePairingState.configuring)) {
      AppLogging.connection(
        '📡 SCANNER: User disconnected but transport still ${deviceState.state} '
        '— waiting for disconnect to complete before scanning',
      );
      _listenForDisconnectCompletion();
      return;
    }

    // CRITICAL: If the background reconnect (autoReconnectManagerProvider →
    // _performReconnect) is already scanning or connecting, do NOT start a
    // duplicate scan from the Scanner. Running two concurrent BLE scans
    // (one from _performReconnect's FlutterBluePlus.startScan and one from
    // Scanner's transport.scan) causes BLE contention, interleaved results,
    // and connection failures. Instead, show the "Reconnecting..." state and
    // let the background reconnect finish. The Scanner will react to the
    // autoReconnectState changing to success (navigate to main) or failed
    // (fall through to manual scan).
    if (autoReconnectState == AutoReconnectState.scanning ||
        autoReconnectState == AutoReconnectState.connecting) {
      AppLogging.connection(
        '📡 SCANNER: DEFERRED — background reconnect already active '
        '(state=$autoReconnectState), showing reconnecting UI instead of scanning',
      );
      AppErrorHandler.addBreadcrumb(
        'Scanner: deferred to background reconnect ($autoReconnectState)',
      );
      safeSetState(() {
        _autoReconnecting = true;
      });
      // Listen for background reconnect outcome — when it completes or
      // fails, we either navigate away or fall through to manual scan.
      _listenForBackgroundReconnectOutcome();
      return;
    }

    if (autoReconnectState == AutoReconnectState.failed) {
      AppLogging.connection(
        '📡 SCANNER: Auto-reconnect already failed, skipping to scan',
      );
      _startScan();
      return;
    }

    // CRITICAL: Check the global userDisconnected flag
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
      settingsService = await settingsFuture;
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

    safeSetState(() {
      _autoReconnecting = true;
    });

    AppLogging.connection(
      '📡 SCANNER: Auto-reconnect looking for device $lastDeviceId ($lastDeviceType)',
    );

    try {
      // NOTE: Don't clear userDisconnected flag here - only clear it when user
      // explicitly taps on a device to connect in _connect()

      // Start scanning to find the last device
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
        safeSetState(() {
          _autoReconnecting = false;
          _savedDeviceNotFoundName = lastDeviceName ?? 'your saved device';
        });
        _startScan();
      }
    } catch (e) {
      AppLogging.connection('📡 SCANNER: Auto-reconnect failed: $e');
      safeSetState(() {
        _autoReconnecting = false;
      });
      if (mounted) _startScan();
    }
  }

  Future<void> _startScan() async {
    if (_scanning) {
      AppLogging.connection(
        '📡 SCANNER: _startScan called but already scanning',
      );
      return;
    }

    // CRITICAL: Don't scan or do BLE cleanup if a device is already
    // connected. The aggressive cleanup (stopScan, system device
    // disconnect) can destroy an active connection and trigger a
    // cascade of auto-reconnect cycles.
    final currentDeviceState = ref.read(conn.deviceConnectionProvider);
    if (currentDeviceState.isConnected ||
        currentDeviceState.state == conn.DevicePairingState.configuring) {
      AppLogging.connection(
        '📡 SCANNER: _startScan BLOCKED — device already '
        '${currentDeviceState.state}, skipping destructive BLE cleanup',
      );
      return;
    }

    // Capture providers BEFORE any await
    final userJustDisconnected = ref.read(userDisconnectedProvider);
    final settingsFuture = ref.read(settingsServiceProvider.future);
    final transport = ref.read(transportProvider);
    final showAllDevices = ref.read(showAllBleDevicesProvider);
    AppLogging.connection(
      '📡 SCANNER: Starting 10s scan... (userJustDisconnected=$userJustDisconnected)',
    );

    // Get saved device info before scan to check if it was found afterward
    try {
      final settingsService = await settingsFuture;
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

    safeSetState(() {
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
        safeSetState(() {
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
          safeSetState(() {
            _savedDeviceNotFoundName = _savedDeviceName ?? 'Your saved device';
          });
        }
      }
    } catch (e) {
      AppLogging.connection('📡 SCANNER: Scan error: $e');
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        safeSetState(() {
          _errorMessage = message;
          _showPairingInvalidationHint = false;
        });
      }
    } finally {
      AppLogging.connection('📡 SCANNER: Scan finally block, mounted=$mounted');
      safeSetState(() {
        _scanning = false;
      });
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
        return protocol == MeshProtocolType.meshtastic;
        //|| protocol == MeshProtocolType.meshcore;
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

    // Capture providers BEFORE any await
    final userDisconnectedNotifier = ref.read(
      userDisconnectedProvider.notifier,
    );
    final deviceConnectionNotifier = ref.read(
      conn.deviceConnectionProvider.notifier,
    );
    final autoReconnectNotifier = ref.read(autoReconnectStateProvider.notifier);

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
    userDisconnectedNotifier.setUserDisconnected(false);
    deviceConnectionNotifier.clearUserDisconnected();
    // Set state to manualConnecting to prevent auto-reconnect to the OLD saved device
    // if this manual connection fails (e.g., device is already connected to another phone)
    autoReconnectNotifier.setState(AutoReconnectState.manualConnecting);
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

    // Capture providers BEFORE any await
    final protocol = ref.read(protocolServiceProvider);
    final coordinator = ref.read(connectionCoordinatorProvider);
    final settingsFuture = ref.read(settingsServiceProvider.future);
    final connectedDeviceNotifier = ref.read(connectedDeviceProvider.notifier);
    final userDisconnectedNotifier = ref.read(
      userDisconnectedProvider.notifier,
    );
    final deviceConnectionNotifier = ref.read(
      conn.deviceConnectionProvider.notifier,
    );
    final autoReconnectNotifier = ref.read(autoReconnectStateProvider.notifier);

    safeSetState(() {
      _connecting = true;
      _errorMessage = null;
    });

    try {
      // Stop any running Meshtastic ProtocolService to prevent state mixing.
      // MeshCore and Meshtastic are mutually exclusive - only one protocol
      // can be active at a time. Stopping ProtocolService ensures:
      // - No "Requesting position" errors from Meshtastic polling
      // - No stale Meshtastic state interfering with MeshCore UI
      protocol.stop();
      AppLogging.connection(
        '📡 SCANNER: Stopped Meshtastic ProtocolService for MeshCore connect',
      );

      // Use ConnectionCoordinator to handle MeshCore connection
      final result = await coordinator.connect(device: device);

      if (!mounted) return;

      if (!result.success) {
        // Connection failed
        safeSetState(() {
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
      final settingsService = await settingsFuture;
      await settingsService.setLastDevice(
        device.id,
        'ble',
        deviceName: device.name,
        protocol: 'meshcore',
      );

      // Update connected device provider
      connectedDeviceNotifier.setState(device);

      // Mark as paired in device connection provider
      // For MeshCore, we use the nodeId from MeshDeviceInfo
      // Pass isMeshCore=true so it sets up the correct state listener
      final nodeIdHex = result.deviceInfo?.nodeId ?? '0';
      final nodeNumParsed = int.tryParse(nodeIdHex, radix: 16);
      deviceConnectionNotifier.markAsPaired(
        device,
        nodeNumParsed,
        isMeshCore: true,
      );

      // Clear userDisconnected flag
      userDisconnectedNotifier.setUserDisconnected(false);
      deviceConnectionNotifier.clearUserDisconnected();

      // Reset auto-reconnect state
      autoReconnectNotifier.setState(AutoReconnectState.idle);

      // CRITICAL: Invalidate linkStatusProvider to force UI rebuild.
      // This ensures activeProtocolProvider sees MeshCore as connected
      // and AppRootShell routes to MeshCoreShell instead of MainShell.
      ref.invalidate(linkStatusProvider);

      AppLogging.connection(
        '📡 SCANNER: MeshCore connected successfully: ${result.deviceInfo?.displayName}',
      );

      safeSetState(() {
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
        _navigateToMain();
      }
      // If inline, don't navigate - let connection state trigger rebuild
    } catch (e, stack) {
      AppLogging.connection('📡 SCANNER: MeshCore connection error: $e');
      FirebaseCrashlytics.instance.recordError(e, stack);

      if (!mounted) return;

      safeSetState(() {
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

    // Capture providers BEFORE any await
    final transport = ref.read(transportProvider);
    final connectedDeviceNotifier = ref.read(connectedDeviceProvider.notifier);
    final settingsAsync = ref.read(settingsServiceProvider);
    final settingsFuture = ref.read(settingsServiceProvider.future);
    final protocol = ref.read(protocolServiceProvider);
    final locationService = ref.read(locationServiceProvider);
    final deviceConnectionNotifier = ref.read(
      conn.deviceConnectionProvider.notifier,
    );
    final autoReconnectNotifier = ref.read(autoReconnectStateProvider.notifier);
    final appInitNotifier = ref.read(appInitProvider.notifier);
    final offlineQueue = ref.read(offlineQueueProvider);

    safeSetState(() {
      _connecting = true;
      _autoReconnecting = isAutoReconnect;
      _showPairingInvalidationHint = false;
    });

    try {
      AppLogging.connection('📡 SCANNER: Calling transport.connect()...');
      await transport.connect(device);
      AppLogging.connection(
        '📡 SCANNER: transport.connect() returned, state=${transport.state}',
      );

      if (!mounted) return;

      connectedDeviceNotifier.setState(device);

      // Save device for auto-reconnect (with protocol for future reconnect routing)
      final settingsService = settingsAsync.value;
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
      deviceConnectionNotifier.markAsPaired(device, protocol.myNodeNum);

      // Start phone GPS location updates
      // This sends phone GPS to mesh for devices without GPS hardware
      await locationService.startLocationUpdates();

      if (!mounted) return;

      // If onboarding, return the device and let onboarding handle navigation
      if (widget.isOnboarding) {
        Navigator.of(context).pop(device);
        return;
      }

      // ALWAYS check the actual device region - firmware updates can reset it!
      // Don't assume "connected before = region configured" - that's wrong.
      final settings = await settingsFuture;

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
      // These reads are after mounted check and need fresh state, safe with LifecycleSafeMixin
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
        // Navigate to region selection using push (NOT pushReplacement).
        // pushReplacement destroys Scanner from the nav stack, so when
        // RegionSelectionScreen pops after apply, _AppRouter still has
        // appInit == needsScanner → shows Scanner again → "No devices
        // found" even though the device is connected. By using push and
        // awaiting, Scanner stays in the stack and continues its normal
        // post-connection flow (setInitialized / pushReplacementNamed)
        // after RegionSelectionScreen pops.
        //
        // isInitialSetup must be true whenever the device has UNSET region,
        // not just during onboarding. The apply-and-wait flow (with hard
        // timeout) is required because the device will reboot after region
        // is set and the user must stay on-screen until reconnect completes
        // (or the timeout fires and pops optimistically).
        //
        // Use direct MaterialPageRoute to bypass route guard protection —
        // the region save causes device reboot, which momentarily disconnects.
        // Route guard would show "Device Required" screen during this brief
        // disconnect.
        AppLogging.connection(
          '📡 SCANNER: Region UNSET — pushing RegionSelectionScreen '
          '(isInitialSetup=true, isOnboarding=${widget.isOnboarding})',
        );
        // CRITICAL: Clear manualConnecting BEFORE pushing RegionSelection.
        // The region apply causes a device reboot (expected disconnect).
        // The autoReconnectManager needs to handle that reconnect, but it
        // checks autoReconnectState and blocks when manualConnecting is
        // set. Scanner's manual connection is done at this point — the
        // device is paired, protocol configured, region is the only
        // remaining step. Hand off reconnect responsibility to the
        // auto-reconnect manager so the reboot-reconnect cycle works.
        autoReconnectNotifier.setState(AutoReconnectState.idle);
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) =>
                const RegionSelectionScreen(isInitialSetup: true),
          ),
        );
        // RegionSelectionScreen popped — region is now applied (or timed
        // out optimistically). Fall through to the normal post-connection
        // navigation below to transition to MainShell.
        if (!mounted) return;
        AppLogging.connection(
          '📡 SCANNER: RegionSelectionScreen returned — transitioning to MainShell',
        );
        if (isFromNeedsScanner) {
          appInitNotifier.setInitialized();
        } else if (!widget.isInline) {
          _navigateToMain();
        }
      } else if (needsRegionSetup) {
        AppLogging.app(
          'REGION_FLOW choose=${regionState.regionChoice?.name ?? "null"} session=$sessionId status=${regionState.applyStatus.name} reason=region_picker_suppressed',
        );
        // Keep user on main flow; require explicit reconnect to retry
        if (isFromNeedsScanner) {
          appInitNotifier.setInitialized();
        } else if (!widget.isInline) {
          _navigateToMain();
        }
      } else if (isFromNeedsScanner) {
        // We're at the root level from needsScanner - update app state to initialized
        // This will cause _AppRouter to show MainShell
        appInitNotifier.setInitialized();
      } else if (!widget.isInline) {
        // Navigate to main app (only if not inline - inline will auto-rebuild)
        _navigateToMain();
      }
      // If inline (shown within MainShell), don't navigate - just let the
      // connection state change trigger MainShell to rebuild and show main content

      // Reset auto-reconnect state to idle on successful manual connection
      // This clears any previous failed state from auto-reconnect attempts
      autoReconnectNotifier.setState(AutoReconnectState.idle);

      // Ensure offline queue is initialized and process any pending messages
      offlineQueue.processQueueIfNeeded();

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

      // CRITICAL: Do NOT clear manualConnecting here. The transport may
      // still be firing state transitions (error → disconnecting →
      // disconnected) asynchronously. If we set autoReconnectState to
      // idle now, the auto-reconnect manager sees idle + disconnected +
      // saved device ID and starts _performReconnect — which races with
      // the user's ability to manually retry from this Scanner screen.
      //
      // manualConnecting stays set, which blocks the auto-reconnect
      // manager. It is cleared:
      //  - On the next successful connection (success path above)
      //  - When the user taps another device (_connect sets it again)
      //  - In Scanner.dispose() when this screen closes
      //
      // For auto-reconnect paths (isAutoReconnect == true), the state
      // is not manualConnecting so this is a no-op either way.
      AppLogging.connection(
        '📡 SCANNER: _connectToDevice error — keeping autoReconnectState '
        'as-is to prevent background reconnect race '
        '(isAutoReconnect=$isAutoReconnect)',
      );
      AppErrorHandler.addBreadcrumb(
        'Scanner: connect error, race guard active '
        '(isAutoReconnect=$isAutoReconnect, err=${e.runtimeType})',
      );

      // Only reset connecting state on error
      safeSetState(() {
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
                  StatusBanner.custom(
                    color: Colors.orange,
                    title: '$_savedDeviceNotFoundName not found',
                    subtitle:
                        'If another app is connected to this device, disconnect from it first. Only one app can use Bluetooth at a time.',
                    margin: const EdgeInsets.only(bottom: 16),
                    onDismiss: () =>
                        setState(() => _savedDeviceNotFoundName = null),
                  ),

                // Info banner when auto-reconnect is disabled
                if (_showAutoReconnectDisabledHint)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: context.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.accentColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.bluetooth_disabled,
                          color: context.accentColor,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Auto-reconnect is disabled',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _savedDeviceName != null
                                    ? 'Select "$_savedDeviceName" below, or enable auto-reconnect.'
                                    : 'Select a device below to connect manually.',
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch.adaptive(
                          value: false,
                          activeColor: context.accentColor,
                          onChanged: (value) async {
                            if (value) {
                              // Ask for confirmation before enabling
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Enable Auto-Reconnect?'),
                                  content: Text(
                                    _savedDeviceName != null
                                        ? 'This will automatically connect to "$_savedDeviceName" now and whenever you open the app.'
                                        : 'This will automatically connect to your last used device whenever you open the app.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Enable'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true && mounted) {
                                // Enable auto-reconnect and trigger reconnection
                                final settings = await ref.read(
                                  settingsServiceProvider.future,
                                );
                                await settings.setAutoReconnect(true);
                                if (!mounted) return;
                                setState(
                                  () => _showAutoReconnectDisabledHint = false,
                                );
                                // Trigger auto-reconnect attempt
                                _tryAutoReconnect();
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                if (_errorMessage != null)
                  StatusBanner.error(
                    title: _errorMessage!,
                    margin: const EdgeInsets.only(bottom: 16),
                    onDismiss: () => setState(() {
                      _errorMessage = null;
                      _showPairingInvalidationHint = false;
                    }),
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
                  StatusBanner.accent(
                    title: 'Scanning for nearby devices',
                    subtitle: _devices.isEmpty
                        ? 'Looking for Meshtastic devices...'
                        : '${_devices.length} ${_devices.length == 1 ? 'device' : 'devices'} found so far',
                    isLoading: true,
                    margin: const EdgeInsets.only(bottom: 16),
                  ),

                // Dev mode toggle: Show all BLE devices
                if (kDebugMode)
                  Consumer(
                    builder: (context, ref, child) {
                      final showAllDevices = ref.watch(
                        showAllBleDevicesProvider,
                      );
                      return StatusBanner.custom(
                        color: Colors.purple,
                        title: 'Show all BLE devices',
                        subtitle: showAllDevices
                            ? 'Scanning all devices (dev mode)'
                            : 'Filtering by Meshtastic UUID',
                        icon: Icons.developer_mode,
                        margin: const EdgeInsets.only(bottom: 16),
                        trailing: Switch.adaptive(
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
              child: Text(
                'Unknown Protocol',
                style: Theme.of(context).textTheme.titleMedium,
              ),
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
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(fontFamily: 'monospace'),
                  ),
                  Text(
                    'Confidence: ${(detection.confidence * 100).toStringAsFixed(0)}%',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This device cannot be connected automatically. '
              'Only Meshtastic and MeshCore devices are supported.',
              style: Theme.of(context).textTheme.bodyMedium,
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
