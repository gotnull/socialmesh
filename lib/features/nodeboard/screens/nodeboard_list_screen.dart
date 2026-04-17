// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// NodeBoard list screen — "My Boards" and "Discover" tabs. Premium design
// matching Signals / Aether / NodeDex: GlassScaffold host, cycling animated
// empty states, staggered card entrances, haptic-armed taps.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animated_empty_state.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../providers/nodeboard_providers.dart';
import '../widgets/nodeboard_card.dart';
import '../widgets/nodeboard_card_container.dart';
import 'nodeboard_screen.dart';
import 'nodeboard_wizard_screen.dart';

class NodeBoardListScreen extends ConsumerWidget {
  const NodeBoardListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: GlassScaffold(
        title: context.l10n.nodeboardTitle,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: context.l10n.nodeboardCreateBoard,
            onPressed: () {
              AppLogging.nodeBoard('UI: navigating to create wizard');
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NodeBoardWizardScreen(),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          indicatorColor: context.accentColor,
          labelColor: context.textPrimary,
          unselectedLabelColor: context.textSecondary,
          tabs: [
            Tab(text: context.l10n.nodeboardMyBoards),
            Tab(text: context.l10n.nodeboardDiscover),
          ],
        ),
        slivers: const [
          SliverFillRemaining(
            hasScrollBody: true,
            child: TabBarView(children: [_MyBoardsTab(), _DiscoverTab()]),
          ),
        ],
      ),
    );
  }
}

void _openWizard(BuildContext context, String logReason) {
  AppLogging.nodeBoard(logReason);
  HapticFeedback.lightImpact();
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const NodeBoardWizardScreen()));
}

class _MyBoardsTab extends ConsumerWidget {
  const _MyBoardsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myBoards = ref.watch(myNodeBoardsProvider);

    return myBoards.when(
      data: (boards) {
        if (boards.isEmpty) {
          return AnimatedEmptyState(
            config: AnimatedEmptyStateConfig(
              icons: const [
                Icons.dashboard_outlined,
                Icons.forum_outlined,
                Icons.terminal,
                Icons.edit_note,
                Icons.public,
                Icons.computer,
              ],
              taglines: [
                context.l10n.nodeboardEmptyMyBoardsDescription,
                // lint-allow: hardcoded-string
                'Run your own retro BBS on the mesh',
                // lint-allow: hardcoded-string
                'Threads, sections, and terminal mode',
                // lint-allow: hardcoded-string
                'Your board, your rules',
              ],
              // lint-allow: hardcoded-string
              titlePrefix: 'No ',
              // lint-allow: hardcoded-string
              titleKeyword: 'boards',
              // lint-allow: hardcoded-string
              titleSuffix: ' yet',
              actionLabel: context.l10n.nodeboardCreateFirstBoard,
              actionIcon: Icons.add,
              onAction: () =>
                  _openWizard(context, 'UI: empty state → create wizard'),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(
            top: AppTheme.spacing8,
            bottom: AppTheme.spacing24,
          ),
          itemCount: boards.length,
          itemBuilder: (context, index) {
            final board = boards[index];
            return NodeBoardEntrance(
              index: index,
              child: NodeBoardCard(
                summary: board,
                onTap: () {
                  AppLogging.nodeBoard('UI: opening board slug=${board.slug}');
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NodeBoardScreen(slug: board.slug),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _ErrorState(message: context.l10n.nodeboardLoadError),
    );
  }
}

class _DiscoverTab extends ConsumerWidget {
  const _DiscoverTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discoverBoards = ref.watch(discoverNodeBoardsProvider);

    return discoverBoards.when(
      data: (boards) {
        if (boards.isEmpty) {
          return AnimatedEmptyState(
            config: AnimatedEmptyStateConfig(
              icons: const [
                Icons.explore_outlined,
                Icons.public,
                Icons.forum_outlined,
                Icons.search,
                Icons.language,
                Icons.rss_feed,
              ],
              taglines: [
                context.l10n.nodeboardEmptyDiscoverDescription,
                // lint-allow: hardcoded-string
                'Discover boards from the mesh community',
                // lint-allow: hardcoded-string
                'Public boards appear here automatically',
                // lint-allow: hardcoded-string
                'Join the conversation on any board',
              ],
              // lint-allow: hardcoded-string
              titlePrefix: 'No ',
              // lint-allow: hardcoded-string
              titleKeyword: 'public boards',
              // lint-allow: hardcoded-string
              titleSuffix: ' yet',
              actionLabel: context.l10n.nodeboardCreateBoard,
              actionIcon: Icons.add,
              onAction: () =>
                  _openWizard(context, 'UI: discover empty → create wizard'),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(
            top: AppTheme.spacing8,
            bottom: AppTheme.spacing24,
          ),
          itemCount: boards.length,
          itemBuilder: (context, index) {
            final board = boards[index];
            return NodeBoardEntrance(
              index: index,
              child: NodeBoardCard(
                summary: board,
                onTap: () {
                  AppLogging.nodeBoard('UI: opening board slug=${board.slug}');
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NodeBoardScreen(slug: board.slug),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _ErrorState(message: context.l10n.nodeboardLoadError),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: AppTheme.spacing48,
            color: context.textSecondary,
          ),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            message,
            style: TextStyle(fontSize: 14, color: context.textSecondary),
          ),
        ],
      ),
    );
  }
}
