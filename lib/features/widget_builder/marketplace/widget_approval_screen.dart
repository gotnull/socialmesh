// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widget_marketplace_service.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/splash_mesh_provider.dart';
import '../../../utils/snackbar.dart';

/// Admin screen for reviewing and approving pending widgets
class WidgetApprovalScreen extends ConsumerStatefulWidget {
  const WidgetApprovalScreen({super.key});

  @override
  ConsumerState<WidgetApprovalScreen> createState() =>
      _WidgetApprovalScreenState();
}

class _WidgetApprovalScreenState extends ConsumerState<WidgetApprovalScreen>
    with LifecycleSafeMixin<WidgetApprovalScreen> {
  final _marketplaceService = WidgetMarketplaceService();
  List<MarketplaceWidget> _pendingWidgets = [];
  bool _isLoading = true;
  String? _error;
  String? _processingWidgetId;

  @override
  void initState() {
    super.initState();
    _loadPendingWidgets();
  }

  Future<void> _loadPendingWidgets() async {
    safeSetState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final token = await authService.getIdToken();
      if (!mounted) return;

      if (token == null) {
        safeSetState(() {
          _error = 'Not authenticated';
          _isLoading = false;
        });
        return;
      }

      final widgets = await _marketplaceService.getPendingWidgets(token);
      if (!mounted) return;
      safeSetState(() {
        _pendingWidgets = widgets;
        _isLoading = false;
      });
    } on MarketplaceException catch (e) {
      safeSetState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      safeSetState(() {
        _error = 'Failed to load pending widgets: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _approveWidget(MarketplaceWidget widget) async {
    if (_processingWidgetId != null) return;
    safeSetState(() => _processingWidgetId = widget.id);
    try {
      final authService = ref.read(authServiceProvider);
      final token = await authService.getIdToken();
      if (!mounted) return;

      if (token == null) {
        showErrorSnackBar(context, 'Not authenticated');
        return;
      }

      await _marketplaceService.approveWidget(widget.id, token);
      if (!mounted) return;

      showSuccessSnackBar(context, '${widget.name} approved');
      _loadPendingWidgets();
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Failed to approve: $e');
    } finally {
      safeSetState(() => _processingWidgetId = null);
    }
  }

  Future<void> _rejectWidget(MarketplaceWidget widget) async {
    // Show dialog to get rejection reason
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: context.card,
          title: Text(
            'Reject Widget',
            style: TextStyle(color: context.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Why is "${widget.name}" being rejected?',
                style: TextStyle(color: context.textSecondary),
              ),
              SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter reason...',
                  hintStyle: TextStyle(color: context.textSecondary),
                  filled: true,
                  fillColor: context.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(color: context.textPrimary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: context.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) {
                  showErrorSnackBar(context, 'Please enter a reason');
                  return;
                }
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text(
                'Reject',
                style: TextStyle(color: AppTheme.errorRed),
              ),
            ),
          ],
        );
      },
    );

    if (reason == null || !mounted) return;

    if (_processingWidgetId != null) return;
    safeSetState(() => _processingWidgetId = widget.id);

    try {
      final authService = ref.read(authServiceProvider);
      final token = await authService.getIdToken();
      if (!mounted) return;

      if (token == null) {
        showErrorSnackBar(context, 'Not authenticated');
        return;
      }

      await _marketplaceService.rejectWidget(widget.id, reason, token);
      if (!mounted) return;

      showSuccessSnackBar(context, '${widget.name} rejected');
      _loadPendingWidgets();
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Failed to reject: $e');
    } finally {
      safeSetState(() => _processingWidgetId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Widget Approval',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadPendingWidgets,
        ),
      ],
      slivers: _buildSlivers(),
    );
  }

  List<Widget> _buildSlivers() {
    if (_isLoading) {
      return [const SliverFillRemaining(child: ScreenLoadingIndicator())];
    }

    if (_error != null) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: AppTheme.errorRed),
                SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: context.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _loadPendingWidgets,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    if (_pendingWidgets.isEmpty) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: AppTheme.successGreen,
                ),
                SizedBox(height: 16),
                Text(
                  'No widgets pending approval',
                  style: TextStyle(color: context.textSecondary, fontSize: 18),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final widget = _pendingWidgets[index];
            final isProcessing = _processingWidgetId == widget.id;
            return _PendingWidgetCard(
              widget: widget,
              onApprove: () => _approveWidget(widget),
              onReject: () => _rejectWidget(widget),
              isProcessing: isProcessing,
            );
          }, childCount: _pendingWidgets.length),
        ),
      ),
    ];
  }
}

class _PendingWidgetCard extends StatelessWidget {
  final MarketplaceWidget widget;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final bool isProcessing;

  const _PendingWidgetCard({
    required this.widget,
    required this.onApprove,
    required this.onReject,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.card,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.name,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.warningYellow.withAlpha(51),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'PENDING',
                    style: TextStyle(
                      color: AppTheme.warningYellow,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Description
            if (widget.description.isNotEmpty)
              Text(
                widget.description,
                style: TextStyle(color: context.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            SizedBox(height: 12),

            // Meta info
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 16,
                  color: context.textSecondary,
                ),
                SizedBox(width: 4),
                Text(
                  widget.author,
                  style: TextStyle(color: context.textSecondary, fontSize: 12),
                ),
                SizedBox(width: 16),
                Icon(
                  Icons.category_outlined,
                  size: 16,
                  color: context.textSecondary,
                ),
                SizedBox(width: 4),
                Text(
                  WidgetCategories.getDisplayName(widget.category),
                  style: TextStyle(color: context.textSecondary, fontSize: 12),
                ),
                SizedBox(width: 16),
                Icon(Icons.schedule, size: 16, color: context.textSecondary),
                SizedBox(width: 4),
                Text(
                  _formatDate(widget.createdAt),
                  style: TextStyle(color: context.textSecondary, fontSize: 12),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Tags
            if (widget.tags.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.background,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 16),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: isProcessing ? null : onReject,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorRed,
                    side: BorderSide(color: AppTheme.errorRed),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: isProcessing ? null : onApprove,
                  icon: isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: Text(isProcessing ? 'Processing...' : 'Approve'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.successGreen,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
