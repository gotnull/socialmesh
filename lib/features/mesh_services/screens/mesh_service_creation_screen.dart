// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Service creation flow screen.
///
/// Collects title, description, TTL, and template-specific fields.
/// Shows a preview before publishing. Publishes via the engine.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../services/haptic_service.dart';
import '../../../utils/snackbar.dart';
import '../models/mesh_service_template.dart';
import '../providers/mesh_service_providers.dart';

/// Maximum poll options.
const _maxPollOptions = 6;

/// Maximum checklist/resource items.
const _maxListItems = 10;

/// Minimum poll options.
const _minPollOptions = 2;

/// Service creation screen for a specific template.
class MeshServiceCreationScreen extends ConsumerStatefulWidget {
  final MeshServiceTemplate template;

  const MeshServiceCreationScreen({super.key, required this.template});

  @override
  ConsumerState<MeshServiceCreationScreen> createState() =>
      _MeshServiceCreationScreenState();
}

class _MeshServiceCreationScreenState
    extends ConsumerState<MeshServiceCreationScreen>
    with LifecycleSafeMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  /// Poll question (uses _titleController).
  final _optionControllers = <TextEditingController>[];

  /// Checklist / resource list items.
  final _itemControllers = <TextEditingController>[];

  late int _ttlMinutes;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _ttlMinutes = widget.template.defaultTtlMinutes;

    // Initialize poll options.
    if (widget.template.id == MeshServiceTemplateId.poll) {
      _optionControllers.addAll([
        TextEditingController(),
        TextEditingController(),
      ]);
    }

    // Initialize list items.
    if (widget.template.id == MeshServiceTemplateId.checklist ||
        widget.template.id == MeshServiceTemplateId.resourceList) {
      _itemControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    for (final c in _itemControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (title, _) = _templateStrings(l10n);
    final accent = widget.template.accentColor;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold(
        title: title,
        slivers: [
          SliverToBoxAdapter(
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppTheme.spacing16),

                    // Template header card
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacing12),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius8,
                              ),
                            ),
                            child: Icon(
                              widget.template.icon,
                              size: 18,
                              color: accent,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacing12),
                          Expanded(
                            child: Text(
                              title,
                              style: context.bodyStyle?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacing24),
                    _buildTitleField(l10n),
                    const SizedBox(height: AppTheme.spacing16),
                    _buildDescriptionField(l10n),
                    if (_buildTemplateFields(l10n).isNotEmpty) ...[
                      Divider(
                        height: AppTheme.spacing32,
                        color: context.border.withValues(alpha: 0.15),
                      ),
                      ..._buildTemplateFields(l10n),
                    ],
                    Divider(
                      height: AppTheme.spacing32,
                      color: context.border.withValues(alpha: 0.15),
                    ),
                    _buildDurationSelector(l10n, accent),
                    Divider(
                      height: AppTheme.spacing32,
                      color: context.border.withValues(alpha: 0.15),
                    ),
                    _buildPublishButton(l10n),
                    const SizedBox(height: AppTheme.spacing48),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField(dynamic l10n) {
    final isPoll = widget.template.id == MeshServiceTemplateId.poll;
    return TextFormField(
      controller: _titleController,
      maxLength: widget.template.maxTitleLength,
      decoration: InputDecoration(
        labelText: isPoll
            ? l10n.meshServicesFieldQuestion as String
            : l10n.meshServicesFieldTitle as String,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return l10n.meshServicesTitleRequired as String;
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField(dynamic l10n) {
    return TextFormField(
      controller: _descriptionController,
      maxLength: widget.template.maxDescriptionLength,
      maxLines: 2,
      decoration: InputDecoration(
        labelText: l10n.meshServicesFieldDescription as String,
      ),
    );
  }

  List<Widget> _buildTemplateFields(dynamic l10n) {
    return switch (widget.template.id) {
      MeshServiceTemplateId.poll => _buildPollFields(l10n),
      MeshServiceTemplateId.checklist ||
      MeshServiceTemplateId.resourceList => _buildListFields(l10n),
      _ => const [],
    };
  }

  List<Widget> _buildPollFields(dynamic l10n) {
    return [
      for (var i = 0; i < _optionControllers.length; i++) ...[
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _optionControllers[i],
                maxLength: 40,
                decoration: InputDecoration(
                  labelText: l10n.meshServicesFieldOption(i + 1) as String,
                ),
              ),
            ),
            if (_optionControllers.length > _minPollOptions)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                color: SemanticColors.error,
                onPressed: () => _removeOption(i),
              ),
          ],
        ),
      ],
      if (_optionControllers.length < _maxPollOptions) ...[
        const SizedBox(height: AppTheme.spacing8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addOption,
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.meshServicesFieldAddOption as String),
          ),
        ),
      ],
    ];
  }

  List<Widget> _buildListFields(dynamic l10n) {
    return [
      for (var i = 0; i < _itemControllers.length; i++) ...[
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _itemControllers[i],
                maxLength: 60,
                decoration: InputDecoration(
                  labelText: l10n.meshServicesFieldItem(i + 1) as String,
                ),
              ),
            ),
            if (_itemControllers.length > 1)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                color: SemanticColors.error,
                onPressed: () => _removeItem(i),
              ),
          ],
        ),
      ],
      if (_itemControllers.length < _maxListItems) ...[
        const SizedBox(height: AppTheme.spacing8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addItem,
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.meshServicesFieldAddItem as String),
          ),
        ),
      ],
    ];
  }

  Widget _buildDurationSelector(dynamic l10n, Color accent) {
    final max = widget.template.maxTtlMinutes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.meshServicesFieldDuration as String,
          style: context.bodySmallStyle?.copyWith(
            color: context.textTertiary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: AppTheme.spacing8),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing12,
            vertical: AppTheme.spacing8,
          ),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            border: Border.all(color: context.border.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.schedule, size: 16, color: accent),
              const SizedBox(width: AppTheme.spacing8),
              Expanded(
                child: Slider(
                  value: _ttlMinutes.toDouble(),
                  min: 5,
                  max: max.toDouble(),
                  divisions: (max - 5) ~/ 5,
                  activeColor: accent,
                  onChanged: (value) {
                    setState(() => _ttlMinutes = value.round());
                  },
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              SizedBox(
                width: 60,
                child: Text(
                  _ttlMinutes >= 60
                      ? l10n.meshServicesDurationHours(_ttlMinutes ~/ 60)
                            as String
                      : l10n.meshServicesDurationMinutes(_ttlMinutes) as String,
                  style: context.bodySmallStyle?.copyWith(
                    color: context.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPublishButton(dynamic l10n) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _publishing ? null : _onPublish,
        child: _publishing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(l10n.meshServicesPublishAction as String),
      ),
    );
  }

  void _addOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
    });
  }

  void _addItem() {
    setState(() {
      _itemControllers.add(TextEditingController());
    });
  }

  void _removeItem(int index) {
    setState(() {
      _itemControllers[index].dispose();
      _itemControllers.removeAt(index);
    });
  }

  Future<void> _onPublish() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate template-specific fields.
    final l10n = context.l10n;
    if (widget.template.id == MeshServiceTemplateId.poll) {
      final filledOptions = _optionControllers
          .where((c) => c.text.trim().isNotEmpty)
          .length;
      if (filledOptions < _minPollOptions) {
        showErrorSnackBar(context, l10n.meshServicesMinOptions);
        return;
      }
    }
    if (widget.template.id == MeshServiceTemplateId.checklist ||
        widget.template.id == MeshServiceTemplateId.resourceList) {
      final filledItems = _itemControllers
          .where((c) => c.text.trim().isNotEmpty)
          .length;
      if (filledItems < 1) {
        showErrorSnackBar(context, l10n.meshServicesMinItems);
        return;
      }
    }

    final engine = ref.read(meshServiceEngineProvider);
    final haptics = ref.read(hapticServiceProvider);
    if (engine == null) return;

    setState(() => _publishing = true);

    await haptics.trigger(HapticType.medium);

    final config = _buildConfig();
    final instance = await engine.createInstance(
      templateId: widget.template.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      ttlMinutes: _ttlMinutes,
      config: config,
    );

    if (!mounted) return;

    setState(() => _publishing = false);

    if (instance != null) {
      showSuccessSnackBar(context, l10n.meshServicesPublishSuccess);
      Navigator.of(context)
        ..pop() // Pop creation screen.
        ..pop(); // Pop template picker (return to My Services).
    }
  }

  Map<String, dynamic> _buildConfig() {
    return switch (widget.template.id) {
      MeshServiceTemplateId.poll => {
        'options': _optionControllers
            .map((c) => c.text.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
      },
      MeshServiceTemplateId.checklist || MeshServiceTemplateId.resourceList => {
        'items': _itemControllers
            .map((c) => c.text.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
      },
      _ => const {},
    };
  }

  (String, String) _templateStrings(dynamic l10n) {
    return switch (widget.template.id) {
      MeshServiceTemplateId.board => (
        l10n.meshServicesTemplateBoard as String,
        l10n.meshServicesTemplateBoardDescription as String,
      ),
      MeshServiceTemplateId.signal => (
        l10n.meshServicesTemplateSignal as String,
        l10n.meshServicesTemplateSignalDescription as String,
      ),
      MeshServiceTemplateId.poll => (
        l10n.meshServicesTemplatePoll as String,
        l10n.meshServicesTemplatePollDescription as String,
      ),
      MeshServiceTemplateId.checklist => (
        l10n.meshServicesTemplateChecklist as String,
        l10n.meshServicesTemplateChecklistDescription as String,
      ),
      MeshServiceTemplateId.resourceList => (
        l10n.meshServicesTemplateResourceList as String,
        l10n.meshServicesTemplateResourceListDescription as String,
      ),
      MeshServiceTemplateId.weatherStation => (
        l10n.meshServicesTemplateWeatherStation as String,
        l10n.meshServicesTemplateWeatherStationDescription as String,
      ),
      MeshServiceTemplateId.sensorNode => (
        l10n.meshServicesTemplateSensorNode as String,
        l10n.meshServicesTemplateSensorNodeDescription as String,
      ),
      MeshServiceTemplateId.taskBoard => (
        l10n.meshServicesTemplateTaskBoard as String,
        l10n.meshServicesTemplateTaskBoardDescription as String,
      ),
      MeshServiceTemplateId.trailConditions => (
        l10n.meshServicesTemplateTrailConditions as String,
        l10n.meshServicesTemplateTrailConditionsDescription as String,
      ),
      MeshServiceTemplateId.lostAndFound => (
        l10n.meshServicesTemplateLostAndFound as String,
        l10n.meshServicesTemplateLostAndFoundDescription as String,
      ),
    };
  }
}
