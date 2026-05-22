// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/permission.dart';
import '../../../core/auth/permission_service.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/chip_selector.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../providers/app_providers.dart';
import '../../../services/haptic_service.dart';
import '../../../utils/snackbar.dart';
import '../models/incident.dart';
import '../providers/incident_providers.dart';
import '../services/incident_state_machine.dart';
import 'incident_detail_screen.dart';

/// Create incident screen — form to create a new incident.
///
/// Fields: title (maxLength 200, required), description (maxLength 2000),
/// priority picker (default routine), classification picker (default
/// operational), optional location capture.
///
/// Submit button is RBAC-gated via [Permission.createIncident] and
/// rendered as a fixed bottom gradient button.
///
/// Spec: Sprint 008/W3.3.
class CreateIncidentScreen extends ConsumerStatefulWidget {
  const CreateIncidentScreen({super.key});

  @override
  ConsumerState<CreateIncidentScreen> createState() =>
      _CreateIncidentScreenState();
}

class _CreateIncidentScreenState extends ConsumerState<CreateIncidentScreen>
    with LifecycleSafeMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  IncidentPriority _priority = IncidentPriority.routine;
  IncidentClassification _classification = IncidentClassification.operational;

  double? _locationLat;
  double? _locationLon;
  bool _isCapturingLocation = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: GlassScaffold(
        title: context.l10n.incidentCreateScreenTitle,
        resizeToAvoidBottomInset: true,
        bottomNavigationBar: _buildSubmitButton(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // -- Title --
                    _buildSectionTitle(
                      context,
                      context.l10n.incidentCreateTitleSection,
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    TextFormField(
                      controller: _titleController,
                      maxLength: 200,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDecoration(
                        context,
                        hintText: context.l10n.incidentCreateTitleHint,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return context.l10n.incidentCreateTitleRequired;
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: AppTheme.spacing16),

                    // -- Description --
                    _buildSectionTitle(
                      context,
                      context.l10n.incidentCreateDescriptionSection,
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLength: 2000,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDecoration(
                        context,
                        hintText: context.l10n.incidentCreateDescriptionHint,
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacing16),

                    // -- Priority --
                    _buildSectionTitle(
                      context,
                      context.l10n.incidentCreatePrioritySection,
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    _buildPrioritySelector(context),

                    const SizedBox(height: AppTheme.spacing16),

                    // -- Classification --
                    _buildSectionTitle(
                      context,
                      context.l10n.incidentCreateClassificationSection,
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    _buildClassificationSelector(context),

                    const SizedBox(height: AppTheme.spacing16),

                    // -- Location --
                    _buildSectionTitle(
                      context,
                      context.l10n.incidentCreateLocationSection,
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    _buildLocationCapture(context),

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

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: context.labelStyle?.copyWith(
        color: context.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String hintText,
  }) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: context.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        borderSide: BorderSide(color: context.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        borderSide: const BorderSide(color: AppTheme.errorRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        borderSide: const BorderSide(color: AppTheme.errorRed),
      ),
      counterText: '',
    );
  }

  Widget _buildPrioritySelector(BuildContext context) {
    final l10n = context.l10n;
    return ChipSelector<IncidentPriority>(
      value: _priority,
      options: [
        for (final p in IncidentPriority.values)
          ChipOption<IncidentPriority>(
            value: p,
            label: p.displayLabel(l10n),
            color: _priorityColor(p),
          ),
      ],
      onChanged: (p) {
        ref.haptics.toggle();
        safeSetState(() => _priority = p);
      },
    );
  }

  Widget _buildClassificationSelector(BuildContext context) {
    final l10n = context.l10n;
    return ChipSelector<IncidentClassification>(
      value: _classification,
      options: [
        for (final c in IncidentClassification.values)
          ChipOption<IncidentClassification>(
            value: c,
            label: c.displayLabel(l10n),
            color: context.accentColor,
          ),
      ],
      onChanged: (c) {
        ref.haptics.toggle();
        safeSetState(() => _classification = c);
      },
    );
  }

  Widget _buildLocationCapture(BuildContext context) {
    if (_locationLat != null && _locationLon != null) {
      return Row(
        children: [
          Icon(Icons.location_on, size: 16, color: AppTheme.successGreen),
          const SizedBox(width: AppTheme.spacing6),
          Text(
            '${_locationLat!.toStringAsFixed(5)}, '
            '${_locationLon!.toStringAsFixed(5)}',
            style: context.bodySmallStyle?.copyWith(
              color: context.textSecondary,
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          TextButton(
            onPressed: () {
              ref.haptics.toggle();
              safeSetState(() {
                _locationLat = null;
                _locationLon = null;
              });
            },
            child: Text(context.l10n.incidentCreateRemoveLocation),
          ),
        ],
      );
    }

    return OutlinedButton.icon(
      icon: _isCapturingLocation
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.my_location, size: 16),
      label: Text(
        _isCapturingLocation
            ? context.l10n.incidentCreateGettingLocation
            : context.l10n.incidentCreateCaptureLocation,
      ),
      onPressed: _isCapturingLocation ? null : _captureLocation,
    );
  }

  Future<void> _captureLocation() async {
    ref.haptics.buttonTap();
    safeSetState(() => _isCapturingLocation = true);

    try {
      final locationService = ref.read(locationServiceProvider);
      final position = await locationService.getCurrentPosition();
      if (position != null) {
        safeSetState(() {
          _locationLat = position.latitude;
          _locationLon = position.longitude;
        });
      } else {
        if (mounted) {
          showErrorSnackBar(context, context.l10n.incidentCreateLocationError);
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          context.l10n.incidentCreateLocationException('$e'),
        );
      }
    } finally {
      safeSetState(() => _isCapturingLocation = false);
    }
  }

  Widget _buildSubmitButton() {
    final theme = Theme.of(context);
    final gradientColors = _isSubmitting
        ? [
            theme.colorScheme.primary.withValues(alpha: 0.5),
            theme.colorScheme.primary.withValues(alpha: 0.4),
          ]
        : [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.8),
          ];

    return BottomActionBar(
      horizontalPadding: AppTheme.spacing16,
      child: PermissionGate(
        permission: Permission.createIncident,
        child: BouncyTap(
          onTap: _isSubmitting ? null : _submit,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradientColors),
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            child: _isSubmitting
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacing10),
                      Text(
                        context.l10n.incidentCreateSubmitting,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  )
                : Text(
                    context.l10n.incidentCreateSubmitButton,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    ref.haptics.buttonTap();
    safeSetState(() => _isSubmitting = true);

    final title = _titleController.text.trim();
    final l10n = context.l10n;

    AppLogging.incidentUI(
      'create incident submitted '
      '(title=$title, priority=${_priority.name})',
    );

    try {
      final incident = await ref
          .read(incidentActionsProvider.notifier)
          .createIncident(
            title: title,
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            priority: _priority,
            classification: _classification,
            locationLat: _locationLat,
            locationLon: _locationLon,
          );

      if (incident != null && mounted) {
        ref.haptics.success();
        showSuccessSnackBar(context, l10n.incidentCreatedSuccess);
        // Replace this screen with detail to avoid double-back to list.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => IncidentDetailScreen(incidentId: incident.id),
          ),
        );
      } else if (mounted) {
        final error = ref.read(incidentActionsProvider);
        final message = error is AsyncError
            ? '${error.error}'
            : l10n.incidentCreateFailed;
        if (error.error is InvalidTransitionException ||
            error.error is InsufficientPermissionException) {
          showErrorSnackBar(context, message);
        } else {
          showErrorSnackBar(context, message);
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, l10n.incidentCreateError('$e'));
      }
    } finally {
      safeSetState(() => _isSubmitting = false);
    }
  }

  static Color _priorityColor(IncidentPriority priority) {
    return switch (priority) {
      IncidentPriority.routine => AccentColors.teal,
      IncidentPriority.priority => AppTheme.warningYellow,
      IncidentPriority.immediate => AccentColors.coral,
      IncidentPriority.flash => AppTheme.errorRed,
    };
  }
}
