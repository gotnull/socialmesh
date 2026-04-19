// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/gradient_border_container.dart';
import '../../../services/haptic_service.dart';
import '../../../services/protocol/sip/spp_constants.dart';
import '../../../services/protocol/sip/spp_incident_codec.dart';
import '../../../services/protocol/sip/spp_types.dart';
import '../../../utils/snackbar.dart';
import '../models/incident.dart';
import '../models/mesh_incident_report.dart';
import '../providers/mesh_incident_providers.dart';

/// Composer screen for creating, updating, or correcting mesh incident reports.
class MeshIncidentComposerScreen extends ConsumerStatefulWidget {
  final int? existingCaseId;
  final IncidentUpdateType updateType;
  final int? refSeq;

  const MeshIncidentComposerScreen({
    super.key,
    this.existingCaseId,
    this.updateType = IncidentUpdateType.initial,
    this.refSeq,
  });

  @override
  ConsumerState<MeshIncidentComposerScreen> createState() =>
      _MeshIncidentComposerScreenState();
}

class _MeshIncidentComposerScreenState
    extends ConsumerState<MeshIncidentComposerScreen>
    with LifecycleSafeMixin {
  final _formKey = GlobalKey<FormState>();
  final _bodyController = TextEditingController();

  IncidentClassification _classification = IncidentClassification.operational;
  IncidentPriority _priority = IncidentPriority.routine;
  IncidentConfidence _confidence = IncidentConfidence.unconfirmed;
  IncidentReporterRole _role = IncidentReporterRole.observer;
  bool _includeLocation = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  String _screenTitle() {
    return switch (widget.updateType) {
      IncidentUpdateType.initial => context.l10n.meshIncidentComposerTitle,
      IncidentUpdateType.update => context.l10n.meshIncidentComposerUpdateTitle,
      IncidentUpdateType.correction =>
        context.l10n.meshIncidentComposerCorrectionTitle,
      IncidentUpdateType.closure => context.l10n.meshIncidentCloseCase,
    };
  }

  String _submitLabel() {
    return switch (widget.updateType) {
      IncidentUpdateType.initial => context.l10n.meshIncidentSendButton,
      IncidentUpdateType.update => context.l10n.meshIncidentSendUpdateButton,
      IncidentUpdateType.correction =>
        context.l10n.meshIncidentSendCorrectionButton,
      IncidentUpdateType.closure => context.l10n.meshIncidentCloseCase,
    };
  }

  int _estimatePayloadSize() {
    final report = MeshIncidentReport(
      caseId: widget.existingCaseId ?? 0,
      seqNum: 0,
      updateType: widget.updateType,
      confidence: _confidence,
      classification: _classification,
      priority: _priority,
      status: IncidentMeshStatus.reported,
      reporterRole: _role,
      timestamp: DateTime.now(),
      body: _bodyController.text,
      latitude: _includeLocation ? 0.0 : null,
      longitude: _includeLocation ? 0.0 : null,
    );
    return SppIncidentCodec.estimateSize(report);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    final nav = Navigator.of(context);
    final haptics = ref.haptics;

    setState(() => _isSubmitting = true);

    try {
      final actions = ref.read(meshIncidentActionsProvider.notifier);
      MeshIncidentReport? result;

      switch (widget.updateType) {
        case IncidentUpdateType.initial:
          result = await actions.createReport(
            classification: _classification,
            priority: _priority,
            confidence: _confidence,
            reporterRole: _role,
            body: _bodyController.text.trim(),
          );
        case IncidentUpdateType.update:
          result = await actions.sendUpdate(
            caseId: widget.existingCaseId!,
            classification: _classification,
            priority: _priority,
            confidence: _confidence,
            reporterRole: _role,
            body: _bodyController.text.trim(),
          );
        case IncidentUpdateType.correction:
          result = await actions.sendCorrection(
            caseId: widget.existingCaseId!,
            refSeq: widget.refSeq!,
            classification: _classification,
            priority: _priority,
            confidence: _confidence,
            reporterRole: _role,
            body: _bodyController.text.trim(),
          );
        case IncidentUpdateType.closure:
          result = await actions.closeCase(
            caseId: widget.existingCaseId!,
            reporterRole: _role,
            body: _bodyController.text.trim(),
          );
      }

      if (!mounted) return;

      if (result != null) {
        haptics.trigger(HapticType.success);
        safeShowSnackBar(
          context.l10n.meshIncidentSentSuccess,
          type: SnackBarType.success,
        );
        nav.pop();
      } else {
        haptics.trigger(HapticType.error);
        safeShowSnackBar(
          context.l10n.meshIncidentSendFailed,
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxBody = _includeLocation
        ? SppConstants.incidentMaxBodyWithLoc
        : SppConstants.incidentMaxBodyNoLoc;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: GlassScaffold(
        title: _screenTitle(),
        resizeToAvoidBottomInset: true,
        bottomNavigationBar: BottomActionBar(
          child: FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: AppTheme.spacing20,
                    height: AppTheme.spacing20,
                    child: CircularProgressIndicator(
                      strokeWidth: AppTheme.spacing2,
                    ),
                  )
                : Text(_submitLabel()),
          ),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Classification section
                    GradientBorderContainer(
                      accentColor: _classificationColor(_classification),
                      accentOpacity: 0.4,
                      borderRadius: AppTheme.radius12,
                      padding: const EdgeInsets.all(AppTheme.spacing12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(
                            icon: Icons.category,
                            label: context.l10n.meshIncidentClassificationLabel,
                            color: _classificationColor(_classification),
                          ),
                          const SizedBox(height: AppTheme.spacing8),
                          Wrap(
                            spacing: AppTheme.spacing8,
                            runSpacing: AppTheme.spacing8,
                            children: IncidentClassification.values.map((c) {
                              return _SelectableChip(
                                label: c.displayLabel(context.l10n),
                                isSelected: _classification == c,
                                color: _classificationColor(c),
                                onTap: () {
                                  ref.haptics.toggle();
                                  safeSetState(() => _classification = c);
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacing12),

                    // Priority section
                    GradientBorderContainer(
                      accentColor: _priorityColor(_priority),
                      accentOpacity: 0.4,
                      borderRadius: AppTheme.radius12,
                      padding: const EdgeInsets.all(AppTheme.spacing12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(
                            icon: Icons.flag,
                            label: context.l10n.meshIncidentPriorityLabel,
                            color: _priorityColor(_priority),
                          ),
                          const SizedBox(height: AppTheme.spacing8),
                          Wrap(
                            spacing: AppTheme.spacing8,
                            runSpacing: AppTheme.spacing8,
                            children: IncidentPriority.values.map((p) {
                              return _SelectableChip(
                                label: p.displayLabel(context.l10n),
                                isSelected: _priority == p,
                                color: _priorityColor(p),
                                onTap: () {
                                  ref.haptics.toggle();
                                  safeSetState(() => _priority = p);
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacing12),

                    // Confidence & Role row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Confidence
                        Expanded(
                          child: GradientBorderContainer(
                            accentColor: _confidenceColor(_confidence),
                            accentOpacity: 0.3,
                            borderRadius: AppTheme.radius12,
                            padding: const EdgeInsets.all(AppTheme.spacing12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionHeader(
                                  icon: Icons.verified,
                                  label:
                                      context.l10n.meshIncidentConfidenceLabel,
                                  color: _confidenceColor(_confidence),
                                ),
                                const SizedBox(height: AppTheme.spacing8),
                                ...IncidentConfidence.values.map((c) {
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppTheme.spacing4,
                                    ),
                                    child: _SelectableChip(
                                      label: _confidenceLabel(c),
                                      isSelected: _confidence == c,
                                      color: _confidenceColor(c),
                                      onTap: () {
                                        ref.haptics.toggle();
                                        safeSetState(() => _confidence = c);
                                      },
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing12),
                        // Role
                        Expanded(
                          child: GradientBorderContainer(
                            accentColor: AccentColors.blue,
                            accentOpacity: 0.3,
                            borderRadius: AppTheme.radius12,
                            padding: const EdgeInsets.all(AppTheme.spacing12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionHeader(
                                  icon: Icons.person,
                                  label: context.l10n.meshIncidentRoleLabel,
                                  color: AccentColors.blue,
                                ),
                                const SizedBox(height: AppTheme.spacing8),
                                ...IncidentReporterRole.values.map((r) {
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppTheme.spacing4,
                                    ),
                                    child: _SelectableChip(
                                      label: _roleLabel(r),
                                      isSelected: _role == r,
                                      color: AccentColors.blue,
                                      onTap: () {
                                        ref.haptics.toggle();
                                        safeSetState(() => _role = r);
                                      },
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppTheme.spacing12),

                    // Location toggle
                    GradientBorderContainer(
                      accentColor: _includeLocation
                          ? AccentColors.emerald
                          : SemanticColors.muted,
                      accentOpacity: _includeLocation ? 0.4 : 0.15,
                      borderRadius: AppTheme.radius12,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing12,
                        vertical: AppTheme.spacing4,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _includeLocation
                                ? Icons.location_on
                                : Icons.location_off,
                            size: AppTheme.spacing16,
                            color: _includeLocation
                                ? AccentColors.emerald
                                : context.textTertiary,
                          ),
                          const SizedBox(width: AppTheme.spacing8),
                          Expanded(
                            child: Text(
                              context.l10n.meshIncidentLocationLabel,
                              style: context.bodyStyle,
                            ),
                          ),
                          ThemedSwitch(
                            value: _includeLocation,
                            onChanged: (v) {
                              ref.haptics.toggle();
                              safeSetState(() => _includeLocation = v);
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacing12),

                    // Body text
                    GradientBorderContainer(
                      accentColor: AccentColors.orange,
                      accentOpacity: 0.2,
                      borderRadius: AppTheme.radius12,
                      padding: const EdgeInsets.all(AppTheme.spacing12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(
                            icon: Icons.edit_note,
                            label: context.l10n.meshIncidentBodyLabel,
                            color: AccentColors.orange,
                          ),
                          const SizedBox(height: AppTheme.spacing8),
                          TextFormField(
                            controller: _bodyController,
                            maxLength: maxBody,
                            maxLines: 5,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: _inputDecoration(
                              context,
                              hintText: context.l10n.meshIncidentBodyHint,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return context.l10n.meshIncidentBodyRequired;
                              }
                              return null;
                            },
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: AppTheme.spacing4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spacing8,
                                vertical: AppTheme.spacing2,
                              ),
                              decoration: BoxDecoration(
                                color: AccentColors.orange.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius10,
                                ),
                                border: Border.all(
                                  color: AccentColors.orange.withValues(
                                    alpha: 0.25,
                                  ),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                context.l10n.meshIncidentPayloadSize(
                                  _estimatePayloadSize(),
                                ),
                                style: context.captionMutedStyle?.copyWith(
                                  color: AccentColors.orange,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bottom padding for keyboard
                    const SizedBox(height: AppTheme.spacing80),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _priorityColor(IncidentPriority p) => switch (p) {
    IncidentPriority.routine => AccentColors.teal,
    IncidentPriority.priority => SemanticColors.warning,
    IncidentPriority.immediate => AccentColors.orange,
    IncidentPriority.flash => SemanticColors.error,
  };

  Color _classificationColor(IncidentClassification c) => switch (c) {
    IncidentClassification.safety => AccentColors.red,
    IncidentClassification.security => AccentColors.orange,
    IncidentClassification.environmental => AccentColors.emerald,
    IncidentClassification.operational => AccentColors.blue,
    IncidentClassification.logistics => AccentColors.purple,
    IncidentClassification.medical => AccentColors.pink,
    IncidentClassification.comms => AccentColors.cyan,
  };

  Color _confidenceColor(IncidentConfidence c) => switch (c) {
    IncidentConfidence.unconfirmed => SemanticColors.warning,
    IncidentConfidence.probable => SemanticColors.info,
    IncidentConfidence.confirmed => SemanticColors.success,
  };

  String _confidenceLabel(IncidentConfidence c) => switch (c) {
    IncidentConfidence.unconfirmed =>
      context.l10n.meshIncidentConfidenceUnconfirmed,
    IncidentConfidence.probable => context.l10n.meshIncidentConfidenceProbable,
    IncidentConfidence.confirmed =>
      context.l10n.meshIncidentConfidenceConfirmed,
  };

  String _roleLabel(IncidentReporterRole r) => switch (r) {
    IncidentReporterRole.observer => context.l10n.meshIncidentRoleObserver,
    IncidentReporterRole.operator => context.l10n.meshIncidentRoleOperator,
    IncidentReporterRole.supervisor => context.l10n.meshIncidentRoleSupervisor,
    IncidentReporterRole.admin => context.l10n.meshIncidentRoleAdmin,
  };

  InputDecoration _inputDecoration(BuildContext context, {String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: context.surface.withValues(alpha: 0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        borderSide: BorderSide(color: context.border.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        borderSide: const BorderSide(color: AccentColors.orange),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        borderSide: const BorderSide(color: AppTheme.errorRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        borderSide: const BorderSide(color: AppTheme.errorRed),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing12,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: AppTheme.spacing14, color: color),
        const SizedBox(width: AppTheme.spacing6),
        Text(
          label,
          style: context.labelStyle?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SelectableChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _SelectableChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing12,
          vertical: AppTheme.spacing6,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radius10),
          border: Border.all(
            color: isSelected ? color.withValues(alpha: 0.5) : context.border,
            width: isSelected ? 1.0 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? color : context.textSecondary,
          ),
        ),
      ),
    );
  }
}
