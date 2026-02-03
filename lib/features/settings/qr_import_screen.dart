// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/logging.dart';
import '../../providers/app_providers.dart';
import '../../models/mesh_models.dart';
import '../../core/transport.dart';
import '../../generated/meshtastic/channel.pb.dart' as channel_pb;
import '../../core/theme.dart';
import '../../utils/snackbar.dart';
import '../../utils/encoding.dart';
import '../channels/channel_form_screen.dart';
import '../../core/widgets/loading_indicator.dart';

class QrImportScreen extends ConsumerStatefulWidget {
  const QrImportScreen({super.key});

  @override
  ConsumerState<QrImportScreen> createState() => _QrImportScreenState();
}

class _QrImportScreenState extends ConsumerState<QrImportScreen> {
  late final MobileScannerController _controller;
  bool _isProcessing = false;
  bool _checkedRouteArgs = false;
  String? _lastProcessedCode;

  @override
  void initState() {
    super.initState();
    AppLogging.qr('QR Import Scanner: initState - initializing');

    // Create controller - autoStart defaults to true
    _controller = MobileScannerController();

    // Listen to barcode stream for debugging
    _controller.barcodes.listen(
      (capture) {
        AppLogging.qr(
          'QR Import Scanner: Barcode stream - ${capture.barcodes.length} codes',
        );
      },
      onError: (error) {
        AppLogging.qr('QR Import Scanner ERROR: $error');
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check for route arguments (from deep link)
    if (!_checkedRouteArgs) {
      _checkedRouteArgs = true;
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['base64Data'] != null) {
        final base64Data = args['base64Data'] as String;
        AppLogging.qr('QR Import: Received base64Data from deep link');
        // Process in next frame to avoid build-time navigation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _processBase64Channel(base64Data);
          }
        });
      }
    }
  }

  /// Process channel data received from deep link (not from scanner)
  Future<void> _processBase64Channel(String base64Data) async {
    setState(() {
      _isProcessing = true;
    });
    // Construct the full URL format and process
    await _processQrCode('socialmesh://channel/$base64Data');
  }

  void _handleBarcodeCapture(BarcodeCapture capture) {
    if (_isProcessing) {
      AppLogging.qr('QR Import Scanner: Already processing, ignoring');
      return;
    }

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) {
      AppLogging.qr('QR Import Scanner: No barcodes in capture');
      return;
    }

    final String? code = barcodes.first.rawValue;
    if (code == null) {
      AppLogging.qr('QR Import Scanner: Barcode rawValue is null');
      return;
    }

    // Skip if we already processed this exact code
    if (code == _lastProcessedCode) {
      return;
    }
    _lastProcessedCode = code;

    AppLogging.qr(
      'QR Import Scanner: Detected code: ${code.substring(0, code.length > 50 ? 50 : code.length)}...',
    );

    setState(() {
      _isProcessing = true;
    });

    _processQrCode(code);
  }

  @override
  void dispose() {
    AppLogging.qr('QR Import Scanner: dispose - stopping camera');
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    AppLogging.qr('QR Import Scanner: onDetect callback triggered');
    _handleBarcodeCapture(capture);
  }

  Future<void> _processQrCode(String code) async {
    try {
      AppLogging.qr('Processing QR code: $code');

      // Check for automation QR codes first - hand off to deep link system
      if (code.startsWith('socialmesh://automation/')) {
        final base64Data = code.substring('socialmesh://automation/'.length);
        AppLogging.qr('Detected automation QR code, navigating to import');
        if (mounted) {
          Navigator.pop(context); // Close scanner
          Navigator.pushNamed(
            context,
            '/automation-import',
            arguments: {'base64Data': base64Data},
          );
        }
        return;
      }

      // Channel QR codes format: "socialmesh://channel/<base64data>"
      // Also supports legacy formats:
      //   - "https://meshtastic.org/e/#<url-encoded-base64data>"
      //   - Other HTTP URLs with fragment

      String base64Data;
      if (code.startsWith('socialmesh://channel/')) {
        // Socialmesh native format
        base64Data = code.substring('socialmesh://channel/'.length);
      } else if (code.contains('meshtastic.org/e/#')) {
        // Legacy Meshtastic format - extract the fragment after #
        final hashIndex = code.indexOf('#');
        if (hashIndex == -1 || hashIndex == code.length - 1) {
          throw Exception('Invalid Meshtastic URL format');
        }
        // URL decode the base64 data (it may have + encoded as %2B, etc.)
        base64Data = Uri.decodeComponent(code.substring(hashIndex + 1));
      } else if (code.startsWith('http')) {
        // Try to extract from URL fragment
        final uri = Uri.parse(code);
        if (uri.fragment.isEmpty) {
          throw Exception('No channel data in URL');
        }
        base64Data = Uri.decodeComponent(uri.fragment);
      } else {
        // Not a recognized format - show helpful error
        AppLogging.qr('Unrecognized QR format: $code');
        if (mounted) {
          showErrorSnackBar(
            context,
            'Not a Meshtastic channel QR code. Scan a channel QR from the Meshtastic app.',
          );
          setState(() {
            _isProcessing = false;
          });
        }
        return;
      }

      AppLogging.qr('Decoded base64 data: $base64Data');

      if (base64Data.isEmpty) {
        throw Exception('Empty channel data');
      }

      // Decode base64 to bytes (handles both standard and URL-safe, with/without padding)
      final bytes = Base64Utils.decodeWithPadding(base64Data);
      AppLogging.qr('Decoded ${bytes.length} bytes');

      // Try to parse as different protobuf formats
      ChannelConfig? channel;
      String? channelName;
      List<int>? psk;

      // Try parsing as Channel first
      try {
        final pbChannel = channel_pb.Channel.fromBuffer(bytes);
        AppLogging.qr(
          'Parsed as Channel: index=${pbChannel.index}, hasSettings=${pbChannel.hasSettings()}',
        );

        if (pbChannel.hasSettings()) {
          final settings = pbChannel.settings;
          channelName = settings.name.isNotEmpty ? settings.name : null;
          psk = settings.psk.isNotEmpty ? settings.psk : null;

          AppLogging.qr(
            'Channel settings: name="$channelName", psk length=${psk?.length ?? 0}',
          );
        }
      } catch (e) {
        AppLogging.qr('⚠️ Failed to parse as Channel: $e');
      }

      // Try parsing as ChannelSettings if Channel parsing failed or had no PSK
      if (psk == null || psk.isEmpty) {
        try {
          final pbSettings = channel_pb.ChannelSettings.fromBuffer(bytes);
          AppLogging.qr(
            'Parsed as ChannelSettings: name="${pbSettings.name}", psk length=${pbSettings.psk.length}',
          );

          if (pbSettings.psk.isNotEmpty) {
            channelName = pbSettings.name.isNotEmpty ? pbSettings.name : null;
            psk = pbSettings.psk;
          }
        } catch (e) {
          AppLogging.qr('⚠️ Failed to parse as ChannelSettings: $e');
        }
      }

      // If still no PSK, treat the raw bytes as the PSK (legacy format)
      if (psk == null || psk.isEmpty) {
        AppLogging.qr('Using raw bytes as PSK (${bytes.length} bytes)');
        // Validate PSK length (should be 16 or 32 bytes for AES)
        if (bytes.length == 16 || bytes.length == 32) {
          psk = bytes;
        } else {
          throw Exception(
            'Invalid key length: ${bytes.length} bytes (expected 16 or 32)',
          );
        }
      }

      // Check for duplicate channel (same PSK already exists)
      final channels = ref.read(channelsProvider);
      final existingChannel = channels.where((c) {
        if (c.psk.length != psk!.length) return false;
        for (int i = 0; i < c.psk.length; i++) {
          if (c.psk[i] != psk[i]) return false;
        }
        return true;
      }).firstOrNull;

      if (existingChannel != null) {
        if (mounted) {
          Navigator.pop(context);
          showInfoSnackBar(
            context,
            'You already have this channel as "${existingChannel.name}"',
          );
        }
        return;
      }

      // Find next available channel index
      final usedIndices = channels.map((c) => c.index).toSet();
      int newIndex = 1; // Start from 1 (0 is primary)
      while (usedIndices.contains(newIndex) && newIndex < 8) {
        newIndex++;
      }
      if (newIndex >= 8) {
        throw Exception('Maximum 8 channels - delete one first');
      }

      // Create channel config
      channel = ChannelConfig(
        index: newIndex,
        name: channelName ?? 'Imported',
        psk: psk,
        uplink: false,
        downlink: false,
        role: 'SECONDARY',
      );

      AppLogging.qr(
        'Created channel: index=${channel.index}, name="${channel.name}", psk=${channel.psk.length} bytes',
      );

      // Show confirmation dialog with option to edit
      if (mounted) {
        final confirmed = await _showImportConfirmation(channel);
        if (confirmed == true) {
          await _importChannel(channel);
        } else if (confirmed == false) {
          // User wants to edit - navigate to form
          if (mounted) {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChannelFormScreen(
                  existingChannel: channel,
                  channelIndex: channel!.index,
                ),
              ),
            );
          }
          return;
        }
        // null = cancelled, just reset processing state
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      AppLogging.qr('⚠️ QR import error: $e');
      if (mounted) {
        showErrorSnackBar(context, 'Failed to import: $e');
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<bool?> _showImportConfirmation(ChannelConfig channel) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Import Channel',
          style: TextStyle(color: context.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Name', channel.name),
            SizedBox(height: 8),
            _buildInfoRow('Slot', '${channel.index}'),
            const SizedBox(height: 8),
            _buildInfoRow('Encryption', '${channel.psk.length * 8}-bit AES'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentOrange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.accentOrange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.restart_alt,
                    color: AppTheme.accentOrange,
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Device will reboot after import. The app will automatically reconnect.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.accentOrange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Edit First',
              style: TextStyle(color: context.accentColor),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: context.accentColor),
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(color: context.textSecondary, fontSize: 14),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _importChannel(ChannelConfig channel) async {
    // Check connection state before importing
    final connectionState = ref.read(connectionStateProvider);
    final isConnected = connectionState.maybeWhen(
      data: (state) => state == DeviceConnectionState.connected,
      orElse: () => false,
    );

    if (!isConnected) {
      showErrorSnackBar(context, 'Cannot import channel: Device not connected');
      setState(() {
        _isProcessing = false;
      });
      return;
    }

    try {
      // Sync to device first - this must succeed
      final protocol = ref.read(protocolServiceProvider);
      await protocol.setChannel(channel);
      await Future.delayed(const Duration(milliseconds: 300));
      await protocol.getChannel(channel.index);

      // Update local state only after successful device sync
      ref.read(channelsProvider.notifier).setChannel(channel);

      // Store key securely
      if (channel.psk.isNotEmpty) {
        final secureStorage = ref.read(secureStorageProvider);
        await secureStorage.storeChannelKey(channel.name, channel.psk);
      }

      if (mounted) {
        showSuccessSnackBar(context, 'Channel "${channel.name}" imported');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Import failed: $e');
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        title: Text(
          'Scan Channel QR',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.flash_on, color: context.textPrimary),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: Icon(Icons.flip_camera_ios, color: context.textPrimary),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Scanner overlay
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: context.accentColor.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: Center(child: LoadingIndicator(size: 48)),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    context.background.withValues(alpha: 0.9),
                    context.background,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    size: 32,
                    color: context.accentColor,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Point your camera at a Meshtastic channel QR code',
                    style: TextStyle(color: context.textPrimary, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'The channel will be automatically imported',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
