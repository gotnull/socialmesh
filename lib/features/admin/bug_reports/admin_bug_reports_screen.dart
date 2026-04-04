// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../utils/time_format.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/search_filter_header.dart';
import '../../../core/widgets/status_filter_chip.dart';
import '../../../core/widgets/fullscreen_gallery.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/screenshot_thumbnail.dart';
import '../../../utils/snackbar.dart';
import '../../feedback/bug_report_repository.dart';
import 'admin_bug_report_providers.dart';

/// Filter options for admin bug reports.
enum _AdminBugFilter {
  all('All'),
  open('Open'),
  userReplied('User Replied'),
  responded('Responded'),
  resolved('Resolved'),
  anonymous('Anonymous');

  const _AdminBugFilter(this.label);
  final String label;
}

/// Admin screen for viewing and responding to all bug reports.
class AdminBugReportsScreen extends ConsumerStatefulWidget {
  const AdminBugReportsScreen({super.key});

  @override
  ConsumerState<AdminBugReportsScreen> createState() =>
      _AdminBugReportsScreenState();
}

class _AdminBugReportsScreenState extends ConsumerState<AdminBugReportsScreen>
    with LifecycleSafeMixin<AdminBugReportsScreen> {
  _AdminBugFilter _activeFilter = _AdminBugFilter.open;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedIds = {};
  final Map<String, TextEditingController> _replyControllers = {};
  final Map<String, BugReportStatus> _optimisticStatuses = {};
  final Set<String> _updatingStatus = {};
  final Set<String> _sendingReply = {};

  @override
  void dispose() {
    _searchController.dispose();
    for (final controller in _replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  BugReportStatus _effectiveStatus(AdminBugReport r) =>
      _optimisticStatuses[r.id] ?? r.status;

  List<AdminBugReport> _applyFilters(List<AdminBugReport> reports) {
    var filtered = reports;

    switch (_activeFilter) {
      case _AdminBugFilter.all:
        break;
      case _AdminBugFilter.open:
        filtered = filtered
            .where((r) => _effectiveStatus(r) == BugReportStatus.open)
            .toList();
      case _AdminBugFilter.userReplied:
        filtered = filtered
            .where((r) => _effectiveStatus(r) == BugReportStatus.userReplied)
            .toList();
      case _AdminBugFilter.responded:
        filtered = filtered
            .where((r) => _effectiveStatus(r) == BugReportStatus.responded)
            .toList();
      case _AdminBugFilter.resolved:
        filtered = filtered
            .where((r) => _effectiveStatus(r) == BugReportStatus.resolved)
            .toList();
      case _AdminBugFilter.anonymous:
        filtered = filtered.where((r) => r.isAnonymous).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((r) {
        return r.description.toLowerCase().contains(q) ||
            (r.uid ?? '').toLowerCase().contains(q) ||
            (r.email ?? '').toLowerCase().contains(q) ||
            (r.platform ?? '').toLowerCase().contains(q) ||
            r.id.toLowerCase().contains(q);
      }).toList();
    }

    return filtered;
  }

  Map<_AdminBugFilter, int> _computeCounts(List<AdminBugReport> reports) {
    return {
      _AdminBugFilter.all: reports.length,
      _AdminBugFilter.open: reports
          .where((r) => _effectiveStatus(r) == BugReportStatus.open)
          .length,
      _AdminBugFilter.userReplied: reports
          .where((r) => _effectiveStatus(r) == BugReportStatus.userReplied)
          .length,
      _AdminBugFilter.responded: reports
          .where((r) => _effectiveStatus(r) == BugReportStatus.responded)
          .length,
      _AdminBugFilter.resolved: reports
          .where((r) => _effectiveStatus(r) == BugReportStatus.resolved)
          .length,
      _AdminBugFilter.anonymous: reports.where((r) => r.isAnonymous).length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(adminBugReportsProvider);

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: GlassScaffold(
        title: context.l10n.adminBugReportsTitle,
        slivers: [
          reportsAsync.when(
            data: (reports) {
              final counts = _computeCounts(reports);
              final filtered = _applyFilters(reports);

              return SliverMainAxisGroup(
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: SearchFilterHeaderDelegate(
                      searchController: _searchController,
                      searchQuery: _searchQuery,
                      onSearchChanged: (value) =>
                          setState(() => _searchQuery = value),
                      hintText: context.l10n.adminBugReportsSearchHint,
                      textScaler: MediaQuery.textScalerOf(context),
                      rebuildKey: Object.hashAll([
                        _activeFilter,
                        ...counts.values,
                      ]),
                      filterChips: _AdminBugFilter.values.map((filter) {
                        return StatusFilterChip(
                          label: filter.label,
                          count: counts[filter] ?? 0,
                          color: _filterColor(filter),
                          isSelected: _activeFilter == filter,
                          onTap: () => setState(() => _activeFilter = filter),
                        );
                      }).toList(),
                    ),
                  ),
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(hasReports: reports.isNotEmpty),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing16,
                      ),
                      sliver: SliverList.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final report = filtered[index];
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppTheme.spacing12,
                            ),
                            child: _ReportCard(
                              report: report,
                              isExpanded: _expandedIds.contains(report.id),
                              replyController: _getReplyController(report.id),
                              onToggle: () => _toggleReport(report),
                              onSendReply: () => _sendReply(report.id),
                              statusOverride: _optimisticStatuses[report.id],
                              isStatusUpdating: _updatingStatus.contains(
                                report.id,
                              ),
                              isSendingReply: _sendingReply.contains(report.id),
                              onResolve: () =>
                                  _updateStatus(report.id, 'resolved'),
                              onReopen: () => _updateStatus(report.id, 'open'),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(height: AppTheme.spacing16),
                    Text(
                      context.l10n.adminBugReportsLoadError,
                      style: TextStyle(color: context.textSecondary),
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    Text(
                      error.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  Color _filterColor(_AdminBugFilter filter) {
    return switch (filter) {
      _AdminBugFilter.all => Colors.grey,
      _AdminBugFilter.open => Colors.amber,
      _AdminBugFilter.userReplied => Colors.blue,
      _AdminBugFilter.responded => Colors.purple,
      _AdminBugFilter.resolved => Colors.green,
      _AdminBugFilter.anonymous => Colors.orange,
    };
  }

  TextEditingController _getReplyController(String reportId) {
    return _replyControllers.putIfAbsent(
      reportId,
      () => TextEditingController(),
    );
  }

  void _toggleReport(AdminBugReport report) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_expandedIds.contains(report.id)) {
        _expandedIds.remove(report.id);
      } else {
        _expandedIds.add(report.id);
        // Mark user responses as read when expanding
        if (report.hasUnreadUserReplies) {
          ref
              .read(adminBugReportRepositoryProvider)
              .markUserResponsesAsRead(report.id);
        }
      }
    });
  }

  Future<void> _sendReply(String reportId) async {
    final controller = _replyControllers[reportId];
    if (controller == null) return;

    final message = controller.text.trim();
    if (message.isEmpty) return;
    if (_sendingReply.contains(reportId)) return;
    if (message.length > 2000) {
      if (mounted) {
        showErrorSnackBar(context, context.l10n.adminBugReportsMessageTooLong);
      }
      return;
    }

    setState(() => _sendingReply.add(reportId));
    try {
      await ref
          .read(adminBugReportRepositoryProvider)
          .respondToReport(reportId: reportId, message: message);
      controller.clear();
      if (mounted) {
        showSuccessSnackBar(context, context.l10n.adminBugReportsReplySent);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          context.l10n.adminBugReportsReplyFailed('$e'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sendingReply.remove(reportId));
      }
    }
  }

  Future<void> _updateStatus(String reportId, String status) async {
    if (_updatingStatus.contains(reportId)) return;
    setState(() {
      _optimisticStatuses[reportId] = BugReportStatus.fromString(status);
      _updatingStatus.add(reportId);
    });
    try {
      await ref
          .read(adminBugReportRepositoryProvider)
          .updateReportStatus(reportId: reportId, status: status);
      if (mounted) {
        showSuccessSnackBar(
          context,
          status == 'resolved'
              ? context.l10n.adminBugReportsResolved
              : context.l10n.adminBugReportsReopened,
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          context.l10n.adminBugReportsStatusFailed('$e'),
        );
        // Revert optimistic status on failure
        setState(() => _optimisticStatuses.remove(reportId));
      }
    } finally {
      if (mounted) {
        setState(() => _updatingStatus.remove(reportId));
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Search bar

// ---------------------------------------------------------------------------
// Report card
// ---------------------------------------------------------------------------

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    this.statusOverride,
    this.isStatusUpdating = false,
    this.isSendingReply = false,
    required this.isExpanded,
    required this.replyController,
    required this.onToggle,
    required this.onSendReply,
    required this.onResolve,
    required this.onReopen,
  });

  final AdminBugReport report;
  final BugReportStatus? statusOverride;
  final bool isStatusUpdating;
  final bool isSendingReply;
  final bool isExpanded;
  final TextEditingController replyController;
  final VoidCallback onToggle;
  final VoidCallback onSendReply;
  final VoidCallback onResolve;
  final VoidCallback onReopen;

  BugReportStatus get _effectiveStatus => statusOverride ?? report.status;

  Color _statusColor() {
    return switch (_effectiveStatus) {
      BugReportStatus.open => Colors.amber,
      BugReportStatus.userReplied => Colors.blue,
      BugReportStatus.responded => Colors.purple,
      BugReportStatus.resolved => Colors.green,
    };
  }

  String _statusLabel(BuildContext context) {
    return switch (_effectiveStatus) {
      BugReportStatus.open => context.l10n.adminBugReportsStatusOpen,
      BugReportStatus.userReplied =>
        context.l10n.adminBugReportsStatusUserReplied,
      BugReportStatus.responded => context.l10n.adminBugReportsStatusResponded,
      BugReportStatus.resolved => context.l10n.adminBugReportsStatusResolved,
    };
  }

  String _formatDate(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) {
      return context.l10n.adminBugReportsTimeJustNow;
    }
    if (diff.inMinutes < 60) {
      return context.l10n.adminBugReportsTimeMinutes(diff.inMinutes);
    }
    if (diff.inHours < 24) {
      return context.l10n.adminBugReportsTimeHours(diff.inHours);
    }
    if (diff.inDays < 7) {
      return context.l10n.adminBugReportsTimeDays(diff.inDays);
    }
    return AppTimeFormat.withDatePrefix(context, 'd MMM y,').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    final statusLabel = _statusLabel(context);
    final desc = report.description;
    final preview = desc.length > 120 ? '${desc.substring(0, 117)}…' : desc;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(
          color: report.hasUnreadUserReplies
              ? Colors.pink
              : isExpanded
              ? Colors.purple
              : Colors.white.withValues(alpha: 0.08),
          width: report.hasUnreadUserReplies ? 1.5 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius12 - 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header (always visible)
            InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radius12 - 1),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            preview,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppTheme.spacing6),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              _MetaChip(
                                icon: Icons.schedule,
                                text: _formatDate(context, report.createdAt),
                              ),
                              if (report.deviceModel != null ||
                                  report.platform != null)
                                _MetaChip(
                                  icon: Icons.devices,
                                  text: [
                                    report.deviceModel ?? report.platform,
                                    report.osVersion ?? report.platformVersion,
                                  ].whereType<String>().join(' · '),
                                ),
                              if (report.appVersion != null)
                                _MetaChip(
                                  icon: Icons.label_outline,
                                  text:
                                      'v${report.appVersion}${report.buildNumber != null ? ' (${report.buildNumber})' : ''}',
                                ),
                              if (report.responses.isNotEmpty)
                                _MetaChip(
                                  icon: Icons.chat_bubble_outline,
                                  text: '${report.responses.length}',
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (report.unreadUserReplyCount > 0)
                              Container(
                                margin: const EdgeInsets.only(
                                  right: AppTheme.spacing8,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacing8,
                                  vertical: AppTheme.spacing2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.pink,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radius11,
                                  ),
                                ),
                                child: Text(
                                  '${report.unreadUserReplyCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spacing8,
                                vertical: AppTheme.spacing3,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius8,
                                ),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacing8),
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.expand_more,
                            size: 20,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Expanded body
            if (isExpanded) ...[
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),

              // Description
              _Section(
                label: context.l10n.adminBugReportsSectionDesc,
                child: SelectableText(
                  desc,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: context.textSecondary,
                  ),
                ),
              ),

              // Screenshot
              if (report.screenshotUrl != null)
                _Section(
                  label: context.l10n.adminBugReportsSectionScreenshot,
                  child: ScreenshotThumbnail(
                    imageUrl: report.screenshotUrl!,
                    onTapOverride: () => _showScreenshot(context),
                  ),
                ),

              // Details grid
              _Section(
                label: context.l10n.adminBugReportsSectionDetails,
                child: Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  children: [
                    _DetailItem(
                      label: context.l10n.adminBugReportsDetailReportId,
                      value: report.id,
                    ),
                    _DetailItem(
                      label: context.l10n.adminBugReportsDetailUserId,
                      value:
                          report.uid ??
                          context.l10n.adminBugReportsAnonymousValue,
                    ),
                    if (report.email != null)
                      _DetailItem(
                        label: context.l10n.adminBugReportsDetailEmail,
                        value: report.email!,
                      ),
                    if (report.deviceModel != null)
                      _DetailItem(
                        label: context.l10n.adminBugReportsDetailDevice,
                        value: report.deviceModel!,
                      ),
                    if (report.osVersion != null ||
                        report.platformVersion != null)
                      _DetailItem(
                        label: context.l10n.adminBugReportsDetailOs,
                        value: report.osVersion ?? report.platformVersion ?? '',
                      ),
                    if (report.appVersion != null)
                      _DetailItem(
                        label: context.l10n.adminBugReportsDetailAppVer,
                        value:
                            'v${report.appVersion}${report.buildNumber != null ? ' (${report.buildNumber})' : ''}',
                      ),
                  ],
                ),
              ),

              // Conversation thread
              if (report.responses.isNotEmpty)
                _Section(
                  label: context.l10n.adminBugReportsSectionConversation,
                  child: Column(
                    children: report.responses
                        .map((r) => _ThreadBubble(response: r))
                        .toList(),
                  ),
                ),

              // Reply box
              if (!report.isAnonymous)
                _ReplyBox(
                  controller: replyController,
                  isResolved: _effectiveStatus == BugReportStatus.resolved,
                  isStatusUpdating: isStatusUpdating,
                  isSendingReply: isSendingReply,
                  onSend: onSendReply,
                  onResolve: onResolve,
                  onReopen: onReopen,
                )
              else
                _AnonymousReplyBox(
                  isResolved: _effectiveStatus == BugReportStatus.resolved,
                  isStatusUpdating: isStatusUpdating,
                  onResolve: onResolve,
                  onReopen: onReopen,
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _showScreenshot(BuildContext context) {
    if (report.screenshotUrl == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            FullscreenGallery(images: [report.screenshotUrl!], initialIndex: 0),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small helper widgets
// ---------------------------------------------------------------------------

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: context.textSecondary),
        const SizedBox(width: AppTheme.spacing3),
        Text(
          text,
          style: TextStyle(fontSize: 11, color: context.textSecondary),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: Colors.white.withValues(alpha: 0.04)),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            AppTheme.spacing14,
            AppTheme.spacing16,
            AppTheme.spacing10,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: AppTheme.spacing8),
              child,
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing2),
          Text(
            value,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ThreadBubble extends StatelessWidget {
  const _ThreadBubble({required this.response});
  final BugReportResponse response;

  @override
  Widget build(BuildContext context) {
    final isFounder = response.isFromFounder;
    return Align(
      alignment: isFounder ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing14,
          vertical: AppTheme.spacing10,
        ),
        decoration: BoxDecoration(
          color: isFounder
              ? Colors.pink.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppTheme.radius12),
            topRight: const Radius.circular(AppTheme.radius12),
            bottomLeft: Radius.circular(isFounder ? 12 : 4),
            bottomRight: Radius.circular(isFounder ? 4 : 12),
          ),
        ),
        child: Column(
          crossAxisAlignment: isFounder
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              response.message,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: AppTheme.spacing4),
            Text(
              '${isFounder ? context.l10n.adminBugReportsThreadYou : context.l10n.adminBugReportsThreadUser} · ${_formatDate(context, response.createdAt)}',
              style: TextStyle(fontSize: 10, color: context.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(BuildContext context, DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) {
      return context.l10n.adminBugReportsTimeJustNow;
    }
    if (diff.inMinutes < 60) {
      return context.l10n.adminBugReportsTimeMinutes(diff.inMinutes);
    }
    if (diff.inHours < 24) {
      return context.l10n.adminBugReportsTimeHours(diff.inHours);
    }
    if (diff.inDays < 7) {
      return context.l10n.adminBugReportsTimeDays(diff.inDays);
    }
    return AppTimeFormat.withDatePrefix(context, 'd MMM,').format(date);
  }
}

class _ReplyBox extends StatefulWidget {
  const _ReplyBox({
    required this.controller,
    required this.isResolved,
    this.isStatusUpdating = false,
    this.isSendingReply = false,
    required this.onSend,
    required this.onResolve,
    required this.onReopen,
  });

  final TextEditingController controller;
  final bool isResolved;
  final bool isStatusUpdating;
  final bool isSendingReply;
  final VoidCallback onSend;
  final VoidCallback onResolve;
  final VoidCallback onReopen;

  @override
  State<_ReplyBox> createState() => _ReplyBoxState();
}

class _ReplyBoxState extends State<_ReplyBox> {
  static const int _countdownSeconds = 3;

  // Status action (resolve/reopen) countdown
  Timer? _statusTimer;
  int _statusCountdown = 0;
  bool _isStatusCountingDown = false;
  VoidCallback? _pendingStatusAction;

  // Send action countdown
  Timer? _sendTimer;
  int _sendCountdown = 0;
  bool _isSendCountingDown = false;

  @override
  void dispose() {
    _statusTimer?.cancel();
    _sendTimer?.cancel();
    super.dispose();
  }

  void _startStatusCountdown(VoidCallback action) {
    // Cancel any active send countdown first
    _cancelSendCountdown(silent: true);
    HapticFeedback.mediumImpact();
    _pendingStatusAction = action;
    setState(() {
      _isStatusCountingDown = true;
      _statusCountdown = _countdownSeconds;
    });
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_statusCountdown <= 1) {
        timer.cancel();
        setState(() => _isStatusCountingDown = false);
        _pendingStatusAction?.call();
      } else {
        setState(() => _statusCountdown--);
      }
    });
  }

  void _cancelStatusCountdown({bool silent = false}) {
    _statusTimer?.cancel();
    if (!silent) HapticFeedback.lightImpact();
    setState(() {
      _isStatusCountingDown = false;
      _statusCountdown = 0;
      _pendingStatusAction = null;
    });
  }

  void _startSendCountdown() {
    if (widget.controller.text.trim().isEmpty) {
      widget.onSend(); // Let parent handle empty validation
      return;
    }
    // Cancel any active status countdown first
    _cancelStatusCountdown(silent: true);
    HapticFeedback.mediumImpact();
    setState(() {
      _isSendCountingDown = true;
      _sendCountdown = _countdownSeconds;
    });
    _sendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_sendCountdown <= 1) {
        timer.cancel();
        setState(() => _isSendCountingDown = false);
        widget.onSend();
      } else {
        setState(() => _sendCountdown--);
      }
    });
  }

  void _cancelSendCountdown({bool silent = false}) {
    _sendTimer?.cancel();
    if (!silent) HapticFeedback.lightImpact();
    setState(() {
      _isSendCountingDown = false;
      _sendCountdown = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final anyCountdown = _isStatusCountingDown || _isSendCountingDown;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        color: Colors.white.withValues(alpha: 0.02),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: widget.controller,
            maxLines: 8,
            minLines: 4,
            maxLength: 4000,
            enabled: !anyCountdown,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: context.l10n.adminBugReportsReplyHint,
              hintStyle: TextStyle(color: context.textSecondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                borderSide: const BorderSide(color: Colors.pink),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing14,
                vertical: AppTheme.spacing12,
              ),
              counterText: '',
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          Row(
            children: [
              Expanded(
                child: _isStatusCountingDown
                    ? OutlinedButton(
                        onPressed: _cancelStatusCountdown,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorRed,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: AppTheme.errorRed),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius12,
                            ),
                          ),
                        ),
                        child: Text(
                          context.l10n.adminBugReportsCountdownCancel(
                            _statusCountdown,
                          ),
                        ),
                      )
                    : widget.isResolved
                    ? OutlinedButton(
                        onPressed:
                            widget.isStatusUpdating || _isSendCountingDown
                            ? null
                            : () => _startStatusCountdown(widget.onReopen),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.amber,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                            color: widget.isStatusUpdating
                                ? Colors.amber.withAlpha(80)
                                : Colors.amber,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius12,
                            ),
                          ),
                        ),
                        child: widget.isStatusUpdating
                            ? const SizedBox(
                                width: AppTheme.spacing16,
                                height: AppTheme.spacing16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.amber,
                                ),
                              )
                            : Text(context.l10n.adminBugReportsReopen),
                      )
                    : OutlinedButton(
                        onPressed:
                            widget.isStatusUpdating || _isSendCountingDown
                            ? null
                            : () => _startStatusCountdown(widget.onResolve),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                            color: widget.isStatusUpdating
                                ? Colors.green.withAlpha(80)
                                : Colors.green,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius12,
                            ),
                          ),
                        ),
                        child: widget.isStatusUpdating
                            ? const SizedBox(
                                width: AppTheme.spacing16,
                                height: AppTheme.spacing16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.green,
                                ),
                              )
                            : Text(context.l10n.adminBugReportsResolve),
                      ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: _isSendCountingDown
                    ? FilledButton.icon(
                        onPressed: _cancelSendCountdown,
                        icon: const Icon(Icons.close, size: 16),
                        label: Text(
                          context.l10n.adminBugReportsCountdownCancel(
                            _sendCountdown,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.errorRed,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius12,
                            ),
                          ),
                        ),
                      )
                    : FilledButton.icon(
                        onPressed:
                            widget.isSendingReply || _isStatusCountingDown
                            ? null
                            : _startSendCountdown,
                        icon: widget.isSendingReply
                            ? const SizedBox(
                                width: AppTheme.spacing16,
                                height: AppTheme.spacing16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send, size: 16),
                        label: Text(context.l10n.adminBugReportsSend),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.pink,
                          disabledBackgroundColor: Colors.pink.withAlpha(120),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius12,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnonymousReplyBox extends StatefulWidget {
  const _AnonymousReplyBox({
    required this.isResolved,
    this.isStatusUpdating = false,
    required this.onResolve,
    required this.onReopen,
  });

  final bool isResolved;
  final bool isStatusUpdating;
  final VoidCallback onResolve;
  final VoidCallback onReopen;

  @override
  State<_AnonymousReplyBox> createState() => _AnonymousReplyBoxState();
}

class _AnonymousReplyBoxState extends State<_AnonymousReplyBox> {
  static const int _countdownSeconds = 3;

  Timer? _timer;
  int _countdown = 0;
  bool _isCountingDown = false;
  VoidCallback? _pendingAction;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown(VoidCallback action) {
    HapticFeedback.mediumImpact();
    _pendingAction = action;
    setState(() {
      _isCountingDown = true;
      _countdown = _countdownSeconds;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown <= 1) {
        timer.cancel();
        setState(() => _isCountingDown = false);
        _pendingAction?.call();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  void _cancelCountdown() {
    _timer?.cancel();
    HapticFeedback.lightImpact();
    setState(() {
      _isCountingDown = false;
      _countdown = 0;
      _pendingAction = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        color: Colors.white.withValues(alpha: 0.02),
      ),
      child: Row(
        children: [
          Icon(Icons.block, size: 16, color: Colors.orange.shade400),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Text(
              context.l10n.adminBugReportsAnonNotice,
              style: TextStyle(fontSize: 12, color: Colors.orange.shade400),
            ),
          ),
          if (_isCountingDown)
            _SmallActionButton(
              label: context.l10n.adminBugReportsCountdownCancel(_countdown),
              color: AppTheme.errorRed,
              onTap: _cancelCountdown,
            )
          else if (widget.isResolved)
            _SmallActionButton(
              label: context.l10n.adminBugReportsReopen,
              color: Colors.amber,
              isLoading: widget.isStatusUpdating,
              onTap: () => _startCountdown(widget.onReopen),
            )
          else
            _SmallActionButton(
              label: context.l10n.adminBugReportsResolve,
              color: Colors.green,
              isLoading: widget.isStatusUpdating,
              onTap: () => _startCountdown(widget.onResolve),
            ),
        ],
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  const _SmallActionButton({
    required this.label,
    required this.color,
    this.isLoading = false,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap();
            },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isLoading ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing10,
            vertical: AppTheme.spacing5,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius8),
            border: Border.all(color: color),
          ),
          child: isLoading
              ? SizedBox(
                  width: AppTheme.spacing12,
                  height: AppTheme.spacing12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: color,
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasReports});
  final bool hasReports;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing60),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.inbox,
              size: 48,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              hasReports
                  ? context.l10n.adminBugReportsEmptyFilter
                  : context.l10n.adminBugReportsEmptyAll,
              style: TextStyle(color: context.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
