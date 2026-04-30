// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodedex/widgets/sigil_painter.dart';
import 'package:socialmesh/features/nodedex/widgets/tappable_sigil_avatar.dart';

class _PushCountingObserver extends NavigatorObserver {
  int pushCount = 0;
  Route<dynamic>? lastPushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    pushCount++;
    lastPushed = route;
  }
}

Widget _wrap(Widget child, {NavigatorObserver? observer}) {
  return ProviderScope(
    child: MaterialApp(
      navigatorObservers: observer == null ? const [] : [observer],
      home: Scaffold(body: child),
    ),
  );
}

/// Silence widget-build errors from the pushed destination
/// `NodeDexDetailScreen` — it depends on Riverpod providers that are
/// not exhaustively stubbed in this unit test. We only verify that the
/// wrapper *pushes* a route, not that the destination renders.
void _swallowDestinationErrors() {
  FlutterError.onError = (FlutterErrorDetails details) {
    final msg = details.exceptionAsString();
    if (msg.contains('NodeDexDetailScreen') ||
        msg.contains('No ProviderScope') ||
        msg.contains('was used after being disposed')) {
      return;
    }
    FlutterError.presentError(details);
  };
}

void main() {
  group('TappableSigilAvatar', () {
    testWidgets('renders a SigilAvatar with the given nodeNum', (tester) async {
      await tester.pumpWidget(
        _wrap(const TappableSigilAvatar(nodeNum: 0xB15E74DB)),
      );

      final avatar = tester.widget<SigilAvatar>(find.byType(SigilAvatar));
      expect(avatar.nodeNum, 0xB15E74DB);
    });

    testWidgets('default tap pushes one route on top of the initial', (
      tester,
    ) async {
      _swallowDestinationErrors();
      final observer = _PushCountingObserver();
      await tester.pumpWidget(
        _wrap(
          const TappableSigilAvatar(nodeNum: 0xCAFE_BABE),
          observer: observer,
        ),
      );

      final initialPushes = observer.pushCount;

      await tester.tap(find.byType(SigilAvatar));
      // Don't pumpAndSettle — the destination NodeDexDetailScreen
      // depends on Riverpod providers that aren't fully stubbed here.
      // We only verify the push happened.
      await tester.pump();

      expect(observer.pushCount - initialPushes, 1);
      expect(observer.lastPushed, isA<MaterialPageRoute<void>>());
    });

    testWidgets('onTapOverride is invoked and no route is pushed', (
      tester,
    ) async {
      final observer = _PushCountingObserver();
      var overrideCalls = 0;

      await tester.pumpWidget(
        _wrap(
          TappableSigilAvatar(
            nodeNum: 0xDEAD_BEEF,
            onTapOverride: () => overrideCalls++,
          ),
          observer: observer,
        ),
      );

      final initialPushes = observer.pushCount;

      await tester.tap(find.byType(SigilAvatar));
      await tester.pump();

      expect(overrideCalls, 1);
      expect(observer.pushCount - initialPushes, 0);
    });

    testWidgets('enableTap=false makes the avatar non-interactive', (
      tester,
    ) async {
      final observer = _PushCountingObserver();
      await tester.pumpWidget(
        _wrap(
          const TappableSigilAvatar(nodeNum: 0xBAD_BABE, enableTap: false),
          observer: observer,
        ),
      );

      expect(find.byType(SigilAvatar), findsOneWidget);
      final initialPushes = observer.pushCount;

      await tester.tap(find.byType(SigilAvatar), warnIfMissed: false);
      await tester.pump();

      expect(observer.pushCount - initialPushes, 0);
    });

    testWidgets('forwards size and badge to the inner avatar', (tester) async {
      const badge = SizedBox.square(
        dimension: 8,
        key: ValueKey('badge'), // lint-allow: hardcoded-string
      );

      await tester.pumpWidget(
        _wrap(
          const TappableSigilAvatar(
            nodeNum: 0xB15E74DB,
            size: 64,
            badge: badge,
          ),
        ),
      );

      final avatar = tester.widget<SigilAvatar>(find.byType(SigilAvatar));
      expect(avatar.size, 64);
      expect(avatar.badge, isNotNull);
    });
  });
}
