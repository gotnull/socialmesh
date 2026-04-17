// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// NodeBoard personality layer — the system's voice.
//
// Every piece of user-facing text on a board (empty states, connection
// sequences, actions, errors, activity labels) flows through this
// service so a board feels like a place, not a settings screen. Phrase
// choice is deterministic per board so repeat visits feel consistent,
// but different boards speak with different voices based on their tone.

import '../../../core/logging.dart';

/// Board personality. Derived from the board's theme preset (or left at
/// [neutral] when no preset is selected). Drives phrasing for everything
/// the terminal and empty states render.
enum BoardTone {
  neutral,
  hacker,
  wasteland,
  corporate,
  chaotic,
  minimal;

  /// Map a NodeBoard theme id to a tone. Unknown / null ids fall back
  /// to [neutral] so a board without a preset is still coherent.
  static BoardTone fromThemeId(String? themeId) {
    final tone = switch (themeId) {
      'classic_green' => BoardTone.hacker,
      'amber_terminal' => BoardTone.hacker,
      'cyber_blue' => BoardTone.corporate,
      'wasteland' => BoardTone.wasteland,
      'fire_ansi' => BoardTone.chaotic,
      _ => BoardTone.neutral,
    };
    if (tone != BoardTone.neutral) {
      AppLogging.nodeBoard('Voice: tone resolved | theme=$themeId → $tone');
    }
    return tone;
  }

  String get id => name;
}

/// Deterministic voice generator. Picks a stable variant per board +
/// phrase-key so repeat visits are consistent, but different boards
/// (or different phrase categories on the same board) vary.
///
/// Everything user-facing in NodeBoard's terminal + empty states should
/// be funneled through this class — no ad-hoc string literals.
class NodeBoardVoice {
  const NodeBoardVoice({this.tone = BoardTone.neutral, this.seed = 0});

  final BoardTone tone;

  /// Per-board seed so different boards pick different variants.
  /// Typically `board.id.hashCode`.
  final int seed;

  // ---------------------------------------------------------------------------
  // Connection / handshake
  // ---------------------------------------------------------------------------

  /// Multi-line handshake shown as the entry ritual when a board opens.
  /// The terminal screen emits these lines with small staggered delays
  /// to sell the "connecting" feel. Keep each line short — the rhythm
  /// matters more than the words.
  List<String> handshake({required String nodeHex, required String sysop}) =>
      switch (tone) {
        BoardTone.hacker => [
          // lint-allow: hardcoded-string
          '> DIALING...',
          'LINK ESTABLISHED',
          'NODE: $nodeHex',
          'SYSOP: $sysop',
        ],
        BoardTone.wasteland => [
          // lint-allow: hardcoded-string
          '> SCANNING BAND...',
          'SIGNAL FOUND',
          'ANCHOR: $nodeHex',
          'OPERATOR: $sysop',
        ],
        BoardTone.corporate => [
          // lint-allow: hardcoded-string
          '> INITIALIZING SESSION...',
          'CONNECTION AUTHORIZED',
          'NODE ID: $nodeHex',
          'ADMINISTRATOR: $sysop',
        ],
        BoardTone.chaotic => [
          // lint-allow: hardcoded-string
          '> knocking...',
          'yeah sure come in',
          'node: $nodeHex',
          'running the place: $sysop',
        ],
        BoardTone.minimal => [
          // lint-allow: hardcoded-string
          '> CONNECTING',
          'OK',
          nodeHex,
          sysop,
        ],
        BoardTone.neutral => [
          // lint-allow: hardcoded-string
          '> CONNECTING...',
          'LINK ESTABLISHED',
          'NODE: $nodeHex',
          'SYSOP: $sysop',
        ],
      };

  /// Tagline rendered under the handshake. One short line hinting at
  /// the command surface.
  String welcomeHint() => _pick('welcomeHint', switch (tone) {
    BoardTone.hacker => const [
      'type HELP for commands. awaiting input.',
      'HELP lists commands. tap a chip to act.',
    ],
    BoardTone.wasteland => const [
      'type HELP. or just poke around.',
      'HELP if you are lost out here.',
    ],
    BoardTone.corporate => const [
      'Type HELP for available operations.',
      'HELP lists supported commands.',
    ],
    BoardTone.chaotic => const [
      'HELP, or just mash buttons',
      'type stuff. HELP if you must.',
    ],
    BoardTone.minimal => const ['HELP.', 'type HELP.'],
    BoardTone.neutral => const [
      'Type HELP to see commands, or tap a chip below.',
      'Tap a chip below, or type a command. HELP for the list.',
    ],
  });

  /// Header label for the activity line inside the welcome banner /
  /// board header. Content is the value (e.g. "2h ago").
  String get activityLabel => switch (tone) {
    BoardTone.hacker => 'LAST TRANSMISSION',
    BoardTone.wasteland => 'LAST SIGNAL',
    BoardTone.corporate => 'LAST ACTIVITY',
    BoardTone.chaotic => 'last peep',
    BoardTone.minimal => 'LAST',
    BoardTone.neutral => 'LAST ENTRY',
  };

  // ---------------------------------------------------------------------------
  // Action echoes
  // ---------------------------------------------------------------------------

  String openingSection(String title) => switch (tone) {
    BoardTone.hacker => '> ACCESSING $title...',
    BoardTone.wasteland => '> tuning $title...',
    BoardTone.corporate => '> OPENING $title...',
    BoardTone.chaotic => '> peeking into $title...',
    BoardTone.minimal => '> $title',
    BoardTone.neutral => '> Opening $title...',
  };

  String openingThread(String title) => switch (tone) {
    BoardTone.hacker => '> LOADING "$title"...',
    BoardTone.wasteland => '> unrolling "$title"...',
    BoardTone.corporate => '> LOADING THREAD: "$title"...',
    BoardTone.chaotic => '> unfurling "$title"...',
    BoardTone.minimal => '> "$title"',
    BoardTone.neutral => '> Opening "$title"...',
  };

  String loadingSections() => _pick('loadingSections', switch (tone) {
    BoardTone.hacker => const ['> ENUMERATING CHANNELS...', '> SCANNING...'],
    BoardTone.wasteland => const ['> searching the dial...', '> listening...'],
    BoardTone.corporate => const ['> LOADING DIRECTORY...'],
    BoardTone.chaotic => const ['> lemme check', '> one sec'],
    BoardTone.minimal => const ['> SECTIONS'],
    BoardTone.neutral => const ['> Loading sections...'],
  });

  String openingGuestbook() => _pick('openingGuestbook', switch (tone) {
    BoardTone.hacker => const ['> OPENING GUESTBOOK...'],
    BoardTone.wasteland => const ['> pulling out the guestbook...'],
    BoardTone.corporate => const ['> LOADING VISITORS LOG...'],
    BoardTone.chaotic => const ['> the guestbook! yeah'],
    BoardTone.minimal => const ['> GUESTBOOK'],
    BoardTone.neutral => const ['> Opening guestbook...'],
  });

  String listing() => _pick('listing', switch (tone) {
    BoardTone.hacker => const ['> LISTING...'],
    BoardTone.wasteland => const ['> looking...'],
    BoardTone.corporate => const ['> LISTING...'],
    BoardTone.chaotic => const ['> ok here we go'],
    BoardTone.minimal => const ['> LIST'],
    BoardTone.neutral => const ['> Listing...'],
  });

  String back() => _pick('back', switch (tone) {
    BoardTone.hacker => const ['< BACK', '< stepped back'],
    BoardTone.wasteland => const ['< back'],
    BoardTone.corporate => const ['< BACK'],
    BoardTone.chaotic => const ['< nope, back', '< out of there'],
    BoardTone.minimal => const ['<'],
    BoardTone.neutral => const ['< Back'],
  });

  String postingThread() => _pick('postingThread', switch (tone) {
    BoardTone.hacker => const ['> TRANSMITTING...', '> UPLOADING ENTRY...'],
    BoardTone.wasteland => const ['> sending...', '> broadcasting...'],
    BoardTone.corporate => const ['> SUBMITTING THREAD...', '> DISPATCHING...'],
    BoardTone.chaotic => const ['> sending that thing', '> here we go...'],
    BoardTone.minimal => const ['> POST'],
    BoardTone.neutral => const ['> Posting thread...'],
  });

  String postingReply() => _pick('postingReply', switch (tone) {
    BoardTone.hacker => const ['> TRANSMITTING REPLY...'],
    BoardTone.wasteland => const ['> shouting back...'],
    BoardTone.corporate => const ['> SUBMITTING REPLY...'],
    BoardTone.chaotic => const ['> firing off a reply...'],
    BoardTone.minimal => const ['> REPLY'],
    BoardTone.neutral => const ['> Posting reply...'],
  });

  String postedThread() => _pick('postedThread', switch (tone) {
    BoardTone.hacker => const [
      '✓ ENTRY LOGGED',
      '✓ TRANSMISSION RECEIVED',
      '✓ POSTED',
    ],
    BoardTone.wasteland => const [
      '✓ got through',
      '✓ picked up',
      '✓ heard you',
    ],
    BoardTone.corporate => const ['✓ THREAD SUBMITTED', '✓ DISPATCH COMPLETE'],
    BoardTone.chaotic => const ['✓ yep that went out', '✓ posted!!'],
    BoardTone.minimal => const ['✓ OK'],
    BoardTone.neutral => const ['✓ Thread posted'],
  });

  String postedReply() => _pick('postedReply', switch (tone) {
    BoardTone.hacker => const ['✓ REPLY LOGGED', '✓ PATCHED IN'],
    BoardTone.wasteland => const ['✓ heard', '✓ noted'],
    BoardTone.corporate => const ['✓ REPLY SUBMITTED'],
    BoardTone.chaotic => const ['✓ reply away', '✓ yep'],
    BoardTone.minimal => const ['✓ OK'],
    BoardTone.neutral => const ['✓ Reply posted'],
  });

  // ---------------------------------------------------------------------------
  // Errors
  // ---------------------------------------------------------------------------

  String outOfRange(String kind, int index) => switch (tone) {
    BoardTone.hacker => 'NO $kind [$index] — OUT OF RANGE',
    BoardTone.wasteland => 'no $kind at [$index]',
    BoardTone.corporate => 'INVALID $kind INDEX: $index',
    BoardTone.chaotic => 'uhh there is no $kind $index',
    BoardTone.minimal => 'NO $kind $index',
    BoardTone.neutral => 'No $kind [$index]',
  };

  String notHere() => _pick('notHere', switch (tone) {
    BoardTone.hacker => const ['COMMAND NOT AVAILABLE HERE', 'NOT IN CONTEXT'],
    BoardTone.wasteland => const ['not from here', 'wrong channel for that'],
    BoardTone.corporate => const ['COMMAND NOT PERMITTED HERE'],
    BoardTone.chaotic => const ['nope, not here', "can't do that here"],
    BoardTone.minimal => const ['NO.'],
    BoardTone.neutral => const ['Not available here'],
  });

  String missingContext(String what) => switch (tone) {
    BoardTone.hacker => 'OPEN A $what FIRST',
    BoardTone.wasteland => 'pick a $what first',
    BoardTone.corporate => 'SELECT A $what FIRST',
    BoardTone.chaotic => 'need a $what first, pal',
    BoardTone.minimal => 'NO $what',
    BoardTone.neutral => 'Open a $what first',
  };

  String usageHint(String usage) => 'USAGE: $usage';

  String unknownCommand(String raw) => switch (tone) {
    BoardTone.hacker => 'UNKNOWN: $raw',
    BoardTone.wasteland => 'didn\'t catch that: $raw',
    BoardTone.corporate => 'UNRECOGNIZED COMMAND: $raw',
    BoardTone.chaotic => 'uhh what is "$raw"',
    BoardTone.minimal => '?$raw',
    BoardTone.neutral => 'Unknown command: $raw',
  };

  String unknownHint() => _pick('unknownHint', switch (tone) {
    BoardTone.hacker => const ['type HELP for commands'],
    BoardTone.wasteland => const ['try HELP'],
    BoardTone.corporate => const ['Type HELP for available commands'],
    BoardTone.chaotic => const ['HELP is a thing btw'],
    BoardTone.minimal => const ['HELP.'],
    BoardTone.neutral => const ['Type HELP for available commands'],
  });

  String failedTo(String what, Object error) => switch (tone) {
    BoardTone.hacker => 'FAILED TO $what: $error',
    BoardTone.wasteland => "couldn't $what: $error",
    BoardTone.corporate => 'OPERATION FAILED: $what — $error',
    BoardTone.chaotic => "uhh $what didn't work: $error",
    BoardTone.minimal => 'FAIL: $error',
    BoardTone.neutral => 'Failed to $what: $error',
  };

  // ---------------------------------------------------------------------------
  // Empty states
  // ---------------------------------------------------------------------------

  /// In-terminal empty: appears inside rendered lists. Short.
  String emptyThreadsInline() => _pick('emptyThreadsInline', switch (tone) {
    BoardTone.hacker => const ['  (CHANNEL SILENT)', '  (NO ENTRIES)'],
    BoardTone.wasteland => const ['  (dust only)', '  (nothing on the wire)'],
    BoardTone.corporate => const ['  (no records)'],
    BoardTone.chaotic => const [
      '  (tumbleweeds)',
      '  (crickets)',
      '  (nobody home)',
    ],
    BoardTone.minimal => const ['  —'],
    BoardTone.neutral => const ['  (no threads yet)'],
  });

  /// Card-level empty state title for the native Threads panel.
  String emptyThreadsTitle() => _pick('emptyThreadsTitle', switch (tone) {
    BoardTone.hacker => const [
      'NO TRANSMISSIONS',
      'CHANNEL SILENT',
      'AWAITING FIRST ENTRY',
    ],
    BoardTone.wasteland => const ['SILENCE', 'NO SIGNAL', 'NOTHING ON THE AIR'],
    BoardTone.corporate => const ['NO THREADS RECORDED', 'EMPTY CHANNEL'],
    BoardTone.chaotic => const ['nothing yet', 'yeah this is empty'],
    BoardTone.minimal => const ['EMPTY'],
    BoardTone.neutral => const ['NO THREADS YET'],
  });

  /// Card-level empty state subtitle.
  String emptyThreadsSubtitle() => _pick('emptyThreadsSubtitle', switch (tone) {
    BoardTone.hacker => const [
      'BE THE FIRST TO TRANSMIT.',
      'OPEN THE CHANNEL.',
    ],
    BoardTone.wasteland => const [
      'leave the first mark.',
      'break the silence.',
    ],
    BoardTone.corporate => const [
      'Start the first thread.',
      'No activity yet.',
    ],
    BoardTone.chaotic => const ['go on, say something', 'someone has to start'],
    BoardTone.minimal => const ['POST.'],
    BoardTone.neutral => const ['Be the first to post.'],
  });

  String emptyGuestbookTitle() => _pick('emptyGuestbookTitle', switch (tone) {
    BoardTone.hacker => const ['NO ENTRIES LOGGED', 'GUESTBOOK EMPTY'],
    BoardTone.wasteland => const ['no visitors', 'nobody\'s stopped by'],
    BoardTone.corporate => const ['GUESTBOOK EMPTY'],
    BoardTone.chaotic => const ['no one\'s signed in yet'],
    BoardTone.minimal => const ['—'],
    BoardTone.neutral => const ['NO ENTRIES YET'],
  });

  String emptyGuestbookSubtitle() =>
      _pick('emptyGuestbookSubtitle', switch (tone) {
        BoardTone.hacker => const ['LEAVE A MARK.', 'SIGN IN.'],
        BoardTone.wasteland => const ['leave a mark.', 'scratch something in.'],
        BoardTone.corporate => const ['Add the first entry.'],
        BoardTone.chaotic => const ['drop a hello'],
        BoardTone.minimal => const ['SIGN.'],
        BoardTone.neutral => const ['Leave a mark.'],
      });

  String emptyRepliesInline() => _pick('emptyRepliesInline', switch (tone) {
    BoardTone.hacker => const ['(NO REPLIES)', '(AWAITING RESPONSE)'],
    BoardTone.wasteland => const ['(silence)', '(nobody bit)'],
    BoardTone.corporate => const ['(no responses)'],
    BoardTone.chaotic => const ['(no takers yet)'],
    BoardTone.minimal => const ['—'],
    BoardTone.neutral => const ['No replies yet — be the first.'],
  });

  // ---------------------------------------------------------------------------
  // Plumbing
  // ---------------------------------------------------------------------------

  /// Deterministic pick: same (seed, key) → same option. Keeps repeat
  /// visits to a board consistent so the voice doesn't feel random.
  String _pick(String key, List<String> options) {
    if (options.length == 1) return options.first;
    final h = (seed ^ key.hashCode).abs();
    return options[h % options.length];
  }
}

// ---------------------------------------------------------------------------
// Activity formatting — used for the "LAST ENTRY: 2h ago" header line.
// Kept here so the terminal and native surfaces share a voice-agnostic
// relative-time shape; the [NodeBoardVoice] supplies the label prefix.
// ---------------------------------------------------------------------------

String formatNodeBoardRelativeTime(DateTime? when) {
  if (when == null) return 'NEVER'; // lint-allow: hardcoded-string
  final diff = DateTime.now().difference(when);
  if (diff.inSeconds < 45) return 'just now'; // lint-allow: hardcoded-string
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  if (diff.inDays < 365) return '${diff.inDays ~/ 30}mo ago';
  return '${diff.inDays ~/ 365}y ago';
}
