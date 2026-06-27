// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../utils/snackbar.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../l10n/app_localizations.dart';
import '../../models/accessibility_preferences.dart';
import '../../providers/accessibility_providers.dart';
import '../../providers/app_providers.dart';
import '../../providers/locale_provider.dart';
import '../../services/haptic_service.dart';

// ---------------------------------------------------------------------------
// Localized display names / descriptions for accessibility preference enums
// ---------------------------------------------------------------------------

extension ThemeModeL10n on ThemeMode {
  String localizedName(BuildContext context) {
    switch (this) {
      case ThemeMode.system:
        return context.l10n.appearanceThemeModeSystem;
      case ThemeMode.light:
        return context.l10n.appearanceThemeModeLight;
      case ThemeMode.dark:
        return context.l10n.appearanceThemeModeDark;
    }
  }

  String localizedDescription(BuildContext context) {
    switch (this) {
      case ThemeMode.system:
        return context.l10n.appearanceThemeModeSystemDesc;
      case ThemeMode.light:
        return context.l10n.appearanceThemeModeLightDesc;
      case ThemeMode.dark:
        return context.l10n.appearanceThemeModeDarkDesc;
    }
  }
}

extension FontModeL10n on FontMode {
  String localizedName(BuildContext context) {
    switch (this) {
      case FontMode.branded:
        return context.l10n.appearanceFontBranded;
      case FontMode.system:
        return context.l10n.appearanceFontSystem;
      case FontMode.accessibility:
        return context.l10n.appearanceFontAccessibility;
    }
  }

  String localizedDescription(BuildContext context) {
    switch (this) {
      case FontMode.branded:
        return context.l10n.appearanceFontBrandedDesc;
      case FontMode.system:
        return context.l10n.appearanceFontSystemDesc;
      case FontMode.accessibility:
        return context.l10n.appearanceFontAccessibilityDesc;
    }
  }
}

extension TextScaleModeL10n on TextScaleMode {
  String localizedName(BuildContext context) {
    switch (this) {
      case TextScaleMode.systemDefault:
        return context.l10n.appearanceTextScaleSystem;
      case TextScaleMode.socialmeshDefault:
        return context.l10n.appearanceTextScaleDefault;
      case TextScaleMode.large:
        return context.l10n.appearanceTextScaleLarge;
      case TextScaleMode.extraLarge:
        return context.l10n.appearanceTextScaleExtraLarge;
    }
  }

  String localizedDescription(BuildContext context) {
    switch (this) {
      case TextScaleMode.systemDefault:
        return context.l10n.appearanceTextScaleSystemDesc;
      case TextScaleMode.socialmeshDefault:
        return context.l10n.appearanceTextScaleDefaultDesc;
      case TextScaleMode.large:
        return context.l10n.appearanceTextScaleLargeDesc;
      case TextScaleMode.extraLarge:
        return context.l10n.appearanceTextScaleExtraLargeDesc;
    }
  }
}

extension DensityModeL10n on DensityMode {
  String localizedName(BuildContext context) {
    switch (this) {
      case DensityMode.compact:
        return context.l10n.appearanceDensityCompact;
      case DensityMode.comfortable:
        return context.l10n.appearanceDensityComfortable;
      case DensityMode.largeTouch:
        return context.l10n.appearanceDensityLargeTouch;
    }
  }

  String localizedDescription(BuildContext context) {
    switch (this) {
      case DensityMode.compact:
        return context.l10n.appearanceDensityCompactDesc;
      case DensityMode.comfortable:
        return context.l10n.appearanceDensityComfortableDesc;
      case DensityMode.largeTouch:
        return context.l10n.appearanceDensityLargeTouchDesc;
    }
  }
}

extension ContrastModeL10n on ContrastMode {
  String localizedName(BuildContext context) {
    switch (this) {
      case ContrastMode.normal:
        return context.l10n.appearanceContrastNormal;
      case ContrastMode.high:
        return context.l10n.appearanceContrastHigh;
    }
  }

  String localizedDescription(BuildContext context) {
    switch (this) {
      case ContrastMode.normal:
        return context.l10n.appearanceContrastNormalDesc;
      case ContrastMode.high:
        return context.l10n.appearanceContrastHighDesc;
    }
  }
}

extension ReduceMotionModeL10n on ReduceMotionMode {
  String localizedName(BuildContext context) {
    switch (this) {
      case ReduceMotionMode.off:
        return context.l10n.appearanceMotionNormal;
      case ReduceMotionMode.on:
        return context.l10n.appearanceMotionReduced;
    }
  }

  String localizedDescription(BuildContext context) {
    switch (this) {
      case ReduceMotionMode.off:
        return context.l10n.appearanceMotionNormalDesc;
      case ReduceMotionMode.on:
        return context.l10n.appearanceMotionReducedDesc;
    }
  }
}

extension TimeFormatModeL10n on TimeFormatMode {
  String localizedName(BuildContext context) {
    switch (this) {
      case TimeFormatMode.system:
        return context.l10n.appearanceTimeFormatSystem;
      case TimeFormatMode.twelveHour:
        return context.l10n.appearanceTimeFormat12h;
      case TimeFormatMode.twentyFourHour:
        return context.l10n.appearanceTimeFormat24h;
    }
  }

  String localizedDescription(BuildContext context) {
    switch (this) {
      case TimeFormatMode.system:
        return context.l10n.appearanceTimeFormatSystemDesc;
      case TimeFormatMode.twelveHour:
        return context.l10n.appearanceTimeFormat12hDesc;
      case TimeFormatMode.twentyFourHour:
        return context.l10n.appearanceTimeFormat24hDesc;
    }
  }
}

extension DateFormatModeL10n on DateFormatMode {
  String localizedName(BuildContext context) {
    switch (this) {
      case DateFormatMode.system:
        return context.l10n.appearanceDateFormatSystem;
      case DateFormatMode.monthDayYear:
        return context.l10n.appearanceDateFormatMdy;
      case DateFormatMode.dayMonthYear:
        return context.l10n.appearanceDateFormatDmy;
      case DateFormatMode.yearMonthDay:
        return context.l10n.appearanceDateFormatYmd;
    }
  }

  String localizedDescription(BuildContext context) {
    switch (this) {
      case DateFormatMode.system:
        return context.l10n.appearanceDateFormatSystemDesc;
      case DateFormatMode.monthDayYear:
        return context.l10n.appearanceDateFormatMdyDesc;
      case DateFormatMode.dayMonthYear:
        return context.l10n.appearanceDateFormatDmyDesc;
      case DateFormatMode.yearMonthDay:
        return context.l10n.appearanceDateFormatYmdDesc;
    }
  }
}

/// Appearance & Accessibility settings screen
///
/// Allows users to customize font, text size, density, contrast, and motion
/// settings with a live preview that updates instantly.
class AppearanceAccessibilityScreen extends ConsumerStatefulWidget {
  const AppearanceAccessibilityScreen({super.key});

  @override
  ConsumerState<AppearanceAccessibilityScreen> createState() =>
      _AppearanceAccessibilityScreenState();
}

class _AppearanceAccessibilityScreenState
    extends ConsumerState<AppearanceAccessibilityScreen>
    with LifecycleSafeMixin {
  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(accessibilityPreferencesProvider);
    final hasCustomSettings = ref.watch(hasCustomAccessibilitySettingsProvider);
    final currentLocale = ref.watch(localeProvider);

    return GlassScaffold(
      title: context.l10n.appearanceTitle,
      actions: [
        if (hasCustomSettings)
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: context.l10n.appearanceResetTooltip,
            onPressed: () => _showResetConfirmation(context),
          ),
      ],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: AppTheme.spacing16),

              // Live Preview Card
              _PreviewCard(preferences: prefs),

              const SizedBox(height: AppTheme.spacing24),

              // Theme Mode Section
              _SectionHeader(
                title: context.l10n.appearanceThemeMode,
                icon: Icons.brightness_6_rounded,
              ),
              const SizedBox(height: AppTheme.spacing8),
              _ThemeModeSelector(
                currentMode: ref.watch(themeModeProvider),
                onChanged: (mode) => _updateThemeMode(mode),
              ),

              const SizedBox(height: AppTheme.spacing24),

              _SectionHeader(
                title: context.l10n.appearanceLanguage,
                icon: Icons.language_rounded,
              ),
              const SizedBox(height: AppTheme.spacing8),
              _LanguageSelector(
                currentLocale: currentLocale,
                onChanged: (locale) => _updateLocale(locale),
              ),
              const SizedBox(height: AppTheme.spacing24),

              // Font Mode Section
              _SectionHeader(
                title: context.l10n.appearanceFont,
                icon: Icons.text_fields_rounded,
              ),
              const SizedBox(height: AppTheme.spacing8),
              _FontModeSelector(
                currentMode: prefs.fontMode,
                onChanged: (mode) => _updateFontMode(mode),
              ),

              const SizedBox(height: AppTheme.spacing24),

              // Text Size Section
              _SectionHeader(
                title: context.l10n.appearanceTextSize,
                icon: Icons.format_size_rounded,
              ),
              const SizedBox(height: AppTheme.spacing8),
              _TextScaleSelector(
                currentMode: prefs.textScaleMode,
                onChanged: (mode) => _updateTextScale(mode),
              ),

              const SizedBox(height: AppTheme.spacing24),

              // Time Format Section
              _SectionHeader(
                title: context.l10n.appearanceTimeFormat,
                icon: Icons.schedule_rounded,
              ),
              const SizedBox(height: AppTheme.spacing8),
              _TimeFormatSelector(
                currentMode: prefs.timeFormatMode,
                onChanged: (mode) => _updateTimeFormat(mode),
              ),

              const SizedBox(height: AppTheme.spacing24),

              // Date Format Section
              _SectionHeader(
                title: context.l10n.appearanceDateFormat,
                icon: Icons.calendar_today_rounded,
              ),
              const SizedBox(height: AppTheme.spacing8),
              _DateFormatSelector(
                currentMode: prefs.dateFormatMode,
                onChanged: (mode) => _updateDateFormat(mode),
              ),

              const SizedBox(height: AppTheme.spacing24),

              // Density Section
              _SectionHeader(
                title: context.l10n.appearanceDisplayDensity,
                icon: Icons.view_compact_rounded,
              ),
              const SizedBox(height: AppTheme.spacing8),
              _DensitySelector(
                currentMode: prefs.densityMode,
                onChanged: (mode) => _updateDensity(mode),
              ),

              const SizedBox(height: AppTheme.spacing24),

              // Contrast Section
              _SectionHeader(
                title: context.l10n.appearanceContrast,
                icon: Icons.contrast_rounded,
              ),
              const SizedBox(height: AppTheme.spacing8),
              _ContrastToggle(
                isHighContrast: prefs.contrastMode.isHighContrast,
                onChanged: (enabled) => _updateContrast(enabled),
              ),

              const SizedBox(height: AppTheme.spacing24),

              // Reduce Motion Section
              _SectionHeader(
                title: context.l10n.appearanceMotion,
                icon: Icons.animation_rounded,
              ),
              const SizedBox(height: AppTheme.spacing8),
              _ReduceMotionToggle(
                reduceMotion: prefs.reduceMotionMode.shouldReduceMotion,
                onChanged: (enabled) => _updateReduceMotion(enabled),
              ),

              const SizedBox(height: AppTheme.spacing24),

              // Reset Button (always visible as escape hatch)
              _ResetButton(
                hasCustomSettings: hasCustomSettings,
                onReset: () => _showResetConfirmation(context),
              ),

              // Bottom padding for safe area
              SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _updateLocale(Locale? locale) async {
    HapticFeedback.selectionClick();
    final notifier = ref.read(localeProvider.notifier);
    await notifier.setLocale(locale);
  }

  Future<void> _updateThemeMode(ThemeMode mode) async {
    HapticFeedback.selectionClick();
    final notifier = ref.read(themeModeProvider.notifier);
    final settingsService = await ref.read(settingsServiceProvider.future);
    if (!mounted) return;
    await settingsService.setThemeMode(mode.index);
    notifier.setThemeMode(mode);
  }

  Future<void> _updateFontMode(FontMode mode) async {
    HapticFeedback.selectionClick();
    final notifier = ref.read(accessibilityPreferencesProvider.notifier);
    await notifier.setFontMode(mode);
  }

  Future<void> _updateTextScale(TextScaleMode mode) async {
    HapticFeedback.selectionClick();
    if (!mounted) return;
    final notifier = ref.read(accessibilityPreferencesProvider.notifier);
    await notifier.setTextScaleMode(mode);
  }

  Future<void> _updateDensity(DensityMode mode) async {
    HapticFeedback.selectionClick();
    if (!mounted) return;
    final notifier = ref.read(accessibilityPreferencesProvider.notifier);
    await notifier.setDensityMode(mode);
  }

  Future<void> _updateContrast(bool enabled) async {
    HapticFeedback.selectionClick();
    if (!mounted) return;
    final notifier = ref.read(accessibilityPreferencesProvider.notifier);
    await notifier.setContrastMode(
      enabled ? ContrastMode.high : ContrastMode.normal,
    );
  }

  Future<void> _updateTimeFormat(TimeFormatMode mode) async {
    HapticFeedback.selectionClick();
    if (!mounted) return;
    final notifier = ref.read(accessibilityPreferencesProvider.notifier);
    await notifier.setTimeFormatMode(mode);
  }

  Future<void> _updateDateFormat(DateFormatMode mode) async {
    HapticFeedback.selectionClick();
    if (!mounted) return;
    final notifier = ref.read(accessibilityPreferencesProvider.notifier);
    await notifier.setDateFormatMode(mode);
  }

  Future<void> _updateReduceMotion(bool enabled) async {
    HapticFeedback.selectionClick();
    if (!mounted) return;
    final notifier = ref.read(accessibilityPreferencesProvider.notifier);
    await notifier.setReduceMotionMode(
      enabled ? ReduceMotionMode.on : ReduceMotionMode.off,
    );
  }

  void _showResetConfirmation(BuildContext context) {
    AppBottomSheet.show<bool>(
      context: context,
      child: _ResetConfirmationSheet(
        onConfirm: () async {
          // Capture all context-dependent values BEFORE any await
          final navigator = Navigator.of(context);
          final notifier = ref.read(accessibilityPreferencesProvider.notifier);
          final haptics = ref.read(hapticServiceProvider);

          await notifier.resetToDefaults();

          if (!mounted) return;
          navigator.pop(true);

          await haptics.trigger(HapticType.success);
          if (!mounted) return;

          ScaffoldMessenger.of(this.context).clearSnackBars();
          showSuccessSnackBar(
            this.context,
            this.context.l10n.appearanceResetSuccess,
          );
        },
      ),
    );
  }
}

/// Section header with icon
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: context.textSecondary),
        const SizedBox(width: AppTheme.spacing8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: context.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Live preview card showing current settings
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preferences});

  final AccessibilityPreferences preferences;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(
          color: preferences.contrastMode.isHighContrast
              ? (isDark ? Colors.white54 : Colors.black38)
              : context.border,
          width: preferences.contrastMode.isHighContrast ? 2 : 1,
        ),
      ),
      padding: EdgeInsets.all(
        AppTheme.spacing16 * preferences.densityMode.spacingMultiplier,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.accentColor,
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                child: const Icon(
                  Icons.accessibility_new_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              SizedBox(
                width:
                    AppTheme.spacing12 *
                    preferences.densityMode.spacingMultiplier,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.appearanceLivePreview,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing2),
                    Text(
                      context.l10n.appearanceChangesApplyInstantly,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(
            height:
                AppTheme.spacing16 * preferences.densityMode.spacingMultiplier,
          ),
          Text(
            context.l10n.appearanceSampleText,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          SizedBox(
            height:
                AppTheme.spacing12 * preferences.densityMode.spacingMultiplier,
          ),
          Row(
            children: [
              _PreviewChip(label: preferences.fontMode.localizedName(context)),
              const SizedBox(width: AppTheme.spacing8),
              _PreviewChip(
                label: preferences.textScaleMode.localizedName(context),
              ),
              const SizedBox(width: AppTheme.spacing8),
              _PreviewChip(
                label: preferences.densityMode.localizedName(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: context.accentColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Theme mode selector with radio-style options (System / Light / Dark)
class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({
    required this.currentMode,
    required this.onChanged,
  });

  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onChanged;

  static const _modes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: _modes.map((mode) {
          final isSelected = mode == currentMode;
          final isLast = mode == _modes.last;

          return Column(
            children: [
              InkWell(
                onTap: () => onChanged(mode),
                borderRadius: BorderRadius.vertical(
                  top: mode == _modes.first
                      ? const Radius.circular(12)
                      : Radius.zero,
                  bottom: isLast ? const Radius.circular(12) : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mode.localizedName(context),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: AppTheme.spacing2),
                            Text(
                              mode.localizedDescription(context),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Radio<ThemeMode>(
                        value: mode,
                        groupValue: currentMode,
                        onChanged: (value) {
                          if (value != null) onChanged(value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast) Divider(height: 1, color: context.border),
            ],
          );
        }).toList(),
      ),
    );
  }
}

/// Font mode selector with radio-style options
class _FontModeSelector extends StatelessWidget {
  const _FontModeSelector({required this.currentMode, required this.onChanged});

  final FontMode currentMode;
  final ValueChanged<FontMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: FontMode.values.map((mode) {
          final isSelected = mode == currentMode;
          final isLast = mode == FontMode.values.last;

          return Column(
            children: [
              InkWell(
                onTap: () => onChanged(mode),
                borderRadius: BorderRadius.vertical(
                  top: mode == FontMode.values.first
                      ? const Radius.circular(12)
                      : Radius.zero,
                  bottom: isLast ? const Radius.circular(12) : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mode.localizedName(context),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: AppTheme.spacing2),
                            Text(
                              mode.localizedDescription(context),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Radio<FontMode>(
                        value: mode,
                        groupValue: currentMode,
                        onChanged: (value) {
                          if (value != null) onChanged(value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast) Divider(height: 1, color: context.border),
            ],
          );
        }).toList(),
      ),
    );
  }
}

/// Text scale mode selector
class _TextScaleSelector extends StatelessWidget {
  const _TextScaleSelector({
    required this.currentMode,
    required this.onChanged,
  });

  final TextScaleMode currentMode;
  final ValueChanged<TextScaleMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: TextScaleMode.values.map((mode) {
          final isSelected = mode == currentMode;
          final isLast = mode == TextScaleMode.values.last;

          return Column(
            children: [
              InkWell(
                onTap: () => onChanged(mode),
                borderRadius: BorderRadius.vertical(
                  top: mode == TextScaleMode.values.first
                      ? const Radius.circular(12)
                      : Radius.zero,
                  bottom: isLast ? const Radius.circular(12) : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mode.localizedName(context),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: AppTheme.spacing2),
                            Text(
                              mode.localizedDescription(context),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Radio<TextScaleMode>(
                        value: mode,
                        groupValue: currentMode,
                        onChanged: (value) {
                          if (value != null) onChanged(value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast) Divider(height: 1, color: context.border),
            ],
          );
        }).toList(),
      ),
    );
  }
}

/// Density mode selector
class _DensitySelector extends StatelessWidget {
  const _DensitySelector({required this.currentMode, required this.onChanged});

  final DensityMode currentMode;
  final ValueChanged<DensityMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: DensityMode.values.map((mode) {
          final isSelected = mode == currentMode;
          final isLast = mode == DensityMode.values.last;

          return Column(
            children: [
              InkWell(
                onTap: () => onChanged(mode),
                borderRadius: BorderRadius.vertical(
                  top: mode == DensityMode.values.first
                      ? const Radius.circular(12)
                      : Radius.zero,
                  bottom: isLast ? const Radius.circular(12) : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mode.localizedName(context),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: AppTheme.spacing2),
                            Text(
                              mode.localizedDescription(context),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Radio<DensityMode>(
                        value: mode,
                        groupValue: currentMode,
                        onChanged: (value) {
                          if (value != null) onChanged(value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast) Divider(height: 1, color: context.border),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _TimeFormatSelector extends StatelessWidget {
  const _TimeFormatSelector({
    required this.currentMode,
    required this.onChanged,
  });

  final TimeFormatMode currentMode;
  final ValueChanged<TimeFormatMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: TimeFormatMode.values.map((mode) {
          final isSelected = mode == currentMode;
          final isLast = mode == TimeFormatMode.values.last;

          return Column(
            children: [
              InkWell(
                onTap: () => onChanged(mode),
                borderRadius: BorderRadius.vertical(
                  top: mode == TimeFormatMode.values.first
                      ? const Radius.circular(12)
                      : Radius.zero,
                  bottom: isLast ? const Radius.circular(12) : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mode.localizedName(context),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: AppTheme.spacing2),
                            Text(
                              mode.localizedDescription(context),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Radio<TimeFormatMode>(
                        value: mode,
                        groupValue: currentMode,
                        onChanged: (value) {
                          if (value != null) onChanged(value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast) Divider(height: 1, color: context.border),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _DateFormatSelector extends StatelessWidget {
  const _DateFormatSelector({
    required this.currentMode,
    required this.onChanged,
  });

  final DateFormatMode currentMode;
  final ValueChanged<DateFormatMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: DateFormatMode.values.map((mode) {
          final isSelected = mode == currentMode;
          final isLast = mode == DateFormatMode.values.last;

          return Column(
            children: [
              InkWell(
                onTap: () => onChanged(mode),
                borderRadius: BorderRadius.vertical(
                  top: mode == DateFormatMode.values.first
                      ? const Radius.circular(12)
                      : Radius.zero,
                  bottom: isLast ? const Radius.circular(12) : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mode.localizedName(context),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: AppTheme.spacing2),
                            Text(
                              mode.localizedDescription(context),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Radio<DateFormatMode>(
                        value: mode,
                        groupValue: currentMode,
                        onChanged: (value) {
                          if (value != null) onChanged(value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast) Divider(height: 1, color: context.border),
            ],
          );
        }).toList(),
      ),
    );
  }
}

/// High contrast toggle
class _ContrastToggle extends StatelessWidget {
  const _ContrastToggle({
    required this.isHighContrast,
    required this.onChanged,
  });

  final bool isHighContrast;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: ListTile(
        onTap: () => onChanged(!isHighContrast),
        title: Text(
          context.l10n.appearanceHighContrast,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: Text(
          context.l10n.appearanceHighContrastDesc,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: ThemedSwitch(value: isHighContrast, onChanged: onChanged),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius12),
        ),
      ),
    );
  }
}

class _ReduceMotionToggle extends StatelessWidget {
  const _ReduceMotionToggle({
    required this.reduceMotion,
    required this.onChanged,
  });

  final bool reduceMotion;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: ListTile(
        onTap: () => onChanged(!reduceMotion),
        title: Text(
          context.l10n.appearanceReduceMotion,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: Text(
          context.l10n.appearanceReduceMotionDesc,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: ThemedSwitch(value: reduceMotion, onChanged: onChanged),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius12),
        ),
      ),
    );
  }
}

/// Reset to defaults button
class _ResetButton extends StatelessWidget {
  const _ResetButton({required this.hasCustomSettings, required this.onReset});

  final bool hasCustomSettings;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: ListTile(
        leading: Icon(
          Icons.restore_rounded,
          color: hasCustomSettings ? context.accentColor : context.textTertiary,
        ),
        title: Text(
          context.l10n.appearanceResetToRecommended,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: hasCustomSettings
                ? context.textPrimary
                : context.textTertiary,
          ),
        ),
        subtitle: Text(
          hasCustomSettings
              ? context.l10n.appearanceRestoreDefaults
              : context.l10n.appearanceUsingRecommended,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: hasCustomSettings
            ? Icon(Icons.chevron_right_rounded, color: context.textTertiary)
            : null,
        onTap: hasCustomSettings ? onReset : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius12),
        ),
      ),
    );
  }
}

/// Reset confirmation bottom sheet
class _ResetConfirmationSheet extends StatelessWidget {
  const _ResetConfirmationSheet({required this.onConfirm});

  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.warningYellow.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            child: const Icon(
              Icons.restore_rounded,
              color: AppTheme.warningYellow,
              size: 28,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          Text(
            context.l10n.appearanceResetDialogTitle,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            context.l10n.appearanceResetDialogMessage,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.textSecondary),
          ),
          const SizedBox(height: AppTheme.spacing24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.appearanceResetDialogCancel),
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: FilledButton(
                  onPressed: onConfirm,
                  child: Text(context.l10n.appearanceResetDialogConfirm),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Language selector — shows "System Default" plus each supported locale.
class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({
    required this.currentLocale,
    required this.onChanged,
  });

  final Locale? currentLocale;
  final ValueChanged<Locale?> onChanged;

  String _localeDisplayName(BuildContext context, Locale? locale) {
    if (locale == null) return context.l10n.appearanceLanguageSystemDefault;
    switch (locale.languageCode) {
      case 'en':
        return context.l10n.appearanceLanguageEnglish;
      case 'it':
        return context.l10n.appearanceLanguageItalian;
      case 'ru':
        return context.l10n.appearanceLanguageRussian;
      case 'pt':
        return context.l10n.appearanceLanguagePortuguese;
      case 'de':
        return context.l10n.appearanceLanguageGerman;
      case 'es':
        return context.l10n.appearanceLanguageSpanish;
      case 'fr':
        return context.l10n.appearanceLanguageFrench;
      case 'uk':
        return context.l10n.appearanceLanguageUkrainian;
      default:
        return locale.languageCode;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build options: null (system default) + all supported locales
    final options = <Locale?>[null, ...AppLocalizations.supportedLocales];

    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: options.map((locale) {
          final isSelected =
              currentLocale == locale ||
              (currentLocale == null && locale == null);
          final isLast = locale == options.last;

          return Column(
            children: [
              InkWell(
                onTap: () => onChanged(locale),
                borderRadius: BorderRadius.vertical(
                  top: locale == options.first
                      ? const Radius.circular(12)
                      : Radius.zero,
                  bottom: isLast ? const Radius.circular(12) : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _localeDisplayName(context, locale),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                        ),
                      ),
                      Radio<Locale?>(
                        value: locale,
                        groupValue: currentLocale,
                        onChanged: (value) => onChanged(value),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast) Divider(height: 1, color: context.border),
            ],
          );
        }).toList(),
      ),
    );
  }
}
