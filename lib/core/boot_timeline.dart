// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Records how long each awaited boot step takes, from Dart entry until the
/// shell is on screen, so a slow launch can be attributed from the app log
/// instead of guessed at.
///
/// Every `mark` stores the time since the previous mark under the step's
/// name; `summary` renders the whole list on one line. The clock starts
/// when the class is first touched, which happens at the top of `main()`.
class BootTimeline {
  BootTimeline._();

  static final BootTimeline instance = BootTimeline._();

  final Stopwatch _clock = Stopwatch()..start();
  final List<({String step, int ms})> _marks = [];
  int _lastMarkMs = 0;

  /// Close the step named [step]; its duration is the time since the
  /// previous mark (or since the clock started for the first one).
  void mark(String step) {
    final now = _clock.elapsedMilliseconds;
    _marks.add((step: step, ms: now - _lastMarkMs));
    _lastMarkMs = now;
  }

  /// Milliseconds since Dart entry.
  int get elapsedMs => _clock.elapsedMilliseconds;

  /// One log line: `BOOT_TIMELINE at=<where> total=<ms> step=<ms> ...`.
  String summary(String at) {
    final steps = _marks.map((m) => '${m.step}=${m.ms}ms').join(' ');
    return 'BOOT_TIMELINE at=$at total=${elapsedMs}ms $steps';
  }
}
