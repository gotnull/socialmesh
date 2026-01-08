import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../providers/social_providers.dart';
import '../../../utils/snackbar.dart';

/// Admin screen for reviewing reported content (posts and comments).
class ReportedContentScreen extends ConsumerStatefulWidget {
  const ReportedContentScreen({super.key});

  @override
  ConsumerState<ReportedContentScreen> createState() =>
      _ReportedContentScreenState();
}

class _ReportedContentScreenState extends ConsumerState<ReportedContentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reported Content'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Auto'),
            Tab(text: 'All'),
            Tab(text: 'Posts'),
            Tab(text: 'Comments'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ModerationQueueList(),
          _ReportsList(filter: null),
          _ReportsList(filter: 'post'),
          _ReportsList(filter: 'comment'),
        ],
      ),
    );
  }
}

/// Shows auto-moderated content from the moderation queue.
class _ModerationQueueList extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ModerationQueueList> createState() =>
      _ModerationQueueListState();
}

class _ModerationQueueListState extends ConsumerState<_ModerationQueueList> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final socialService = ref.watch(socialServiceProvider);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: socialService.watchModerationQueue(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: theme.colorScheme.error.withAlpha(150),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading moderation queue',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 64,
                  color: theme.hintColor.withAlpha(100),
                ),
                const SizedBox(height: 16),
                Text(
                  'No flagged content',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Auto-moderation has not flagged any content',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final contentType = item['contentType'] as String? ?? '';

            // Special handling for user moderation entries (suspensions/strikes)
            if (contentType == 'user_moderation') {
              return _UserModerationCard(
                item: item,
                onUnsuspend: () => _unsuspendUser(context, ref, item),
                onDismiss: () => _approveItem(context, ref, item['id']),
              );
            }

            return _ModerationCard(
              item: item,
              onApprove: () => _approveItem(context, ref, item['id']),
              onReject: () => _rejectItem(context, ref, item),
            );
          },
        );
      },
    );
  }

  Future<void> _unsuspendUser(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> item,
  ) async {
    final metadata = item['metadata'] as Map<String, dynamic>?;
    final userId =
        metadata?['userId'] as String? ?? item['contentId'] as String?;
    final displayName = metadata?['displayName'] as String? ?? 'User';

    if (userId == null) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Cannot identify user');
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsuspend User'),
        content: Text(
          'Are you sure you want to lift the suspension for $displayName?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Unsuspend'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final functions = FirebaseFunctions.instance;
        final callable = functions.httpsCallable('unsuspendUser');
        await callable.call<dynamic>({
          'userId': userId,
          'queueItemId': item['id'],
          'reason': 'Admin lifted suspension',
        });
        if (context.mounted) {
          showSuccessSnackBar(context, 'User unsuspended successfully');
        }
      } catch (e) {
        if (context.mounted) {
          showErrorSnackBar(context, 'Error: $e');
        }
      }
    }
  }

  Future<void> _approveItem(
    BuildContext context,
    WidgetRef ref,
    String itemId,
  ) async {
    try {
      await ref.read(socialServiceProvider).approveModerationItem(itemId);
      if (context.mounted) {
        showSuccessSnackBar(context, 'Content approved');
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Error: $e');
      }
    }
  }

  Future<void> _rejectItem(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> item,
  ) async {
    if (_isProcessing) return; // Prevent double-tap

    final contentType = item['contentType'] as String? ?? 'content';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject & Delete'),
        content: Text(
          'This will delete the $contentType and issue a warning to the user. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      setState(() => _isProcessing = true);
      try {
        await ref.read(socialServiceProvider).rejectModerationItem(item['id']);
        if (context.mounted) {
          showSuccessSnackBar(context, 'Content rejected and user warned');
        }
      } catch (e) {
        if (context.mounted) {
          showErrorSnackBar(context, 'Error: $e');
        }
      } finally {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      }
    }
  }
}

/// Card for displaying auto-moderated content.
class _ModerationCard extends StatelessWidget {
  const _ModerationCard({
    required this.item,
    required this.onApprove,
    required this.onReject,
  });

  final Map<String, dynamic> item;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contentType = item['contentType'] as String? ?? 'unknown';
    final textContent = item['textContent'] as String?;
    final contentUrl = item['contentUrl'] as String?;
    final createdAt = item['createdAt'];
    final DateTime? timestamp = createdAt is Timestamp
        ? createdAt.toDate()
        : (createdAt is DateTime ? createdAt : null);

    // Extract moderation result details
    final moderationResult = item['moderationResult'] as Map<String, dynamic>?;
    final decision =
        moderationResult?['decision'] as String? ??
        moderationResult?['action'] as String? ??
        'unknown';
    final categories = moderationResult?['categories'] as List<dynamic>? ?? [];
    final details = moderationResult?['details'] as String?;

    // Type styling
    final (Color bgColor, Color fgColor, IconData icon) = switch (contentType) {
      'post' => (
        context.accentColor.withAlpha(30),
        context.accentColor,
        Icons.article_outlined,
      ),
      'comment' => (
        theme.colorScheme.secondary.withAlpha(30),
        theme.colorScheme.secondary,
        Icons.comment_outlined,
      ),
      'story' => (
        Colors.orange.withAlpha(30),
        Colors.orange,
        Icons.auto_stories_outlined,
      ),
      _ => (
        theme.colorScheme.errorContainer,
        theme.colorScheme.onErrorContainer,
        Icons.flag_outlined,
      ),
    };

    // Decision styling
    final (
      Color decisionBg,
      Color decisionFg,
      IconData decisionIcon,
    ) = switch (decision) {
      'reject' || 'auto_reject' => (
        Colors.red.withAlpha(40),
        Colors.red,
        Icons.dangerous_outlined,
      ),
      'review' || 'flag' || 'flag_for_review' => (
        Colors.orange.withAlpha(40),
        Colors.orange,
        Icons.warning_outlined,
      ),
      _ => (
        theme.colorScheme.surfaceContainerHighest,
        theme.hintColor,
        Icons.help_outline,
      ),
    };

    // Map decision to display text
    final decisionLabel = switch (decision) {
      'reject' || 'auto_reject' => 'REJECTED',
      'review' || 'flag' || 'flag_for_review' => 'FLAGGED',
      _ => 'PENDING',
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Content type badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: fgColor),
                      const SizedBox(width: 6),
                      Text(
                        contentType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: fgColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Decision badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: decisionBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(decisionIcon, size: 12, color: decisionFg),
                      const SizedBox(width: 4),
                      Text(
                        decisionLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: decisionFg,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (timestamp != null)
                  Text(
                    timeago.format(timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Detected violations
            if (categories.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withAlpha(50),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.error.withAlpha(50),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.gpp_bad_outlined,
                          size: 16,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Violations Detected',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: categories.map((cat) {
                        final category = cat as Map<String, dynamic>;
                        final name = category['name'] as String? ?? 'unknown';
                        final likelihood =
                            category['likelihood'] as String? ?? '';
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(20),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.red.withAlpha(50)),
                          ),
                          child: Text(
                            '$name ($likelihood)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red.shade700,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (details != null && details.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        details,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error.withAlpha(180),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Content preview
            if (contentUrl != null && contentUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  contentUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 60,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 24),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (textContent != null && textContent.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  textContent,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            const SizedBox(height: 16),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Approve'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      side: BorderSide(color: Colors.green.shade300),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Reject'),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Card for displaying user moderation entries (suspensions/strikes).
class _UserModerationCard extends StatelessWidget {
  const _UserModerationCard({
    required this.item,
    required this.onUnsuspend,
    required this.onDismiss,
  });

  final Map<String, dynamic> item;
  final VoidCallback onUnsuspend;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final createdAt = item['createdAt'];
    final DateTime? timestamp = createdAt is Timestamp
        ? createdAt.toDate()
        : (createdAt is DateTime ? createdAt : null);

    // Extract metadata
    final metadata = item['metadata'] as Map<String, dynamic>? ?? {};
    final moderationResult =
        item['moderationResult'] as Map<String, dynamic>? ?? {};
    final displayName = metadata['displayName'] as String? ?? 'Unknown User';
    final actionType =
        metadata['actionType'] as String? ??
        moderationResult['actionType'] as String? ??
        'unknown';
    final isSuspension =
        metadata['isSuspension'] == true || actionType == 'suspension';
    final reason =
        moderationResult['reason'] as String? ?? 'No reason provided';
    final userId =
        metadata['userId'] as String? ?? item['contentId'] as String?;

    // Styling based on action type
    final (Color bgColor, Color fgColor, IconData icon) = isSuspension
        ? (Colors.red.withAlpha(30), Colors.red, Icons.block)
        : (Colors.orange.withAlpha(30), Colors.orange, Icons.warning_amber);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Action type badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: fgColor),
                      const SizedBox(width: 6),
                      Text(
                        isSuspension ? 'SUSPENDED' : 'STRIKE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: fgColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (timestamp != null)
                  Text(
                    timeago.format(timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // User info
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  radius: 24,
                  child: Icon(Icons.person, size: 28, color: theme.hintColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (userId != null)
                        Text(
                          'ID: ${userId.substring(0, 8)}...',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor,
                            fontFamily: 'monospace',
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Reason
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withAlpha(50),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.error.withAlpha(50),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.gpp_bad_outlined,
                        size: 16,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Reason',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reason,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(200),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDismiss,
                    icon: const Icon(Icons.done, size: 18),
                    label: const Text('Dismiss'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.hintColor,
                    ),
                  ),
                ),
                if (isSuspension) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onUnsuspend,
                      icon: const Icon(Icons.lock_open, size: 18),
                      label: const Text('Unsuspend'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportsList extends ConsumerWidget {
  const _ReportsList({this.filter});

  final String? filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final socialService = ref.watch(socialServiceProvider);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: socialService.watchPendingReports(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: theme.colorScheme.error.withAlpha(150),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading reports',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      // Trigger rebuild
                      (context as Element).markNeedsBuild();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        var reports = snapshot.data ?? [];

        // Apply filter
        if (filter != null) {
          reports = reports.where((r) => r['type'] == filter).toList();
        }

        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: theme.hintColor.withAlpha(100),
                ),
                const SizedBox(height: 16),
                Text(
                  filter == null
                      ? 'No pending reports'
                      : 'No pending $filter reports',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            return _ReportCard(
              report: report,
              onDismiss: () => _dismissReport(context, ref, report['id']),
              onDelete: () => _deleteContent(context, ref, report),
              onViewContent: () => _viewContent(context, ref, report),
              onBanUser: () => _banUser(context, ref, report),
            );
          },
        );
      },
    );
  }

  Future<void> _dismissReport(
    BuildContext context,
    WidgetRef ref,
    String reportId,
  ) async {
    try {
      await ref.read(socialServiceProvider).dismissReport(reportId);
      if (context.mounted) {
        showSuccessSnackBar(context, 'Report dismissed');
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Error: $e');
      }
    }
  }

  Future<void> _deleteContent(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> report,
  ) async {
    final type = report['type'] as String? ?? 'content';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $type'),
        content: Text(
          'This will permanently delete the reported $type. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(socialServiceProvider)
            .deleteReportedContent(report['id']);
        if (context.mounted) {
          showSuccessSnackBar(context, '${type.capitalize()} deleted');
        }
      } catch (e) {
        if (context.mounted) {
          showErrorSnackBar(context, 'Error: $e');
        }
      }
    }
  }

  Future<void> _viewContent(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> report,
  ) async {
    final type = report['type'] as String?;
    final targetId = report['targetId'] as String?;

    if (targetId == null) {
      showErrorSnackBar(context, 'Content ID not found');
      return;
    }

    if (type == 'post') {
      // Navigate to post detail
      Navigator.pushNamed(context, '/post-detail', arguments: targetId);
    } else if (type == 'comment') {
      // Get the post ID from context and navigate there
      final reportContext = report['context'] as Map<String, dynamic>?;
      final postId = reportContext?['postId'] as String?;
      if (postId != null) {
        Navigator.pushNamed(context, '/post-detail', arguments: postId);
      } else {
        showErrorSnackBar(context, 'Post not found for this comment');
      }
    } else if (type == 'story') {
      _showStoryPreviewSheet(context, report);
    }
  }

  void _showStoryPreviewSheet(
    BuildContext context,
    Map<String, dynamic> report,
  ) {
    final reportContext = report['context'] as Map<String, dynamic>?;
    final mediaUrl = reportContext?['mediaUrl'] as String?;
    final mediaType = reportContext?['mediaType'] as String?;
    final authorId = reportContext?['authorId'] as String?;
    final reason = report['reason'] as String? ?? 'No reason provided';

    AppBottomSheet.show(
      context: context,
      child: _StoryPreviewContent(
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        authorId: authorId,
        reason: reason,
      ),
    );
  }

  Future<void> _banUser(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> report,
  ) async {
    AppLogging.social('[BanUser] Starting ban user flow');
    AppLogging.social('[BanUser] Report data: $report');

    final reportContext = report['context'] as Map<String, dynamic>?;
    final authorId = reportContext?['authorId'] as String?;
    final type = report['type'] as String? ?? 'content';

    AppLogging.social('[BanUser] Extracted authorId: $authorId, type: $type');

    if (authorId == null) {
      AppLogging.social('[BanUser] ERROR: authorId is null, cannot proceed');
      await FirebaseAnalytics.instance.logEvent(
        name: 'ban_user_error',
        parameters: {
          'error_type': 'missing_author_id',
          'report_id': report['id'] ?? 'unknown',
        },
      );
      if (context.mounted) {
        showErrorSnackBar(context, 'Cannot identify user to ban');
      }
      return;
    }

    // Show confirmation with ban reason selection
    final result = await AppBottomSheet.show<Map<String, dynamic>>(
      context: context,
      child: _BanUserSheet(authorId: authorId, contentType: type),
    );

    if (result == null || !context.mounted) {
      AppLogging.social('[BanUser] User cancelled ban flow');
      return;
    }

    final reason = result['reason'] as String;
    final sendEmail = result['sendEmail'] as bool;

    AppLogging.social(
      '[BanUser] Ban params - reason: $reason, sendEmail: $sendEmail',
    );

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      AppLogging.social('[BanUser] Calling Firebase Function banUser');
      AppLogging.social(
        '[BanUser] Payload: userId=$authorId, reason=$reason, sendEmail=$sendEmail, reportId=${report['id']}',
      );

      // Call Firebase Function to ban user
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('banUser');

      AppLogging.social('[BanUser] httpsCallable created, calling...');

      final response = await callable.call<dynamic>({
        'userId': authorId,
        'reason': reason,
        'sendEmail': sendEmail,
        'reportId': report['id'],
      });

      AppLogging.social(
        '[BanUser] Firebase Function response: ${response.data}',
      );

      // Log success to analytics
      await FirebaseAnalytics.instance.logEvent(
        name: 'ban_user_success',
        parameters: {
          'user_id': authorId,
          'reason': reason,
          'report_id': report['id'] ?? 'unknown',
        },
      );

      // Delete the content
      AppLogging.social('[BanUser] Deleting reported content...');
      await ref.read(socialServiceProvider).deleteReportedContent(report['id']);
      AppLogging.social('[BanUser] Reported content deleted');

      if (context.mounted) {
        Navigator.pop(context); // Close loading
        showSuccessSnackBar(context, 'User banned and $type deleted');
      }
    } on FirebaseFunctionsException catch (e, stackTrace) {
      AppLogging.social(
        '[BanUser] FirebaseFunctionsException: code=${e.code}, message=${e.message}, details=${e.details}',
      );

      // Record to Crashlytics for debugging
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'banUser Firebase Function failed',
        information: [
          'code: ${e.code}',
          'message: ${e.message}',
          'details: ${e.details}',
          'userId: $authorId',
          'reportId: ${report['id']}',
        ],
      );

      // Log to Firebase Analytics for monitoring
      await FirebaseAnalytics.instance.logEvent(
        name: 'ban_user_error',
        parameters: {
          'error_type': 'firebase_functions_exception',
          'error_code': e.code,
          'error_message': e.message ?? 'unknown',
          'user_id': authorId,
          'report_id': report['id'] ?? 'unknown',
        },
      );

      if (context.mounted) {
        Navigator.pop(context); // Close loading
        showErrorSnackBar(
          context,
          'Failed to ban user: [${e.code}] ${e.message}',
        );
      }
    } catch (e, stackTrace) {
      AppLogging.social('[BanUser] Unexpected error: $e');
      AppLogging.social('[BanUser] Stack trace: $stackTrace');

      // Record to Crashlytics for debugging
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'banUser unexpected error',
        information: ['userId: $authorId', 'reportId: ${report['id']}'],
      );

      // Log to Firebase Analytics for monitoring
      await FirebaseAnalytics.instance.logEvent(
        name: 'ban_user_error',
        parameters: {
          'error_type': 'unexpected_exception',
          'error_message': e.toString().substring(
            0,
            (e.toString().length > 100) ? 100 : e.toString().length,
          ),
          'user_id': authorId,
          'report_id': report['id'] ?? 'unknown',
        },
      );

      if (context.mounted) {
        Navigator.pop(context); // Close loading
        showErrorSnackBar(context, 'Failed to ban user: $e');
      }
    }
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.onDismiss,
    required this.onDelete,
    required this.onViewContent,
    required this.onBanUser,
  });

  final Map<String, dynamic> report;
  final VoidCallback onDismiss;
  final VoidCallback onDelete;
  final VoidCallback onViewContent;
  final VoidCallback onBanUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = report['type'] as String? ?? 'unknown';
    final reportContext = report['context'] as Map<String, dynamic>?;
    final content =
        reportContext?['content'] as String? ?? 'Content unavailable';
    final imageUrl = reportContext?['imageUrl'] as String?;
    final reason = report['reason'] as String? ?? 'No reason provided';
    final createdAt = report['createdAt'];
    final DateTime? timestamp = createdAt is Timestamp
        ? createdAt.toDate()
        : (createdAt is DateTime ? createdAt : null);

    // Type styling
    final (Color bgColor, Color fgColor, IconData icon) = switch (type) {
      'post' => (
        context.accentColor.withAlpha(30),
        context.accentColor,
        Icons.article_outlined,
      ),
      'comment' => (
        theme.colorScheme.secondary.withAlpha(30),
        theme.colorScheme.secondary,
        Icons.comment_outlined,
      ),
      'user' => (
        Colors.purple.withAlpha(30),
        Colors.purple,
        Icons.person_outlined,
      ),
      'story' => (
        Colors.orange.withAlpha(30),
        Colors.orange,
        Icons.auto_stories_outlined,
      ),
      _ => (
        theme.colorScheme.errorContainer,
        theme.colorScheme.onErrorContainer,
        Icons.flag_outlined,
      ),
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: fgColor),
                      const SizedBox(width: 6),
                      Text(
                        type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: fgColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (timestamp != null)
                  Text(
                    timeago.format(timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Reason
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withAlpha(50),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.error.withAlpha(50),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.flag, size: 16, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Content preview
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 60,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 24),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                content,
                style: theme.textTheme.bodyMedium,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 16),

            // Actions
            Row(
              children: [
                TextButton.icon(
                  onPressed: onViewContent,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('View'),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: onDismiss,
                  child: const Text('Dismiss'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onDelete,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                  ),
                  child: const Text('Delete'),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Ban user action
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onBanUser,
                icon: const Icon(Icons.block, size: 18),
                label: const Text('Ban User & Delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade300),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for banning a user with reason selection.
class _BanUserSheet extends StatefulWidget {
  const _BanUserSheet({required this.authorId, required this.contentType});

  final String authorId;
  final String contentType;

  @override
  State<_BanUserSheet> createState() => _BanUserSheetState();
}

class _BanUserSheetState extends State<_BanUserSheet> {
  String? _selectedReason;
  bool _sendEmail = true;

  static const _reasons = [
    ('pornography', 'Pornography / Sexual content'),
    ('violence', 'Violence / Threats'),
    ('harassment', 'Harassment / Bullying'),
    ('hate_speech', 'Hate speech / Discrimination'),
    ('spam', 'Spam / Scam'),
    ('illegal', 'Illegal activity'),
    ('impersonation', 'Impersonation'),
    ('other', 'Other violation'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.block, color: Colors.red, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ban User',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'This will permanently disable their account',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const Divider(),

        // User ID
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 16,
                color: context.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'User ID: ',
                style: TextStyle(fontSize: 12, color: context.textSecondary),
              ),
              Expanded(
                child: Text(
                  widget.authorId,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        // Reason selection
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(
            'Select ban reason',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
        ),

        SizedBox(
          height: 200,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _reasons.length,
            itemBuilder: (context, index) {
              final (value, label) = _reasons[index];
              final isSelected = _selectedReason == value;
              return InkWell(
                onTap: () => setState(() => _selectedReason = value),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 20,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : context.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Email option
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: CheckboxListTile(
            value: _sendEmail,
            onChanged: (v) => setState(() => _sendEmail = v ?? true),
            title: const Text(
              'Send notification email to user',
              style: TextStyle(fontSize: 14),
            ),
            subtitle: Text(
              'Inform them why their account was banned',
              style: TextStyle(fontSize: 12, color: context.textSecondary),
            ),
            dense: true,
          ),
        ),

        const SizedBox(height: 8),

        // Actions
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _selectedReason == null
                      ? null
                      : () => Navigator.pop(context, {
                          'reason': _selectedReason,
                          'sendEmail': _sendEmail,
                        }),
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Ban User'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Content widget for story preview bottom sheet.
class _StoryPreviewContent extends StatelessWidget {
  const _StoryPreviewContent({
    required this.mediaUrl,
    required this.mediaType,
    required this.authorId,
    required this.reason,
  });

  final String? mediaUrl;
  final String? mediaType;
  final String? authorId;
  final String reason;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_stories_outlined,
                      size: 14,
                      color: Colors.orange,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'STORY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),

        // Report reason
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer.withAlpha(50),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.error.withAlpha(50),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.flag,
                  size: 16,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reason,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Media preview
        if (mediaUrl != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Media (${mediaType ?? 'unknown'})',
                  style: TextStyle(fontSize: 12, color: context.textSecondary),
                ),
                const SizedBox(height: 8),
                if (mediaType == 'image')
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      mediaUrl!,
                      height: 250,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 150,
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              size: 48,
                              color: context.textTertiary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Image unavailable',
                              style: TextStyle(
                                color: context.textTertiary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.videocam_outlined,
                          color: context.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Video content',
                            style: TextStyle(color: context.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.image_not_supported_outlined,
                      size: 48,
                      color: context.textTertiary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Content not available',
                      style: TextStyle(color: context.textTertiary),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Author info
        if (authorId != null) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 16,
                  color: context.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Author: ',
                  style: TextStyle(fontSize: 12, color: context.textSecondary),
                ),
                Expanded(
                  child: Text(
                    authorId!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),
      ],
    );
  }
}

extension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
