// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../l10n/app_localizations.dart';

/// Result of comparing a single decoded field against its expected value.
class FieldComparison {
  final String name;
  final String expected;
  final String actual;
  final bool matches;

  const FieldComparison({
    required this.name,
    required this.expected,
    required this.actual,
    required this.matches,
  });
}

/// Result of replaying a single test fixture through the MRRP codec.
class FixtureReplayResult {
  /// Display name of the fixture (e.g. "SERVICE_ADVERT").
  final String name;

  /// Whether the decode succeeded (true) or returned null.
  final bool decodeSuccess;

  /// For valid vectors: field comparisons. Empty for fuzz cases.
  final List<FieldComparison> fields;

  /// Whether decoding should have failed (fuzz case).
  final bool expectNull;

  /// Overall pass: for vectors all fields match, for fuzz decode returned null.
  bool get passed {
    if (expectNull) return !decodeSuccess;
    if (!decodeSuccess) return false;
    return fields.every((f) => f.matches);
  }

  int get matchedFields => fields.where((f) => f.matches).length;

  const FixtureReplayResult({
    required this.name,
    required this.decodeSuccess,
    this.fields = const [],
    this.expectNull = false,
  });
}

/// Tile showing the result of a single fixture replay.
class MrrpFixtureResultTile extends StatefulWidget {
  final FixtureReplayResult result;

  const MrrpFixtureResultTile({super.key, required this.result});

  @override
  State<MrrpFixtureResultTile> createState() => _MrrpFixtureResultTileState();
}

class _MrrpFixtureResultTileState extends State<MrrpFixtureResultTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final r = widget.result;
    final passed = r.passed;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
      child: Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(
            color: context.border.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            onTap: r.fields.isNotEmpty
                ? () => setState(() => _expanded = !_expanded)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row: name + pass/fail badge
                  Row(
                    children: [
                      Icon(
                        passed ? Icons.check_circle : Icons.cancel,
                        size: 20,
                        color: passed
                            ? SemanticColors.success
                            : SemanticColors.error,
                      ),
                      const SizedBox(width: AppTheme.spacing8),
                      Expanded(
                        child: Text(
                          r.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: AppTheme.fontFamily,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacing8,
                          vertical: AppTheme.spacing2,
                        ),
                        decoration: BoxDecoration(
                          color: passed
                              ? SemanticColors.success.withValues(alpha: 0.15)
                              : SemanticColors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppTheme.radius4),
                        ),
                        child: Text(
                          passed
                              ? l10n.mrrpHarnessFixturePass
                              : l10n.mrrpHarnessFixtureFail,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: passed
                                    ? SemanticColors.success
                                    : SemanticColors.error,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      if (r.fields.isNotEmpty) ...[
                        const SizedBox(width: AppTheme.spacing4),
                        Icon(
                          _expanded ? Icons.expand_less : Icons.expand_more,
                          size: 18,
                          color: context.textTertiary,
                        ),
                      ],
                    ],
                  ),

                  // Subtitle: decode status + field match count
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 28,
                      top: AppTheme.spacing4,
                    ),
                    child: Text(
                      _subtitleText(l10n, r),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.textSecondary,
                      ),
                    ),
                  ),

                  // Expanded field comparisons
                  if (_expanded && r.fields.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 28,
                        top: AppTheme.spacing8,
                      ),
                      child: Column(
                        children: r.fields
                            .map((f) => _FieldRow(field: f))
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _subtitleText(AppLocalizations l10n, FixtureReplayResult r) {
    if (r.expectNull) {
      return r.passed
          ? l10n.mrrpHarnessFixtureRejected
          : l10n.mrrpHarnessFixtureNotRejected;
    }
    if (!r.decodeSuccess) return l10n.mrrpHarnessFixtureDecodeNull;
    return '${l10n.mrrpHarnessFixtureDecodeOk} — ${l10n.mrrpHarnessFixtureFieldsMatch(r.matchedFields, r.fields.length)}';
  }
}

/// A single field comparison row.
class _FieldRow extends StatelessWidget {
  final FieldComparison field;

  const _FieldRow({required this.field});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            field.matches ? Icons.check : Icons.close,
            size: 14,
            color: field.matches
                ? SemanticColors.success
                : SemanticColors.error,
          ),
          const SizedBox(width: AppTheme.spacing4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  field.name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: AppTheme.fontFamily,
                    color: context.textPrimary,
                  ),
                ),
                if (!field.matches)
                  Text(
                    '${context.l10n.mrrpHarnessFixtureExpected}: ${field.expected} → ${context.l10n.mrrpHarnessFixtureActual}: ${field.actual}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: SemanticColors.error,
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
