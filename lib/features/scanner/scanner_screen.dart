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
    });

    try {
      final transport = ref.read(transportProvider);
      final scanStream = transport.scan(timeout: const Duration(seconds: 10));

      await for (final device in scanStream) {
        if (mounted) {
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Scan error: $e')));
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
    try {
      final transport = ref.read(transportProvider);
      await transport.connect(device);

      ref.read(connectedDeviceProvider.notifier).state = device;

      // Start protocol service
      final protocol = ref.read(protocolServiceProvider);
      protocol.start();

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Connection failed: $e')));
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
                      return ListTile(
                        leading: Icon(
                          device.type == TransportType.ble
                              ? Icons.bluetooth
                              : Icons.usb,
                        ),
                        title: Text(device.name),
                        subtitle: Text(device.address ?? device.id),
                        trailing: device.rssi != null
                            ? Chip(label: Text('${device.rssi} dBm'))
                            : null,
                        onTap: () => _connect(device),
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
