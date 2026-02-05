// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      title: 'Admin',
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const _SectionHeader(title: 'SHOP MANAGEMENT'),
              _AdminTile(
                icon: Icons.dashboard_customize,
                label: 'Shop Admin Dashboard',
                subtitle: 'Manage products, orders, and inventory',
                iconColor: Colors.purple.shade400,
                onTap: () => _navigateTo(context, const ShopAdminDashboard()),
              ),
              _AdminTile(
                icon: Icons.store,
                label: 'Device Shop',
                subtitle: 'View and manage device listings',
                iconColor: Colors.teal.shade400,
                onTap: () => _navigateTo(context, const DeviceShopScreen()),
              ),
              const SizedBox(height: 16),
              const _SectionHeader(title: 'CONTENT MODERATION'),
              _AdminTile(
                icon: Icons.rate_review_outlined,
                label: 'Review Moderation',
                subtitle: 'Approve or reject user reviews',
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
                label: 'Reported Content',
                subtitle: 'Review flagged posts and comments',
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
                label: 'Widget Marketplace Review',
                subtitle: 'Approve pending widget submissions',
                iconColor: Colors.deepPurple.shade400,
                onTap: () => _navigateTo(context, const WidgetApprovalScreen()),
              ),
              const SizedBox(height: 16),
              const _SectionHeader(title: 'USER MANAGEMENT'),
              _AdminTile(
                icon: Icons.group_add_rounded,
                label: 'Social Seeding',
                subtitle: 'Manage follow requests and connections',
                iconColor: Colors.teal.shade400,
                onTap: () =>
                    _navigateTo(context, const AdminFollowRequestsScreen()),
              ),
              _AdminTile(
                icon: Icons.receipt_long,
                label: 'User Purchases',
                subtitle: 'View and manage user transactions',
                iconColor: Colors.amber.shade400,
                onTap: () =>
                    _navigateTo(context, const UserPurchasesAdminScreen()),
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
          const SizedBox(width: 6),
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
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 16),
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
                      const SizedBox(height: 2),
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badgeCount! > 99 ? '99+' : badgeCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
