// SPDX-License-Identifier: GPL-3.0-or-later

// Sigil Card Sheet — bottom sheet for previewing and sharing a node's
// collectible identity card.
//
// Flow:
//   1. User taps "Share Sigil Card" on the NodeDex detail screen.
//   2. This sheet opens with an animated live preview of the card.
//   3. User taps the share button.
//   4. The card is re-rendered statically (no animation) into a
//      RepaintBoundary, captured at 3x pixel ratio for crisp output.
//   5. The PNG is written to a temp file and shared via share_plus.
//
// The sheet uses two render paths:
// - Animated SigilCard for the live preview (delightful to look at).
// - Static SigilCard inside a RepaintBoundary for image capture
//   (animations would produce inconsistent frames).

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants.dart';
import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../models/mesh_models.dart';
import '../../../utils/share_utils.dart';
import '../../../utils/snackbar.dart';
import '../models/nodedex_entry.dart';
import '../services/trait_engine.dart';
import 'sigil_card.dart';

/// Card capture pixel ratio — 3x produces a ~960x1344 PNG which looks
/// crisp on all modern screens and social media platforms.
const double _capturePixelRatio = 3.0;

/// Width of the card used for capture (matches SigilCard default).
const double _captureCardWidth = 320.0;

/// Show the Sigil Card share sheet for a node.
///
/// This is the public entry point. Call it from the NodeDex detail screen
/// or anywhere a node's identity card should be previewed and shared.
void showSigilCardSheet({
  required BuildContext context,
  required NodeDexEntry entry,
  required TraitResult traitResult,
  MeshNode? node,
}) {
  final displayName = node?.displayName ?? 'Node ${entry.nodeNum}';
  final hexId =
      '!${entry.nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}';

  AppLogging.nodeDex(
    'Sigil card sheet showing for $hexId ($displayName), '
    'trait: ${traitResult.primary.name}, '
    'encounters: ${entry.encounterCount}',
  );

  AppBottomSheet.show<void>(
    context: context,
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
    child: _SigilCardSheetContent(
      entry: entry,
      traitResult: traitResult,
      displayName: displayName,
      hexId: hexId,
      hardwareModel: node?.hardwareModel,
      firmwareVersion: node?.firmwareVersion,
      role: node?.role,
    ),
  );
}

// =============================================================================
// Sheet content
// =============================================================================

class _SigilCardSheetContent extends ConsumerStatefulWidget {
  final NodeDexEntry entry;
  final TraitResult traitResult;
  final String displayName;
  final String hexId;
  final String? hardwareModel;
  final String? firmwareVersion;
  final String? role;

  const _SigilCardSheetContent({
    required this.entry,
    required this.traitResult,
    required this.displayName,
    required this.hexId,
    this.hardwareModel,
    this.firmwareVersion,
    this.role,
  });

  @override
  ConsumerState<_SigilCardSheetContent> createState() =>
      _SigilCardSheetContentState();
}

class _SigilCardSheetContentState extends ConsumerState<_SigilCardSheetContent>
    with LifecycleSafeMixin<_SigilCardSheetContent> {
  final GlobalKey _captureKey = GlobalKey();
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    final rarity = CardRarityVisuals.fromNodeData(
      encounterCount: widget.entry.encounterCount,
      trait: widget.traitResult.primary,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),

        // --- Header ---
        Row(
          children: [
            Icon(Icons.auto_awesome, size: 18, color: rarity.borderColor),
            const SizedBox(width: 8),
            Text(
              'Sigil Card',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
            const Spacer(),
            // Rarity badge.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: rarity.borderColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: rarity.borderColor.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Text(
                rarity.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: rarity.borderColor,
                  letterSpacing: 1.0,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // --- Animated card preview (visible to user) ---
        Center(
          child: SigilCard(
            nodeNum: widget.entry.nodeNum,
            sigil: widget.entry.sigil,
            displayName: widget.displayName,
            hexId: widget.hexId,
            traitResult: widget.traitResult,
            entry: widget.entry,
            hardwareModel: widget.hardwareModel,
            firmwareVersion: widget.firmwareVersion,
            role: widget.role,
            animated: true,
            width: 280,
          ),
        ),

        const SizedBox(height: 16),

        // --- Share button ---
        if (_isSharing)
          const SizedBox(
            height: 48,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _shareCard,
              icon: const Icon(Icons.share_outlined, size: 18),
              label: const Text(
                'Share Sigil Card',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: context.accentColor,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ),
          ),

        // Bottom safe area padding so button text is never clipped
        SizedBox(height: MediaQuery.of(context).padding.bottom),

        // --- Off-screen capture widget ---
        // Uses a near-zero Opacity + OverflowBox so the widget is still
        // painted (required for RepaintBoundary.toImage) but invisible
        // and takes no layout space.
        //
        // CRITICAL: opacity MUST be > 0. At exactly 0.0 Flutter's
        // RenderOpacity.paint() short-circuits and never paints the
        // child, so the RepaintBoundary never creates a layer and
        // toImage() throws "Null check operator used on a null value".
        // Offstage(offstage: true) has the same skip-paint behaviour.
        SizedBox.shrink(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            maxWidth: _captureCardWidth,
            maxHeight: _captureCardWidth * 1.4,
            child: Opacity(
              opacity: 0.01,
              child: RepaintBoundary(
                key: _captureKey,
                child: SigilCard(
                  nodeNum: widget.entry.nodeNum,
                  sigil: widget.entry.sigil,
                  displayName: widget.displayName,
                  hexId: widget.hexId,
                  traitResult: widget.traitResult,
                  entry: widget.entry,
                  hardwareModel: widget.hardwareModel,
                  firmwareVersion: widget.firmwareVersion,
                  role: widget.role,
                  animated: false,
                  width: _captureCardWidth,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Share logic
  // ---------------------------------------------------------------------------

  Future<void> _shareCard() async {
    if (_isSharing) return;

    AppLogging.nodeDex(
      'Share sigil card initiated for node ${widget.entry.nodeNum}',
    );

    // Capture context-dependent values before any await.
    final messenger = ScaffoldMessenger.of(context);
    final sharePosition = getSafeSharePosition(context);

    setState(() => _isSharing = true);

    try {
      // Publish sigil data to the API and capture the card image in parallel.
      final results = await Future.wait([
        _publishSigilCard(),
        _captureCardImage(),
      ]);

      if (!mounted) return;

      final webUrl = results[0] as String?;
      final pngBytes = results[1] as List<int>?;

      if (pngBytes == null) {
        AppLogging.nodeDex(
          'Share failed — card image capture returned null '
          'for node ${widget.entry.nodeNum}',
        );
        showErrorSnackBar(context, 'Failed to capture card image');
        return;
      }

      AppLogging.nodeDex(
        'Card image captured: ${pngBytes.length} bytes '
        'for node ${widget.entry.nodeNum}',
      );

      // Write to temp file.
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'sigil_card_${widget.entry.nodeNum}_$timestamp.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pngBytes);

      AppLogging.nodeDex('Card PNG written to ${file.path}');

      if (!mounted) return;

      final shareLines = <String>[
        'Check out the Sigil Card for ${widget.displayName} on Socialmesh!',
        if (webUrl != null) webUrl,
        '',
        'Get Socialmesh:',
        'iOS: ${AppUrls.appStoreUrl}',
        'Android: ${AppUrls.playStoreUrl}',
      ];
      final shareText = shareLines.join('\n');

      if (webUrl != null) {
        AppLogging.nodeDex('Sharing sigil card with URL: $webUrl');
      } else {
        AppLogging.nodeDex(
          'Sharing sigil card without URL (API publish failed)',
        );
      }

      // Share via system share sheet.
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '${widget.displayName} — Sigil Card',
        text: shareText,
        sharePositionOrigin: sharePosition,
      );

      AppLogging.nodeDex(
        'Share sheet completed for node ${widget.entry.nodeNum}',
      );
    } catch (e, stack) {
      AppLogging.nodeDex(
        'Share failed for node ${widget.entry.nodeNum}: $e\n$stack',
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not share card: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  /// Publish sigil card data to the API and return the shareable URL.
  ///
  /// Returns null if the API call fails — sharing should still proceed
  /// with just the image (graceful degradation).
  Future<String?> _publishSigilCard() async {
    final entry = widget.entry;
    final payload = <String, dynamic>{
      'nodeNum': entry.nodeNum,
      'displayName': widget.displayName,
      'hexId': widget.hexId,
      'trait': widget.traitResult.primary.name,
      'encounterCount': entry.encounterCount,
      'messageCount': entry.messageCount,
      'coSeenCount': entry.coSeenCount,
      'ageDays': entry.age.inDays,
    };

    if (entry.maxDistanceSeen != null) {
      payload['maxDistance'] = entry.maxDistanceSeen!.round();
    }
    if (entry.bestSnr != null) {
      payload['bestSnr'] = entry.bestSnr;
    }
    if (widget.role != null && widget.role!.isNotEmpty) {
      payload['role'] = widget.role;
    }
    if (widget.hardwareModel != null && widget.hardwareModel!.isNotEmpty) {
      payload['hardwareModel'] = widget.hardwareModel;
    }
    if (widget.firmwareVersion != null && widget.firmwareVersion!.isNotEmpty) {
      payload['firmwareVersion'] = widget.firmwareVersion;
    }

    try {
      final uri = Uri.parse('${AppUrls.sigilApiUrl}/api/sigil');
      AppLogging.nodeDex('Publishing sigil card to $uri');

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final url = body['url'] as String?;
        if (url != null) {
          AppLogging.nodeDex('Sigil published: $url');
          return url;
        }
        // Fallback: construct URL from returned ID
        final id = body['id'] as String?;
        if (id != null) {
          final fallbackUrl = AppUrls.shareSigilUrl(id);
          AppLogging.nodeDex('Sigil published (constructed URL): $fallbackUrl');
          return fallbackUrl;
        }
      }

      AppLogging.nodeDex(
        'Sigil API returned ${response.statusCode}: ${response.body}',
      );
      return null;
    } catch (e) {
      AppLogging.nodeDex('Sigil API publish failed: $e');
      return null;
    }
  }

  /// Capture the off-screen static card as a PNG byte list.
  Future<List<int>?> _captureCardImage() async {
    try {
      // Allow two frames for the widget to fully lay out and paint.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final renderObject = _captureKey.currentContext?.findRenderObject();
      if (renderObject == null) {
        AppLogging.nodeDex('Capture failed — render object is null');
        return null;
      }

      final boundary = renderObject as RenderRepaintBoundary;

      AppLogging.nodeDex(
        'Capturing card image at ${_capturePixelRatio}x pixel ratio, '
        'boundary size: ${boundary.size}',
      );

      final image = await boundary.toImage(pixelRatio: _capturePixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        AppLogging.nodeDex('Capture failed — toByteData returned null');
        return null;
      }

      AppLogging.nodeDex(
        'Card image captured successfully: '
        '${image.width}x${image.height} pixels, '
        '${byteData.lengthInBytes} bytes',
      );

      return byteData.buffer.asUint8List();
    } catch (e, stack) {
      AppLogging.nodeDex('Capture failed with exception: $e\n$stack');
      return null;
    }
  }
}
