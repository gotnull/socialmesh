// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: haptic-feedback — onTap delegates to parent callback
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/widget_builder/models/widget_schema.dart';
import '../../features/widget_builder/renderer/widget_renderer.dart';
import '../../providers/app_providers.dart';
import '../theme.dart';

/// A reusable widget preview card used across My Widgets and other places.
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

  /// Optional callback for share/QR code button - shows QR icon when provided
  final VoidCallback? onShare;

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
    this.onShare,
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
          borderRadius: BorderRadius.circular(AppTheme.radius16),
          border: Border.all(color: context.border, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radius16 - 1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Widget preview - auto-sizes to content
              // This is the actual widget structure that goes on the dashboard
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacing12),
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
                padding: const EdgeInsets.all(AppTheme.spacing12),
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
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (titleLeading != null) ...[
                                const SizedBox(width: AppTheme.spacing8),
                                titleLeading!,
                              ],
                            ],
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: AppTheme.spacing4),
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
                    // QR code share button
                    if (onShare != null) ...[
                      GestureDetector(
                        onTap: onShare,
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacing4),
                          child: Icon(
                            Icons.qr_code_2,
                            color: context.accentColor,
                            size: 22,
                          ),
                        ),
                      ),
                      if (trailing != null)
                        const SizedBox(width: AppTheme.spacing8),
                    ],
                    ?trailing,
                  ],
                ),
              ),
            ],
          ),
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
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(color: context.border, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius16 - 1),
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
                padding: const EdgeInsets.all(AppTheme.spacing12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (title != null)
                            Text(
                              title!,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (subtitle != null) ...[
                            const SizedBox(height: AppTheme.spacing4),
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
      ),
    );
  }
}
