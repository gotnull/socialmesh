// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Mobile audit-log drill-in screen. Mirrors the web admin's
// /license-orgs/<id>/audit page but bounded to mobile real estate:
// outcome filter via ChipSelector + paginated list + Load more.
//
// Reached from the "View all activity" tap on the Recent activity
// section of the License Org Overview card. The recent-activity
// preview shows up to 5 events; this screen shows every event the
// org has, 50 at a time.
//
// Provider:
//   licenseOrgAuditLogProvider.family(orgId)
//     -> AsyncValue<LicenseOrgAuditLogState>
//       .loadMore() pulls the next page
//
// State handling:
//   - flag off / signed out / suspended org -> empty AnimatedEmptyState
//   - error                                 -> error AnimatedEmptyState
//   - zero events                           -> AnimatedEmptyState
//   - 1+ events                             -> ListView + Load more
//
// IMPORTANT - reads the licensing namespace
// (`license_org_audit_events/`), NOT enterprise multi-tenancy.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/safety/safety.dart';
import '../../core/theme.dart';
import '../../core/widgets/animated_empty_state.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/chip_selector.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/section_header.dart';
import '../../l10n/app_localizations.dart';
import '../../models/license_org_audit_event.dart';
import '../../providers/license_org_audit_providers.dart';

enum _OutcomeFilter { all, success, rejected }

/// Sentinel wrapper used by the action-filter picker. `value == null`
/// means the user explicitly chose "All actions"; a `null` result from
/// the picker `Future` (no wrapper at all) means the sheet was
/// dismissed without selection.
class _ActionPickerResult {
  final LicenseOrgAuditAction? value;
  const _ActionPickerResult(this.value);
}

String _actionLabel(AppLocalizations l10n, LicenseOrgAuditAction a) {
  switch (a) {
    case LicenseOrgAuditAction.seatCodeMinted:
      return l10n.licenseOrgAuditActionSeatCodeMinted;
    case LicenseOrgAuditAction.seatCodeRedeemed:
      return l10n.licenseOrgAuditActionSeatCodeRedeemed;
    case LicenseOrgAuditAction.seatCodeReplayed:
      return l10n.licenseOrgAuditActionSeatCodeReplayed;
    case LicenseOrgAuditAction.seatRevokedManual:
      return l10n.licenseOrgAuditActionSeatRevokedManual;
    case LicenseOrgAuditAction.seatReplacementMinted:
      return l10n.licenseOrgAuditActionSeatReplacementMinted;
    case LicenseOrgAuditAction.seatReinstated:
      return l10n.licenseOrgAuditActionSeatReinstated;
    case LicenseOrgAuditAction.memberInvited:
      return l10n.licenseOrgAuditActionMemberInvited;
    case LicenseOrgAuditAction.memberJoined:
      return l10n.licenseOrgAuditActionMemberJoined;
    case LicenseOrgAuditAction.orgPurchased:
      return l10n.licenseOrgAuditActionOrgPurchased;
    case LicenseOrgAuditAction.orgOwnerCollision:
      return l10n.licenseOrgAuditActionOrgOwnerCollision;
    case LicenseOrgAuditAction.orgSeatRevokedRefund:
      return l10n.licenseOrgAuditActionOrgSeatRevokedRefund;
    case LicenseOrgAuditAction.orgSuspendedDrained:
      return l10n.licenseOrgAuditActionOrgSuspendedDrained;
    case LicenseOrgAuditAction.licenseOrgRenamed:
      return l10n.licenseOrgAuditActionLicenseOrgRenamed;
    case LicenseOrgAuditAction.unknown:
      return l10n.licenseOrgAuditActionUnknown;
  }
}

class LicenseOrgAuditLogScreen extends ConsumerStatefulWidget {
  final String orgId;

  const LicenseOrgAuditLogScreen({super.key, required this.orgId});

  /// Push helper so callers don't need MaterialPageRoute + import.
  static Route<void> route(String orgId) => MaterialPageRoute<void>(
    builder: (_) => LicenseOrgAuditLogScreen(orgId: orgId),
  );

  @override
  ConsumerState<LicenseOrgAuditLogScreen> createState() =>
      _LicenseOrgAuditLogScreenState();
}

class _LicenseOrgAuditLogScreenState
    extends ConsumerState<LicenseOrgAuditLogScreen>
    with LifecycleSafeMixin {
  _OutcomeFilter _outcome = _OutcomeFilter.all;

  // null = "All actions"; otherwise restricts the list to events with
  // a matching `action`. Mirrors the web admin's `?action=` query
  // param (web_admin/audit.html).
  LicenseOrgAuditAction? _action;

  // The unknown enum value is the fallback for unrecognised wire
  // strings and is intentionally NOT exposed as a pickable filter.
  static const List<LicenseOrgAuditAction> _pickableActions = [
    LicenseOrgAuditAction.memberInvited,
    LicenseOrgAuditAction.memberJoined,
    LicenseOrgAuditAction.seatCodeMinted,
    LicenseOrgAuditAction.seatCodeRedeemed,
    LicenseOrgAuditAction.seatCodeReplayed,
    LicenseOrgAuditAction.seatRevokedManual,
    LicenseOrgAuditAction.seatReplacementMinted,
    LicenseOrgAuditAction.orgPurchased,
    LicenseOrgAuditAction.orgOwnerCollision,
    LicenseOrgAuditAction.orgSeatRevokedRefund,
    LicenseOrgAuditAction.orgSuspendedDrained,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stateAsync = ref.watch(licenseOrgAuditLogProvider(widget.orgId));

    return GlassScaffold.body(
      title: l10n.licenseOrgAuditLogScreenTitle,
      hasScrollBody: true,
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildErrorState(context, l10n),
        data: (state) {
          final filtered = _applyFilter(state.events);
          if (state.events.isEmpty) {
            return _buildEmptyState(context, l10n);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, l10n, state.events.length),
              const SizedBox(height: AppTheme.spacing12),
              _buildActionFilterRow(context, l10n),
              const SizedBox(height: AppTheme.spacing12),
              _buildFilter(context, l10n, state.events),
              const SizedBox(height: AppTheme.spacing12),
              Expanded(
                child: filtered.isEmpty
                    ? _buildFilteredEmptyState(context, l10n)
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacing16,
                        ),
                        itemCount: filtered.length + 1,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppTheme.spacing8),
                        itemBuilder: (context, index) {
                          if (index == filtered.length) {
                            return _buildLoadMore(context, l10n, state);
                          }
                          return _AuditLogRow(event: filtered[index]);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<LicenseOrgAuditEvent> _applyFilter(List<LicenseOrgAuditEvent> events) {
    // Apply action filter first so outcome chip counts (computed
    // against `_applyActionFilter(events)`) match the visible list.
    final byAction = _applyActionFilter(events);
    switch (_outcome) {
      case _OutcomeFilter.all:
        return byAction;
      case _OutcomeFilter.success:
        return byAction
            .where((e) => e.outcome == LicenseOrgAuditOutcome.success)
            .toList(growable: false);
      case _OutcomeFilter.rejected:
        return byAction
            .where((e) => e.outcome == LicenseOrgAuditOutcome.rejected)
            .toList(growable: false);
    }
  }

  List<LicenseOrgAuditEvent> _applyActionFilter(
    List<LicenseOrgAuditEvent> events,
  ) {
    final a = _action;
    if (a == null) return events;
    return events.where((e) => e.action == a).toList(growable: false);
  }

  Widget _buildHeader(
    BuildContext context,
    AppLocalizations l10n,
    int loadedCount,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing16,
        AppTheme.spacing16,
        0,
      ),
      child: SectionTitle(title: l10n.licenseOrgAuditLogSubtitle(loadedCount)),
    );
  }

  Widget _buildFilter(
    BuildContext context,
    AppLocalizations l10n,
    List<LicenseOrgAuditEvent> events,
  ) {
    // Counts must reflect the active action filter so the chip labels
    // never claim more rows than the user will see after filtering.
    final byAction = _applyActionFilter(events);
    final successCount = byAction
        .where((e) => e.outcome == LicenseOrgAuditOutcome.success)
        .length;
    final rejectedCount = byAction
        .where((e) => e.outcome == LicenseOrgAuditOutcome.rejected)
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: ChipSelector<_OutcomeFilter>(
        value: _outcome,
        options: [
          ChipOption(
            value: _OutcomeFilter.all,
            label: l10n.licenseOrgAuditFilterAllWithCount(byAction.length),
            color: AccentColors.magenta,
          ),
          ChipOption(
            value: _OutcomeFilter.success,
            label: l10n.licenseOrgAuditFilterSuccessWithCount(successCount),
            color: AppTheme.successGreen,
          ),
          ChipOption(
            value: _OutcomeFilter.rejected,
            label: l10n.licenseOrgAuditFilterRejectedWithCount(rejectedCount),
            color: AppTheme.errorRed,
          ),
        ],
        onChanged: (v) => setState(() => _outcome = v),
      ),
    );
  }

  Widget _buildActionFilterRow(BuildContext context, AppLocalizations l10n) {
    final selectionLabel = _action == null
        ? l10n.licenseOrgAuditActionFilterAll
        : _actionLabel(l10n, _action!);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: InkWell(
        onTap: () => _openActionPicker(context, l10n),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing12,
            vertical: AppTheme.spacing12,
          ),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            border: Border.all(color: context.border),
          ),
          child: Row(
            children: [
              Icon(
                Icons.filter_list_outlined,
                size: 18,
                color: context.textSecondary,
              ),
              const SizedBox(width: AppTheme.spacing8),
              // Label stays muted so the eye lands on the selection,
              // not the static word "Action". Colon is a UI-typographic
              // separator (not localised content) so it sits in the
              // Dart literal rather than the ARB string.
              Text(
                '${l10n.licenseOrgAuditActionFilterLabel}:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.textTertiary,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Expanded(
                child: Text(
                  selectionLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
              ),
              Icon(Icons.expand_more, size: 18, color: context.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openActionPicker(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    // Wrap the picked value so `null` from dismiss can be told apart
    // from `null` meaning "the user tapped 'All actions'". Without
    // this, dragging the sheet down by mistake would silently revert
    // an active action filter.
    final selected = await AppBottomSheet.show<_ActionPickerResult>(
      context: context,
      child: Builder(
        builder: (sheetContext) {
          Widget pickerRow({
            required String label,
            required bool selected,
            required VoidCallback onTap,
          }) {
            return InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing16,
                  vertical: AppTheme.spacing12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          color: sheetContext.textPrimary,
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(
                        Icons.check,
                        size: 18,
                        color: sheetContext.accentColor,
                      ),
                  ],
                ),
              ),
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacing16,
                  AppTheme.spacing12,
                  AppTheme.spacing16,
                  AppTheme.spacing8,
                ),
                child: Text(
                  key: const Key('audit-action-picker-title'),
                  l10n.licenseOrgAuditActionFilterSheetTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: sheetContext.textPrimary,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      KeyedSubtree(
                        key: const Key('audit-action-picker-row-all'),
                        child: pickerRow(
                          label: l10n.licenseOrgAuditActionFilterAll,
                          selected: _action == null,
                          onTap: () => Navigator.of(sheetContext)
                              .pop<_ActionPickerResult>(
                                const _ActionPickerResult(null),
                              ),
                        ),
                      ),
                      for (final a in _pickableActions)
                        KeyedSubtree(
                          key: Key('audit-action-picker-row-${a.name}'),
                          child: pickerRow(
                            label: _actionLabel(l10n, a),
                            selected: _action == a,
                            onTap: () => Navigator.of(
                              sheetContext,
                            ).pop<_ActionPickerResult>(_ActionPickerResult(a)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    if (!mounted) return;
    // `null` here means the sheet was dismissed (drag or scrim tap).
    // Preserve the existing filter in that case.
    if (selected == null) return;
    setState(() {
      _action = selected.value;
      // Reset outcome filter when the action selection changes so the
      // user doesn't land on a filtered-empty list whose chips were
      // counted against a different action bucket.
      _outcome = _OutcomeFilter.all;
    });
  }

  Widget _buildLoadMore(
    BuildContext context,
    AppLocalizations l10n,
    LicenseOrgAuditLogState state,
  ) {
    if (!state.hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
        child: Text(
          l10n.licenseOrgAuditLogEndOfFeed,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: context.textTertiary),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing12),
      child: Center(
        child: state.isLoadingMore
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton.icon(
                onPressed: () => ref
                    .read(licenseOrgAuditLogProvider(widget.orgId).notifier)
                    .loadMore(),
                icon: const Icon(Icons.expand_more),
                label: Text(l10n.licenseOrgAuditLogLoadMore),
              ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return AnimatedEmptyState(
      config: AnimatedEmptyStateConfig(
        icons: const [
          Icons.history_outlined,
          Icons.event_note_outlined,
          Icons.fact_check_outlined,
        ],
        taglines: [l10n.licenseOrgAuditLogEmptyDescription],
        titlePrefix: '',
        titleKeyword: l10n.licenseOrgAuditLogEmptyTitle,
        titleSuffix: '',
      ),
    );
  }

  Widget _buildFilteredEmptyState(BuildContext context, AppLocalizations l10n) {
    return AnimatedEmptyState(
      config: AnimatedEmptyStateConfig(
        icons: const [
          Icons.filter_alt_off_outlined,
          Icons.search_off_outlined,
          Icons.tune_outlined,
        ],
        taglines: [l10n.licenseOrgAuditLogFilteredEmptyDescription],
        titlePrefix: '',
        titleKeyword: l10n.licenseOrgAuditLogFilteredEmptyTitle,
        titleSuffix: '',
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, AppLocalizations l10n) {
    return AnimatedEmptyState(
      config: AnimatedEmptyStateConfig(
        icons: const [
          Icons.error_outline,
          Icons.cloud_off_outlined,
          Icons.lock_outline,
        ],
        taglines: [l10n.licenseOrgAuditLogErrorDescription],
        titlePrefix: '',
        titleKeyword: l10n.licenseOrgAuditLogErrorTitle,
        titleSuffix: '',
      ),
    );
  }
}

class _AuditLogRow extends StatelessWidget {
  final LicenseOrgAuditEvent event;

  const _AuditLogRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isRejected = event.outcome == LicenseOrgAuditOutcome.rejected;
    final outcomeColor = isRejected ? AppTheme.errorRed : AppTheme.successGreen;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_iconFor(event.action), size: 20, color: context.textSecondary),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _actionLabel(l10n, event.action),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing4),
                Wrap(
                  spacing: AppTheme.spacing8,
                  runSpacing: AppTheme.spacing4,
                  children: [
                    Text(
                      event.actorDisplayLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    Text(
                      '·',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                      ),
                    ),
                    Text(
                      _absoluteTime(event.tsServer),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    if (isRejected && event.reasonCode != null) ...[
                      Text(
                        '·',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textTertiary,
                        ),
                      ),
                      Text(
                        event.reasonCode!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.errorRed,
                          fontFamily: AppTheme.fontFamily,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing8,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: outcomeColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppTheme.radius8),
              border: Border.all(color: outcomeColor.withValues(alpha: 0.45)),
            ),
            child: Text(
              isRejected
                  ? l10n.licenseOrgAuditOutcomeRejected
                  : l10n.licenseOrgAuditOutcomeSuccess,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: outcomeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(LicenseOrgAuditAction action) {
    switch (action) {
      case LicenseOrgAuditAction.memberInvited:
        return Icons.mail_outline;
      case LicenseOrgAuditAction.memberJoined:
        return Icons.person_add_alt_1_outlined;
      case LicenseOrgAuditAction.seatCodeMinted:
      case LicenseOrgAuditAction.seatReplacementMinted:
        return Icons.confirmation_number_outlined;
      case LicenseOrgAuditAction.seatCodeRedeemed:
      case LicenseOrgAuditAction.seatCodeReplayed:
        return Icons.event_seat_outlined;
      case LicenseOrgAuditAction.seatRevokedManual:
      case LicenseOrgAuditAction.orgSeatRevokedRefund:
        return Icons.remove_circle_outline;
      case LicenseOrgAuditAction.seatReinstated:
        return Icons.restore_outlined;
      case LicenseOrgAuditAction.orgPurchased:
        return Icons.shopping_bag_outlined;
      case LicenseOrgAuditAction.orgOwnerCollision:
        return Icons.warning_amber_outlined;
      case LicenseOrgAuditAction.orgSuspendedDrained:
        return Icons.block_outlined;
      case LicenseOrgAuditAction.licenseOrgRenamed:
        return Icons.edit_outlined;
      case LicenseOrgAuditAction.unknown:
        return Icons.history_outlined;
    }
  }

  static String _absoluteTime(DateTime? ts) {
    if (ts == null) return '-';
    final local = ts.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
