// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../providers/app_providers.dart';
import '../../models/mesh_models.dart';
import '../../core/theme.dart';
import '../../core/logging.dart';
import '../../utils/encoding.dart';
import '../../utils/snackbar.dart';
import '../../utils/text_sanitizer.dart';
import '../../core/widgets/loading_indicator.dart';

class NodeQrScannerScreen extends ConsumerStatefulWidget {
  const NodeQrScannerScreen({super.key});

  @override
  ConsumerState<NodeQrScannerScreen> createState() =>
      _NodeQrScannerScreenState();
}

class _NodeQrScannerScreenState extends ConsumerState<NodeQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  String? _lastProcessedCode;

  @override
  void initState() {
    super.initState();
    AppLogging.qr(
      '📷 QR SCANNER: initState - initializing MobileScannerController',
    );

    // Listen to controller events
    _controller.barcodes.listen(
      (capture) {
        AppLogging.qr('📷 QR SCANNER: Barcode stream event received');
      },
      onError: (error) {
        AppLogging.qr('📷 QR SCANNER ERROR: Barcode stream error: $error');
      },
    );

    _controller
        .start()
        .then((_) {
          AppLogging.qr('📷 QR SCANNER: Camera started successfully');
          if (mounted) {
            setState(() {}); // Trigger rebuild to show camera
          }
        })
        .catchError((error) {
          AppLogging.qr('📷 QR SCANNER ERROR: Failed to start camera: $error');
        });
  }

  @override
  void dispose() {
    AppLogging.qr('📷 QR SCANNER: dispose - stopping camera');
    _controller.dispose();
    super.dispose();
  }

  /// Parse node data from QR code - handles both base64 JSON and hex Firestore ID
  Map<String, dynamic> _parseNodeData(String data) {
    // Check if it looks like a hex ID (8 characters, all hex digits)
    final hexPattern = RegExp(r'^[0-9A-Fa-f]{8}$');
    if (hexPattern.hasMatch(data)) {
      // It's a Firestore hex ID - convert to nodeNum
      final nodeNum = int.parse(data, radix: 16);
      AppLogging.qr('📷 QR SCANNER: Parsed hex ID $data as nodeNum=$nodeNum');
      return {'nodeNum': nodeNum};
    }

    // Try to decode as base64 JSON
    try {
      final jsonStr = utf8.decode(Base64Utils.decodeWithPadding(data));
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      AppLogging.qr('📷 QR SCANNER: Parsed base64 JSON successfully');
      return parsed;
    } catch (e) {
      AppLogging.qr('📷 QR SCANNER ERROR: Failed to parse node data: $e');
      throw Exception('Invalid node QR code format');
    }
  }

  void _onDetect(BarcodeCapture capture) {
    AppLogging.qr('📷 QR SCANNER: onDetect called');
    if (_isProcessing) {
      AppLogging.qr('📷 QR SCANNER: Already processing, ignoring');
      return;
    }

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) {
      AppLogging.qr('📷 QR SCANNER: No barcodes in capture');
      return;
    }

    final String? code = barcodes.first.rawValue;
    if (code == null) {
      AppLogging.qr('📷 QR SCANNER: Barcode rawValue is null');
      return;
    }

    // Skip if we just processed this exact code (prevents duplicate processing)
    if (code == _lastProcessedCode) {
      AppLogging.qr('📷 QR SCANNER: Duplicate code, ignoring');
      return;
    }
    _lastProcessedCode = code;

    AppLogging.ble(
      '📷 QR SCANNER: Detected code: ${code.substring(0, code.length > 50 ? 50 : code.length)}...',
    );
    setState(() {
      _isProcessing = true;
    });

    _processQrCode(code);
  }

  Future<void> _processQrCode(String code) async {
    AppLogging.qr('📷 QR SCANNER: Processing QR code');
    try {
      // Node QR codes format: "socialmesh://node/<base64-encoded-json>"
      // Also supports: "socialmesh://node/<hex-id>" (Firestore doc ID)
      // Also supports legacy format: "meshtastic://node/<base64-encoded-json>"
      String nodeData;
      if (code.startsWith('socialmesh://node/')) {
        nodeData = code.substring('socialmesh://node/'.length);
        AppLogging.qr('📷 QR SCANNER: Valid socialmesh node QR detected');
      } else if (code.startsWith('meshtastic://node/')) {
        nodeData = code.substring('meshtastic://node/'.length);
        AppLogging.qr('📷 QR SCANNER: Valid meshtastic node QR detected');
      } else {
        AppLogging.qr('📷 QR SCANNER ERROR: Invalid QR format: $code');
        throw Exception('Not a valid node QR code');
      }

      // Try to parse the node data - could be base64 JSON or hex Firestore ID
      final nodeInfo = _parseNodeData(nodeData);

      // Extract node information
      final nodeNum = nodeInfo['nodeNum'] as int?;
      final longName = nodeInfo['longName'] as String?;
      final shortName = nodeInfo['shortName'] as String?;
      final userId = nodeInfo['userId'] as String?;
      final lat = nodeInfo['lat'] as double?;
      final lon = nodeInfo['lon'] as double?;

      if (nodeNum == null) {
        AppLogging.qr('📷 QR SCANNER ERROR: Missing nodeNum in QR data');
        throw Exception('Invalid node data: missing nodeNum');
      }

      AppLogging.ble(
        '📷 QR SCANNER: Parsed node - nodeNum=$nodeNum, longName=$longName',
      );

      // Check if node already exists
      final existingNodes = ref.read(nodesProvider);
      final existingNode = existingNodes[nodeNum];

      if (existingNode != null) {
        // Node exists - ask user if they want to update it
        if (mounted) {
          final update = await _showNodeExistsDialog(existingNode, longName);
          if (update == true) {
            await _addOrUpdateNode(
              nodeNum: nodeNum,
              longName: longName,
              shortName: shortName,
              userId: userId,
              lat: lat,
              lon: lon,
              makeFavorite: true,
            );
          }
        }
      } else {
        // New node - show confirmation
        if (mounted) {
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
              makeFavorite: true,
            );
          }
        }
      }

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to import node: $e');
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<bool?> _showNodeExistsDialog(MeshNode existing, String? newName) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
              SizedBox(height: 12),
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
                    SizedBox(width: 10),
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
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
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
    final displayName = longName ?? shortName ?? 'Unknown Node';
    final nodeId = nodeNum.toRadixString(16).toUpperCase();

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Node', style: TextStyle(color: context.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Name', displayName),
            SizedBox(height: 8),
            _buildInfoRow('Node ID', '!$nodeId'),
            if (userId != null) ...[
              SizedBox(height: 8),
              _buildInfoRow('User ID', userId),
            ],
            SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: context.accentColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.star, color: context.accentColor, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This node will be added to your favorites for easy access.',
                      style: TextStyle(
                        fontSize: 12,
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
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: context.accentColor),
            child: const Text('Add Node'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            '$label:',
            style: TextStyle(color: context.textSecondary, fontSize: 14),
          ),
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

  Future<void> _addOrUpdateNode({
    required int nodeNum,
    String? longName,
    String? shortName,
    String? userId,
    double? lat,
    double? lon,
    bool makeFavorite = false,
  }) async {
    try {
      final nodesNotifier = ref.read(nodesProvider.notifier);
      final existingNodes = ref.read(nodesProvider);
      final existing = existingNodes[nodeNum];

      // Sanitize names to prevent UTF-16 crashes when rendering text
      final sanitizedLongName = longName != null
          ? sanitizeUtf16(longName)
          : existing?.longName;
      final sanitizedShortName = shortName != null
          ? sanitizeUtf16(shortName)
          : existing?.shortName;

      // Create or update the node
      final node = MeshNode(
        nodeNum: nodeNum,
        longName: sanitizedLongName,
        shortName: sanitizedShortName,
        userId: userId ?? existing?.userId,
        latitude: lat ?? existing?.latitude,
        longitude: lon ?? existing?.longitude,
        altitude: existing?.altitude,
        isFavorite: makeFavorite || (existing?.isFavorite ?? false),
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

      nodesNotifier.addOrUpdateNode(node);

      if (mounted) {
        showSuccessSnackBar(
          context,
          existing != null
              ? 'Node "${node.displayName}" updated'
              : 'Node "${node.displayName}" added to favorites',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to add node: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLogging.qr('📷 QR SCANNER: build() - isProcessing=$_isProcessing');
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
          // Scanner overlay - simple border like channel scanner
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
                    'Point your camera at a QR code',
                    style: TextStyle(color: context.textPrimary, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Supports nodes shared from Socialmesh',
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
