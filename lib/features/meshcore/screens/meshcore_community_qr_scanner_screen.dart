// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q7: community QR scanner. Reuses `mobile_scanner` (same package
// as the per-channel QR import); on detect the raw value is fed to
// the pure `parseMeshCoreCommunityPayload` parser, then handed off
// to `showMeshCoreCommunityQrPreviewSheet` for per-channel consent.
// The scanner pauses after a successful parse so the camera doesn't
// keep firing while the preview sheet is up.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../services/meshcore/storage/meshcore_community_qr_payload.dart';
import '../../../utils/snackbar.dart';
import '../widgets/meshcore_community_qr_preview_sheet.dart';

class MeshCoreCommunityQrScannerScreen extends ConsumerStatefulWidget {
  const MeshCoreCommunityQrScannerScreen({super.key});

  @override
  ConsumerState<MeshCoreCommunityQrScannerScreen> createState() =>
      _MeshCoreCommunityQrScannerScreenState();
}

class _MeshCoreCommunityQrScannerScreenState
    extends ConsumerState<MeshCoreCommunityQrScannerScreen>
    with LifecycleSafeMixin {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _processing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_processing) return;
    final l10n = context.l10n;
    final code = capture.barcodes.isNotEmpty
        ? capture.barcodes.first.rawValue
        : null;
    if (code == null || code.isEmpty) return;

    setState(() => _processing = true);
    _controller.stop();

    final result = parseMeshCoreCommunityPayload(code);
    if (!result.isSuccess) {
      showErrorSnackBar(context, _errorMessage(l10n, result.error!));
      _resetScanner();
      return;
    }

    _showPreview(result.payload!);
  }

  Future<void> _showPreview(MeshCoreCommunityPayload payload) async {
    final accepted = await showMeshCoreCommunityQrPreviewSheet(
      context,
      payload: payload,
    );
    if (!mounted) return;
    if (accepted == true) {
      safeNavigatorPop(true);
    } else {
      _resetScanner();
    }
  }

  void _resetScanner() {
    if (!mounted) return;
    setState(() => _processing = false);
    _controller.start();
  }

  String _errorMessage(dynamic l10n, MeshCoreCommunityParseError e) {
    switch (e) {
      case MeshCoreCommunityParseError.notJson:
        return l10n.meshcoreCommunityQrErrorNotJson as String;
      case MeshCoreCommunityParseError.wrongType:
        return l10n.meshcoreCommunityQrErrorWrongType as String;
      case MeshCoreCommunityParseError.unsupportedVersion:
        return l10n.meshcoreCommunityQrErrorUnsupportedVersion as String;
      case MeshCoreCommunityParseError.missingName:
      case MeshCoreCommunityParseError.emptyName:
        return l10n.meshcoreCommunityQrErrorMissingName as String;
      case MeshCoreCommunityParseError.missingSecret:
      case MeshCoreCommunityParseError.badSecretEncoding:
      case MeshCoreCommunityParseError.badSecretLength:
        return l10n.meshcoreCommunityQrErrorBadSecret as String;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GlassScaffold.body(
      hasScrollBody: false,
      title: l10n.meshcoreCommunityQrScannerTitle,
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(color: context.accentColor, width: 2),
                    borderRadius: BorderRadius.circular(AppTheme.radius16),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: AppTheme.spacing24,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing24,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spacing12),
                decoration: BoxDecoration(
                  color: context.background.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: Text(
                  l10n.meshcoreCommunityQrScannerHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textPrimary, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
