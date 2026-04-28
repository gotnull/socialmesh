// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/info_table.dart';
import '../../core/widgets/section_header.dart';
import '../../providers/rns_companion_providers.dart';
import '../../services/rns_companion/rns_companion_models.dart';
import 'rns_companion_page_reader_screen.dart';
import 'rns_companion_services_screen.dart';

class RnsCompanionPagesScreen extends ConsumerWidget {
  const RnsCompanionPagesScreen({super.key, required this.service});
  final RnsCompanionServiceSummary service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPages = ref.watch(
      rnsCompanionPagesProvider(service.destination),
    );
    return GlassScaffold(
      title: context.l10n.rnsCompanionPagesTitle,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
          sliver: SliverList.list(
            children: [
              _ServiceHeader(service: service),
              ...asyncPages.when(
                data: (pages) {
                  if (pages.isEmpty) {
                    return [
                      Padding(
                        padding: const EdgeInsets.all(AppTheme.spacing16),
                        child: Text(
                          context.l10n.rnsCompanionPagesEmpty,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textTertiary,
                          ),
                        ),
                      ),
                    ];
                  }
                  return pages
                      .map(
                        (p) => _PageTile(
                          destination: service.destination,
                          page: p,
                        ),
                      )
                      .toList(growable: false);
                },
                loading: () => const <Widget>[
                  Padding(
                    padding: EdgeInsets.all(AppTheme.spacing24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
                error: (e, _) => [
                  _ErrorBanner(
                    error: e,
                    onRetry: () => ref.invalidate(
                      rnsCompanionPagesProvider(service.destination),
                    ),
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

class _ServiceHeader extends StatelessWidget {
  const _ServiceHeader({required this.service});
  final RnsCompanionServiceSummary service;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: service.name.toUpperCase()),
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
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
        ],
      ),
    );
  }
}

class _PageTile extends StatelessWidget {
  const _PageTile({required this.destination, required this.page});
  final String destination;
  final RnsCompanionPageSummary page;

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
                builder: (_) => RnsCompanionPageReaderScreen(
                  destination: destination,
                  pageId: page.pageId,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: AppTheme.spacing12,
            ),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.article_outlined,
                  color: context.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        page.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing2),
                      Text(
                        '${context.l10n.rnsCompanionPageUpdatedLabel}: '
                        '${_fmtTs(page.updatedAt)}',
                        style: context.bodySmallStyle?.copyWith(
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: context.textTertiary,
                  size: 18,
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error, required this.onRetry});
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
            Text(
              rnsCompanionFriendlyError(context, error),
              style: TextStyle(fontSize: 13, color: context.textSecondary),
            ),
            const SizedBox(height: AppTheme.spacing8),
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
