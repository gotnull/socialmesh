// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/fullscreen_gallery.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/search_filter_header.dart';
import '../../core/widgets/section_header.dart';
import '../../utils/snackbar.dart';
import 'bug_report_repository.dart';

/// Filter options for the bug reports list.
enum _BugReportFilter { all, open, responded, awaiting, resolved }

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
  _BugReportFilter _activeFilter = _BugReportFilter.all;

  @override
  void initState() {
    super.initState();
    // Force a fresh stream when the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.invalidate(myBugReportsProvider);
      }
    });
  }

  List<BugReport> _applyFilter(List<BugReport> reports) {
    switch (_activeFilter) {
      case _BugReportFilter.all:
        return reports;
      case _BugReportFilter.open:
        return reports.where((r) => r.status == BugReportStatus.open).toList();
      case _BugReportFilter.responded:
        return reports
            .where((r) => r.status == BugReportStatus.responded)
            .toList();
      case _BugReportFilter.awaiting:
        return reports
            .where((r) => r.status == BugReportStatus.userReplied)
            .toList();
      case _BugReportFilter.resolved:
        return reports
            .where((r) => r.status == BugReportStatus.resolved)
            .toList();
    }
  }

  Color _filterColor(BuildContext context, _BugReportFilter filter) {
    switch (filter) {
      case _BugReportFilter.all:
        return AppTheme.primaryBlue;
      case _BugReportFilter.open:
        return context.textTertiary;
      case _BugReportFilter.responded:
        return context.accentColor;
      case _BugReportFilter.awaiting:
        return AccentColors.yellow;
      case _BugReportFilter.resolved:
        return AppTheme.successGreen;
    }
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

          // Compute counts per status for filter badges
          final openCount = reports
              .where((r) => r.status == BugReportStatus.open)
              .length;
          final respondedCount = reports
              .where((r) => r.status == BugReportStatus.responded)
              .length;
          final awaitingCount = reports
              .where((r) => r.status == BugReportStatus.userReplied)
              .length;
          final resolvedCount = reports
              .where((r) => r.status == BugReportStatus.resolved)
              .length;

          final filtered = _applyFilter(reports);

          return Column(
            children: [
              // Filter chips row
              SizedBox(
                height: SearchFilterLayout.chipRowHeight,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(
                    horizontal: SearchFilterLayout.horizontalPadding,
                  ),
                  children: [
                    SectionFilterChip(
                      label: 'All',
                      count: reports.length,
                      isSelected: _activeFilter == _BugReportFilter.all,
                      color: _filterColor(context, _BugReportFilter.all),
                      onTap: () => safeSetState(
                        () => _activeFilter = _BugReportFilter.all,
                      ),
                    ),
                    SizedBox(width: SearchFilterLayout.chipSpacing),
                    SectionFilterChip(
                      label: 'Open',
                      count: openCount,
                      isSelected: _activeFilter == _BugReportFilter.open,
                      color: _filterColor(context, _BugReportFilter.open),
                      onTap: () => safeSetState(
                        () => _activeFilter = _BugReportFilter.open,
                      ),
                    ),
                    SizedBox(width: SearchFilterLayout.chipSpacing),
                    SectionFilterChip(
                      label: 'Responded',
                      count: respondedCount,
                      isSelected: _activeFilter == _BugReportFilter.responded,
                      color: _filterColor(context, _BugReportFilter.responded),
                      onTap: () => safeSetState(
                        () => _activeFilter = _BugReportFilter.responded,
                      ),
                    ),
                    SizedBox(width: SearchFilterLayout.chipSpacing),
                    SectionFilterChip(
                      label: 'Awaiting',
                      count: awaitingCount,
                      isSelected: _activeFilter == _BugReportFilter.awaiting,
                      color: _filterColor(context, _BugReportFilter.awaiting),
                      onTap: () => safeSetState(
                        () => _activeFilter = _BugReportFilter.awaiting,
                      ),
                    ),
                    SizedBox(width: SearchFilterLayout.chipSpacing),
                    SectionFilterChip(
                      label: 'Resolved',
                      count: resolvedCount,
                      isSelected: _activeFilter == _BugReportFilter.resolved,
                      color: _filterColor(context, _BugReportFilter.resolved),
                      icon: Icons.check_circle_outline,
                      onTap: () => safeSetState(
                        () => _activeFilter = _BugReportFilter.resolved,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // Filtered reports list
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.filter_list_off,
                              size: 48,
                              color: context.textTertiary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No reports match this filter',
                              style: TextStyle(
                                fontSize: 15,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(myBugReportsProvider);
                          await ref.read(myBugReportsProvider.future);
                        },
                        color: context.accentColor,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final report = filtered[index];
                            final isInitialReport =
                                widget.initialReportId == report.id;
                            return _BugReportCard(
                              report: report,
                              initiallyExpanded: isInitialReport,
                            );
                          },
                        ),
                      ),
              ),
            ],
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
  bool _wasReplyFocusedOnTapDown = false;

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
                child: GestureDetector(
                  onTapDown: (_) {
                    // Capture focus state before onTapOutside clears it
                    _wasReplyFocusedOnTapDown = _replyFocusNode.hasFocus;
                  },
                  onTap: () {
                    // If the reply field was focused when the tap started,
                    // swallow the tap — onTapOutside already dismissed the
                    // keyboard so no further action is needed.
                    if (_wasReplyFocusedOnTapDown) return;
                    FullscreenGallery.show(
                      context,
                      images: [report.screenshotUrl!],
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: context.background,
                        border: Border.all(
                          color: context.border.withValues(alpha: 0.3),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            report.screenshotUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 200,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return _ScreenshotSkeleton(
                                borderColor: context.border,
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                Center(
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
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.fullscreen_rounded,
                                color: Colors.white70,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _replyController,
                    focusNode: _replyFocusNode,
                    maxLines: 6,
                    minLines: 3,
                    maxLength: 2000,
                    enabled: !_isSending,
                    decoration: InputDecoration(
                      hintText: 'Write a reply...',
                      hintStyle: TextStyle(color: context.textTertiary),
                      filled: true,
                      fillColor: context.background,
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: context.border.withValues(alpha: 0.5),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: context.border.withValues(alpha: 0.5),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: context.accentColor.withValues(alpha: 0.6),
                        ),
                      ),
                      counterText: '',
                    ),
                    style: TextStyle(fontSize: 14, color: context.textPrimary),
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _replyController,
                        builder: (context, value, _) => Text(
                          '${value.text.length}/2000',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.textTertiary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: _isSending
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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

/// Shimmer skeleton shown while a screenshot is loading.
class _ScreenshotSkeleton extends StatefulWidget {
  const _ScreenshotSkeleton({required this.borderColor});

  final Color borderColor;

  @override
  State<_ScreenshotSkeleton> createState() => _ScreenshotSkeletonState();
}

class _ScreenshotSkeletonState extends State<_ScreenshotSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final shimmerOpacity = 0.04 + (_animation.value * 0.08);
        return Container(
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              // Shimmer gradient overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      begin: Alignment(-1.0 + (_animation.value * 3), -0.3),
                      end: Alignment(-0.5 + (_animation.value * 3), 0.3),
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: shimmerOpacity),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
              // Placeholder content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_outlined,
                      size: 32,
                      color: context.textTertiary.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Loading screenshot...',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
