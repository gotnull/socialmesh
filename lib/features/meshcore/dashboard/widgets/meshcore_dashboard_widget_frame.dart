// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/gradient_border_container.dart';
import '../../../dashboard/widgets/dashboard_widget.dart';
import '../models/meshcore_dashboard_widget_config.dart';

// MeshCore-side equivalent of `DashboardWidget`. Mirrors the Meshtastic
// frame byte-for-byte: gradient border on favorites, dashed border on
// edit mode, wobble animation, drag handle, star toggle, remove button,
// and confirmation sheet. The only protocol-scoped delta is the config
// type and registry it consumes.
class MeshCoreDashboardWidgetFrame extends StatefulWidget {
  final MeshCoreDashboardWidgetConfig config;
  final Widget child;
  final bool isEditMode;
  final VoidCallback? onRemove;
  final VoidCallback? onFavorite;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showHeader;
  final int? reorderIndex;

  const MeshCoreDashboardWidgetFrame({
    super.key,
    required this.config,
    required this.child,
    this.isEditMode = false,
    this.onRemove,
    this.onFavorite,
    this.onTap,
    this.trailing,
    this.showHeader = true,
    this.reorderIndex,
  });

  @override
  State<MeshCoreDashboardWidgetFrame> createState() =>
      _MeshCoreDashboardWidgetFrameState();
}

class _MeshCoreDashboardWidgetFrameState
    extends State<MeshCoreDashboardWidgetFrame>
    with SingleTickerProviderStateMixin {
  late AnimationController _wobbleController;
  late Animation<double> _wobbleAnimation;

  @override
  void initState() {
    super.initState();
    _wobbleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _wobbleAnimation = Tween<double>(begin: -0.01, end: 0.01).animate(
      CurvedAnimation(parent: _wobbleController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(MeshCoreDashboardWidgetFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEditMode && !oldWidget.isEditMode) {
      _wobbleController.repeat(reverse: true);
    } else if (!widget.isEditMode && oldWidget.isEditMode) {
      _wobbleController.stop();
      _wobbleController.reset();
    }
  }

  @override
  void dispose() {
    _wobbleController.dispose();
    super.dispose();
  }

  Future<void> _showRemoveConfirmation() async {
    final displayName = MeshCoreWidgetRegistry.getInfo(widget.config.type).name;

    final shouldRemove = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.dashboardRemoveWidgetTitle,
      message: context.l10n.dashboardRemoveWidgetMessage(displayName),
      confirmLabel: context.l10n.dashboardRemoveConfirm,
      isDestructive: true,
    );

    if (shouldRemove == true) {
      widget.onRemove?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = MeshCoreWidgetRegistry.getInfo(widget.config.type);
    final isFavorite = widget.config.isFavorite;
    final displayName = _localizedName(context, info);
    final displayIcon = info.icon;

    Widget content = widget.isEditMode
        ? CustomPaint(
            painter: DashedBorderPainter(
              color: context.accentColor.withValues(alpha: 0.6),
              strokeWidth: 2,
              dashWidth: 8,
              dashSpace: 4,
              borderRadius: 16,
            ),
            child: _buildCardContent(displayName, displayIcon, isFavorite),
          )
        : _buildCardContent(displayName, displayIcon, isFavorite);

    if (widget.isEditMode) {
      return AnimatedBuilder(
        animation: _wobbleAnimation,
        builder: (context, child) {
          return Transform.rotate(angle: _wobbleAnimation.value, child: child);
        },
        child: content,
      );
    }

    return content;
  }

  String _localizedName(BuildContext context, MeshCoreWidgetTypeInfo info) {
    final l10n = context.l10n;
    switch (info.type) {
      case MeshCoreDashboardWidgetType.networkOverview:
        return l10n.meshcoreWidgetNetworkOverviewName;
      case MeshCoreDashboardWidgetType.quickActions:
        return l10n.meshcoreWidgetQuickActionsName;
      case MeshCoreDashboardWidgetType.nearbyContacts:
        return l10n.meshcoreWidgetNearbyContactsName;
      case MeshCoreDashboardWidgetType.recentMessages:
        return l10n.meshcoreWidgetRecentMessagesName;
    }
  }

  Widget _buildCardContent(
    String displayName,
    IconData displayIcon,
    bool isFavorite,
  ) {
    final cardChild = ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radius15),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showHeader) _buildHeader(displayName, displayIcon),
            Flexible(child: widget.child),
          ],
        ),
      ),
    );

    if (isFavorite && !widget.isEditMode) {
      return GradientBorderContainer(
        borderRadius: 16,
        borderWidth: 2,
        accentOpacity: 1.0,
        backgroundColor: context.card,
        child: cardChild,
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(
          color: widget.isEditMode ? Colors.transparent : context.border,
          width: 1,
        ),
      ),
      child: cardChild,
    );
  }

  Widget _buildHeader(String displayName, IconData displayIcon) {
    Widget header = Container(
      padding: EdgeInsets.only(
        left: 16,
        right: widget.isEditMode ? 4 : 16,
        top: 12,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: context.background.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: context.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          if (widget.isEditMode) ...[
            Icon(Icons.drag_indicator, color: context.textTertiary, size: 20),
            SizedBox(width: AppTheme.spacing8),
          ],
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing6),
            decoration: BoxDecoration(
              color: context.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radius8),
            ),
            child: Icon(displayIcon, color: context.accentColor, size: 16),
          ),
          SizedBox(width: AppTheme.spacing10),
          Expanded(
            child: Text(
              displayName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          ),
          if (widget.trailing != null && !widget.isEditMode) ...[
            widget.trailing!,
            const SizedBox(width: AppTheme.spacing8),
          ],
          if (!widget.isEditMode && widget.config.isFavorite)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.star, color: AppTheme.warningYellow, size: 16),
            ),
          if (widget.isEditMode) ...[
            _EditButton(
              icon: widget.config.isFavorite ? Icons.star : Icons.star_border,
              color: widget.config.isFavorite
                  ? AppTheme.warningYellow
                  : context.textTertiary,
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onFavorite?.call();
              },
              tooltip: widget.config.isFavorite
                  ? context.l10n.dashboardRemoveFromFavorites
                  : context.l10n.dashboardAddToFavorites,
            ),
            _EditButton(
              icon: Icons.close,
              color: AppTheme.errorRed,
              onTap: () {
                HapticFeedback.mediumImpact();
                _showRemoveConfirmation();
              },
              tooltip: context.l10n.dashboardRemoveWidget,
            ),
          ],
        ],
      ),
    );

    if (widget.isEditMode && widget.reorderIndex != null) {
      header = ReorderableDragStartListener(
        index: widget.reorderIndex!,
        child: header,
      );
    }

    return header;
  }
}

class _EditButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _EditButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radius8),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing8),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }
}
