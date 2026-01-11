import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/help/help_content.dart';
import '../core/logging.dart';

/// State for the help system
class HelpState {
  final Set<String> completedTopics;
  final Set<String> dismissedTopics;
  final bool skipFutureHelp;
  final String? activeTourId;
  final int currentStepIndex;
  final bool showPulsingHint;

  const HelpState({
    this.completedTopics = const {},
    this.dismissedTopics = const {},
    this.skipFutureHelp = false,
    this.activeTourId,
    this.currentStepIndex = 0,
    this.showPulsingHint = true,
  });

  HelpState copyWith({
    Set<String>? completedTopics,
    Set<String>? dismissedTopics,
    bool? skipFutureHelp,
    String? activeTourId,
    int? currentStepIndex,
    bool? showPulsingHint,
  }) {
    return HelpState(
      completedTopics: completedTopics ?? this.completedTopics,
      dismissedTopics: dismissedTopics ?? this.dismissedTopics,
      skipFutureHelp: skipFutureHelp ?? this.skipFutureHelp,
      activeTourId: activeTourId,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      showPulsingHint: showPulsingHint ?? this.showPulsingHint,
    );
  }

  bool isTopicCompleted(String topicId) => completedTopics.contains(topicId);
  bool isTopicDismissed(String topicId) => dismissedTopics.contains(topicId);
  bool shouldShowHelp(String topicId) =>
      !skipFutureHelp &&
      !isTopicCompleted(topicId) &&
      !isTopicDismissed(topicId);

  static const HelpState initial = HelpState();
}

/// Notifier for managing help system state
class HelpNotifier extends Notifier<HelpState> {
  static const String _prefCompletedKey = 'help_completed_topics';
  static const String _prefDismissedKey = 'help_dismissed_topics';
  static const String _prefSkipKey = 'help_skip_future';

  @override
  HelpState build() {
    _loadFromPreferences();
    return HelpState.initial;
  }

  Future<void> _loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final completed = prefs.getStringList(_prefCompletedKey) ?? [];
      final dismissed = prefs.getStringList(_prefDismissedKey) ?? [];
      final skipFuture = prefs.getBool(_prefSkipKey) ?? false;

      state = HelpState(
        completedTopics: completed.toSet(),
        dismissedTopics: dismissed.toSet(),
        skipFutureHelp: skipFuture,
      );

      AppLogging.app(
        'Help: Loaded state - ${completed.length} completed, ${dismissed.length} dismissed, skip=$skipFuture',
      );
    } catch (e) {
      AppLogging.app('Help: Failed to load preferences: $e');
    }
  }

  Future<void> _saveToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _prefCompletedKey,
        state.completedTopics.toList(),
      );
      await prefs.setStringList(
        _prefDismissedKey,
        state.dismissedTopics.toList(),
      );
      await prefs.setBool(_prefSkipKey, state.skipFutureHelp);
    } catch (e) {
      AppLogging.app('Help: Failed to save preferences: $e');
    }
  }

  /// Start a help tour
  void startTour(String topicId) {
    AppLogging.app('Help: Starting tour $topicId');
    state = state.copyWith(activeTourId: topicId, currentStepIndex: 0);
  }

  /// Advance to next step in active tour
  void nextStep() {
    if (state.activeTourId == null) return;

    final topic = HelpContent.getTopic(state.activeTourId!);
    if (topic == null) return;

    final nextIndex = state.currentStepIndex + 1;
    if (nextIndex >= topic.steps.length) {
      completeTour();
    } else {
      AppLogging.app('Help: Next step ${nextIndex + 1}/${topic.steps.length}');
      state = state.copyWith(currentStepIndex: nextIndex);
    }
  }

  /// Go to previous step in active tour
  void previousStep() {
    if (state.activeTourId == null || state.currentStepIndex == 0) return;

    final prevIndex = state.currentStepIndex - 1;
    AppLogging.app('Help: Previous step ${prevIndex + 1}');
    state = state.copyWith(currentStepIndex: prevIndex);
  }

  /// Complete the active tour
  void completeTour() {
    if (state.activeTourId == null) return;

    final topicId = state.activeTourId!;
    AppLogging.app('Help: Completed tour $topicId');

    state = state.copyWith(
      completedTopics: {...state.completedTopics, topicId},
      activeTourId: null,
      currentStepIndex: 0,
    );

    _saveToPreferences();
  }

  /// Dismiss/skip a topic
  void dismissTopic(String topicId, {bool dontShowAgain = false}) {
    AppLogging.app('Help: Dismissed $topicId (permanent=$dontShowAgain)');

    if (dontShowAgain) {
      state = state.copyWith(
        dismissedTopics: {...state.dismissedTopics, topicId},
        activeTourId: state.activeTourId == topicId ? null : state.activeTourId,
      );
      _saveToPreferences();
    } else {
      // Just close without marking dismissed
      if (state.activeTourId == topicId) {
        state = state.copyWith(activeTourId: null, currentStepIndex: 0);
      }
    }
  }

  /// Cancel active tour
  void cancelTour() {
    if (state.activeTourId == null) return;

    AppLogging.app('Help: Cancelled tour ${state.activeTourId}');
    state = state.copyWith(activeTourId: null, currentStepIndex: 0);
  }

  /// Set skip future help preference
  void setSkipFutureHelp(bool skip) {
    AppLogging.app('Help: Skip future help = $skip');
    state = state.copyWith(skipFutureHelp: skip);
    _saveToPreferences();
  }

  /// Reset a specific topic (for replay)
  void resetTopic(String topicId) {
    AppLogging.app('Help: Reset topic $topicId');
    state = state.copyWith(
      completedTopics: state.completedTopics.difference({topicId}),
      dismissedTopics: state.dismissedTopics.difference({topicId}),
    );
    _saveToPreferences();
  }

  /// Reset all help state
  void resetAll() {
    AppLogging.app('Help: Reset all help state');
    state = HelpState.initial;
    _saveToPreferences();
  }

  /// Check if should auto-trigger help for a topic
  bool shouldAutoTrigger(String topicId) {
    if (state.skipFutureHelp) return false;
    if (state.activeTourId != null) return false; // Another tour active
    return state.shouldShowHelp(topicId);
  }
}

final helpProvider = NotifierProvider<HelpNotifier, HelpState>(
  HelpNotifier.new,
);
