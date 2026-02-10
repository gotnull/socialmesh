// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../utils/snackbar.dart';
import 'bug_report_repository.dart';

/// Screen showing the user's submitted bug reports and threaded responses.
class MyBugReportsScreen extends ConsumerStatefulWidget {
  const MyBugReportsScreen({super.key, this.initialReportId});

  /// If provided, scrolls to and expands this specific report on load.
  final String? initialReportId;

  @override
  ConsumerState<MyBugReportsScreen> createState() => _MyBugReportsScreenState();
}

class _MyBugReportsScreenState extends ConsumerState<MyBugReportsScreen>
    with LifecycleSafeMixin<MyBugReportsScreen> {
  @override
  void initState() {
    super.initState();
    // Force a fresh fetch when the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.invalidate(myBugReportsProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(myBugReportsProvider);

    return GlassScaffold.body(
      title: 'My Bug Reports',
      body: reportsAsync.when(
        data: (reports) {
          if (reports.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bug_report_outlined,
                      size: 64,
                      color: context.textTertiary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No bug reports yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Shake your device to report a bug.\n'
                      'Your reports and any responses will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myBugReportsProvider);
              // Wait for the new data to load
              await ref.read(myBugReportsProvider.future);
            },
            color: context.accentColor,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: reports.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final report = reports[index];
                final isInitialReport = widget.initialReportId == report.id;
                return _BugReportCard(
                  report: report,
                  initiallyExpanded: isInitialReport,
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: AppTheme.errorRed),
                const SizedBox(height: 16),
                Text(
                  'Failed to load reports',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: context.textSecondary),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => ref.invalidate(myBugReportsProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Expandable card showing a single bug report with its threaded responses.
class _BugReportCard extends ConsumerStatefulWidget {
  const _BugReportCard({required this.report, this.initiallyExpanded = false});

  final BugReport report;
  final bool initiallyExpanded;

  @override
  ConsumerState<_BugReportCard> createState() => _BugReportCardState();
}

class _BugReportCardState extends ConsumerState<_BugReportCard>
    with LifecycleSafeMixin<_BugReportCard> {
  late bool _isExpanded;
  final _replyController = TextEditingController();
  final _replyFocusNode = FocusNode();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    if (_isExpanded && widget.report.hasUnreadResponses) {
      _markAsRead();
    }
  }

  @override
  void dispose() {
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    if (!widget.report.hasUnreadResponses) return;
    try {
      final repository = ref.read(bugReportRepositoryProvider);
      await repository.markResponsesAsRead(widget.report.id);
    } catch (e) {
      AppLogging.bugReport('Failed to mark as read: $e');
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _isSending) return;

    final repository = ref.read(bugReportRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    safeSetState(() => _isSending = true);

    try {
      await repository.replyToReport(reportId: widget.report.id, message: text);

      if (!mounted) return;
      _replyController.clear();
      _replyFocusNode.unfocus();
      ref.invalidate(myBugReportsProvider);

      messenger.showSnackBar(
        SnackBar(
          content: const Text('Reply sent'),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Failed to send reply: $e');
    } finally {
      if (mounted) {
        safeSetState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final dateFormat = DateFormat('d MMM yyyy, HH:mm');
    final hasResponses = report.responses.isNotEmpty;
    final hasUnread = report.hasUnreadResponses;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasUnread
              ? context.accentColor.withValues(alpha: 0.6)
              : context.border,
          width: hasUnread ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — always visible, tappable to expand
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              safeSetState(() => _isExpanded = !_isExpanded);
              if (_isExpanded && hasUnread) {
                _markAsRead();
              }
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          report.description.length > 80
                              ? '${report.description.substring(0, 77)}...'
                              : report.description,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (hasUnread)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: context.accentColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${report.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: context.textTertiary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _StatusChip(status: report.status),
                      const Spacer(),
                      if (hasResponses) ...[
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 14,
                          color: context.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${report.responses.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Text(
                        dateFormat.format(report.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  if (report.appVersion != null || report.platform != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (report.platform != null) report.platform,
                        if (report.appVersion != null) 'v${report.appVersion}',
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Expanded content — full description + thread + reply box
          if (_isExpanded) ...[
            Divider(height: 1, color: context.border.withValues(alpha: 0.5)),

            // Full description
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Your report',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.textTertiary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                report.description,
                style: TextStyle(
                  fontSize: 14,
                  color: context.textPrimary,
                  height: 1.5,
                ),
              ),
            ),

            // Screenshot thumbnail if present
            if (report.screenshotUrl != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: context.background,
                      border: Border.all(
                        color: context.border.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.network(
                      report.screenshotUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              size: 20,
                              color: context.textTertiary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Screenshot unavailable',
                              style: TextStyle(
                                fontSize: 13,
                                color: context.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],

            // Conversation thread
            if (hasResponses) ...[
              Divider(height: 1, color: context.border.withValues(alpha: 0.5)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'Conversation',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.textTertiary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              ...report.responses.map(
                (response) => _ResponseBubble(response: response),
              ),
              const SizedBox(height: 8),
            ],

            // Reply input
            Divider(height: 1, color: context.border.withValues(alpha: 0.5)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      focusNode: _replyFocusNode,
                      maxLines: 4,
                      minLines: 1,
                      maxLength: 2000,
                      enabled: !_isSending,
                      decoration: InputDecoration(
                        hintText: 'Write a reply...',
                        hintStyle: TextStyle(color: context.textTertiary),
                        filled: true,
                        fillColor: context.background,
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: context.textPrimary,
                      ),
                      onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: _isSending
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            onPressed: _sendReply,
                            icon: Icon(
                              Icons.send_rounded,
                              color: context.accentColor,
                              size: 22,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Styled chip showing the status of a bug report.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final BugReportStatus status;

  Color _color(BuildContext context) {
    switch (status) {
      case BugReportStatus.open:
        return context.textTertiary;
      case BugReportStatus.responded:
        return context.accentColor;
      case BugReportStatus.userReplied:
        return AccentColors.yellow;
      case BugReportStatus.resolved:
        return AppTheme.successGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// A single message bubble in the response thread.
class _ResponseBubble extends StatelessWidget {
  const _ResponseBubble({required this.response});

  final BugReportResponse response;

  @override
  Widget build(BuildContext context) {
    final isFounder = response.isFromFounder;
    final timeFormat = DateFormat('d MMM, HH:mm');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Align(
        alignment: isFounder ? Alignment.centerLeft : Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isFounder
                ? context.accentColor.withValues(alpha: 0.12)
                : context.background,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isFounder ? 4 : 16),
              bottomRight: Radius.circular(isFounder ? 16 : 4),
            ),
            border: Border.all(
              color: isFounder
                  ? context.accentColor.withValues(alpha: 0.25)
                  : context.border.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isFounder ? Icons.support_agent : Icons.person,
                    size: 14,
                    color: isFounder
                        ? context.accentColor
                        : context.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isFounder ? 'Socialmesh' : 'You',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isFounder
                          ? context.accentColor
                          : context.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeFormat.format(response.createdAt),
                    style: TextStyle(fontSize: 10, color: context.textTertiary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
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
        ),
      ),
    );
  }
}
