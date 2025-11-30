import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/transport.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../services/storage/storage_service.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  final bool isOnboarding;

  const ScannerScreen({super.key, this.isOnboarding = false});

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
    // Skip auto-reconnect during onboarding - user needs to select device
    if (widget.isOnboarding) {
      _startScan();
    } else {
      _tryAutoReconnect();
    }
  }

  Future<void> _tryAutoReconnect() async {
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
          lastDevice = device;
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

      ref.read(connectedDeviceProvider.notifier).state = device;

      // Save device for auto-reconnect
      final settingsServiceAsync = ref.read(settingsServiceProvider);
      final settingsService = settingsServiceAsync.valueOrNull;
      if (settingsService != null) {
        final deviceType = device.type == TransportType.ble ? 'ble' : 'usb';
        await settingsService.setLastDevice(device.id, deviceType);
      }

      // Start protocol service and wait for configuration
      final protocol = ref.read(protocolServiceProvider);
      debugPrint('🟡 Scanner screen - protocol instance: ${protocol.hashCode}');
      await protocol.start();

      if (!mounted) return;

      // If onboarding, return the device and let onboarding handle navigation
      if (widget.isOnboarding) {
        Navigator.of(context).pop(device);
        return;
      }

      // Request LoRa config to check region
      protocol.getLoRaConfig();

      // Wait a moment for the response
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      // Check if region is unset - need to configure before using
      final region = protocol.currentRegion;
      if (region == null || region.value == 0) {
        // Navigate to region selection (initial setup mode)
        Navigator.of(context).pushReplacementNamed('/region-setup');
      } else {
        // Navigate to main app
        Navigator.of(context).pushReplacementNamed('/main');
      }
    } catch (e) {
      if (!mounted) return;

      final message = e.toString().replaceFirst('Exception: ', '');

      if (!isAutoReconnect) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 6),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
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
  }

  @override
  Widget build(BuildContext context) {
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
        actions: widget.isOnboarding
            ? null
            : [
                IconButton(
                  icon: Icon(
                    Icons.bluetooth,
                    color: _connecting
                        ? AppTheme.textTertiary
                        : AppTheme.textSecondary,
                  ),
                  onPressed: _connecting ? null : () {},
                ),
                IconButton(
                  icon: Icon(
                    Icons.settings,
                    color: _connecting ? AppTheme.textTertiary : Colors.white,
                  ),
                  onPressed: _connecting
                      ? null
                      : () {
                          Navigator.of(context).pushNamed('/settings');
                        },
                ),
              ],
      ),
      body: _connecting
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppTheme.primaryGreen),
                  const SizedBox(height: 16),
                  Text(
                    _autoReconnecting
                        ? 'Auto-reconnecting...'
                        : 'Connecting...',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (_autoReconnecting) ...[
                    const SizedBox(height: 8),
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
                        style: TextStyle(color: AppTheme.textTertiary),
                      ),
                    ),
                  ],
                ],
              ),
            )
          : ListView(
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
                          icon: const Icon(
                            Icons.close,
                            color: AppTheme.errorRed,
                          ),
                          onPressed: () => setState(() => _errorMessage = null),
                          iconSize: 20,
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
                      color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryGreen,
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
                                  fontFamily: 'Inter',
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
                                  fontFamily: 'Inter',
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
                            fontFamily: 'Inter',
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_devices.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryGreen,
                              fontFamily: 'Inter',
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
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Make sure Bluetooth is enabled and\nyour Meshtastic device is powered on',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textTertiary,
                            fontFamily: 'Inter',
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
                        _DeviceCard(
                          device: device,
                          onTap: () => _connect(device),
                        ),
                        if (device.rssi != null)
                          _DeviceDetailsTable(device: device),
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
          splashColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
          highlightColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
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
                    color: AppTheme.primaryGreen,
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
                                ? AppTheme.primaryGreen
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
                            fontFamily: 'Inter',
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
                            fontFamily: 'Inter',
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
