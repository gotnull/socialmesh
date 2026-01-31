// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../providers/social_providers.dart';
import '../../../services/content_moderation_service.dart';
import '../../../utils/snackbar.dart';

/// Admin screen for reviewing AI-flagged content.
/// Shows items that need human review before final decision.
class ModerationQueueScreen extends ConsumerStatefulWidget {
  const ModerationQueueScreen({super.key});

  @override
  ConsumerState<ModerationQueueScreen> createState() =>
      _ModerationQueueScreenState();
}

class _ModerationQueueScreenState extends ConsumerState<ModerationQueueScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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
    return GlassScaffold(
      title: 'Moderation Queue',
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Pending'),
          Tab(text: 'Approved'),
          Tab(text: 'Rejected'),
        ],
      ),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: true,
          child: TabBarView(
            controller: _tabController,
            children: const [
              _QueueList(status: 'pending'),
              _QueueList(status: 'approved'),
              _QueueList(status: 'rejected'),
            ],
          ),
        ),
      ],
    );
  }
}

class _QueueList extends ConsumerWidget {
  const _QueueList({required this.status});

  final String status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(moderationQueueProvider(status));

    return queueAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: context.textSecondary),
            const SizedBox(height: 16),
            Text(
              'Error loading queue',
              style: TextStyle(color: context.textSecondary),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.invalidate(moderationQueueProvider(status)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  status == 'pending'
                      ? Icons.check_circle_outline
                      : Icons.inbox_outlined,
                  size: 48,
                  color: context.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  status == 'pending'
                      ? 'No items pending review'
                      : 'No $status items',
                  style: TextStyle(color: context.textSecondary),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(moderationQueueProvider(status));
          },
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return _QueueItemCard(
                item: items[index],
                showActions: status == 'pending',
              );
            },
          ),
        );
      },
    );
  }
}

class _QueueItemCard extends ConsumerWidget {
  const _QueueItemCard({required this.item, this.showActions = true});

  final ModerationQueueItem item;
  final bool showActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                _ContentTypeChip(contentType: item.contentType),
                const SizedBox(width: 8),
                _StatusChip(status: item.status),
                const Spacer(),
                Text(
                  _formatDate(item.createdAt),
                  style: TextStyle(fontSize: 12, color: context.textSecondary),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Content preview
            if (item.contentUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item.contentUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      color: context.surfaceVariant,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    color: context.surfaceVariant,
                    child: Icon(
                      Icons.broken_image,
                      color: context.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (item.textContent != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.surfaceVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.textContent!,
                  style: TextStyle(fontSize: 14, color: context.textPrimary),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // User ID
            Text(
              'User: ${item.userId}',
              style: TextStyle(fontSize: 12, color: context.textSecondary),
            ),

            // Actions
            if (showActions) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _handleReview(context, ref, 'approve'),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _handleReview(context, ref, 'reject'),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Review info for non-pending items
            if (!showActions && item.reviewedBy != null) ...[
              const SizedBox(height: 12),
              Text(
                'Reviewed by ${item.reviewedBy} on ${_formatDate(item.reviewedAt!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: context.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleReview(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    String? notes;

    if (action == 'reject') {
      notes = await AppBottomSheet.show<String>(
        context: context,
        child: _RejectNotesSheet(),
      );
      if (notes == null) return; // User cancelled
    }

    try {
      await reviewModerationItem(
        ref,
        itemId: item.id,
        action: action,
        notes: notes,
      );

      if (context.mounted) {
        if (action == 'approve') {
          showSuccessSnackBar(context, 'Content approved');
        } else {
          showErrorSnackBar(context, 'Content rejected');
        }
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Error: $e');
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _ContentTypeChip extends StatelessWidget {
  const _ContentTypeChip({required this.contentType});

  final String contentType;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (contentType) {
      case 'story':
        icon = Icons.auto_stories;
        color = Colors.purple;
      case 'post':
        icon = Icons.article;
        color = Colors.blue;
      case 'comment':
        icon = Icons.comment;
        color = Colors.teal;
      case 'profile':
        icon = Icons.person;
        color = Colors.orange;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            contentType,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;

    switch (status) {
      case 'pending':
        color = Colors.orange;
      case 'approved':
        color = Colors.green;
      case 'rejected':
        color = Colors.red;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _RejectNotesSheet extends StatefulWidget {
  @override
  State<_RejectNotesSheet> createState() => _RejectNotesSheetState();
}

class _RejectNotesSheetState extends State<_RejectNotesSheet> {
  final _controller = TextEditingController();
  String? _selectedReason;

  final _reasons = [
    'Nudity or sexual content',
    'Violence or graphic content',
    'Hate speech or discrimination',
    'Harassment or bullying',
    'Spam or misleading content',
    'Illegal activity',
    'Other',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rejection Reason',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: _reasons.length,
              itemBuilder: (context, index) {
                final reason = _reasons[index];
                final isSelected = _selectedReason == reason;

                return InkWell(
                  onTap: () => setState(() => _selectedReason = reason),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
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
                            reason,
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
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Additional notes (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _selectedReason == null
                      ? null
                      : () {
                          final notes =
                              _selectedReason! +
                              (_controller.text.isNotEmpty
                                  ? ': ${_controller.text}'
                                  : '');
                          Navigator.of(context).pop(notes);
                        },
                  child: const Text('Reject'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
