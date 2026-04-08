// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/guided_flow_scaffold.dart';
import '../../../core/widgets/step_choice_card.dart';
import '../../../core/widgets/summary_card.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/haptic_service.dart';
import '../models/mesh_service_template.dart';
import 'mesh_service_creation_screen.dart';

/// Audience scope for a new service.
enum _AudienceScope { anyone, contactsOnly }

/// Guided wizard for creating a new mesh service.
///
/// Steps: What → Who → Review.
/// On confirmation, navigates to the full [MeshServiceCreationScreen]
/// with the selected template, keeping the existing form + publish flow.
class ServiceCreationWizard extends ConsumerStatefulWidget {
  const ServiceCreationWizard({super.key});

  @override
  ConsumerState<ServiceCreationWizard> createState() =>
      _ServiceCreationWizardState();
}

class _ServiceCreationWizardState extends ConsumerState<ServiceCreationWizard>
    with LifecycleSafeMixin {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  MeshServiceTemplateId? _selectedTemplate;
  _AudienceScope _audience = _AudienceScope.anyone;

  static const int _totalSteps = 3;

  List<GuidedFlowStep> _buildSteps(AppLocalizations l10n) => [
    GuidedFlowStep(
      title: l10n.serviceWizardStepWhat,
      icon: Icons.category_outlined,
      color: AccentColors.cyan,
    ),
    GuidedFlowStep(
      title: l10n.serviceWizardStepWho,
      icon: Icons.people_outline,
      color: AccentColors.purple,
    ),
    GuidedFlowStep(
      title: l10n.serviceWizardStepReview,
      icon: Icons.check_circle_outline,
      color: AppTheme.successGreen,
    ),
  ];

  void _nextStep() {
    ref.haptics.trigger(HapticType.light);
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    ref.haptics.trigger(HapticType.light);
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool get _canAdvance {
    switch (_currentStep) {
      case 0:
        return _selectedTemplate != null;
      case 1:
        return true;
      case 2:
        return _selectedTemplate != null;
      default:
        return false;
    }
  }

  void _onConfirm() {
    final template = MeshServiceTemplateCatalog.byId(_selectedTemplate!);
    if (template == null) return;

    ref.haptics.trigger(HapticType.medium);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MeshServiceCreationScreen(template: template),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return GuidedFlowScaffold(
      title: l10n.serviceWizardTitle,
      steps: _buildSteps(l10n),
      currentStep: _currentStep,
      pageController: _pageController,
      pageBuilder: (context, index) {
        switch (index) {
          case 0:
            return _buildWhatStep(context, l10n);
          case 1:
            return _buildWhoStep(context, l10n);
          case 2:
            return _buildReviewStep(context, l10n);
          default:
            return const SizedBox.shrink();
        }
      },
      bottomBar: BottomActionBar(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousStep,
                  child: Text(l10n.guidedFlowBack),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: AppTheme.spacing16),
            Expanded(
              child: FilledButton(
                onPressed: _canAdvance
                    ? (_currentStep == _totalSteps - 1 ? _onConfirm : _nextStep)
                    : null,
                child: Text(
                  _currentStep == _totalSteps - 1
                      ? l10n.guidedFlowContinue
                      : l10n.guidedFlowNext,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Step 1: What ───

  Widget _buildWhatStep(BuildContext context, AppLocalizations l10n) {
    final templates = MeshServiceTemplateCatalog.all;
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      children: [
        Text(l10n.serviceWizardWhatTitle, style: context.headingStyle),
        const SizedBox(height: AppTheme.spacing4),
        Text(
          l10n.serviceWizardWhatSubtitle,
          style: context.bodySecondaryStyle?.copyWith(
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: AppTheme.spacing16),
        ...templates.map((t) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
            child: StepChoiceCard(
              icon: t.icon,
              title: _templateName(l10n, t.id),
              description: _templateDescription(l10n, t.id),
              accentColor: t.accentColor,
              isSelected: _selectedTemplate == t.id,
              onTap: () {
                ref.haptics.trigger(HapticType.light);
                setState(() => _selectedTemplate = t.id);
              },
            ),
          );
        }),
      ],
    );
  }

  // ─── Step 2: Who ───

  Widget _buildWhoStep(BuildContext context, AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      children: [
        Text(l10n.serviceWizardWhoTitle, style: context.headingStyle),
        const SizedBox(height: AppTheme.spacing4),
        Text(
          l10n.serviceWizardWhoSubtitle,
          style: context.bodySecondaryStyle?.copyWith(
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: AppTheme.spacing16),
        StepChoiceCard(
          icon: Icons.public,
          title: l10n.serviceWizardAudienceAnyone,
          description: l10n.serviceWizardAudienceAnyoneDesc,
          accentColor: AccentColors.emerald,
          isSelected: _audience == _AudienceScope.anyone,
          onTap: () {
            ref.haptics.trigger(HapticType.light);
            setState(() => _audience = _AudienceScope.anyone);
          },
        ),
        const SizedBox(height: AppTheme.spacing8),
        StepChoiceCard(
          icon: Icons.group,
          title: l10n.serviceWizardAudienceContacts,
          description: l10n.serviceWizardAudienceContactsDesc,
          accentColor: AccentColors.purple,
          isSelected: _audience == _AudienceScope.contactsOnly,
          onTap: () {
            ref.haptics.trigger(HapticType.light);
            setState(() => _audience = _AudienceScope.contactsOnly);
          },
        ),
      ],
    );
  }

  // ─── Step 3: Review ───

  Widget _buildReviewStep(BuildContext context, AppLocalizations l10n) {
    final template = _selectedTemplate != null
        ? MeshServiceTemplateCatalog.byId(_selectedTemplate!)
        : null;

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      children: [
        Text(l10n.serviceWizardReviewTitle, style: context.headingStyle),
        const SizedBox(height: AppTheme.spacing4),
        Text(
          l10n.serviceWizardReviewSubtitle,
          style: context.bodySecondaryStyle?.copyWith(
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: AppTheme.spacing16),
        SummaryCard(
          title: l10n.serviceWizardReviewTitle,
          titleIcon: Icons.checklist,
          accentColor: AppTheme.successGreen,
          rows: [
            SummaryRow(
              label: l10n.serviceWizardReviewType,
              value: template != null
                  ? _templateName(l10n, template.id)
                  : '—', // lint-allow: hardcoded-string
              icon: template?.icon,
              iconColor: template?.accentColor,
            ),
            SummaryRow(
              label: l10n.serviceWizardReviewAudience,
              value: _audience == _AudienceScope.anyone
                  ? l10n.serviceWizardAudienceAnyone
                  : l10n.serviceWizardAudienceContacts,
              icon: _audience == _AudienceScope.anyone
                  ? Icons.public
                  : Icons.group,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing16),
        Container(
          padding: const EdgeInsets.all(AppTheme.spacing12),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            border: Border.all(color: context.border.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.tips_and_updates_outlined,
                size: 18,
                color: AppTheme.warningYellow,
              ),
              const SizedBox(width: AppTheme.spacing10),
              Expanded(
                child: Text(
                  l10n.serviceWizardReviewMeshHint,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Template display name helpers ───

  String _templateName(AppLocalizations l10n, MeshServiceTemplateId id) {
    switch (id) {
      case MeshServiceTemplateId.board:
        return l10n.meshServicesTemplateBoard;
      case MeshServiceTemplateId.signal:
        return l10n.meshServicesTemplateSignal;
      case MeshServiceTemplateId.poll:
        return l10n.meshServicesTemplatePoll;
      case MeshServiceTemplateId.checklist:
        return l10n.meshServicesTemplateChecklist;
      case MeshServiceTemplateId.resourceList:
        return l10n.meshServicesTemplateResourceList;
      case MeshServiceTemplateId.weatherStation:
        return l10n.meshServicesTemplateWeatherStation;
      case MeshServiceTemplateId.sensorNode:
        return l10n.meshServicesTemplateSensorNode;
      case MeshServiceTemplateId.taskBoard:
        return l10n.meshServicesTemplateTaskBoard;
      case MeshServiceTemplateId.trailConditions:
        return l10n.meshServicesTemplateTrailConditions;
      case MeshServiceTemplateId.lostAndFound:
        return l10n.meshServicesTemplateLostAndFound;
    }
  }

  String _templateDescription(AppLocalizations l10n, MeshServiceTemplateId id) {
    switch (id) {
      case MeshServiceTemplateId.board:
        return l10n.meshServicesTemplateBoardDescription;
      case MeshServiceTemplateId.signal:
        return l10n.meshServicesTemplateSignalDescription;
      case MeshServiceTemplateId.poll:
        return l10n.meshServicesTemplatePollDescription;
      case MeshServiceTemplateId.checklist:
        return l10n.meshServicesTemplateChecklistDescription;
      case MeshServiceTemplateId.resourceList:
        return l10n.meshServicesTemplateResourceListDescription;
      case MeshServiceTemplateId.weatherStation:
        return l10n.meshServicesTemplateWeatherStationDescription;
      case MeshServiceTemplateId.sensorNode:
        return l10n.meshServicesTemplateSensorNodeDescription;
      case MeshServiceTemplateId.taskBoard:
        return l10n.meshServicesTemplateTaskBoardDescription;
      case MeshServiceTemplateId.trailConditions:
        return l10n.meshServicesTemplateTrailConditionsDescription;
      case MeshServiceTemplateId.lostAndFound:
        return l10n.meshServicesTemplateLostAndFoundDescription;
    }
  }
}
