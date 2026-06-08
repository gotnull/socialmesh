// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';

/// Bottom sheet explaining what all the compact node tile icons mean.
class NodesLegendSheet extends StatelessWidget {
  const NodesLegendSheet({required this.scrollController, super.key});

  final ScrollController scrollController;

  static Future<void> show(BuildContext context) {
    return AppBottomSheet.showScrollable<void>(
      context: context,
      title: context.l10n.nodesScreenLegendTitle,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (controller) => NodesLegendSheet(scrollController: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing24,
        0,
        AppTheme.spacing24,
        AppTheme.spacing24,
      ),
      children: [
        _LegendSection(
          title: l10n.nodesScreenLegendSectionStatus,
          items: [
            _LegendItem(
              label: l10n.nodesScreenLegendStatusActive,
              icon: _statusDot(AccentColors.green, glow: true),
            ),
            _LegendItem(
              label: l10n.nodesScreenLegendStatusFading,
              icon: _statusDot(AppTheme.warningYellow),
            ),
            _LegendItem(
              label: l10n.nodesScreenLegendStatusStale,
              icon: _statusDot(context.textSecondary),
            ),
            _LegendItem(
              label: l10n.nodesScreenLegendStatusUnknown,
              icon: _statusDot(context.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing16),
        _LegendSection(
          title: l10n.nodesScreenLegendSectionSignal,
          items: [
            _LegendItem(
              label: l10n.nodesScreenLegendSignalStrong,
              icon: _signalBars(4, AccentColors.green),
            ),
            _LegendItem(
              label: l10n.nodesScreenLegendSignalMedium,
              icon: _signalBars(2, AppTheme.warningYellow),
            ),
            _LegendItem(
              label: l10n.nodesScreenLegendSignalWeak,
              icon: _signalBars(1, AppTheme.errorRed),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing16),
        _LegendSection(
          title: l10n.nodesScreenLegendSectionHops,
          items: [
            _LegendItem(
              label: l10n.nodesScreenLegendHopsDirect,
              icon: _hopDot(
                'D', // lint-allow: hardcoded-string
                AccentColors.green,
              ),
            ),
            _LegendItem(
              label: l10n.nodesScreenLegendHops1,
              icon: _hopDot(
                '1', // lint-allow: hardcoded-string
                AccentColors.green,
              ),
            ),
            _LegendItem(
              label: l10n.nodesScreenLegendHops2,
              icon: _hopDot(
                '2', // lint-allow: hardcoded-string
                AppTheme.warningYellow,
              ),
            ),
            _LegendItem(
              label: l10n.nodesScreenLegendHops3,
              icon: _hopDot(
                '3', // lint-allow: hardcoded-string
                AccentColors.orange,
              ),
            ),
            _LegendItem(
              label: l10n.nodesScreenLegendHops4Plus,
              icon: _hopDot(
                '4', // lint-allow: hardcoded-string
                AppTheme.errorRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing16),
        _LegendSection(
          title: l10n.nodesScreenLegendSectionTransport,
          items: [
            _LegendItem(
              label: l10n.nodesScreenLegendTransportRf,
              icon: Icon(
                Icons.cell_tower,
                size: 16,
                color: AccentColors.emerald,
              ),
            ),
            _LegendItem(
              label: l10n.nodesScreenLegendTransportMqtt,
              icon: Icon(
                Icons.cloud_outlined,
                size: 16,
                color: AccentColors.sky,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing16),
        _LegendSection(
          title: l10n.nodesScreenLegendSectionBattery,
          items: [
            _LegendItem(
              label: l10n.nodesScreenLegendBatteryGood,
              icon: Icon(
                Icons.battery_full,
                size: 16,
                color: AccentColors.green,
              ),
            ),
            _LegendItem(
              label: l10n.nodesScreenLegendBatteryLow,
              icon: Icon(
                Icons.battery_3_bar,
                size: 16,
                color: AppTheme.warningYellow,
              ),
            ),
            _LegendItem(
              label: l10n.nodesScreenLegendBatteryCritical,
              icon: Icon(
                Icons.battery_alert,
                size: 16,
                color: AppTheme.errorRed,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static Widget _statusDot(Color color, {bool glow = false}) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: glow
            ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4)]
            : null,
      ),
    );
  }

  static Widget _signalBars(int activeBars, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final isActive = i < activeBars;
        return Container(
          margin: const EdgeInsets.only(right: 1),
          width: 3,
          height: 6.0 + (i * 2.0),
          decoration: BoxDecoration(
            color: isActive
                ? color
                : SemanticColors.disabled.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(AppTheme.radius1),
          ),
        );
      }),
    );
  }

  static Widget _hopDot(String label, Color color) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color, width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1,
        ),
      ),
    );
  }
}

class _LegendSection extends StatelessWidget {
  final String title;
  final List<_LegendItem> items;

  const _LegendSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.accentColor,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppTheme.spacing8),
        ...items,
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Widget icon;
  final String label;

  const _LegendItem({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
      child: Row(
        children: [
          SizedBox(
            width: AppTheme.spacing24,
            child: Center(child: icon),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: context.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
