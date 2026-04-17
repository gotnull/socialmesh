// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// NodeBoard detail screen — card-based layout matching NodeDex detail.
//
// The screen is assembled from staggered `NodeBoardEntrance` cards:
//   1. Premium hero card (icon tile + title + sysop + tagline + stat chips)
//   2. Welcome card (optional, only when welcomeText is present)
//   3. Sections picker card (segmented chips that swap the thread list)
//   4. Threads card (scoped to the selected section, tappable rows)
//
// A fixed bottom gradient button launches the thread composer (stub).
// A terminal-mode icon in the app bar jumps to the BBS-style UI, and
// the overflow menu exposes edit + share (copy link) actions.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/app_bar_overflow_menu.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../providers/app_providers.dart';
import '../../../utils/snackbar.dart';
import '../models/nodeboard.dart';
import '../models/nodeboard_enums.dart';
import '../models/nodeboard_section.dart';
import '../models/nodeboard_thread.dart';
import '../providers/nodeboard_providers.dart';
import '../services/nodeboard_voice.dart';
import '../widgets/nodeboard_card_container.dart';
import '../widgets/nodeboard_edit_sheet.dart';
import 'nodeboard_compose_screen.dart';
import 'nodeboard_terminal_screen.dart';
import 'nodeboard_thread_screen.dart';

// Hero card visual tuning — kept close to the widget tree so designers can
// tune the card without threading arguments through a dozen layers.
const double _kHeroIconTileSize = 48;
const double _kHeroIconSize = 22;
const double _kHeroTitleFontSize = 22;
const double _kHeroBorderAlpha = 0.5;
const double _kHeroIconBgAlpha = 0.15;
const double _kBadgeBgAlpha = 0.12;
const double _kBadgeBorderAlpha = 0.5;
const double _kBadgeLetterSpacing = 0.5;
const double _kBadgeFontSize = 11;
const double _kTaglineFontSize = 14;
const double _kTaglineLineHeight = 1.4;
const double _kThreadRowDividerAlpha = 0.12;
const double _kThreadRowVerticalPadding = AppTheme.spacing12;

class NodeBoardScreen extends ConsumerWidget {
  final String slug;

  const NodeBoardScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardAsync = ref.watch(nodeBoardDetailProvider(slug));

    return boardAsync.when(
      data: (board) {
        if (board == null) {
          return _ErrorShell(
            title: context.l10n.nodeboardTitle,
            message: context.l10n.nodeboardBoardNotFound,
          );
        }
        return _BoardContent(slug: slug, board: board);
      },
      loading: () => GlassScaffold.body(
        title: context.l10n.nodeboardTitle,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _ErrorShell(
        title: context.l10n.nodeboardTitle,
        message: context.l10n.nodeboardLoadError,
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Main content — watches sections and renders the card stack.
// ----------------------------------------------------------------------------

class _BoardContent extends ConsumerStatefulWidget {
  final String slug;
  final NodeBoard board;

  const _BoardContent({required this.slug, required this.board});

  @override
  ConsumerState<_BoardContent> createState() => _BoardContentState();
}

class _BoardContentState extends ConsumerState<_BoardContent>
    with LifecycleSafeMixin<_BoardContent> {
  int _selectedSectionIndex = 0;

  void _onSectionTapped(int index, NodeBoardSection section) {
    if (index == _selectedSectionIndex) return;
    HapticFeedback.lightImpact();
    AppLogging.nodeBoard(
      'UI: section selected slug=${widget.slug} index=$index key=${section.key}',
    );
    safeSetState(() => _selectedSectionIndex = index);
  }

  Future<void> _onEditTapped() async {
    HapticFeedback.lightImpact();
    AppLogging.nodeBoard('UI: overflow action=edit slug=${widget.slug}');
    await showNodeBoardEditSheet(context: context, board: widget.board);
  }

  Future<void> _onShareTapped() async {
    HapticFeedback.lightImpact();
    AppLogging.nodeBoard('UI: overflow action=share slug=${widget.slug}');
    final url =
        'https://socialmesh.app/share/board/${widget.slug}'; // lint-allow: hardcoded-string
    final messenger = ScaffoldMessenger.maybeOf(context);
    final copiedMessage = context.l10n.nodeboardShareCopied;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted || messenger == null) return;
    showSuccessSnackBar(context, copiedMessage);
  }

  void _onTerminalTapped() {
    HapticFeedback.lightImpact();
    AppLogging.nodeBoard('UI: switching to terminal mode slug=${widget.slug}');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NodeBoardTerminalScreen(slug: widget.slug),
      ),
    );
  }

  Future<void> _onComposeTapped() async {
    HapticFeedback.lightImpact();
    AppLogging.nodeBoard('UI: compose tapped slug=${widget.slug}');
    final sectionsAsync = ref.read(nodeBoardSectionsProvider(widget.slug));
    final sections = sectionsAsync.value ?? const <NodeBoardSection>[];
    if (sections.isEmpty) {
      showErrorSnackBar(
        context,
        // lint-allow: hardcoded-string
        'This board has no sections yet',
      );
      return;
    }
    final clampedIndex = _selectedSectionIndex.clamp(0, sections.length - 1);
    final section = sections[clampedIndex];

    final result = await pushNodeBoardComposeScreen(
      context: context,
      kind: NodeBoardComposeKind.thread,
      sectionTitle: section.title,
    );
    if (!mounted) return;
    if (result == null) {
      AppLogging.nodeBoard('UI: compose cancelled');
      return;
    }

    final notifier = ref.read(nodeBoardModNotifierProvider.notifier);
    try {
      final myNodeNum = ref.read(myNodeNumProvider);
      final nodes = ref.read(nodesProvider);
      final myNode = myNodeNum != null ? nodes[myNodeNum] : null;
      final myHexId = myNodeNum != null
          ? '!${myNodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}'
          : null;
      final displayName =
          myNode?.displayName ?? myNode?.shortName ?? widget.board.sysopName;

      await notifier.createThread(
        widget.slug,
        widget.board.id,
        section.id,
        {
          'sectionId': section.id,
          'title': result.title,
          'body': result.body,
          'authorDisplayName': displayName,
          if (myHexId != null) 'authorNodeId': myHexId,
        },
        ownerNodeId: widget.board.ownerNodeId,
      );
      if (!mounted) return;
      AppLogging.nodeBoard('UI: thread posted');
      HapticFeedback.lightImpact();
      showSuccessSnackBar(
        context,
        // lint-allow: hardcoded-string
        'Thread posted',
      );
    } catch (e) {
      AppLogging.nodeBoard('UI: compose failed: $e');
      if (!mounted) return;
      showErrorSnackBar(
        context,
        // lint-allow: hardcoded-string
        'Failed to post thread: $e',
      );
    }
  }

  void _onThreadTapped(NodeBoardThread thread) {
    HapticFeedback.lightImpact();
    AppLogging.nodeBoard(
      'UI: opening thread slug=${widget.slug} threadId=${thread.id}',
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            NodeBoardThreadScreen(slug: widget.slug, threadId: thread.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final board = widget.board;
    final sectionsAsync = ref.watch(nodeBoardSectionsProvider(widget.slug));

    return GlassScaffold(
      title: board.title,
      actions: [
        IconButton(
          icon: const Icon(Icons.terminal),
          tooltip: context.l10n.nodeboardTerminalMode,
          onPressed: _onTerminalTapped,
        ),
        AppBarOverflowMenu<String>(
          onSelected: (value) async {
            if (value == _MenuAction.edit) {
              await _onEditTapped();
            } else if (value == _MenuAction.share) {
              await _onShareTapped();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: _MenuAction.edit,
              child: _OverflowMenuRow(
                icon: Icons.edit_outlined,
                label: context.l10n.nodeboardEditBoard,
              ),
            ),
            PopupMenuItem<String>(
              value: _MenuAction.share,
              child: _OverflowMenuRow(
                icon: Icons.share_outlined,
                label: context.l10n.nodeboardShareBoard,
              ),
            ),
          ],
        ),
      ],
      bottomNavigationBar: BottomActionBar(
        child: _NewThreadButton(onPressed: _onComposeTapped),
      ),
      slivers: [
        // 1. Hero card — NOT using NodeBoardCardContainer (premium hero).
        SliverToBoxAdapter(
          child: NodeBoardEntrance(index: 0, child: _HeroCard(board: board)),
        ),

        // 2. Welcome card (optional).
        if (board.welcomeText != null && board.welcomeText!.trim().isNotEmpty)
          SliverToBoxAdapter(
            child: NodeBoardEntrance(
              index: 1,
              child: NodeBoardCardContainer(
                title: context.l10n.nodeboardWelcomeSectionTitle,
                icon: Icons.auto_awesome_outlined,
                child: Text(
                  board.welcomeText!,
                  style: TextStyle(
                    fontSize: _kTaglineFontSize,
                    height: _kTaglineLineHeight,
                    color: context.textSecondary,
                  ),
                ),
              ),
            ),
          ),

        // 3. Sections picker + 4. Threads card (only once sections resolve).
        ...sectionsAsync.when(
          data: (sections) => _buildSectionSlivers(sections, board),
          loading: () => [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spacing24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
          error: (e, _) => [
            SliverToBoxAdapter(
              child: NodeBoardEntrance(
                index: 2,
                child: NodeBoardCardContainer(
                  title: context.l10n.nodeboardLoadError,
                  icon: Icons.error_outline,
                  child: Text(
                    context.l10n.nodeboardLoadError,
                    style: TextStyle(
                      fontSize: _kTaglineFontSize,
                      color: context.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        // Trailing breathing room so the last card clears the bottom bar.
        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacing32)),
      ],
    );
  }

  List<Widget> _buildSectionSlivers(
    List<NodeBoardSection> sections,
    NodeBoard board,
  ) {
    if (sections.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: NodeBoardEntrance(
            index: 2,
            child: NodeBoardCardContainer(
              title: context.l10n.nodeboardSectionsSectionTitle,
              icon: Icons.view_list_outlined,
              child: _EmptyInlineState(
                icon: Icons.view_list_outlined,
                label: context.l10n.nodeboardNoSections,
              ),
            ),
          ),
        ),
      ];
    }

    final clampedIndex = _selectedSectionIndex.clamp(0, sections.length - 1);
    final selectedSection = sections[clampedIndex];

    return [
      SliverToBoxAdapter(
        child: NodeBoardEntrance(
          index: 2,
          child: NodeBoardCardContainer(
            title: context.l10n.nodeboardSectionsSectionTitle,
            icon: Icons.view_list_outlined,
            child: _SectionPicker(
              sections: sections,
              selectedIndex: clampedIndex,
              onSelected: _onSectionTapped,
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: NodeBoardEntrance(
          index: 3,
          child: _ThreadsCard(
            slug: widget.slug,
            boardId: board.id,
            section: selectedSection,
            onThreadTap: _onThreadTapped,
          ),
        ),
      ),
    ];
  }
}

// ----------------------------------------------------------------------------
// Overflow menu action identifiers. Kept as constants so provider logs and
// lint-allow comments can reference a single source of truth.
// ----------------------------------------------------------------------------

class _MenuAction {
  _MenuAction._();
  static const String edit = 'edit'; // lint-allow: hardcoded-string
  static const String share = 'share'; // lint-allow: hardcoded-string
}

class _OverflowMenuRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _OverflowMenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: AppTheme.spacing20, color: context.textSecondary),
        const SizedBox(width: AppTheme.spacing12),
        Text(label),
      ],
    );
  }
}

// ----------------------------------------------------------------------------
// Error shell — used when the board fetch fails or returns null.
// ----------------------------------------------------------------------------

class _ErrorShell extends StatelessWidget {
  final String title;
  final String message;

  const _ErrorShell({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold.body(
      title: title,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing24),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacing20),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(AppTheme.radius16),
              border: Border.all(
                color: context.border.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
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
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: _kTaglineFontSize,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Hero card — a richer, bespoke card at the top of the screen. Deliberately
// NOT using NodeBoardCardContainer so the icon tile, title, and stats can
// dominate the first viewport the way NodeDex's sigil-hero does.
// ----------------------------------------------------------------------------

class _HeroCard extends StatelessWidget {
  final NodeBoard board;

  const _HeroCard({required this.board});

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    final visibilityColor = _visibilityTint(context, board.visibility);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing8,
      ),
      padding: const EdgeInsets.all(AppTheme.spacing20),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(
          color: context.border.withValues(alpha: _kHeroBorderAlpha),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon tile + title row.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: _kHeroIconTileSize,
                height: _kHeroIconTileSize,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: _kHeroIconBgAlpha),
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: Icon(
                  Icons.dashboard_outlined,
                  color: accent,
                  size: _kHeroIconSize,
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppTheme.spacing4),
                  child: Text(
                    board.title,
                    style: TextStyle(
                      fontSize: _kHeroTitleFontSize,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spacing12),

          // SysOp row.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.person_outline,
                  size: AppTheme.spacing14,
                  color: accent,
                ),
              ),
              const SizedBox(width: AppTheme.spacing6),
              Expanded(
                child: Text(
                  '${context.l10n.nodeboardSysop}: ${board.sysopName}',
                  style: TextStyle(
                    fontSize: _kTaglineFontSize,
                    fontWeight: FontWeight.w600,
                    color: accent,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),

          // Tagline.
          if (board.tagline != null && board.tagline!.trim().isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacing8),
            Text(
              board.tagline!,
              style: TextStyle(
                fontSize: _kTaglineFontSize,
                fontStyle: FontStyle.italic,
                height: _kTaglineLineHeight,
                color: context.textSecondary,
              ),
            ),
          ],

          // Activity line — tone-aware, e.g. "LAST TRANSMISSION: 2H AGO".
          // Skipped for boards that have never had any activity so we don't
          // render a dead "NEVER" row on brand-new boards.
          if (board.lastActivityAt != null) ...[
            const SizedBox(height: AppTheme.spacing10),
            _HeroActivityLine(board: board),
          ],

          const SizedBox(height: AppTheme.spacing16),

          // Stats row.
          Wrap(
            spacing: AppTheme.spacing8,
            runSpacing: AppTheme.spacing8,
            children: [
              NodeBoardStatChip(
                icon: Icons.forum_outlined,
                label: context.l10n.nodeboardThreadCount(
                  board.stats.threadCount,
                ),
              ),
              NodeBoardStatChip(
                icon: Icons.reply_outlined,
                label: context.l10n.nodeboardReplyCount(board.stats.replyCount),
              ),
              NodeBoardStatChip(
                icon: Icons.view_list_outlined,
                label: context.l10n.nodeboardSectionCount(
                  board.stats.sectionCount,
                ),
              ),
              _VisibilityBadge(
                label: _visibilityLabel(context, board.visibility),
                color: visibilityColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _visibilityTint(BuildContext context, BoardVisibility v) =>
      switch (v) {
        BoardVisibility.public_ => SemanticColors.success,
        BoardVisibility.unlisted => SemanticColors.warning,
        BoardVisibility.private_ => context.textTertiary,
      };

  static String _visibilityLabel(BuildContext context, BoardVisibility v) =>
      switch (v) {
        BoardVisibility.public_ => context.l10n.nodeboardVisibilityPublic,
        BoardVisibility.unlisted => context.l10n.nodeboardVisibilityUnlisted,
        BoardVisibility.private_ => context.l10n.nodeboardVisibilityPrivate,
      };
}

class _VisibilityBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _VisibilityBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing10,
        vertical: AppTheme.spacing6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: _kBadgeBgAlpha),
        borderRadius: BorderRadius.circular(AppTheme.radius20),
        border: Border.all(
          color: color.withValues(alpha: _kBadgeBorderAlpha),
          width: 0.5,
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: _kBadgeFontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: _kBadgeLetterSpacing,
          color: color,
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Sections picker — horizontally-scrollable chip row. Taps swap the thread
// card's section without rebuilding the whole screen.
// ----------------------------------------------------------------------------

class _SectionPicker extends StatelessWidget {
  final List<NodeBoardSection> sections;
  final int selectedIndex;
  final void Function(int index, NodeBoardSection section) onSelected;

  const _SectionPicker({
    required this.sections,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < sections.length; i++) ...[
            if (i > 0) const SizedBox(width: AppTheme.spacing8),
            _SectionChip(
              label: sections[i].title,
              selected: i == selectedIndex,
              onTap: () => onSelected(i, sections[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SectionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    final bgColor = selected
        ? accent.withValues(alpha: _kBadgeBgAlpha)
        : context.border.withValues(alpha: 0.08);
    final borderColor = selected
        ? accent.withValues(alpha: _kBadgeBorderAlpha)
        : context.border.withValues(alpha: 0.15);
    final textColor = selected ? accent : context.textSecondary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing12,
          vertical: AppTheme.spacing8,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppTheme.radius20),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: _kTaglineFontSize,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Threads card — scoped to the currently-selected section.
// ----------------------------------------------------------------------------

class _ThreadsCard extends ConsumerWidget {
  final String slug;
  final String boardId;
  final NodeBoardSection section;
  final void Function(NodeBoardThread thread) onThreadTap;

  const _ThreadsCard({
    required this.slug,
    required this.boardId,
    required this.section,
    required this.onThreadTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = ThreadListKey(
      slug: slug,
      boardId: boardId,
      sectionId: section.id,
    );
    final threadsAsync = ref.watch(nodeBoardThreadListProvider(key));
    final boardAsync = ref.watch(nodeBoardDetailProvider(slug));
    final board = boardAsync.value;
    final voice = NodeBoardVoice(
      tone: BoardTone.fromThemeId(board?.themeId),
      seed: boardId.hashCode,
    );
    // lint-allow: hardcoded-string
    final isGuestbook = section.key == 'guestbook';
    final emptyLabel = isGuestbook
        ? voice.emptyGuestbookTitle()
        : voice.emptyThreadsTitle();
    final emptySubtitle = isGuestbook
        ? voice.emptyGuestbookSubtitle()
        : voice.emptyThreadsSubtitle();

    return NodeBoardCardContainer(
      title: context.l10n.nodeboardThreadsSectionTitle,
      icon: Icons.forum_outlined,
      child: threadsAsync.when(
        data: (threads) {
          if (threads.isEmpty) {
            AppLogging.nodeBoard(
              'Voice: empty threads card | tone=${voice.tone} '
              'section=${section.key} label="$emptyLabel"',
            );
            return _EmptyInlineState(
              icon: isGuestbook
                  ? Icons.edit_note_outlined
                  : Icons.chat_bubble_outline,
              label: emptyLabel,
              subtitle: emptySubtitle,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < threads.length; i++) ...[
                _ThreadRow(
                  thread: threads[i],
                  onTap: () => onThreadTap(threads[i]),
                ),
                if (i < threads.length - 1)
                  Divider(
                    height: 0,
                    thickness: 0.5,
                    color: context.border.withValues(
                      alpha: _kThreadRowDividerAlpha,
                    ),
                  ),
              ],
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: AppTheme.spacing16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => _EmptyInlineState(
          icon: Icons.error_outline,
          label: context.l10n.nodeboardLoadError,
        ),
      ),
    );
  }
}

class _ThreadRow extends StatelessWidget {
  final NodeBoardThread thread;
  final VoidCallback onTap;

  const _ThreadRow({required this.thread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: _kThreadRowVerticalPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (thread.isPinned) ...[
                  Icon(
                    Icons.push_pin,
                    size: AppTheme.spacing14,
                    color: context.accentColor,
                  ),
                  const SizedBox(width: AppTheme.spacing6),
                ],
                Expanded(
                  child: Text(
                    thread.title,
                    style: TextStyle(
                      fontSize: _kTaglineFontSize,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ),
                if (thread.isLocked) ...[
                  const SizedBox(width: AppTheme.spacing6),
                  Icon(
                    Icons.lock_outline,
                    size: AppTheme.spacing14,
                    color: context.textTertiary,
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppTheme.spacing4),
            Wrap(
              spacing: AppTheme.spacing8,
              runSpacing: AppTheme.spacing4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  thread.authorDisplayName,
                  style: TextStyle(fontSize: 12, color: context.textTertiary),
                ),
                Text(
                  context.l10n.nodeboardReplyCount(thread.replyCount),
                  style: TextStyle(fontSize: 12, color: context.textTertiary),
                ),
                Text(
                  _timeAgoLabel(
                    context,
                    thread.lastReplyAt ?? thread.createdAt,
                  ),
                  style: TextStyle(fontSize: 12, color: context.textTertiary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgoLabel(BuildContext context, DateTime when) {
    final l10n = context.l10n;
    final diff = DateTime.now().difference(when);
    if (diff.inDays > 365) return l10n.nodeboardYearsAgo(diff.inDays ~/ 365);
    if (diff.inDays > 30) return l10n.nodeboardMonthsAgo(diff.inDays ~/ 30);
    if (diff.inDays > 0) return l10n.nodeboardDaysAgo(diff.inDays);
    if (diff.inHours > 0) return l10n.nodeboardHoursAgo(diff.inHours);
    if (diff.inMinutes > 0) return l10n.nodeboardMinutesAgo(diff.inMinutes);
    return l10n.nodeboardJustNow;
  }
}

// ----------------------------------------------------------------------------
// Inline empty state used inside a NodeBoardCardContainer body.
// ----------------------------------------------------------------------------

/// Small tone-aware "LAST TRANSMISSION: 2H AGO" line shown under the
/// hero card tagline. Reads tone off the board's theme so different
/// boards speak with slightly different cadences.
class _HeroActivityLine extends StatelessWidget {
  final NodeBoard board;

  const _HeroActivityLine({required this.board});

  @override
  Widget build(BuildContext context) {
    final voice = NodeBoardVoice(
      tone: BoardTone.fromThemeId(board.themeId),
      seed: board.id.hashCode,
    );
    final rel = formatNodeBoardRelativeTime(board.lastActivityAt);
    final label = '${voice.activityLabel}: ${rel.toUpperCase()}';
    AppLogging.nodeBoard(
      'Voice: hero activity rendered | tone=${voice.tone} rel=$rel',
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            Icons.sensors,
            size: AppTheme.spacing14,
            color: context.textTertiary,
          ),
        ),
        const SizedBox(width: AppTheme.spacing6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: context.textTertiary,
              letterSpacing: 0.8,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyInlineState extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;

  const _EmptyInlineState({
    required this.icon,
    required this.label,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppTheme.spacing32, color: context.textTertiary),
          const SizedBox(height: AppTheme.spacing10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppTheme.spacing4),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: context.textTertiary,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Gradient "New Thread" button shown in the fixed bottom action bar.
// ----------------------------------------------------------------------------

class _NewThreadButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _NewThreadButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    return BouncyTap(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [accent, accent.withValues(alpha: 0.75)],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radius16),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.35),
              blurRadius: AppTheme.spacing16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_comment_outlined,
              size: AppTheme.spacing20,
              color: SemanticColors.onAccent,
            ),
            const SizedBox(width: AppTheme.spacing8),
            Text(
              context.l10n.nodeboardNewThread,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: SemanticColors.onAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
