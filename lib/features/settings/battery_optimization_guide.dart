// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';

/// SharedPreferences key tracking whether the OEM battery guide has been
/// dismissed. Once set, the guide will not be shown again automatically.
const String kBatteryGuideDismissed = 'bg_battery_guide_dismissed';

// =============================================================================
// OEM Guide Data
// =============================================================================

/// Instructions tailored to a specific Android OEM.
class _OemGuide {
  const _OemGuide({
    required this.oemName,
    required this.steps,
    this.deepLinkAction,
  });

  final String oemName;
  final List<String> steps;

  /// Optional Android intent action to deep-link into OEM settings.
  final String? deepLinkAction;
}

/// Returns the [_OemGuide] for the detected [manufacturer], or a generic
/// guide for stock Android.
_OemGuide _guideForManufacturer(String manufacturer) {
  final m = manufacturer.toLowerCase().trim();

  if (m.contains('xiaomi') || m.contains('redmi') || m.contains('poco')) {
    return const _OemGuide(
      oemName: 'Xiaomi / Redmi / POCO',
      steps: [
        'Open Settings > Apps > Manage apps > Socialmesh.',
        'Tap "AutoStart" and enable it.',
        'Go back and tap "Battery saver".',
        'Select "No restrictions" for Socialmesh.',
      ],
    );
  }

  if (m.contains('samsung')) {
    return const _OemGuide(
      oemName: 'Samsung',
      steps: [
        'Open Settings > Battery and device care > Battery.',
        'Tap "Background usage limits".',
        'Remove Socialmesh from the "Sleeping apps" and "Deep sleeping apps" lists.',
        'Optionally disable "Adaptive battery" for best results.',
      ],
    );
  }

  if (m.contains('huawei') || m.contains('honor')) {
    return const _OemGuide(
      oemName: 'Huawei / Honor',
      steps: [
        'Open Settings > Battery > App launch.',
        'Find Socialmesh and set it to "Manage manually".',
        'Enable all three toggles: Auto-launch, Secondary launch, and Run in background.',
      ],
    );
  }

  if (m.contains('oppo') ||
      m.contains('realme') ||
      m.contains('oneplus') ||
      m.contains('one plus')) {
    return const _OemGuide(
      oemName: 'Oppo / Realme / OnePlus',
      steps: [
        'Open Settings > Apps > App management > Socialmesh.',
        'Enable "Auto-launch" and "Allow activity in background".',
        'On OnePlus 14+: also check Settings > Battery > Battery optimization > Socialmesh > "Don\'t optimize".',
      ],
    );
  }

  // Generic / Stock Android
  return const _OemGuide(
    oemName: 'Android',
    deepLinkAction: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
    steps: [
      'Open Settings > Apps > Socialmesh > Battery.',
      'Select "Unrestricted" or "Don\'t optimize".',
      'This allows Socialmesh to maintain the mesh connection in the background.',
    ],
  );
}

// =============================================================================
// Public API
// =============================================================================

/// Show the OEM battery optimization guide as a bottom sheet.
///
/// The guide is only shown on Android, only once (unless [force] is true), and
/// only if battery optimization has not already been disabled.
///
/// Call this after [BackgroundBleService.promptBatteryOptimizationIfNeeded]
/// to provide additional OEM-specific guidance.
Future<void> showBatteryOptimizationGuide(
  BuildContext context, {
  bool force = false,
}) async {
  if (!Platform.isAndroid) return;

  if (!force) {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(kBatteryGuideDismissed) ?? false;
    if (dismissed) {
      AppLogging.ble('BatteryOptimizationGuide: already dismissed, skipping');
      return;
    }
  }

  // Detect manufacturer.
  final deviceInfo = DeviceInfoPlugin();
  final androidInfo = await deviceInfo.androidInfo;
  final manufacturer = androidInfo.manufacturer;
  final guide = _guideForManufacturer(manufacturer);

  AppLogging.ble(
    'BatteryOptimizationGuide: manufacturer="$manufacturer", '
    'showing guide for ${guide.oemName}',
  );

  if (!context.mounted) return;

  await AppBottomSheet.show<void>(
    context: context,
    child: _BatteryGuideContent(guide: guide),
  );
}

// =============================================================================
// Guide content widget
// =============================================================================

class _BatteryGuideContent extends StatelessWidget {
  const _BatteryGuideContent({required this.guide});

  final _OemGuide guide;

  Future<void> _dismiss(
    BuildContext context, {
    required bool dontShowAgain,
  }) async {
    if (dontShowAgain) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kBatteryGuideDismissed, true);
    }
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openBatterySettings() async {
    if (!Platform.isAndroid) return;

    try {
      const platform = MethodChannel('com.socialmesh/settings');
      await platform.invokeMethod('openBatterySettings');
    } catch (e) {
      AppLogging.ble('BatteryOptimizationGuide: failed to open settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.battery_alert, color: context.accentColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Optimize for ${guide.oemName}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Scrollable description + steps
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  Text(
                    'Your device manufacturer may aggressively limit background apps. '
                    'Follow these steps to keep the mesh connection alive:',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Steps
                  ...guide.steps.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final step = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: context.accentColor.withValues(
                                alpha: 0.15,
                              ),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$index',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: context.accentColor,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              step,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: context.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Open settings button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                _openBatterySettings();
              },
              icon: const Icon(Icons.settings, size: 18),
              label: const Text('Open Battery Settings'),
            ),
          ),
          const SizedBox(height: 8),

          // Dismiss / don't show again
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _dismiss(context, dontShowAgain: false);
                  },
                  child: const Text('Dismiss'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _dismiss(context, dontShowAgain: true);
                  },
                  child: Text(
                    "Don't show again",
                    style: TextStyle(color: context.textTertiary),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
