// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Full-screen compose modal for new threads and replies.
//
// Visually identical to the Signals "Go Active" screen: centered
// title + section subtitle, GradientBorderContainer wrapping a large
// borderless text area, circular character counter on the bottom
// action row, short-status card for thread title, shield info banner,
// and a gradient "Post thread" / "Post reply" button in a
// BottomActionBar. Consistency wins.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/gradient_border_container.dart';

enum NodeBoardComposeKind { thread, reply }

class NodeBoardComposeResult {
  final String? title;
  final String body;

  const NodeBoardComposeResult({this.title, required this.body});
}

/// Launches the compose screen as a fullscreen modal route. Returns the
/// result (or null if the user cancelled).
Future<NodeBoardComposeResult?> pushNodeBoardComposeScreen({
  required BuildContext context,
  required NodeBoardComposeKind kind,
  required String sectionTitle,
}) {
  AppLogging.nodeBoard('Compose: opening kind=$kind section=$sectionTitle');
  return Navigator.of(context).push<NodeBoardComposeResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          NodeBoardComposeScreen(kind: kind, sectionTitle: sectionTitle),
    ),
  );
}

class NodeBoardComposeScreen extends ConsumerStatefulWidget {
  final NodeBoardComposeKind kind;
  final String sectionTitle;

  const NodeBoardComposeScreen({
    super.key,
    required this.kind,
    required this.sectionTitle,
  });

  @override
  ConsumerState<NodeBoardComposeScreen> createState() =>
      _NodeBoardComposeScreenState();
}

class _NodeBoardComposeScreenState extends ConsumerState<NodeBoardComposeScreen>
    with LifecycleSafeMixin<NodeBoardComposeScreen> {
  static const int _titleMaxLength = 200;
  static const int _bodyMaxLength = 50000;

  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _titleFocus = FocusNode();
  final _bodyFocus = FocusNode();
  bool _canSubmit = false;

  bool get _isThread => widget.kind == NodeBoardComposeKind.thread;

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(_onChanged);
    _bodyCtrl.addListener(_onChanged);
    _titleFocus.addListener(_onFocusChanged);
    _bodyFocus.addListener(_onFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isThread) {
        _titleFocus.requestFocus();
      } else {
        _bodyFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_onChanged);
    _bodyCtrl.removeListener(_onChanged);
    _titleFocus.removeListener(_onFocusChanged);
    _bodyFocus.removeListener(_onFocusChanged);
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _titleFocus.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    // Rebuild so the character counter switches to the focused field.
    safeSetState(() {});
  }

  /// The field the character counter should track — the currently-focused
  /// one, falling back to the body (the primary field) when neither is
  /// focused.
  bool get _counterTracksTitle => _isThread && _titleFocus.hasFocus;

  int get _activeFieldMax =>
      _counterTracksTitle ? _titleMaxLength : _bodyMaxLength;

  int get _activeFieldUsed =>
      _counterTracksTitle ? _titleCtrl.text.length : _bodyCtrl.text.length;

  void _onChanged() {
    final titleOk = !_isThread || _titleCtrl.text.trim().isNotEmpty;
    final bodyOk = _bodyCtrl.text.trim().isNotEmpty;
    final next = titleOk && bodyOk;
    if (next != _canSubmit) {
      safeSetState(() => _canSubmit = next);
    } else {
      // Trigger rebuild so the character counter keeps up with keystrokes.
      safeSetState(() {});
    }
  }

  void _submit() {
    if (!_canSubmit) return;
    AppLogging.nodeBoard(
      'Compose: submitting kind=${widget.kind} section=${widget.sectionTitle}',
    );
    HapticFeedback.mediumImpact();
    safeNavigatorPop(
      NodeBoardComposeResult(
        title: _isThread ? _titleCtrl.text.trim() : null,
        body: _bodyCtrl.text.trim(),
      ),
    );
  }

  void _dismissKeyboard() {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    // lint-allow: hardcoded-string
    final screenTitle = _isThread ? 'New thread' : 'New reply';
    // lint-allow: hardcoded-string
    final submitLabel = _isThread ? 'Post thread' : 'Post reply';
    final submitIcon = _isThread ? Icons.forum_outlined : Icons.reply_outlined;
    // lint-allow: hardcoded-string
    final bodyHint = _isThread ? 'What\'s on your mind?' : 'Write a reply...';
    // lint-allow: hardcoded-string
    final infoLabel = _isThread
        ? 'Posting in ${widget.sectionTitle}'
        : 'Replying in ${widget.sectionTitle}';

    return GlassScaffold(
      leading: IconButton(
        icon: Icon(Icons.close, color: context.textPrimary),
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop();
        },
      ),
      centerTitle: true,
      titleWidget: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            screenTitle,
            style: TextStyle(
              color: context.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          Text(
            // lint-allow: hardcoded-string
            '#${widget.sectionTitle.toUpperCase()}',
            style: TextStyle(
              color: context.accentColor,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isThread ? Icons.forum_outlined : Icons.reply_outlined,
            color: context.textSecondary,
            size: 20,
          ),
          // lint-allow: hardcoded-string
          tooltip: _isThread ? 'Thread' : 'Reply',
          onPressed: null,
        ),
      ],
      slivers: [
        SliverFillRemaining(
          hasScrollBody: true,
          child: Column(
            children: [
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
                        GradientBorderContainer(
                          borderRadius: 24,
                          borderWidth: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_isThread) ...[
                                _TitleField(
                                  controller: _titleCtrl,
                                  focusNode: _titleFocus,
                                  maxLength: _titleMaxLength,
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacing20,
                                  ),
                                  child: Divider(
                                    height: 1,
                                    color: context.border.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                              _BodyField(
                                controller: _bodyCtrl,
                                focusNode: _bodyFocus,
                                hint: bodyHint,
                                maxLength: _bodyMaxLength,
                              ),
                              _ComposeActionBar(
                                remaining: _activeFieldMax - _activeFieldUsed,
                                maxLength: _activeFieldMax,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing16),
                        _InfoBanner(label: infoLabel),
                      ],
                    ),
                  ),
                ),
              ),
              BottomActionBar(
                child: BouncyTap(
                  onTap: _canSubmit ? _submit : null,
                  child: _SubmitButton(
                    enabled: _canSubmit,
                    icon: submitIcon,
                    label: submitLabel,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Title field — borderless, 20px bold, lives inside the gradient container.
// ---------------------------------------------------------------------------

class _TitleField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int maxLength;

  const _TitleField({
    required this.controller,
    required this.focusNode,
    required this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing20,
        AppTheme.spacing16,
        AppTheme.spacing20,
        AppTheme.spacing8,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLength: maxLength,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        textCapitalization: TextCapitalization.sentences,
        inputFormatters: [LengthLimitingTextInputFormatter(maxLength)],
        style: TextStyle(
          color: context.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
        decoration: InputDecoration(
          // lint-allow: hardcoded-string
          hintText: 'Thread title',
          hintStyle: TextStyle(
            color: context.textTertiary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          counterText: '',
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body field — borderless multi-line text area, 16px regular.
// ---------------------------------------------------------------------------

class _BodyField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final int maxLength;

  const _BodyField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing20,
        AppTheme.spacing16,
        AppTheme.spacing20,
        AppTheme.spacing8,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLines: 8,
        minLines: 5,
        maxLength: maxLength,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        textCapitalization: TextCapitalization.sentences,
        inputFormatters: [LengthLimitingTextInputFormatter(maxLength)],
        style: TextStyle(color: context.textPrimary, fontSize: 16, height: 1.4),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: context.textTertiary, fontSize: 16),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          counterText: '',
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom action row inside the gradient container — circular character
// counter. Colors follow the same thresholds as Signals.
// ---------------------------------------------------------------------------

class _ComposeActionBar extends StatelessWidget {
  final int remaining;
  final int maxLength;

  const _ComposeActionBar({required this.remaining, required this.maxLength});

  @override
  Widget build(BuildContext context) {
    final used = (maxLength - remaining).clamp(0, maxLength);
    final progress = (used / maxLength).clamp(0.0, 1.0);
    final indicatorColor = remaining < 0
        ? AppTheme.errorRed
        : remaining < 20
        ? AccentColors.orange
        : context.accentColor;
    final textColor = remaining < 0
        ? AppTheme.errorRed
        : remaining < 20
        ? AccentColors.orange
        : context.textTertiary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing12,
        0,
        AppTheme.spacing12,
        AppTheme.spacing10,
      ),
      child: Row(
        children: [
          const Spacer(),
          SizedBox(
            width: 36,
            height: 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2.5,
                  backgroundColor: context.border.withValues(alpha: 0.2),
                  color: indicatorColor,
                ),
                Text(
                  '$remaining',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info banner — shield icon + muted text, matches Signals info rows.
// ---------------------------------------------------------------------------

class _InfoBanner extends StatelessWidget {
  final String label;

  const _InfoBanner({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, size: 14, color: context.textTertiary),
        const SizedBox(width: AppTheme.spacing8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: context.textTertiary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Gradient submit button — full-width, matches Create Signal pattern.
// ---------------------------------------------------------------------------

class _SubmitButton extends StatelessWidget {
  final bool enabled;
  final IconData icon;
  final String label;

  const _SubmitButton({
    required this.enabled,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
      decoration: BoxDecoration(
        gradient: enabled
            ? LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [accent, accent.withValues(alpha: 0.75)],
              )
            : null,
        color: enabled ? null : context.border.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 18,
            color: enabled ? SemanticColors.onAccent : context.textTertiary,
          ),
          const SizedBox(width: AppTheme.spacing8),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: enabled ? SemanticColors.onAccent : context.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
