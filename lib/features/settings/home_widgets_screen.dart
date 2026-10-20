// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/revenuecat_config.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../providers/subscription_providers.dart';

/// Home widgets configuration screen for Widget Pack owners
/// Shows available iOS/Android widgets and instructions for adding them
class HomeWidgetsScreen extends ConsumerStatefulWidget {
  const HomeWidgetsScreen({super.key});

  @override
  ConsumerState<HomeWidgetsScreen> createState() => _HomeWidgetsScreenState();
}

class _HomeWidgetsScreenState extends ConsumerState<HomeWidgetsScreen> {
  @override
  Widget build(BuildContext context) {
    final accentColor = context.accentColor;

    return GlassScaffold(
      title: context.l10n.homeWidgetsTitle,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Header
              _buildHeader(context, accentColor),
              const SizedBox(height: AppTheme.spacing24),

              // Available Widgets Section
              _buildSectionHeader(context.l10n.homeWidgetsSectionAvailable),
              const SizedBox(height: AppTheme.spacing12),
              _buildWidgetCard(
                context,
                icon: Icons.people,
                title: context.l10n.homeWidgetsMeshStatus,
                description: context.l10n.homeWidgetsMeshStatusDesc,
                sizes: [
                  context.l10n.homeWidgetsSizeSmall,
                  context.l10n.homeWidgetsSizeMedium,
                ],
                accentColor: accentColor,
              ),
              const SizedBox(height: AppTheme.spacing12),
              _buildWidgetCard(
                context,
                icon: Icons.message,
                title: context.l10n.homeWidgetsRecentMessages,
                description: context.l10n.homeWidgetsRecentMessagesDesc,
                sizes: [
                  context.l10n.homeWidgetsSizeMedium,
                  context.l10n.homeWidgetsSizeLarge,
                ],
                accentColor: accentColor,
              ),
              const SizedBox(height: AppTheme.spacing12),
              _buildWidgetCard(
                context,
                icon: Icons.battery_full,
                title: context.l10n.homeWidgetsDeviceBattery,
                description: context.l10n.homeWidgetsDeviceBatteryDesc,
                sizes: [context.l10n.homeWidgetsSizeSmall],
                accentColor: accentColor,
              ),
              const SizedBox(height: AppTheme.spacing12),
              _buildWidgetCard(
                context,
                icon: Icons.send,
                title: context.l10n.homeWidgetsQuickMessage,
                description: context.l10n.homeWidgetsQuickMessageDesc,
                sizes: [
                  context.l10n.homeWidgetsSizeSmall,
                  context.l10n.homeWidgetsSizeMedium,
                ],
                accentColor: accentColor,
              ),
              const SizedBox(height: AppTheme.spacing12),
              _buildWidgetCard(
                context,
                icon: Icons.gps_fixed,
                title: context.l10n.homeWidgetsLocationBeacon,
                description: context.l10n.homeWidgetsLocationBeaconDesc,
                sizes: [context.l10n.homeWidgetsSizeSmall],
                accentColor: accentColor,
              ),
              const SizedBox(height: AppTheme.spacing24),

              // How to Add Section
              _buildSectionHeader(context.l10n.homeWidgetsSectionHowTo),
              const SizedBox(height: AppTheme.spacing12),
              _buildInstructions(context, accentColor),
              const SizedBox(height: AppTheme.spacing24),

              // Tips Section
              _buildSectionHeader(context.l10n.homeWidgetsSectionTips),
              const SizedBox(height: AppTheme.spacing12),
              _buildTipsSection(context, accentColor),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, Color accentColor) {
    final storeProductsAsync = ref.watch(storeProductsProvider);
    final storeProducts = storeProductsAsync.when(
      data: (data) => data,
      loading: () => <String, StoreProductInfo>{},
      error: (e, s) => <String, StoreProductInfo>{},
    );
    final widgetPackName =
        storeProducts[RevenueCatConfig.widgetPackProductId]?.title ??
        'Widget Pack'; // lint-allow: hardcoded-string

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.3),
            accentColor.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(color: accentColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(AppTheme.radius14),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(Icons.widgets, color: Colors.white, size: 28),
          ),
          const SizedBox(width: AppTheme.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widgetPackName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
                Text(
                  context.l10n.homeWidgetsAddToHomeScreen,
                  style: context.bodySecondaryStyle?.copyWith(
                    color: context.textSecondary,
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
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: context.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildWidgetCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required List<String> sizes,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            child: Icon(icon, color: accentColor, size: 24),
          ),
          SizedBox(width: AppTheme.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing2),
                Text(
                  description,
                  style: context.bodySmallStyle?.copyWith(
                    color: context.textTertiary,
                  ),
                ),
                SizedBox(height: AppTheme.spacing8),
                Wrap(
                  spacing: 6,
                  children: sizes.map((size) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: context.background,
                        borderRadius: BorderRadius.circular(AppTheme.radius6),
                        border: Border.all(color: context.border),
                      ),
                      child: Text(
                        size,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textTertiary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions(BuildContext context, Color accentColor) {
    final isIOS = Platform.isIOS;
    final steps = isIOS
        ? [
            _InstructionStep(
              number: 1,
              title: context.l10n.homeWidgetsIosLongPress,
              description: context.l10n.homeWidgetsIosLongPressDesc,
            ),
            _InstructionStep(
              number: 2,
              title: context.l10n.homeWidgetsIosTapPlus,
              description: context.l10n.homeWidgetsIosTapPlusDesc,
            ),
            _InstructionStep(
              number: 3,
              title: context.l10n.homeWidgetsIosSearch,
              description: context.l10n.homeWidgetsIosSearchDesc,
            ),
            _InstructionStep(
              number: 4,
              title: context.l10n.homeWidgetsIosChooseSize,
              description: context.l10n.homeWidgetsIosChooseSizeDesc,
            ),
            _InstructionStep(
              number: 5,
              title: context.l10n.homeWidgetsIosPosition,
              description: context.l10n.homeWidgetsIosPositionDesc,
            ),
          ]
        : [
            _InstructionStep(
              number: 1,
              title: context.l10n.homeWidgetsAndroidLongPress,
              description: context.l10n.homeWidgetsIosLongPressDesc,
            ),
            _InstructionStep(
              number: 2,
              title: context.l10n.homeWidgetsAndroidTapWidgets,
              description: context.l10n.homeWidgetsAndroidTapWidgetsDesc,
            ),
            _InstructionStep(
              number: 3,
              title: context.l10n.homeWidgetsIosSearch,
              description: context.l10n.homeWidgetsIosSearchDesc,
            ),
            _InstructionStep(
              number: 4,
              title: context.l10n.homeWidgetsAndroidLongPressDrag,
              description: context.l10n.homeWidgetsAndroidLongPressDragDesc,
            ),
          ];

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isIOS ? Icons.phone_iphone : Icons.phone_android,
                color: accentColor,
                size: 20,
              ),
              SizedBox(width: AppTheme.spacing8),
              Text(
                isIOS
                    ? context.l10n.homeWidgetsIosInstructions
                    : context.l10n.homeWidgetsAndroidInstructions,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing16),
          ...steps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${step.number}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                        Text(
                          step.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsSection(BuildContext context, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTipRow(
            Icons.refresh,
            context.l10n.homeWidgetsTipAutoUpdate,
            accentColor,
          ),
          const SizedBox(height: AppTheme.spacing12),
          _buildTipRow(
            Icons.wifi_off,
            context.l10n.homeWidgetsTipOffline,
            accentColor,
          ),
          const SizedBox(height: AppTheme.spacing12),
          _buildTipRow(
            Icons.touch_app,
            context.l10n.homeWidgetsTipTapToOpen,
            accentColor,
          ),
          const SizedBox(height: AppTheme.spacing12),
          _buildTipRow(
            Icons.palette,
            context.l10n.homeWidgetsTipAccentColor,
            accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildTipRow(IconData icon, String text, Color accentColor) {
    return Row(
      children: [
        Icon(icon, size: 18, color: accentColor.withValues(alpha: 0.7)),
        SizedBox(width: AppTheme.spacing12),
        Expanded(
          child: Text(
            text,
            style: context.bodySmallStyle?.copyWith(
              color: context.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _InstructionStep {
  final int number;
  final String title;
  final String description;

  _InstructionStep({
    required this.number,
    required this.title,
    required this.description,
  });
}
