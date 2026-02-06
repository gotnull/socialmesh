// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/accessibility_theme_adapter.dart';
import 'package:socialmesh/core/theme.dart';
import 'package:socialmesh/core/widgets/accessibility_wrapper.dart'
    show
        AccessibilityWrapper,
        AccessibilityContext,
        AccessibleTapTarget,
        AccessibleAnimatedContainer,
        AccessibleAnimatedOpacity;
import 'package:socialmesh/models/accessibility_preferences.dart';
import 'package:socialmesh/providers/accessibility_providers.dart';

void main() {
  group('AccessibilityThemeAdapter', () {
    group('applyPreferences', () {
      test('returns theme unchanged for default preferences', () {
        final baseTheme = AppTheme.darkTheme(AccentColors.magenta);
        final result = AccessibilityThemeAdapter.applyPreferences(
          baseTheme: baseTheme,
          preferences: AccessibilityPreferences.defaults,
        );

        // Font family should remain JetBrainsMono
        expect(result.textTheme.bodyLarge?.fontFamily, 'JetBrainsMono');
        // Visual density should be comfortable (0,0)
        expect(result.visualDensity.horizontal, 0.0);
        expect(result.visualDensity.vertical, 0.0);
      });

      test('applies system font when fontMode is system', () {
        final baseTheme = AppTheme.darkTheme(AccentColors.magenta);
        final result = AccessibilityThemeAdapter.applyPreferences(
          baseTheme: baseTheme,
          preferences: const AccessibilityPreferences(
            fontMode: FontMode.system,
          ),
        );

        // Font family should be a system font (not JetBrainsMono)
        // The exact font depends on platform, but it should NOT be the branded font
        expect(result.textTheme.bodyLarge?.fontFamily, isNot('JetBrainsMono'));
        expect(result.textTheme.titleLarge?.fontFamily, isNot('JetBrainsMono'));
        expect(
          result.textTheme.headlineMedium?.fontFamily,
          isNot('JetBrainsMono'),
        );
        // Should be a known system font
        expect(
          result.textTheme.bodyLarge?.fontFamily,
          anyOf('.AppleSystemUIFont', '.SF Pro Text', 'Roboto', 'Segoe UI'),
        );
      });

      test('applies Inter font when fontMode is accessibility', () {
        final baseTheme = AppTheme.darkTheme(AccentColors.magenta);
        final result = AccessibilityThemeAdapter.applyPreferences(
          baseTheme: baseTheme,
          preferences: const AccessibilityPreferences(
            fontMode: FontMode.accessibility,
          ),
        );

        expect(result.textTheme.bodyLarge?.fontFamily, 'Inter');
        expect(result.textTheme.titleLarge?.fontFamily, 'Inter');
        expect(result.textTheme.headlineMedium?.fontFamily, 'Inter');
      });

      test('applies compact visual density', () {
        final baseTheme = AppTheme.darkTheme(AccentColors.magenta);
        final result = AccessibilityThemeAdapter.applyPreferences(
          baseTheme: baseTheme,
          preferences: const AccessibilityPreferences(
            densityMode: DensityMode.compact,
          ),
        );

        expect(result.visualDensity.horizontal, -1.0);
        expect(result.visualDensity.vertical, -1.0);
      });

      test('applies large touch visual density', () {
        final baseTheme = AppTheme.darkTheme(AccentColors.magenta);
        final result = AccessibilityThemeAdapter.applyPreferences(
          baseTheme: baseTheme,
          preferences: const AccessibilityPreferences(
            densityMode: DensityMode.largeTouch,
          ),
        );

        expect(result.visualDensity.horizontal, 1.0);
        expect(result.visualDensity.vertical, 1.0);
      });

      test('applies high contrast adjustments to dark theme', () {
        final baseTheme = AppTheme.darkTheme(AccentColors.magenta);
        final result = AccessibilityThemeAdapter.applyPreferences(
          baseTheme: baseTheme,
          preferences: const AccessibilityPreferences(
            contrastMode: ContrastMode.high,
          ),
        );

        // High contrast should use pure white for onSurface
        expect(result.colorScheme.onSurface, Colors.white);
        // Borders should be more visible
        expect(
          result.colorScheme.outline.computeLuminance(),
          greaterThan(baseTheme.colorScheme.outline.computeLuminance()),
        );
      });

      test('applies high contrast adjustments to light theme', () {
        final baseTheme = AppTheme.lightTheme(AccentColors.magenta);
        final result = AccessibilityThemeAdapter.applyPreferences(
          baseTheme: baseTheme,
          preferences: const AccessibilityPreferences(
            contrastMode: ContrastMode.high,
          ),
        );

        // High contrast should use pure black for onSurface
        expect(result.colorScheme.onSurface, const Color(0xFF000000));
      });

      test('applies shrinkWrap tap target for compact mode', () {
        final baseTheme = AppTheme.darkTheme(AccentColors.magenta);
        final result = AccessibilityThemeAdapter.applyPreferences(
          baseTheme: baseTheme,
          preferences: const AccessibilityPreferences(
            densityMode: DensityMode.compact,
          ),
        );

        expect(result.materialTapTargetSize, MaterialTapTargetSize.shrinkWrap);
      });

      test('applies padded tap target for large touch mode', () {
        final baseTheme = AppTheme.darkTheme(AccentColors.magenta);
        final result = AccessibilityThemeAdapter.applyPreferences(
          baseTheme: baseTheme,
          preferences: const AccessibilityPreferences(
            densityMode: DensityMode.largeTouch,
          ),
        );

        expect(result.materialTapTargetSize, MaterialTapTargetSize.padded);
      });
    });

    group('effectiveTextScaler', () {
      test('returns system scale clamped for systemDefault mode', () {
        final scaler = AccessibilityThemeAdapter.effectiveTextScaler(
          preferences: const AccessibilityPreferences(
            textScaleMode: TextScaleMode.systemDefault,
          ),
          systemTextScale: 1.2,
        );

        expect(scaler.scale(1.0), 1.2);
      });

      test('clamps excessive system scale to max safe scale', () {
        final scaler = AccessibilityThemeAdapter.effectiveTextScaler(
          preferences: const AccessibilityPreferences(
            textScaleMode: TextScaleMode.systemDefault,
          ),
          systemTextScale: 3.0,
        );

        expect(scaler.scale(1.0), TextScaleMode.maxSafeScale);
      });

      test('returns 1.0 for socialmeshDefault mode', () {
        final scaler = AccessibilityThemeAdapter.effectiveTextScaler(
          preferences: const AccessibilityPreferences(
            textScaleMode: TextScaleMode.socialmeshDefault,
          ),
          systemTextScale: 1.5,
        );

        expect(scaler.scale(1.0), 1.0);
      });

      test('returns 1.15 for large mode', () {
        final scaler = AccessibilityThemeAdapter.effectiveTextScaler(
          preferences: const AccessibilityPreferences(
            textScaleMode: TextScaleMode.large,
          ),
          systemTextScale: 1.0,
        );

        expect(scaler.scale(1.0), 1.15);
      });

      test('returns 1.3 for extraLarge mode', () {
        final scaler = AccessibilityThemeAdapter.effectiveTextScaler(
          preferences: const AccessibilityPreferences(
            textScaleMode: TextScaleMode.extraLarge,
          ),
          systemTextScale: 1.0,
        );

        expect(scaler.scale(1.0), 1.3);
      });
    });

    group('animationDuration', () {
      test('returns base duration when reduce motion is off', () {
        const baseDuration = Duration(milliseconds: 300);
        final result = AccessibilityThemeAdapter.animationDuration(
          baseDuration,
          AccessibilityPreferences.defaults,
        );

        expect(result, baseDuration);
      });

      test('returns near-instant duration when reduce motion is on', () {
        const baseDuration = Duration(milliseconds: 300);
        final result = AccessibilityThemeAdapter.animationDuration(
          baseDuration,
          const AccessibilityPreferences(reduceMotionMode: ReduceMotionMode.on),
        );

        expect(result.inMilliseconds, 1);
      });
    });

    group('animationCurve', () {
      test('returns base curve when reduce motion is off', () {
        const baseCurve = Curves.easeInOut;
        final result = AccessibilityThemeAdapter.animationCurve(
          baseCurve,
          AccessibilityPreferences.defaults,
        );

        expect(result, baseCurve);
      });

      test('returns linear curve when reduce motion is on', () {
        const baseCurve = Curves.easeInOut;
        final result = AccessibilityThemeAdapter.animationCurve(
          baseCurve,
          const AccessibilityPreferences(reduceMotionMode: ReduceMotionMode.on),
        );

        expect(result, Curves.linear);
      });
    });

    group('isTextScaleSafe', () {
      test('returns true for scale within bounds', () {
        expect(AccessibilityThemeAdapter.isTextScaleSafe(1.0), true);
        expect(AccessibilityThemeAdapter.isTextScaleSafe(1.3), true);
        expect(AccessibilityThemeAdapter.isTextScaleSafe(0.9), true);
      });

      test('returns false for scale exceeding max', () {
        expect(AccessibilityThemeAdapter.isTextScaleSafe(1.6), false);
        expect(AccessibilityThemeAdapter.isTextScaleSafe(2.0), false);
      });

      test('returns false for scale below min', () {
        expect(AccessibilityThemeAdapter.isTextScaleSafe(0.7), false);
        expect(AccessibilityThemeAdapter.isTextScaleSafe(0.5), false);
      });
    });

    group('getMinTapTargetSize', () {
      test('returns 44.0 for compact mode', () {
        final size = AccessibilityThemeAdapter.getMinTapTargetSize(
          const AccessibilityPreferences(densityMode: DensityMode.compact),
        );
        expect(size, 44.0);
      });

      test('returns 48.0 for comfortable mode', () {
        final size = AccessibilityThemeAdapter.getMinTapTargetSize(
          const AccessibilityPreferences(densityMode: DensityMode.comfortable),
        );
        expect(size, 48.0);
      });

      test('returns 56.0 for large touch mode', () {
        final size = AccessibilityThemeAdapter.getMinTapTargetSize(
          const AccessibilityPreferences(densityMode: DensityMode.largeTouch),
        );
        expect(size, 56.0);
      });
    });

    group('scaledSpacing', () {
      test('returns base spacing for comfortable mode', () {
        final spacing = AccessibilityThemeAdapter.scaledSpacing(
          16.0,
          const AccessibilityPreferences(densityMode: DensityMode.comfortable),
        );
        expect(spacing, 16.0);
      });

      test('returns reduced spacing for compact mode', () {
        final spacing = AccessibilityThemeAdapter.scaledSpacing(
          16.0,
          const AccessibilityPreferences(densityMode: DensityMode.compact),
        );
        expect(spacing, 16.0 * 0.85);
      });

      test('returns increased spacing for large touch mode', () {
        final spacing = AccessibilityThemeAdapter.scaledSpacing(
          16.0,
          const AccessibilityPreferences(densityMode: DensityMode.largeTouch),
        );
        expect(spacing, 16.0 * 1.25);
      });
    });
  });

  group('AccessibilityDurationExtension', () {
    test('withAccessibility returns base duration when motion not reduced', () {
      const baseDuration = Duration(milliseconds: 200);
      final result = baseDuration.withAccessibility(
        AccessibilityPreferences.defaults,
      );
      expect(result, baseDuration);
    });

    test('withAccessibility returns instant when motion reduced', () {
      const baseDuration = Duration(milliseconds: 200);
      final result = baseDuration.withAccessibility(
        const AccessibilityPreferences(reduceMotionMode: ReduceMotionMode.on),
      );
      expect(result.inMilliseconds, 1);
    });
  });

  group('AccessibilitySpacingExtension', () {
    test('withDensity returns base spacing for comfortable', () {
      const baseSpacing = 16.0;
      final result = baseSpacing.withDensity(AccessibilityPreferences.defaults);
      expect(result, 16.0);
    });

    test('withDensity scales spacing for compact', () {
      const baseSpacing = 16.0;
      final result = baseSpacing.withDensity(
        const AccessibilityPreferences(densityMode: DensityMode.compact),
      );
      expect(result, 16.0 * 0.85);
    });
  });

  group('AccessibleTapTarget widget', () {
    testWidgets('enforces minimum tap target size', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: AccessibleTapTarget(
                  child: Container(width: 20, height: 20, color: Colors.red),
                ),
              ),
            ),
          ),
        ),
      );

      // Find the ConstrainedBox inside AccessibleTapTarget (descendant of AccessibleTapTarget)
      final constrainedBox = tester.widget<ConstrainedBox>(
        find
            .descendant(
              of: find.byType(AccessibleTapTarget),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );

      // Default minimum should be 48.0 (comfortable mode)
      expect(constrainedBox.constraints.minWidth, 48.0);
      expect(constrainedBox.constraints.minHeight, 48.0);
    });

    testWidgets('responds to tap when onTap provided', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: AccessibleTapTarget(
                  onTap: () => tapped = true,
                  child: const Icon(Icons.add),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AccessibleTapTarget));
      expect(tapped, true);
    });
  });

  group('AccessibilityWrapper widget', () {
    testWidgets('applies text scaling for non-system mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accessibilityPreferencesProvider.overrideWith(() {
              return _TestAccessibilityNotifier(
                const AccessibilityPreferences(
                  textScaleMode: TextScaleMode.large,
                ),
              );
            }),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return AccessibilityWrapper(
                  child: Scaffold(
                    body: Builder(
                      builder: (innerContext) {
                        // Check that MediaQuery has been updated
                        final mediaQuery = MediaQuery.of(innerContext);
                        return Text(
                          'Test',
                          key: const Key('test_text'),
                          style: TextStyle(
                            fontSize: 16.0 * mediaQuery.textScaler.scale(1.0),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the text widget exists
      expect(find.byKey(const Key('test_text')), findsOneWidget);
    });

    testWidgets('provides accessibility preferences to descendants', (
      tester,
    ) async {
      late AccessibilityPreferences capturedPrefs;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accessibilityPreferencesProvider.overrideWith(() {
              return _TestAccessibilityNotifier(
                const AccessibilityPreferences(
                  fontMode: FontMode.accessibility,
                  textScaleMode: TextScaleMode.large,
                ),
              );
            }),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return AccessibilityWrapper(
                  child: Scaffold(
                    body: Builder(
                      builder: (innerContext) {
                        capturedPrefs = innerContext.accessibilityPreferences;
                        return const Text('Test');
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(capturedPrefs.fontMode, FontMode.accessibility);
      expect(capturedPrefs.textScaleMode, TextScaleMode.large);
    });

    testWidgets('context extensions return correct values', (tester) async {
      late bool reduceMotion;
      late bool highContrast;
      late double minTapTarget;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accessibilityPreferencesProvider.overrideWith(() {
              return _TestAccessibilityNotifier(
                const AccessibilityPreferences(
                  contrastMode: ContrastMode.high,
                  reduceMotionMode: ReduceMotionMode.on,
                  densityMode: DensityMode.largeTouch,
                ),
              );
            }),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return AccessibilityWrapper(
                  child: Scaffold(
                    body: Builder(
                      builder: (innerContext) {
                        reduceMotion = innerContext.reduceMotion;
                        highContrast = innerContext.highContrast;
                        minTapTarget = innerContext.minTapTargetSize;
                        return const Text('Test');
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(reduceMotion, true);
      expect(highContrast, true);
      expect(minTapTarget, 56.0);
    });
  });

  group('AccessibleAnimatedContainer', () {
    testWidgets('uses zero duration when reduce motion enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accessibilityPreferencesProvider.overrideWith(() {
              return _TestAccessibilityNotifier(
                const AccessibilityPreferences(
                  reduceMotionMode: ReduceMotionMode.on,
                ),
              );
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AccessibleAnimatedContainer(
                duration: const Duration(milliseconds: 300),
                color: Colors.red,
                child: const SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      );

      // Find the AnimatedContainer
      final animatedContainer = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );

      // Duration should be zero when reduce motion is enabled
      expect(animatedContainer.duration, Duration.zero);
    });

    testWidgets('uses normal duration when reduce motion disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AccessibleAnimatedContainer(
                duration: const Duration(milliseconds: 300),
                color: Colors.red,
                child: const SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      );

      final animatedContainer = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );

      expect(animatedContainer.duration, const Duration(milliseconds: 300));
    });
  });

  group('AccessibleAnimatedOpacity', () {
    testWidgets('uses zero duration when reduce motion enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accessibilityPreferencesProvider.overrideWith(() {
              return _TestAccessibilityNotifier(
                const AccessibilityPreferences(
                  reduceMotionMode: ReduceMotionMode.on,
                ),
              );
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AccessibleAnimatedOpacity(
                opacity: 0.5,
                duration: const Duration(milliseconds: 200),
                child: const Text('Test'),
              ),
            ),
          ),
        ),
      );

      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );

      expect(animatedOpacity.duration, Duration.zero);
    });
  });
}

/// Test notifier that returns fixed preferences
class _TestAccessibilityNotifier extends Notifier<AccessibilityPreferences>
    implements AccessibilityPreferencesNotifier {
  _TestAccessibilityNotifier(this._prefs);

  final AccessibilityPreferences _prefs;

  @override
  AccessibilityPreferences build() => _prefs;

  @override
  Future<void> setFontMode(FontMode mode) async {
    state = state.copyWith(fontMode: mode);
  }

  @override
  Future<void> setTextScaleMode(TextScaleMode mode) async {
    state = state.copyWith(textScaleMode: mode);
  }

  @override
  Future<void> setDensityMode(DensityMode mode) async {
    state = state.copyWith(densityMode: mode);
  }

  @override
  Future<void> setContrastMode(ContrastMode mode) async {
    state = state.copyWith(contrastMode: mode);
  }

  @override
  Future<void> setReduceMotionMode(ReduceMotionMode mode) async {
    state = state.copyWith(reduceMotionMode: mode);
  }

  @override
  Future<void> resetToDefaults() async {
    state = AccessibilityPreferences.defaults;
  }

  @override
  Future<void> updateAll(AccessibilityPreferences preferences) async {
    state = preferences;
  }
}
