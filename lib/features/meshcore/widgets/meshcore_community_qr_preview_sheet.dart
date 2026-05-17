// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q7: preview sheet that surfaces a freshly-scanned community
// payload before any channel is written to the radio. The user
// taps "Add" per row — never a bulk-accept button — so each PSK
// import is a deliberate, consented action. PSKs are previewed as
// the first 8 hex chars + ellipsis (matches the diagnostics-bundle
// fingerprint convention).
//
// Slot allocation is left to the user via a slot picker on the
// channel-edit sheet. From the preview the user accepts the
// derived channel; routing into a free slot is handled by
// `MeshCoreChannelsNotifier.setChannel` downstream.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../../../models/meshcore_channel.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../services/meshcore/storage/meshcore_community_qr_payload.dart';
import '../../../utils/snackbar.dart';

/// Show the preview sheet for a parsed community payload. Returns
/// `true` if the user accepted at least one channel; the caller can
/// use this to dismiss the scanner screen.
Future<bool?> showMeshCoreCommunityQrPreviewSheet(
  BuildContext context, {
  required MeshCoreCommunityPayload payload,
}) {
  return AppBottomSheet.showScrollable<bool>(
    context: context,
    initialChildSize: 0.85,
    minChildSize: 0.5,
    maxChildSize: 0.95,
    builder: (controller) =>
        _CommunityPreviewSheet(payload: payload, scrollController: controller),
  );
}

class _CommunityPreviewSheet extends ConsumerStatefulWidget {
  final MeshCoreCommunityPayload payload;
  final ScrollController scrollController;
  const _CommunityPreviewSheet({
    required this.payload,
    required this.scrollController,
  });

  @override
  ConsumerState<_CommunityPreviewSheet> createState() =>
      _CommunityPreviewSheetState();
}

class _CommunityPreviewSheetState extends ConsumerState<_CommunityPreviewSheet>
    with LifecycleSafeMixin {
  final TextEditingController _hashtagController = TextEditingController();
  final List<_DerivedRow> _rows = [];
  bool _acceptedAny = false;

  @override
  void initState() {
    super.initState();
    // Seed with the implicit public channel. The user can still tap
    // Decline next to it if they only want hashtag channels.
    _rows.add(
      _DerivedRow(
        tag: kMeshCoreCommunityPublicTag,
        displayName: 'public',
        psk: widget.payload.derivePskFor(kMeshCoreCommunityPublicTag),
        accepted: false,
      ),
    );
  }

  @override
  void dispose() {
    _hashtagController.dispose();
    super.dispose();
  }

  void _addHashtagRow() {
    final raw = _hashtagController.text;
    final tag = normaliseMeshCoreCommunityTag(raw);
    final l10n = context.l10n;
    if (tag.isEmpty) {
      showInfoSnackBar(context, l10n.meshcoreCommunityQrHashtagEmpty);
      return;
    }
    if (_rows.any((r) => r.tag == tag)) {
      showInfoSnackBar(context, l10n.meshcoreCommunityQrHashtagDuplicate);
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _rows.add(
        _DerivedRow(
          tag: tag,
          displayName: tag,
          psk: widget.payload.derivePskFor(tag),
          accepted: false,
        ),
      );
      _hashtagController.clear();
    });
  }

  Future<void> _acceptRow(int index) async {
    final l10n = context.l10n;
    final row = _rows[index];
    HapticFeedback.lightImpact();
    setState(() => row.busy = true);
    try {
      // Pick the next free 0-7 slot at accept time. Computing lazily
      // (not at sheet open) lets successive Adds correctly skip slots
      // that filled mid-session — same logic as the per-channel QR
      // scanner's `newIndex` walk.
      final channelsState = ref.read(meshCoreChannelsProvider);
      final usedIndices = channelsState.channels.map((c) => c.index).toSet();
      var slot = -1;
      for (var i = 0; i < 8; i++) {
        if (!usedIndices.contains(i)) {
          slot = i;
          break;
        }
      }
      if (slot < 0) {
        if (!mounted) return;
        setState(() => row.busy = false);
        showInfoSnackBar(context, l10n.meshcoreCommunityQrNoFreeSlot);
        return;
      }
      final ok = await ref
          .read(meshCoreChannelsProvider.notifier)
          .setChannel(
            MeshCoreChannel(
              index: slot,
              name: row.displayName,
              psk: Uint8List.fromList(row.psk),
            ),
          );
      if (!mounted) return;
      if (ok) {
        setState(() {
          row.accepted = true;
          row.busy = false;
          _acceptedAny = true;
        });
        showSuccessSnackBar(
          context,
          l10n.meshcoreCommunityQrChannelAdded(row.displayName),
        );
      } else {
        setState(() => row.busy = false);
        showErrorSnackBar(context, l10n.meshcoreCommunityQrChannelAddFailed);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => row.busy = false);
      showErrorSnackBar(context, l10n.meshcoreCommunityQrChannelAddFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final payload = widget.payload;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            AppTheme.spacing8,
            AppTheme.spacing16,
            AppTheme.spacing4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.meshcoreCommunityQrPreviewTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.spacing4),
              Text(
                l10n.meshcoreCommunityQrPreviewSubtitle(payload.name),
                style: TextStyle(fontSize: 13, color: context.textTertiary),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: AppTheme.spacing12,
            ),
            children: [
              for (var i = 0; i < _rows.length; i++) ...[
                _rowTile(i),
                const SizedBox(height: AppTheme.spacing8),
              ],
              const SizedBox(height: AppTheme.spacing8),
              _hashtagInputCard(),
              const SizedBox(height: AppTheme.spacing24),
              PrimaryGradientButton(
                label: l10n.meshcoreCommunityQrDone,
                icon: Icons.check_rounded,
                onPressed: () => Navigator.of(context).pop(_acceptedAny),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rowTile(int i) {
    final l10n = context.l10n;
    final row = _rows[i];
    final fingerprint = _pskFingerprint(row.psk);
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                row.tag == kMeshCoreCommunityPublicTag
                    ? Icons.public_rounded
                    : Icons.tag_rounded,
                color: context.accentColor,
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.displayName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing2),
                    Text(
                      l10n.meshcoreCommunityQrPskFingerprint(fingerprint),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
              if (row.accepted)
                Icon(Icons.check_circle_rounded, color: AppTheme.successGreen)
              else if (row.busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                TextButton(
                  onPressed: () => _acceptRow(i),
                  child: Text(l10n.meshcoreCommunityQrAddRow),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hashtagInputCard() {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.meshcoreCommunityQrAddHashtagSection,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hashtagController,
                  maxLength: 32,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addHashtagRow(),
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    hintText: l10n.meshcoreCommunityQrHashtagHint,
                    hintStyle: TextStyle(color: SemanticColors.muted),
                    filled: true,
                    fillColor: context.background,
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                      borderSide: BorderSide(color: context.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                      borderSide: BorderSide(color: context.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                      borderSide: BorderSide(color: context.accentColor),
                    ),
                    prefixIcon: Icon(
                      Icons.tag_rounded,
                      color: context.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              IconButton(
                onPressed: _addHashtagRow,
                icon: const Icon(Icons.add_rounded),
                color: context.accentColor,
                tooltip: l10n.meshcoreCommunityQrAddHashtagButton,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Render the first 8 hex chars of the PSK so the user has a
  /// visual cross-check without seeing the full key.
  String _pskFingerprint(List<int> psk) {
    final buf = StringBuffer();
    for (var i = 0; i < psk.length && i < 4; i++) {
      buf.write(psk[i].toRadixString(16).padLeft(2, '0'));
    }
    buf.write('…');
    return buf.toString();
  }
}

class _DerivedRow {
  final String tag;
  final String displayName;
  final List<int> psk;
  bool accepted;
  bool busy;

  _DerivedRow({
    required this.tag,
    required this.displayName,
    required this.psk,
    required this.accepted,
  }) : busy = false;
}
