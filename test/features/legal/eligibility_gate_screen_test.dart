// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/core/legal/age_eligibility_state.dart';
import 'package:socialmesh/core/legal/legal_constants.dart';
import 'package:socialmesh/features/legal/eligibility_gate_screen.dart';
import 'package:socialmesh/providers/age_eligibility_provider.dart';
import 'package:socialmesh/services/haptic_service.dart';

/// Builds the test widget with the [EligibilityGateScreen] wrapped in the
/// required [ProviderScope] and [MaterialApp].
Widget _buildTestApp({AgeEligibilityState? eligibilityState}) {
  final state = eligibilityState ?? AgeEligibilityState.empty;

  return ProviderScope(
    overrides: [
      hapticServiceProvider.overrideWith((ref) => HapticService(ref)),
      ageEligibilityProvider.overrideWith(() {
        return _FakeAgeEligibilityNotifier(state);
      }),
    ],
    child: MaterialApp(
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(primary: Color(0xFFE91E8C)),
      ),
      home: const EligibilityGateScreen(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('EligibilityGateScreen rendering', () {
    testWidgets('shows title text', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Ages 16+'), findsOneWidget);
    });

    testWidgets('shows body text', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.textContaining('16 or older'), findsWidgets);
    });

    testWidgets('shows confirm button', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('I Am 16 or Older'), findsOneWidget);
    });

    testWidgets('shows exit button', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Exit'), findsOneWidget);
    });

    testWidgets('shows Terms and Privacy links', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Terms'), findsOneWidget);
      expect(find.text('Privacy'), findsOneWidget);
    });

    testWidgets('shows shield icon', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.verified_user_outlined), findsOneWidget);
    });
  });

  group('EligibilityGateScreen gate logic', () {
    testWidgets('gate appears when not confirmed', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // The gate screen is showing with its title
      expect(find.text('Ages 16+'), findsOneWidget);
      expect(find.text('I Am 16 or Older'), findsOneWidget);
    });

    testWidgets('gate appears when policy version is outdated', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          eligibilityState: AgeEligibilityState(
            hasConfirmed: true,
            confirmedAt: DateTime.now().toUtc(),
            policyVersion: LegalConstants.ageEligibilityPolicyVersion - 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The gate should still show since policy version is outdated
      expect(find.text('Ages 16+'), findsOneWidget);
    });
  });
}

/// Fake notifier for testing that returns a predetermined state.
class _FakeAgeEligibilityNotifier extends AgeEligibilityNotifier {
  final AgeEligibilityState _initial;

  _FakeAgeEligibilityNotifier(this._initial);

  @override
  Future<AgeEligibilityState> build() async => _initial;

  @override
  Future<void> confirm() async {
    state = AsyncData(
      AgeEligibilityState(
        hasConfirmed: true,
        confirmedAt: DateTime.now().toUtc(),
        policyVersion: LegalConstants.ageEligibilityPolicyVersion,
      ),
    );
  }
}
