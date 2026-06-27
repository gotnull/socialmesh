// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Bottom sheet that opens when the user taps the in-app snackbar that
// announces a founder response to one of their bug reports. Shows a
// summary of the report + the most recent founder reply, an inline
// reply field, and a row of secondary actions (view full report, mark
// resolved, notification settings, suppress future in-app snackbars).
// Mirrors the visual contract of NodeNoteEditSheet for the
// header/textarea/save pattern.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../models/user_profile.dart';
import '../../providers/profile_providers.dart';
import '../../utils/snackbar.dart';
import '../../utils/time_format.dart';
import 'bug_report_repository.dart';

class BugResponseQuickSheet extends ConsumerStatefulWidget {
  const BugResponseQuickSheet({
    super.key,
    required this.reportId,
    required this.scrollController,
  });

  final String reportId;
  final ScrollController scrollController;

  static const int replyMaxLength = 2000;

  static Future<void> show({
    required BuildContext context,
    required String reportId,
  }) {
    return AppBottomSheet.showScrollable<void>(
      context: context,
      initialChildSize: 0.7,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (scrollController) => BugResponseQuickSheet(
        reportId: reportId,
        scrollController: scrollController,
      ),
    );
  }

  @override
  ConsumerState<BugResponseQuickSheet> createState() =>
      _BugResponseQuickSheetState();
}

class _BugResponseQuickSheetState extends ConsumerState<BugResponseQuickSheet>
    with LifecycleSafeMixin<BugResponseQuickSheet> {
  late final TextEditingController _replyController;
  late final FocusNode _replyFocusNode;

  BugReport? _report;
  bool _loading = true;
  bool _loadFailed = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _replyController = TextEditingController();
    _replyFocusNode = FocusNode();
    _fetchReport();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchReport() async {
    try {
      final report = await ref
          .read(bugReportRepositoryProvider)
          .fetchReport(widget.reportId);
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
        _loadFailed = report == null;
      });
      if (report != null) {
        // Best-effort mark-as-read; failures don't break the sheet.
        unawaited(
          ref.read(bugReportRepositoryProvider).markResponsesAsRead(report.id),
        );
      }
    } catch (e) {
      AppLogging.bugReport('BugResponseQuickSheet: fetch failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _sending) return;
    HapticFeedback.selectionClick();
    setState(() => _sending = true);
    try {
      await ref
          .read(bugReportRepositoryProvider)
          .replyToReport(reportId: widget.reportId, message: text);
      if (!mounted) return;
      _replyController.clear();
      safeNavigatorPop();
      showGlobalSuccessSnackBar(context.l10n.bugResponseSheetReplySent);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showGlobalErrorSnackBar(context.l10n.bugResponseSheetReplyFailed('$e'));
    }
  }

  Future<void> _viewFullReport() async {
    HapticFeedback.selectionClick();
    final navigator = Navigator.of(context);
    final id = widget.reportId;
    safeNavigatorPop();
    await navigator.pushNamed(
      '/my-bug-reports',
      arguments: {'reportId': id, 'focusReply': true},
    );
  }

  Future<void> _disableInAppSnackbars() async {
    HapticFeedback.selectionClick();
    final notifier = ref.read(userProfileProvider.notifier);
    final current = ref.read(userProfileProvider).value;
    final updated = (current?.preferences ?? const UserPreferences()).copyWith(
      bugResponseSnackbarsDisabled: true,
    );
    try {
      await notifier.updatePreferences(updated);
      if (!mounted) return;
      safeNavigatorPop();
      showGlobalSuccessSnackBar(context.l10n.bugResponseSheetSnackbarsDisabled);
    } catch (e) {
      AppLogging.bugReport(
        'BugResponseQuickSheet: failed to update preferences: $e',
      );
      if (!mounted) return;
      showGlobalErrorSnackBar('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        0,
        AppTheme.spacing16,
        AppTheme.spacing16,
      ),
      child: ListView(
        controller: widget.scrollController,
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(),
          const SizedBox(height: AppTheme.spacing16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppTheme.spacing24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_loadFailed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing12),
              child: Text(
                context.l10n.bugResponseSheetLoadFailed,
                style: TextStyle(color: context.textSecondary, fontSize: 13),
              ),
            )
          else ...[
            _buildSummaryCard(),
            const SizedBox(height: AppTheme.spacing12),
            _buildLatestResponseCard(),
            const SizedBox(height: AppTheme.spacing16),
            _buildReplyField(),
            const SizedBox(height: AppTheme.spacing8),
            _buildSendButton(),
          ],
          const SizedBox(height: AppTheme.spacing16),
          Divider(color: context.border, height: 1),
          const SizedBox(height: AppTheme.spacing8),
          _buildActionRow(
            icon: Icons.open_in_new_rounded,
            label: context.l10n.bugResponseSheetViewFull,
            onTap: _viewFullReport,
          ),
          _buildActionRow(
            icon: Icons.notifications_off_outlined,
            label: context.l10n.bugResponseSheetDisableSnackbars,
            onTap: _disableInAppSnackbars,
            destructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.bug_report, size: 20, color: AccentColors.magenta),
        const SizedBox(width: AppTheme.spacing8),
        Expanded(
          child: Text(
            context.l10n.bugResponseSheetTitle,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final report = _report!;
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
                Icons.description_outlined,
                size: 14,
                color: context.textTertiary,
              ),
              const SizedBox(width: AppTheme.spacing6),
              Expanded(
                child: Text(
                  context.l10n.bugResponseSheetReportedOn(
                    AppTimeFormat.withDatePrefix(
                      context,
                      '${AppTimeFormat.fullDatePattern(context)},',
                    ).format(report.createdAt),
                  ),
                  style: TextStyle(fontSize: 11, color: context.textTertiary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing6),
          Text(
            report.description,
            style: TextStyle(
              fontSize: 13,
              color: context.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestResponseCard() {
    final response = _latestFounderResponse();
    if (response == null) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: AccentColors.magenta.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(
          color: AccentColors.magenta.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.reply_rounded, size: 14, color: AccentColors.magenta),
              const SizedBox(width: AppTheme.spacing6),
              Text(
                response.from.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AccentColors.magenta,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                AppTimeFormat.withDatePrefix(
                  context,
                  '${AppTimeFormat.monthDayPattern(context)},',
                ).format(response.createdAt),
                style: TextStyle(fontSize: 11, color: context.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            response.message,
            style: TextStyle(
              fontSize: 14,
              color: context.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.bugResponseSheetReplyLabel.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.textTertiary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AppTheme.spacing8),
        TextField(
          controller: _replyController,
          focusNode: _replyFocusNode,
          maxLines: 4,
          minLines: 2,
          maxLength: BugResponseQuickSheet.replyMaxLength,
          textInputAction: TextInputAction.newline,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          style: TextStyle(fontSize: 14, color: context.textPrimary),
          decoration: InputDecoration(
            hintText: context.l10n.bugResponseSheetReplyHint,
            hintStyle: TextStyle(fontSize: 14, color: context.textTertiary),
            filled: true,
            fillColor: context.background,
            contentPadding: const EdgeInsets.all(AppTheme.spacing12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius12),
              borderSide: BorderSide(
                color: context.border.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius12),
              borderSide: BorderSide(
                color: context.border.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius12),
              borderSide: BorderSide(
                color: AccentColors.magenta.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            counterText: '',
          ),
        ),
        const SizedBox(height: AppTheme.spacing4),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _replyController,
          builder: (context, value, _) {
            final remaining =
                BugResponseQuickSheet.replyMaxLength -
                value.text.characters.length;
            final low = remaining < 80;
            return Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$remaining',
                style: TextStyle(
                  fontSize: 11,
                  color: low ? AccentColors.orange : context.textTertiary,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSendButton() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _replyController,
      builder: (context, value, _) {
        final hasText = value.text.trim().isNotEmpty;
        final enabled = hasText && !_sending;
        return Material(
          color: AccentColors.magenta.withValues(alpha: enabled ? 1.0 : 0.3),
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          child: InkWell(
            onTap: enabled ? _sendReply : null,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing16,
                vertical: AppTheme.spacing12,
              ),
              alignment: Alignment.center,
              child: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      context.l10n.bugResponseSheetSend,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final color = destructive ? AppTheme.errorRed : context.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing8,
            vertical: AppTheme.spacing12,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: context.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  BugReportResponse? _latestFounderResponse() {
    final report = _report;
    if (report == null) return null;
    for (final r in report.responses.reversed) {
      if (r.from == 'founder') return r;
    }
    return null;
  }
}
