// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/navigation.dart';
import 'package:socialmesh/core/routing/conversation_routes.dart';
import 'package:socialmesh/core/routing/notification_routes.dart';

void main() {
  group('conversation route names', () {
    test('same conversation always produces the same tag', () {
      expect(
        meshtasticChannelRouteName(0),
        equals(meshtasticChannelRouteName(0)),
      );
      expect(
        meshCoreContactRouteName('AABB'),
        equals(meshCoreContactRouteName('aabb')),
      );
    });

    test('different conversations never collide', () {
      final tags = {
        meshtasticChannelRouteName(0),
        meshtasticChannelRouteName(1),
        meshtasticDmRouteName(0),
        meshtasticDmRouteName(1),
        meshCoreChannelRouteName(0),
        meshCoreChannelRouteName(1),
        meshCoreContactRouteName('aa'),
        meshCoreContactRouteName('bb'),
      };
      expect(tags.length, 8);
    });

    test('notification target tags never collide across types', () {
      // Every notification payload type that opens a target-specific
      // screen needs its own tag, or one target would suppress another.
      final tags = {
        nodeDetailRouteName(7),
        detectionLogRouteName(7),
        waypointMapRouteName(7),
        takEventRouteName('7'),
        aetherFlightRouteName('7'),
        sipDmRouteName(7),
        meshtasticDmRouteName(7),
        meshtasticChannelRouteName(7),
        petHomeRouteName,
        firmwareUpdateRouteName,
        meshCoreNodesRouteName,
      };
      expect(tags.length, 11);
    });

    test('case-insensitive targets normalise to one tag', () {
      expect(aetherFlightRouteName('ua123'), aetherFlightRouteName('UA123'));
    });

    test('tags are not navigator paths', () {
      // A leading slash would let a tag be mistaken for an onGenerateRoute
      // path or match a RouteRegistry entry.
      for (final tag in [
        meshtasticChannelRouteName(0),
        meshtasticDmRouteName(1),
        meshCoreChannelRouteName(2),
        meshCoreContactRouteName('ff'),
        nodeDetailRouteName(3),
        detectionLogRouteName(4),
        waypointMapRouteName(5),
        takEventRouteName('abc'),
        aetherFlightRouteName('UA123'),
        sipDmRouteName(6),
        petHomeRouteName,
        firmwareUpdateRouteName,
        meshCoreNodesRouteName,
      ]) {
        expect(tag.startsWith('/'), isFalse);
      }
    });
  });

  // Issue 283: repeated notifications for the same conversation used to push
  // a new chat screen every time, so the user had to back out of a pile of
  // identical screens. These drive the guard the notification router uses.
  group('pushRouteUnlessOnTop', () {
    late _RouteCounter counter;

    Future<NavigatorState> pumpNavigator(WidgetTester tester) async {
      final key = GlobalKey<NavigatorState>();
      counter = _RouteCounter();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          navigatorObservers: [counter],
          home: const Text('shell'),
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            builder: (_) => Text(settings.name ?? 'unnamed'),
            settings: settings,
          ),
        ),
      );
      return key.currentState!;
    }

    testWidgets('five taps on the same channel leave one chat screen', (
      tester,
    ) async {
      final navigator = await pumpNavigator(tester);
      var pushes = 0;

      for (var tap = 0; tap < 5; tap++) {
        final pushed = pushRouteUnlessOnTop(
          navigator,
          routeName: meshtasticChannelRouteName(0),
          builder: (_) => const Text('channel 0'),
        );
        if (pushed) pushes++;
        await tester.pumpAndSettle();
      }

      expect(pushes, 1, reason: 'only the first tap should push');
      expect(counter.depth, 2, reason: 'shell + one chat screen');

      // One back tap must return to the shell, not to another copy.
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('shell'), findsOneWidget);
      expect(find.text('channel 0'), findsNothing);
    });

    testWidgets('a different conversation still opens', (tester) async {
      final navigator = await pumpNavigator(tester);

      for (final tag in [
        meshtasticChannelRouteName(0),
        meshtasticChannelRouteName(0),
        meshtasticDmRouteName(42),
        meshCoreChannelRouteName(0),
        meshCoreContactRouteName('AABB'),
        meshCoreContactRouteName('aabb'),
      ]) {
        pushRouteUnlessOnTop(
          navigator,
          routeName: tag,
          builder: (_) => Text(tag),
        );
        await tester.pumpAndSettle();
      }

      // Six pushes, two of which repeat the route already on top.
      expect(counter.depth, 5);
    });

    testWidgets('the list fallback does not stack either', (tester) async {
      final navigator = await pumpNavigator(tester);
      var pushes = 0;

      for (var tap = 0; tap < 3; tap++) {
        if (pushNamedUnlessOnTop(navigator, '/channels')) pushes++;
        await tester.pumpAndSettle();
      }

      expect(pushes, 1);
      expect(counter.depth, 2);
    });
  });

  group('isTopRouteNamed', () {
    testWidgets('reports the top route and leaves the stack intact', (
      tester,
    ) async {
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: key, home: const SizedBox.shrink()),
      );

      final navigator = key.currentState!;
      expect(
        isTopRouteNamed(navigator, meshtasticChannelRouteName(0)),
        isFalse,
      );

      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const SizedBox.shrink(),
          settings: RouteSettings(name: meshtasticChannelRouteName(0)),
        ),
      );
      await tester.pumpAndSettle();

      expect(isTopRouteNamed(navigator, meshtasticChannelRouteName(0)), isTrue);
      expect(
        isTopRouteNamed(navigator, meshtasticChannelRouteName(1)),
        isFalse,
      );
      expect(isTopRouteNamed(navigator, meshtasticDmRouteName(0)), isFalse);

      // The probe must not pop: the pushed route is still there.
      expect(navigator.canPop(), isTrue);
    });

    testWidgets('a different conversation on top reads as absent', (
      tester,
    ) async {
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: key, home: const SizedBox.shrink()),
      );

      final navigator = key.currentState!;
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const SizedBox.shrink(),
          settings: RouteSettings(name: meshtasticChannelRouteName(0)),
        ),
      );
      await tester.pumpAndSettle();
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const SizedBox.shrink(),
          settings: RouteSettings(name: meshtasticDmRouteName(42)),
        ),
      );
      await tester.pumpAndSettle();

      // Buried, not on top: a repeat notification for channel 0 still pushes.
      expect(
        isTopRouteNamed(navigator, meshtasticChannelRouteName(0)),
        isFalse,
      );
      expect(isTopRouteNamed(navigator, meshtasticDmRouteName(42)), isTrue);
    });
  });
}

// Counts live routes so a test can assert the stack never grows a duplicate.
class _RouteCounter extends NavigatorObserver {
  int depth = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    depth++;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    depth--;
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    depth--;
  }
}
