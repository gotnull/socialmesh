// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Lists the stored per-radio datasets and lets the user delete the ones they
// no longer want on the device.
//
// Every radio the app connects to gets its own storage scope, so its mesh
// stays separate from every other radio's. That also means data accumulates
// per radio, and nothing else in the app surfaces it: this screen is where a
// radio's dataset can be seen and removed.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/radio_scope.dart';
import '../../core/theme.dart';
import '../../core/units/byte_format.dart';
import '../../core/widgets/animated_empty_state.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/settings_primitives.dart';
import '../../core/widgets/status_banner.dart';
import '../../providers/radio_scope_providers.dart';
import '../../services/haptic_service.dart';
import '../../utils/snackbar.dart';

class RadioProfilesScreen extends ConsumerWidget {
  const RadioProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scopesAsync = ref.watch(radioScopeListProvider);

    return GlassScaffold(
      title: context.l10n.radioProfilesTitle,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              AppTheme.spacing16,
              AppTheme.spacing16,
              AppTheme.spacing8,
            ),
            child: StatusBanner(
              type: StatusBannerType.info,
              icon: Icons.folder_shared_outlined,
              title: context.l10n.radioProfilesBannerTitle,
              subtitle: context.l10n.radioProfilesBannerBody,
            ),
          ),
        ),
        ...scopesAsync.when(
          loading: () => const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: LoadingIndicator()),
            ),
          ],
          // The exception itself goes to the log rather than the banner: it
          // is an untranslated IO error and names a path the user has no way
          // to act on.
          error: (error, _) => [
            SliverToBoxAdapter(
              child: Builder(
                builder: (context) {
                  AppLogging.storage(
                    'RADIO SCOPE: profile list failed: $error',
                  );
                  return Padding(
                    padding: const EdgeInsets.all(AppTheme.spacing16),
                    child: StatusBanner(
                      type: StatusBannerType.error,
                      icon: Icons.error_outline,
                      title: context.l10n.radioProfilesLoadFailedTitle,
                      subtitle: context.l10n.radioProfilesLoadFailedBody,
                    ),
                  );
                },
              ),
            ),
          ],
          data: (scopes) => _buildScopeSlivers(context, ref, scopes),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacing24)),
      ],
    );
  }

  List<Widget> _buildScopeSlivers(
    BuildContext context,
    WidgetRef ref,
    List<RadioScopeInfo> scopes,
  ) {
    if (scopes.isEmpty) {
      return [SliverFillRemaining(hasScrollBody: false, child: _EmptyState())];
    }

    final current = scopes.where((s) => s.isCurrent).toList();
    final stored = scopes.where((s) => !s.isCurrent).toList();

    return [
      if (current.isNotEmpty)
        SliverList(
          delegate: SliverChildListDelegate([
            SettingsSectionHeader(
              title: context.l10n.radioProfilesSectionInUse,
            ),
            for (final scope in current)
              _RadioProfileTile(scope: scope, onDelete: null),
          ]),
        ),
      if (stored.isNotEmpty)
        SliverList(
          delegate: SliverChildListDelegate([
            SettingsSectionHeader(
              title: context.l10n.radioProfilesSectionStored,
            ),
            for (final scope in stored)
              _RadioProfileTile(
                scope: scope,
                onDelete: () => _confirmDelete(context, ref, scope),
              ),
          ]),
        ),
    ];
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    RadioScopeInfo scope,
  ) async {
    final l10n = context.l10n;
    final name = _displayName(context, scope);
    ref.haptics.trigger(HapticType.heavy);

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: l10n.radioProfilesDeleteTitle,
      message: l10n.radioProfilesDeleteMessage(name),
      confirmLabel: l10n.radioProfilesDeleteConfirm,
      cancelLabel: l10n.commonCancel,
      isDestructive: true,
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final deleted = await RadioScope.instance.deleteScope(scope.key);
    if (!context.mounted) return;

    if (deleted) {
      ref.haptics.trigger(HapticType.success);
      showSuccessSnackBar(context, l10n.radioProfilesDeleted(name));
      ref.invalidate(radioScopeListProvider);
    } else {
      showErrorSnackBar(context, l10n.radioProfilesDeleteFailed);
    }
  }
}

/// Name to show for a radio: the device name it advertised when we last
/// connected, falling back to its node id, then to a label for a radio that
/// disconnected before it ever reported one.
String _displayName(BuildContext context, RadioScopeInfo scope) {
  final label = scope.label;
  if (label != null && label.isNotEmpty) return label;
  final nodeNum = scope.nodeNum;
  if (nodeNum != null) return formatNodeId(nodeNum);
  return context.l10n.radioProfilesUnidentifiedRadio;
}

class _RadioProfileTile extends StatelessWidget {
  const _RadioProfileTile({required this.scope, required this.onDelete});

  final RadioScopeInfo scope;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final nodeNum = scope.nodeNum;
    final size = formatByteSize(scope.sizeBytes);
    final subtitle = nodeNum != null
        ? context.l10n.radioProfilesTileSubtitle(formatNodeId(nodeNum), size)
        : context.l10n.radioProfilesTileSubtitleUnidentified(size);

    return SettingsTile(
      // A radio that never reported its identity carries a two-line
      // subtitle, so the row tops out rather than centring around it.
      crossAxisAlignment: CrossAxisAlignment.start,
      icon: scope.isCurrent ? Icons.router : Icons.storage_outlined,
      iconColor: scope.isCurrent ? SemanticColors.success : null,
      title: _displayName(context, scope),
      subtitle: subtitle,
      trailing: onDelete == null
          ? null
          : IconButton(
              icon: const Icon(Icons.delete_outline),
              color: SemanticColors.error,
              tooltip: context.l10n.radioProfilesDeleteTooltip,
              onPressed: onDelete,
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing24),
      child: AnimatedEmptyState(
        config: AnimatedEmptyStateConfig(
          icons: const [
            Icons.router_outlined,
            Icons.storage_outlined,
            Icons.sd_card_outlined,
            Icons.folder_shared_outlined,
          ],
          taglines: [
            context.l10n.radioProfilesEmptyTagline1,
            context.l10n.radioProfilesEmptyTagline2,
            context.l10n.radioProfilesEmptyTagline3,
          ],
          titlePrefix: context.l10n.radioProfilesEmptyTitlePrefix,
          titleKeyword: context.l10n.radioProfilesEmptyTitleKeyword,
          titleSuffix: context.l10n.radioProfilesEmptyTitleSuffix,
        ),
      ),
    );
  }
}
