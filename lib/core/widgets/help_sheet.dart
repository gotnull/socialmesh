// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Reusable in-app help sheet — icon-driven explanations for screens
// where the user needs to know what each control does. Designed to be
// dropped into any AppBottomSheet.showScrollable builder. Pattern:
// short intro paragraph followed by a vertical list of icon + title +
// description rows, each visually distinct (icon in an accent-tinted
// square, title bold, body secondary-color).

import 'package:flutter/material.dart';

import '../theme.dart';

/// One row in the [HelpSheet] — an icon, a short title, and a
/// body paragraph describing what the thing does.
class HelpSheetItem {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String description;

  const HelpSheetItem({
    required this.icon,
    required this.title,
    required this.description,
    this.iconColor,
  });
}

/// Icon-driven help sheet. Pass its builder into
/// `AppBottomSheet.showScrollable(builder: (c) => HelpSheet(...))`.
class HelpSheet extends StatelessWidget {
  final String title;
  final String? intro;
  final List<HelpSheetItem> items;
  final ScrollController? scrollController;

  const HelpSheet({
    super.key,
    required this.title,
    required this.items,
    this.intro,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing8,
        AppTheme.spacing16,
        AppTheme.spacing24,
      ),
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        if (intro != null) ...[
          const SizedBox(height: AppTheme.spacing12),
          Text(
            intro!,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: context.textSecondary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
        const SizedBox(height: AppTheme.spacing16),
        for (final item in items) ...[
          _HelpRow(item: item),
          const SizedBox(height: AppTheme.spacing10),
        ],
      ],
    );
  }
}

class _HelpRow extends StatelessWidget {
  final HelpSheetItem item;
  const _HelpRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final iconColor = item.iconColor ?? context.textPrimary;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppTheme.radius8),
            ),
            child: Icon(item.icon, size: 22, color: iconColor),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  item.description,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: context.textSecondary,
                    fontFamily: AppTheme.fontFamily,
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
