// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../providers/rns_companion_providers.dart';
import 'rns_companion_services_screen.dart';

class RnsCompanionPageReaderScreen extends ConsumerWidget {
  const RnsCompanionPageReaderScreen({
    super.key,
    required this.destination,
    required this.pageId,
  });

  final String destination;
  final String pageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (destination: destination, pageId: pageId);
    final asyncPage = ref.watch(rnsCompanionPageProvider(args));
    return GlassScaffold(
      title: context.l10n.rnsCompanionReaderTitle,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing16,
          ),
          sliver: SliverList.list(
            children: asyncPage.when(
              data: (page) => [
                Text(
                  page.title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  '${context.l10n.rnsCompanionPageUpdatedLabel}: '
                  '${_fmtTs(page.updatedAt)}',
                  style: context.bodySmallStyle?.copyWith(
                    color: context.textTertiary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing16),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                  child: SelectableText(
                    page.body,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
              loading: () => const <Widget>[
                Padding(
                  padding: EdgeInsets.all(AppTheme.spacing24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (e, _) => [
                Padding(
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
                          rnsCompanionFriendlyError(context, e),
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () =>
                                ref.invalidate(rnsCompanionPageProvider(args)),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: Text(context.l10n.rnsCompanionRetry),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _fmtTs(int seconds) {
    final dt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000).toLocal();
    return dt.toIso8601String();
  }
}
