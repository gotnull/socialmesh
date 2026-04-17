// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Riverpod providers for the NodeBoard feature.
// Single file matching the nodedex_providers.dart convention.
// Uses Riverpod 3.x: Notifier, AsyncNotifier, FutureProvider, Provider.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../providers/auth_providers.dart';
import '../models/nodeboard.dart';
import '../models/nodeboard_enums.dart';
import '../models/nodeboard_reply.dart';
import '../models/nodeboard_section.dart';
import '../models/nodeboard_summary.dart';
import '../models/nodeboard_theme.dart';
import '../models/nodeboard_thread.dart';
import '../services/nodeboard_api_service.dart';
import '../services/nodeboard_voice.dart';
import '../services/nodeboard_cache_service.dart';
import '../services/nodeboard_repository.dart';
import '../services/terminal_command_parser.dart';

// ==========================================================================
// Infrastructure providers
// ==========================================================================

final nodeBoardApiServiceProvider = Provider<NodeBoardApiService>((ref) {
  final authService = ref.watch(authServiceProvider);
  AppLogging.nodeBoard('Provider: API service created');
  return NodeBoardApiService(getIdToken: () => authService.getIdToken());
});

final nodeBoardCacheProvider = FutureProvider<NodeBoardCacheService>((
  ref,
) async {
  final cache = NodeBoardCacheService();
  await cache.init();
  ref.onDispose(() => cache.close());
  AppLogging.nodeBoard('Provider: cache initialized');
  return cache;
});

final nodeBoardRepositoryProvider = FutureProvider<NodeBoardRepository>((
  ref,
) async {
  final api = ref.watch(nodeBoardApiServiceProvider);
  final cache = await ref.watch(nodeBoardCacheProvider.future);
  AppLogging.nodeBoard('Provider: repository ready');
  return NodeBoardRepository(api: api, cache: cache);
});

// ==========================================================================
// Read providers — board lists
// ==========================================================================

final myNodeBoardsProvider = FutureProvider<List<NodeBoardSummary>>((
  ref,
) async {
  final repo = await ref.watch(nodeBoardRepositoryProvider.future);
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    AppLogging.nodeBoard('Provider myNodeBoards: no user, returning []');
    return [];
  }
  AppLogging.nodeBoard('Provider myNodeBoards: fetching for user=${user.uid}');
  final boards = await repo.getMyBoards(user.uid);
  AppLogging.nodeBoard('Provider myNodeBoards: ✅ ${boards.length} boards');
  return boards;
});

final discoverNodeBoardsProvider = FutureProvider<List<NodeBoardSummary>>((
  ref,
) async {
  AppLogging.nodeBoard('Provider discoverNodeBoards: fetching');
  final repo = await ref.watch(nodeBoardRepositoryProvider.future);
  final result = await repo.discoverBoards();
  AppLogging.nodeBoard(
    'Provider discoverNodeBoards: ✅ ${result.boards.length} boards',
  );
  return result.boards;
});

// ==========================================================================
// Read providers — board detail (FutureProvider.family by slug)
// ==========================================================================

final nodeBoardDetailProvider = FutureProvider.family<NodeBoard?, String>((
  ref,
  slug,
) async {
  AppLogging.nodeBoard('Provider detail: loading slug=$slug');
  final repo = await ref.watch(nodeBoardRepositoryProvider.future);
  return repo.getBoardBySlug(slug);
});

// ==========================================================================
// Read providers — sections (FutureProvider.family by slug)
// ==========================================================================

final nodeBoardSectionsProvider =
    FutureProvider.family<List<NodeBoardSection>, String>((ref, slug) async {
      AppLogging.nodeBoard('Provider sections: loading slug=$slug');
      final repo = await ref.watch(nodeBoardRepositoryProvider.future);
      return repo.getSections(slug);
    });

// ==========================================================================
// Read providers — threads
// Typed record key: safe from delimiter injection in slug/id fields.
// ==========================================================================

class ThreadListKey {
  final String slug;
  final String boardId;
  final String sectionId;

  const ThreadListKey({
    required this.slug,
    required this.boardId,
    required this.sectionId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThreadListKey &&
          slug == other.slug &&
          boardId == other.boardId &&
          sectionId == other.sectionId;

  @override
  int get hashCode => Object.hash(slug, boardId, sectionId);

  @override
  String toString() =>
      'ThreadListKey(slug=$slug, boardId=$boardId, sectionId=$sectionId)';
}

final nodeBoardThreadListProvider =
    FutureProvider.family<List<NodeBoardThread>, ThreadListKey>((
      ref,
      key,
    ) async {
      AppLogging.nodeBoard('Provider threads: loading $key');
      final repo = await ref.watch(nodeBoardRepositoryProvider.future);
      final result = await repo.getThreads(
        key.slug,
        key.boardId,
        key.sectionId,
      );
      AppLogging.nodeBoard(
        'Provider threads: ✅ ${result.threads.length} threads for $key',
      );
      return result.threads;
    });

// ==========================================================================
// Read providers — thread detail + replies
// Typed record key.
// ==========================================================================

class ThreadDetailKey {
  final String slug;
  final String threadId;

  const ThreadDetailKey({required this.slug, required this.threadId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThreadDetailKey &&
          slug == other.slug &&
          threadId == other.threadId;

  @override
  int get hashCode => Object.hash(slug, threadId);

  @override
  String toString() => 'ThreadDetailKey(slug=$slug, threadId=$threadId)';
}

class ThreadDetailData {
  final NodeBoardThread thread;
  final List<NodeBoardReply> replies;

  const ThreadDetailData({required this.thread, required this.replies});
}

final nodeBoardThreadDetailProvider =
    FutureProvider.family<ThreadDetailData?, ThreadDetailKey>((ref, key) async {
      AppLogging.nodeBoard('Provider threadDetail: loading $key');
      final repo = await ref.watch(nodeBoardRepositoryProvider.future);
      final result = await repo.getThreadDetail(key.slug, key.threadId);
      AppLogging.nodeBoard(
        'Provider threadDetail: ✅ ${result.replies.length} replies',
      );
      return ThreadDetailData(thread: result.thread, replies: result.replies);
    });

// ==========================================================================
// Read providers — themes
// ==========================================================================

final nodeBoardThemesProvider = FutureProvider<List<NodeBoardTheme>>((
  ref,
) async {
  AppLogging.nodeBoard('Provider themes: loading');
  final repo = await ref.watch(nodeBoardRepositoryProvider.future);
  final themes = await repo.getThemes();
  AppLogging.nodeBoard('Provider themes: ✅ ${themes.length} themes');
  return themes;
});

// ==========================================================================
// NodeDex bridge — board summary for a node ID
//
// autoDispose: every NodeDex detail visit re-fetches instead of trusting
// a stale `null` from an earlier fetch (before the user linked their
// board). The backend lookup is cheap and the freshness matters more
// than caching a negative result.
// ==========================================================================

final nodeBoardSummaryForNodeProvider = FutureProvider.autoDispose
    .family<NodeBoardSummary?, String>((ref, nodeId) async {
      AppLogging.nodeBoard('Provider summaryForNode: nodeId=$nodeId');
      final repo = await ref.watch(nodeBoardRepositoryProvider.future);
      return repo.getBoardSummaryByNodeId(nodeId);
    });

// ==========================================================================
// Mutation provider — create board
// ==========================================================================

final nodeBoardCreateNotifierProvider =
    AsyncNotifierProvider<NodeBoardCreateNotifier, void>(
      NodeBoardCreateNotifier.new,
    );

class NodeBoardCreateNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<NodeBoard> createBoard({
    required String slug,
    required String title,
    required String sysopName,
    String? tagline,
    String? description,
    BoardVisibility? visibility,
    String? themeId,
    String? welcomeText,
    String? ansiSplash,
    bool? isListedInNodeDex,
    bool? isGuestPostingAllowed,
    String? ownerNodeId,
    List<Map<String, String>>? defaultSections,
  }) async {
    AppLogging.nodeBoard('Create: starting slug=$slug title=$title');
    state = const AsyncValue.loading();
    final repo = await ref.read(nodeBoardRepositoryProvider.future);
    try {
      final board = await repo.createBoard(
        slug: slug,
        title: title,
        sysopName: sysopName,
        tagline: tagline,
        description: description,
        visibility: visibility,
        themeId: themeId,
        welcomeText: welcomeText,
        ansiSplash: ansiSplash,
        isListedInNodeDex: isListedInNodeDex,
        isGuestPostingAllowed: isGuestPostingAllowed,
        ownerNodeId: ownerNodeId,
        defaultSections: defaultSections,
      );

      AppLogging.nodeBoard('Create: ✅ board created id=${board.id}');
      // Invalidate list providers
      ref.invalidate(myNodeBoardsProvider);
      ref.invalidate(discoverNodeBoardsProvider);

      state = const AsyncValue.data(null);
      return board;
    } catch (e, st) {
      AppLogging.nodeBoard('Create: ❌ failed: $e');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

// ==========================================================================
// Mutation provider — moderation + writes
// ==========================================================================

final nodeBoardModNotifierProvider =
    AsyncNotifierProvider<NodeBoardModNotifier, void>(NodeBoardModNotifier.new);

class NodeBoardModNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Invalidates all read providers that touch a specific board.
  /// Used by mutations whose effect spans board detail, sections, threads,
  /// and both list surfaces (my boards + discover + NodeDex bridge).
  ///
  /// [ownerNodeIds] may contain one or more node hex IDs that should
  /// have their NodeDex bridge summary invalidated (pass both the old
  /// and new owner when linking changes so neither cache goes stale).
  void _invalidateBoardSurface(
    String slug, {
    List<String> ownerNodeIds = const [],
  }) {
    ref.invalidate(nodeBoardDetailProvider(slug));
    ref.invalidate(nodeBoardSectionsProvider(slug));
    ref.invalidate(myNodeBoardsProvider);
    ref.invalidate(discoverNodeBoardsProvider);
    for (final id in ownerNodeIds) {
      AppLogging.nodeBoard('Mod invalidate summaryForNode nodeId=$id');
      ref.invalidate(nodeBoardSummaryForNodeProvider(id));
    }
  }

  Future<void> updateBoard(
    String boardId,
    String slug,
    Map<String, dynamic> updates, {
    String? ownerNodeId,
    String? previousOwnerNodeId,
  }) async {
    AppLogging.nodeBoard(
      'Mod updateBoard: boardId=$boardId slug=$slug '
      'ownerNodeId=$ownerNodeId previousOwnerNodeId=$previousOwnerNodeId',
    );
    final repo = await ref.read(nodeBoardRepositoryProvider.future);
    await repo.updateBoard(boardId, updates);
    // Invalidate NodeDex summaries for BOTH the old and new owner so
    // that unlinking / relinking clears the stale cache on either side.
    final ids = <String>{
      if (ownerNodeId != null) ownerNodeId,
      if (previousOwnerNodeId != null) previousOwnerNodeId,
    }.toList();
    _invalidateBoardSurface(slug, ownerNodeIds: ids);
    AppLogging.nodeBoard('Mod updateBoard: ✅ invalidated board surface');
  }

  Future<void> pinThread(
    ThreadListKey listKey,
    ThreadDetailKey detailKey, {
    bool pin = true,
    String? ownerNodeId,
  }) async {
    AppLogging.nodeBoard('Mod pinThread: $listKey pin=$pin');
    final repo = await ref.read(nodeBoardRepositoryProvider.future);
    await repo.pinThread(listKey.boardId, detailKey.threadId, pin: pin);
    ref.invalidate(nodeBoardThreadListProvider(listKey));
    ref.invalidate(nodeBoardThreadDetailProvider(detailKey));
    ref.invalidate(nodeBoardDetailProvider(listKey.slug));
    if (ownerNodeId != null) {
      ref.invalidate(nodeBoardSummaryForNodeProvider(ownerNodeId));
    }
    AppLogging.nodeBoard(
      'Mod pinThread: ✅ invalidated thread + board surfaces',
    );
  }

  Future<void> lockThread(
    ThreadListKey listKey,
    ThreadDetailKey detailKey, {
    bool lock = true,
  }) async {
    AppLogging.nodeBoard('Mod lockThread: $detailKey lock=$lock');
    final repo = await ref.read(nodeBoardRepositoryProvider.future);
    await repo.lockThread(listKey.boardId, detailKey.threadId, lock: lock);
    ref.invalidate(nodeBoardThreadListProvider(listKey));
    ref.invalidate(nodeBoardThreadDetailProvider(detailKey));
    AppLogging.nodeBoard('Mod lockThread: ✅ invalidated thread list + detail');
  }

  Future<void> deleteThread(
    ThreadListKey listKey,
    ThreadDetailKey detailKey, {
    String? reason,
    String? ownerNodeId,
  }) async {
    AppLogging.nodeBoard('Mod deleteThread: $detailKey');
    final repo = await ref.read(nodeBoardRepositoryProvider.future);
    await repo.deleteThread(
      listKey.boardId,
      detailKey.threadId,
      reason: reason,
    );
    // Stats (threadCount, replyCount) change on board; invalidate the
    // full board surface so summaries reflect decrement.
    ref.invalidate(nodeBoardThreadListProvider(listKey));
    ref.invalidate(nodeBoardThreadDetailProvider(detailKey));
    _invalidateBoardSurface(
      listKey.slug,
      ownerNodeIds: ownerNodeId == null ? const [] : [ownerNodeId],
    );
    AppLogging.nodeBoard('Mod deleteThread: ✅ invalidated board surface');
  }

  Future<void> deleteReply(
    String boardId,
    String replyId,
    ThreadDetailKey detailKey, {
    String? reason,
    String? ownerNodeId,
  }) async {
    AppLogging.nodeBoard('Mod deleteReply: $detailKey replyId=$replyId');
    final repo = await ref.read(nodeBoardRepositoryProvider.future);
    await repo.deleteReply(boardId, replyId, reason: reason);
    ref.invalidate(nodeBoardThreadDetailProvider(detailKey));
    // replyCount + lastActivityAt change on board summary.
    ref.invalidate(nodeBoardDetailProvider(detailKey.slug));
    ref.invalidate(myNodeBoardsProvider);
    if (ownerNodeId != null) {
      ref.invalidate(nodeBoardSummaryForNodeProvider(ownerNodeId));
    }
    AppLogging.nodeBoard('Mod deleteReply: ✅ invalidated thread + board');
  }

  Future<void> lockSection(
    String slug,
    String boardId,
    String sectionId, {
    bool lock = true,
  }) async {
    AppLogging.nodeBoard(
      'Mod lockSection: boardId=$boardId sectionId=$sectionId lock=$lock',
    );
    final repo = await ref.read(nodeBoardRepositoryProvider.future);
    await repo.lockSection(boardId, sectionId, lock: lock);
    ref.invalidate(nodeBoardSectionsProvider(slug));
    ref.invalidate(
      nodeBoardThreadListProvider(
        ThreadListKey(slug: slug, boardId: boardId, sectionId: sectionId),
      ),
    );
    AppLogging.nodeBoard('Mod lockSection: ✅ invalidated section + threads');
  }

  Future<NodeBoardThread> createThread(
    String slug,
    String boardId,
    String sectionId,
    Map<String, dynamic> input, {
    String? ownerNodeId,
  }) async {
    AppLogging.nodeBoard('Mod createThread: slug=$slug sectionId=$sectionId');
    final repo = await ref.read(nodeBoardRepositoryProvider.future);
    final thread = await repo.createThread(slug, input);
    AppLogging.nodeBoard('Mod createThread: ✅ id=${thread.id}');
    // Full board surface: threadCount + lastActivityAt change, and the
    // section's thread list needs the new thread appended.
    ref.invalidate(
      nodeBoardThreadListProvider(
        ThreadListKey(slug: slug, boardId: boardId, sectionId: sectionId),
      ),
    );
    _invalidateBoardSurface(
      slug,
      ownerNodeIds: ownerNodeId == null ? const [] : [ownerNodeId],
    );
    return thread;
  }

  Future<NodeBoardReply> createReply(
    ThreadDetailKey detailKey,
    Map<String, dynamic> input, {
    ThreadListKey? listKey,
    String? ownerNodeId,
  }) async {
    AppLogging.nodeBoard('Mod createReply: $detailKey');
    final repo = await ref.read(nodeBoardRepositoryProvider.future);
    final reply = await repo.createReply(
      detailKey.slug,
      detailKey.threadId,
      input,
    );
    AppLogging.nodeBoard('Mod createReply: ✅ id=${reply.id}');
    // replyCount + lastReplyAt change on thread and board; if listKey is
    // known, invalidate the section's thread list too so previews update.
    ref.invalidate(nodeBoardThreadDetailProvider(detailKey));
    if (listKey != null) {
      ref.invalidate(nodeBoardThreadListProvider(listKey));
    }
    ref.invalidate(nodeBoardDetailProvider(detailKey.slug));
    ref.invalidate(myNodeBoardsProvider);
    if (ownerNodeId != null) {
      ref.invalidate(nodeBoardSummaryForNodeProvider(ownerNodeId));
    }
    return reply;
  }
}

// ==========================================================================
// Terminal mode providers
// ==========================================================================

enum TerminalLineStyle { normal, header, accent, dim, error, system }

/// A line in the terminal output buffer. When [tapCommand] is non-null the
/// line is rendered as tappable, and tapping it executes that command
/// (e.g. `OPEN 1`). [index] is the optional display number used for the
/// `[n] Label` prefix on listable lines.
class TerminalOutputLine {
  final String text;
  final TerminalLineStyle style;
  final String? tapCommand;
  final int? index;

  const TerminalOutputLine(this.text, [this.style = TerminalLineStyle.normal])
    : tapCommand = null,
      index = null;

  const TerminalOutputLine.tappable({
    required this.text,
    required this.tapCommand,
    this.index,
    this.style = TerminalLineStyle.normal,
  });

  /// Return a copy with `tapCommand` stripped. Used to freeze older
  /// tappable lines when the screen changes so their `OPEN n` commands
  /// don't mis-dispatch against the new list context.
  TerminalOutputLine withoutTapCommand() {
    if (tapCommand == null) return this;
    return TerminalOutputLine(text, style);
  }
}

/// A context-aware chip action rendered above the command input bar.
/// Tapping a chip executes its command string through the same pipeline
/// as typed input — there is no hidden shortcut path.
class TerminalChipAction {
  final String label;
  final String command;
  final IconData? icon;

  const TerminalChipAction({
    required this.label,
    required this.command,
    this.icon,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TerminalChipAction &&
          label == other.label &&
          command == other.command;

  @override
  int get hashCode => Object.hash(label, command);
}

class TerminalState {
  final List<TerminalScreen> screenStack;
  final List<TerminalOutputLine> outputBuffer;
  final List<TerminalChipAction> chips;
  final String? currentSectionId;
  final String? currentSectionKey;
  final String? currentThreadId;
  final BoardTone tone;
  final int toneSeed;

  const TerminalState({
    this.screenStack = const [TerminalScreen.boardHome],
    this.outputBuffer = const [],
    this.chips = const [],
    this.currentSectionId,
    this.currentSectionKey,
    this.currentThreadId,
    this.tone = BoardTone.neutral,
    this.toneSeed = 0,
  });

  TerminalScreen get currentScreen =>
      screenStack.isNotEmpty ? screenStack.last : TerminalScreen.boardHome;

  NodeBoardVoice get voice => NodeBoardVoice(tone: tone, seed: toneSeed);

  TerminalState copyWith({
    List<TerminalScreen>? screenStack,
    List<TerminalOutputLine>? outputBuffer,
    List<TerminalChipAction>? chips,
    String? currentSectionId,
    String? currentSectionKey,
    String? currentThreadId,
    BoardTone? tone,
    int? toneSeed,
    bool clearSection = false,
    bool clearThread = false,
  }) => TerminalState(
    screenStack: screenStack ?? this.screenStack,
    outputBuffer: outputBuffer ?? this.outputBuffer,
    chips: chips ?? this.chips,
    currentSectionId: clearSection
        ? null
        : (currentSectionId ?? this.currentSectionId),
    currentSectionKey: clearSection
        ? null
        : (currentSectionKey ?? this.currentSectionKey),
    currentThreadId: clearThread
        ? null
        : (currentThreadId ?? this.currentThreadId),
    tone: tone ?? this.tone,
    toneSeed: toneSeed ?? this.toneSeed,
  );
}

/// Typed, transient result of executing a terminal command. The state
/// notifier never uses side-channels (error strings, status flags) to
/// signal actions — every command resolution either mutates state via
/// explicit methods or returns one of these effect variants for the
/// screen to handle. Effects carry the data the screen needs (like an
/// OPEN index) directly rather than encoding it in another field.
sealed class TerminalEffect {
  const TerminalEffect();
}

/// No action required beyond the state mutations executeCommand already
/// performed (e.g. HELP appended lines, BACK popped the stack).
class NoEffect extends TerminalEffect {
  const NoEffect();
}

/// User requested `OPEN <index>`. The screen owns the current list of
/// sections or threads and resolves the index against whichever screen
/// is active.
class OpenIndexEffect extends TerminalEffect {
  final int index;
  const OpenIndexEffect(this.index);
}

/// User requested the board's guestbook section. The screen resolves
/// the section by key.
class OpenGuestbookEffect extends TerminalEffect {
  const OpenGuestbookEffect();
}

/// User requested POST (new thread) inside the current section.
/// Screen launches the in-terminal composer.
class ComposeThreadEffect extends TerminalEffect {
  const ComposeThreadEffect();
}

/// User requested REPLY to the current thread.
class ComposeReplyEffect extends TerminalEffect {
  const ComposeReplyEffect();
}

/// User requested QUIT. The screen pops the navigator.
class QuitEffect extends TerminalEffect {
  const QuitEffect();
}

/// Hybrid terminal: command parser + context-aware chips + tappable
/// output + data-driven screens. The notifier is the single source of
/// truth for the output buffer, screen stack, and chip list. The screen
/// feeds real data into it via renderSections / renderThreads / etc.
class TerminalStateNotifier extends Notifier<TerminalState> {
  @override
  TerminalState build() {
    final initial = const TerminalState();
    return initial.copyWith(chips: _chipsForScreen(initial));
  }

  // --------------------------------------------------------------------
  // Public control surface
  // --------------------------------------------------------------------

  void appendOutput(List<TerminalOutputLine> lines) {
    state = state.copyWith(outputBuffer: [...state.outputBuffer, ...lines]);
  }

  void clearOutput() {
    state = state.copyWith(outputBuffer: const []);
  }

  /// Strip `tapCommand` from every line currently in the output buffer.
  /// Called at screen transitions and whenever a new tappable list is
  /// rendered so that stale `OPEN n` commands from earlier screens can't
  /// dispatch against the new list context (they become display-only
  /// history).
  void _freezePriorTaps() {
    final frozen = state.outputBuffer
        .map((line) => line.withoutTapCommand())
        .toList(growable: false);
    state = state.copyWith(outputBuffer: frozen);
  }

  void pushScreen(TerminalScreen screen) {
    _freezePriorTaps();
    final next = state.copyWith(screenStack: [...state.screenStack, screen]);
    state = next.copyWith(chips: _chipsForScreen(next));
  }

  void popScreen() {
    if (state.screenStack.length <= 1) return;
    _freezePriorTaps();
    final popped = state.screenStack.last;
    final newStack = state.screenStack.sublist(0, state.screenStack.length - 1);
    // Clear the context appropriate to what we left behind so OPEN
    // indices from the outer list don't mis-dispatch.
    final next = switch (popped) {
      TerminalScreen.threadView => state.copyWith(
        screenStack: newStack,
        clearThread: true,
      ),
      TerminalScreen.threadList => state.copyWith(
        screenStack: newStack,
        clearSection: true,
        clearThread: true,
      ),
      _ => state.copyWith(screenStack: newStack),
    };
    state = next.copyWith(chips: _chipsForScreen(next));
  }

  /// Apply a [BoardTone] + per-board seed to this state. Called by the
  /// terminal screen once the board detail loads — before any render.
  /// Silently no-ops when the tone + seed haven't changed so the voice
  /// stays stable across rebuilds.
  void applyTone(BoardTone tone, int seed) {
    if (tone == state.tone && seed == state.toneSeed) return;
    AppLogging.nodeBoard('Voice: applyTone | tone=$tone seed=$seed');
    state = state.copyWith(tone: tone, toneSeed: seed);
  }

  /// Render the entry ritual — the connection sequence + welcome tagline
  /// + optional activity line, phrased by the current [BoardTone].
  ///
  /// Lines are emitted in three small batches with short delays so the
  /// terminal feels like it's speaking, not dumping. The delays are tiny
  /// (~300ms total), never block input, and are idempotent: once the
  /// output buffer has content we bail.
  Future<void> renderWelcome({
    required String boardTitle,
    required String sysopName,
    required String nodeHex,
    DateTime? lastActivityAt,
  }) async {
    if (state.outputBuffer.isNotEmpty) return;
    AppLogging.nodeBoard(
      'Terminal: entry ritual start | board=$boardTitle tone=${state.tone}',
    );
    final v = state.voice;
    final handshake = v.handshake(nodeHex: nodeHex, sysop: sysopName);

    // Beat 1 — dialing / scanning / initializing.
    appendOutput([TerminalOutputLine(handshake[0], TerminalLineStyle.dim)]);
    await Future.delayed(const Duration(milliseconds: 120));

    // Beat 2 — connected, identity.
    if (state.outputBuffer.isEmpty) return; // disposed mid-sequence
    appendOutput([
      TerminalOutputLine(handshake[1], TerminalLineStyle.accent),
      TerminalOutputLine(handshake[2], TerminalLineStyle.normal),
      TerminalOutputLine(handshake[3], TerminalLineStyle.normal),
      const TerminalOutputLine(''),
    ]);
    await Future.delayed(const Duration(milliseconds: 90));

    // Beat 3 — welcome, activity, hint.
    if (state.outputBuffer.isEmpty) return;
    final lines = <TerminalOutputLine>[
      TerminalOutputLine(boardTitle, TerminalLineStyle.header),
    ];
    if (lastActivityAt != null) {
      final rel = formatNodeBoardRelativeTime(lastActivityAt);
      final activityLine = '${v.activityLabel}: ${rel.toUpperCase()}';
      lines.add(TerminalOutputLine(activityLine, TerminalLineStyle.dim));
      AppLogging.nodeBoard('Terminal: activity line rendered | relative=$rel');
    }
    lines.add(const TerminalOutputLine(''));
    lines.add(TerminalOutputLine(v.welcomeHint(), TerminalLineStyle.dim));
    lines.add(const TerminalOutputLine(''));
    appendOutput(lines);
    AppLogging.nodeBoard('Terminal: entry ritual complete');
  }

  /// Render a list of sections as a tappable numbered list. The screen
  /// calls this in response to the SECTIONS command once section data
  /// loads.
  void renderSections(List<NodeBoardSection> sections) {
    AppLogging.nodeBoard('Terminal: renderSections count=${sections.length}');
    _freezePriorTaps();
    final lines = <TerminalOutputLine>[
      const TerminalOutputLine('Sections:', TerminalLineStyle.header),
    ];
    for (var i = 0; i < sections.length; i++) {
      final s = sections[i];
      lines.add(
        TerminalOutputLine.tappable(
          text: s.title,
          index: i + 1,
          tapCommand: 'OPEN ${i + 1}',
        ),
      );
    }
    lines.add(const TerminalOutputLine(''));
    appendOutput(lines);
    // Navigation already happened via `pushScreen(sectionList)` in the
    // command dispatcher; this method only renders output and refreshes
    // the chip bar for the current screen.
    state = state.copyWith(chips: _chipsForSectionList(sections.length));
  }

  /// Render a list of threads inside a section. Tapping an index runs
  /// `OPEN n` — handled by the screen via openThreadByIndex().
  void renderThreads(NodeBoardSection section, List<NodeBoardThread> threads) {
    AppLogging.nodeBoard(
      'Terminal: renderThreads section=${section.key} count=${threads.length}',
    );
    _freezePriorTaps();
    final lines = <TerminalOutputLine>[
      TerminalOutputLine(
        'Threads in ${section.title}:',
        TerminalLineStyle.header,
      ),
    ];
    if (threads.isEmpty) {
      AppLogging.nodeBoard('Voice: empty threads inline | tone=${state.tone}');
      lines.add(
        TerminalOutputLine(
          state.voice.emptyThreadsInline(),
          TerminalLineStyle.dim,
        ),
      );
    } else {
      for (var i = 0; i < threads.length; i++) {
        final t = threads[i];
        final prefix = t.isPinned ? '📌 ' : '';
        lines.add(
          TerminalOutputLine.tappable(
            text: '$prefix${t.title}  (${t.replyCount} replies)',
            index: i + 1,
            tapCommand: 'OPEN ${i + 1}',
          ),
        );
      }
    }
    lines.add(const TerminalOutputLine(''));
    appendOutput(lines);
    // Navigation already happened via `openSection` (OPEN dispatch). Only
    // keep the section context fresh and update the chip bar.
    state = state.copyWith(
      currentSectionId: section.id,
      currentSectionKey: section.key,
      chips: _chipsForThreadList(threads.length),
    );
  }

  /// Render a thread and its replies inline.
  void renderThread(NodeBoardThread thread, List<NodeBoardReply> replies) {
    AppLogging.nodeBoard(
      'Terminal: renderThread threadId=${thread.id} replies=${replies.length}',
    );
    _freezePriorTaps();
    final lines = <TerminalOutputLine>[
      TerminalOutputLine(thread.title, TerminalLineStyle.header),
      TerminalOutputLine(
        '— ${thread.authorDisplayName}',
        TerminalLineStyle.accent,
      ),
      const TerminalOutputLine(''),
      TerminalOutputLine(thread.body),
      const TerminalOutputLine(''),
      TerminalOutputLine('Replies (${replies.length}):', TerminalLineStyle.dim),
    ];
    if (replies.isEmpty) {
      AppLogging.nodeBoard('Voice: empty replies inline | tone=${state.tone}');
      lines.add(
        TerminalOutputLine(
          '  ${state.voice.emptyRepliesInline()}',
          TerminalLineStyle.dim,
        ),
      );
    } else {
      for (final r in replies) {
        lines.add(
          TerminalOutputLine(
            '${r.authorDisplayName}:',
            TerminalLineStyle.accent,
          ),
        );
        lines.add(TerminalOutputLine('  ${r.body}'));
      }
    }
    lines.add(const TerminalOutputLine(''));
    appendOutput(lines);
    // Navigation already happened via `openThread` (OPEN dispatch). Only
    // keep the thread context fresh and update the chip bar.
    state = state.copyWith(
      currentThreadId: thread.id,
      chips: _chipsForThreadView(),
    );
  }

  /// Render a user-facing error line in the output buffer. `renderError`
  /// is purely a display concern — it never carries control data. If a
  /// command needs to signal an action, it emits a [TerminalEffect]
  /// instead.
  void renderError(String message) {
    AppLogging.nodeBoard(
      'Voice: error rendered | tone=${state.tone} text="$message"',
    );
    appendOutput([TerminalOutputLine(message, TerminalLineStyle.error)]);
  }

  /// Transition into section list with a specific section selected and
  /// the screen stack advanced. Used by the screen when `OPEN n`
  /// resolves an index to a real section.
  void openSection({required String sectionId, required String sectionKey}) {
    _freezePriorTaps();
    final next = state.copyWith(
      currentSectionId: sectionId,
      currentSectionKey: sectionKey,
      screenStack: [...state.screenStack, TerminalScreen.threadList],
    );
    state = next.copyWith(chips: _chipsForThreadList(0));
  }

  /// Transition into thread view for a specific thread.
  void openThread(String threadId) {
    _freezePriorTaps();
    final next = state.copyWith(
      currentThreadId: threadId,
      screenStack: [...state.screenStack, TerminalScreen.threadView],
    );
    state = next.copyWith(chips: _chipsForThreadView());
  }

  // --------------------------------------------------------------------
  // Command execution
  // --------------------------------------------------------------------

  /// Execute a parsed command. Mutates state for anything the notifier
  /// owns (output buffer, screen stack, chips) and returns a typed
  /// [TerminalEffect] for anything the screen needs to resolve against
  /// external data (sections, threads, native handoffs, navigation).
  ///
  /// This is the single dispatch path. Typed input, chip taps, and
  /// tappable output rows all arrive here via `parseTerminalCommand` —
  /// there are no alternate shortcut paths.
  TerminalEffect executeCommand(ParsedCommand command) {
    AppLogging.nodeBoard(
      'Terminal exec | command=${command.command} args=${command.args}',
    );
    switch (command.command) {
      case TerminalCommand.help:
        _appendHelp();
        return const NoEffect();
      case TerminalCommand.back:
        popScreen();
        appendOutput([
          TerminalOutputLine(state.voice.back(), TerminalLineStyle.dim),
        ]);
        return const NoEffect();
      case TerminalCommand.sections:
        _appendAccent(state.voice.loadingSections());
        pushScreen(TerminalScreen.sectionList);
        return const NoEffect();
      case TerminalCommand.about:
        _appendAbout();
        return const NoEffect();
      case TerminalCommand.guestbook:
        _appendAccent(state.voice.openingGuestbook());
        AppLogging.nodeBoard('Terminal effect emitted | effect=openGuestbook');
        return const OpenGuestbookEffect();
      case TerminalCommand.list:
        // Context-aware: if already in a section the screen refreshes;
        // otherwise behave like SECTIONS.
        _appendAccent(state.voice.listing());
        if (state.currentSectionId == null) {
          pushScreen(TerminalScreen.sectionList);
        }
        return const NoEffect();
      case TerminalCommand.open:
        return _executeOpen(command);
      case TerminalCommand.post:
        if (state.currentSectionId == null) {
          // lint-allow: hardcoded-string
          renderError(state.voice.missingContext('SECTION'));
          return const NoEffect();
        }
        AppLogging.nodeBoard(
          'Terminal effect emitted | effect=composeThread sectionId=${state.currentSectionId}',
        );
        return const ComposeThreadEffect();
      case TerminalCommand.reply:
        if (state.currentThreadId == null) {
          // lint-allow: hardcoded-string
          renderError(state.voice.missingContext('THREAD'));
          return const NoEffect();
        }
        AppLogging.nodeBoard(
          'Terminal effect emitted | effect=composeReply threadId=${state.currentThreadId}',
        );
        return const ComposeReplyEffect();
      case TerminalCommand.quit:
        AppLogging.nodeBoard('Terminal effect emitted | effect=quit');
        return const QuitEffect();
      case TerminalCommand.unknown:
        final raw = command.args.isNotEmpty ? command.args[0] : '';
        final v = state.voice;
        appendOutput([
          TerminalOutputLine(v.unknownCommand(raw), TerminalLineStyle.error),
          TerminalOutputLine(v.unknownHint(), TerminalLineStyle.dim),
        ]);
        return const NoEffect();
    }
  }

  TerminalEffect _executeOpen(ParsedCommand command) {
    if (command.args.isEmpty) {
      // lint-allow: hardcoded-string
      renderError(state.voice.usageHint('OPEN <number>'));
      return const NoEffect();
    }
    final index = int.tryParse(command.args[0]);
    if (index == null || index < 1) {
      renderError(
        'INVALID INDEX: ${command.args[0]}',
      ); // lint-allow: hardcoded-string
      return const NoEffect();
    }
    AppLogging.nodeBoard(
      'Terminal effect emitted | effect=openIndex index=$index',
    );
    return OpenIndexEffect(index);
  }

  // --------------------------------------------------------------------
  // Static content builders
  // --------------------------------------------------------------------

  void _appendHelp() {
    appendOutput(const [
      TerminalOutputLine('Available commands:', TerminalLineStyle.header),
      TerminalOutputLine('  HELP         Show this help'),
      TerminalOutputLine('  SECTIONS     List board sections'),
      TerminalOutputLine('  LIST         Context-aware listing'),
      TerminalOutputLine('  OPEN <n>     Open item by number'),
      TerminalOutputLine('  ABOUT        Board info'),
      TerminalOutputLine('  GUESTBOOK    Open guestbook section'),
      TerminalOutputLine('  POST         Start a new thread'),
      TerminalOutputLine('  REPLY        Reply to current thread'),
      TerminalOutputLine('  BACK         Go back one screen'),
      TerminalOutputLine('  QUIT         Exit terminal mode'),
      TerminalOutputLine(''),
    ]);
  }

  void _appendAbout() {
    appendOutput(const [
      TerminalOutputLine('About this board:', TerminalLineStyle.header),
      TerminalOutputLine(
        'Tap chips below or type a command.',
        TerminalLineStyle.dim,
      ),
      TerminalOutputLine(''),
    ]);
  }

  void _appendAccent(String text) {
    appendOutput([TerminalOutputLine(text, TerminalLineStyle.accent)]);
  }

  // --------------------------------------------------------------------
  // Context-aware chip generation
  // --------------------------------------------------------------------

  static const _chipHelp = TerminalChipAction(
    label: 'HELP',
    command: 'HELP',
    icon: Icons.help_outline,
  );
  static const _chipBack = TerminalChipAction(
    label: 'BACK',
    command: 'BACK',
    icon: Icons.arrow_back,
  );
  static const _chipSections = TerminalChipAction(
    label: 'SECTIONS',
    command: 'SECTIONS',
    icon: Icons.view_list_outlined,
  );
  static const _chipAbout = TerminalChipAction(
    label: 'ABOUT',
    command: 'ABOUT',
    icon: Icons.info_outline,
  );
  static const _chipGuestbook = TerminalChipAction(
    label: 'GUESTBOOK',
    command: 'GUESTBOOK',
    icon: Icons.edit_note,
  );
  static const _chipPost = TerminalChipAction(
    label: 'POST',
    command: 'POST',
    icon: Icons.add_comment_outlined,
  );
  static const _chipReply = TerminalChipAction(
    label: 'REPLY',
    command: 'REPLY',
    icon: Icons.reply_outlined,
  );
  static const _chipQuit = TerminalChipAction(
    label: 'QUIT',
    command: 'QUIT',
    icon: Icons.close,
  );

  List<TerminalChipAction> _chipsForScreen(TerminalState s) {
    return switch (s.currentScreen) {
      TerminalScreen.boardHome => const [
        _chipSections,
        _chipGuestbook,
        _chipAbout,
        _chipHelp,
        _chipQuit,
      ],
      TerminalScreen.sectionList => const [_chipBack, _chipHelp],
      TerminalScreen.threadList => const [_chipBack, _chipPost, _chipHelp],
      TerminalScreen.threadView => const [_chipBack, _chipReply, _chipHelp],
      TerminalScreen.compose => const [_chipBack],
      TerminalScreen.splash => const [_chipHelp],
      TerminalScreen.help => const [_chipBack],
    };
  }

  List<TerminalChipAction> _chipsForSectionList(int count) {
    final chips = <TerminalChipAction>[_chipBack];
    for (var i = 1; i <= count && i <= 6; i++) {
      chips.add(
        TerminalChipAction(
          label: '[$i]',
          command: 'OPEN $i',
          icon: Icons.chevron_right,
        ),
      );
    }
    chips.add(_chipHelp);
    return chips;
  }

  List<TerminalChipAction> _chipsForThreadList(int count) {
    final chips = <TerminalChipAction>[_chipBack, _chipPost];
    for (var i = 1; i <= count && i <= 6; i++) {
      chips.add(
        TerminalChipAction(
          label: '[$i]',
          command: 'OPEN $i',
          icon: Icons.chevron_right,
        ),
      );
    }
    chips.add(_chipHelp);
    return chips;
  }

  List<TerminalChipAction> _chipsForThreadView() => const [
    _chipBack,
    _chipReply,
    _chipHelp,
  ];
}

final terminalStateProvider =
    NotifierProvider<TerminalStateNotifier, TerminalState>(
      TerminalStateNotifier.new,
    );
