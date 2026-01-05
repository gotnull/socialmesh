import 'dart:async';

import '../../core/logging.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/transport.dart';
import '../../core/theme.dart';
import '../../core/widgets/connecting_content.dart';
import '../../providers/splash_mesh_provider.dart';
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
      AppLogging.debug(
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
      AppLogging.debug('Failed to load settings service: $e');
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

    AppLogging.debug(
      '🔄 Auto-reconnect: looking for device $lastDeviceId ($lastDeviceType)',
    );

    try {
      // Start scanning to find the last device
      final transport = ref.read(transportProvider);
      final scanStream = transport.scan(timeout: const Duration(seconds: 5));
      DeviceInfo? lastDevice;

      await for (final device in scanStream) {
        if (!mounted) break;
        AppLogging.debug(
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
        AppLogging.debug('🔄 Auto-reconnect: device found, connecting...');
        // Found the device, try to connect
        await _connectToDevice(lastDevice, isAutoReconnect: true);
      } else {
        AppLogging.debug(
          '🔄 Auto-reconnect: device not found, starting regular scan',
        );
        // Device not found, start regular scan
        setState(() {
          _autoReconnecting = false;
        });
        _startScan();
      }
    } catch (e) {
      AppLogging.debug('🔄 Auto-reconnect failed: $e');
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
        // Continue - just ensuring clean state
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
        pbenum.RegionCode? region = protocol.currentRegion;
        AppLogging.debug('🔍 Initial region: ${region?.name ?? "null"}');

        // If region not available yet, wait for loraConfigStream with proper timeout
        // This handles the timing issue where config arrives after our initial check
        if (region == null || region == pbenum.RegionCode.UNSET_REGION) {
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
        if (region == null || region == pbenum.RegionCode.UNSET_REGION) {
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
        // Continue on cleanup errors
      }

      // Also stop any active BLE scan
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {
        // Continue
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
    final statusInfo = _autoReconnecting
        ? ConnectionStatusInfo.autoReconnecting(context.accentColor)
        : ConnectionStatusInfo.connecting(context.accentColor);

    return ConnectingContent(
      statusInfo: statusInfo,
      showMeshNode: true,
      showCancel: _autoReconnecting,
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
                      '© 2025 Socialmesh. All rights reserved.',
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

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        leading: widget.isOnboarding
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: context.textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          widget.isOnboarding ? 'Connect Device' : 'Meshtastic',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
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
                  child: MeshLoadingIndicator(size: 20),
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
                    child: MeshLoadingIndicator(size: 20),
                  ),
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

          if (_devices.isNotEmpty)
            Padding(
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
                    style: TextStyle(fontSize: 14, color: context.textTertiary),
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
                    '© 2025 Socialmesh. All rights reserved.',
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
              border: Border.all(color: context.border),
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
                    color: context.accentColor,
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
                      Text(
                        device.type == TransportType.ble ? 'Bluetooth' : 'USB',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.textTertiary,
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
