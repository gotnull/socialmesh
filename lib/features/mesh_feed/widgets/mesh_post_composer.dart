// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Full-screen composer for creating new mesh feed posts.
///
/// Follows the Create Signal pattern: GlassScaffold (slivers) with
/// SliverFillRemaining → Column → [Expanded(SingleChildScrollView), BottomActionBar]
/// so the post button stays pinned above the keyboard.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/gradient_border_container.dart';
import '../../../services/haptic_service.dart';
import '../../../services/mesh_feed/mesh_post.dart';
import '../../../utils/snackbar.dart';

/// Shows the mesh post composer as a full-screen route.
///
/// Returns `true` if a post was successfully created, `null` otherwise.
Future<bool?> showMeshPostComposer({
  required BuildContext context,
  required Future<bool> Function(String content, MeshPostTtl ttl) onPost,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => _MeshPostComposerScreen(onPost: onPost)),
  );
}

class _MeshPostComposerScreen extends ConsumerStatefulWidget {
  const _MeshPostComposerScreen({required this.onPost});

  final Future<bool> Function(String content, MeshPostTtl ttl) onPost;

  @override
  ConsumerState<_MeshPostComposerScreen> createState() =>
      _MeshPostComposerScreenState();
}

class _MeshPostComposerScreenState
    extends ConsumerState<_MeshPostComposerScreen>
    with LifecycleSafeMixin<_MeshPostComposerScreen> {
  static const _maxLength = 200;

  final _controller = TextEditingController();
  MeshPostTtl _selectedTtl = MeshPostTtl.hours24;
  bool _isPosting = false;

  int get _remaining => _maxLength - _controller.text.length;
  bool get _hasContent => _controller.text.trim().isNotEmpty;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  Future<void> _handlePost() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;

    safeSetState(() => _isPosting = true);
    ref.haptics.buttonTap();

    final nav = Navigator.of(context);
    final l10n = AppLocalizations.of(context);

    try {
      final success = await widget.onPost(content, _selectedTtl);
      if (!mounted) return;

      if (success) {
        showSuccessSnackBar(context, l10n.meshFeedPostCreated);
        nav.pop(true);
      } else {
        showErrorSnackBar(context, l10n.meshFeedPostFailed);
        safeSetState(() => _isPosting = false);
      }
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, l10n.meshFeedPostFailed);
      safeSetState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final gradientColors = AccentColors.gradientFor(context.accentColor);

    return GlassScaffold(
      leading: IconButton(
        icon: Icon(
          Icons.close,
          color: _isPosting ? context.textTertiary : context.textPrimary,
        ),
        onPressed: _isPosting ? null : () => Navigator.of(context).pop(),
      ),
      centerTitle: true,
      title: l10n.meshFeedComposeTitle,
      slivers: [
        SliverFillRemaining(
          hasScrollBody: true,
          child: Column(
            children: [
              // Scrollable content
              Expanded(
                child: GestureDetector(
                  onTap: _dismissKeyboard,
                  behavior: HitTestBehavior.opaque,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.spacing20,
                      AppTheme.spacing8,
                      AppTheme.spacing20,
                      AppTheme.spacing20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Content input — GradientBorderContainer
                        GradientBorderContainer(
                          borderRadius: 24,
                          borderWidth: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppTheme.spacing20,
                                  AppTheme.spacing16,
                                  AppTheme.spacing20,
                                  AppTheme.spacing8,
                                ),
                                child: TextField(
                                  controller: _controller,
                                  maxLines: 5,
                                  minLines: 3,
                                  maxLength: _maxLength,
                                  maxLengthEnforcement:
                                      MaxLengthEnforcement.enforced,
                                  autofocus: true,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(
                                      _maxLength,
                                    ),
                                  ],
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 16,
                                    height: 1.4,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: l10n.meshFeedComposeHint,
                                    hintStyle: TextStyle(
                                      color: context.textTertiary,
                                      fontSize: 16,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                    counterText: '',
                                  ),
                                  onChanged: (_) => safeSetState(() {}),
                                ),
                              ),

                              // Character counter
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppTheme.spacing20,
                                  0,
                                  AppTheme.spacing20,
                                  AppTheme.spacing12,
                                ),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '$_remaining/$_maxLength',
                                    style: TextStyle(
                                      color: _remaining < 20
                                          ? AccentColors.orange
                                          : context.textTertiary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppTheme.spacing16),

                        // TTL label
                        Text(
                          l10n.meshFeedTtlLabel,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: context.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing8),

                        // TTL selector chips
                        Wrap(
                          spacing: AppTheme.spacing8,
                          runSpacing: AppTheme.spacing8,
                          children: MeshPostTtl.values.map((ttl) {
                            final isSelected = ttl == _selectedTtl;
                            return BouncyTap(
                              onTap: () {
                                ref.haptics.toggle();
                                safeSetState(() => _selectedTtl = ttl);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacing16,
                                  vertical: AppTheme.spacing10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? context.accentColor.withValues(
                                          alpha: 0.15,
                                        )
                                      : context.card,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radius20,
                                  ),
                                  border: Border.all(
                                    color: isSelected
                                        ? context.accentColor
                                        : context.border.withValues(alpha: 0.5),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Text(
                                  _ttlLabel(ttl, l10n),
                                  style: TextStyle(
                                    color: isSelected
                                        ? context.accentColor
                                        : context.textSecondary,
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: AppTheme.spacing12),

                        // Propagation note
                        Text(
                          l10n.meshFeedPropagationNote(_maxLength),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.textTertiary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Post button — fixed above keyboard, matching Create Signal
              BottomActionBar(
                child: BouncyTap(
                  onTap: _hasContent && !_isPosting ? _handlePost : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.spacing16,
                    ),
                    decoration: BoxDecoration(
                      gradient: _hasContent && !_isPosting
                          ? LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [gradientColors[0], gradientColors[1]],
                            )
                          : null,
                      color: _hasContent && !_isPosting
                          ? null
                          : context.border.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(AppTheme.radius16),
                      boxShadow: _hasContent && !_isPosting
                          ? [
                              BoxShadow(
                                color: gradientColors[0].withValues(alpha: 0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: _isPosting
                        ? const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.send_rounded,
                                size: 20,
                                color: _hasContent
                                    ? Colors.white
                                    : context.textTertiary,
                              ),
                              const SizedBox(width: AppTheme.spacing10),
                              Text(
                                l10n.meshFeedPostButton,
                                style: TextStyle(
                                  color: _hasContent
                                      ? Colors.white
                                      : context.textTertiary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _ttlLabel(MeshPostTtl ttl, AppLocalizations l10n) {
    return switch (ttl) {
      MeshPostTtl.hours1 => l10n.meshFeedTtl1h,
      MeshPostTtl.hours6 => l10n.meshFeedTtl6h,
      MeshPostTtl.hours24 => l10n.meshFeedTtl24h,
      MeshPostTtl.days3 => l10n.meshFeedTtl3d,
      MeshPostTtl.days7 => l10n.meshFeedTtl7d,
    };
  }
}
