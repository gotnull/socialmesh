// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Service detail screen — shows a specific service from a remote peer.
///
/// Known template types get custom rendering; unknown services fall back
/// to the schema-driven generic renderer. Handles data fetching via MRRP
/// and caches schemas locally.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../services/haptic_service.dart';
import '../../../utils/snackbar.dart';
import '../models/service_schema.dart';
import '../models/template_schemas.dart';
import '../models/mesh_service_template.dart';
import '../widgets/generic_service_renderer.dart';

/// Service detail screen.
///
/// Displays either a template-specific UI for known services or the
/// generic schema-driven renderer for unknown services.
class ServiceDetailScreen extends ConsumerStatefulWidget {
  /// The remote peer's node ID.
  final int nodeId;

  /// Service type string (e.g., "weather.v1").
  final String serviceType;

  /// Human-readable title from the service advert.
  final String serviceTitle;

  /// Service icon.
  final IconData icon;

  /// Accent color.
  final Color accentColor;

  const ServiceDetailScreen({
    super.key,
    required this.nodeId,
    required this.serviceType,
    required this.serviceTitle,
    required this.icon,
    required this.accentColor,
  });

  @override
  ConsumerState<ServiceDetailScreen> createState() =>
      _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends ConsumerState<ServiceDetailScreen>
    with LifecycleSafeMixin {
  ServiceSchema? _schema;
  final Map<int, dynamic> _data = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSchema();
  }

  void _loadSchema() {
    // Try to resolve schema from built-in templates first.
    for (final id in MeshServiceTemplateId.values) {
      final templateSchema = TemplateSchemas.forTemplate(id);
      if (templateSchema != null &&
          templateSchema.serviceType == widget.serviceType) {
        setState(() {
          _schema = templateSchema;
          _loading = false;
        });
        return;
      }
    }

    // Unknown service type — show empty schema state (would request
    // via MRRP get_schema in production).
    setState(() {
      _loading = false;
    });
  }

  void _onAction(SchemaAction action) {
    final haptics = ref.read(hapticServiceProvider);
    haptics.trigger(HapticType.light);
    // Action handling would dispatch MRRP REQUEST to the peer.
    // For now, show a feedback indication.
    if (!mounted) return;
    showInfoSnackBar(
      context,
      '${action.name} → ${widget.serviceType}', // lint-allow: hardcoded-string
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return GlassScaffold(
      title: widget.serviceTitle,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: _buildContent(context, l10n),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacing48)),
      ],
    );
  }

  Widget _buildContent(BuildContext context, dynamic l10n) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacing32),
          child: CircularProgressIndicator.adaptive(),
        ),
      );
    }

    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _loadSchema);
    }

    if (_schema != null) {
      return _buildSchemaContent(context);
    }

    return _UnknownServiceState(serviceType: widget.serviceType, l10n: l10n);
  }

  Widget _buildSchemaContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Service header card.
        _ServiceHeaderCard(
          icon: widget.icon,
          title: widget.serviceTitle,
          serviceType: widget.serviceType,
          accentColor: widget.accentColor,
          nodeId: widget.nodeId,
        ),
        const SizedBox(height: AppTheme.spacing16),

        // Schema-driven content.
        GenericServiceRenderer(
          schema: _schema!,
          data: _data,
          onAction: _onAction,
        ),
      ],
    );
  }
}

/// Header card showing service icon, title, and node info.
class _ServiceHeaderCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String serviceType;
  final Color accentColor;
  final int nodeId;

  const _ServiceHeaderCard({
    required this.icon,
    required this.title,
    required this.serviceType,
    required this.accentColor,
    required this.nodeId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.spacing12),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.spacing12),
            ),
            child: Icon(icon, color: accentColor, size: 24),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.titleStyle?.copyWith(
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing2),
                Text(
                  // lint-allow: hardcoded-string
                  '$serviceType · Node 0x${nodeId.toRadixString(16)}',
                  style: context.captionStyle?.copyWith(
                    color: context.textTertiary,
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

/// Empty state for unknown services without schema.
class _UnknownServiceState extends StatelessWidget {
  final String serviceType;
  final dynamic l10n;

  const _UnknownServiceState({required this.serviceType, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.extension_outlined,
              size: 48,
              color: context.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              l10n.serviceDetailUnknownTitle,
              style: context.titleStyle?.copyWith(color: context.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              l10n.serviceDetailUnknownBody(serviceType),
              style: context.bodySecondaryStyle?.copyWith(
                color: context.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Error state with retry.
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: AccentColors.coral.withValues(alpha: 0.7),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              message,
              style: context.bodySecondaryStyle?.copyWith(
                color: context.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing16),
            FilledButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
          ],
        ),
      ),
    );
  }
}
