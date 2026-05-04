// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/widgets/chat_bubble_text.dart';
import 'package:socialmesh/models/accessibility_preferences.dart';
import 'package:socialmesh/providers/accessibility_providers.dart';

void main() {
  group('chatBubbleBodyStyle', () {
    testWidgets('returns base size when textScaleMode is socialmeshDefault', (
      tester,
    ) async {
      TextStyle? captured;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accessibilityPreferencesProvider.overrideWith(
              () => _MockAccessibilityNotifier(
                initial: TextScaleMode.socialmeshDefault,
              ),
            ),
          ],
          child: _Capture(
            baseFontSize: 14,
            color: const Color(0xFF000000),
            onResolve: (style) => captured = style,
          ),
        ),
      );

      expect(captured, isNotNull);
      expect(captured!.fontSize, 14);
      expect(captured!.color, const Color(0xFF000000));
    });

    testWidgets('returns base size when textScaleMode is systemDefault', (
      tester,
    ) async {
      // For systemDefault the helper returns the un-multiplied size; the
      // app's MediaQuery.textScaler handles the system scale on top.
      TextStyle? captured;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accessibilityPreferencesProvider.overrideWith(
              () => _MockAccessibilityNotifier(
                initial: TextScaleMode.systemDefault,
              ),
            ),
          ],
          child: _Capture(
            baseFontSize: 14,
            onResolve: (style) => captured = style,
          ),
        ),
      );

      expect(captured!.fontSize, 14);
    });

    testWidgets('scales by 1.15 in large mode', (tester) async {
      TextStyle? captured;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accessibilityPreferencesProvider.overrideWith(
              () => _MockAccessibilityNotifier(initial: TextScaleMode.large),
            ),
          ],
          child: _Capture(
            baseFontSize: 14,
            onResolve: (style) => captured = style,
          ),
        ),
      );

      expect(captured!.fontSize, closeTo(14 * 1.15, 1e-9));
    });

    testWidgets('scales by 1.3 in extraLarge mode', (tester) async {
      TextStyle? captured;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accessibilityPreferencesProvider.overrideWith(
              () =>
                  _MockAccessibilityNotifier(initial: TextScaleMode.extraLarge),
            ),
          ],
          child: _Capture(
            baseFontSize: 14,
            onResolve: (style) => captured = style,
          ),
        ),
      );

      expect(captured!.fontSize, closeTo(14 * 1.3, 1e-9));
    });

    testWidgets('scales 15pt incoming bubbles too (Meshtastic/MeshCore)', (
      tester,
    ) async {
      TextStyle? captured;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accessibilityPreferencesProvider.overrideWith(
              () => _MockAccessibilityNotifier(initial: TextScaleMode.large),
            ),
          ],
          child: _Capture(
            baseFontSize: 15,
            onResolve: (style) => captured = style,
          ),
        ),
      );

      expect(captured!.fontSize, closeTo(15 * 1.15, 1e-9));
    });

    testWidgets(
      'incoming and outgoing with same baseFontSize resolve to same scaled size',
      (tester) async {
        TextStyle? outgoing;
        TextStyle? incoming;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              accessibilityPreferencesProvider.overrideWith(
                () => _MockAccessibilityNotifier(
                  initial: TextScaleMode.extraLarge,
                ),
              ),
            ],
            child: Column(
              children: [
                _Capture(
                  baseFontSize: 14,
                  color: Colors.white,
                  onResolve: (style) => outgoing = style,
                ),
                _Capture(
                  baseFontSize: 14,
                  color: const Color(0xFF111111),
                  onResolve: (style) => incoming = style,
                ),
              ],
            ),
          ),
        );

        expect(outgoing!.fontSize, incoming!.fontSize);
        expect(outgoing!.color, Colors.white);
        expect(incoming!.color, const Color(0xFF111111));
      },
    );

    testWidgets('rebuilds when textScaleMode changes', (tester) async {
      final container = ProviderContainer(
        overrides: [
          accessibilityPreferencesProvider.overrideWith(
            _MockAccessibilityNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      double? captured;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _Capture(
            baseFontSize: 14,
            onResolve: (style) => captured = style.fontSize,
          ),
        ),
      );
      expect(captured, 14);

      await container
          .read(accessibilityPreferencesProvider.notifier)
          .setTextScaleMode(TextScaleMode.large);
      await tester.pump();

      expect(captured, closeTo(14 * 1.15, 1e-9));
    });
  });
}

class _Capture extends ConsumerWidget {
  const _Capture({
    required this.baseFontSize,
    required this.onResolve,
    this.color,
  });

  final double baseFontSize;
  final Color? color;
  final void Function(TextStyle style) onResolve;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = chatBubbleBodyStyle(
      ref,
      baseFontSize: baseFontSize,
      color: color,
    );
    onResolve(style);
    return const SizedBox.shrink();
  }
}

class _MockAccessibilityNotifier extends Notifier<AccessibilityPreferences>
    implements AccessibilityPreferencesNotifier {
  _MockAccessibilityNotifier({this.initial = TextScaleMode.socialmeshDefault});

  final TextScaleMode initial;

  @override
  AccessibilityPreferences build() {
    return AccessibilityPreferences(textScaleMode: initial);
  }

  @override
  Future<void> setTextScaleMode(TextScaleMode mode) async {
    state = state.copyWith(textScaleMode: mode);
  }

  @override
  Future<void> setFontMode(FontMode mode) async {
    state = state.copyWith(fontMode: mode);
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
  Future<void> setTimeFormatMode(TimeFormatMode mode) async {
    state = state.copyWith(timeFormatMode: mode);
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
