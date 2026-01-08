import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/theme.dart';
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
    _tabController = TabController(length: 3, vsync: this);
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
            Tab(text: 'All'),
            Tab(text: 'Posts'),
            Tab(text: 'Comments'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ReportsList(filter: null),
          _ReportsList(filter: 'post'),
          _ReportsList(filter: 'comment'),
        ],
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
      // Show story details in a dialog since stories may have expired
      final reportContext = report['context'] as Map<String, dynamic>?;
      final mediaUrl = reportContext?['mediaUrl'] as String?;
      final mediaType = reportContext?['mediaType'] as String?;
      final authorId = reportContext?['authorId'] as String?;

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reported Story'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (mediaUrl != null) ...[
                  Text(
                    'Media Type: ${mediaType ?? 'unknown'}',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  if (mediaType == 'image')
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        mediaUrl,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 100,
                          color: Colors.grey[800],
                          child: const Center(
                            child: Icon(Icons.broken_image, size: 48),
                          ),
                        ),
                      ),
                    )
                  else
                    Text('Video URL: $mediaUrl'),
                ],
                if (authorId != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Author ID: $authorId',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.onDismiss,
    required this.onDelete,
    required this.onViewContent,
  });

  final Map<String, dynamic> report;
  final VoidCallback onDismiss;
  final VoidCallback onDelete;
  final VoidCallback onViewContent;

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
          ],
        ),
      ),
    );
  }
}

extension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
