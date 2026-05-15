// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../providers/social_providers.dart';
import '../../device_shop/screens/device_shop_screen.dart';
import '../../device_shop/screens/shop_admin_dashboard.dart';
import '../../device_shop/screens/review_moderation_screen.dart';
import '../../device_shop/providers/admin_shop_providers.dart';
import '../../social/screens/reported_content_screen.dart';
import '../../settings/admin_follow_requests_screen.dart';
import '../../widget_builder/marketplace/widget_approval_screen.dart';
import '../bug_reports/admin_bug_report_providers.dart';
import '../bug_reports/admin_bug_reports_screen.dart';
import '../conformance/ui/admin_conformance_screen.dart';
import 'admin_broadcast_screen.dart';
import 'admin_diagnostics_screen.dart';
import 'admin_storage_health_screen.dart';
import 'mesh_morph_preview_screen.dart';
import 'qr_style_preview_screen.dart';
import 'user_purchases_admin_screen.dart';

/// Admin hub screen with all admin-only features.
///
/// This screen is accessible after PIN verification and contains
/// administrative tools for managing the app's backend features.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassScaffold(
      title: context.l10n.adminPanelTitle,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _SectionHeader(title: context.l10n.adminPanelSectionShop),
              _AdminTile(
                icon: Icons.dashboard_customize,
                label: context.l10n.adminPanelShopDashboard,
                subtitle: context.l10n.adminPanelShopDashboardSub,
                iconColor: Colors.purple.shade400,
                onTap: () => _navigateTo(context, const ShopAdminDashboard()),
              ),
              _AdminTile(
                icon: Icons.store,
                label: context.l10n.adminPanelDeviceShop,
                subtitle: context.l10n.adminPanelDeviceShopSub,
                iconColor: Colors.teal.shade400,
                onTap: () => _navigateTo(context, const DeviceShopScreen()),
              ),
              const SizedBox(height: AppTheme.spacing16),
              _SectionHeader(title: context.l10n.adminPanelSectionModeration),
              _AdminTile(
                icon: Icons.bug_report,
                label: context.l10n.adminPanelBugReports,
                subtitle: context.l10n.adminPanelBugReportsSub,
                iconColor: Colors.pink.shade400,
                badgeCount: ref.watch(adminOpenBugReportCountProvider),
                onTap: () =>
                    _navigateTo(context, const AdminBugReportsScreen()),
              ),
              _AdminTile(
                icon: Icons.rate_review_outlined,
                label: context.l10n.adminPanelReviewMod,
                subtitle: context.l10n.adminPanelReviewModSub,
                iconColor: Colors.blue.shade400,
                badgeCount: ref
                    .watch(pendingReviewCountProvider)
                    .when(
                      data: (count) => count,
                      loading: () => null,
                      error: (e, stack) => null,
                    ),
                onTap: () =>
                    _navigateTo(context, const ReviewModerationScreen()),
              ),
              _AdminTile(
                icon: Icons.flag_outlined,
                label: context.l10n.adminPanelReportedContent,
                subtitle: context.l10n.adminPanelReportedContentSub,
                iconColor: Colors.red.shade400,
                badgeCount: ref
                    .watch(pendingReportCountProvider)
                    .when(
                      data: (count) => count,
                      loading: () => null,
                      error: (e, stack) => null,
                    ),
                onTap: () =>
                    _navigateTo(context, const ReportedContentScreen()),
              ),
              _AdminTile(
                icon: Icons.widgets_outlined,
                label: context.l10n.adminPanelWidgetReview,
                subtitle: context.l10n.adminPanelWidgetReviewSub,
                iconColor: Colors.deepPurple.shade400,
                onTap: () => _navigateTo(context, const WidgetApprovalScreen()),
              ),
              const SizedBox(height: AppTheme.spacing16),
              _SectionHeader(title: context.l10n.adminPanelSectionUsers),
              _AdminTile(
                icon: Icons.group_add_rounded,
                label: context.l10n.adminPanelSocialSeeding,
                subtitle: context.l10n.adminPanelSocialSeedingSub,
                iconColor: Colors.teal.shade400,
                onTap: () =>
                    _navigateTo(context, const AdminFollowRequestsScreen()),
              ),
              _AdminTile(
                icon: Icons.receipt_long,
                label: context.l10n.adminPanelUserPurchases,
                subtitle: context.l10n.adminPanelUserPurchasesSub,
                iconColor: Colors.amber.shade400,
                onTap: () =>
                    _navigateTo(context, const UserPurchasesAdminScreen()),
              ),
              const SizedBox(height: AppTheme.spacing16),
              _SectionHeader(title: context.l10n.adminPanelSectionConfig),
              _AdminTile(
                icon: Icons.campaign_outlined,
                label: context.l10n.adminPanelBroadcast,
                subtitle: context.l10n.adminPanelBroadcastSub,
                iconColor: Colors.orange.shade400,
                onTap: () => _navigateTo(context, const AdminBroadcastScreen()),
              ),
              _AdminTile(
                icon: Icons.qr_code_2,
                label: context.l10n.adminPanelQrStyles,
                subtitle: context.l10n.adminPanelQrStylesSub,
                iconColor: Colors.cyan.shade400,
                onTap: () => _navigateTo(context, const QrStylePreviewScreen()),
              ),
              const SizedBox(height: AppTheme.spacing16),
              _SectionHeader(title: context.l10n.adminPanelSectionDiag),
              _AdminTile(
                icon: Icons.biotech,
                label: context.l10n.adminPanelDiagHarness,
                subtitle: context.l10n.adminPanelDiagHarnessSub,
                iconColor: Colors.lime.shade400,
                onTap: () =>
                    _navigateTo(context, const AdminDiagnosticsScreen()),
              ),
              _AdminTile(
                icon: Icons.verified,
                label: context.l10n.adminPanelConformance,
                subtitle: context.l10n.adminPanelConformanceSub,
                iconColor: Colors.amber.shade400,
                onTap: () =>
                    _navigateTo(context, const AdminConformanceScreen()),
              ),
              _AdminTile(
                icon: Icons.storage_rounded,
                label: context.l10n.adminPanelStorageHealth,
                subtitle: context.l10n.adminPanelStorageHealthSub,
                iconColor: Colors.teal.shade400,
                onTap: () =>
                    _navigateTo(context, const AdminStorageHealthScreen()),
              ),
              _AdminTile(
                icon: Icons.auto_awesome,
                label: context.l10n.adminPanelMeshMorph,
                subtitle: context.l10n.adminPanelMeshMorphSub,
                iconColor: Colors.deepPurple.shade400,
                onTap: () =>
                    _navigateTo(context, const MeshMorphPreviewScreen()),
              ),
              // Bottom padding
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ]),
          ),
        ),
      ],
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => screen));
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8, bottom: 12),
      child: Row(
        children: [
          Icon(
            Icons.admin_panel_settings,
            size: 14,
            color: Colors.orange.withValues(alpha: 0.7),
          ),
          const SizedBox(width: AppTheme.spacing6),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: Colors.orange.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.iconColor,
    required this.onTap,
    this.badgeCount,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color iconColor;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showBadge = badgeCount != null && badgeCount! > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radius10),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: AppTheme.spacing16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showBadge) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                    child: Text(
                      badgeCount! > 99
                          ? context.l10n.adminPanelBadgeOverflow
                          : badgeCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                ],
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
