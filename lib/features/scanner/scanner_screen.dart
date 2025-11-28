import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/transport.dart';
import '../../providers/app_providers.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final List<DeviceInfo> _devices = [];
  bool _scanning = false;
  bool _connecting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startScan();
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
    if (_connecting) {
      return;
    }

    setState(() {
      _connecting = true;
    });

    try {
      final transport = ref.read(transportProvider);

      await transport.connect(device);

      if (!mounted) return;

      ref.read(connectedDeviceProvider.notifier).state = device;

      // Start protocol service and wait for configuration
      final protocol = ref.read(protocolServiceProvider);
      await protocol.start();

      if (!mounted) return;

      // Navigate to dashboard
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } catch (e) {
      if (!mounted) return;

      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 6),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _connecting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final transportType = ref.watch(transportTypeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Device'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).pushNamed('/settings');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Transport type selector
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SegmentedButton<TransportType>(
              segments: const [
                ButtonSegment(
                  value: TransportType.ble,
                  label: Text('Bluetooth'),
                  icon: Icon(Icons.bluetooth),
                ),
                ButtonSegment(
                  value: TransportType.usb,
                  label: Text('USB'),
                  icon: Icon(Icons.usb),
                ),
              ],
              selected: {transportType},
              onSelectionChanged: (Set<TransportType> newSelection) {
                ref.read(transportTypeProvider.notifier).state =
                    newSelection.first;
                _startScan();
              },
            ),
          ),

          // Error banner
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.errorContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        onPressed: () {
                          setState(() {
                            _errorMessage = null;
                          });
                        },
                      ),
                    ],
                  ),
                  if (_errorMessage!.toLowerCase().contains('bluetooth'))
                    Padding(
                      padding: const EdgeInsets.only(left: 36, top: 8),
                      child: Text(
                        'Go to Settings > Bluetooth and ensure it is turned on',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Device list
          Expanded(
            child: _devices.isEmpty && !_scanning
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.devices,
                          size: 64,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(height: 16),
                        const Text('No devices found'),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _startScan,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Scan Again'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      final isConnecting = _connecting;

                      return ListTile(
                        enabled: !isConnecting,
                        leading: Icon(
                          device.type == TransportType.ble
                              ? Icons.bluetooth
                              : Icons.usb,
                        ),
                        title: Text(device.name),
                        subtitle: Text(
                          isConnecting
                              ? 'Connecting...'
                              : (device.address ?? device.id),
                        ),
                        trailing: isConnecting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : (device.rssi != null
                                  ? Chip(label: Text('${device.rssi} dBm'))
                                  : null),
                        onTap: isConnecting ? null : () => _connect(device),
                      );
                    },
                  ),
          ),

          // Scanning indicator
          if (_scanning) const LinearProgressIndicator(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scanning ? null : _startScan,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
