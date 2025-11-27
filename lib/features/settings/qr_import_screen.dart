import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:logger/logger.dart';
import '../../providers/app_providers.dart';
import '../../models/mesh_models.dart';
import '../../generated/meshtastic/mesh.pb.dart' as pb;

class QrImportScreen extends ConsumerStatefulWidget {
  const QrImportScreen({super.key});

  @override
  ConsumerState<QrImportScreen> createState() => _QrImportScreenState();
}

class _QrImportScreenState extends ConsumerState<QrImportScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final Logger _logger = Logger();
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null) return;

    setState(() {
      _isProcessing = true;
    });

    _processQrCode(code);
  }

  Future<void> _processQrCode(String code) async {
    try {
      // Meshtastic QR codes typically contain base64-encoded channel config
      // Format: "https://meshtastic.org/e/#<base64data>"
      // or just the base64 data directly

      String? base64Data;
      if (code.startsWith('https://meshtastic.org/e/#')) {
        base64Data = code.substring('https://meshtastic.org/e/#'.length);
      } else if (code.startsWith('http')) {
        // Try to extract from URL
        final uri = Uri.parse(code);
        base64Data = uri.fragment;
      } else {
        // Assume it's raw base64
        base64Data = code;
      }

      if (base64Data.isEmpty) {
        throw Exception('Invalid QR code format');
      }

      // Decode base64
      final bytes = base64Decode(base64Data);

      ChannelConfig channel;
      try {
        // Try parsing as protobuf ChannelSettings
        final pbChannel = pb.Channel.fromBuffer(bytes);
        channel = ChannelConfig(
          index: pbChannel.index,
          name: pbChannel.hasSettings()
              ? pbChannel.settings.name
              : 'Imported Channel',
          psk: pbChannel.hasSettings() ? pbChannel.settings.psk : bytes,
          uplink: pbChannel.hasSettings()
              ? pbChannel.settings.uplinkEnabled
              : true,
          downlink: pbChannel.hasSettings()
              ? pbChannel.settings.downlinkEnabled
              : true,
        );
      } catch (e) {
        // If protobuf parsing fails, treat as raw PSK
        _logger.w('Failed to parse as protobuf, using raw PSK: $e');
        channel = ChannelConfig(index: 0, name: 'Imported Channel', psk: bytes);
      }

      // Store the channel key
      final secureStorage = ref.read(secureStorageProvider);
      await secureStorage.storeChannelKey(channel.name, channel.psk);

      // Update channels
      ref.read(channelsProvider.notifier).setChannel(channel);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Channel "${channel.name}" imported')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to import: $e')));
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Channel QR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black54,
              child: const Text(
                'Point your camera at a Meshtastic channel QR code',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
