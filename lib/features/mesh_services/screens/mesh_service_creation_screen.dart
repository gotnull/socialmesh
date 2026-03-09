// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Service creation flow screen.
///
/// Collects title, description, TTL, and template-specific fields.
/// Shows a preview before publishing. Publishes via the engine.
///
/// Design language mirrors [CreateSignalScreen]: GradientBorderContainer
/// for the primary input, card-styled secondary fields, BottomActionBar
/// with gradient publish button.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/bottom_action_bar.dart';
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
    with LifecycleSafeMixin, SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _titleFocusNode = FocusNode();

  /// Poll option controllers.
  final _optionControllers = <TextEditingController>[];

  /// Checklist / resource list item controllers.
  final _itemControllers = <TextEditingController>[];

  late int _ttlMinutes;
  bool _publishing = false;

  late final AnimationController _entryAnimationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

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

    _entryAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entryAnimationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entryAnimationController,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
          ),
        );

    _entryAnimationController.forward();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _titleFocusNode.dispose();
    _entryAnimationController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    for (final c in _itemControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // ─────────────────────── helpers ───────────────────────

  void _dismissKeyboard() => FocusScope.of(context).unfocus();

  bool get _isPoll => widget.template.id == MeshServiceTemplateId.poll;

  bool get _hasList =>
      widget.template.id == MeshServiceTemplateId.checklist ||
      widget.template.id == MeshServiceTemplateId.resourceList;

  // ─────────────────────── build ───────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (title, _) = _templateStrings(l10n);
    final accent = widget.template.accentColor;

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: GlassScaffold(
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: _publishing ? context.textTertiary : context.textPrimary,
          ),
          onPressed: _publishing ? null : () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            Text(
              l10n.meshServicesCreateTitle,
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: true,
            child: Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _dismissKeyboard,
                    behavior: HitTestBehavior.opaque,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spacing20,
                        AppTheme.spacing8,
                        AppTheme.spacing20,
                        AppTheme.spacing20,
                      ),
                      child: Form(
                        key: _formKey,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Template badge ──
                                _TemplateBadge(
                                  template: widget.template,
                                  title: title,
                                ),

                                const SizedBox(height: AppTheme.spacing20),

                                // ── Title input (primary) ──
                                _buildTitleInput(l10n, accent),

                                const SizedBox(height: AppTheme.spacing16),

                                // ── Description field ──
                                _buildDescriptionField(l10n),

                                // ── Template-specific fields ──
                                if (_isPoll) ...[
                                  const SizedBox(height: AppTheme.spacing16),
                                  ..._buildPollFields(l10n, accent),
                                ],
                                if (_hasList) ...[
                                  const SizedBox(height: AppTheme.spacing16),
                                  ..._buildListFields(l10n, accent),
                                ],

                                const SizedBox(height: AppTheme.spacing16),

                                // ── Duration selector ──
                                _buildDurationSelector(l10n, accent),

                                const SizedBox(height: AppTheme.spacing16),

                                // ── Privacy note ──
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.shield_outlined,
                                      size: 14,
                                      color: context.textTertiary,
                                    ),
                                    const SizedBox(width: AppTheme.spacing6),
                                    Expanded(
                                      child: Text(
                                        l10n.meshServicesPreviewSubtitle,
                                        style: TextStyle(
                                          color: context.textTertiary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: AppTheme.spacing48),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Publish button ──
                _buildPublishButton(l10n, accent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────── primary title input ───────────────────

  Widget _buildTitleInput(dynamic l10n, Color accent) {
    return TextFormField(
      controller: _titleController,
      focusNode: _titleFocusNode,
      enabled: !_publishing,
      maxLines: 2,
      minLines: 1,
      maxLength: widget.template.maxTitleLength,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      textCapitalization: TextCapitalization.sentences,
      inputFormatters: [
        LengthLimitingTextInputFormatter(widget.template.maxTitleLength),
      ],
      style: TextStyle(color: context.textPrimary),
      decoration: InputDecoration(
        labelText:
            (_isPoll
                    ? l10n.meshServicesFieldQuestion
                    : l10n.meshServicesFieldTitle)
                as String,
        labelStyle: TextStyle(color: context.textSecondary),
        hintText: _isPoll
            ? l10n.meshServicesFieldQuestion as String
            : l10n.meshServicesFieldTitle as String,
        hintStyle: TextStyle(color: context.textSecondary.withAlpha(128)),
        filled: true,
        fillColor: context.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          borderSide: BorderSide.none,
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        counterStyle: TextStyle(color: context.textSecondary),
        counterText: '',
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return l10n.meshServicesTitleRequired as String;
        }
        return null;
      },
      onChanged: (_) => setState(() {}),
    );
  }

  // ─────────────────── description field ───────────────────

  Widget _buildDescriptionField(dynamic l10n) {
    final accent = widget.template.accentColor;

    return TextFormField(
      controller: _descriptionController,
      enabled: !_publishing,
      maxLines: 5,
      minLines: 3,
      maxLength: widget.template.maxDescriptionLength,
      textCapitalization: TextCapitalization.sentences,
      style: TextStyle(color: context.textPrimary),
      decoration: InputDecoration(
        labelText: l10n.meshServicesFieldDescription as String,
        labelStyle: TextStyle(color: context.textSecondary),
        hintText: l10n.meshServicesDescriptionHint as String,
        hintStyle: TextStyle(
          color: context.textSecondary.withValues(alpha: 0.5),
        ),
        filled: true,
        fillColor: context.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  // ─────────────────── poll fields ───────────────────

  List<Widget> _buildPollFields(dynamic l10n, Color accent) {
    return [
      // Section label
      _SectionLabel(
        icon: Icons.poll_outlined,
        label: l10n.meshServicesTemplatePoll as String,
        color: accent,
      ),
      const SizedBox(height: AppTheme.spacing10),

      // Options
      for (var i = 0; i < _optionControllers.length; i++) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            border: Border.all(color: context.border.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radius6),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacing10),
              Expanded(
                child: TextField(
                  controller: _optionControllers[i],
                  enabled: !_publishing,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(color: context.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: l10n.meshServicesFieldOption(i + 1) as String,
                    hintStyle: TextStyle(
                      color: context.textTertiary,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    counterText: '',
                  ),
                ),
              ),
              if (_optionControllers.length > _minPollOptions)
                BouncyTap(
                  onTap: _publishing ? null : () => _removeOption(i),
                  child: Icon(
                    Icons.remove_circle_outline,
                    size: 20,
                    color: SemanticColors.error.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
        ),
        if (i < _optionControllers.length - 1)
          const SizedBox(height: AppTheme.spacing8),
      ],

      // Add option button
      if (_optionControllers.length < _maxPollOptions) ...[
        const SizedBox(height: AppTheme.spacing10),
        BouncyTap(
          onTap: _publishing ? null : _addOption,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppTheme.radius12),
              border: Border.all(color: accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 18, color: accent),
                const SizedBox(width: AppTheme.spacing8),
                Text(
                  l10n.meshServicesFieldAddOption as String,
                  style: TextStyle(
                    color: accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ];
  }

  // ─────────────────── list fields ───────────────────

  List<Widget> _buildListFields(dynamic l10n, Color accent) {
    final isChecklist = widget.template.id == MeshServiceTemplateId.checklist;

    return [
      // Section label
      _SectionLabel(
        icon: isChecklist ? Icons.checklist_outlined : Icons.list_alt_outlined,
        label: isChecklist
            ? l10n.meshServicesTemplateChecklist as String
            : l10n.meshServicesTemplateResourceList as String,
        color: accent,
      ),
      const SizedBox(height: AppTheme.spacing10),

      // Items
      for (var i = 0; i < _itemControllers.length; i++) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            border: Border.all(color: context.border.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(
                isChecklist
                    ? Icons.check_box_outline_blank
                    : Icons.circle_outlined,
                size: 18,
                color: accent.withValues(alpha: 0.5),
              ),
              const SizedBox(width: AppTheme.spacing10),
              Expanded(
                child: TextField(
                  controller: _itemControllers[i],
                  enabled: !_publishing,
                  maxLength: 60,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(color: context.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: l10n.meshServicesFieldItem(i + 1) as String,
                    hintStyle: TextStyle(
                      color: context.textTertiary,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    counterText: '',
                  ),
                ),
              ),
              if (_itemControllers.length > 1)
                BouncyTap(
                  onTap: _publishing ? null : () => _removeItem(i),
                  child: Icon(
                    Icons.remove_circle_outline,
                    size: 20,
                    color: SemanticColors.error.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
        ),
        if (i < _itemControllers.length - 1)
          const SizedBox(height: AppTheme.spacing8),
      ],

      // Add item button
      if (_itemControllers.length < _maxListItems) ...[
        const SizedBox(height: AppTheme.spacing10),
        BouncyTap(
          onTap: _publishing ? null : _addItem,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppTheme.radius12),
              border: Border.all(color: accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 18, color: accent),
                const SizedBox(width: AppTheme.spacing8),
                Text(
                  l10n.meshServicesFieldAddItem as String,
                  style: TextStyle(
                    color: accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ];
  }

  // ─────────────────── duration selector ───────────────────

  Widget _buildDurationSelector(dynamic l10n, Color accent) {
    final max = widget.template.maxTtlMinutes;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: accent),
              const SizedBox(width: AppTheme.spacing8),
              Text(
                l10n.meshServicesFieldDuration as String,
                style: TextStyle(
                  color: context.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                _ttlMinutes >= 60
                    ? l10n.meshServicesDurationHours(_ttlMinutes ~/ 60)
                          as String
                    : l10n.meshServicesDurationMinutes(_ttlMinutes) as String,
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: accent,
              inactiveTrackColor: context.border.withValues(alpha: 0.2),
              thumbColor: accent,
              overlayColor: accent.withValues(alpha: 0.12),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: _ttlMinutes.toDouble(),
              min: 5,
              max: max.toDouble(),
              divisions: (max - 5) ~/ 5,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() => _ttlMinutes = value.round());
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────── publish button ───────────────────

  Widget _buildPublishButton(dynamic l10n, Color accent) {
    final gradientColors = _publishing
        ? [accent.withValues(alpha: 0.5), accent.withValues(alpha: 0.4)]
        : [accent, accent.withValues(alpha: 0.8)];

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: _entryAnimationController,
                curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
              ),
            ),
        child: BottomActionBar(
          child: BouncyTap(
            onTap: _publishing ? null : _onPublish,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: gradientColors,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radius16),
                boxShadow: _publishing
                    ? null
                    : [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: _publishing
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.publish_rounded,
                          size: 22,
                          color: Colors.white,
                        ),
                        const SizedBox(width: AppTheme.spacing10),
                        Text(
                          l10n.meshServicesPublishAction as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────── actions ───────────────────

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
    if (_isPoll) {
      final filledOptions = _optionControllers
          .where((c) => c.text.trim().isNotEmpty)
          .length;
      if (filledOptions < _minPollOptions) {
        showErrorSnackBar(context, l10n.meshServicesMinOptions);
        return;
      }
    }
    if (_hasList) {
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

// ═══════════════════════════════════════════════════════════════
// Private widgets
// ═══════════════════════════════════════════════════════════════

/// Template badge shown above the main input.
class _TemplateBadge extends StatelessWidget {
  const _TemplateBadge({required this.template, required this.title});

  final MeshServiceTemplate template;
  final String title;

  @override
  Widget build(BuildContext context) {
    final accent = template.accentColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(template.icon, size: 16, color: accent),
          const SizedBox(width: AppTheme.spacing8),
          Text(
            title,
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (template.isPublic) ...[
            const SizedBox(width: AppTheme.spacing8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: SemanticColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radius6),
              ),
              child: const Text(
                'Open', // lint-allow: hardcoded-string
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: SemanticColors.success,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Section label row for template-specific field groups.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: AppTheme.spacing6),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: context.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}
