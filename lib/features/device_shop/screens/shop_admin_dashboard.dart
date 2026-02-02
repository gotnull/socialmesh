// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../providers/admin_shop_providers.dart';
import '../services/device_shop_service.dart';
import 'admin_products_screen.dart';
import 'admin_sellers_screen.dart';
import 'featured_products_screen.dart';
import 'review_moderation_screen.dart';

/// Admin dashboard for managing the device shop
class ShopAdminDashboard extends ConsumerWidget {
  const ShopAdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdminAsync = ref.watch(isShopAdminProvider);

    return isAdminAsync.when(
      data: (isAdmin) {
        if (!isAdmin) {
          return GlassScaffold(
            title: 'Access Denied',
            slivers: [
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock,
                        size: 64,
                        color: Colors.red.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Admin Access Required',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You do not have permission to access this area.',
                        style: TextStyle(color: context.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        return const _AdminDashboardContent();
      },
      loading: () => const GlassScaffold(
        title: 'Shop Admin',
        slivers: [
          SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
      error: (error, _) => GlassScaffold(
        title: 'Error',
        slivers: [
          SliverFillRemaining(child: Center(child: Text('Error: \$error'))),
        ],
      ),
    );
  }
}

class _AdminDashboardContent extends ConsumerWidget {
  const _AdminDashboardContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminShopStatisticsProvider);

    return GlassScaffold.body(
      titleWidget: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.admin_panel_settings, color: context.accentColor),
          ),
          const SizedBox(width: 12),
          const Text('Shop Admin'),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(adminShopStatisticsProvider),
          tooltip: 'Refresh',
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Statistics Cards
            statsAsync.when(
              data: (stats) => _buildStatisticsGrid(context, stats),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),

            const SizedBox(height: 32),

            // Quick Actions
            Text(
              'Quick Actions',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildQuickActions(context),

            const SizedBox(height: 32),

            // Management Sections
            Text(
              'Management',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildManagementCards(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsGrid(BuildContext context, AdminShopStatistics stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _StatCard(
          title: 'Total Products',
          value: stats.totalProducts.toString(),
          subtitle: '${stats.activeProducts} active',
          icon: Icons.inventory_2,
          color: Colors.blue,
        ),
        _StatCard(
          title: 'Total Sellers',
          value: stats.totalSellers.toString(),
          icon: Icons.store,
          color: Colors.green,
        ),
        _StatCard(
          title: 'Total Sales',
          value: stats.totalSales.toString(),
          icon: Icons.shopping_cart,
          color: Colors.orange,
        ),
        _StatCard(
          title: 'Total Views',
          value: _formatNumber(stats.totalViews),
          icon: Icons.visibility,
          color: Colors.purple,
        ),
        _StatCard(
          title: 'Reviews',
          value: stats.totalReviews.toString(),
          icon: Icons.star,
          color: Colors.amber,
        ),
        _StatCard(
          title: 'Est. Revenue',
          value: '\$${_formatNumber(stats.estimatedRevenue.round())}',
          icon: Icons.attach_money,
          color: Colors.teal,
        ),
        _StatCard(
          title: 'Out of Stock',
          value: stats.outOfStockProducts.toString(),
          icon: Icons.warning,
          color: stats.outOfStockProducts > 0 ? Colors.red : Colors.grey,
        ),
        _StatCard(
          title: 'Inactive',
          value: stats.inactiveProducts.toString(),
          icon: Icons.pause_circle,
          color: Colors.grey,
        ),
      ],
    );
  }

  String _formatNumber(num value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.add_box,
            label: 'Add Product',
            color: context.accentColor,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminProductEditScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            icon: Icons.store,
            label: 'Add Seller',
            color: Colors.green,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminSellerEditScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildManagementCards(BuildContext context) {
    return Column(
      children: [
        _ManagementCard(
          icon: Icons.inventory_2,
          title: 'Products',
          subtitle: 'Manage all product listings',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminProductsScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        _ManagementCard(
          icon: Icons.store,
          title: 'Sellers',
          subtitle: 'Manage seller profiles and partnerships',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminSellersScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        _ManagementCard(
          icon: Icons.star,
          title: 'Featured Products',
          subtitle: 'Manage featured product display order',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FeaturedProductsScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        _ManagementCard(
          icon: Icons.rate_review,
          title: 'Reviews',
          subtitle: 'Moderate product reviews',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReviewModerationScreen()),
            );
          },
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12, color: context.textSecondary),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(fontSize: 10, color: context.textTertiary),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManagementCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ManagementCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: context.accentColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
