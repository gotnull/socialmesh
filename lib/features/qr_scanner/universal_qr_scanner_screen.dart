// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: scaffold — camera feed, glass blur would obscure scanner
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/qr_scanner_overlay.dart';
import '../../generated/meshtastic/channel.pb.dart' as channel_pb;
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import '../../services/deep_link/deep_link.dart';
import '../../utils/encoding.dart';
import '../../utils/snackbar.dart';
import '../../utils/text_sanitizer.dart';
import '../channels/channel_form_screen.dart';

/// Universal QR code scanner that handles all SocialMesh QR code types:
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
    extends ConsumerState<UniversalQrScannerScreen>
    with LifecycleSafeMixin<UniversalQrScannerScreen> {
  late final MobileScannerController _controller;
  bool _isProcessing = false;
  String? _lastProcessedCode;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    AppLogging.qr('📷 Universal QR Scanner: Initializing');

    // Create controller with autoStart disabled to prevent race conditions
    _controller = MobileScannerController(autoStart: false);

    _controller.barcodes.listen(
      (capture) {
        AppLogging.qr('📷 Universal QR Scanner: Barcode stream event');
      },
      onError: (error) {
        AppLogging.qr('📷 Universal QR Scanner ERROR: $error');
      },
    );

    // Start camera manually after controller is fully initialized
    _startCamera();
  }

  Future<void> _startCamera() async {
    if (_isDisposed) return;
    try {
      await _controller.start();
      AppLogging.qr('📷 Universal QR Scanner: Camera started');
      if (mounted) safeSetState(() {});
    } catch (error) {
      AppLogging.qr(
        'QR - 📷 Universal QR Scanner ERROR: Failed to start: $error',
      );
    }
  }

  @override
  void dispose() {
    AppLogging.qr('📷 Universal QR Scanner: Disposing');
    _isDisposed = true;
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

    safeSetState(() => _isProcessing = true);
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
        case DeepLinkType.helpCircleInvite:
          await _handleHelpCircleInviteQr(parsed);
        case DeepLinkType.channelInvite:
        case DeepLinkType.aetherFlight:
        case DeepLinkType.legal:
        case DeepLinkType.purchaseReturn:
        case DeepLinkType.licenseOrgInvite:
        case DeepLinkType.invalid:
          throw Exception('Invalid QR code');
      }
    } catch (e) {
      AppLogging.qr('📷 Universal QR Scanner ERROR: $e');
      if (mounted) {
        showErrorSnackBar(
          context,
          context.l10n.qrScannerFailedToProcess(e.toString()),
        );
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

  // ─────────────────────────────────────────────────────────────────────────────
  // Help Circle invite QR Handling
  // ─────────────────────────────────────────────────────────────────────────────

  /// Routes a scanned Help Circle invite to the consent screen, which gates the
  /// actual add behind an explicit user tap. Replaces the scanner so Back does
  /// not return to the live camera.
  Future<void> _handleHelpCircleInviteQr(ParsedDeepLink parsed) async {
    final nodeNum = parsed.helpCircleInviteNodeNum;
    if (nodeNum == null) {
      throw Exception('Invalid help circle invite');
    }
    if (!mounted) return;
    await Navigator.of(context).pushReplacementNamed(
      '/help-circle-invite',
      arguments: {
        'nodeNum': nodeNum,
        'longName': parsed.helpCircleInviteLongName,
        'shortName': parsed.helpCircleInviteShortName,
      },
    );
  }

  Future<bool?> _showNodeExistsDialog(MeshNode existing, String? newName) {
    return AppBottomSheet.show<bool>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.qrScannerNodeAlreadyExists,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            context.l10n.qrScannerNodeAlreadyInList(existing.displayName),
            style: TextStyle(color: context.textSecondary, fontSize: 14),
          ),
          if (newName != null && newName != existing.longName) ...[
            const SizedBox(height: AppTheme.spacing12),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              decoration: BoxDecoration(
                color: context.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: context.accentColor,
                    size: 18,
                  ),
                  const SizedBox(width: AppTheme.spacing10),
                  Expanded(
                    child: Text(
                      context.l10n.qrScannerUpdateNamePrompt(newName),
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
          const SizedBox(height: AppTheme.spacing24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: SemanticColors.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                  child: Text(
                    context.l10n.qrScannerCancel,
                    style: TextStyle(color: context.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: context.accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                  child: Text(context.l10n.qrScannerUpdate),
                ),
              ),
            ],
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
    return AppBottomSheet.show<bool>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.qrScannerAddNodeTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            context.l10n.qrScannerAddNodePrompt(displayName),
            style: TextStyle(color: context.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: AppTheme.spacing16),
          _buildNodeInfoRow(
            context.l10n.qrScannerNodeInfoId,
            '!${nodeNum.toRadixString(16)}',
          ),
          if (longName != null)
            _buildNodeInfoRow(context.l10n.qrScannerNodeInfoName, longName),
          if (shortName != null)
            _buildNodeInfoRow(context.l10n.qrScannerNodeInfoShort, shortName),
          const SizedBox(height: AppTheme.spacing24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: SemanticColors.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                  child: Text(
                    context.l10n.qrScannerCancelAdd,
                    style: TextStyle(color: context.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: context.accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                  child: Text(context.l10n.qrScannerAddNodeConfirm),
                ),
              ),
            ],
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
    final sanitizedLongName = longName != null
        ? sanitizeExternalText(longName)
        : null;
    final sanitizedShortName = shortName != null
        ? sanitizeExternalText(shortName)
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
        context.l10n.qrScannerNodeAddedToFavorites(node.displayName),
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
    } else if (code.startsWith('meshtastic://channel/')) {
      base64Data = code.substring('meshtastic://channel/'.length);
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
    AppLogging.qr('📷 Channel QR Decoded ${bytes.length} bytes');

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
        // Meshtastic firmware stores Primary (index 0) with an empty
        // `name` field by convention — empty name + AQ== PSK = the
        // canonical default LongFast channel. Showing the literal `""`
        // in the snackbar is jarring; fall back to the localized
        // "Primary Channel" label (or `Channel <index>` for unnamed
        // secondaries).
        final displayName = existingChannel.name.isNotEmpty
            ? existingChannel.name
            : (existingChannel.index == 0
                  ? context.l10n.channelsPrimaryChannelName
                  : context.l10n.channelFormDefaultName(existingChannel.index));
        showInfoSnackBar(
          context,
          context.l10n.qrScannerChannelAlreadyExists(displayName),
        );
      }
      return;
    }

    // Name collision with a DIFFERENT PSK — the user is scanning a QR
    // for an existing channel but the encryption key has drifted (or
    // the QR is from a different device). Silently appending at the
    // next free index produces ghost duplicates ("RnsHarness" at slot
    // 1 with key A and "RnsHarness" at slot 2 with key B), which is
    // exactly the bug the user hit. Match the official Meshtastic iOS
    // safety net by detecting the collision and asking the user
    // whether to replace the existing channel in-place. iOS reference:
    // `meshtastic-ios/Meshtastic/Accessory/Accessory Manager/AccessoryManager+ToRadio.swift:480-491`
    // ("When adding channels the names must be unique").
    final scannedName = channelName;
    final nameCollisionTarget = (scannedName != null && scannedName.isNotEmpty)
        ? channels.firstWhereOrNull((c) => c.name == scannedName)
        : null;
    if (nameCollisionTarget != null) {
      if (!mounted) return;
      final shouldReplace = await _showChannelNameCollisionSheet(
        existing: nameCollisionTarget,
      );
      if (shouldReplace != true) {
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }
      // User opted to replace — overwrite at the existing index, keep
      // the existing role/uplink/downlink so we don't silently flip
      // any side settings the user already configured locally.
      // `scannedName` is provably non-empty here (we entered this
      // branch only because the name-collision lookup matched), but
      // Dart can't carry that flow-promotion through the await above,
      // so we re-read it from the matched target's name to keep the
      // analyser happy without a `!`.
      final replacementChannel = ChannelConfig(
        index: nameCollisionTarget.index,
        name: nameCollisionTarget.name,
        psk: psk,
        uplink: nameCollisionTarget.uplink,
        downlink: nameCollisionTarget.downlink,
        positionPrecision: nameCollisionTarget.positionPrecision,
        role: nameCollisionTarget.role,
      );
      await _importChannel(replacementChannel);
      return;
    }

    // Find next available slot
    final usedIndices = channels.map((c) => c.index).toSet();
    int newIndex = 1;
    while (usedIndices.contains(newIndex) && newIndex < 8) {
      newIndex++;
    }
    if (newIndex >= 8) throw Exception(context.l10n.qrScannerMaxChannels);

    // The protobuf decode returns "" for an unset name field, not null,
    // so a bare `??` fallback never fires. Empty name → use the
    // localized default ("Imported Channel"). Without this guard the
    // import sheet renders the channel with no displayable name and
    // the receiving radio stores an empty channel name.
    final hasUsableName = channelName != null && channelName.isNotEmpty;
    channel = ChannelConfig(
      index: newIndex,
      name: hasUsableName
          ? channelName
          : context.l10n.qrScannerImportedChannelName,
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
    return AppBottomSheet.show<bool>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.qrScannerImportChannelTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          _buildChannelInfoRow(
            context.l10n.qrScannerChannelInfoName,
            channel.name,
          ),
          const SizedBox(height: AppTheme.spacing8),
          _buildChannelInfoRow('Slot', '${channel.index}'),
          const SizedBox(height: AppTheme.spacing8),
          _buildChannelInfoRow(
            context.l10n.qrScannerChannelInfoEncryption,
            '${channel.psk.length * 8}-bit AES',
          ),
          // Warning for default (insecure) 1-byte key
          if (channel.isDefaultKey) ...[
            const SizedBox(height: AppTheme.spacing12),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              decoration: BoxDecoration(
                color: AppTheme.warningYellow.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                border: Border.all(
                  color: AppTheme.warningYellow.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: AppTheme.warningYellow,
                        size: 18,
                      ),
                      const SizedBox(width: AppTheme.spacing8),
                      Expanded(
                        child: Text(
                          context.l10n.qrScannerChannelDefaultKeyWarning,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacing6),
                  Padding(
                    padding: const EdgeInsets.only(left: 26),
                    child: Text(
                      context.l10n.qrScannerChannelDefaultKeyRecommendation,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppTheme.spacing16),
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing12),
            decoration: BoxDecoration(
              color: context.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radius8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: context.accentColor, size: 18),
                const SizedBox(width: AppTheme.spacing10),
                Expanded(
                  child: Text(
                    context.l10n.qrScannerChannelSyncNotice,
                    style: TextStyle(fontSize: 13, color: context.accentColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, null),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: SemanticColors.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                  child: Text(
                    context.l10n.qrScannerChannelCancel,
                    style: TextStyle(color: context.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: context.accentColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                  child: Text(
                    context.l10n.qrScannerChannelEditFirst,
                    style: TextStyle(color: context.accentColor),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: context.accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                  child: Text(context.l10n.qrScannerChannelImport),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Confirmation sheet shown when a scanned QR's channel name matches
  /// an existing channel but with a different PSK.
  ///
  /// Returns:
  /// - `true` if the user confirms replacement (overwrite at the
  ///   existing channel's slot with the scanned key)
  /// - `null` if the user cancels (or dismisses the sheet)
  ///
  /// Replaces SocialMesh's prior silent "import at next free slot"
  /// behaviour, which produced duplicate channels with the same name
  /// at different indices. Mirrors the safety net the official
  /// Meshtastic iOS app enforces in `AccessoryManager.saveChannelSet`
  /// (Add mode rejects duplicate names with "Channel already exists";
  /// Replace All wipes the channel set). We surface the equivalent
  /// choice as Replace / Cancel — appropriate for the per-channel QR
  /// shape SocialMesh uses today.
  Future<bool?> _showChannelNameCollisionSheet({
    required ChannelConfig existing,
  }) {
    return AppBottomSheet.show<bool>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.qrScannerChannelNameCollisionTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          Text(
            context.l10n.qrScannerChannelNameCollisionBody(
              existing.name,
              existing.index,
            ),
            style: TextStyle(fontSize: 14, color: context.textSecondary),
          ),
          const SizedBox(height: AppTheme.spacing24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, null),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: SemanticColors.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                  child: Text(
                    context.l10n.qrScannerChannelCancel,
                    style: TextStyle(color: context.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: context.accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                  child: Text(
                    context.l10n.qrScannerChannelNameCollisionReplace,
                  ),
                ),
              ),
            ],
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
    // Capture providers before any await
    final connectionState = ref.read(connectionStateProvider);
    final protocol = ref.read(protocolServiceProvider);
    final channelsNotifier = ref.read(channelsProvider.notifier);
    final secureStorage = ref.read(secureStorageProvider);
    final navigator = Navigator.of(context);

    final isConnected = connectionState.maybeWhen(
      data: (state) => state == DeviceConnectionState.connected,
      orElse: () => false,
    );

    if (!isConnected) {
      showErrorSnackBar(context, context.l10n.qrScannerConnectDeviceToImport);
      safeSetState(() => _isProcessing = false);
      return;
    }

    try {
      await protocol.setChannel(channel);
      await Future.delayed(const Duration(milliseconds: 300));
      await protocol.getChannel(channel.index);

      if (!mounted) return;
      channelsNotifier.setChannel(channel);

      if (channel.psk.isNotEmpty) {
        await secureStorage.storeChannelKey(channel.name, channel.psk);
      }

      if (mounted) {
        showSuccessSnackBar(
          context,
          context.l10n.qrScannerChannelImported(channel.name),
        );
        navigator.pop();
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          context.l10n.qrScannerImportFailed(e.toString()),
        );
        safeSetState(() => _isProcessing = false);
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
      // Handle Firestore ID (cloud-stored widget)
      if (parsed.hasWidgetFirestoreId) {
        Navigator.pushNamed(
          context,
          '/widget-import',
          arguments: {'firestoreId': parsed.widgetFirestoreId},
        );
      } else if (parsed.hasWidgetBase64Data) {
        // Handle base64-encoded widget schema (legacy direct import)
        Navigator.pushNamed(
          context,
          '/widget-import',
          arguments: {'base64Data': parsed.widgetBase64Data},
        );
      } else {
        // Handle marketplace widget ID
        Navigator.pushNamed(
          context,
          '/widget-detail',
          arguments: {'widgetId': parsed.widgetId},
        );
      }
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
    final accentColor = context.accentColor;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          context.l10n.qrScannerTitle,
          style: const TextStyle(color: Colors.white),
        ),
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
          QrScannerOverlay(
            cornerColor: _isProcessing ? AppTheme.successGreen : accentColor,
          ),
          if (_isProcessing) const Center(child: LoadingIndicator(size: 48)),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_scanner, size: 32, color: accentColor),
                  const SizedBox(height: AppTheme.spacing12),
                  Text(
                    context.l10n.qrScannerPrompt,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  Text(
                    context.l10n.qrScannerSupportsHint,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
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
