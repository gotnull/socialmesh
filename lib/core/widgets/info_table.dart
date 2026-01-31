// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import '../theme.dart';

/// A single row item for the InfoTable
class InfoTableRow {
  final String label;
  final String value;
  final IconData? icon;
  final Color? iconColor;

  const InfoTableRow({
    required this.label,
    required this.value,
    this.icon,
    this.iconColor,
  });
}

/// A consistent zebra-striped info table used across the app
class InfoTable extends StatelessWidget {
  final List<InfoTableRow> rows;

  const InfoTable({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    // Get accent color once for all rows
    final accentColor = context.accentColor;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          children: rows.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isOdd = index % 2 == 1;

            return Container(
              decoration: BoxDecoration(
                color: isOdd ? context.cardAlt : context.background,
                border: Border(
                  bottom: index < rows.length - 1
                      ? BorderSide(color: context.border, width: 1)
                      : BorderSide.none,
                ),
              ),
              child: IntrinsicHeight(
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
                        child: Row(
                          children: [
                            if (item.icon != null) ...[
                              Icon(
                                item.icon,
                                size: 16,
                                color: item.iconColor ?? accentColor,
                              ),
                              const SizedBox(width: 8),
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
                        child: Text(
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
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
