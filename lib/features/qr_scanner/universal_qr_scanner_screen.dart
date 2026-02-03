// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../generated/meshtastic/channel.pb.dart' as channel_pb;
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import '../../services/deep_link/deep_link.dart';
import '../../utils/encoding.dart';
import '../../utils/snackbar.dart';
import '../../utils/text_sanitizer.dart';
import '../channels/channel_form_screen.dart';

/// Universal QR code scanner that handles all Socialmesh QR code types:
/// - Nodes (socialmesh://node/...)
/// - Channels (socialmesh://channel/... or meshtastic.org/e/#...)
/// - Automations (socialmesh://automation/...)
/// - Profiles, widgets, locations, posts
///
/// Uses the deep link parser to identify QR code types and routes accordingly.
class UniversalQrScannerScreen extends ConsumerStatefulWidget {
  const UniversalQrScannerScreen({super.key});

  @override
  ConsumerState<UniversalQrScannerScreen> createState() =>
      _UniversalQrScannerScreenState();
}

class _UniversalQrScannerScreenState
    extends ConsumerState<UniversalQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  String? _lastProcessedCode;

  @override
  void initState() {
    super.initState();
    AppLogging.qr('📷 Universal QR Scanner: Initializing');

    _controller.barcodes.listen(
      (capture) {
        AppLogging.qr('📷 Universal QR Scanner: Barcode stream event');
      },
      onError: (error) {
        AppLogging.qr('📷 Universal QR Scanner ERROR: $error');
      },
    );

    _controller
        .start()
        .then((_) {
          AppLogging.qr('📷 Universal QR Scanner: Camera started');
          if (mounted) setState(() {});
        })
        .catchError((error) {
          AppLogging.qr(
            '📷 Universal QR Scanner ERROR: Failed to start: $error',
          );
        });
  }

  @override
  void dispose() {
    AppLogging.qr('📷 Universal QR Scanner: Disposing');
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null) return;

    // Deduplicate - prevent processing same code multiple times
    if (code == _lastProcessedCode) return;
    _lastProcessedCode = code;

    AppLogging.qr(
      '📷 Universal QR Scanner: Detected ${code.length > 50 ? '${code.substring(0, 50)}...' : code}',
    );

    setState(() => _isProcessing = true);
    _processQrCode(code);
  }

  Future<void> _processQrCode(String code) async {
    try {
      // Use the deep link parser to identify the QR code type
      final parser = const DeepLinkParser();
      final parsed = parser.parse(code);

      AppLogging.qr(
        '📷 Universal QR Scanner: Parsed as ${parsed.type}, valid=${parsed.isValid}',
      );

      if (!parsed.isValid) {
        // Check if it might be a legacy channel format we can handle
        if (code.contains('meshtastic.org/e/#') ||
            (code.startsWith('http') && Uri.parse(code).fragment.isNotEmpty)) {
          await _handleChannelQr(code);
          return;
        }

        throw Exception(
          parsed.validationErrors.isNotEmpty
              ? parsed.validationErrors.first
              : 'Unrecognized QR code format',
        );
      }

      // Route based on type
      switch (parsed.type) {
        case DeepLinkType.node:
          await _handleNodeQr(parsed);
        case DeepLinkType.channel:
          await _handleChannelQr(code);
        case DeepLinkType.automation:
          _handleAutomationQr(parsed);
        case DeepLinkType.profile:
          _handleProfileQr(parsed);
        case DeepLinkType.widget:
          _handleWidgetQr(parsed);
        case DeepLinkType.location:
          _handleLocationQr(parsed);
        case DeepLinkType.post:
          _handlePostQr(parsed);
        case DeepLinkType.invalid:
          throw Exception('Invalid QR code');
      }
    } catch (e) {
      AppLogging.qr('📷 Universal QR Scanner ERROR: $e');
      if (mounted) {
        showErrorSnackBar(context, 'Failed to process QR code: $e');
        setState(() => _isProcessing = false);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Node QR Handling
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _handleNodeQr(ParsedDeepLink parsed) async {
    int? nodeNum = parsed.nodeNum;
    String? longName = parsed.nodeLongName;
    String? shortName = parsed.nodeShortName;
    String? userId = parsed.nodeUserId;
    double? lat = parsed.nodeLatitude;
    double? lon = parsed.nodeLongitude;

    // If we only have a Firestore ID, convert it to nodeNum
    if (nodeNum == null && parsed.nodeFirestoreId != null) {
      final hexPattern = RegExp(r'^[0-9A-Fa-f]{8}$');
      if (hexPattern.hasMatch(parsed.nodeFirestoreId!)) {
        nodeNum = int.parse(parsed.nodeFirestoreId!, radix: 16);
        AppLogging.qr('📷 Converted Firestore ID to nodeNum: $nodeNum');
      } else {
        throw Exception('Invalid node ID format');
      }
    }

    if (nodeNum == null) {
      throw Exception('Missing node number');
    }

    // Check if node already exists
    final existingNodes = ref.read(nodesProvider);
    final existingNode = existingNodes[nodeNum];

    if (existingNode != null) {
      final update = await _showNodeExistsDialog(existingNode, longName);
      if (update == true) {
        await _addOrUpdateNode(
          nodeNum: nodeNum,
          longName: longName,
          shortName: shortName,
          userId: userId,
          lat: lat,
          lon: lon,
        );
      }
    } else {
      final confirmed = await _showAddNodeConfirmation(
        nodeNum: nodeNum,
        longName: longName,
        shortName: shortName,
        userId: userId,
      );
      if (confirmed == true) {
        await _addOrUpdateNode(
          nodeNum: nodeNum,
          longName: longName,
          shortName: shortName,
          userId: userId,
          lat: lat,
          lon: lon,
        );
      }
    }

    if (mounted) setState(() => _isProcessing = false);
  }

  Future<bool?> _showNodeExistsDialog(MeshNode existing, String? newName) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Node Already Exists',
          style: TextStyle(color: context.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This node is already in your list as "${existing.displayName}".',
              style: TextStyle(color: context.textSecondary, fontSize: 14),
            ),
            if (newName != null && newName != existing.longName) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: context.accentColor,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Update name to "$newName" and add to favorites?',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: context.accentColor),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showAddNodeConfirmation({
    required int nodeNum,
    String? longName,
    String? shortName,
    String? userId,
  }) {
    final displayName =
        longName ?? shortName ?? '!${nodeNum.toRadixString(16)}';
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Node', style: TextStyle(color: context.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add "$displayName" to your tracked nodes?',
              style: TextStyle(color: context.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            _buildNodeInfoRow('Node ID', '!${nodeNum.toRadixString(16)}'),
            if (longName != null) _buildNodeInfoRow('Name', longName),
            if (shortName != null) _buildNodeInfoRow('Short', shortName),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: context.accentColor),
            child: const Text('Add Node'),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: context.textPrimary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addOrUpdateNode({
    required int nodeNum,
    String? longName,
    String? shortName,
    String? userId,
    double? lat,
    double? lon,
  }) async {
    final sanitizedLongName = longName != null ? sanitizeUtf16(longName) : null;
    final sanitizedShortName = shortName != null
        ? sanitizeUtf16(shortName)
        : null;

    final existingNodes = ref.read(nodesProvider);
    final existing = existingNodes[nodeNum];

    final node = MeshNode(
      nodeNum: nodeNum,
      longName: sanitizedLongName ?? existing?.longName,
      shortName: sanitizedShortName ?? existing?.shortName,
      userId: userId ?? existing?.userId,
      latitude: lat ?? existing?.latitude,
      longitude: lon ?? existing?.longitude,
      altitude: existing?.altitude,
      isFavorite: true,
      lastHeard: existing?.lastHeard ?? DateTime.now(),
      snr: existing?.snr,
      rssi: existing?.rssi,
      batteryLevel: existing?.batteryLevel,
      firmwareVersion: existing?.firmwareVersion,
      hardwareModel: existing?.hardwareModel,
      role: existing?.role,
      distance: existing?.distance,
      avatarColor: existing?.avatarColor,
      hasPublicKey: existing?.hasPublicKey ?? false,
    );

    ref.read(nodesProvider.notifier).addOrUpdateNode(node);

    if (mounted) {
      Navigator.pop(context);
      showSuccessSnackBar(
        context,
        'Node "${node.displayName}" added to favorites',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Channel QR Handling
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _handleChannelQr(String code) async {
    String base64Data;

    if (code.startsWith('socialmesh://channel/')) {
      base64Data = code.substring('socialmesh://channel/'.length);
    } else if (code.contains('meshtastic.org/e/#')) {
      final hashIndex = code.indexOf('#');
      if (hashIndex == -1 || hashIndex == code.length - 1) {
        throw Exception('Invalid Meshtastic URL format');
      }
      base64Data = Uri.decodeComponent(code.substring(hashIndex + 1));
    } else if (code.startsWith('http')) {
      final uri = Uri.parse(code);
      if (uri.fragment.isEmpty) throw Exception('No channel data in URL');
      base64Data = Uri.decodeComponent(uri.fragment);
    } else {
      throw Exception('Not a recognized channel format');
    }

    if (base64Data.isEmpty) throw Exception('Empty channel data');

    // Decode base64 to bytes
    final bytes = Base64Utils.decodeWithPadding(base64Data);
    AppLogging.qr('📷 Channel QR: Decoded ${bytes.length} bytes');

    // Parse channel settings from protobuf
    ChannelConfig? channel;
    String? channelName;
    List<int>? psk;

    // Try parsing as Channel first
    try {
      final pbChannel = channel_pb.Channel.fromBuffer(bytes);
      if (pbChannel.hasSettings()) {
        channelName = pbChannel.settings.name;
        if (pbChannel.settings.psk.isNotEmpty) {
          psk = pbChannel.settings.psk;
        }
      }
    } catch (_) {}

    // Try parsing as ChannelSettings if needed
    if (psk == null || psk.isEmpty) {
      try {
        final pbSettings = channel_pb.ChannelSettings.fromBuffer(bytes);
        channelName ??= pbSettings.name;
        if (pbSettings.psk.isNotEmpty) psk = pbSettings.psk;
      } catch (_) {}
    }

    // Fallback: treat raw bytes as PSK
    if (psk == null || psk.isEmpty) {
      if (bytes.length == 16 || bytes.length == 32) {
        psk = bytes;
      } else {
        throw Exception('Invalid channel data');
      }
    }

    // Check for duplicate channel
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

    // Find next available slot
    final usedIndices = channels.map((c) => c.index).toSet();
    int newIndex = 1;
    while (usedIndices.contains(newIndex) && newIndex < 8) {
      newIndex++;
    }
    if (newIndex >= 8) throw Exception('Maximum 8 channels - delete one first');

    channel = ChannelConfig(
      index: newIndex,
      name: channelName ?? 'Imported',
      psk: psk,
      uplink: false,
      downlink: false,
      role: 'SECONDARY',
    );

    // Show confirmation
    if (mounted) {
      final result = await _showChannelImportConfirmation(channel);
      if (result == true) {
        await _importChannel(channel);
      } else if (result == false) {
        // User wants to edit first
        if (mounted) {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChannelFormScreen(
                existingChannel: channel,
                channelIndex: channel!.index,
              ),
            ),
          );
        }
        return;
      }
      setState(() => _isProcessing = false);
    }
  }

  Future<bool?> _showChannelImportConfirmation(ChannelConfig channel) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
            _buildChannelInfoRow('Name', channel.name),
            const SizedBox(height: 8),
            _buildChannelInfoRow('Slot', '${channel.index}'),
            const SizedBox(height: 8),
            _buildChannelInfoRow(
              'Encryption',
              '${channel.psk.length * 8}-bit AES',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: context.accentColor,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'The channel will be synced to your connected device.',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.accentColor,
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
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Edit First',
              style: TextStyle(color: context.accentColor),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: context.accentColor),
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelInfoRow(String label, String value) {
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
    final connectionState = ref.read(connectionStateProvider);
    final isConnected = connectionState.maybeWhen(
      data: (state) => state == DeviceConnectionState.connected,
      orElse: () => false,
    );

    if (!isConnected) {
      showErrorSnackBar(context, 'Connect a device to import this channel');
      setState(() => _isProcessing = false);
      return;
    }

    try {
      final protocol = ref.read(protocolServiceProvider);
      await protocol.setChannel(channel);
      await Future.delayed(const Duration(milliseconds: 300));
      await protocol.getChannel(channel.index);

      ref.read(channelsProvider.notifier).setChannel(channel);

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
        setState(() => _isProcessing = false);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Automation QR Handling
  // ─────────────────────────────────────────────────────────────────────────────

  void _handleAutomationQr(ParsedDeepLink parsed) {
    if (mounted) {
      Navigator.pop(context);
      Navigator.pushNamed(
        context,
        '/automation-import',
        arguments: {
          'base64Data': parsed.automationBase64Data,
          'firestoreId': parsed.automationFirestoreId,
        },
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Other QR Types (delegate to deep link routes)
  // ─────────────────────────────────────────────────────────────────────────────

  void _handleProfileQr(ParsedDeepLink parsed) {
    if (mounted) {
      Navigator.pop(context);
      Navigator.pushNamed(
        context,
        '/profile',
        arguments: {'displayName': parsed.profileDisplayName},
      );
    }
  }

  void _handleWidgetQr(ParsedDeepLink parsed) {
    if (mounted) {
      Navigator.pop(context);
      Navigator.pushNamed(
        context,
        '/widget-detail',
        arguments: {'widgetId': parsed.widgetId},
      );
    }
  }

  void _handleLocationQr(ParsedDeepLink parsed) {
    if (mounted) {
      Navigator.pop(context);
      Navigator.pushNamed(
        context,
        '/map',
        arguments: {
          'latitude': parsed.locationLatitude,
          'longitude': parsed.locationLongitude,
          'label': parsed.locationLabel,
        },
      );
    }
  }

  void _handlePostQr(ParsedDeepLink parsed) {
    if (mounted) {
      Navigator.pop(context);
      Navigator.pushNamed(
        context,
        '/post-detail',
        arguments: {'postId': parsed.postId},
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        title: Text(
          'Scan QR Code',
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
              child: const Center(child: LoadingIndicator(size: 48)),
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
                  const SizedBox(height: 12),
                  Text(
                    'Point your camera at a QR code',
                    style: TextStyle(color: context.textPrimary, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Supports nodes, channels, automations, and more',
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
