import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../providers/app_providers.dart';
import '../../models/mesh_models.dart';
import '../../core/theme.dart';
import '../../utils/snackbar.dart';

class NodeQrScannerScreen extends ConsumerStatefulWidget {
  const NodeQrScannerScreen({super.key});

  @override
  ConsumerState<NodeQrScannerScreen> createState() =>
      _NodeQrScannerScreenState();
}

class _NodeQrScannerScreenState extends ConsumerState<NodeQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
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
      // Node QR codes format: "socialmesh://node/<base64-encoded-json>"
      // Also supports legacy format: "meshtastic://node/<base64-encoded-json>"
      String base64Data;
      if (code.startsWith('socialmesh://node/')) {
        base64Data = code.substring('socialmesh://node/'.length);
      } else if (code.startsWith('meshtastic://node/')) {
        base64Data = code.substring('meshtastic://node/'.length);
      } else {
        throw Exception('Not a valid node QR code');
      }
      final jsonStr = utf8.decode(base64Decode(base64Data));
      final nodeInfo = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Extract node information
      final nodeNum = nodeInfo['nodeNum'] as int?;
      final longName = nodeInfo['longName'] as String?;
      final shortName = nodeInfo['shortName'] as String?;
      final userId = nodeInfo['userId'] as String?;
      final lat = nodeInfo['lat'] as double?;
      final lon = nodeInfo['lon'] as double?;

      if (nodeNum == null) {
        throw Exception('Invalid node data: missing nodeNum');
      }

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
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Node Already Exists',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This node is already in your list as "${existing.displayName}".',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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
              style: TextStyle(color: AppTheme.textSecondary),
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
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Node', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Name', displayName),
            const SizedBox(height: 8),
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
              style: TextStyle(color: AppTheme.textSecondary),
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
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
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

      // Create or update the node
      final node = MeshNode(
        nodeNum: nodeNum,
        longName: longName ?? existing?.longName,
        shortName: shortName ?? existing?.shortName,
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
        isOnline: existing?.isOnline ?? false,
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
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text(
          'Scan Node QR',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: Icon(Icons.flip_camera_ios, color: Colors.white),
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
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    context.accentColor,
                  ),
                ),
              ),
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
                    AppTheme.darkBackground.withValues(alpha: 0.9),
                    AppTheme.darkBackground,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_add, size: 32, color: context.accentColor),
                  SizedBox(height: 12),
                  Text(
                    'Point your camera at a node QR code',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'The node will be added to your favorites',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
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
