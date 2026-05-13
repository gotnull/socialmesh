// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../theme.dart';
import 'app_bottom_sheet.dart';

/// A single row item for the InfoTable
class InfoTableRow {
  final String label;
  final String value;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onTap;

  /// Optional widget rendered right-aligned in the value cell in place of
  /// [value] (badges, chips, status pills). [value] is still required so
  /// callers always have a textual semantic for tests / accessibility.
  final Widget? valueWidget;

  /// When set, the row renders as a single full-width section: an
  /// uppercase header (icon + label + optional help + optional
  /// [headerTrailing] right-aligned), followed by [fullWidthContent]
  /// occupying the entire card width. Use this for paragraph-style
  /// content (notes, descriptions) that would be cramped in the 5:6
  /// two-column layout.
  final Widget? fullWidthContent;

  /// Right-aligned widget rendered in the header row of a full-width
  /// section (typically a small edit/pencil affordance). Ignored when
  /// [fullWidthContent] is null.
  final Widget? headerTrailing;

  /// Optional contextual help builder rendered as an info-icon next
  /// to the label on full-width rows. Tapping opens the builder's
  /// widget in an AppBottomSheet.
  final WidgetBuilder? helpSheetBuilder;

  const InfoTableRow({
    required this.label,
    required this.value,
    this.icon,
    this.iconColor,
    this.onTap,
    this.valueWidget,
    this.fullWidthContent,
    this.headerTrailing,
    this.helpSheetBuilder,
  });
}

/// A consistent zebra-striped info table used across the app
class InfoTable extends StatelessWidget {
  final List<InfoTableRow> rows;

  /// Whether to render the outer card border + rounded clip. Default
  /// true (the standalone look used across the app). Set false when
  /// the InfoTable is embedded inside another card surface whose
  /// border already provides the visual outline (e.g. NodeDex
  /// detail's classification/note section).
  final bool showBorder;

  const InfoTable({super.key, required this.rows, this.showBorder = true});

  @override
  Widget build(BuildContext context) {
    // Get accent color once for all rows
    final accentColor = context.accentColor;

    final body = Column(
      children: rows.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isOdd = index % 2 == 1;
        final isFullWidth = item.fullWidthContent != null;

        final Widget rowBody = isFullWidth
            ? _FullWidthRow(item: item)
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(color: context.border, width: 1),
                          ),
                        ),
                        // Top-align label content. When the value
                        // cell wraps to multiple lines or stacks a
                        // chip / button under the value text, the
                        // row's IntrinsicHeight grows and a
                        // centered label would float in the middle
                        // of empty space. Top-aligned keeps the
                        // label level with the value's first line.
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.icon != null) ...[
                              Icon(
                                item.icon,
                                size: 16,
                                color: item.iconColor ?? accentColor,
                              ),
                              const SizedBox(width: AppTheme.spacing8),
                            ],
                            Expanded(
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: context.textTertiary,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        // Top-right (not center-right) so multi-line
                        // values and value+chip stacks share a top
                        // baseline with the label cell on the left.
                        alignment: Alignment.topRight,
                        child:
                            item.valueWidget ??
                            Text(
                              item.value,
                              style: TextStyle(
                                fontSize: 14,
                                color: context.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.right,
                            ),
                      ),
                    ),
                  ],
                ),
              );

        final rowContainer = Container(
          decoration: BoxDecoration(
            color: isOdd ? context.cardAlt : context.background,
            border: Border(
              bottom: index < rows.length - 1
                  ? BorderSide(color: context.border, width: 1)
                  : BorderSide.none,
            ),
          ),
          child: rowBody,
        );

        if (item.onTap != null) {
          return Material(
            type: MaterialType.transparency,
            child: InkWell(onTap: item.onTap, child: rowContainer),
          );
        }

        return rowContainer;
      }).toList(),
    );

    if (!showBorder) {
      // Embedded mode: zebra stripes + inner row dividers, no outer
      // border or rounded clip. The parent surface provides the
      // visual outline.
      return body;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius11),
        child: body,
      ),
    );
  }
}

/// Renders a full-width [InfoTableRow]: uppercase header (icon +
/// label + optional help (i) + optional trailing right-aligned) over
/// the row's [fullWidthContent] body. Kept private so callers always
/// go through [InfoTable] with [InfoTableRow.fullWidthContent] set.
class _FullWidthRow extends StatelessWidget {
  final InfoTableRow item;

  const _FullWidthRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (item.icon != null) ...[
                Icon(
                  item.icon,
                  size: 14,
                  color: item.iconColor ?? context.textTertiary,
                ),
                const SizedBox(width: AppTheme.spacing8),
              ],
              Text(
                item.label.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.textTertiary,
                  letterSpacing: 1,
                ),
              ),
              if (item.helpSheetBuilder != null) ...[
                const SizedBox(width: AppTheme.spacing4),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    AppBottomSheet.show<void>(
                      context: context,
                      child: Builder(builder: item.helpSheetBuilder!),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacing4),
                    child: Icon(
                      Icons.info_outline,
                      size: 14,
                      color: context.textTertiary.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
              if (item.headerTrailing != null) ...[
                const Spacer(),
                item.headerTrailing!,
              ],
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          item.fullWidthContent!,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// InfoTableSheet — reusable scrollable sheet wrapping an InfoTable
// ---------------------------------------------------------------------------

/// A standardised bottom sheet that renders an [InfoTable] inside a scrollable
/// sheet with a title, optional section label, and optional footer widget.
///
/// Use [InfoTableSheet.show] anywhere you need a consistent info-table sheet.
/// Both the padding and typography exactly follow the device-status sheet.
class InfoTableSheet extends StatelessWidget {
  const InfoTableSheet({
    super.key,
    required this.rows,
    this.sectionLabel,
    this.footer,
    required this.scrollController,
  });

  final List<InfoTableRow> rows;
  final String? sectionLabel;
  final Widget? footer;
  final ScrollController scrollController;

  /// Shows a standard info-table bottom sheet.
  ///
  /// [title] is displayed as the pinned sheet header.
  /// [sectionLabel] is rendered above the table in ALL-CAPS.
  /// [footer] is rendered below the table (scrolls with it).
  static Future<void> show({
    required BuildContext context,
    required String title,
    required List<InfoTableRow> rows,
    String? sectionLabel,
    Widget? footer,
    double initialChildSize = 0.6,
    double maxChildSize = 0.95,
  }) {
    return AppBottomSheet.showScrollable<void>(
      context: context,
      title: title,
      initialChildSize: initialChildSize,
      maxChildSize: maxChildSize,
      builder: (sc) => InfoTableSheet(
        rows: rows,
        sectionLabel: sectionLabel,
        footer: footer,
        scrollController: sc,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing20,
        0,
        AppTheme.spacing20,
        AppTheme.spacing20,
      ),
      children: [
        if (sectionLabel != null) ...[
          Text(
            sectionLabel!.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.textTertiary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
        ],
        InfoTable(rows: rows),
        if (footer != null) ...[
          const SizedBox(height: AppTheme.spacing16),
          footer!,
        ],
        const SizedBox(height: AppTheme.spacing8),
      ],
    );
  }
}
