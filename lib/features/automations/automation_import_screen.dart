// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/premium_gating.dart';
import '../../models/subscription_models.dart';
import '../../providers/subscription_providers.dart';
import '../../utils/snackbar.dart';
import 'models/automation.dart';
import 'automation_providers.dart';
import 'automation_editor_screen.dart';

/// Screen for importing automations from deep links or QR codes
/// Handles: socialmesh://automation/{base64} or Firestore ID lookup
class AutomationImportScreen extends ConsumerStatefulWidget {
  const AutomationImportScreen({super.key, this.base64Data, this.firestoreId});

  final String? base64Data;
  final String? firestoreId;

  @override
  ConsumerState<AutomationImportScreen> createState() =>
      _AutomationImportScreenState();
}

class _AutomationImportScreenState
    extends ConsumerState<AutomationImportScreen> {
  Automation? _automation;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAutomation();
  }

  Future<void> _loadAutomation() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (widget.base64Data != null) {
        // Decode from base64
        final jsonString = utf8.decode(base64Decode(widget.base64Data!));
        final json = jsonDecode(jsonString) as Map<String, dynamic>;

        // Create automation from JSON (without id/timestamps for import)
        setState(() {
          _automation = Automation(
            name: json['name'] as String,
            description: json['description'] as String?,
            enabled: false, // Start disabled for review
            trigger: AutomationTrigger.fromJson(
              json['trigger'] as Map<String, dynamic>,
            ),
            actions: (json['actions'] as List)
                .map(
                  (a) => AutomationAction.fromJson(a as Map<String, dynamic>),
                )
                .toList(),
            conditions: (json['conditions'] as List?)
                ?.map(
                  (c) =>
                      AutomationCondition.fromJson(c as Map<String, dynamic>),
                )
                .toList(),
          );
          _isLoading = false;
        });

        AppLogging.debug('Imported automation: ${_automation!.name}');
      } else if (widget.firestoreId != null) {
        final doc = await FirebaseFirestore.instance
            .collection('shared_automations')
            .doc(widget.firestoreId)
            .get();

        if (!doc.exists) {
          setState(() {
            _error = 'Automation not found or has been deleted';
            _isLoading = false;
          });
          return;
        }

        final data = doc.data()!;
        setState(() {
          _automation = Automation(
            name: data['name'] as String,
            description: data['description'] as String?,
            enabled: false,
            trigger: AutomationTrigger.fromJson(
              data['trigger'] as Map<String, dynamic>,
            ),
            actions: (data['actions'] as List)
                .map(
                  (a) => AutomationAction.fromJson(a as Map<String, dynamic>),
                )
                .toList(),
            conditions: (data['conditions'] as List?)
                ?.map(
                  (c) =>
                      AutomationCondition.fromJson(c as Map<String, dynamic>),
                )
                .toList(),
          );
          _isLoading = false;
        });

        AppLogging.debug(
          'Fetched automation from Firestore: ${_automation!.name}',
        );
      } else {
        setState(() {
          _error = 'No automation data provided';
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogging.debug('Failed to import automation: $e');
      setState(() {
        _error = 'Failed to import automation: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _importAutomation() async {
    if (_automation == null) return;

    // Check entitlement before allowing import
    final hasPremium = ref.read(hasFeatureProvider(PremiumFeature.automations));
    if (!hasPremium) {
      await showPremiumInfoSheet(
        context: context,
        ref: ref,
        feature: PremiumFeature.automations,
      );
      return;
    }

    try {
      // Add to automations repository
      final notifier = ref.read(automationsProvider.notifier);
      await notifier.addAutomation(_automation!);

      if (mounted) {
        showSuccessSnackBar(context, 'Automation imported successfully');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to import: $e');
      }
    }
  }

  Future<void> _editBeforeImport() async {
    if (_automation == null) return;

    // Check entitlement before allowing edit/import
    final hasPremium = ref.read(hasFeatureProvider(PremiumFeature.automations));
    if (!hasPremium) {
      await showPremiumInfoSheet(
        context: context,
        ref: ref,
        feature: PremiumFeature.automations,
      );
      return;
    }

    final result = await Navigator.of(context).push<Automation>(
      MaterialPageRoute(
        builder: (context) => AutomationEditorScreen(automation: _automation),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _automation = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Import Automation',
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _buildError()
              : _automation != null
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
    final automation = _automation!;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Preview Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        automation.trigger.type.icon,
                        color: context.accentColor,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              automation.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (automation.description != null)
                              Text(
                                automation.description!,
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
                    'Trigger',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: context.accentColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(automation.trigger.type.displayName),
                  const SizedBox(height: 16),
                  Text(
                    'Actions (${automation.actions.length})',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: context.accentColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...automation.actions.map(
                    (action) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            action.type.icon,
                            size: 16,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              action.type.displayName,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (automation.conditions != null &&
                      automation.conditions!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Conditions (${automation.conditions!.length})',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: context.accentColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${automation.conditions!.length} conditions'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Warning
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warningYellow.withOpacity(0.1),
              border: Border.all(color: AppTheme.warningYellow),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.warningYellow),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This automation will be imported as disabled. Review and enable it when ready.',
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
                  onPressed: _importAutomation,
                  icon: const Icon(Icons.download),
                  label: const Text('Import'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
