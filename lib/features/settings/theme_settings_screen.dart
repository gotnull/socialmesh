// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/branded_qr_code.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/premium_feature_gate.dart';
import '../../models/subscription_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/profile_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../providers/subscription_providers.dart';
import '../../services/storage/storage_service.dart';
import '../../core/widgets/loading_indicator.dart';

/// Theme settings screen for Theme Pack owners
/// Allows customization of accent color and app appearance
class ThemeSettingsScreen extends ConsumerStatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  ConsumerState<ThemeSettingsScreen> createState() =>
      _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends ConsumerState<ThemeSettingsScreen>
    with LifecycleSafeMixin {
  @override
  Widget build(BuildContext context) {
    final accentColorAsync = ref.watch(accentColorProvider);
    final currentColor = accentColorAsync.asData?.value ?? AccentColors.magenta;
    final settingsAsync = ref.watch(settingsServiceProvider);

    return settingsAsync.when(
      loading: () => const GlassScaffold(
        title: 'Theme Settings',
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: ScreenLoadingIndicator(),
          ),
        ],
      ),
      error: (e, _) => GlassScaffold(
        title: 'Theme Settings',
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('Error: $e')),
          ),
        ],
      ),
      data: (settingsService) => GlassScaffold(
        title: 'Theme Settings',
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Header with current theme preview
                _buildThemePreview(context, currentColor),
                const SizedBox(height: 24),

                // Accent Color Section
                _buildSectionHeader('ACCENT COLOR'),
                const SizedBox(height: 12),
                _buildAccentColorGrid(
                  context,
                  ref,
                  settingsService,
                  currentColor,
                ),
                const SizedBox(height: 24),

                // QR Code Style Section (Premium)
                _buildSectionHeader('QR CODE STYLE'),
                const SizedBox(height: 12),
                _buildQrStyleSection(
                  context,
                  ref,
                  settingsService,
                  currentColor,
                ),
                const SizedBox(height: 24),

                // Theme Preview Section
                _buildSectionHeader('PREVIEW'),
                const SizedBox(height: 12),
                _buildPreviewElements(context, currentColor),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemePreview(BuildContext context, Color accentColor) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.3),
            accentColor.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.palette, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AccentColors.nameFor(accentColor),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
                Text(
                  'Current accent color',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildAccentColorGrid(
    BuildContext context,
    WidgetRef ref,
    SettingsService settingsService,
    Color currentColor,
  ) {
    final theme = Theme.of(context);
    final hasThemePack = ref.watch(
      hasFeatureProvider(PremiumFeature.premiumThemes),
    );
    final hasCompletePack = ref.watch(hasAllPremiumFeaturesProvider);
    // Free colors: first 3 (cyan, magenta, purple) are always available
    const freeColorCount = 3;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: AccentColors.all.asMap().entries.map((entry) {
          final index = entry.key;
          final color = entry.value;
          final isSelected = color.toARGB32() == currentColor.toARGB32();
          final colorName = AccentColors.names[index];
          final isGold = index == AccentColors.goldColorIndex;
          // Gold requires complete pack, other premium colors require theme pack
          final isPremiumColor = index >= freeColorCount;
          final isLocked = isGold
              ? !hasCompletePack
              : (isPremiumColor && !hasThemePack);

          return BouncyTap(
            onTap: () async {
              if (isLocked) {
                // Show premium upsell
                final purchased = await checkPremiumOrShowUpsell(
                  context: context,
                  ref: ref,
                  feature: PremiumFeature.premiumThemes,
                );
                if (!purchased) return;
              }
              HapticFeedback.selectionClick();
              final accentNotifier = ref.read(accentColorProvider.notifier);
              final profileNotifier = ref.read(userProfileProvider.notifier);
              await accentNotifier.setColor(color);
              // Also sync to cloud profile for cross-device persistence
              profileNotifier.updateProfile(accentColorIndex: index);
            },
            scaleFactor: 0.9,
            child: Tooltip(
              message: isGold
                  ? '$colorName (Complete Pack only)'
                  : (isLocked ? '$colorName (Theme Pack)' : colorName),
              child: AnimatedScale(
                scale: isSelected ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: isGold ? AccentColors.goldGradient : null,
                        color: isGold ? null : color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(
                                  alpha: isLocked ? 0.1 : 0.2,
                                ),
                          width: isSelected ? 3 : 2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.6),
                                  blurRadius: 12,
                                  spreadRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: isLocked
                            ? Icon(
                                Icons.lock,
                                key: const ValueKey('lock'),
                                color: Colors.white.withValues(alpha: 0.5),
                                size: 20,
                              )
                            : isSelected
                            ? const Icon(
                                Icons.check,
                                key: ValueKey('check'),
                                color: Colors.white,
                                size: 24,
                              )
                            : const SizedBox.shrink(key: ValueKey('empty')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQrStyleSection(
    BuildContext context,
    WidgetRef ref,
    SettingsService settingsService,
    Color accentColor,
  ) {
    final theme = Theme.of(context);
    final hasThemePack = ref.watch(
      hasFeatureProvider(PremiumFeature.premiumThemes),
    );
    final currentStyleIndex = settingsService.qrStyleIndex;
    final usesAccentColor = settingsService.qrUsesAccentColor;

    final styles = [
      (QrStyle.dots, 'Dots', 'Clean circular modules'),
      (QrStyle.smooth, 'Smooth', 'Premium liquid modules'),
      (QrStyle.squares, 'Classic', 'Maximum compatibility'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // QR Preview
          Center(
            child: usesAccentColor
                ? _buildAccentGradientPreview(
                    accentColor,
                    styles[currentStyleIndex].$1,
                  )
                : Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: BrandedQrCode(
                      data: 'socialmesh://preview',
                      size: 120,
                      style: styles[currentStyleIndex].$1,
                      foregroundColor: const Color(0xFF1F2633),
                      backgroundColor: Colors.white,
                    ),
                  ),
          ),
          const SizedBox(height: 20),

          // Style selector
          Text(
            'Pattern',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: styles.asMap().entries.map((entry) {
              final index = entry.key;
              final (style, name, _) = entry.value;
              final isSelected = index == currentStyleIndex;
              // Smooth style is premium
              final isPremium = style == QrStyle.smooth;
              final isLocked = isPremium && !hasThemePack;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index < 2 ? 8 : 0),
                  child: BouncyTap(
                    onTap: () async {
                      if (isLocked) {
                        final purchased = await checkPremiumOrShowUpsell(
                          context: context,
                          ref: ref,
                          feature: PremiumFeature.premiumThemes,
                        );
                        if (!purchased) return;
                      }
                      HapticFeedback.selectionClick();
                      await settingsService.setQrStyleIndex(index);
                      safeSetState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accentColor.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? accentColor : theme.dividerColor,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          if (isLocked)
                            Icon(
                              Icons.lock,
                              size: 16,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.4,
                              ),
                            )
                          else
                            Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              size: 16,
                              color: isSelected
                                  ? accentColor
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.4,
                                    ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isSelected
                                  ? accentColor
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Accent color toggle (premium)
          BouncyTap(
            onTap: () async {
              if (!hasThemePack) {
                final purchased = await checkPremiumOrShowUpsell(
                  context: context,
                  ref: ref,
                  feature: PremiumFeature.premiumThemes,
                );
                if (!purchased) return;
              }
              HapticFeedback.selectionClick();
              await settingsService.setQrUsesAccentColor(!usesAccentColor);
              safeSetState(() {});
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: usesAccentColor
                    ? accentColor.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: usesAccentColor ? accentColor : theme.dividerColor,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          HSLColor.fromColor(accentColor)
                              .withLightness(
                                (HSLColor.fromColor(accentColor).lightness +
                                        0.15)
                                    .clamp(0.0, 1.0),
                              )
                              .toColor(),
                          accentColor,
                          HSLColor.fromColor(accentColor)
                              .withLightness(
                                (HSLColor.fromColor(accentColor).lightness -
                                        0.15)
                                    .clamp(0.0, 1.0),
                              )
                              .toColor(),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Use Accent Gradient',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'Apply accent color to QR codes',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!hasThemePack)
                    Icon(
                      Icons.lock,
                      size: 18,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    )
                  else
                    Switch(
                      value: usesAccentColor,
                      onChanged: (value) async {
                        HapticFeedback.selectionClick();
                        await settingsService.setQrUsesAccentColor(value);
                        safeSetState(() {});
                      },
                      activeTrackColor: accentColor,
                      thumbColor: WidgetStateProperty.all(Colors.white),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewElements(BuildContext context, Color accentColor) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Buttons preview
          Text(
            'Buttons',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Primary'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: accentColor,
                  side: BorderSide(color: accentColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Secondary'),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(foregroundColor: accentColor),
                child: const Text('Text'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Switch & Checkbox preview
          Text(
            'Controls',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Switch(
                value: true,
                onChanged: (_) {},
                activeTrackColor: accentColor,
                thumbColor: WidgetStateProperty.all(Colors.white),
              ),
              const SizedBox(width: 16),
              Checkbox(
                value: true,
                onChanged: (_) {},
                activeColor: accentColor,
              ),
              const SizedBox(width: 16),
              // Radio indicator (styled to match accent)
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor, width: 2),
                ),
                child: Center(
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Progress indicators
          Text(
            'Progress',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              LoadingIndicator(size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: LinearProgressIndicator(
                  value: 0.7,
                  backgroundColor: theme.dividerColor,
                  valueColor: AlwaysStoppedAnimation(accentColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Badge/Chip preview
          Text(
            'Badges',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  'Online',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  '5 new',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds an accent gradient QR preview matching the elevated styles.
  Widget _buildAccentGradientPreview(Color accent, QrStyle style) {
    final lightAccent = HSLColor.fromColor(accent)
        .withLightness(
          (HSLColor.fromColor(accent).lightness + 0.15).clamp(0.0, 1.0),
        )
        .toColor();
    final darkAccent = HSLColor.fromColor(accent)
        .withLightness(
          (HSLColor.fromColor(accent).lightness - 0.15).clamp(0.0, 1.0),
        )
        .toColor();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lightAccent, accent, darkAccent],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              spreadRadius: -2,
            ),
          ],
        ),
        child: BrandedQrCode(
          data: 'socialmesh://preview',
          size: 110,
          style: style,
          foregroundColor: accent,
          backgroundColor: Colors.white,
        ),
      ),
    );
  }
}
