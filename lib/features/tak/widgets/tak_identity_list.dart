// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../services/haptic_service.dart';
import '../../../services/tak/identity_registry.dart';
import '../../../services/tak/providers/tak_bridge_providers.dart';

/// Displays the TAK identity registry as a scrollable list.
class TakIdentityList extends ConsumerWidget {
  const TakIdentityList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(takIdentityRegistryProvider);
    final identities = registry.allIdentities;
    final l10n = context.l10n;
    final theme = Theme.of(context);

    if (identities.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.badge_outlined,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing16),
                Text(
                  l10n.takIdentityNoEntries,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final identity = identities[index];
        return _IdentityTile(identity: identity);
      }, childCount: identities.length),
    );
  }
}

class _IdentityTile extends ConsumerWidget {
  final TakIdentity identity;

  const _IdentityTile({required this.identity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final nodeHex = identity.nodeNum != 0
        ? '0x${identity.nodeNum.toRadixString(16).toUpperCase().padLeft(8, "0")}'
        : null;

    return ListTile(
      leading: Icon(
        identity.isMeshNode ? Icons.radio : Icons.tablet_mac,
        color: identity.isMeshNode ? AccentColors.cyan : AccentColors.purple,
      ),
      title: Text(identity.displayCallsign),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(identity.takUid),
          if (nodeHex != null)
            Text(
              nodeHex,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          Text(
            identity.isMeshNode
                ? l10n.takIdentityMeshNode
                : l10n.takIdentityTakClient,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      isThreeLine: true,
      onTap: identity.isMeshNode
          ? () {
              ref.haptics.buttonTap();
              _showOverrideSheet(context, ref, identity);
            }
          : null,
    );
  }

  void _showOverrideSheet(
    BuildContext context,
    WidgetRef ref,
    TakIdentity identity,
  ) {
    final l10n = context.l10n;
    final controller = TextEditingController(
      text: identity.overrideCallsign ?? '',
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          left: AppTheme.spacing16,
          right: AppTheme.spacing16,
          top: AppTheme.spacing16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.takIdentityOverrideCallsign,
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spacing16),
            TextField(
              controller: controller,
              maxLength: 30,
              decoration: InputDecoration(
                hintText: l10n.takIdentityOverrideHint,
              ),
              autofocus: true,
            ),
            const SizedBox(height: AppTheme.spacing16),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  ref
                      .read(takIdentityRegistryProvider)
                      .setCallsignOverride(identity.nodeNum, text);
                }
                Navigator.of(sheetContext).pop();
              },
              child: Text(l10n.commonSave),
            ),
            const SizedBox(height: AppTheme.spacing16),
          ],
        ),
      ),
    );
  }
}
