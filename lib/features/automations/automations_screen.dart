// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging.dart';
import '../../core/legal/legal_constants.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../core/widgets/legal_document_sheet.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/premium_gating.dart';
import '../../models/subscription_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/help_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../providers/subscription_providers.dart';
import '../../services/haptic_service.dart';
import '../../utils/snackbar.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/edge_fade.dart';
import 'automation_providers.dart';
import 'automation_repository.dart';
import 'automation_share_utils.dart';
import 'models/automation.dart';
import 'widgets/automation_card.dart';
import 'widgets/automation_history_sheet.dart';
import 'automation_editor_screen.dart';

/// Screen showing all configured automations
class AutomationsScreen extends ConsumerWidget {
  const AutomationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final automationsAsync = ref.watch(automationsProvider);
    final stats = ref.watch(automationStatsProvider);

    return HelpTourController(
      topicId: 'automations_overview',
      stepKeys: const {},
      child: GlassScaffold(
        title: context.l10n.automationScreenTitle,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: context.l10n.automationScreenNewTooltip,
            onPressed: () => _showAddAutomation(context, ref),
          ),
          AppBarOverflowMenu<String>(
            onSelected: (value) {
              switch (value) {
                case 'history':
                  _showExecutionLog(context, ref);
                case 'scan':
                  Navigator.pushNamed(context, '/qr-scanner');
                case 'help':
                  ref
                      .read(helpProvider.notifier)
                      .startTour('automations_overview');
                case 'acceptable_use':
                  LegalDocumentSheet.showTermsSection(
                    context,
                    LegalConstants.anchorAcceptableUse,
                  );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'history',
                child: ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(context.l10n.automationScreenExecutionLog),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'scan',
                child: ListTile(
                  leading: const Icon(Icons.qr_code_scanner),
                  title: Text(context.l10n.automationScreenScanQrCode),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'acceptable_use',
                child: ListTile(
                  leading: const Icon(Icons.gavel_rounded),
                  title: Text(context.l10n.automationScreenAcceptableUse),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'help',
                child: ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: Text(context.l10n.automationScreenHelp),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
        slivers: automationsAsync.when(
          data: (allAutomations) {
            // Hide automations whose `trigger.protocolFilter` is pinned
            // to the OTHER protocol from the active shell. They still
            // exist in storage and re-appear when the shell switches
            // back; the editor will not silently delete them. This is
            // a view filter only.
            final activeFilter = _activeProtocolFilter(ref);
            final automations = allAutomations.where((a) {
              final pinned = a.trigger.protocolFilter;
              if (pinned == TriggerProtocolFilter.any) return true;
              if (activeFilter == TriggerProtocolFilter.any) return true;
              return pinned == activeFilter;
            }).toList();
            if (automations.isEmpty) {
              AppLogging.automations('screen RENDER -> EMPTY (Quick Start)');
              return _buildEmptyStateSlivers(context, ref);
            }
            AppLogging.automations(
              'screen RENDER -> LIST '
              '(count=${automations.length} '
              'hidden=${allAutomations.length - automations.length})',
            );
            return _buildAutomationsListSlivers(
              context,
              ref,
              automations,
              stats,
            );
          },
          loading: () {
            AppLogging.automations('screen RENDER -> LOADING');
            return [
              const SliverFillRemaining(
                hasScrollBody: false,
                child: ScreenLoadingIndicator(),
              ),
            ];
          },
          error: (error, _) => [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: AppTheme.errorRed,
                    ),
                    const SizedBox(height: AppTheme.spacing16),
                    Text(
                      context.l10n.automationScreenLoadError,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    TextButton(
                      onPressed: () =>
                          ref.read(automationsProvider.notifier).refresh(),
                      child: Text(context.l10n.automationScreenRetry),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the first-visit/empty state as a guided automation builder - returns slivers
  /// This transforms "empty list" into "invitation to create"
  List<Widget> _buildEmptyStateSlivers(BuildContext context, WidgetRef ref) {
    final hasAutomationsPack = ref.watch(
      hasFeatureProvider(PremiumFeature.automations),
    );

    return [
      SliverPadding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            // Hero section - What this is
            _buildHeroSection(context, hasAutomationsPack),

            const SizedBox(height: AppTheme.spacing24),

            // Create from scratch CTA - Primary action
            _buildCreateFromScratchCard(context, ref, hasAutomationsPack),

            const SizedBox(height: AppTheme.spacing24),

            // Quick Start Templates - Secondary inspiration
            _buildTemplatesSection(context, ref, hasAutomationsPack),

            const SizedBox(height: AppTheme.spacing24),

            // Start with a Trigger - Exploration path
            _buildTriggerCategoriesSection(context, ref, hasAutomationsPack),

            // Bottom padding
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ]),
        ),
      ),
    ];
  }

  /// Hero section explaining what automations are
  Widget _buildHeroSection(BuildContext context, bool hasAutomationsPack) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.1),
            accentColor.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius20),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentColor, accentColor.withValues(alpha: 0.7)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.25),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.bolt, size: 44, color: Colors.white),
          ),
          const SizedBox(height: AppTheme.spacing16),
          Text(
            context.l10n.automationScreenEmptyTitle,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            context.l10n.automationScreenEmptyDescription,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.textSecondary),
          ),
        ],
      ),
    );
  }

  /// Primary CTA to create from scratch
  Widget _buildCreateFromScratchCard(
    BuildContext context,
    WidgetRef ref,
    bool hasAutomationsPack,
  ) {
    return BouncyTap(
      onTap: () => _createNewAutomation(context, ref),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radius16),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppTheme.radius14),
              ),
              child: Icon(
                Icons.add,
                size: 28,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppTheme.spacing16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.automationScreenCreateFromScratch,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing4),
                  Text(
                    context.l10n.automationScreenCreateFromScratchSubtitle,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.textTertiary),
          ],
        ),
      ),
    );
  }

  /// Quick Start Templates section
  Widget _buildTemplatesSection(
    BuildContext context,
    WidgetRef ref,
    bool hasAutomationsPack,
  ) {
    final activeFilter = _activeProtocolFilter(ref);
    // When pinned to MeshCore, drop templates whose underlying trigger
    // cannot fire on MeshCore (e.g. `low_battery_alert` uses
    // `TriggerType.batteryLow`, unsupported on MeshCore per the
    // compatibility matrix). Templates without a known trigger mapping
    // are kept (caller-side override).
    final templates = AutomationRepository.templates.where((template) {
      if (activeFilter != TriggerProtocolFilter.meshcore) return true;
      final triggerType = AutomationRepository.templateTriggerType(template.id);
      if (triggerType == null) return true;
      return triggerType.supportOn(TriggerProtocol.meshcore) !=
          ProtocolSupport.unsupported;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              Icon(Icons.flash_on, size: 18, color: AppTheme.warningYellow),
              const SizedBox(width: AppTheme.spacing6),
              Text(
                context.l10n.automationScreenQuickStartTemplates,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacing4),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            context.l10n.automationScreenQuickStartSubtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.textTertiary),
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),
        SizedBox(
          height: 130,
          child: EdgeFade.end(
            fadeSize: 24,
            fadeColor: context.background,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: templates.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: AppTheme.spacing12),
              itemBuilder: (context, index) {
                final template = templates[index];
                return BouncyTap(
                  onTap: () => _addFromTemplate(context, ref, template.id),
                  child: Container(
                    width: 160,
                    padding: const EdgeInsets.all(AppTheme.spacing12),
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                      border: Border.all(color: context.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _getTemplateColor(
                              template.id,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius10,
                            ),
                          ),
                          child: Icon(
                            template.icon,
                            size: 20,
                            color: _getTemplateColor(template.id),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          AutomationRepository.localizedTemplateTitle(
                            template.id,
                            context.l10n,
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Get color for template based on its type
  Color _getTemplateColor(String templateId) {
    switch (templateId) {
      case 'low_battery_alert':
        return AppTheme.warningYellow;
      case 'node_offline_alert':
        return AppTheme.errorRed;
      case 'geofence_exit':
        return AccentColors.purple;
      case 'sos_response':
        return AppTheme.errorRed;
      case 'dead_mans_switch':
        return AccentColors.orange;
      default:
        return AccentColors.blue;
    }
  }

  /// Trigger categories section for exploration
  Widget _buildTriggerCategoriesSection(
    BuildContext context,
    WidgetRef ref,
    bool hasAutomationsPack,
  ) {
    final activeFilter = _activeProtocolFilter(ref);
    final triggersByCategory = _getTriggersByCategory(
      activeFilter: activeFilter,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              Icon(Icons.explore, size: 18, color: context.accentColor),
              const SizedBox(width: AppTheme.spacing6),
              Text(
                context.l10n.automationScreenStartWithTrigger,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacing4),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            context.l10n.automationScreenStartWithTriggerSubtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.textTertiary),
          ),
        ),
        const SizedBox(height: AppTheme.spacing16),

        // Build categories
        ..._categoryOrder.map((category) {
          final triggers = triggersByCategory[category];
          if (triggers == null || triggers.isEmpty) {
            return const SizedBox.shrink();
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category header
                Row(
                  children: [
                    Icon(
                      _categoryIcon(category),
                      size: 14,
                      color: _categoryColor(context, category),
                    ),
                    const SizedBox(width: AppTheme.spacing6),
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _categoryColor(context, category),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing8),
                // Trigger chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: triggers.map((type) {
                    return BouncyTap(
                      onTap: () => _createWithTrigger(context, ref, type),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius20,
                          ),
                          border: Border.all(color: context.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(type.icon, size: 16),
                            const SizedBox(width: AppTheme.spacing6),
                            Text(
                              type.localizedName(context.l10n),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // Active-protocol-aware grouping. When the user is in the MeshCore
  // shell (`activeProtocolProvider == meshcore`), trigger types that
  // are `unsupported` on MeshCore (battery telemetry, sensor) drop out
  // of the grouped list entirely. `partial` triggers still surface so
  // the user can pick them, with a "Limited on MeshCore" warning chip
  // applied at render time.
  Map<String, List<TriggerType>> _getTriggersByCategory({
    TriggerProtocolFilter activeFilter = TriggerProtocolFilter.any,
  }) {
    final grouped = <String, List<TriggerType>>{};
    for (final type in TriggerType.values) {
      if (activeFilter == TriggerProtocolFilter.meshcore &&
          type.supportOn(TriggerProtocol.meshcore) ==
              ProtocolSupport.unsupported) {
        continue;
      }
      final category = type.category;
      grouped.putIfAbsent(category, () => []).add(type);
    }
    return grouped;
  }

  // Resolve the picker's active filter from the connected protocol.
  // `none` (no device) falls back to `any` so the screen still shows
  // every trigger for a freshly-installed user with no radio paired.
  TriggerProtocolFilter _activeProtocolFilter(WidgetRef ref) {
    final active = ref.watch(activeProtocolProvider);
    switch (active) {
      case ActiveProtocol.meshcore:
        return TriggerProtocolFilter.meshcore;
      case ActiveProtocol.meshtastic:
        return TriggerProtocolFilter.meshtastic;
      case ActiveProtocol.none:
        return TriggerProtocolFilter.any;
    }
  }

  static const _categoryOrder = [
    'Node Status', // lint-allow: hardcoded-string
    'Battery',
    'Messages',
    'Location',
    'Time',
    'Signal',
    'Sensors',
    'Manual',
  ];

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Node Status':
        return Icons.router;
      case 'Battery':
        return Icons.battery_std;
      case 'Messages':
        return Icons.chat;
      case 'Location':
        return Icons.location_on;
      case 'Time':
        return Icons.schedule;
      case 'Signal':
        return Icons.signal_cellular_alt;
      case 'Sensors':
        return Icons.sensors;
      case 'Manual':
        return Icons.touch_app;
      default:
        return Icons.bolt;
    }
  }

  Color _categoryColor(BuildContext context, String category) {
    switch (category) {
      case 'Node Status':
        return AccentColors.blue;
      case 'Battery':
        return AppTheme.warningYellow;
      case 'Messages':
        return AppTheme.successGreen;
      case 'Location':
        return AccentColors.purple;
      case 'Time':
        return AccentColors.cyan;
      case 'Signal':
        return AccentColors.orange;
      case 'Sensors':
        return AppTheme.errorRed;
      case 'Manual':
        return Theme.of(context).colorScheme.primary;
      default:
        return SemanticColors.disabled;
    }
  }

  List<Widget> _buildAutomationsListSlivers(
    BuildContext context,
    WidgetRef ref,
    List<Automation> automations,
    AutomationStats stats,
  ) {
    return [
      // Stats header
      SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.all(AppTheme.spacing16),
          padding: const EdgeInsets.all(AppTheme.spacing16),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius16),
            border: Border.all(color: context.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                context,
                label: context.l10n.automationScreenStatTotal,
                value: stats.total.toString(),
                icon: Icons.bolt,
              ),
              Container(width: 1, height: 40, color: context.border),
              _buildStatItem(
                context,
                label: context.l10n.automationScreenStatActive,
                value: stats.enabled.toString(),
                icon: Icons.play_circle,
                color: AppTheme.successGreen,
              ),
              Container(width: 1, height: 40, color: context.border),
              _buildStatItem(
                context,
                label: context.l10n.automationScreenStatExecutions,
                value: stats.totalTriggers.toString(),
                icon: Icons.trending_up,
                onTap: () {
                  ref.haptics.trigger(HapticType.light);
                  _showExecutionLog(context, ref);
                },
              ),
            ],
          ),
        ),
      ),

      // Automations list
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final automation = automations[index];
            final animationsEnabled = ref.watch(animationsEnabledProvider);
            final history = ref.watch(
              automationHistoryByIdProvider(automation.id),
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Perspective3DSlide(
                index: index,
                direction: SlideDirection.left,
                enabled: animationsEnabled,
                child: AutomationCard(
                  automation: automation,
                  lastRun: history.isNotEmpty ? history.first : null,
                  onToggle: (enabled) {
                    ref
                        .read(automationsProvider.notifier)
                        .toggleAutomation(automation.id, enabled);
                  },
                  onTap: () => _editAutomation(context, ref, automation),
                  onDelete: () => _confirmDelete(context, ref, automation),
                  onShare: () => _shareAutomation(context, ref, automation),
                  onRun: automation.enabled
                      ? () => _runAutomation(context, ref, automation)
                      : null,
                ),
              ),
            );
          }, childCount: automations.length),
        ),
      ),

      // Bottom padding for FAB
      const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacing100)),
    ];
  }

  Widget _buildStatItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    Color? color,
    VoidCallback? onTap,
  }) {
    final content = Column(
      children: [
        Icon(icon, size: 24, color: color ?? SemanticColors.disabled),
        const SizedBox(height: AppTheme.spacing4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: SemanticColors.disabled),
        ),
      ],
    );
    if (onTap == null) return content;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }

  void _showAddAutomation(BuildContext context, WidgetRef ref) {
    // Check premium before allowing automation creation
    final hasPremium = ref.read(hasFeatureProvider(PremiumFeature.automations));
    if (!hasPremium) {
      showPremiumInfoSheet(
        context: context,
        ref: ref,
        feature: PremiumFeature.automations,
      );
      return;
    }

    AppBottomSheet.showRaw<void>(
      context: context,
      builder: (context) => _AddAutomationSheet(
        onCreateNew: () {
          Navigator.pop(context);
          _createNewAutomation(context, ref);
        },
        onSelectTemplate: (templateId) {
          Navigator.pop(context);
          _addFromTemplate(context, ref, templateId);
        },
        onSelectTrigger: (triggerType) {
          Navigator.pop(context);
          _createWithTrigger(context, ref, triggerType);
        },
      ),
    );
  }

  void _createNewAutomation(BuildContext context, WidgetRef ref) {
    // Check premium before allowing automation creation
    final hasPremium = ref.read(hasFeatureProvider(PremiumFeature.automations));
    if (!hasPremium) {
      showPremiumInfoSheet(
        context: context,
        ref: ref,
        feature: PremiumFeature.automations,
      );
      return;
    }

    // Pre-pin the protocol filter from the active shell so the editor
    // opens with MeshCore-only (or Meshtastic-only) trigger / action
    // pickers when the user is connected to a single protocol. Falls
    // back to `any` when no device is paired.
    final activeFilter = _activeProtocolFilter(ref);
    Automation? seed;
    if (activeFilter != TriggerProtocolFilter.any) {
      seed = Automation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: '',
        trigger: AutomationTrigger(
          type: TriggerType.messageReceived,
          config: {'protocolFilter': activeFilter.name},
        ),
        actions: const [AutomationAction(type: ActionType.pushNotification)],
        enabled: true,
        createdAt: DateTime.now(),
      );
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AutomationEditorScreen(automation: seed, isNew: seed != null),
      ),
    );
  }

  void _createWithTrigger(
    BuildContext context,
    WidgetRef ref,
    TriggerType triggerType,
  ) {
    // Check premium before allowing automation creation
    final hasPremium = ref.read(hasFeatureProvider(PremiumFeature.automations));
    if (!hasPremium) {
      showPremiumInfoSheet(
        context: context,
        ref: ref,
        feature: PremiumFeature.automations,
      );
      return;
    }

    // Create a new automation with pre-filled trigger type. Inherit
    // the active shell's protocol filter so the editor opens already
    // pinned (and the matrix gating drives the downstream pickers).
    final activeFilter = _activeProtocolFilter(ref);
    final automation = Automation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '${triggerType.displayName} Alert',
      description: triggerType.defaultDescription,
      trigger: AutomationTrigger(
        type: triggerType,
        config: activeFilter == TriggerProtocolFilter.any
            ? const {}
            : {'protocolFilter': activeFilter.name},
      ),
      actions: [const AutomationAction(type: ActionType.pushNotification)],
      enabled: true,
      createdAt: DateTime.now(),
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AutomationEditorScreen(automation: automation, isNew: true),
      ),
    );
  }

  void _editAutomation(
    BuildContext context,
    WidgetRef ref,
    Automation automation,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AutomationEditorScreen(automation: automation),
      ),
    );
  }

  Future<void> _addFromTemplate(
    BuildContext context,
    WidgetRef ref,
    String templateId,
  ) async {
    // Check premium before adding template
    final hasPremium = ref.read(hasFeatureProvider(PremiumFeature.automations));
    if (!hasPremium) {
      showPremiumInfoSheet(
        context: context,
        ref: ref,
        feature: PremiumFeature.automations,
      );
      return;
    }

    final activeFilter = _activeProtocolFilter(ref);
    await ref
        .read(automationsProvider.notifier)
        .addFromTemplate(templateId, protocolFilter: activeFilter);
    if (context.mounted) {
      showSuccessSnackBar(
        context,
        context.l10n.automationScreenCreatedFromTemplate,
      );
    }
  }

  void _shareAutomation(
    BuildContext context,
    WidgetRef ref,
    Automation automation,
  ) {
    showAutomationShareSheet(context, automation, ref: ref);
  }

  Future<void> _runAutomation(
    BuildContext context,
    WidgetRef ref,
    Automation automation,
  ) async {
    final engine = ref.read(automationEngineProvider);
    final event = AutomationEvent(type: TriggerType.manual);
    showLoadingSnackBar(
      context,
      context.l10n.automationScreenRunning(automation.name),
    );
    try {
      await engine.executeAutomationManually(automation, event);
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        showSuccessSnackBar(
          context,
          context.l10n.automationScreenRunSuccess(automation.name),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        showErrorSnackBar(
          context,
          context.l10n.automationScreenRunFailed(e.toString()),
        );
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Automation automation,
  ) async {
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.automationScreenDeleteTitle,
      message: context.l10n.automationScreenDeleteMessage(automation.name),
      confirmLabel: context.l10n.automationScreenDelete,
      isDestructive: true,
    );
    if (confirmed == true && context.mounted) {
      final l10n = context.l10n;
      final messenger = ScaffoldMessenger.of(context);
      showLoadingSnackBar(
        context,
        l10n.automationScreenDeleting(automation.name),
      );
      await ref
          .read(automationsProvider.notifier)
          .deleteAutomation(automation.id);
      messenger.hideCurrentSnackBar();
      showGlobalSuccessSnackBar(l10n.automationScreenDeleted(automation.name));
    }
  }

  void _showExecutionLog(BuildContext context, WidgetRef ref) {
    AppBottomSheet.showRaw<void>(
      context: context,
      builder: (_) => AutomationHistorySheet(
        onClear: () {
          ref.read(automationsProvider.notifier).clearExecutionLog();
        },
      ),
    );
  }
}

/// Bottom sheet for adding automations (when user has existing automations)
/// Uses the same rich UI as the empty state for consistency
class _AddAutomationSheet extends ConsumerWidget {
  final VoidCallback onCreateNew;
  final void Function(String templateId) onSelectTemplate;
  final void Function(TriggerType triggerType) onSelectTrigger;

  const _AddAutomationSheet({
    required this.onCreateNew,
    required this.onSelectTemplate,
    required this.onSelectTrigger,
  });

  /// Get trigger types grouped by category
  Map<String, List<TriggerType>> get _triggersByCategory {
    final grouped = <String, List<TriggerType>>{};
    for (final type in TriggerType.values) {
      final category = type.category;
      grouped.putIfAbsent(category, () => []).add(type);
    }
    return grouped;
  }

  /// Category order for display
  static const _categoryOrder = [
    'Node Status', // lint-allow: hardcoded-string
    'Battery',
    'Messages',
    'Location',
    'Time',
    'Signal',
    'Sensors',
    'Manual',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radius20),
          ),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: SemanticColors.muted,
                  borderRadius: BorderRadius.circular(AppTheme.radius2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    context.l10n.automationScreenAddAutomation,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
            // Scrollable content - matches empty state UI
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Create from scratch - same style as empty state
                  _buildCreateFromScratchCard(context),

                  const SizedBox(height: AppTheme.spacing24),

                  // Quick Start Templates - same style as empty state
                  _buildTemplatesSection(context),

                  const SizedBox(height: AppTheme.spacing24),

                  // Start with a Trigger - same style as empty state
                  _buildTriggerCategoriesSection(context),

                  SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Primary CTA to create from scratch - matches empty state style
  Widget _buildCreateFromScratchCard(BuildContext context) {
    return Column(
      children: [
        // Form-based editor card.
        BouncyTap(
          onTap: onCreateNew,
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radius16),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radius14),
                  ),
                  child: Icon(
                    Icons.add,
                    size: 28,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.automationScreenCreateFromScratch,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing4),
                      Text(
                        context.l10n.automationScreenCreateFromScratchSubtitle,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: context.textTertiary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Quick Start Templates section - matches empty state style
  Widget _buildTemplatesSection(BuildContext context) {
    final templates = AutomationRepository.templates;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              Icon(Icons.flash_on, size: 18, color: AppTheme.warningYellow),
              const SizedBox(width: AppTheme.spacing6),
              Text(
                context.l10n.automationScreenQuickStartTemplates,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacing4),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            context.l10n.automationScreenQuickStartSubtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.textTertiary),
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),
        SizedBox(
          height: 130,
          child: EdgeFade.end(
            fadeSize: 24,
            fadeColor: context.surface,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: templates.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: AppTheme.spacing12),
              itemBuilder: (context, index) {
                final template = templates[index];
                return BouncyTap(
                  onTap: () => onSelectTemplate(template.id),
                  child: Container(
                    width: 160,
                    padding: const EdgeInsets.all(AppTheme.spacing12),
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                      border: Border.all(color: context.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _getTemplateColor(
                              template.id,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius10,
                            ),
                          ),
                          child: Icon(
                            template.icon,
                            size: 20,
                            color: _getTemplateColor(template.id),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          AutomationRepository.localizedTemplateTitle(
                            template.id,
                            context.l10n,
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Get color for template based on its type - same as empty state
  Color _getTemplateColor(String templateId) {
    switch (templateId) {
      case 'low_battery_alert':
        return AppTheme.warningYellow;
      case 'node_offline_alert':
        return AppTheme.errorRed;
      case 'geofence_exit':
        return AccentColors.purple;
      case 'sos_response':
        return AppTheme.errorRed;
      case 'dead_mans_switch':
        return AccentColors.orange;
      default:
        return AccentColors.blue;
    }
  }

  /// Trigger categories section for exploration - matches empty state style
  Widget _buildTriggerCategoriesSection(BuildContext context) {
    final triggersByCategory = _triggersByCategory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              Icon(Icons.explore, size: 18, color: context.accentColor),
              const SizedBox(width: AppTheme.spacing6),
              Text(
                'Start with a Trigger', // lint-allow: hardcoded-string
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacing4),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Choose what event starts your automation', // lint-allow: hardcoded-string
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.textTertiary),
          ),
        ),
        const SizedBox(height: AppTheme.spacing16),

        // Build categories
        ..._categoryOrder.map((category) {
          final triggers = triggersByCategory[category];
          if (triggers == null || triggers.isEmpty) {
            return const SizedBox.shrink();
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category header
                Row(
                  children: [
                    Icon(
                      _categoryIcon(category),
                      size: 14,
                      color: _categoryColor(context, category),
                    ),
                    const SizedBox(width: AppTheme.spacing6),
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _categoryColor(context, category),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing8),
                // Trigger chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: triggers.map((type) {
                    return BouncyTap(
                      onTap: () => onSelectTrigger(type),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius20,
                          ),
                          border: Border.all(color: context.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(type.icon, size: 16),
                            const SizedBox(width: AppTheme.spacing6),
                            Text(
                              type.displayName,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Node Status':
        return Icons.router;
      case 'Battery':
        return Icons.battery_std;
      case 'Messages':
        return Icons.chat;
      case 'Location':
        return Icons.location_on;
      case 'Time':
        return Icons.schedule;
      case 'Signal':
        return Icons.signal_cellular_alt;
      case 'Sensors':
        return Icons.sensors;
      case 'Manual':
        return Icons.touch_app;
      default:
        return Icons.bolt;
    }
  }

  Color _categoryColor(BuildContext context, String category) {
    switch (category) {
      case 'Node Status':
        return AccentColors.blue;
      case 'Battery':
        return AppTheme.warningYellow;
      case 'Messages':
        return AppTheme.successGreen;
      case 'Location':
        return AccentColors.purple;
      case 'Time':
        return AccentColors.cyan;
      case 'Signal':
        return AccentColors.orange;
      case 'Sensors':
        return AppTheme.errorRed;
      case 'Manual':
        return Theme.of(context).colorScheme.primary;
      default:
        return SemanticColors.disabled;
    }
  }
}
