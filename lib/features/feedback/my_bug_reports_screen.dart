// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import '../../core/l10n/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/time_format.dart';

import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/fullscreen_gallery.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/screenshot_thumbnail.dart';
import '../../core/widgets/search_filter_header.dart';
import '../../core/widgets/status_filter_chip.dart';
import '../../utils/snackbar.dart';
import 'bug_report_repository.dart';

/// Filter options for the bug reports list.
enum _BugReportFilter { all, open, responded, awaiting, resolved }

/// Screen showing the user's submitted bug reports and threaded responses.
class MyBugReportsScreen extends ConsumerStatefulWidget {
  const MyBugReportsScreen({
    super.key,
    this.initialReportId,
    this.initialFocusReply = false,
  });

  /// If provided, scrolls to and expands this specific report on load.
  final String? initialReportId;

  /// When true, the matching card auto-focuses its reply field after the
  /// scroll-into-view animation. Used by the bug-response quick sheet's
  /// "View full bug report" action so the user can reply immediately.
  final bool initialFocusReply;

  @override
  ConsumerState<MyBugReportsScreen> createState() => _MyBugReportsScreenState();
}

class _MyBugReportsScreenState extends ConsumerState<MyBugReportsScreen>
    with LifecycleSafeMixin<MyBugReportsScreen> {
  _BugReportFilter _activeFilter = _BugReportFilter.all;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  List<BugReport> _applySearch(List<BugReport> reports) {
    if (_searchQuery.isEmpty) return reports;
    final query = _searchQuery.toLowerCase();
    return reports.where((r) {
      return r.description.toLowerCase().contains(query) ||
          r.id.toLowerCase().contains(query) ||
          (r.appVersion?.toLowerCase().contains(query) ?? false) ||
          (r.platform?.toLowerCase().contains(query) ?? false) ||
          r.status.label.toLowerCase().contains(query) ||
          r.responses.any((resp) => resp.message.toLowerCase().contains(query));
    }).toList();
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

  List<Widget> _buildFilterChips(
    BuildContext context,
    List<BugReport> reports,
  ) {
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

    return [
      StatusFilterChip(
        label: context.l10n.feedbackFilterAll,
        count: reports.length,
        isSelected: _activeFilter == _BugReportFilter.all,
        color: _filterColor(context, _BugReportFilter.all),
        onTap: () => safeSetState(() => _activeFilter = _BugReportFilter.all),
      ),
      StatusFilterChip(
        label: context.l10n.feedbackFilterOpen,
        count: openCount,
        isSelected: _activeFilter == _BugReportFilter.open,
        color: _filterColor(context, _BugReportFilter.open),
        onTap: () => safeSetState(() => _activeFilter = _BugReportFilter.open),
      ),
      StatusFilterChip(
        label: context.l10n.feedbackFilterResponded,
        count: respondedCount,
        isSelected: _activeFilter == _BugReportFilter.responded,
        color: _filterColor(context, _BugReportFilter.responded),
        onTap: () =>
            safeSetState(() => _activeFilter = _BugReportFilter.responded),
      ),
      StatusFilterChip(
        label: context.l10n.feedbackFilterAwaiting,
        count: awaitingCount,
        isSelected: _activeFilter == _BugReportFilter.awaiting,
        color: _filterColor(context, _BugReportFilter.awaiting),
        onTap: () =>
            safeSetState(() => _activeFilter = _BugReportFilter.awaiting),
      ),
      StatusFilterChip(
        label: context.l10n.feedbackFilterResolved,
        count: resolvedCount,
        isSelected: _activeFilter == _BugReportFilter.resolved,
        color: _filterColor(context, _BugReportFilter.resolved),
        icon: Icons.check_circle_outline,
        onTap: () =>
            safeSetState(() => _activeFilter = _BugReportFilter.resolved),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(myBugReportsProvider);

    return GlassScaffold(
      resizeToAvoidBottomInset: false,
      title: context.l10n.feedbackBugReportsTitle,
      slivers: [
        ...reportsAsync.when(
          data: (reports) {
            if (reports.isEmpty) {
              return [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacing32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bug_report_outlined,
                            size: 64,
                            color: context.textTertiary,
                          ),
                          const SizedBox(height: AppTheme.spacing16),
                          Text(
                            context.l10n.feedbackNoBugReports,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacing8),
                          Text(
                            context.l10n.feedbackNoBugReportsDesc,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ];
            }

            final filtered = _applySearch(_applyFilter(reports));

            return [
              // Pinned search + filter chips
              SliverPersistentHeader(
                pinned: true,
                delegate: SearchFilterHeaderDelegate(
                  searchController: _searchController,
                  searchQuery: _searchQuery,
                  onSearchChanged: (value) =>
                      safeSetState(() => _searchQuery = value),
                  hintText: context.l10n.feedbackSearchReports,
                  textScaler: MediaQuery.textScalerOf(context),
                  rebuildKey: Object.hashAll([_activeFilter, reports.length]),
                  filterChips: _buildFilterChips(context, reports),
                ),
              ),
              // Results
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.filter_list_off,
                          size: 48,
                          color: context.textTertiary,
                        ),
                        const SizedBox(height: AppTheme.spacing12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? context.l10n.feedbackNoMatchSearch
                              : context.l10n.feedbackNoMatchFilter,
                          style: TextStyle(
                            fontSize: 15,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(top: 4, bottom: 12),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppTheme.spacing8),
                    itemBuilder: (context, index) {
                      final report = filtered[index];
                      final isInitialReport =
                          widget.initialReportId == report.id;
                      return _BugReportCard(
                        key: isInitialReport
                            ? const PageStorageKey('initial-bug-report-card')
                            : null,
                        report: report,
                        initiallyExpanded: isInitialReport,
                        autoFocusReply:
                            isInitialReport && widget.initialFocusReply,
                      );
                    },
                  ),
                ),
            ];
          },
          loading: () => [
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (error, _) => [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppTheme.errorRed,
                      ),
                      const SizedBox(height: AppTheme.spacing16),
                      Text(
                        context.l10n.feedbackFailedToLoad,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing8),
                      Text(
                        '$error',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing16),
                      TextButton.icon(
                        onPressed: () => ref.invalidate(myBugReportsProvider),
                        icon: const Icon(Icons.refresh),
                        label: Text(context.l10n.feedbackRetry),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Expandable card showing a single bug report with its threaded responses.
class _BugReportCard extends ConsumerStatefulWidget {
  const _BugReportCard({
    super.key,
    required this.report,
    this.initiallyExpanded = false,
    this.autoFocusReply = false,
  });

  final BugReport report;
  final bool initiallyExpanded;

  /// On mount: scroll this card into view and focus its reply field. Used by
  /// the bug-response quick sheet so users land in reply mode without an
  /// extra tap.
  final bool autoFocusReply;

  @override
  ConsumerState<_BugReportCard> createState() => _BugReportCardState();
}

class _BugReportCardState extends ConsumerState<_BugReportCard>
    with LifecycleSafeMixin<_BugReportCard> {
  late bool _isExpanded;
  final _replyController = TextEditingController();
  final _replyFocusNode = FocusNode();
  bool _isSending = false;

  /// Timestamp of the most recent reply-field unfocus event.
  /// Used to debounce screenshot taps so the first tap after keyboard
  /// dismiss only closes the keyboard and does not open the gallery.
  DateTime? _lastReplyUnfocusTime;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _replyFocusNode.addListener(_onReplyFocusChanged);
    if (_isExpanded && widget.report.hasUnreadResponses) {
      _markAsRead();
    }
    if (widget.autoFocusReply) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final ctx = context;
        try {
          await Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            alignment: 0.1,
          );
        } catch (_) {
          // Card may not be inside a Scrollable yet (race during build).
          // Falling through to focus still gives the user a usable state.
        }
        if (!mounted) return;
        _replyFocusNode.requestFocus();
      });
    }
  }

  void _onReplyFocusChanged() {
    if (!_replyFocusNode.hasFocus) {
      _lastReplyUnfocusTime = DateTime.now();
    }
  }

  @override
  void dispose() {
    _replyFocusNode.removeListener(_onReplyFocusChanged);
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _BugReportCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isExpanded &&
        !oldWidget.report.hasUnreadResponses &&
        widget.report.hasUnreadResponses) {
      _markAsRead();
    }
  }

  Future<void> _markAsRead() async {
    if (!widget.report.hasUnreadResponses) return;
    try {
      final repository = ref.read(bugReportRepositoryProvider);
      await repository.markResponsesAsRead(widget.report.id);
      ref.invalidate(myBugReportsProvider);
    } catch (e) {
      AppLogging.bugReport('Failed to mark as read: $e');
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _isSending) return;

    if (!mounted) return;
    final repository = ref.read(bugReportRepositoryProvider);

    safeSetState(() => _isSending = true);

    try {
      await repository.replyToReport(reportId: widget.report.id, message: text);

      if (!mounted) return;
      _replyController.clear();
      _replyFocusNode.unfocus();
      ref.invalidate(myBugReportsProvider);

      safeShowSnackBar(
        context.l10n.feedbackReplySent,
        type: SnackBarType.success,
      );
    } catch (e) {
      showErrorSnackBar(context, context.l10n.feedbackReplyFailed('$e'));
    } finally {
      if (mounted) {
        safeSetState(() => _isSending = false);
      }
    }
  }

  /// Whether the user is allowed to reply.
  /// Users can reply if:
  /// - There are no responses yet (initial reply to their own report)
  /// - The last response is from the founder/admin
  /// They cannot reply if the last response is already from the user
  /// (must wait for admin to respond first).
  bool _canReply(BugReport report) {
    if (report.status == BugReportStatus.resolved) return false;
    if (report.status == BugReportStatus.userReplied) return false;
    if (report.status == BugReportStatus.responded) return true;
    if (!report.responsesLoaded || report.responses.isEmpty) return true;
    final lastResponse = report.responses.last;
    return lastResponse.isFromFounder;
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final dateFormat = AppTimeFormat.withDatePrefix(context, 'd MMM yyyy,');
    final hasResponses = report.responses.isNotEmpty;
    final responsesLoaded = report.responsesLoaded;
    final hasUnread = report.hasUnreadResponses;
    final canReply = _canReply(report);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
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
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          report.description.length > 80
                              ? '${report.description.substring(0, 77)}…'
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
                      const SizedBox(width: AppTheme.spacing8),
                      if (hasUnread)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: context.accentColor,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius10,
                            ),
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
                  const SizedBox(height: AppTheme.spacing8),
                  Row(
                    children: [
                      _StatusChip(status: report.status),
                      const Spacer(),
                      if (responsesLoaded && hasResponses) ...[
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 14,
                          color: context.textTertiary,
                        ),
                        const SizedBox(width: AppTheme.spacing4),
                        Text(
                          '${report.responses.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textTertiary,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing12),
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
                    const SizedBox(height: AppTheme.spacing4),
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
              padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 12, 16, 4),
              child: Text(
                context.l10n.feedbackYourReport,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.textTertiary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 4, 16, 12),
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
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacing16,
                  0,
                  16,
                  12,
                ),
                child: ScreenshotThumbnail(
                  imageUrl: report.screenshotUrl!,
                  onTapOverride: () {
                    // If the reply field just lost focus (keyboard dismissed),
                    // swallow this tap so the gallery does not open.
                    // Uses a time-based debounce to avoid race conditions
                    // between onTapOutside and GestureDetector ordering.
                    if (_lastReplyUnfocusTime != null &&
                        DateTime.now().difference(_lastReplyUnfocusTime!) <
                            const Duration(milliseconds: 300)) {
                      return;
                    }
                    FullscreenGallery.show(
                      context,
                      images: [report.screenshotUrl!],
                    );
                  },
                ),
              ),
            ],

            // Conversation thread
            if (!responsesLoaded)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing16,
                  vertical: AppTheme.spacing20,
                ),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.accentColor,
                    ),
                  ),
                ),
              )
            else if (hasResponses) ...[
              Divider(height: 1, color: context.border.withValues(alpha: 0.5)),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacing16,
                  12,
                  16,
                  4,
                ),
                child: Text(
                  context.l10n.feedbackConversation,
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
              const SizedBox(height: AppTheme.spacing8),
            ],

            // Reply input (or waiting message)
            Divider(height: 1, color: context.border.withValues(alpha: 0.5)),
            if (report.status == BugReportStatus.resolved)
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: context.textTertiary,
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    Text(
                      context.l10n.feedbackReportResolved,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textTertiary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              )
            else if (!canReply)
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.hourglass_top_rounded,
                      size: 16,
                      color: context.textTertiary,
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    Text(
                      context.l10n.feedbackWaitingForAdmin,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textTertiary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacing12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _replyController,
                      focusNode: _replyFocusNode,
                      maxLines: 6,
                      minLines: 3,
                      maxLength: 4000,
                      enabled: !_isSending,
                      decoration: InputDecoration(
                        hintText: context.l10n.feedbackReplyHint,
                        hintStyle: TextStyle(color: context.textTertiary),
                        filled: true,
                        fillColor: context.background,
                        contentPadding: const EdgeInsets.all(
                          AppTheme.spacing14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius12,
                          ),
                          borderSide: BorderSide(
                            color: context.border.withValues(alpha: 0.5),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius12,
                          ),
                          borderSide: BorderSide(
                            color: context.border.withValues(alpha: 0.5),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius12,
                          ),
                          borderSide: BorderSide(
                            color: context.accentColor.withValues(alpha: 0.6),
                          ),
                        ),
                        counterText: '',
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: context.textPrimary,
                      ),
                      onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    ),
                    const SizedBox(height: AppTheme.spacing8),
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
                                  padding: EdgeInsets.all(AppTheme.spacing10),
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
        borderRadius: BorderRadius.circular(AppTheme.radius6),
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
    final timeFormat = AppTimeFormat.withDatePrefix(context, 'd MMM,');

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
                  const SizedBox(width: AppTheme.spacing6),
                  Text(
                    isFounder
                        ? context.l10n.feedbackResponseAuthorSocialMesh
                        : context.l10n.feedbackResponseAuthorYou,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isFounder
                          ? context.accentColor
                          : context.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Text(
                    timeFormat.format(response.createdAt),
                    style: TextStyle(fontSize: 10, color: context.textTertiary),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing6),
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
