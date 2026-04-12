// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Services section for Mesh Explorer.
///
/// Renders nearby MRRP services as rich destination cards suitable for
/// a service-first discovery hub. Each card shows capability, title,
/// creator identity, freshness, and an access badge.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../features/nodedex/widgets/sigil_painter.dart';
import '../../mesh_services/models/mesh_service_localization.dart';
import '../../mesh_services/models/mesh_service_template.dart';
import '../../../providers/mesh_explorer_providers.dart';
import '../../../services/haptic_service.dart';
import '../../mesh_services/screens/service_detail_screen.dart';
import '../models/service_presentation.dart';

/// Display section for nearby MRRP services as rich discovery cards.
class MeshExplorerServicesSection extends StatelessWidget {
  /// List of individual service entries.
  final List<MeshExplorerServiceInfo> services;

  const MeshExplorerServicesSection({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Column(
        children: [
          for (int i = 0; i < services.length; i++) ...[
            _ServiceDiscoveryCard(service: services[i]),
            if (i < services.length - 1)
              const SizedBox(height: AppTheme.spacing12),
          ],
        ],
      ),
    );
  }
}

/// A rich service discovery card — the primary UI element of Mesh Explorer.
class _ServiceDiscoveryCard extends ConsumerWidget {
  final MeshExplorerServiceInfo service;

  const _ServiceDiscoveryCard({required this.service});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final canonicalType = service.canonicalType;
    final presetId = service.presetId;
    final resolved = canonicalType == null
        ? null
        : MeshServiceCatalog.resolve(
            canonicalType: canonicalType,
            presetId: presetId,
          );
    final presentation = ServicePresentationCatalog.forServiceId(
      service.serviceId,
      l10n,
    );
    final capabilityLabel = canonicalType == null
        ? presentation.title
        : meshServiceTypeName(l10n, canonicalType);
    final serviceTitle =
        service.metadata ??
        (presetId != null
            ? meshServicePresetName(l10n, presetId)
            : capabilityLabel);
    final accent =
        resolved?.accentColor ??
        (presentation.privacyClass == ServicePrivacyClass.open
            ? context.accentColor
            : SemanticColors.warning);
    final icon = resolved?.icon ?? presentation.icon;
    final presetLabel = presetId == null
        ? null
        : meshServicePresetName(l10n, presetId);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        onTap: () async {
          final haptics = ref.read(hapticServiceProvider);
          await haptics.trigger(HapticType.selection);

          if (!context.mounted) return;

          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ServiceDetailScreen(
                nodeId: service.nodeId,
                serviceId: service.serviceId,
                serviceType: capabilityLabel,
                serviceTitle: serviceTitle,
                icon: icon,
                accentColor: accent,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius16),
            border: Border.all(color: context.border.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: icon + title + badges
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service type icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                    child: Icon(icon, size: 24, color: accent),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          serviceTitle,
                          style: context.bodyStyle?.copyWith(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppTheme.spacing4),
                        if (serviceTitle != capabilityLabel)
                          Text(
                            capabilityLabel,
                            style: context.captionStyle?.copyWith(
                              color: context.textTertiary,
                            ),
                          ),
                        if (presetLabel != null) ...[
                          const SizedBox(height: AppTheme.spacing6),
                          _PresetBadge(label: presetLabel, accent: accent),
                        ],
                      ],
                    ),
                  ),
                  // Badges
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _LiveBadge(l10n: l10n),
                      const SizedBox(height: AppTheme.spacing4),
                      _AccessBadge(presentation: presentation, l10n: l10n),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.spacing12),

              // Bottom row: creator + freshness + CTA
              Row(
                children: [
                  // Creator identity
                  SigilAvatar(nodeNum: service.creatorSigilSeed, size: 22),
                  const SizedBox(width: AppTheme.spacing6),
                  Expanded(
                    child: Text(
                      service.creatorName ?? l10n.meshExplorerPeerAnonymous,
                      style: context.captionStyle?.copyWith(
                        color: service.isCreatorIdentified
                            ? context.textSecondary
                            : context.textTertiary,
                        fontWeight: service.isCreatorIdentified
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Freshness
                  Text(
                    _freshness(l10n, service.cachedAt),
                    style: context.captionStyle?.copyWith(
                      color: context.textTertiary,
                    ),
                  ),

                  const SizedBox(width: AppTheme.spacing8),

                  // CTA arrow
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: context.textTertiary.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _freshness(AppLocalizations l10n, DateTime cachedAt) {
    final elapsed = DateTime.now().difference(cachedAt);
    if (elapsed.inMinutes < 1) {
      return l10n.meshExplorerFreshnessJustNow;
    }
    if (elapsed.inHours < 1) {
      return l10n.meshExplorerFreshnessMinutes(elapsed.inMinutes);
    }
    return l10n.meshExplorerFreshnessHours(elapsed.inHours);
  }
}

class _PresetBadge extends StatelessWidget {
  final String label;
  final Color accent;

  const _PresetBadge({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing6,
        vertical: AppTheme.spacing2,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: accent,
        ),
      ),
    );
  }
}

/// Small "LIVE" badge.
class _LiveBadge extends StatelessWidget {
  final AppLocalizations l10n;

  const _LiveBadge({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing6,
        vertical: AppTheme.spacing2,
      ),
      decoration: BoxDecoration(
        color: SemanticColors.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: SemanticColors.success,
            ),
          ),
          const SizedBox(width: AppTheme.spacing4),
          Text(
            l10n.meshExplorerCardLive,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: SemanticColors.success,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Access badge (Open / Consent / Identity).
class _AccessBadge extends StatelessWidget {
  final ServicePresentation presentation;
  final AppLocalizations l10n;

  const _AccessBadge({required this.presentation, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (presentation.privacyClass) {
      ServicePrivacyClass.open => (
        l10n.meshExplorerCardOpen,
        SemanticColors.success,
      ),
      ServicePrivacyClass.consentGated => (
        l10n.meshExplorerPeerHandshaked,
        SemanticColors.warning,
      ),
      ServicePrivacyClass.identityGated => (
        l10n.meshExplorerPeerVerified,
        SemanticColors.info,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing6,
        vertical: AppTheme.spacing2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
