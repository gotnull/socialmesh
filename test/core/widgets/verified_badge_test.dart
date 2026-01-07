import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/widgets/verified_badge.dart';

void main() {
  group('kGoldBadgeColor', () {
    test('has correct gold color value', () {
      expect(kGoldBadgeColor, const Color(0xFFFFD700));
    });
  });

  group('SimpleVerifiedBadge', () {
    testWidgets('renders with default size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SimpleVerifiedBadge())),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.verified);
      expect(icon.size, 16);
      expect(icon.color, kGoldBadgeColor);
    });

    testWidgets('renders with custom size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SimpleVerifiedBadge(size: 24))),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.size, 24);
    });

    testWidgets('uses gold color', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SimpleVerifiedBadge())),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, kGoldBadgeColor);
    });
  });

  group('VerifiedBadge', () {
    testWidgets('shows nothing when not verified and no premium check', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VerifiedBadge(isVerified: false, checkPremiumStatus: false),
          ),
        ),
      );

      expect(find.byType(Icon), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('shows gold badge when isVerified is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VerifiedBadge(isVerified: true, checkPremiumStatus: false),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.verified);
      expect(icon.color, kGoldBadgeColor);
    });

    testWidgets('uses custom size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: VerifiedBadge(isVerified: true, size: 20)),
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.size, 20);
    });
  });
}
