import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/theme.dart';
import '../../../core/widgets/auto_scroll_text.dart';
import '../../../providers/auth_providers.dart';
import '../models/shop_models.dart';
import '../providers/device_shop_providers.dart';

final pendingReviewsProvider = StreamProvider<List<ProductReview>>((ref) {
  final service = ref.watch(deviceShopServiceProvider);
  return service.watchPendingReviews();
});

final allReviewsProvider = StreamProvider<List<ProductReview>>((ref) {
  final service = ref.watch(deviceShopServiceProvider);
  return service.watchAllReviews();
});

/// Admin screen for moderating product reviews
class ReviewModerationScreen extends ConsumerStatefulWidget {
  const ReviewModerationScreen({super.key});

  @override
  ConsumerState<ReviewModerationScreen> createState() =>
      _ReviewModerationScreenState();
}

class _ReviewModerationScreenState
    extends ConsumerState<ReviewModerationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.card,
        title: AutoScrollText(
          'Review Management',
          style: TextStyle(color: context.textPrimary),
          maxLines: 1,
          velocity: 30.0,
          fadeWidth: 20.0,
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: context.accentColor,
          labelColor: context.accentColor,
          unselectedLabelColor: context.textSecondary,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'All Reviews'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ReviewList(reviewsProvider: pendingReviewsProvider, isPending: true),
          _ReviewList(reviewsProvider: allReviewsProvider, isPending: false),
        ],
      ),
    );
  }
}

class _ReviewList extends ConsumerWidget {
  final StreamProvider<List<ProductReview>> reviewsProvider;
  final bool isPending;

  const _ReviewList({required this.reviewsProvider, required this.isPending});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(reviewsProvider);

    return reviewsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppTheme.errorRed, size: 48),
            const SizedBox(height: 16),
            Text(
              'Error loading reviews',
              style: TextStyle(color: context.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              e.toString(),
              style: TextStyle(color: context.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      data: (reviews) {
        if (reviews.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: context.accentColor,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  isPending ? 'All caught up!' : 'No reviews yet',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isPending
                      ? 'No pending reviews to moderate'
                      : 'No reviews in database',
                  style: TextStyle(color: context.textSecondary),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reviews.length,
          itemBuilder: (context, index) {
            return _ReviewModerationCard(
              review: reviews[index],
              showModerationActions: isPending,
            );
          },
        );
      },
    );
  }
}

class _ReviewModerationCard extends ConsumerStatefulWidget {
  final ProductReview review;
  final bool showModerationActions;

  const _ReviewModerationCard({
    required this.review,
    this.showModerationActions = true,
  });

  @override
  ConsumerState<_ReviewModerationCard> createState() =>
      _ReviewModerationCardState();
}

class _ReviewModerationCardState extends ConsumerState<_ReviewModerationCard> {
  bool _isProcessing = false;

  Future<void> _approve() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isProcessing = true);
    try {
      await ref
          .read(deviceShopServiceProvider)
          .approveReview(widget.review.id, user.uid);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Review approved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _reject() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const _RejectReasonDialog(),
    );

    if (reason == null || reason.isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      await ref
          .read(deviceShopServiceProvider)
          .rejectReview(widget.review.id, user.uid, reason);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Review rejected')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Review'),
        content: const Text(
          'Are you sure you want to permanently delete this review?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      await ref.read(deviceShopServiceProvider).deleteReview(widget.review.id);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Review deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(
      singleProductFutureProvider(widget.review.productId),
    );

    return Card(
      color: context.card,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product info
            productAsync.when(
              data: (product) => product != null
                  ? Row(
                      children: [
                        if (product.primaryImage != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              product.primaryImage!,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                product.sellerName,
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
              loading: () => const SizedBox(
                height: 50,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (e, stack) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),
            Divider(color: context.border),
            const SizedBox(height: 16),

            // Review header
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: widget.review.userPhotoUrl != null
                      ? NetworkImage(widget.review.userPhotoUrl!)
                      : null,
                  child: widget.review.userPhotoUrl == null
                      ? Icon(Icons.person, color: context.textSecondary)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.review.userName ?? 'Anonymous',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (widget.review.isVerifiedPurchase) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.verified,
                              size: 16,
                              color: context.accentColor,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'Verified',
                              style: TextStyle(
                                color: context.accentColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        timeago.format(widget.review.createdAt),
                        style: TextStyle(
                          color: context.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < widget.review.rating
                          ? Icons.star
                          : Icons.star_outline,
                      color: Colors.amber,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),

            // Review content
            if (widget.review.title != null) ...[
              const SizedBox(height: 12),
              Text(
                widget.review.title!,
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
            if (widget.review.body != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.review.body!,
                style: TextStyle(color: context.textSecondary),
              ),
            ],

            const SizedBox(height: 16),
            Divider(color: context.border),
            const SizedBox(height: 12),

            // Action buttons
            if (_isProcessing)
              const Center(child: CircularProgressIndicator())
            else if (widget.showModerationActions)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _reject,
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _approve,
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red,
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Show status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: widget.review.status == 'approved'
                          ? Colors.green.withValues(alpha: 0.2)
                          : widget.review.status == 'rejected'
                              ? Colors.red.withValues(alpha: 0.2)
                              : widget.review.status == 'legacy'
                                  ? Colors.orange.withValues(alpha: 0.2)
                                  : Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.review.status == 'legacy'
                          ? 'Legacy (no status)'
                          : widget.review.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: widget.review.status == 'approved'
                            ? Colors.green
                            : widget.review.status == 'rejected'
                                ? Colors.red
                                : widget.review.status == 'legacy'
                                    ? Colors.orange
                                    : Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
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

class _RejectReasonDialog extends StatefulWidget {
  const _RejectReasonDialog();

  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject Review'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Reason for rejection',
          hintText: 'e.g., Inappropriate content, spam, etc.',
        ),
        maxLines: 3,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}
