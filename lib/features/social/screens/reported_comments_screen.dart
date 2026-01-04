import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../providers/social_providers.dart';
import '../../../utils/snackbar.dart';

/// Admin screen for reviewing reported comments.
class ReportedCommentsScreen extends ConsumerWidget {
  const ReportedCommentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final socialService = ref.watch(socialServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reported Comments')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: socialService.watchPendingReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final reports = snapshot.data ?? [];

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
                    'No pending reports',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return _ReportCard(
                report: report,
                onDismiss: () => _dismissReport(context, ref, report['id']),
                onDelete: () => _deleteContent(context, ref, report['id']),
              );
            },
          );
        },
      ),
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
    String reportId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Content'),
        content: const Text(
          'This will permanently delete the reported content. Continue?',
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
        await ref.read(socialServiceProvider).deleteReportedContent(reportId);
        if (context.mounted) {
          showSuccessSnackBar(context, 'Content deleted');
        }
      } catch (e) {
        if (context.mounted) {
          showErrorSnackBar(context, 'Error: $e');
        }
      }
    }
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.onDismiss,
    required this.onDelete,
  });

  final Map<String, dynamic> report;
  final VoidCallback onDismiss;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final context_ = report['context'] as Map<String, dynamic>?;
    final content = context_?['content'] as String? ?? 'Content unavailable';
    final reason = report['reason'] as String? ?? 'No reason provided';
    final createdAt = report['createdAt'];
    final DateTime? timestamp = createdAt is Timestamp
        ? createdAt.toDate()
        : (createdAt is DateTime ? createdAt : null);

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
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    report['type']?.toString().toUpperCase() ?? 'REPORT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onErrorContainer,
                    ),
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
            Text(
              'Reason: $reason',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 8),

            // Content preview
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
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
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
