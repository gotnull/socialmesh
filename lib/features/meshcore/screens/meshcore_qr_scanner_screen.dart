// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: scaffold — immersive camera scanner with transparent AppBar
import 'dart:async';

import '../../../core/l10n/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../models/meshcore_channel.dart';
import '../../../models/meshcore_contact.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../utils/snackbar.dart';

/// Enum for scan mode
enum MeshCoreScanMode { contact, channel }

/// QR Scanner screen for MeshCore contacts and channels.
class MeshCoreQrScannerScreen extends ConsumerStatefulWidget {
  final MeshCoreScanMode mode;

  const MeshCoreQrScannerScreen({super.key, required this.mode});

  @override
  ConsumerState<MeshCoreQrScannerScreen> createState() =>
      _MeshCoreQrScannerScreenState();
}

class _MeshCoreQrScannerScreenState
    extends ConsumerState<MeshCoreQrScannerScreen>
    with LifecycleSafeMixin<MeshCoreQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  StreamSubscription<BarcodeCapture>? _barcodeSubscription;
  bool _isProcessing = false;
  String? _lastScannedCode;

  @override
  void initState() {
    super.initState();
    AppLogging.ble('MeshCore QR Scanner: initState - mode=${widget.mode.name}');
    AppLogging.meshcore(
      'event=screen.opened name=qr_scanner mode=${widget.mode.name}',
    );

    _barcodeSubscription = _controller.barcodes.listen(
      (capture) {
        AppLogging.ble('MeshCore QR Scanner: Barcode stream event received');
      },
      onError: (error) {
        AppLogging.ble('MeshCore QR Scanner ERROR: $error');
      },
    );

    _controller
        .start()
        .then((_) {
          AppLogging.ble('MeshCore QR Scanner: Camera started successfully');
          if (mounted) {
            safeSetState(() {});
          }
        })
        .catchError((error) {
          AppLogging.ble(
            'MeshCore QR Scanner ERROR: Failed to start camera: $error',
          );
        });
  }

  @override
  void dispose() {
    AppLogging.ble('MeshCore QR Scanner: dispose - stopping camera');
    _barcodeSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code == _lastScannedCode) return;

    _lastScannedCode = code;
    AppLogging.ble(
      'MeshCore QR Scanner: Detected code: ${code.substring(0, code.length > 50 ? 50 : code.length)}...',
    );

    safeSetState(() {
      _isProcessing = true;
    });

    _processQrCode(code);
  }

  void _processQrCode(String code) {
    try {
      switch (widget.mode) {
        case MeshCoreScanMode.contact:
          _processContactCode(code);
        case MeshCoreScanMode.channel:
          _processChannelCode(code);
      }
    } catch (e) {
      AppLogging.ble('MeshCore QR Scanner ERROR: $e');
      showErrorSnackBar(context, context.l10n.meshcoreInvalidQrCodeFormat);
      _resetScanner();
    }
  }

  void _processContactCode(String code) {
    // Try parsing as contact code (pubKeyHex:name format)
    final contact = parseContactCode(code);
    if (contact != null) {
      // Check if contact already exists
      final existingContacts = ref.read(meshCoreContactsProvider).contacts;
      final exists = existingContacts.any(
        (c) => c.publicKeyHex == contact.publicKeyHex,
      );

      if (exists) {
        showInfoSnackBar(
          context,
          context.l10n.meshcoreContactAlreadyExists(contact.name),
        );
        _resetScanner();
        return;
      }

      // Add the contact
      ref.read(meshCoreContactsProvider.notifier).addContact(contact);
      showSuccessSnackBar(
        context,
        context.l10n.meshcoreContactAddedToContacts(contact.name),
      );
      safeNavigatorPop(contact);
      return;
    }

    // Try socialmesh:// or meshcore:// URL format
    if (code.startsWith('socialmesh://contact/') ||
        code.startsWith('meshcore://contact/')) {
      final base64Part = code.contains('socialmesh://')
          ? code.substring('socialmesh://contact/'.length)
          : code.substring('meshcore://contact/'.length);

      // Decode and parse
      final decodedContact = parseContactCode(base64Part);
      if (decodedContact != null) {
        final existingContacts = ref.read(meshCoreContactsProvider).contacts;
        final exists = existingContacts.any(
          (c) => c.publicKeyHex == decodedContact.publicKeyHex,
        );

        if (exists) {
          showInfoSnackBar(
            context,
            context.l10n.meshcoreContactAlreadyExists(decodedContact.name),
          );
          _resetScanner();
          return;
        }

        ref.read(meshCoreContactsProvider.notifier).addContact(decodedContact);
        showSuccessSnackBar(
          context,
          context.l10n.meshcoreContactAddedToContacts(decodedContact.name),
        );
        safeNavigatorPop(decodedContact);
        return;
      }
    }

    showErrorSnackBar(context, context.l10n.meshcoreNotValidContactQr);
    _resetScanner();
  }

  void _processChannelCode(String code) {
    // Find next available channel index
    final channelsState = ref.read(meshCoreChannelsProvider);
    final existingIndices = channelsState.channels.map((c) => c.index).toSet();
    var newIndex = 0;
    for (var i = 0; i < 8; i++) {
      if (!existingIndices.contains(i)) {
        newIndex = i;
        break;
      }
    }

    // Try parsing as channel code (name:pskHex format)
    final channel = parseChannelCode(code, index: newIndex);
    if (channel != null) {
      // Check if channel already exists
      final exists = channelsState.channels.any(
        (c) => c.pskHex == channel.pskHex && c.name == channel.name,
      );

      if (exists) {
        showInfoSnackBar(
          context,
          context.l10n.meshcoreChannelAlreadyExists(channel.displayName),
        );
        _resetScanner();
        return;
      }

      // Add the channel
      ref.read(meshCoreChannelsProvider.notifier).setChannel(channel);
      showSuccessSnackBar(
        context,
        context.l10n.meshcoreJoinedChannel(channel.displayName),
      );
      safeNavigatorPop(channel);
      return;
    }

    // Try socialmesh:// or meshcore:// URL format
    if (code.startsWith('socialmesh://channel/') ||
        code.startsWith('meshcore://channel/')) {
      final base64Part = code.contains('socialmesh://')
          ? code.substring('socialmesh://channel/'.length)
          : code.substring('meshcore://channel/'.length);

      final decodedChannel = parseChannelCode(base64Part, index: newIndex);
      if (decodedChannel != null) {
        final exists = channelsState.channels.any(
          (c) =>
              c.pskHex == decodedChannel.pskHex &&
              c.name == decodedChannel.name,
        );

        if (exists) {
          showInfoSnackBar(
            context,
            context.l10n.meshcoreChannelAlreadyExists(
              decodedChannel.displayName,
            ),
          );
          _resetScanner();
          return;
        }

        ref.read(meshCoreChannelsProvider.notifier).setChannel(decodedChannel);
        showSuccessSnackBar(
          context,
          context.l10n.meshcoreJoinedChannel(decodedChannel.displayName),
        );
        safeNavigatorPop(decodedChannel);
        return;
      }
    }

    showErrorSnackBar(context, context.l10n.meshcoreNotValidChannelQr);
    _resetScanner();
  }

  void _resetScanner() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        safeSetState(() {
          _isProcessing = false;
          _lastScannedCode = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.mode == MeshCoreScanMode.contact
        ? context.l10n.meshcoreScanContactQrTitle
        : context.l10n.meshcoreScanChannelQrTitle;

    final accentColor = widget.mode == MeshCoreScanMode.contact
        ? AccentColors.cyan
        : AccentColors.purple;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _controller.torchEnabled ? Icons.flash_on : Icons.flash_off,
              color: _controller.torchEnabled ? accentColor : Colors.white70,
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white70),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Scan frame overlay
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isProcessing ? AppTheme.successGreen : accentColor,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radius16),
              ),
            ),
          ),
          // Corner decorations
          Center(
            child: SizedBox(
              width: 280,
              height: 280,
              child: Stack(
                children: [
                  _buildCorner(accentColor, Alignment.topLeft),
                  _buildCorner(accentColor, Alignment.topRight),
                  _buildCorner(accentColor, Alignment.bottomLeft),
                  _buildCorner(accentColor, Alignment.bottomRight),
                ],
              ),
            ),
          ),
          // Processing indicator
          if (_isProcessing) const Center(child: LoadingIndicator()),
          // Instructions
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(AppTheme.radius12),
              ),
              child: Text(
                widget.mode == MeshCoreScanMode.contact
                    ? context.l10n.meshcorePointCameraAtContactQr
                    : context.l10n.meshcorePointCameraAtChannelQr,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorner(Color color, Alignment alignment) {
    const size = 30.0;
    const thickness = 4.0;

    final isTop =
        alignment == Alignment.topLeft || alignment == Alignment.topRight;
    final isLeft =
        alignment == Alignment.topLeft || alignment == Alignment.bottomLeft;

    return Positioned(
      top: isTop ? 0 : null,
      bottom: !isTop ? 0 : null,
      left: isLeft ? 0 : null,
      right: !isLeft ? 0 : null,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _CornerPainter(
            color: color,
            thickness: thickness,
            isTop: isTop,
            isLeft: isLeft,
          ),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final bool isTop;
  final bool isLeft;

  _CornerPainter({
    required this.color,
    required this.thickness,
    required this.isTop,
    required this.isLeft,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    if (isTop && isLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (isTop && !isLeft) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (!isTop && isLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
