// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/theme.dart';
import '../../core/widgets/animated_empty_state.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/info_table.dart';
import '../../providers/rns_companion_providers.dart';
import '../../services/rns_companion/rns_companion_client.dart';
import '../../services/rns_companion/rns_companion_models.dart';
import 'rns_companion_pages_screen.dart';
import 'rns_companion_settings_screen.dart';

class RnsCompanionServicesScreen extends ConsumerWidget {
  const RnsCompanionServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncServices = ref.watch(rnsCompanionServicesProvider);
    return GlassScaffold(
      title: context.l10n.rnsCompanionServicesTitle,
      actions: [
        IconButton(
          icon: const Icon(Icons.tune),
          tooltip: context.l10n.rnsCompanionSettingsTitle,
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const RnsCompanionSettingsScreen(),
              ),
            );
          },
        ),
      ],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
          sliver: SliverList.list(
            children: [
              const _ExperimentalHeader(),
              const _ConnectionStatusPill(),
              ...asyncServices.when(
                data: (services) {
                  if (services.isEmpty) {
                    return [
                      _EmptyState(
                        onReload: () =>
                            ref.invalidate(rnsCompanionServicesProvider),
                      ),
                    ];
                  }
                  return services
                      .map((s) => _ServiceTile(service: s))
                      .toList(growable: false);
                },
                loading: () => const <Widget>[
                  Padding(
                    padding: EdgeInsets.all(AppTheme.spacing24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
                error: (e, _) => [
                  _ErrorState(
                    error: e,
                    onRetry: () => ref.invalidate(rnsCompanionServicesProvider),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing24),
            ],
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------

class _ExperimentalHeader extends StatelessWidget {
  const _ExperimentalHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing8,
        AppTheme.spacing16,
        AppTheme.spacing16,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(color: context.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing8,
                vertical: AppTheme.spacing4,
              ),
              decoration: BoxDecoration(
                color: AppTheme.warningYellow.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                border: Border.all(
                  color: AppTheme.warningYellow.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                context.l10n.rnsCompanionExperimental,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.warningYellow,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacing12),
            Text(
              context.l10n.rnsCompanionConnectionHint,
              style: TextStyle(
                fontSize: 13,
                color: context.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionStatusPill extends ConsumerWidget {
  const _ConnectionStatusPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHealth = ref.watch(rnsCompanionHealthProvider);
    final baseUrl = ref.watch(rnsCompanionBaseUrlProvider);

    final ({Color color, IconData icon, String label}) view = asyncHealth.when(
      loading: () => (
        color: context.textTertiary,
        icon: Icons.sync,
        label: context.l10n.rnsCompanionStatusChecking,
      ),
      data: (h) => (
        color: context.accentColor,
        icon: Icons.check_circle_outline,
        label: context.l10n.rnsCompanionStatusConnectedWithVersion(h.version),
      ),
      error: (_, _) => (
        color: SemanticColors.error,
        icon: Icons.cloud_off_outlined,
        label: context.l10n.rnsCompanionStatusUnreachable,
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        0,
        AppTheme.spacing16,
        AppTheme.spacing12,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            ref.invalidate(rnsCompanionHealthProvider);
          },
          borderRadius: BorderRadius.circular(AppTheme.radius8),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing12,
              vertical: AppTheme.spacing8,
            ),
            decoration: BoxDecoration(
              color: view.color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppTheme.radius8),
              border: Border.all(color: view.color.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(view.icon, color: view.color, size: 16),
                const SizedBox(width: AppTheme.spacing8),
                Expanded(
                  child: Text(
                    view.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: view.color,
                    ),
                  ),
                ),
                Text(
                  baseUrl.replaceFirst('http://', ''),
                  style: TextStyle(fontSize: 11, color: context.textTertiary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service});
  final RnsCompanionServiceSummary service;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing4,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RnsCompanionPagesScreen(service: service),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacing12),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      color: context.accentColor,
                      size: 18,
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    Expanded(
                      child: Text(
                        service.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: context.textTertiary,
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing8),
                InfoTable(
                  rows: [
                    InfoTableRow(
                      label: context.l10n.rnsCompanionServiceDestinationLabel,
                      value: service.destination,
                      icon: Icons.tag,
                    ),
                    InfoTableRow(
                      label: context.l10n.rnsCompanionServiceTypeLabel,
                      value: service.type,
                      icon: Icons.category_outlined,
                    ),
                    InfoTableRow(
                      label: context.l10n.rnsCompanionServiceLastSeenLabel,
                      value: _fmtTs(service.lastSeen),
                      icon: Icons.access_time,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmtTs(int seconds) {
    final dt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000).toLocal();
    return dt.toIso8601String();
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onReload});
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing24),
      child: AnimatedEmptyState(
        config: AnimatedEmptyStateConfig(
          icons: const [
            Icons.menu_book_outlined,
            Icons.podcasts,
            Icons.cell_tower,
          ],
          taglines: [
            context.l10n.rnsCompanionEmptyTagline1,
            context.l10n.rnsCompanionEmptyTagline2,
            context.l10n.rnsCompanionEmptyTagline3,
          ],
          titlePrefix: '',
          titleKeyword: context.l10n.rnsCompanionEmptyTitle,
          titleSuffix: '',
          actionLabel: context.l10n.rnsCompanionEmptyAction,
          actionIcon: Icons.refresh,
          onAction: onReload,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        decoration: BoxDecoration(
          color: SemanticColors.error.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(
            color: SemanticColors.error.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: SemanticColors.error,
                  size: 18,
                ),
                const SizedBox(width: AppTheme.spacing8),
                Expanded(
                  child: Text(
                    rnsCompanionFriendlyError(context, error),
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(context.l10n.rnsCompanionRetry),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Maps a typed `RnsCompanionError` (or any other exception) to a
/// user-facing localized string. Exposed for re-use by the pages /
/// reader screens.
String rnsCompanionFriendlyError(BuildContext context, Object error) {
  if (error is RnsCompanionConnectionError) {
    return context.l10n.rnsCompanionErrorConnection;
  }
  if (error is RnsCompanionTimeoutError) {
    return context.l10n.rnsCompanionErrorTimeout;
  }
  if (error is RnsCompanionParseError) {
    return context.l10n.rnsCompanionErrorParse;
  }
  if (error is RnsCompanionNotFoundError) {
    return context.l10n.rnsCompanionErrorNotFound;
  }
  return context.l10n.rnsCompanionErrorGeneric;
}
