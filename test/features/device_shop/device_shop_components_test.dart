// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/device_shop/widgets/device_shop_components.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('DeviceShopChoiceChip', () {
    testWidgets('renders label and invokes tap callback', (
      WidgetTester tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        _wrap(
          DeviceShopChoiceChip(
            label: 'Nodes',
            icon: Icons.router,
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Nodes'), findsOneWidget);
      expect(find.byIcon(Icons.router), findsOneWidget);

      await tester.tap(find.text('Nodes'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });

  group('DeviceShopStatePanel', () {
    testWidgets('renders action button and invokes callback', (
      WidgetTester tester,
    ) async {
      var actionTapped = false;

      await tester.pumpWidget(
        _wrap(
          DeviceShopStatePanel(
            icon: Icons.refresh,
            title: 'Temporary issue',
            description: 'Try again to reload products.',
            actionLabel: 'Retry',
            actionIcon: Icons.refresh,
            onAction: () => actionTapped = true,
          ),
        ),
      );

      expect(find.text('Temporary issue'), findsOneWidget);
      expect(find.text('Try again to reload products.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(actionTapped, isTrue);
    });
  });
}
