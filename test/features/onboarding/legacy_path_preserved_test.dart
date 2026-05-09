// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level pin tests guarding the flag-off legacy path. The
/// onboarding-flow refactor MUST preserve the legacy
/// Scanner -> Navigator.push(RegionSelectionScreen) -> pop ->
/// setInitialized choreography when the feature flag is off, so
/// that the patch can be rolled back per-install via env override.
///
/// These pins assert that the legacy code is still present in the
/// codebase under a feature-flag guard. If a future patch removes
/// the legacy path entirely, the rollback story breaks and the
/// pins fire.
void main() {
  group('Scanner: legacy region-push path preserved', () {
    late String source;
    setUpAll(() async {
      source = await File(
        'lib/features/scanner/scanner_screen.dart',
      ).readAsString();
    });

    test('Navigator.push(RegionSelectionScreen) is still present for the '
        'flag-off path', () {
      // The legacy push is wrapped in a flag check; the flag-off
      // branch falls through to it. Removing the push entirely would
      // strand flag-off users.
      final collapsed = source.replaceAll(RegExp(r'\s+'), ' ');
      expect(
        collapsed.contains('RegionSelectionScreen(isInitialSetup: true)'),
        isTrue,
        reason:
            'flag-off must continue to push RegionSelectionScreen so '
            'a release rollback restores the legacy choreography.',
      );
    });

    test('post-region setInitialized() is still present for the flag-off '
        'path', () {
      // Five legacy callsites of setInitialized live in scanner; they
      // must remain reachable when the flag is off. We pin the
      // canonical "MAIN_SHELL_PROMOTED" log-line which sits next to
      // the setInitialized call in the scanner_post_region branch.
      expect(
        source.contains('MAIN_SHELL_PROMOTED source=scanner_post_region'),
        isTrue,
      );
      expect(source.contains('appInitNotifier.setInitialized()'), isTrue);
    });

    test('flag check guards the legacy push block', () {
      // The new coordinator owns the post-connect path when the flag
      // is on. The early-return must consult the flag, not bypass it.
      expect(
        source.contains('meshtasticOnboardingFlowFlagsProvider'),
        isTrue,
        reason:
            'scanner must read the flag at runtime to gate the push '
            'block, otherwise the legacy path runs even when the new '
            'coordinator is on.',
      );
      expect(source.contains('SCANNER: onboarding-flow active'), isTrue);
    });

    test('Scanner.tap dispatches to the coordinator (no-op when flag off)', () {
      // The scanner tap entry must call the coordinator unconditionally
      // — the coordinator itself is a no-op when the flag is off.
      // This pin ensures the dispatch is in place so flag-flip on a
      // running install takes effect immediately.
      expect(
        source.contains('meshtasticOnboardingFlowProvider.notifier).connect('),
        isTrue,
      );
    });
  });

  group('RegionSelection: legacy applyAndPop path preserved', () {
    late String source;
    setUpAll(() async {
      source = await File(
        'lib/features/device/region_selection_screen.dart',
      ).readAsString();
    });

    test('legacy _applyAndPop is still present for the flag-off path', () {
      expect(source.contains('_applyAndPop('), isTrue);
      expect(source.contains('await _applyAndPop('), isTrue);
    });

    test('flag-on path dispatches to coordinator and stays mounted', () {
      // The new coordinator-driven branch must call selectRegion and
      // return early WITHOUT calling _applyAndPop. The "stay on
      // screen" comment is a load-bearing contract: appShellProvider
      // unmounts the screen, not the screen itself.
      expect(
        source.contains('meshtasticOnboardingFlowProvider.notifier'),
        isTrue,
      );
      expect(source.contains('.selectRegion('), isTrue);
      expect(
        source.contains('appShellProvider will route us out'),
        isTrue,
        reason:
            'comment pins the contract that RegionSelection no longer '
            'self-pops or calls setInitialized; routing is owned by '
            'appShellProvider via coordinator state.',
      );
    });
  });

  group('_AppRouter: appShellProvider is the single source of truth', () {
    late String source;
    setUpAll(() async {
      source = await File('lib/main.dart').readAsString();
    });

    test(
      '_AppRouter watches appShellProvider, not appInitProvider directly',
      () {
        // The legacy router watched appInitProvider and switched on
        // AppInitState; the refactor moves that decision into
        // appShellProvider. _AppRouter must consume the derived
        // resolution.
        expect(source.contains('ref.watch(appShellProvider)'), isTrue);
        expect(source.contains('AppShell.regionPicker'), isTrue);
        expect(source.contains('APP_SHELL: route='), isTrue);
      },
    );
  });
}
