// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../utils/snackbar.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../models/accessibility_preferences.dart';
import '../../providers/accessibility_providers.dart';
import '../../services/haptic_service.dart';
import '../nodedex/atmosphere/atmosphere_provider.dart';

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

    return GlassScaffold(
      title: 'Appearance & Accessibility',
      actions: [
        if (hasCustomSettings)
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reset to defaults',
            onPressed: () => _showResetConfirmation(context),
          ),
      ],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 16),

              // Live Preview Card
              _PreviewCard(preferences: prefs),

              const SizedBox(height: 24),

              // Font Mode Section
              _SectionHeader(title: 'Font', icon: Icons.text_fields_rounded),
              const SizedBox(height: 8),
              _FontModeSelector(
                currentMode: prefs.fontMode,
                onChanged: (mode) => _updateFontMode(mode),
              ),

              const SizedBox(height: 24),

              // Text Size Section
              _SectionHeader(
                title: 'Text Size',
                icon: Icons.format_size_rounded,
              ),
              const SizedBox(height: 8),
              _TextScaleSelector(
                currentMode: prefs.textScaleMode,
                onChanged: (mode) => _updateTextScale(mode),
              ),

              const SizedBox(height: 24),

              // Density Section
              _SectionHeader(
                title: 'Display Density',
                icon: Icons.view_compact_rounded,
              ),
              const SizedBox(height: 8),
              _DensitySelector(
                currentMode: prefs.densityMode,
                onChanged: (mode) => _updateDensity(mode),
              ),

              const SizedBox(height: 24),

              // Contrast Section
              _SectionHeader(title: 'Contrast', icon: Icons.contrast_rounded),
              const SizedBox(height: 8),
              _ContrastToggle(
                isHighContrast: prefs.contrastMode.isHighContrast,
                onChanged: (enabled) => _updateContrast(enabled),
              ),

              const SizedBox(height: 24),

              // Reduce Motion Section
              _SectionHeader(title: 'Motion', icon: Icons.animation_rounded),
              const SizedBox(height: 8),
              _ReduceMotionToggle(
                reduceMotion: prefs.reduceMotionMode.shouldReduceMotion,
                onChanged: (enabled) => _updateReduceMotion(enabled),
              ),

              const SizedBox(height: 16),

              // Elemental Atmosphere toggle
              _AtmosphereToggle(
                reduceMotionActive: prefs.reduceMotionMode.shouldReduceMotion,
              ),

              const SizedBox(height: 24),

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

  Future<void> _updateFontMode(FontMode mode) async {
    HapticFeedback.selectionClick();
    final notifier = ref.read(accessibilityPreferencesProvider.notifier);
    await notifier.setFontMode(mode);
  }

  Future<void> _updateTextScale(TextScaleMode mode) async {
    HapticFeedback.selectionClick();
    final notifier = ref.read(accessibilityPreferencesProvider.notifier);
    await notifier.setTextScaleMode(mode);
  }

  Future<void> _updateDensity(DensityMode mode) async {
    HapticFeedback.selectionClick();
    final notifier = ref.read(accessibilityPreferencesProvider.notifier);
    await notifier.setDensityMode(mode);
  }

  Future<void> _updateContrast(bool enabled) async {
    HapticFeedback.selectionClick();
    final notifier = ref.read(accessibilityPreferencesProvider.notifier);
    await notifier.setContrastMode(
      enabled ? ContrastMode.high : ContrastMode.normal,
    );
  }

  Future<void> _updateReduceMotion(bool enabled) async {
    HapticFeedback.selectionClick();
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
          showSuccessSnackBar(this.context, 'Settings reset to defaults');
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
        const SizedBox(width: 8),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: preferences.contrastMode.isHighContrast
              ? (isDark ? Colors.white54 : Colors.black38)
              : context.border,
          width: preferences.contrastMode.isHighContrast ? 2 : 1,
        ),
      ),
      padding: EdgeInsets.all(16 * preferences.densityMode.spacingMultiplier),
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.accessibility_new_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              SizedBox(width: 12 * preferences.densityMode.spacingMultiplier),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Preview',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Changes apply instantly',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16 * preferences.densityMode.spacingMultiplier),
          Text(
            'Sample body text to preview your settings. '
            'Adjust the options below to find what works best for you.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          SizedBox(height: 12 * preferences.densityMode.spacingMultiplier),
          Row(
            children: [
              _PreviewChip(label: preferences.fontMode.displayName),
              const SizedBox(width: 8),
              _PreviewChip(label: preferences.textScaleMode.displayName),
              const SizedBox(width: 8),
              _PreviewChip(label: preferences.densityMode.displayName),
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
        borderRadius: BorderRadius.circular(12),
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
        borderRadius: BorderRadius.circular(12),
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
                              mode.displayName,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              mode.description,
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
        borderRadius: BorderRadius.circular(12),
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
                              mode.displayName,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              mode.description,
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
        borderRadius: BorderRadius.circular(12),
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
                              mode.displayName,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              mode.description,
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: SwitchListTile(
        title: Text(
          'High Contrast',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: Text(
          'Enhanced visibility for text and UI elements',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        value: isHighContrast,
        onChanged: onChanged,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Reduce motion toggle
/// Toggle for the Elemental Atmosphere ambient particle effects.
///
/// Allows users to enable or disable ambient data-driven particle
/// effects (rain, embers, mist, starlight) that visualize mesh
/// activity behind NodeDex and map views. The toggle is disabled
/// when reduce-motion is active because all particle effects are
/// suppressed in that mode.
class _AtmosphereToggle extends ConsumerWidget {
  const _AtmosphereToggle({required this.reduceMotionActive});

  /// Whether reduce-motion is currently active. When true, the
  /// toggle is disabled and shows an explanatory subtitle.
  final bool reduceMotionActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final atmosphereEnabled = ref.watch(atmosphereEnabledProvider);

    return Card(
      margin: EdgeInsets.zero,
      color: context.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        title: Text(
          'Elemental Atmosphere',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: Text(
          reduceMotionActive
              ? 'Disabled while Reduce Motion is active'
              : 'Ambient particle effects driven by mesh activity',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        secondary: Icon(
          Icons.auto_awesome_outlined,
          color: reduceMotionActive
              ? context.textTertiary
              : atmosphereEnabled
              ? context.accentColor
              : context.textSecondary,
        ),
        value: reduceMotionActive ? false : atmosphereEnabled,
        onChanged: reduceMotionActive
            ? null
            : (enabled) {
                HapticFeedback.selectionClick();
                ref
                    .read(atmosphereEnabledProvider.notifier)
                    .setEnabled(enabled);
              },
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: SwitchListTile(
        title: Text(
          'Reduce Motion',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: Text(
          'Minimize animations throughout the app',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        value: reduceMotion,
        onChanged: onChanged,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: ListTile(
        leading: Icon(
          Icons.restore_rounded,
          color: hasCustomSettings ? context.accentColor : context.textTertiary,
        ),
        title: Text(
          'Reset to Recommended',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: hasCustomSettings
                ? context.textPrimary
                : context.textTertiary,
          ),
        ),
        subtitle: Text(
          hasCustomSettings
              ? 'Restore default settings'
              : 'Using recommended settings',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: hasCustomSettings
            ? Icon(Icons.chevron_right_rounded, color: context.textTertiary)
            : null,
        onTap: hasCustomSettings ? onReset : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.restore_rounded,
              color: AppTheme.warningYellow,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Reset to Defaults?',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'This will restore all appearance and accessibility '
            'settings to their recommended values.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.textSecondary),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onConfirm,
                  child: const Text('Reset'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
