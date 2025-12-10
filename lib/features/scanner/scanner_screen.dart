import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/transport.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/widgets/animated_tagline.dart';
import '../../utils/snackbar.dart';
import '../../providers/app_providers.dart';
import '../../services/storage/storage_service.dart';
import '../../generated/meshtastic/mesh.pbenum.dart' as pbenum;
import 'widgets/connecting_animation.dart';

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

  @override
  void initState() {
    super.initState();
    // Skip auto-reconnect during onboarding or inline - user needs to select device
    if (widget.isOnboarding || widget.isInline) {
      _startScan();
    } else {
      _tryAutoReconnect();
    }
  }

  Future<void> _tryAutoReconnect() async {
    // Check if auto-reconnect already failed (e.g., user cancelled PIN during app init)
    // In that case, don't retry - just show the scanner
    final autoReconnectState = ref.read(autoReconnectStateProvider);
    if (autoReconnectState == AutoReconnectState.failed) {
      debugPrint(
        '🔄 Auto-reconnect: skipping - already failed during app init',
      );
      _startScan();
      return;
    }

    // Wait for settings service to initialize
    final SettingsService settingsService;
    try {
      settingsService = await ref.read(settingsServiceProvider.future);
    } catch (e) {
      debugPrint('Failed to load settings service: $e');
      _startScan();
      return;
    }

    // Check if auto-reconnect is enabled
    if (!settingsService.autoReconnect) {
      _startScan();
      return;
    }

    final lastDeviceId = settingsService.lastDeviceId;
    final lastDeviceType = settingsService.lastDeviceType;
    final lastDeviceName = settingsService.lastDeviceName;

    if (lastDeviceId == null || lastDeviceType == null) {
      _startScan();
      return;
    }

    if (!mounted) return;

    setState(() {
      _autoReconnecting = true;
    });

    debugPrint(
      '🔄 Auto-reconnect: looking for device $lastDeviceId ($lastDeviceType)',
    );

    try {
      // Start scanning to find the last device
      final transport = ref.read(transportProvider);
      final scanStream = transport.scan(timeout: const Duration(seconds: 5));
      DeviceInfo? lastDevice;

      await for (final device in scanStream) {
        if (!mounted) break;
        debugPrint(
          '🔄 Auto-reconnect: found ${device.id} - checking if matches',
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
        debugPrint('🔄 Auto-reconnect: device found, connecting...');
        // Found the device, try to connect
        await _connectToDevice(lastDevice, isAutoReconnect: true);
      } else {
        debugPrint(
          '🔄 Auto-reconnect: device not found, starting regular scan',
        );
        // Device not found, start regular scan
        setState(() {
          _autoReconnecting = false;
        });
        _startScan();
      }
    } catch (e) {
      debugPrint('🔄 Auto-reconnect failed: $e');
      if (mounted) {
        setState(() {
          _autoReconnecting = false;
        });
        _startScan();
      }
    }
  }

  Future<void> _startScan() async {
    if (_scanning) return;

    setState(() {
      _scanning = true;
      _devices.clear();
      _errorMessage = null;
    });

    try {
      // Clean up any stale BLE state before starting scan
      // This fixes issues where scanner gets stuck after app was backgrounded
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {
        // Ignore errors - just ensuring clean state
      }

      final transport = ref.read(transportProvider);
      final scanStream = transport.scan(timeout: const Duration(seconds: 10));

      await for (final device in scanStream) {
        if (!mounted) break;
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
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        setState(() {
          _errorMessage = message;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _scanning = false;
        });
      }
    }
  }

  Future<void> _connect(DeviceInfo device) async {
    HapticFeedback.mediumImpact();
    await _connectToDevice(device, isAutoReconnect: false);
  }

  Future<void> _connectToDevice(
    DeviceInfo device, {
    required bool isAutoReconnect,
  }) async {
    if (_connecting) {
      return;
    }

    setState(() {
      _connecting = true;
      _autoReconnecting = isAutoReconnect;
    });

    try {
      final transport = ref.read(transportProvider);

      await transport.connect(device);

      if (!mounted) return;

      ref.read(connectedDeviceProvider.notifier).setState(device);

      // Save device for auto-reconnect
      final settingsServiceAsync = ref.read(settingsServiceProvider);
      final settingsService = settingsServiceAsync.value;
      if (settingsService != null) {
        final deviceType = device.type == TransportType.ble ? 'ble' : 'usb';
        await settingsService.setLastDevice(
          device.id,
          deviceType,
          deviceName: device.name,
        );
      }

      // Start protocol service and wait for configuration
      final protocol = ref.read(protocolServiceProvider);
      debugPrint('🟡 Scanner screen - protocol instance: ${protocol.hashCode}');

      // Set device info for hardware model inference (for devices like T1000-E that return UNSET)
      protocol.setDeviceName(device.name);
      protocol.setBleModelNumber(transport.bleModelNumber);
      protocol.setBleManufacturerName(transport.bleManufacturerName);

      await protocol.start();

      // Verify protocol actually received configuration from device
      // If PIN was cancelled or authentication failed, myNodeNum will be null
      if (protocol.myNodeNum == null) {
        debugPrint(
          '🔴 Scanner: No config received - authentication may have failed',
        );
        await transport.disconnect();
        throw Exception(
          'Connection failed - please try again and enter the PIN when prompted',
        );
      }

      // Start phone GPS location updates (like iOS app does)
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

      debugPrint(
        '🔍 Checking device region (always check - firmware may have reset it)...',
      );

      bool needsRegionSetup = false;

      // Always check region from device - firmware updates can reset it
      {
        pbenum.RegionCode? region = protocol.currentRegion;
        debugPrint('🔍 Initial region: ${region?.name ?? "null"}');

        // If region not available yet, wait for loraConfigStream with proper timeout
        // This handles the timing issue where config arrives after our initial check
        if (region == null || region == pbenum.RegionCode.UNSET_REGION) {
          debugPrint('🔍 Waiting for LoRa config stream...');
          try {
            // Subscribe to stream FIRST, then request config
            final configFuture = protocol.loraConfigStream.first.timeout(
              const Duration(seconds: 8),
              onTimeout: () {
                debugPrint('⏱️ LoRa config timeout');
                throw TimeoutException('LoRa config timeout');
              },
            );

            // Request LoRa config
            await protocol.getLoRaConfig();

            // Wait for response
            final loraConfig = await configFuture;
            region = loraConfig.region;
            debugPrint('✅ Received LoRa config - region: ${region.name}');
          } catch (e) {
            debugPrint('⚠️ Error getting LoRa config: $e');
            // Fall back to checking currentRegion one more time
            region = protocol.currentRegion;
            debugPrint('🔍 Fallback region: ${region?.name ?? "null"}');
          }
        }

        debugPrint('📍 Final region decision: ${region?.name ?? "null"}');

        // Need region setup if region is UNSET (not configured on device)
        // This can happen on fresh install OR after firmware update/reset
        if (region == null || region == pbenum.RegionCode.UNSET_REGION) {
          needsRegionSetup = true;
          debugPrint('⚠️ Region is UNSET - need to configure!');
        } else {
          // Device has a valid region - mark as configured
          await settings.setRegionConfigured(true);
          debugPrint('✅ Region ${region.name} detected, marked as configured');
        }
      }

      if (!mounted) return;

      // Check current app state - if we're shown from needsScanner, update provider
      final appState = ref.read(appInitProvider);
      final isFromNeedsScanner = appState == AppInitState.needsScanner;

      if (needsRegionSetup) {
        // Navigate to region selection (initial setup mode)
        Navigator.of(context).pushReplacementNamed('/region-setup');
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
    } catch (e) {
      if (!mounted) return;

      // Force cleanup on error to ensure clean state for retry
      try {
        final transport = ref.read(transportProvider);
        await transport.disconnect();
      } catch (_) {
        // Ignore cleanup errors
      }

      // Also stop any active BLE scan
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {
        // Ignore
      }

      if (!mounted) return;

      final message = e.toString().replaceFirst('Exception: ', '');

      if (!isAutoReconnect) {
        showErrorSnackBar(context, message);
      }

      // Only reset connecting state on error
      setState(() {
        _connecting = false;
        _autoReconnecting = false;
      });

      // If auto-reconnect failed, start regular scan
      if (isAutoReconnect) {
        _startScan();
      }
    }
  }

  Widget _buildConnectingContent() {
    final statusText = _autoReconnecting ? 'Auto-reconnecting' : 'Connecting';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset(AssetPaths.appIcon, width: 120, height: 120),
        ),
        const SizedBox(height: 32),
        const Text(
          'Socialmesh',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        const AnimatedTagline(taglines: appTaglines),
        const SizedBox(height: 48),
        // Status indicator
        SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    context.accentColor.withValues(alpha: 0.4),
                  ),
                ),
              ),
              Icon(
                Icons.bluetooth_connected_rounded,
                color: context.accentColor,
                size: 24,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          statusText,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: context.accentColor,

            letterSpacing: 0.3,
          ),
        ),
        if (_autoReconnecting) ...[
          const SizedBox(height: 24),
          TextButton(
            onPressed: () {
              setState(() {
                _connecting = false;
                _autoReconnecting = false;
              });
              _startScan();
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 16),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // When connecting, use EXACT same structure as onboarding
    if (_connecting) {
      return Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: Stack(
          children: [
            // Background - EXACT same as onboarding
            Positioned.fill(child: FloatingIconsBackground()),
            // Content in SafeArea - EXACT same as onboarding
            SafeArea(child: Center(child: _buildConnectingContent())),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        leading: widget.isOnboarding
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          widget.isOnboarding ? 'Connect Device' : 'Meshtastic',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          if (_scanning)
            const SizedBox(
              width: 48,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                  const Icon(Icons.error_outline, color: AppTheme.errorRed),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppTheme.errorRed),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppTheme.errorRed),
                    onPressed: () => setState(() => _errorMessage = null),
                    iconSize: 20,
                  ),
                ],
              ),
            ),

          if (_scanning)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: context.accentColor,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Scanning for nearby devices',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _devices.isEmpty
                              ? 'Looking for Meshtastic devices...'
                              : '${_devices.length} ${_devices.length == 1 ? 'device' : 'devices'} found so far',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          if (_devices.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Text(
                    'Available Devices',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,

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
                      '${_devices.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.accentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (_devices.isEmpty && !_scanning)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 100),
                  const Icon(
                    Icons.bluetooth_searching,
                    size: 80,
                    color: AppTheme.textTertiary,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No devices found',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Make sure Bluetooth is enabled and\nyour Meshtastic device is powered on',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textTertiary,
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
            ..._devices.map(
              (device) => Column(
                children: [
                  _DeviceCard(device: device, onTap: () => _connect(device)),
                  if (device.rssi != null) _DeviceDetailsTable(device: device),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final DeviceInfo device;
  final VoidCallback onTap;

  const _DeviceCard({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final signalBars = _calculateSignalBars(device.rssi);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: context.accentColor.withValues(alpha: 0.2),
          highlightColor: context.accentColor.withValues(alpha: 0.1),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    device.type == TransportType.ble
                        ? Icons.bluetooth
                        : Icons.usb,
                    color: context.accentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        device.type == TransportType.ble ? 'Bluetooth' : 'USB',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textTertiary,
                        ),
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
                                : AppTheme.textTertiary.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
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

class _DeviceDetailsTable extends StatelessWidget {
  final DeviceInfo device;

  const _DeviceDetailsTable({required this.device});

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
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 16, top: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
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
                color: isOdd
                    ? const Color(0xFF29303D)
                    : AppTheme.darkBackground,
                border: Border(
                  bottom: index < details.length - 1
                      ? const BorderSide(color: AppTheme.darkBorder, width: 1)
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
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: AppTheme.darkBorder,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Text(
                          item.$1,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textTertiary,

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
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
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
