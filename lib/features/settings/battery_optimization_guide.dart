// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/l10n_extension.dart';
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
_OemGuide _guideForManufacturer(String manufacturer, BuildContext context) {
  final m = manufacturer.toLowerCase().trim();

  if (m.contains('xiaomi') || m.contains('redmi') || m.contains('poco')) {
    return _OemGuide(
      oemName: 'Xiaomi / Redmi / POCO',
      steps: [
        context.l10n.batteryOptXiaomiStep1,
        context.l10n.batteryOptXiaomiStep2,
        context.l10n.batteryOptXiaomiStep3,
        context.l10n.batteryOptXiaomiStep4,
      ],
    );
  }

  if (m.contains('samsung')) {
    return _OemGuide(
      oemName: 'Samsung',
      steps: [
        context.l10n.batteryOptSamsungStep1,
        context.l10n.batteryOptSamsungStep2,
        context.l10n.batteryOptSamsungStep3,
        context.l10n.batteryOptSamsungStep4,
      ],
    );
  }

  if (m.contains('huawei') || m.contains('honor')) {
    return _OemGuide(
      oemName: 'Huawei / Honor',
      steps: [
        context.l10n.batteryOptHuaweiStep1,
        context.l10n.batteryOptHuaweiStep2,
        context.l10n.batteryOptHuaweiStep3,
      ],
    );
  }

  if (m.contains('oppo') ||
      m.contains('realme') ||
      m.contains('oneplus') ||
      m.contains('one plus')) {
    return _OemGuide(
      oemName: 'Oppo / Realme / OnePlus',
      steps: [
        context.l10n.batteryOptOneplusStep1,
        context.l10n.batteryOptOneplusStep2,
        context.l10n.batteryOptOneplusStep3,
      ],
    );
  }

  // Generic / Stock Android
  return _OemGuide(
    oemName: 'Android',
    deepLinkAction: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
    steps: [
      context.l10n.batteryOptGenericStep1,
      context.l10n.batteryOptGenericStep2,
      context.l10n.batteryOptGenericStep3,
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
    // A user who has already exempted the app needs no guidance. Without
    // this check the guide reappeared on every connect for users who had
    // done exactly what it asks, because the dismissed flag was only
    // written when they ticked "don't show again".
    final isIgnoring =
        await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    if (isIgnoring) {
      AppLogging.ble(
        'BatteryOptimizationGuide: exemption already granted, skipping',
      );
      return;
    }
  }

  // Detect manufacturer.
  final deviceInfo = DeviceInfoPlugin();
  final androidInfo = await deviceInfo.androidInfo;
  final manufacturer = androidInfo.manufacturer;

  AppLogging.ble('BatteryOptimizationGuide: manufacturer="$manufacturer"');

  if (!context.mounted) return;

  final guide = _guideForManufacturer(manufacturer, context);

  AppLogging.ble(
    'BatteryOptimizationGuide: showing guide for ${guide.oemName}',
  );

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
      padding: const EdgeInsets.fromLTRB(AppTheme.spacing24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.battery_alert, color: context.accentColor, size: 28),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Text(
                  context.l10n.batteryOptTitle(guide.oemName),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing16),

          // Scrollable description + steps
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  Text(
                    context.l10n.batteryOptDescription,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing16),

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
                          const SizedBox(width: AppTheme.spacing12),
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

          const SizedBox(height: AppTheme.spacing8),

          // Open settings button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                _openBatterySettings();
              },
              icon: const Icon(Icons.settings, size: 18),
              label: Text(context.l10n.batteryOptOpenSettings),
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),

          // Dismiss / don't show again
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _dismiss(context, dontShowAgain: false);
                  },
                  child: Text(context.l10n.batteryOptDismiss),
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _dismiss(context, dontShowAgain: true);
                  },
                  child: Text(
                    context.l10n.batteryOptDontShowAgain,
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
