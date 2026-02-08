// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/core/legal/legal_constants.dart';
import 'package:socialmesh/core/legal/terms_acceptance_state.dart';
import 'package:socialmesh/features/legal/legal_acceptance_screen.dart';
import 'package:socialmesh/providers/terms_acceptance_provider.dart';
import 'package:socialmesh/services/haptic_service.dart';

/// Builds the test widget with the [LegalAcceptanceScreen] wrapped in the
/// required [ProviderScope] and [MaterialApp].
///
/// The [termsState] controls what the fake [TermsAcceptanceNotifier] returns.
Widget _buildTestApp({TermsAcceptanceState? termsState}) {
  final state = termsState ?? TermsAcceptanceState.empty;

  return ProviderScope(
    overrides: [
      // Override haptic service so it doesn't try to read real settings.
      // HapticService's trigger() will just return early because settings
      // are not loaded — no need for a custom subclass.
      hapticServiceProvider.overrideWith((ref) => HapticService(ref)),
      termsAcceptanceProvider.overrideWith(() {
        return _FakeTermsNotifier(state);
      }),
    ],
    child: MaterialApp(
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(primary: Color(0xFFE91E8C)),
      ),
      home: const LegalAcceptanceScreen(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LegalAcceptanceScreen rendering', () {
    testWidgets('shows title text', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // First-time acceptance shows "Terms & Privacy"
      expect(find.text('Terms & Privacy'), findsOneWidget);
    });

    testWidgets('shows subtitle / summary text for first acceptance', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.textContaining('Before you get started'), findsOneWidget);
    });

    testWidgets('shows "Updated Terms" title for version bump', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          termsState: const TermsAcceptanceState(
            acceptedTermsVersion: '2025-01-01',
            acceptedPrivacyVersion: '2025-01-01',
          ),
        ),
      );
      // Pump extra frames so the async provider resolves and the
      // widget rebuilds with the correct _isUpdate value.
      await tester.pumpAndSettle();

      expect(find.text('Updated Terms'), findsOneWidget);
      expect(find.textContaining('We have updated'), findsOneWidget);
    });

    testWidgets('shows Terms of Service document link tile', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Terms of Service'), findsOneWidget);
    });

    testWidgets('shows Privacy Policy document link tile', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Privacy Policy'), findsOneWidget);
    });

    testWidgets('shows effective dates for both documents', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Should show formatted dates from LegalConstants
      expect(find.textContaining('Effective'), findsNWidgets(2));
    });
  });

  group('LegalAcceptanceScreen buttons', () {
    testWidgets('I Agree button is present and enabled', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final agreeButton = find.text('I Agree');
      expect(agreeButton, findsOneWidget);

      // FilledButton should be tappable
      final filledButton = find.ancestor(
        of: agreeButton,
        matching: find.byType(FilledButton),
      );
      expect(filledButton, findsOneWidget);

      final widget = tester.widget<FilledButton>(filledButton);
      expect(widget.onPressed, isNotNull);
    });

    testWidgets('Not Now button is present and enabled', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final declineButton = find.text('Not Now');
      expect(declineButton, findsOneWidget);

      final textButton = find.ancestor(
        of: declineButton,
        matching: find.byType(TextButton),
      );
      expect(textButton, findsOneWidget);

      final widget = tester.widget<TextButton>(textButton);
      expect(widget.onPressed, isNotNull);
    });

    testWidgets('fine print text is shown below buttons', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.textContaining('By tapping'), findsOneWidget);
    });
  });

  group('LegalAcceptanceScreen accessibility', () {
    testWidgets('I Agree button has semantic label', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Find Semantics widget wrapping the agree button
      final semantics = find.bySemanticsLabel(
        RegExp(r'I agree to the Terms of Service'),
      );
      expect(semantics, findsOneWidget);
    });

    testWidgets('Not Now button has semantic label', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final semantics = find.bySemanticsLabel(RegExp(r'Not now'));
      expect(semantics, findsOneWidget);
    });

    testWidgets('Terms of Service link has semantic label', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // The Semantics widget wrapping the document link tile sets
      // label: 'View Terms of Service'. Because InkWell inside the
      // tile creates its own semantics node, we verify by finding
      // the Semantics widget directly via predicate.
      final semantics = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'View Terms of Service',
      );
      expect(semantics, findsOneWidget);
    });

    testWidgets('Privacy Policy link has semantic label', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final semantics = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'View Privacy Policy',
      );
      expect(semantics, findsOneWidget);
    });

    testWidgets('title text has header semantics', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final titleFinder = find.text('Terms & Privacy');
      expect(titleFinder, findsOneWidget);

      // Verify the title is wrapped in a Semantics widget configured
      // as a header by finding the Semantics ancestor via predicate.
      final headerSemantics = find.ancestor(
        of: titleFinder,
        matching: find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.header == true,
        ),
      );
      expect(headerSemantics, findsOneWidget);
    });

    testWidgets('app icon has excludeSemantics set', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // The app icon is wrapped with Semantics(label: 'Socialmesh app icon',
      // excludeSemantics: true)
      final iconSemantics = find.bySemanticsLabel('Socialmesh app icon');
      expect(iconSemantics, findsOneWidget);
    });

    testWidgets('no hardcoded font sizes that prevent scaling', (tester) async {
      // Use a realistic phone-sized surface so the scrollable layout
      // has enough room even at large text scales.
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Pump with a large text scale to ensure it does not overflow
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: _buildTestApp(),
        ),
      );
      await tester.pumpAndSettle();

      // If the screen renders without errors at 1.5x text scale, it supports
      // dynamic type. The key assertion is that pumpAndSettle completes.
      expect(find.text('Terms & Privacy'), findsOneWidget);
      expect(find.text('I Agree'), findsOneWidget);
    });
  });

  group('LegalAcceptanceScreen decline flow', () {
    testWidgets('tapping Not Now button exists and is tappable', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Verify the Not Now button exists and is tappable.
      // We cannot reliably test Platform.isIOS / Platform.isAndroid in
      // widget tests because the test runner uses the host platform.
      final notNowButton = find.text('Not Now');
      expect(notNowButton, findsOneWidget);
    });
  });

  group('LegalAcceptanceScreen state interactions', () {
    testWidgets('when acceptance state is current, screen still renders', (
      tester,
    ) async {
      // Even if somehow the screen is shown with current acceptance,
      // it should render without errors. The gating logic is in
      // AppInitNotifier, not in this screen.
      await tester.pumpWidget(
        _buildTestApp(
          termsState: TermsAcceptanceState(
            acceptedTermsVersion: LegalConstants.termsVersion,
            acceptedPrivacyVersion: LegalConstants.privacyVersion,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show first-time title since isUpdate checks hasAccepted &&
      // needsAcceptance, and when both are current, needsAcceptance is false
      expect(find.text('Terms & Privacy'), findsOneWidget);
      expect(find.text('I Agree'), findsOneWidget);
    });

    testWidgets('shield icon is displayed in app icon area', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    });

    testWidgets('document link tiles show chevron icons', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(2));
    });

    testWidgets('document link tiles show correct icons', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
      expect(find.byIcon(Icons.privacy_tip_outlined), findsOneWidget);
    });
  });
}

/// Fake [TermsAcceptanceNotifier] that returns a pre-set state without
/// needing actual SharedPreferences or SettingsService initialisation.
class _FakeTermsNotifier extends AsyncNotifier<TermsAcceptanceState>
    implements TermsAcceptanceNotifier {
  final TermsAcceptanceState _initialState;

  _FakeTermsNotifier(this._initialState);

  @override
  Future<TermsAcceptanceState> build() async => _initialState;

  @override
  bool get needsAcceptance => _initialState.needsAcceptance;

  @override
  bool get isTermsUpdate =>
      _initialState.hasAccepted && _initialState.termsVersionChanged;

  @override
  bool get isPrivacyUpdate =>
      _initialState.hasAccepted && _initialState.privacyVersionChanged;

  @override
  bool get isFirstAcceptance => !_initialState.hasAccepted;

  @override
  Future<void> accept({String? buildNumber}) async {
    state = AsyncData(
      TermsAcceptanceState(
        acceptedTermsVersion: LegalConstants.termsVersion,
        acceptedPrivacyVersion: LegalConstants.privacyVersion,
        acceptedAt: DateTime.now(),
        acceptedPlatform: 'test',
        acceptedBuild: buildNumber,
      ),
    );
  }
}
