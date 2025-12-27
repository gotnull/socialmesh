import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/widget_builder/models/widget_schema.dart';
import '../../features/widget_builder/renderer/widget_renderer.dart';
import '../../providers/app_providers.dart';
import '../theme.dart';

/// A reusable widget preview card used across Marketplace, My Widgets, and other places.
/// Shows a widget rendered from its schema with optional metadata below.
class WidgetPreviewCard extends ConsumerWidget {
  /// The widget schema to render
  final WidgetSchema schema;

  /// Widget title/name
  final String title;

  /// Optional subtitle (e.g., "by Author" or description)
  final String? subtitle;

  /// Callback when the card is tapped
  final VoidCallback? onTap;

  /// Optional trailing widget (e.g., rating/downloads stats, action buttons)
  final Widget? trailing;

  /// Optional leading icon to display next to title
  final Widget? titleLeading;

  /// Whether the widget preview is still loading
  final bool isLoading;

  /// Custom loading height when in loading state
  final double loadingHeight;

  const WidgetPreviewCard({
    super.key,
    required this.schema,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.titleLeading,
    this.isLoading = false,
    this.loadingHeight = 120,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final node = myNodeNum != null ? nodes[myNodeNum] : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.border, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Widget preview - auto-sizes to content
            // This is the actual widget structure that goes on the dashboard
            Padding(
              padding: const EdgeInsets.all(12),
              child: WidgetRenderer(
                schema: schema,
                node: node,
                allNodes: nodes,
                accentColor: context.accentColor,
                enableActions: false, // Only interactive on dashboard
                isPreview: true,
                usePlaceholderData: node == null,
              ),
            ),
            // Divider between widget and info
            Container(height: 1, color: context.border),
            // Info section inside the card
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (titleLeading != null) ...[
                              const SizedBox(width: 8),
                              titleLeading!,
                            ],
                          ],
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A loading placeholder for widget preview cards
class WidgetPreviewCardLoading extends StatelessWidget {
  /// Height of the loading placeholder
  final double height;

  /// Title text to show while loading (optional)
  final String? title;

  /// Subtitle text to show while loading (optional)
  final String? subtitle;

  const WidgetPreviewCardLoading({
    super.key,
    this.height = 120,
    this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Loading placeholder for widget preview
          SizedBox(
            width: double.infinity,
            height: height,
            child: const Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          // Divider between widget and info
          Container(height: 1, color: context.border),
          // Show placeholder text if provided
          if (title != null || subtitle != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null)
                          Text(
                            title!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Stats widget for marketplace items (rating + installs + favorite)
class WidgetMarketplaceStats extends StatelessWidget {
  final double rating;
  final int installs;
  final bool isFavorited;
  final VoidCallback? onFavoriteToggle;

  const WidgetMarketplaceStats({
    super.key,
    required this.rating,
    required this.installs,
    this.isFavorited = false,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star, size: 14, color: AppTheme.warningYellow),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            color: context.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Icon(Icons.download_done, size: 14, color: context.textTertiary),
        const SizedBox(width: 4),
        Text(
          _formatInstalls(installs),
          style: TextStyle(color: context.textSecondary, fontSize: 12),
        ),
        if (onFavoriteToggle != null) ...[
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onFavoriteToggle,
            child: Icon(
              isFavorited ? Icons.favorite : Icons.favorite_border,
              size: 18,
              color: isFavorited ? Colors.redAccent : context.textTertiary,
            ),
          ),
        ],
      ],
    );
  }

  String _formatInstalls(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
