// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/accessibility_preferences.dart';

void main() {
  group('AccessibilityPreferences', () {
    group('defaults', () {
      test('default preferences have expected values', () {
        const prefs = AccessibilityPreferences.defaults;

        expect(prefs.fontMode, FontMode.branded);
        expect(prefs.textScaleMode, TextScaleMode.socialmeshDefault);
        expect(prefs.densityMode, DensityMode.comfortable);
        expect(prefs.contrastMode, ContrastMode.normal);
        expect(prefs.reduceMotionMode, ReduceMotionMode.off);
      });

      test('default constructor matches defaults constant', () {
        const prefs = AccessibilityPreferences();

        expect(prefs, AccessibilityPreferences.defaults);
      });

      test('hasCustomSettings is false for defaults', () {
        expect(AccessibilityPreferences.defaults.hasCustomSettings, false);
      });
    });

    group('copyWith', () {
      test('copyWith creates a new instance with updated values', () {
        const original = AccessibilityPreferences.defaults;
        final modified = original.copyWith(fontMode: FontMode.accessibility);

        expect(modified.fontMode, FontMode.accessibility);
        expect(modified.textScaleMode, original.textScaleMode);
        expect(modified.densityMode, original.densityMode);
        expect(modified.contrastMode, original.contrastMode);
        expect(modified.reduceMotionMode, original.reduceMotionMode);
      });

      test('copyWith with no arguments returns equal instance', () {
        const original = AccessibilityPreferences.defaults;
        final copy = original.copyWith();

        expect(copy, original);
      });

      test('copyWith can update all fields', () {
        const original = AccessibilityPreferences.defaults;
        final modified = original.copyWith(
          fontMode: FontMode.system,
          textScaleMode: TextScaleMode.large,
          densityMode: DensityMode.largeTouch,
          contrastMode: ContrastMode.high,
          reduceMotionMode: ReduceMotionMode.on,
        );

        expect(modified.fontMode, FontMode.system);
        expect(modified.textScaleMode, TextScaleMode.large);
        expect(modified.densityMode, DensityMode.largeTouch);
        expect(modified.contrastMode, ContrastMode.high);
        expect(modified.reduceMotionMode, ReduceMotionMode.on);
      });
    });

    group('hasCustomSettings', () {
      test('returns true when fontMode is changed', () {
        final prefs = AccessibilityPreferences.defaults.copyWith(
          fontMode: FontMode.accessibility,
        );
        expect(prefs.hasCustomSettings, true);
      });

      test('returns true when textScaleMode is changed', () {
        final prefs = AccessibilityPreferences.defaults.copyWith(
          textScaleMode: TextScaleMode.large,
        );
        expect(prefs.hasCustomSettings, true);
      });

      test('returns true when densityMode is changed', () {
        final prefs = AccessibilityPreferences.defaults.copyWith(
          densityMode: DensityMode.compact,
        );
        expect(prefs.hasCustomSettings, true);
      });

      test('returns true when contrastMode is changed', () {
        final prefs = AccessibilityPreferences.defaults.copyWith(
          contrastMode: ContrastMode.high,
        );
        expect(prefs.hasCustomSettings, true);
      });

      test('returns true when reduceMotionMode is changed', () {
        final prefs = AccessibilityPreferences.defaults.copyWith(
          reduceMotionMode: ReduceMotionMode.on,
        );
        expect(prefs.hasCustomSettings, true);
      });
    });

    group('serialization', () {
      test('toJson includes all fields and version', () {
        const prefs = AccessibilityPreferences(
          fontMode: FontMode.accessibility,
          textScaleMode: TextScaleMode.large,
          densityMode: DensityMode.largeTouch,
          contrastMode: ContrastMode.high,
          reduceMotionMode: ReduceMotionMode.on,
        );

        final json = prefs.toJson();

        expect(json['fontMode'], 'accessibility');
        expect(json['textScaleMode'], 'large');
        expect(json['densityMode'], 'largeTouch');
        expect(json['contrastMode'], 'high');
        expect(json['reduceMotionMode'], 'on');
        expect(json['version'], 1);
      });

      test('toJsonString produces valid JSON', () {
        const prefs = AccessibilityPreferences.defaults;
        final jsonString = prefs.toJsonString();

        expect(() => jsonDecode(jsonString), returnsNormally);
      });

      test('fromJson deserializes correctly', () {
        final json = {
          'fontMode': 'system',
          'textScaleMode': 'extraLarge',
          'densityMode': 'compact',
          'contrastMode': 'high',
          'reduceMotionMode': 'on',
          'version': 1,
        };

        final prefs = AccessibilityPreferences.fromJson(json);

        expect(prefs.fontMode, FontMode.system);
        expect(prefs.textScaleMode, TextScaleMode.extraLarge);
        expect(prefs.densityMode, DensityMode.compact);
        expect(prefs.contrastMode, ContrastMode.high);
        expect(prefs.reduceMotionMode, ReduceMotionMode.on);
      });

      test('fromJsonString deserializes correctly', () {
        const prefs = AccessibilityPreferences(
          fontMode: FontMode.accessibility,
          textScaleMode: TextScaleMode.large,
          densityMode: DensityMode.comfortable,
          contrastMode: ContrastMode.normal,
          reduceMotionMode: ReduceMotionMode.off,
        );

        final jsonString = prefs.toJsonString();
        final restored = AccessibilityPreferences.fromJsonString(jsonString);

        expect(restored, prefs);
      });

      test('round-trip serialization preserves all values', () {
        const original = AccessibilityPreferences(
          fontMode: FontMode.system,
          textScaleMode: TextScaleMode.large,
          densityMode: DensityMode.largeTouch,
          contrastMode: ContrastMode.high,
          reduceMotionMode: ReduceMotionMode.on,
        );

        final jsonString = original.toJsonString();
        final restored = AccessibilityPreferences.fromJsonString(jsonString);

        expect(restored.fontMode, original.fontMode);
        expect(restored.textScaleMode, original.textScaleMode);
        expect(restored.densityMode, original.densityMode);
        expect(restored.contrastMode, original.contrastMode);
        expect(restored.reduceMotionMode, original.reduceMotionMode);
      });
    });

    group('deserialization fallbacks', () {
      test('fromJsonString returns defaults for null input', () {
        final prefs = AccessibilityPreferences.fromJsonString(null);
        expect(prefs, AccessibilityPreferences.defaults);
      });

      test('fromJsonString returns defaults for empty string', () {
        final prefs = AccessibilityPreferences.fromJsonString('');
        expect(prefs, AccessibilityPreferences.defaults);
      });

      test('fromJsonString returns defaults for invalid JSON', () {
        final prefs = AccessibilityPreferences.fromJsonString('not valid json');
        expect(prefs, AccessibilityPreferences.defaults);
      });

      test('fromJson uses defaults for missing fields', () {
        final json = <String, dynamic>{'version': 1};
        final prefs = AccessibilityPreferences.fromJson(json);

        expect(prefs.fontMode, FontMode.branded);
        expect(prefs.textScaleMode, TextScaleMode.socialmeshDefault);
        expect(prefs.densityMode, DensityMode.comfortable);
        expect(prefs.contrastMode, ContrastMode.normal);
        expect(prefs.reduceMotionMode, ReduceMotionMode.off);
      });

      test('fromJson uses defaults for invalid enum values', () {
        final json = {
          'fontMode': 'invalid_value',
          'textScaleMode': 'unknown',
          'densityMode': 'nonexistent',
          'contrastMode': 'bad',
          'reduceMotionMode': 'wrong',
          'version': 1,
        };

        final prefs = AccessibilityPreferences.fromJson(json);

        expect(prefs.fontMode, FontMode.branded);
        expect(prefs.textScaleMode, TextScaleMode.socialmeshDefault);
        expect(prefs.densityMode, DensityMode.comfortable);
        expect(prefs.contrastMode, ContrastMode.normal);
        expect(prefs.reduceMotionMode, ReduceMotionMode.off);
      });

      test('fromJson handles null values gracefully', () {
        final json = {
          'fontMode': null,
          'textScaleMode': null,
          'densityMode': null,
          'contrastMode': null,
          'reduceMotionMode': null,
          'version': 1,
        };

        final prefs = AccessibilityPreferences.fromJson(json);

        expect(prefs.fontMode, FontMode.branded);
        expect(prefs.textScaleMode, TextScaleMode.socialmeshDefault);
        expect(prefs.densityMode, DensityMode.comfortable);
        expect(prefs.contrastMode, ContrastMode.normal);
        expect(prefs.reduceMotionMode, ReduceMotionMode.off);
      });
    });

    group('equality', () {
      test('equal instances are equal', () {
        const a = AccessibilityPreferences(
          fontMode: FontMode.branded,
          textScaleMode: TextScaleMode.large,
        );
        const b = AccessibilityPreferences(
          fontMode: FontMode.branded,
          textScaleMode: TextScaleMode.large,
        );

        expect(a, b);
        expect(a.hashCode, b.hashCode);
      });

      test('different instances are not equal', () {
        const a = AccessibilityPreferences(fontMode: FontMode.branded);
        const b = AccessibilityPreferences(fontMode: FontMode.system);

        expect(a, isNot(b));
      });

      test('identical instances are equal', () {
        const prefs = AccessibilityPreferences.defaults;
        expect(identical(prefs, prefs), true);
        expect(prefs == prefs, true);
      });
    });
  });

  group('FontMode', () {
    test('all values have display names', () {
      for (final mode in FontMode.values) {
        expect(mode.displayName, isNotEmpty);
      }
    });

    test('all values have descriptions', () {
      for (final mode in FontMode.values) {
        expect(mode.description, isNotEmpty);
      }
    });

    test('fontFamily returns correct values', () {
      expect(FontMode.branded.fontFamily, 'JetBrainsMono');
      expect(FontMode.system.fontFamily, '');
      expect(FontMode.accessibility.fontFamily, 'Inter');
    });
  });

  group('TextScaleMode', () {
    test('all values have display names', () {
      for (final mode in TextScaleMode.values) {
        expect(mode.displayName, isNotEmpty);
      }
    });

    test('all values have descriptions', () {
      for (final mode in TextScaleMode.values) {
        expect(mode.description, isNotEmpty);
      }
    });

    test('scaleFactor values are valid', () {
      expect(TextScaleMode.systemDefault.scaleFactor, isNull);
      expect(TextScaleMode.socialmeshDefault.scaleFactor, 1.0);
      expect(TextScaleMode.large.scaleFactor, 1.15);
      expect(TextScaleMode.extraLarge.scaleFactor, 1.3);
    });

    test('getEffectiveScale respects safe bounds', () {
      expect(
        TextScaleMode.systemDefault.getEffectiveScale(2.0),
        TextScaleMode.maxSafeScale,
      );
      expect(
        TextScaleMode.systemDefault.getEffectiveScale(0.5),
        TextScaleMode.minScale,
      );
      expect(TextScaleMode.systemDefault.getEffectiveScale(1.0), 1.0);
    });

    test('getEffectiveScale returns scale factor for non-system modes', () {
      expect(TextScaleMode.large.getEffectiveScale(1.0), 1.15);
      expect(TextScaleMode.extraLarge.getEffectiveScale(1.0), 1.3);
    });
  });

  group('DensityMode', () {
    test('all values have display names', () {
      for (final mode in DensityMode.values) {
        expect(mode.displayName, isNotEmpty);
      }
    });

    test('all values have descriptions', () {
      for (final mode in DensityMode.values) {
        expect(mode.description, isNotEmpty);
      }
    });

    test('minTapTargetSize returns reasonable values', () {
      expect(DensityMode.compact.minTapTargetSize, greaterThanOrEqualTo(44.0));
      expect(
        DensityMode.comfortable.minTapTargetSize,
        greaterThanOrEqualTo(48.0),
      );
      expect(
        DensityMode.largeTouch.minTapTargetSize,
        greaterThanOrEqualTo(56.0),
      );
    });

    test('spacingMultiplier values are valid', () {
      expect(DensityMode.compact.spacingMultiplier, lessThan(1.0));
      expect(DensityMode.comfortable.spacingMultiplier, 1.0);
      expect(DensityMode.largeTouch.spacingMultiplier, greaterThan(1.0));
    });
  });

  group('ContrastMode', () {
    test('isHighContrast returns correct values', () {
      expect(ContrastMode.normal.isHighContrast, false);
      expect(ContrastMode.high.isHighContrast, true);
    });
  });

  group('ReduceMotionMode', () {
    test('shouldReduceMotion returns correct values', () {
      expect(ReduceMotionMode.off.shouldReduceMotion, false);
      expect(ReduceMotionMode.on.shouldReduceMotion, true);
    });

    test('durationMultiplier returns correct values', () {
      expect(ReduceMotionMode.off.durationMultiplier, 1.0);
      expect(ReduceMotionMode.on.durationMultiplier, 0.0);
    });
  });
}
