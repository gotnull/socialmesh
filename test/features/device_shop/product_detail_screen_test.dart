// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/device_shop/widgets/device_shop_components.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('DeviceShopBadgePill', () {
    testWidgets('renders label and icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const DeviceShopBadgePill(
            label: 'SALE',
            icon: Icons.local_offer,
            color: Colors.red,
          ),
        ),
      );

      expect(find.text('SALE'), findsOneWidget);
      expect(find.byIcon(Icons.local_offer), findsOneWidget);
    });

    testWidgets('has decorated container', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const DeviceShopBadgePill(
            label: '20% OFF',
            icon: Icons.percent,
            color: Colors.green,
          ),
        ),
      );

      expect(find.text('20% OFF'), findsOneWidget);
      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('20% OFF'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(container.decoration, isNotNull);
    });
  });

  group('DeviceShopInfoPill', () {
    testWidgets('renders label text', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const DeviceShopInfoPill(label: 'Verified', color: Colors.green)),
      );

      expect(find.text('Verified'), findsOneWidget);
    });

    testWidgets('has tinted container decoration', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const DeviceShopInfoPill(label: 'In Stock', color: Colors.teal)),
      );

      expect(find.text('In Stock'), findsOneWidget);
      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('In Stock'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(container.decoration, isNotNull);
    });
  });

  group('DeviceShopIconOrb', () {
    testWidgets('renders icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          DeviceShopIconOrb(
            icon: Icons.arrow_back,
            color: Colors.white,
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('invokes onTap callback', (WidgetTester tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          DeviceShopIconOrb(
            icon: Icons.favorite_border,
            color: Colors.white,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('wraps in BouncyTap', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          DeviceShopIconOrb(
            icon: Icons.share,
            color: Colors.white,
            onTap: () {},
          ),
        ),
      );

      expect(find.byType(BouncyTap), findsOneWidget);
    });
  });
}
