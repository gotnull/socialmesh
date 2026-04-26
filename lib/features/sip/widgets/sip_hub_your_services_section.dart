// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// "Your Services" section of the SIP Hub.
///
/// Renders:
/// - a header with the active-count badge,
/// - a "Create Service" primary CTA that pushes the existing
///   `ServiceCreationWizard` (no new wizard),
/// - a list of tappable instance cards (tap → existing
///   `ServiceDetailScreen`).
///
/// Data comes from [`localServicesSummaryProvider`] — a pure projection
/// of the existing `meshServiceActiveInstancesProvider`. No new
/// subscriptions, no new transport, no parallel pipeline.
///
/// Intentionally exposes as a [Sliver]-compatible returner so the SIP
/// hub can compose it into its existing `CustomScrollView`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Cross-feature navigation is sanctioned for the SIP hub (same pattern
// as main_shell.dart). Services UX is anchored here; reusing the
// existing wizard + shared instance detail sheet avoids duplication.
import '../../mesh_services/models/mesh_service_instance.dart';
import '../../mesh_services/screens/service_creation_wizard.dart';
import '../../mesh_services/widgets/instance_detail_sheet.dart';
import '../../mesh_services/widgets/mesh_service_instance_card.dart';

import '../../../core/constants.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/section_header.dart';
import '../../../providers/sip_hub_services_providers.dart';
import '../../../services/haptic_service.dart';

/// Returns the slivers comprising the "Your Services" section — header,
/// create CTA, and the instance list. Designed to slot between the
/// Incoming Requests and Peers sections of the SIP hub's sliver list.
List<Widget> buildYourServicesSlivers(BuildContext context, WidgetRef ref) {
  // Mesh Services (Create Service + instance list) is gated behind
  // MESH_SERVICES_ENABLED. When the flag is off, the entire section is
  // hidden from the SIP hub so the feature ships independently of the
  // SIP handshake release.
  if (!AppFeatureFlags.isMeshServicesEnabled) {
    return const <Widget>[];
  }

  final async = ref.watch(localServicesSummaryProvider);
  final items = async.asData?.value ?? const <MeshServiceInstance>[];

  // Always show the section header + CTA — empty list shows only the
  // CTA so the Create affordance is discoverable even when empty.
  return [
    SliverPersistentHeader(
      pinned: true,
      delegate: SectionHeaderDelegate(
        title: context.l10n.sipHubSectionYourServices,
        count: items.length,
      ),
    ),
    SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      sliver: SliverList(
        delegate: SliverChildListDelegate(<Widget>[
          const _CreateServiceCta(),
          for (final instance in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
              child: MeshServiceInstanceCard(
                instance: instance,
                onTap: () => InstanceDetailSheet.show(
                  context: context,
                  instance: instance,
                ),
              ),
            ),
        ]),
      ),
    ),
  ];
}

class _CreateServiceCta extends ConsumerWidget {
  const _CreateServiceCta();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          onTap: () {
            ref.read(hapticServiceProvider).trigger(HapticType.medium);
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ServiceCreationWizard(),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing14,
              vertical: AppTheme.spacing12,
            ),
            decoration: BoxDecoration(
              color: context.accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radius12),
              border: Border.all(
                color: context.accentColor.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.add_circle_outline,
                  size: 20,
                  color: context.accentColor,
                ),
                const SizedBox(width: AppTheme.spacing10),
                Expanded(
                  child: Text(
                    context.l10n.sipHubCreateServiceCta,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.accentColor,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: context.accentColor.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
