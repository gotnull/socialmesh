// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Terminal mode — hybrid BBS UX. Command line + context-aware chip bar
// + tappable indexed output over the exact same providers that power
// the native board view.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../providers/app_providers.dart';
import '../models/nodeboard_enums.dart';
import '../models/nodeboard_section.dart';
import '../models/terminal_preset.dart';
import '../providers/nodeboard_providers.dart';
import '../services/nodeboard_voice.dart';
import '../services/terminal_command_parser.dart';
import '../../../utils/snackbar.dart';
import '../widgets/terminal_chip_bar.dart';
import '../widgets/terminal_chrome.dart';
import '../widgets/terminal_command_input.dart';
import 'nodeboard_compose_screen.dart';
import '../widgets/terminal_output_line.dart';
import '../widgets/terminal_splash_view.dart';

class NodeBoardTerminalScreen extends ConsumerStatefulWidget {
  const NodeBoardTerminalScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<NodeBoardTerminalScreen> createState() =>
      _NodeBoardTerminalScreenState();
}

class _NodeBoardTerminalScreenState
    extends ConsumerState<NodeBoardTerminalScreen>
    with LifecycleSafeMixin<NodeBoardTerminalScreen> {
  final _scrollController = ScrollController();
  bool _welcomeShown = false;
  // Tracks which section/thread has been rendered so transitions don't
  // redundantly re-render. Set to null to force a re-render on the next
  // build pass (used after posting a new thread or reply).
  String? _lastRenderedSectionId;
  String? _lastRenderedThreadId;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  /// Resolve the posting user's identity from the connected node. Used
  /// to stamp new threads/replies with the author's real node hex ID so
  /// reply tiles can render the correct sigil and tap through to the
  /// matching NodeDex detail. Falls back to [fallbackName] when no node
  /// is connected (e.g. cold start) so composing isn't blocked.
  ({String displayName, String? nodeId}) _resolveAuthorIdentity(
    String fallbackName,
  ) {
    final myNodeNum = ref.read(myNodeNumProvider);
    final nodes = ref.read(nodesProvider);
    final myNode = myNodeNum != null ? nodes[myNodeNum] : null;
    final myHexId = myNodeNum != null
        ? '!${myNodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}'
        : null;
    final displayName =
        myNode?.displayName ?? myNode?.shortName ?? fallbackName;
    return (displayName: displayName, nodeId: myHexId);
  }

  /// Single dispatch path for every command source: typed input, chip
  /// tap, and tappable-output tap all land here. The command is parsed
  /// once and the notifier returns a typed [TerminalEffect] the screen
  /// resolves against live provider data — there are no string
  /// side-channels or alternate paths.
  Future<void> _onCommand(String input) async {
    AppLogging.nodeBoard('Terminal dispatch | source=command input="$input"');
    final notifier = ref.read(terminalStateProvider.notifier);
    final parsed = parseTerminalCommand(input);

    // BACK at the root is a silent no-op — echoing `> BACK` and `< Back`
    // for every tap when there's nowhere to go back just pollutes the
    // scrollback. Rapid chip taps before the chip bar rebuilds can still
    // dispatch BACK; this guard swallows them cleanly.
    if (parsed.command == TerminalCommand.back &&
        ref.read(terminalStateProvider).screenStack.length <= 1) {
      AppLogging.nodeBoard('Terminal dispatch | BACK at root (swallowed)');
      return;
    }

    notifier.appendOutput([
      TerminalOutputLine('> $input', TerminalLineStyle.accent),
    ]);

    final effect = notifier.executeCommand(parsed);

    _scrollToBottom();

    switch (effect) {
      case NoEffect():
        break;
      case QuitEffect():
        HapticFeedback.lightImpact();
        safeNavigatorPop();
      case OpenIndexEffect(index: final i):
        _resolveOpenIndex(i);
      case OpenGuestbookEffect():
        _resolveGuestbook();
      case ComposeThreadEffect():
        await _handleComposeThread();
      case ComposeReplyEffect():
        await _handleComposeReply();
    }
  }

  /// Resolve `OPEN n` against the currently-visible list. Reads sections
  /// and threads from their providers directly — no cached copies.
  void _resolveOpenIndex(int index) {
    final state = ref.read(terminalStateProvider);
    final screen = state.currentScreen;
    final notifier = ref.read(terminalStateProvider.notifier);

    final voice = state.voice;

    if (screen == TerminalScreen.sectionList) {
      final sections =
          ref.read(nodeBoardSectionsProvider(widget.slug)).value ?? const [];
      if (index < 1 || index > sections.length) {
        AppLogging.nodeBoard(
          'Terminal invalidOpen | kind=section index=$index max=${sections.length}',
        );
        // lint-allow: hardcoded-string
        notifier.renderError(voice.outOfRange('SECTION', index));
        _scrollToBottom();
        return;
      }
      final section = sections[index - 1];
      AppLogging.nodeBoard(
        'Terminal open resolve | kind=section index=$index key=${section.key} id=${section.id}',
      );
      notifier.appendOutput([
        TerminalOutputLine(
          voice.openingSection(section.title),
          TerminalLineStyle.accent,
        ),
      ]);
      _lastRenderedSectionId = null;
      notifier.openSection(sectionId: section.id, sectionKey: section.key);
      return;
    }

    if (screen == TerminalScreen.threadList) {
      final board = ref.read(nodeBoardDetailProvider(widget.slug)).value;
      final sectionId = state.currentSectionId;
      if (board == null || sectionId == null) {
        // lint-allow: hardcoded-string
        notifier.renderError(voice.notHere());
        _scrollToBottom();
        return;
      }
      final listKey = ThreadListKey(
        slug: widget.slug,
        boardId: board.id,
        sectionId: sectionId,
      );
      final threads =
          ref.read(nodeBoardThreadListProvider(listKey)).value ?? const [];
      if (index < 1 || index > threads.length) {
        AppLogging.nodeBoard(
          'Terminal invalidOpen | kind=thread index=$index max=${threads.length}',
        );
        // lint-allow: hardcoded-string
        notifier.renderError(voice.outOfRange('THREAD', index));
        _scrollToBottom();
        return;
      }
      final thread = threads[index - 1];
      AppLogging.nodeBoard(
        'Terminal open resolve | kind=thread index=$index threadId=${thread.id}',
      );
      notifier.appendOutput([
        TerminalOutputLine(
          voice.openingThread(thread.title),
          TerminalLineStyle.accent,
        ),
      ]);
      _lastRenderedThreadId = null;
      notifier.openThread(thread.id);
      return;
    }

    AppLogging.nodeBoard('Terminal invalidOpen | screen=$screen index=$index');
    notifier.renderError(voice.notHere());
    _scrollToBottom();
  }

  /// Resolve GUESTBOOK by finding the `guestbook`-keyed section and
  /// opening it. Boards without a guestbook get a clean error.
  void _resolveGuestbook() {
    final sections =
        ref.read(nodeBoardSectionsProvider(widget.slug)).value ?? const [];
    final notifier = ref.read(terminalStateProvider.notifier);
    NodeBoardSection? guestbook;
    for (final s in sections) {
      if (s.key == 'guestbook') {
        guestbook = s;
        break;
      }
    }
    if (guestbook == null) {
      AppLogging.nodeBoard('Terminal guestbook resolve | missing');
      // lint-allow: hardcoded-string
      notifier.renderError('NO GUESTBOOK ON THIS BOARD');
      _scrollToBottom();
      return;
    }
    AppLogging.nodeBoard(
      'Terminal guestbook resolve | sectionId=${guestbook.id}',
    );
    _lastRenderedSectionId = null;
    notifier.openSection(sectionId: guestbook.id, sectionKey: guestbook.key);
  }

  Future<void> _handleComposeThread() async {
    AppLogging.nodeBoard('Terminal: compose thread start');
    final state = ref.read(terminalStateProvider);
    final boardAsync = ref.read(nodeBoardDetailProvider(widget.slug));
    final board = boardAsync.value;
    if (board == null || state.currentSectionId == null) {
      ref
          .read(terminalStateProvider.notifier)
          // lint-allow: hardcoded-string
          .renderError(state.voice.missingContext('SECTION'));
      _scrollToBottom();
      return;
    }
    final sectionsAsync = ref.read(nodeBoardSectionsProvider(widget.slug));
    final sections = sectionsAsync.value ?? const [];
    final section = sections.firstWhere(
      (s) => s.id == state.currentSectionId,
      orElse: () => sections.first,
    );

    final result = await pushNodeBoardComposeScreen(
      context: context,
      kind: NodeBoardComposeKind.thread,
      sectionTitle: section.title,
    );
    if (!mounted) return;
    if (result == null) {
      AppLogging.nodeBoard('Terminal: compose thread cancelled');
      return;
    }

    final notifier = ref.read(terminalStateProvider.notifier);
    final voice = state.voice;
    notifier.appendOutput([
      TerminalOutputLine(voice.postingThread(), TerminalLineStyle.accent),
    ]);
    _scrollToBottom();

    try {
      final modNotifier = ref.read(nodeBoardModNotifierProvider.notifier);
      final author = _resolveAuthorIdentity(board.sysopName);
      await modNotifier.createThread(widget.slug, board.id, section.id, {
        'sectionId': section.id,
        'title': result.title,
        'body': result.body,
        'authorDisplayName': author.displayName,
        if (author.nodeId != null) 'authorNodeId': author.nodeId,
      }, ownerNodeId: board.ownerNodeId);
      AppLogging.nodeBoard('Terminal: compose thread ✅ posted');
      if (!mounted) return;
      notifier.appendOutput([
        TerminalOutputLine(voice.postedThread(), TerminalLineStyle.system),
      ]);
      // Force reload of the thread list on this section.
      _lastRenderedSectionId = null;
      _scrollToBottom();
    } catch (e) {
      AppLogging.nodeBoard('Terminal: compose thread ❌ $e');
      if (!mounted) return;
      // lint-allow: hardcoded-string
      notifier.renderError(voice.failedTo('POST THREAD', e));
      showErrorSnackBar(context, voice.failedTo('POST THREAD', e));
      _scrollToBottom();
    }
  }

  Future<void> _handleComposeReply() async {
    AppLogging.nodeBoard('Terminal: compose reply start');
    final state = ref.read(terminalStateProvider);
    final boardAsync = ref.read(nodeBoardDetailProvider(widget.slug));
    final board = boardAsync.value;
    if (board == null || state.currentThreadId == null) {
      ref
          .read(terminalStateProvider.notifier)
          // lint-allow: hardcoded-string
          .renderError(state.voice.missingContext('THREAD'));
      _scrollToBottom();
      return;
    }
    final threadId = state.currentThreadId!;
    final detailKey = ThreadDetailKey(slug: widget.slug, threadId: threadId);
    final detail = ref.read(nodeBoardThreadDetailProvider(detailKey)).value;
    final threadTitle =
        detail?.thread.title ?? 'thread'; // lint-allow: hardcoded-string

    final result = await pushNodeBoardComposeScreen(
      context: context,
      kind: NodeBoardComposeKind.reply,
      sectionTitle: threadTitle,
    );
    if (!mounted) return;
    if (result == null) {
      AppLogging.nodeBoard('Terminal: compose reply cancelled');
      return;
    }

    final notifier = ref.read(terminalStateProvider.notifier);
    final voice = state.voice;
    notifier.appendOutput([
      TerminalOutputLine(voice.postingReply(), TerminalLineStyle.accent),
    ]);
    _scrollToBottom();

    try {
      final modNotifier = ref.read(nodeBoardModNotifierProvider.notifier);
      final listKey = state.currentSectionId == null
          ? null
          : ThreadListKey(
              slug: widget.slug,
              boardId: board.id,
              sectionId: state.currentSectionId!,
            );
      final author = _resolveAuthorIdentity(board.sysopName);
      await modNotifier.createReply(
        detailKey,
        {
          'body': result.body,
          'authorDisplayName': author.displayName,
          if (author.nodeId != null) 'authorNodeId': author.nodeId,
        },
        listKey: listKey,
        ownerNodeId: board.ownerNodeId,
      );
      AppLogging.nodeBoard('Terminal: compose reply ✅ posted');
      if (!mounted) return;
      notifier.appendOutput([
        TerminalOutputLine(voice.postedReply(), TerminalLineStyle.system),
      ]);
      // Re-render thread with fresh replies.
      _lastRenderedThreadId = null;
      _scrollToBottom();
    } catch (e) {
      AppLogging.nodeBoard('Terminal: compose reply ❌ $e');
      if (!mounted) return;
      // lint-allow: hardcoded-string
      notifier.renderError(voice.failedTo('POST REPLY', e));
      showErrorSnackBar(
        context,
        voice.failedTo('POST REPLY', e),
      ); // lint-allow: hardcoded-string
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final terminalState = ref.watch(terminalStateProvider);
    final boardAsync = ref.watch(nodeBoardDetailProvider(widget.slug));
    final board = boardAsync.value;
    final preset = TerminalPreset.fromId(board?.themeId);

    // Apply tone + seed the moment the board resolves. Every render
    // method reads tone/seed off state.voice, so this must run before
    // the welcome ritual so the first line speaks in the right voice.
    if (board != null) {
      final resolvedTone = BoardTone.fromThemeId(board.themeId);
      ref
          .read(terminalStateProvider.notifier)
          .applyTone(resolvedTone, board.id.hashCode);
    }

    // Entry ritual (once per board load). Runs a staggered 3-beat
    // connection sequence — skippable in the sense that input + chip
    // taps never block during the ~300ms total delay.
    if (board != null && !_welcomeShown) {
      _welcomeShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final myNodeNum = ref.read(myNodeNumProvider);
        final nodeHex = myNodeNum != null
            ? '!${myNodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}'
            : (board.ownerNodeId ??
                  // lint-allow: hardcoded-string
                  '!UNKNOWN');
        ref
            .read(terminalStateProvider.notifier)
            .renderWelcome(
              boardTitle: board.title,
              sysopName: board.sysopName,
              nodeHex: nodeHex,
              lastActivityAt: board.lastActivityAt,
            );
        _scrollToBottom();
      });
    }

    // React to screen-state transitions by fetching real data. OPEN and
    // GUESTBOOK resolution happens synchronously in _onCommand via the
    // typed TerminalEffect path — there is no state-polling side channel
    // here.
    _maybeRenderSections(terminalState);
    _maybeRenderThreads(terminalState);
    _maybeRenderThreadDetail(terminalState);

    return GlassScaffold.body(
      title: board?.title ?? 'Terminal', // lint-allow: hardcoded-string
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop();
        },
      ),
      actions: [
        IconButton(
          tooltip: 'Native mode', // lint-allow: hardcoded-string
          icon: const Icon(Icons.dashboard_outlined),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
        ),
      ],
      hasScrollBody: false,
      body: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          FocusScope.of(context).unfocus();
        },
        child: Column(
          children: [
            if (board != null) ...[
              const SizedBox(height: AppTheme.spacing4),
              TerminalBoardHeader(
                boardTitle: board.title,
                sysopName: board.sysopName,
                tagline: board.tagline,
              ),
              if (board.ansiSplash != null && board.ansiSplash!.isNotEmpty)
                TerminalSplashView(splash: board.ansiSplash!),
            ],
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(
                  top: AppTheme.spacing8,
                  bottom: AppTheme.spacing8,
                ),
                itemCount: terminalState.outputBuffer.length,
                itemBuilder: (context, index) => TerminalOutputLineWidget(
                  line: terminalState.outputBuffer[index],
                  onTapCommand: _onCommand,
                ),
              ),
            ),
            TerminalChipBar(
              chips: terminalState.chips,
              onTapCommand: _onCommand,
            ),
            TerminalCommandInput(
              onSubmit: _onCommand,
              promptGlyph: preset.promptGlyph,
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Data coordination: load real data when the terminal's screen state
  // transitions into one that needs it, then hand it to the notifier
  // for rendering.
  // ------------------------------------------------------------------

  void _maybeRenderSections(TerminalState state) {
    // Reset "listed" marker when we leave the section list.
    if (state.currentScreen != TerminalScreen.sectionList) {
      if (_lastRenderedSectionId == '__listed__') {
        _lastRenderedSectionId = null;
      }
      return;
    }
    if (_lastRenderedSectionId == '__listed__') return;

    final sectionsAsync = ref.watch(nodeBoardSectionsProvider(widget.slug));
    sectionsAsync.whenData((sections) {
      if (_lastRenderedSectionId == '__listed__') return;
      _lastRenderedSectionId = '__listed__';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(terminalStateProvider.notifier).renderSections(sections);
        _scrollToBottom();
      });
    });
  }

  void _maybeRenderThreads(TerminalState state) {
    final boardAsync = ref.watch(nodeBoardDetailProvider(widget.slug));
    final board = boardAsync.value;
    if (board == null) return;
    final sectionId = state.currentSectionId;
    if (state.currentScreen != TerminalScreen.threadList) return;
    if (sectionId == null) return;
    if (_lastRenderedSectionId == sectionId) return;

    final sectionsAsync = ref.watch(nodeBoardSectionsProvider(widget.slug));
    final sections = sectionsAsync.value ?? const [];
    final section = sections.firstWhere(
      (s) => s.id == sectionId,
      orElse: () => sections.firstWhere(
        (s) => s.key == state.currentSectionKey,
        orElse: () => sections.isEmpty
            ? NodeBoardSection(
                id: sectionId,
                nodeBoardId: board.id,
                key: state.currentSectionKey ?? '',
                title: state.currentSectionKey ?? '',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              )
            : sections.first,
      ),
    );

    final threadsAsync = ref.watch(
      nodeBoardThreadListProvider(
        ThreadListKey(
          slug: widget.slug,
          boardId: board.id,
          sectionId: section.id,
        ),
      ),
    );
    // `whenData` fires with stale cached values during a refetch (after an
    // invalidation following a mutation). Skip rendering until the fresh
    // result has arrived so posting a thread doesn't render "0 threads"
    // from the pre-mutation cache.
    if (threadsAsync.isLoading || !threadsAsync.hasValue) return;
    final threads = threadsAsync.value!;
    if (_lastRenderedSectionId == sectionId) return;
    _lastRenderedSectionId = sectionId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(terminalStateProvider.notifier).renderThreads(section, threads);
      _scrollToBottom();
    });
  }

  void _maybeRenderThreadDetail(TerminalState state) {
    final threadId = state.currentThreadId;
    if (state.currentScreen != TerminalScreen.threadView) return;
    if (threadId == null) return;
    if (_lastRenderedThreadId == threadId) return;

    final detailAsync = ref.watch(
      nodeBoardThreadDetailProvider(
        ThreadDetailKey(slug: widget.slug, threadId: threadId),
      ),
    );
    // Skip stale refetch values — only render fresh data. See the matching
    // comment in `_maybeRenderThreads` for why `whenData` alone is unsafe
    // after a mutation-driven invalidation.
    if (detailAsync.isLoading || !detailAsync.hasValue) return;
    final detail = detailAsync.value;
    if (detail == null) return;
    if (_lastRenderedThreadId == threadId) return;
    _lastRenderedThreadId = threadId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(terminalStateProvider.notifier)
          .renderThread(detail.thread, detail.replies);
      _scrollToBottom();
    });
  }
}
