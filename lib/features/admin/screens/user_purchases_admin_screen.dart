// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../utils/snackbar.dart';

/// Filter modes for the user list.
enum _UserFilter { all, paying, free, excluded, anonymous }

/// Product prices in AUD for revenue calculation
/// These should match RevenueCat product prices
const _productPricesAud = <String, double>{
  'theme_pack': 2.99,
  'ringtone_pack': 2.99,
  'widget_pack': 4.99,
  'automations_pack': 4.99,
  'ifttt_pack': 2.99,
  'complete_pack': 14.99,
  'cloud_monthly': 2.99,
  'cloud_yearly': 24.99,
};

/// Admin screen to view Firebase users and their RevenueCat purchases
class UserPurchasesAdminScreen extends ConsumerStatefulWidget {
  const UserPurchasesAdminScreen({super.key});

  @override
  ConsumerState<UserPurchasesAdminScreen> createState() =>
      _UserPurchasesAdminScreenState();
}

class _UserPurchasesAdminScreenState
    extends ConsumerState<UserPurchasesAdminScreen>
    with LifecycleSafeMixin<UserPurchasesAdminScreen> {
  final _searchController = TextEditingController();
  bool _isLoading = false;
  List<_UserWithPurchases> _users = [];
  String? _error;

  // Stats
  int _totalUsers = 0;

  /// Active list filter.
  _UserFilter _activeFilter = _UserFilter.all;

  /// User IDs excluded from revenue calculation via the toggle icon.
  final Set<String> _excludedUserIds = {};

  /// Total paying users (before exclusions).
  int get _totalPayingUsers =>
      _users.where((u) => u.purchases.isNotEmpty).length;

  /// Paying users after exclusions.
  int get _netPayingUsers => _users
      .where(
        (u) => u.purchases.isNotEmpty && !_excludedUserIds.contains(u.userId),
      )
      .length;

  /// Gross revenue (all paying users).
  double get _grossRevenue {
    double total = 0;
    for (final user in _users) {
      for (final purchase in user.purchases) {
        total += _productPricesAud[purchase.productId] ?? 0;
      }
    }
    return total;
  }

  /// Revenue from excluded users only.
  double get _excludedRevenue {
    double total = 0;
    for (final user in _users) {
      if (!_excludedUserIds.contains(user.userId)) continue;
      for (final purchase in user.purchases) {
        total += _productPricesAud[purchase.productId] ?? 0;
      }
    }
    return total;
  }

  /// Net revenue (gross minus excluded).
  double get _netRevenue => _grossRevenue - _excludedRevenue;

  /// Number of users currently excluded from revenue.
  int get _excludedCount => _excludedUserIds.length;

  /// Whether any exclusions are active.
  bool get _hasExclusions => _excludedUserIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    // Guard against multiple simultaneous loads
    if (_isLoading) return;

    safeSetState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Batch fetch all collections at once to minimize Firestore calls
      final futures = await Future.wait([
        FirebaseFirestore.instance.collection('users').get(),
        FirebaseFirestore.instance.collection('profiles').get(),
        FirebaseFirestore.instance.collection('user_entitlements').get(),
      ]);

      final usersSnapshot = futures[0];
      final profilesSnapshot = futures[1];
      final entitlementsSnapshot = futures[2];

      // Build lookup maps for O(1) access
      final profilesMap = <String, Map<String, dynamic>>{};
      for (final doc in profilesSnapshot.docs) {
        profilesMap[doc.id] = doc.data();
      }

      final entitlementsMap = <String, Map<String, dynamic>>{};
      for (final doc in entitlementsSnapshot.docs) {
        entitlementsMap[doc.id] = doc.data();
      }

      final users = <_UserWithPurchases>[];

      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        final userData = userDoc.data();
        final profileData = profilesMap[userId];
        final entData = entitlementsMap[userId];

        final purchases = <_Purchase>[];
        String? revenueCatId;

        // Check user_entitlements data (from batch fetch)
        if (entData != null) {
          final cloudSync = entData['cloud_sync'] as String?;
          final allProducts = entData['all_products'] as List<dynamic>?;
          final purchasedAt =
              (entData['purchase_date'] as Timestamp?)?.toDate() ??
              (entData['created_at'] as Timestamp?)?.toDate();
          final expiresAt = (entData['expires_at'] as Timestamp?)?.toDate();
          final source =
              entData['store'] as String? ??
              entData['source'] as String? ??
              'revenuecat';

          // If we have all_products array, show each product
          if (allProducts != null && allProducts.isNotEmpty) {
            for (final product in allProducts) {
              final productId = product as String;
              // Determine status for this product
              String status;
              if (productId == 'cloud_monthly' || productId == 'cloud_yearly') {
                // Subscription products
                status = cloudSync ?? 'unknown';
              } else {
                // One-time purchase products are always "owned"
                status = 'owned';
              }

              purchases.add(
                _Purchase(
                  productId: productId,
                  status: status,
                  purchasedAt: purchasedAt,
                  expiresAt:
                      (productId == 'cloud_monthly' ||
                          productId == 'cloud_yearly')
                      ? expiresAt
                      : null,
                  source: source,
                ),
              );
            }
          } else if (cloudSync != null && cloudSync.isNotEmpty) {
            // Fallback: just show cloud_sync status if no all_products
            final productId = entData['product_id'] as String? ?? 'Cloud Sync';
            purchases.add(
              _Purchase(
                productId: productId,
                status: cloudSync,
                purchasedAt: purchasedAt,
                expiresAt: expiresAt,
                source: source,
              ),
            );
          }

          revenueCatId = entData['revenuecat_app_user_id'] as String?;
        }

        // Note: Legacy subcollections (users/{uid}/entitlements and users/{uid}/purchases)
        // are no longer queried to avoid N+1 query problems. All purchase data now comes
        // from the top-level user_entitlements collection populated by RevenueCat webhooks.

        users.add(
          _UserWithPurchases(
            userId: userId,
            email: userData['email'] as String?,
            displayName:
                profileData?['displayName'] as String? ??
                userData['displayName'] as String?,
            avatarUrl: profileData?['avatarUrl'] as String?,
            revenueCatId: revenueCatId,
            purchases: purchases,
            createdAt:
                (userData['created_at'] as Timestamp?)?.toDate() ??
                (profileData?['createdAt'] as Timestamp?)?.toDate(),
          ),
        );
      }

      // Also check for any entitlements not linked to Firebase users
      // (e.g., anonymous RevenueCat purchases before sign-in)
      // We already have entitlementsSnapshot from the batch fetch above
      final existingUserIds = users.map((u) => u.userId).toSet();

      for (final entDoc in entitlementsSnapshot.docs) {
        final entUserId = entDoc.id;

        // Skip if we already have this user
        if (existingUserIds.contains(entUserId)) continue;

        final entData = entDoc.data();
        final cloudSync = entData['cloud_sync'] as String?;
        final allProducts = entData['all_products'] as List<dynamic>?;

        if (cloudSync != null && cloudSync.isNotEmpty) {
          final purchases = <_Purchase>[];
          final purchasedAt =
              (entData['purchase_date'] as Timestamp?)?.toDate() ??
              (entData['created_at'] as Timestamp?)?.toDate();
          final expiresAt = (entData['expires_at'] as Timestamp?)?.toDate();
          final source =
              entData['store'] as String? ??
              entData['source'] as String? ??
              'revenuecat';

          // If we have all_products array, show each product
          if (allProducts != null && allProducts.isNotEmpty) {
            for (final product in allProducts) {
              final productId = product as String;
              String status;
              if (productId == 'cloud_monthly' || productId == 'cloud_yearly') {
                status = cloudSync;
              } else {
                status = 'owned';
              }
              purchases.add(
                _Purchase(
                  productId: productId,
                  status: status,
                  purchasedAt: purchasedAt,
                  expiresAt:
                      (productId == 'cloud_monthly' ||
                          productId == 'cloud_yearly')
                      ? expiresAt
                      : null,
                  source: source,
                ),
              );
            }
          } else {
            // Fallback for old format
            purchases.add(
              _Purchase(
                productId: entData['product_id'] as String? ?? 'Cloud Sync',
                status: cloudSync,
                purchasedAt: purchasedAt,
                expiresAt: expiresAt,
                source: source,
              ),
            );
          }

          users.add(
            _UserWithPurchases(
              userId: entUserId,
              email: null,
              displayName: entUserId.startsWith(r'$RCAnonymousID')
                  ? 'Anonymous RevenueCat User'
                  : null,
              avatarUrl: null,
              revenueCatId: entData['revenuecat_app_user_id'] as String?,
              purchases: purchases,
              createdAt: (entData['created_at'] as Timestamp?)?.toDate(),
              isAnonymous: entUserId.startsWith(r'$RCAnonymousID'),
            ),
          );
        }
      }

      // Sort by purchase count (most purchases first)
      users.sort((a, b) => b.purchases.length.compareTo(a.purchases.length));

      if (!mounted) return;
      safeSetState(() {
        _users = users;
        _totalUsers = users.length;
        _isLoading = false;
      });
    } catch (e) {
      safeSetState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<_UserWithPurchases> get _filteredUsers {
    final query = _searchController.text.toLowerCase().trim();

    return _users.where((user) {
      // Apply category filter first
      switch (_activeFilter) {
        case _UserFilter.all:
          break;
        case _UserFilter.paying:
          if (user.purchases.isEmpty) return false;
        case _UserFilter.free:
          if (user.purchases.isNotEmpty) return false;
        case _UserFilter.excluded:
          if (!_excludedUserIds.contains(user.userId)) return false;
        case _UserFilter.anonymous:
          if (!user.isAnonymous) return false;
      }

      // Then apply text search
      if (query.isEmpty) return true;
      return (user.displayName?.toLowerCase().contains(query) ?? false) ||
          (user.email?.toLowerCase().contains(query) ?? false) ||
          user.userId.toLowerCase().contains(query) ||
          (user.revenueCatId?.toLowerCase().contains(query) ?? false) ||
          user.purchases.any((p) => p.productId.toLowerCase().contains(query));
    }).toList();
  }

  /// Count of users matching the current filter (for chip labels).
  int _countForFilter(_UserFilter filter) {
    switch (filter) {
      case _UserFilter.all:
        return _users.length;
      case _UserFilter.paying:
        return _totalPayingUsers;
      case _UserFilter.free:
        return _users.where((u) => u.purchases.isEmpty).length;
      case _UserFilter.excluded:
        return _excludedCount;
      case _UserFilter.anonymous:
        return _users.where((u) => u.isAnonymous).length;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'User Purchases',
      slivers: [
        // Stats cards — row 1: users overview
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Total Users',
                      value: _totalUsers.toString(),
                      icon: Icons.people,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Paying',
                      value: _hasExclusions
                          ? '$_netPayingUsers'
                          : '$_totalPayingUsers',
                      icon: Icons.shopping_bag,
                      color: Colors.green,
                      subtitle: _hasExclusions
                          ? '$_excludedCount excluded'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: _hasExclusions ? 'Net Revenue' : 'Gross Revenue',
                      value: _hasExclusions
                          ? 'A\$${_netRevenue.toStringAsFixed(2)}'
                          : 'A\$${_grossRevenue.toStringAsFixed(2)}',
                      icon: Icons.attach_money,
                      color: _hasExclusions ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Stats cards — row 2: revenue breakdown (only when exclusions active)
        if (_hasExclusions)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Gross Revenue',
                        value: 'A\$${_grossRevenue.toStringAsFixed(2)}',
                        icon: Icons.account_balance_wallet,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Excluded',
                        value: '-A\$${_excludedRevenue.toStringAsFixed(2)}',
                        icon: Icons.money_off,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Net Revenue',
                        value: 'A\$${_netRevenue.toStringAsFixed(2)}',
                        icon: Icons.trending_up,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Search bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: context.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),

        // Info banner about data sources
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: StatusBanner.info(
              title:
                  'Shows purchases synced via app login or RevenueCat webhooks.',
              subtitle:
                  'Users must open the app while signed in for their purchases to appear here.',
              borderRadius: 8,
            ),
          ),
        ),

        // Filter chips
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(context, _UserFilter.all, 'All'),
                  const SizedBox(width: 8),
                  _buildFilterChip(context, _UserFilter.paying, 'Paying'),
                  const SizedBox(width: 8),
                  _buildFilterChip(context, _UserFilter.free, 'Free'),
                  if (_hasExclusions) ...[
                    const SizedBox(width: 8),
                    _buildFilterChip(context, _UserFilter.excluded, 'Excluded'),
                  ],
                  const SizedBox(width: 8),
                  _buildFilterChip(context, _UserFilter.anonymous, 'Anonymous'),
                ],
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // Content
        if (_isLoading)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: context.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading users',
                    style: TextStyle(color: context.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(color: context.textTertiary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadUsers,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        else if (_filteredUsers.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 48,
                    color: context.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchController.text.isNotEmpty
                        ? 'No users match your search'
                        : 'No users found',
                    style: TextStyle(color: context.textSecondary),
                  ),
                ],
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final user = _filteredUsers[index];
              final isExcluded = _excludedUserIds.contains(user.userId);
              return _UserTile(
                user: user,
                onTap: () => _showUserDetail(user),
                isExcluded: isExcluded,
                onToggleExclude: user.purchases.isNotEmpty
                    ? () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (isExcluded) {
                            _excludedUserIds.remove(user.userId);
                          } else {
                            _excludedUserIds.add(user.userId);
                          }
                        });
                      }
                    : null,
              );
            }, childCount: _filteredUsers.length),
          ),
      ],
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    _UserFilter filter,
    String label,
  ) {
    final isActive = _activeFilter == filter;
    final count = _countForFilter(filter);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _activeFilter = filter);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? context.accentColor.withValues(alpha: 0.2)
              : context.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? context.accentColor : context.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? context.accentColor : context.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive
                    ? context.accentColor.withValues(alpha: 0.15)
                    : context.card,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isActive ? context.accentColor : context.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserDetail(_UserWithPurchases user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _UserDetailSheet(user: user),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: context.captionStyle?.copyWith(
                    color: context.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final _UserWithPurchases user;
  final VoidCallback onTap;
  final bool isExcluded;
  final VoidCallback? onToggleExclude;

  const _UserTile({
    required this.user,
    required this.onTap,
    this.isExcluded = false,
    this.onToggleExclude,
  });

  @override
  Widget build(BuildContext context) {
    final hasPurchases = user.purchases.isNotEmpty;

    return Opacity(
      opacity: isExcluded ? 0.45 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Material(
          color: context.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: hasPurchases
                        ? Colors.green.shade800
                        : context.card,
                    backgroundImage: user.avatarUrl != null
                        ? NetworkImage(user.avatarUrl!)
                        : null,
                    child: user.avatarUrl == null
                        ? Icon(
                            Icons.person,
                            size: 22,
                            color: hasPurchases
                                ? Colors.white
                                : context.textSecondary,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // User info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user.displayName ?? 'Unknown User',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (user.isAnonymous) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Anonymous',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (user.email != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            user.email!,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                        if (user.purchases.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: user.purchases.map((p) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _getProductColor(
                                    p.productId,
                                  ).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _formatProductName(p.productId),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _getProductColor(p.productId),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Purchase count badge
                  if (hasPurchases) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${user.purchases.length}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  // Exclude from revenue toggle
                  if (hasPurchases) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: onToggleExclude,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          isExcluded
                              ? Icons.money_off_csred_outlined
                              : Icons.attach_money,
                          color: isExcluded
                              ? Colors.red.shade400
                              : context.textTertiary,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                  // Chevron
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: context.textTertiary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getProductColor(String productId) {
    if (productId.contains('complete')) return Colors.purple;
    if (productId.contains('theme')) return Colors.blue;
    if (productId.contains('ringtone')) return Colors.orange;
    if (productId.contains('widget')) return Colors.teal;
    if (productId.contains('automation')) return Colors.pink;
    if (productId.contains('ifttt')) return Colors.red;
    return Colors.grey;
  }

  String _formatProductName(String productId) {
    return productId
        .replaceAll('_', ' ')
        .replaceAll('com.gotnull.socialmesh.', '')
        .split(' ')
        .map(
          (w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '',
        )
        .join(' ');
  }
}

class _UserDetailSheet extends StatelessWidget {
  final _UserWithPurchases user;

  const _UserDetailSheet({required this.user});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.textTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Content
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      // User header
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: context.surface,
                            backgroundImage: user.avatarUrl != null
                                ? NetworkImage(user.avatarUrl!)
                                : null,
                            child: user.avatarUrl == null
                                ? Icon(
                                    Icons.person,
                                    size: 32,
                                    color: context.textSecondary,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        user.displayName ?? 'Unknown User',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: context.textPrimary,
                                        ),
                                      ),
                                    ),
                                    if (user.isAnonymous) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          'Anonymous',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.orange.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (user.email != null)
                                  Text(
                                    user.email!,
                                    style: TextStyle(
                                      color: context.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // IDs section
                      _SectionHeader(title: 'Identifiers'),
                      _InfoTile(
                        icon: Icons.fingerprint,
                        label: 'Firebase UID',
                        value: user.userId,
                        onCopy: () => _copyToClipboard(context, user.userId),
                      ),
                      if (user.revenueCatId != null)
                        _InfoTile(
                          icon: Icons.receipt_long,
                          label: 'RevenueCat ID',
                          value: user.revenueCatId!,
                          onCopy: () =>
                              _copyToClipboard(context, user.revenueCatId!),
                        ),
                      if (user.createdAt != null)
                        _InfoTile(
                          icon: Icons.calendar_today,
                          label: 'Member Since',
                          value: dateFormat.format(user.createdAt!),
                        ),

                      const SizedBox(height: 24),

                      // Purchases section
                      _SectionHeader(
                        title: 'Purchases',
                        trailing: Text(
                          '${user.purchases.length} items',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),

                      if (user.purchases.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: context.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 48,
                                  color: context.textTertiary,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No purchases',
                                  style: TextStyle(
                                    color: context.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...user.purchases.map(
                          (purchase) => _PurchaseTile(
                            purchase: purchase,
                            dateFormat: dateFormat,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    showSuccessSnackBar(context, 'Copied to clipboard');
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
            ),
          ),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onCopy;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.captionStyle?.copyWith(
                    color: context.textTertiary,
                  ),
                ),
                Text(
                  value,
                  style: context.bodySmallStyle?.copyWith(
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (onCopy != null)
            IconButton(
              icon: Icon(Icons.copy, size: 18, color: context.textSecondary),
              onPressed: onCopy,
              tooltip: 'Copy',
            ),
        ],
      ),
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  final _Purchase purchase;
  final DateFormat dateFormat;

  const _PurchaseTile({required this.purchase, required this.dateFormat});

  @override
  Widget build(BuildContext context) {
    final color = _getProductColor(purchase.productId);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getProductIcon(purchase.productId),
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatProductName(purchase.productId),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    Text(
                      purchase.productId,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(
                    purchase.status,
                  ).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  purchase.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(purchase.status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (purchase.purchasedAt != null) ...[
                Icon(
                  Icons.calendar_today,
                  size: 12,
                  color: context.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  dateFormat.format(purchase.purchasedAt!),
                  style: context.captionStyle?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (_productPricesAud.containsKey(purchase.productId)) ...[
                Icon(Icons.attach_money, size: 12, color: context.textTertiary),
                const SizedBox(width: 4),
                Text(
                  'A\$${_productPricesAud[purchase.productId]!.toStringAsFixed(2)}',
                  style: context.captionStyle?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Icon(Icons.store, size: 12, color: context.textTertiary),
              const SizedBox(width: 4),
              Text(
                purchase.source,
                style: context.captionStyle?.copyWith(
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getProductColor(String productId) {
    if (productId.contains('complete')) return Colors.purple;
    if (productId.contains('theme')) return Colors.blue;
    if (productId.contains('ringtone')) return Colors.orange;
    if (productId.contains('widget')) return Colors.teal;
    if (productId.contains('automation')) return Colors.pink;
    if (productId.contains('ifttt')) return Colors.red;
    return Colors.grey;
  }

  IconData _getProductIcon(String productId) {
    if (productId.contains('complete')) return Icons.all_inclusive;
    if (productId.contains('theme')) return Icons.palette;
    if (productId.contains('ringtone')) return Icons.music_note;
    if (productId.contains('widget')) return Icons.widgets;
    if (productId.contains('automation')) return Icons.auto_awesome;
    if (productId.contains('ifttt')) return Icons.link;
    return Icons.shopping_bag;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'owned':
      case 'lifetime_complete':
        return Colors.green;
      case 'expired':
        return Colors.red;
      case 'grace_period':
        return Colors.orange;
      case 'grandfathered':
        return Colors.blue;
      case 'feature_only':
      case 'lifetime_features':
        return Colors.purple; // Has feature packs but no cloud sync
      default:
        return Colors.grey;
    }
  }

  String _formatProductName(String productId) {
    return productId
        .replaceAll('_', ' ')
        .replaceAll('com.gotnull.socialmesh.', '')
        .split(' ')
        .map(
          (w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '',
        )
        .join(' ');
  }
}

// Data models
class _UserWithPurchases {
  final String userId;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final String? revenueCatId;
  final List<_Purchase> purchases;
  final DateTime? createdAt;
  final bool isAnonymous;

  _UserWithPurchases({
    required this.userId,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.revenueCatId,
    required this.purchases,
    this.createdAt,
    this.isAnonymous = false,
  });
}

class _Purchase {
  final String productId;
  final String status;
  final DateTime? purchasedAt;
  final DateTime? expiresAt;
  final String source;

  _Purchase({
    required this.productId,
    required this.status,
    this.purchasedAt,
    this.expiresAt,
    required this.source,
  });
}
