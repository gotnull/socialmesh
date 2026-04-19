// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animated_empty_state.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../services/haptic_service.dart';
import '../providers/mesh_incident_providers.dart';
import '../widgets/mesh_incident_card.dart';
import 'mesh_incident_composer_screen.dart';
import 'mesh_incident_detail_screen.dart';

/// Lists all mesh incident cases received via SIP/MRRP/SPP.
///
/// Shows case projections (effective state from replayed reports).
/// Tap a case to see its full timeline. Tap + to create a new report.
class MeshIncidentListScreen extends ConsumerWidget {
  const MeshIncidentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final casesAsync = ref.watch(meshIncidentAllCasesProvider);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: GlassScaffold(
        title: context.l10n.meshIncidentListTitle,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: context.l10n.meshIncidentCreateButton,
            onPressed: () {
              ref.haptics.buttonTap();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MeshIncidentComposerScreen(),
                ),
              );
            },
          ),
        ],
        slivers: [
          casesAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing24),
                  child: Text(
                    '$e',
                    textAlign: TextAlign.center,
                    style: context.bodyMutedStyle,
                  ),
                ),
              ),
            ),
            data: (cases) {
              if (cases.isEmpty) {
                return SliverFillRemaining(
                  child: AnimatedEmptyState(
                    config: AnimatedEmptyStateConfig(
                      icons: const [
                        Icons.warning_amber_rounded,
                        Icons.cell_tower,
                        Icons.shield_outlined,
                        Icons.medical_services_outlined,
                      ],
                      taglines: [
                        context.l10n.meshIncidentEmptyTagline1,
                        context.l10n.meshIncidentEmptyTagline2,
                        context.l10n.meshIncidentEmptyTagline3,
                      ],
                      titlePrefix: context.l10n.meshIncidentEmptyTitle
                          .split(' ')
                          .take(2)
                          .join(' '),
                      titleKeyword:
                          ' ${context.l10n.meshIncidentEmptyTitle.split(' ').skip(2).join(' ')}',
                      titleSuffix: '',
                      actionLabel: context.l10n.meshIncidentCreateButton,
                      actionIcon: Icons.add,
                      onAction: () {
                        ref.haptics.buttonTap();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const MeshIncidentComposerScreen(),
                          ),
                        );
                      },
                      accentColor: AccentColors.orange,
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing16,
                  vertical: AppTheme.spacing8,
                ),
                sliver: SliverList.builder(
                  itemCount: cases.length,
                  itemBuilder: (context, index) {
                    final caseState = cases[index];
                    return _StaggeredCard(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppTheme.spacing12,
                        ),
                        child: MeshIncidentCard(
                          caseState: caseState,
                          onTap: () {
                            ref.haptics.buttonTap();
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => MeshIncidentDetailScreen(
                                  caseId: caseState.caseId,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Staggered slide+fade entrance animation for list items.
class _StaggeredCard extends StatefulWidget {
  final int index;
  final Widget child;

  const _StaggeredCard({required this.index, required this.child});

  @override
  State<_StaggeredCard> createState() => _StaggeredCardState();
}

class _StaggeredCardState extends State<_StaggeredCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: (widget.index * 40).clamp(0, 400));
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(position: _slideAnim, child: widget.child),
    );
  }
}
