// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/premium_gating.dart';
import '../../core/widgets/widget_preview_card.dart';
import '../../models/subscription_models.dart';
import '../../providers/subscription_providers.dart';
import '../../utils/encoding.dart';
import '../../utils/snackbar.dart';
import '../dashboard/widgets/schema_widget_content.dart';
import 'models/widget_schema.dart';

import 'widget_sync_providers.dart';
import 'editor/widget_editor_screen.dart';
import 'widget_builder_screen.dart';

/// Screen for importing widgets from deep links or QR codes
/// Handles: socialmesh://widget/{base64} (direct import)
///          socialmesh://widget/id:{firestoreId} (cloud import)
class WidgetImportScreen extends ConsumerStatefulWidget {
  const WidgetImportScreen({super.key, this.base64Data, this.firestoreId});

  final String? base64Data;
  final String? firestoreId;

  @override
  ConsumerState<WidgetImportScreen> createState() => _WidgetImportScreenState();
}

class _WidgetImportScreenState extends ConsumerState<WidgetImportScreen>
    with LifecycleSafeMixin<WidgetImportScreen> {
  WidgetSchema? _widget;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWidget();
  }

  Future<void> _loadWidget() async {
    safeSetState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (widget.firestoreId != null) {
        // Fetch from Firestore
        final doc = await FirebaseFirestore.instance
            .collection('shared_widgets')
            .doc(widget.firestoreId)
            .get();
        if (!mounted) return;

        if (!doc.exists) {
          safeSetState(() {
            _error = 'Widget not found or has been deleted';
            _isLoading = false;
          });
          return;
        }

        final data = doc.data()!;
        // Remove Firestore-specific fields before importing
        data.remove('createdBy');
        data.remove('createdAt');

        final importedWidget = WidgetSchema.fromJson(data);

        safeSetState(() {
          _widget = importedWidget;
          _isLoading = false;
        });

        AppLogging.widgets('Fetched widget from Firestore: ${_widget!.name}');
      } else if (widget.base64Data != null) {
        // Decode from base64 (handle URL-safe base64 from QR codes)
        final jsonString = utf8.decode(
          Base64Utils.decodeWithPadding(widget.base64Data!),
        );
        final json = jsonDecode(jsonString) as Map<String, dynamic>;

        // Create widget from JSON with new ID for import
        final importedWidget = WidgetSchema.fromJson(json);

        safeSetState(() {
          _widget = importedWidget;
          _isLoading = false;
        });

        AppLogging.widgets('Imported widget schema: ${_widget!.name}');
      } else {
        safeSetState(() {
          _error = 'No widget data provided';
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogging.widgets('Failed to import widget: $e');
      safeSetState(() {
        _error = 'Failed to load widget: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _importWidget() async {
    if (_widget == null) return;

    // Capture provider refs before awaits
    final purchaseNotifier = ref.read(purchaseStateProvider.notifier);

    // Refresh purchase state to ensure we have latest (important for deep links)
    await purchaseNotifier.refresh();
    if (!mounted) return;

    // Check entitlement before allowing import
    final hasPremium = ref.read(hasFeatureProvider(PremiumFeature.homeWidgets));
    if (!hasPremium) {
      final purchased = await showPremiumInfoSheet(
        context: context,
        ref: ref,
        feature: PremiumFeature.homeWidgets,
      );
      if (!purchased || !mounted) return;
    }

    // Capture navigator and messenger BEFORE any awaits
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      AppLogging.sync(
        '[WidgetImport] _importWidget — id=${_widget!.id}, '
        'name=${_widget!.name}',
      );
      final storageService = await ref.read(
        widgetStorageServiceProvider.future,
      );
      if (!mounted) return;
      await storageService.saveWidget(_widget!);
      if (!mounted) return;

      // Drain outbox immediately so the widget syncs promptly
      // (matching the pattern used by Automations)
      AppLogging.sync(
        '[WidgetImport] Widget saved, triggering drainOutboxNow()...',
      );
      final syncService = ref.read(widgetSyncServiceProvider);
      AppLogging.sync(
        '[WidgetImport] syncService=${syncService != null ? "exists(enabled=${syncService.isEnabled})" : "NULL"}',
      );
      await syncService?.drainOutboxNow();
      AppLogging.sync('[WidgetImport] drainOutboxNow() complete');
      if (!mounted) return;

      // Trigger refresh on any watching screens
      ref.read(widgetRefreshTriggerProvider.notifier).refresh();

      messenger.showSnackBar(
        SnackBar(
          content: const Text('Widget imported successfully'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              navigator.push(
                MaterialPageRoute(builder: (_) => const WidgetBuilderScreen()),
              );
            },
          ),
        ),
      );
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Failed to import: $e');
    }
  }

  Future<void> _editBeforeImport() async {
    if (_widget == null) return;

    // Capture provider refs before awaits
    final purchaseNotifier = ref.read(purchaseStateProvider.notifier);

    // Refresh purchase state to ensure we have latest (important for deep links)
    await purchaseNotifier.refresh();
    if (!mounted) return;

    // Check entitlement before allowing edit/import
    final hasPremium = ref.read(hasFeatureProvider(PremiumFeature.homeWidgets));
    if (!hasPremium) {
      final purchased = await showPremiumInfoSheet(
        context: context,
        ref: ref,
        feature: PremiumFeature.homeWidgets,
      );
      if (!purchased || !mounted) return;
    }

    final navigator = Navigator.of(context);
    final result = await navigator.push<WidgetSchema>(
      MaterialPageRoute(
        builder: (context) => WidgetEditorScreen(initialSchema: _widget),
      ),
    );

    if (result != null && mounted) {
      // Widget was saved in editor, just pop back
      showActionSnackBar(
        context,
        'Widget imported successfully',
        actionLabel: 'View',
        onAction: () {
          navigator.push(
            MaterialPageRoute(builder: (_) => const WidgetBuilderScreen()),
          );
        },
        type: SnackBarType.success,
      );
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Import Widget',
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _buildError()
              : _widget != null
              ? _buildPreview()
              : const SizedBox(),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppTheme.errorRed),
            const SizedBox(height: 16),
            Text(
              'Import Failed',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final widgetSchema = _widget!;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Preview Card using the actual widget preview
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.widgets_outlined,
                      color: context.accentColor,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widgetSchema.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (widgetSchema.description != null &&
                              widgetSchema.description!.isNotEmpty)
                            Text(
                              widgetSchema.description!,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey[400]),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Size',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: context.accentColor),
                ),
                const SizedBox(height: 4),
                Text(_getSizeDisplayName(widgetSchema.size)),
                if (widgetSchema.tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Tags',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: context.accentColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: widgetSchema.tags
                        .map(
                          (tag) => Chip(
                            label: Text(tag, style: context.bodySmallStyle),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Widget preview
          Text(
            'Preview',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: context.accentColor),
          ),
          const SizedBox(height: 8),
          Center(
            child: WidgetPreviewCard(
              schema: widgetSchema,
              title: widgetSchema.name,
            ),
          ),

          const SizedBox(height: 24),

          // Info notice
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.accentColor.withOpacity(0.1),
              border: Border.all(color: context.accentColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: context.accentColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This widget will be added to your custom widgets. You can edit it anytime.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _editBeforeImport,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit First'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _importWidget,
                  icon: const Icon(Icons.download),
                  label: const Text('Import'),
                ),
              ),
            ],
          ),
          // Bottom safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  String _getSizeDisplayName(CustomWidgetSize size) {
    switch (size) {
      case CustomWidgetSize.medium:
        return 'Medium (2x1)';
      case CustomWidgetSize.large:
        return 'Large (2x2)';
      case CustomWidgetSize.custom:
        return 'Custom size';
    }
  }
}
