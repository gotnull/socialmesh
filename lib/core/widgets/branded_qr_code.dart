// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

/// Custom clipper that creates a rounded rectangle path for the embedded image.
class _RoundedRectangleClipper implements PrettyQrClipper {
  const _RoundedRectangleClipper({this.borderRadius = 16});

  final double borderRadius;

  @override
  ui.Path getClip(ui.Size size) {
    return ui.Path()..addRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(0, 0, size.width, size.height),
        ui.Radius.circular(borderRadius),
      ),
    );
  }
}

/// QR code style options for branded QR codes.
enum QrStyle {
  /// Classic square modules (default QR style)
  squares,

  /// Circular dot modules
  dots,

  /// Smooth, rounded liquid-like modules
  smooth,
}

/// A QR code widget with the Socialmesh app icon centered with proper styling.
///
/// Uses pretty_qr_code for advanced styling options including smooth,
/// dots, and square module shapes.
class BrandedQrCode extends StatelessWidget {
  const BrandedQrCode({
    super.key,
    required this.data,
    this.size = 200,
    this.backgroundColor = Colors.white,
    this.foregroundColor = const Color(0xFF1F2633),
    this.style = QrStyle.dots,
    this.showLogo = true,
  });

  /// The data to encode in the QR code.
  final String data;

  /// The size of the QR code (width and height).
  final double size;

  /// The background color of the QR code.
  final Color backgroundColor;

  /// The foreground color (dots and eyes) of the QR code.
  final Color foregroundColor;

  /// The visual style of the QR code modules.
  final QrStyle style;

  /// Whether to show the app logo in the center.
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    final qrCode = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.H,
    );

    final qrImage = QrImage(qrCode);

    return SizedBox(
      width: size,
      height: size,
      child: PrettyQrView(
        qrImage: qrImage,
        decoration: PrettyQrDecoration(
          background: backgroundColor,
          shape: _buildShape(),
          image: showLogo
              ? const PrettyQrDecorationImage(
                  image: AssetImage('assets/app_icons/socialmesh_icon_512.png'),
                  position: PrettyQrDecorationImagePosition.embedded,
                  padding: EdgeInsets.all(8),
                  clipper: _RoundedRectangleClipper(borderRadius: 12),
                )
              : null,
        ),
      ),
    );
  }

  PrettyQrShape _buildShape() {
    switch (style) {
      case QrStyle.squares:
        return PrettyQrSmoothSymbol(
          roundFactor: 0,
          color: PrettyQrBrush.solid(foregroundColor.value),
        );
      case QrStyle.dots:
        return PrettyQrSmoothSymbol(
          roundFactor: 1,
          color: PrettyQrBrush.solid(foregroundColor.value),
        );
      case QrStyle.smooth:
        return PrettyQrSmoothSymbol(
          roundFactor: 0.6,
          color: PrettyQrBrush.solid(foregroundColor.value),
        );
    }
  }
}
