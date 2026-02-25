// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/permission.dart';
import '../../../core/auth/permission_service.dart';
import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
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
        title: 'Create Incident',
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
                    _buildSectionTitle(context, 'Title'),
                    const SizedBox(height: AppTheme.spacing8),
                    TextFormField(
                      controller: _titleController,
                      maxLength: 200,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDecoration(
                        context,
                        hintText: 'Brief incident title',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Title is required';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: AppTheme.spacing16),

                    // -- Description --
                    _buildSectionTitle(context, 'Description (optional)'),
                    const SizedBox(height: AppTheme.spacing8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLength: 2000,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDecoration(
                        context,
                        hintText: 'Detailed description of the incident',
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacing16),

                    // -- Priority --
                    _buildSectionTitle(context, 'Priority'),
                    const SizedBox(height: AppTheme.spacing8),
                    _buildPrioritySelector(context),

                    const SizedBox(height: AppTheme.spacing16),

                    // -- Classification --
                    _buildSectionTitle(context, 'Classification'),
                    const SizedBox(height: AppTheme.spacing8),
                    _buildClassificationSelector(context),

                    const SizedBox(height: AppTheme.spacing16),

                    // -- Location --
                    _buildSectionTitle(context, 'Location (optional)'),
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
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      counterText: '',
    );
  }

  Widget _buildPrioritySelector(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: IncidentPriority.values.map((p) {
        final isSelected = _priority == p;
        final color = _priorityColor(p);
        return ChoiceChip(
          label: Text(_priorityLabel(p)),
          selected: isSelected,
          onSelected: (_) {
            ref.haptics.toggle();
            safeSetState(() => _priority = p);
          },
          labelStyle: TextStyle(
            fontSize: 13,
            color: isSelected ? Colors.white : context.textSecondary,
          ),
          selectedColor: color,
          backgroundColor: context.card,
          side: BorderSide(color: context.border),
          showCheckmark: false,
        );
      }).toList(),
    );
  }

  Widget _buildClassificationSelector(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: IncidentClassification.values.map((c) {
        final isSelected = _classification == c;
        return ChoiceChip(
          label: Text(_classificationLabel(c)),
          selected: isSelected,
          onSelected: (_) {
            ref.haptics.toggle();
            safeSetState(() => _classification = c);
          },
          labelStyle: TextStyle(
            fontSize: 13,
            color: isSelected ? Colors.white : context.textSecondary,
          ),
          selectedColor: Theme.of(context).colorScheme.primary,
          backgroundColor: context.card,
          side: BorderSide(color: context.border),
          showCheckmark: false,
        );
      }).toList(),
    );
  }

  Widget _buildLocationCapture(BuildContext context) {
    if (_locationLat != null && _locationLon != null) {
      return Row(
        children: [
          Icon(Icons.location_on, size: 16, color: Colors.green),
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
            child: const Text('Remove'),
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
        _isCapturingLocation ? 'Getting location...' : 'Capture Location',
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
          showErrorSnackBar(context, 'Could not get location');
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Location error: $e');
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
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
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: AppTheme.spacing10),
                        Text(
                          'Creating...',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Create Incident',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
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
        showSuccessSnackBar(context, 'Incident created');
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
            : 'Failed to create';
        if (error.error is InvalidTransitionException ||
            error.error is InsufficientPermissionException) {
          showErrorSnackBar(context, message);
        } else {
          showErrorSnackBar(context, message);
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Error: $e');
      }
    } finally {
      safeSetState(() => _isSubmitting = false);
    }
  }

  static String _priorityLabel(IncidentPriority priority) {
    return switch (priority) {
      IncidentPriority.routine => 'Routine',
      IncidentPriority.priority => 'Priority',
      IncidentPriority.immediate => 'Immediate',
      IncidentPriority.flash => 'Flash',
    };
  }

  static Color _priorityColor(IncidentPriority priority) {
    return switch (priority) {
      IncidentPriority.routine => Colors.teal,
      IncidentPriority.priority => Colors.amber.shade700,
      IncidentPriority.immediate => Colors.deepOrange,
      IncidentPriority.flash => Colors.red.shade800,
    };
  }

  static String _classificationLabel(IncidentClassification c) {
    return switch (c) {
      IncidentClassification.safety => 'Safety',
      IncidentClassification.security => 'Security',
      IncidentClassification.environmental => 'Environmental',
      IncidentClassification.operational => 'Operational',
      IncidentClassification.logistics => 'Logistics',
      IncidentClassification.medical => 'Medical',
      IncidentClassification.comms => 'Comms',
    };
  }
}
