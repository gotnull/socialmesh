// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Service creation flow screen.
///
/// Collects title, description, TTL, and capability-specific fields.
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
import '../../../core/widgets/completion_state_panel.dart';
import '../../../core/widgets/expert_details_expander.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../l10n/app_localizations.dart';

import '../../../services/haptic_service.dart';
import '../../../utils/snackbar.dart';
import '../models/mesh_service_signal_kind.dart';
import '../models/mesh_service_localization.dart';
import '../models/mesh_service_template.dart';
import '../presentation/mesh_service_presentation.dart';
import '../providers/mesh_service_providers.dart';

/// Maximum poll options.
const _maxPollOptions = 6;

/// Maximum checklist/resource items.
const _maxListItems = 10;

/// Minimum poll options.
const _minPollOptions = 2;

/// Service creation screen for a canonical service capability.
///
/// When [embedded] is `true` the screen strips its own scaffold and publish
/// button, rendering only the form content — designed to live inside a
/// parent wizard's [PageView].
class MeshServiceCreationScreen extends ConsumerStatefulWidget {
  final MeshServiceType canonicalType;
  final MeshServicePresetId? presetId;

  /// If `true`, renders only the scrollable form (no scaffold/publish bar).
  final bool embedded;

  const MeshServiceCreationScreen({
    super.key,
    required this.canonicalType,
    this.presetId,
    this.embedded = false,
  });

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

  final _sensorValueController = TextEditingController();
  final _sensorUnitController = TextEditingController();
  final _sensorSourceController = TextEditingController();

  late int _ttlMinutes;
  MeshServiceSignalKind _signalKind = MeshServiceSignalKind.checkIn;
  bool _publishing = false;
  bool _publishedSuccessfully = false;

  late final AnimationController _entryAnimationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  MeshServiceResolvedDefinition get _resolved => MeshServiceCatalog.resolve(
    canonicalType: widget.canonicalType,
    presetId: widget.presetId,
  );

  MeshServicePresentationSpec get _presentation =>
      MeshServicePresentationRegistry.forType(widget.canonicalType);

  @override
  void initState() {
    super.initState();
    _ttlMinutes = _resolved.defaultTtlMinutes;

    // Initialize poll options.
    if (_isPoll) {
      _optionControllers.addAll([
        TextEditingController(),
        TextEditingController(),
      ]);
    }

    // Initialize list items.
    if (_hasList) {
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
    _sensorValueController.dispose();
    _sensorUnitController.dispose();
    _sensorSourceController.dispose();
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

  bool get _isPoll => widget.canonicalType == MeshServiceType.poll;

  bool get _hasList => widget.canonicalType == MeshServiceType.list;

  bool get _isSensor => widget.canonicalType == MeshServiceType.sensor;

  String _displayName(AppLocalizations l10n) {
    return meshServiceDisplayName(
      l10n,
      canonicalType: widget.canonicalType,
      presetId: _resolved.presetId,
    );
  }

  String _previewTitle(AppLocalizations l10n) {
    final title = _titleController.text.trim();
    if (title.isNotEmpty) return title;
    return l10n.meshServicesPreviewPlaceholder;
  }

  String _previewDescription(AppLocalizations l10n) {
    final description = _descriptionController.text.trim();
    if (description.isNotEmpty) return description;
    return l10n.meshServicesPreviewNoDetails;
  }

  String _formattedVisibleFor(dynamic l10n) {
    final formatted = _ttlMinutes >= 60
        ? l10n.meshServicesDurationHours(_ttlMinutes ~/ 60) as String
        : l10n.meshServicesDurationMinutes(_ttlMinutes) as String;
    return l10n.meshServicesVisibleFor(formatted) as String;
  }

  MeshServiceComposeDraft _buildDraft() {
    return MeshServiceComposeDraft(
      title: _previewTitle(context.l10n),
      description: _previewDescription(context.l10n),
      ttlMinutes: _ttlMinutes,
      options: _optionControllers
          .map((controller) => controller.text.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      items: _itemControllers
          .map((controller) => controller.text.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      signalKind: _signalKind,
      sensorValue: _sensorValueController.text.trim(),
      sensorUnit: _sensorUnitController.text.trim(),
      sensorSource: _sensorSourceController.text.trim(),
    );
  }

  MeshServiceComposeController _buildComposeController() {
    return MeshServiceComposeController(
      isPublishing: _publishing,
      optionControllers: _optionControllers,
      onAddOption: _addOption,
      onRemoveOption: _removeOption,
      itemControllers: _itemControllers,
      onAddItem: _addItem,
      onRemoveItem: _removeItem,
      signalKind: _signalKind,
      onSignalKindChanged: (kind) => setState(() => _signalKind = kind),
      sensorValueController: _sensorValueController,
      sensorUnitController: _sensorUnitController,
      sensorSourceController: _sensorSourceController,
      onChanged: () => setState(() {}),
      maxPollOptions: _maxPollOptions,
      maxListItems: _maxListItems,
    );
  }

  // ─────────────────────── build ───────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = _displayName(l10n);
    final accent = _resolved.accentColor;

    // Embedded mode: just the scrollable form content, no scaffold/publish.
    if (widget.embedded) {
      return _buildFormContent(context, l10n, title, accent);
    }

    // Post-publish success: show completion panel.
    if (_publishedSuccessfully) {
      return _buildCompletionScreen(context, l10n);
    }

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
              l10n.meshServicesCreateTitle,
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            Text(
              title,
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
                              children: _buildComposerSections(
                                context,
                                l10n,
                                title,
                                accent,
                              ),
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

  // ─────────────────── completion screen ───────────────────

  Widget _buildCompletionScreen(BuildContext context, dynamic l10n) {
    return GlassScaffold(
      leading: IconButton(
        icon: Icon(Icons.close, color: context.textPrimary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: CompletionStatePanel(
            icon: Icons.check_circle_outline,
            color: AppTheme.successGreen,
            headline: l10n.meshServicesCreatedHeadline as String,
            description: l10n.meshServicesCreatedDescription as String,
            meshHint: l10n.meshServicesCreatedMeshHint as String,
            primaryActionLabel: l10n.meshServicesCreatedViewServices as String,
            onPrimaryAction: () {
              Navigator.of(context).pop();
            },
            secondaryActionLabel:
                l10n.meshServicesCreatedCreateAnother as String,
            onSecondaryAction: () {
              setState(() {
                _publishedSuccessfully = false;
                _titleController.clear();
                _descriptionController.clear();
                for (final controller in _optionControllers) {
                  controller.clear();
                }
                for (final controller in _itemControllers) {
                  controller.clear();
                }
                _ttlMinutes = _resolved.defaultTtlMinutes;
              });
            },
          ),
        ),
      ],
    );
  }

  // ─────────────────── embedded form content ───────────────────

  Widget _buildFormContent(
    BuildContext context,
    dynamic l10n,
    String title,
    Color accent,
  ) {
    return GestureDetector(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildComposerSections(context, l10n, title, accent),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildComposerSections(
    BuildContext context,
    dynamic l10n,
    String title,
    Color accent,
  ) {
    return [
      _ServiceBadge(
        resolved: _resolved,
        title: title,
        visibilityLabel: l10n.meshServicesVisibilityOpen as String,
      ),
      const SizedBox(height: AppTheme.spacing16),
      Text(
        _presentation.composeLead(l10n),
        style: context.bodySecondaryStyle?.copyWith(
          color: context.textSecondary,
          height: 1.35,
        ),
      ),
      const SizedBox(height: AppTheme.spacing20),
      _buildTitleInput(l10n, accent),
      const SizedBox(height: AppTheme.spacing16),
      _buildDescriptionField(l10n),
      Builder(
        builder: (context) => _presentation.buildComposeFields(
          context,
          l10n,
          _buildComposeController(),
          accent,
        ),
      ),
      if (_isPoll || _hasList || _isSensor) ...[
        const SizedBox(height: AppTheme.spacing16),
      ],
      const SizedBox(height: AppTheme.spacing20),
      _buildPreviewCard(context, l10n, title),
      const SizedBox(height: AppTheme.spacing16),
      Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(color: context.border.withValues(alpha: 0.12)),
        ),
        child: ExpertDetailsExpander(
          label: l10n.meshServicesAdvancedDetails as String,
          icon: Icons.tune_outlined,
          expandedBuilder: (context) => Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              0,
              AppTheme.spacing16,
              AppTheme.spacing16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDurationSelector(l10n, accent),
                const SizedBox(height: AppTheme.spacing10),
                Text(
                  l10n.meshServicesAdvancedDurationHint as String,
                  style: context.bodySmallStyle?.copyWith(
                    color: context.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: AppTheme.spacing48),
    ];
  }

  Widget _buildPreviewCard(BuildContext context, dynamic l10n, String title) {
    final draft = _buildDraft();

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(
          color: _resolved.accentColor.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.meshServicesPreviewCardTitle as String,
            style: context.titleSmallStyle?.copyWith(
              color: context.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            l10n.meshServicesPreviewCardDescription as String,
            style: context.bodySmallStyle?.copyWith(
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _resolved.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: Icon(
                  _resolved.icon,
                  size: 22,
                  color: _resolved.accentColor,
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _previewTitle(context.l10n),
                      style: context.bodyStyle?.copyWith(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing4),
                    Text(
                      title,
                      style: context.bodySmallStyle?.copyWith(
                        color: _resolved.accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          Wrap(
            spacing: AppTheme.spacing8,
            runSpacing: AppTheme.spacing8,
            children: [
              _PreviewPill(
                label: l10n.meshServicesVisibilityOpen as String,
                color: SemanticColors.success,
              ),
              _PreviewPill(
                label: _formattedVisibleFor(l10n),
                color: _resolved.accentColor,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          _presentation.buildComposePreviewContent(context, l10n, draft),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            l10n.meshServicesPreviewSubtitle as String,
            style: context.bodySmallStyle?.copyWith(
              color: context.textTertiary,
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
      maxLength: _resolved.maxTitleLength,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      textCapitalization: TextCapitalization.sentences,
      inputFormatters: [
        LengthLimitingTextInputFormatter(_resolved.maxTitleLength),
      ],
      style: TextStyle(color: context.textPrimary),
      decoration: InputDecoration(
        labelText: _presentation.composeTitleLabel(l10n),
        labelStyle: TextStyle(color: context.textSecondary),
        hintText: _presentation.composeTitleLabel(l10n),
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
    final accent = _resolved.accentColor;

    return TextFormField(
      controller: _descriptionController,
      enabled: !_publishing,
      maxLines: 5,
      minLines: 3,
      maxLength: _resolved.maxDescriptionLength,
      textCapitalization: TextCapitalization.sentences,
      style: TextStyle(color: context.textPrimary),
      decoration: InputDecoration(
        labelText: _presentation.composeDescriptionLabel(l10n),
        labelStyle: TextStyle(color: context.textSecondary),
        hintText: _presentation.composeDescriptionHint(l10n),
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

  // ─────────────────── duration selector ───────────────────

  Widget _buildDurationSelector(dynamic l10n, Color accent) {
    final max = _resolved.maxTtlMinutes;

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
                          Icons.send_rounded,
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

    // Validate capability-specific fields.
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
    if (_isSensor && _sensorValueController.text.trim().isEmpty) {
      showErrorSnackBar(context, l10n.meshServicesMinSensorValue);
      return;
    }

    final engine = ref.read(meshServiceEngineProvider);
    final haptics = ref.read(hapticServiceProvider);
    if (engine == null) return;

    setState(() => _publishing = true);

    await haptics.trigger(HapticType.medium);

    final config = _buildConfig();
    final instance = await engine.createInstance(
      canonicalType: widget.canonicalType,
      presetId: _resolved.presetId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      ttlMinutes: _ttlMinutes,
      config: config,
    );

    if (!mounted) return;

    setState(() => _publishing = false);

    if (instance != null) {
      await ref.read(hapticServiceProvider).trigger(HapticType.success);
      if (!mounted) return;
      setState(() => _publishedSuccessfully = true);
    }
  }

  Map<String, dynamic> _buildConfig() {
    return switch (widget.canonicalType) {
      MeshServiceType.poll => {
        'options': _optionControllers
            .map((c) => c.text.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
      },
      MeshServiceType.list => {
        'items': _itemControllers
            .map((c) => c.text.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
      },
      MeshServiceType.signal => {'signalKind': _signalKind.name},
      MeshServiceType.sensor => {
        'sensorValue': _sensorValueController.text.trim(),
        'sensorUnit': _sensorUnitController.text.trim(),
        'sensorSource': _sensorSourceController.text.trim(),
        'sensorCapturedAtMs': DateTime.now().millisecondsSinceEpoch,
      },
      _ => const {},
    };
  }
}

// ═══════════════════════════════════════════════════════════════
// Private widgets
// ═══════════════════════════════════════════════════════════════

/// Service badge shown above the main input.
class _ServiceBadge extends StatelessWidget {
  const _ServiceBadge({
    required this.resolved,
    required this.title,
    required this.visibilityLabel,
  });

  final MeshServiceResolvedDefinition resolved;
  final String title;
  final String visibilityLabel;

  @override
  Widget build(BuildContext context) {
    final accent = resolved.accentColor;

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
          Icon(resolved.icon, size: 16, color: accent),
          const SizedBox(width: AppTheme.spacing8),
          Text(
            title,
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (resolved.isPublic) ...[
            const SizedBox(width: AppTheme.spacing8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: SemanticColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radius6),
              ),
              child: Text(
                visibilityLabel,
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

class _PreviewPill extends StatelessWidget {
  final String label;
  final Color color;

  const _PreviewPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing10,
        vertical: AppTheme.spacing6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius10),
      ),
      child: Text(
        label,
        style: context.bodySmallStyle?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
