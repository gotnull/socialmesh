// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/accessibility_preferences.dart';
import 'package:socialmesh/providers/accessibility_providers.dart';

void main() {
  group('AccessibilityPreferencesNotifier', () {
    test('initial state is defaults', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final prefs = container.read(accessibilityPreferencesProvider);

      expect(prefs.fontMode, FontMode.branded);
      expect(prefs.textScaleMode, TextScaleMode.socialmeshDefault);
      expect(prefs.densityMode, DensityMode.comfortable);
      expect(prefs.contrastMode, ContrastMode.normal);
      expect(prefs.reduceMotionMode, ReduceMotionMode.off);
    });
  });

  group('effectiveTextScaleProvider', () {
    test('returns 1.0 when using system default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Default is socialmeshDefault which has scale 1.0
      final scale = container.read(effectiveTextScaleProvider);
      expect(scale, 1.0);
    });

    test('returns scale factor for explicit mode', () {
      final container = ProviderContainer(
        overrides: [
          accessibilityPreferencesProvider.overrideWith(() {
            return _MockAccessibilityNotifier(
              const AccessibilityPreferences(
                textScaleMode: TextScaleMode.large,
              ),
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      final scale = container.read(effectiveTextScaleProvider);
      expect(scale, 1.15);
    });
  });

  group('useSystemTextScaleProvider', () {
    test('returns false for default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final useSystem = container.read(useSystemTextScaleProvider);
      expect(useSystem, false);
    });

    test('returns true when set to systemDefault', () {
      final container = ProviderContainer(
        overrides: [
          accessibilityPreferencesProvider.overrideWith(() {
            return _MockAccessibilityNotifier(
              const AccessibilityPreferences(
                textScaleMode: TextScaleMode.systemDefault,
              ),
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      final useSystem = container.read(useSystemTextScaleProvider);
      expect(useSystem, true);
    });
  });

  group('effectiveVisualDensityProvider', () {
    test('returns comfortable density by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final density = container.read(effectiveVisualDensityProvider);
      expect(density.horizontal, 0.0);
      expect(density.vertical, 0.0);
    });

    test('returns compact density when set', () {
      final container = ProviderContainer(
        overrides: [
          accessibilityPreferencesProvider.overrideWith(() {
            return _MockAccessibilityNotifier(
              const AccessibilityPreferences(densityMode: DensityMode.compact),
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      final density = container.read(effectiveVisualDensityProvider);
      expect(density.horizontal, -1.0);
      expect(density.vertical, -1.0);
    });

    test('returns large touch density when set', () {
      final container = ProviderContainer(
        overrides: [
          accessibilityPreferencesProvider.overrideWith(() {
            return _MockAccessibilityNotifier(
              const AccessibilityPreferences(
                densityMode: DensityMode.largeTouch,
              ),
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      final density = container.read(effectiveVisualDensityProvider);
      expect(density.horizontal, 1.0);
      expect(density.vertical, 1.0);
    });
  });

  group('highContrastEnabledProvider', () {
    test('returns false by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final isHighContrast = container.read(highContrastEnabledProvider);
      expect(isHighContrast, false);
    });

    test('returns true when high contrast enabled', () {
      final container = ProviderContainer(
        overrides: [
          accessibilityPreferencesProvider.overrideWith(() {
            return _MockAccessibilityNotifier(
              const AccessibilityPreferences(contrastMode: ContrastMode.high),
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      final isHighContrast = container.read(highContrastEnabledProvider);
      expect(isHighContrast, true);
    });
  });

  group('reduceMotionEnabledProvider', () {
    test('returns false by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final reduceMotion = container.read(reduceMotionEnabledProvider);
      expect(reduceMotion, false);
    });

    test('returns true when reduce motion enabled', () {
      final container = ProviderContainer(
        overrides: [
          accessibilityPreferencesProvider.overrideWith(() {
            return _MockAccessibilityNotifier(
              const AccessibilityPreferences(
                reduceMotionMode: ReduceMotionMode.on,
              ),
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      final reduceMotion = container.read(reduceMotionEnabledProvider);
      expect(reduceMotion, true);
    });
  });

  group('animationDurationMultiplierProvider', () {
    test('returns 1.0 by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final multiplier = container.read(animationDurationMultiplierProvider);
      expect(multiplier, 1.0);
    });

    test('returns 0.0 when reduce motion enabled', () {
      final container = ProviderContainer(
        overrides: [
          accessibilityPreferencesProvider.overrideWith(() {
            return _MockAccessibilityNotifier(
              const AccessibilityPreferences(
                reduceMotionMode: ReduceMotionMode.on,
              ),
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      final multiplier = container.read(animationDurationMultiplierProvider);
      expect(multiplier, 0.0);
    });
  });

  group('effectiveFontFamilyProvider', () {
    test('returns JetBrainsMono by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final fontFamily = container.read(effectiveFontFamilyProvider);
      expect(fontFamily, 'JetBrainsMono');
    });

    test('returns null for system font', () {
      final container = ProviderContainer(
        overrides: [
          accessibilityPreferencesProvider.overrideWith(() {
            return _MockAccessibilityNotifier(
              const AccessibilityPreferences(fontMode: FontMode.system),
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      final fontFamily = container.read(effectiveFontFamilyProvider);
      expect(fontFamily, isNull);
    });

    test('returns Inter for accessibility mode', () {
      final container = ProviderContainer(
        overrides: [
          accessibilityPreferencesProvider.overrideWith(() {
            return _MockAccessibilityNotifier(
              const AccessibilityPreferences(fontMode: FontMode.accessibility),
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      final fontFamily = container.read(effectiveFontFamilyProvider);
      expect(fontFamily, 'Inter');
    });
  });

  group('minTapTargetSizeProvider', () {
    test('returns 48.0 by default (comfortable)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final size = container.read(minTapTargetSizeProvider);
      expect(size, 48.0);
    });

    test('returns 44.0 for compact mode', () {
      final container = ProviderContainer(
        overrides: [
          accessibilityPreferencesProvider.overrideWith(() {
            return _MockAccessibilityNotifier(
              const AccessibilityPreferences(densityMode: DensityMode.compact),
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      final size = container.read(minTapTargetSizeProvider);
      expect(size, 44.0);
    });

    test('returns 56.0 for large touch mode', () {
      final container = ProviderContainer(
        overrides: [
          accessibilityPreferencesProvider.overrideWith(() {
            return _MockAccessibilityNotifier(
              const AccessibilityPreferences(
                densityMode: DensityMode.largeTouch,
              ),
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      final size = container.read(minTapTargetSizeProvider);
      expect(size, 56.0);
    });
  });

  group('spacingMultiplierProvider', () {
    test('returns 1.0 by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final multiplier = container.read(spacingMultiplierProvider);
      expect(multiplier, 1.0);
    });

    test('returns 0.85 for compact mode', () {
      final container = ProviderContainer(
        overrides: [
          accessibilityPreferencesProvider.overrideWith(() {
            return _MockAccessibilityNotifier(
              const AccessibilityPreferences(densityMode: DensityMode.compact),
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      final multiplier = container.read(spacingMultiplierProvider);
      expect(multiplier, 0.85);
    });

    test('returns 1.25 for large touch mode', () {
      final container = ProviderContainer(
        overrides: [
          accessibilityPreferencesProvider.overrideWith(() {
            return _MockAccessibilityNotifier(
              const AccessibilityPreferences(
                densityMode: DensityMode.largeTouch,
              ),
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      final multiplier = container.read(spacingMultiplierProvider);
      expect(multiplier, 1.25);
    });
  });

  group('hasCustomAccessibilitySettingsProvider', () {
    test('returns false for defaults', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final hasCustom = container.read(hasCustomAccessibilitySettingsProvider);
      expect(hasCustom, false);
    });

    test('returns true when any setting is changed', () {
      final container = ProviderContainer(
        overrides: [
          accessibilityPreferencesProvider.overrideWith(() {
            return _MockAccessibilityNotifier(
              const AccessibilityPreferences(
                reduceMotionMode: ReduceMotionMode.on,
              ),
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      final hasCustom = container.read(hasCustomAccessibilitySettingsProvider);
      expect(hasCustom, true);
    });
  });
}

/// Mock notifier for testing that returns a fixed preferences state
class _MockAccessibilityNotifier extends Notifier<AccessibilityPreferences>
    implements AccessibilityPreferencesNotifier {
  _MockAccessibilityNotifier(this._initialState);

  final AccessibilityPreferences _initialState;

  @override
  AccessibilityPreferences build() => _initialState;

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
