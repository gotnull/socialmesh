import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/features/signals/widgets/thread_like_refresh_indicator.dart';

void main() {
  testWidgets('indicator becomes visible on pull and calls onRefresh', (
    WidgetTester tester,
  ) async {
    var refreshed = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ThreadLikeRefreshIndicator(
              onRefresh: () async {
                refreshed = true;
              },
              child: ListView(
                children: List.generate(
                  30,
                  (i) => ListTile(title: Text('Item $i')),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Simulate pull by directly mutating the indicator state (tests should not
    // rely on platform-specific scroll notifications).
    final state = tester.state<ThreadLikeRefreshIndicatorState>(
      find.byType(ThreadLikeRefreshIndicator),
    );
    state.debugSetPullDistanceForTest(120.0); // > trigger threshold
    await tester.pump(const Duration(milliseconds: 50));

    final opacityWidget = tester.widget<Opacity>(
      find.byKey(const Key('thread_like_indicator_opacity')),
    );
    expect(opacityWidget.opacity, greaterThan(0.0));

    // Trigger refresh and wait
    state.debugTriggerRefreshForTest();
    await tester.pumpAndSettle();

    expect(refreshed, isTrue);
  });

  testWidgets('looping active only while refreshing', (
    WidgetTester tester,
  ) async {
    final completer = Completer<void>();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ThreadLikeRefreshIndicator(
              onRefresh: () async {
                // Keep the refresh pending until we complete the completer so
                // we can assert that the loop is active during refresh.
                await completer.future;
              },
              child: ListView(
                children: List.generate(
                  6,
                  (i) => ListTile(title: Text('Item $i')),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final state = tester.state<ThreadLikeRefreshIndicatorState>(
      find.byType(ThreadLikeRefreshIndicator),
    );

    // Pulling alone must NOT start the repeating loop.
    state.debugSetPullDistanceForTest(60.0);
    await tester.pump();
    expect(state.debugIsLoopingForTest(), isFalse);

    // Trigger refresh — the loop should start while refreshing
    state.debugTriggerRefreshForTest();
    await tester.pump();
    expect(state.debugIsLoopingForTest(), isTrue);

    // Complete refresh — loop should stop
    completer.complete();
    await tester.pumpAndSettle();
    expect(state.debugIsLoopingForTest(), isFalse);
  });

  testWidgets('indicator not visible when not pulled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ThreadLikeRefreshIndicator(
              onRefresh: () async {},
              child: ListView(
                children: List.generate(
                  3,
                  (i) => ListTile(title: Text('Item $i')),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // No pull performed
    await tester.pumpAndSettle();

    // The Opacity should be zero when not pulled
    final opacityWidget =
        tester.widgetList(find.byType(Opacity)).first as Opacity;
    expect(opacityWidget.opacity, equals(0.0));
  });
}
