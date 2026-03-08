// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Create Service screen — template picker.
///
/// Entry point for service creation. Displays all available templates
/// as tappable cards. Tapping a template opens the creation flow for
/// that template type.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../services/haptic_service.dart';
import '../models/mesh_service_template.dart';
import '../widgets/mesh_service_template_card.dart';
import 'mesh_service_creation_screen.dart';

/// Template picker screen.
class CreateServiceScreen extends ConsumerWidget {
  const CreateServiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return GlassScaffold(
      title: l10n.meshServicesCreateTitle,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing24,
              AppTheme.spacing8,
              AppTheme.spacing24,
              AppTheme.spacing16,
            ),
            child: Text(
              l10n.meshServicesCreateSubtitle,
              style: context.bodySecondaryStyle?.copyWith(
                color: context.textTertiary,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          sliver: SliverList.separated(
            itemCount: MeshServiceTemplateCatalog.all.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppTheme.spacing8),
            itemBuilder: (context, index) {
              final template = MeshServiceTemplateCatalog.all[index];
              return MeshServiceTemplateCard(
                template: template,
                onTap: () => _onTemplateTap(context, ref, template),
              );
            },
          ),
        ),
        // Bottom padding.
        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacing48)),
      ],
    );
  }

  void _onTemplateTap(
    BuildContext context,
    WidgetRef ref,
    MeshServiceTemplate template,
  ) {
    ref.read(hapticServiceProvider).trigger(HapticType.light);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MeshServiceCreationScreen(template: template),
      ),
    );
  }
}
