// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/search_filter_header.dart';
import '../../../core/widgets/status_filter_chip.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../utils/snackbar.dart';

/// Filter modes for the user list.
enum _UserFilter { all, paying, free, excluded, anonymous, deleted }

// Product prices in AUD for revenue calculation. Mirrors the canonical
// RevenueCat prices and the backend PRODUCT_CATALOG in
// `backend/functions/src/external_checkout.ts`. When a price changes
// in RevenueCat, this map, the backend catalog, and the Stripe price
// IDs in `backend/functions/.env` all change as a unit.
const _productPricesAud = <String, double>{
  'theme_pack': 4.99,
  'ringtone_pack': 1.99,
  'widget_pack': 4.99,
  'automations_pack': 5.99,
  'ifttt_pack': 4.99,
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
  static const _excludedIdsKey = 'admin_excluded_user_ids';

  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;
  List<_UserWithPurchases> _users = [];
  String? _error;

  // Stats
  int _totalUsers = 0;

  /// Active list filter.
  _UserFilter _activeFilter = _UserFilter.all;

  /// User IDs excluded from revenue calculation via the toggle icon.
  final Set<String> _excludedUserIds = {};

  Future<void> _loadExcludedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_excludedIdsKey);
    if (ids != null && mounted) {
      setState(() => _excludedUserIds.addAll(ids));
    }
  }

  Future<void> _saveExcludedIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_excludedIdsKey, _excludedUserIds.toList());
  }

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

  /// Free (non-paying) users.
  int get _freeUsers => _users.where((u) => u.purchases.isEmpty).length;

  /// Conversion rate (paying / total).
  double get _conversionRate =>
      _totalUsers > 0 ? (_netPayingUsers / _totalUsers) * 100 : 0;

  /// Average revenue per user (net revenue / total users).
  double get _arpu => _totalUsers > 0 ? _netRevenue / _totalUsers : 0;

  /// Whether any exclusions are active.
  bool get _hasExclusions => _excludedUserIds.isNotEmpty;

  /// Cutoff for "last 24 hours" calculations.
  DateTime get _last24hCutoff =>
      DateTime.now().subtract(const Duration(hours: 24));

  /// New users in last 24 hours.
  int get _newUsersLast24h => _users
      .where((u) => u.createdAt != null && u.createdAt!.isAfter(_last24hCutoff))
      .length;

  /// New purchases in last 24 hours.
  int get _newPurchasesLast24h {
    int count = 0;
    for (final user in _users) {
      for (final purchase in user.purchases) {
        if (purchase.purchasedAt != null &&
            purchase.purchasedAt!.isAfter(_last24hCutoff)) {
          count++;
        }
      }
    }
    return count;
  }

  /// Revenue from purchases in last 24 hours.
  double get _revenueLast24h {
    double total = 0;
    for (final user in _users) {
      if (_excludedUserIds.contains(user.userId)) continue;
      for (final purchase in user.purchases) {
        if (purchase.purchasedAt != null &&
            purchase.purchasedAt!.isAfter(_last24hCutoff)) {
          total += _productPricesAud[purchase.productId] ?? 0;
        }
      }
    }
    return total;
  }

  /// Helper to build a stat card row with consistent padding.
  Widget _buildStatRow(List<Widget> children) {
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      spaced.add(Expanded(child: children[i]));
      if (i < children.length - 1) {
        spaced.add(const SizedBox(width: AppTheme.spacing12));
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 0, 16, 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: spaced,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadExcludedIds();
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

    final l10n = context.l10n;

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
            final productId =
                entData['product_id'] as String? ??
                l10n.adminPurchasesFallbackCloudSync;
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
            countryCode: entData?['country_code'] as String?,
            currency: entData?['currency'] as String?,
            priceUsd: (entData?['price_usd'] as num?)?.toDouble(),
            priceLocal: (entData?['price_local'] as num?)?.toDouble(),
            taxPercentage: (entData?['tax_percentage'] as num?)?.toDouble(),
            commissionPercentage: (entData?['commission_percentage'] as num?)
                ?.toDouble(),
            offerCode: entData?['offer_code'] as String?,
            isFamilyShare: entData?['is_family_share'] as bool? ?? false,
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
                productId:
                    entData['product_id'] as String? ??
                    l10n.adminPurchasesFallbackCloudSync,
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
                  ? l10n.adminPurchasesAnonRcUser
                  : null,
              avatarUrl: null,
              revenueCatId: entData['revenuecat_app_user_id'] as String?,
              purchases: purchases,
              createdAt: (entData['created_at'] as Timestamp?)?.toDate(),
              isAnonymous: entUserId.startsWith(r'$RCAnonymousID'),
              isDeleted: !entUserId.startsWith(r'$RCAnonymousID'),
              countryCode: entData['country_code'] as String?,
              currency: entData['currency'] as String?,
              priceUsd: (entData['price_usd'] as num?)?.toDouble(),
              priceLocal: (entData['price_local'] as num?)?.toDouble(),
              taxPercentage: (entData['tax_percentage'] as num?)?.toDouble(),
              commissionPercentage: (entData['commission_percentage'] as num?)
                  ?.toDouble(),
              offerCode: entData['offer_code'] as String?,
              isFamilyShare: entData['is_family_share'] as bool? ?? false,
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
    final query = _searchQuery.toLowerCase().trim();

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
        case _UserFilter.deleted:
          if (!user.isDeleted) return false;
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
      case _UserFilter.deleted:
        return _users.where((u) => u.isDeleted).length;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GlassScaffold(
      resizeToAvoidBottomInset: false,
      titleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.adminPurchasesTitle,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          if (!_isLoading && _error == null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text.rich(
                softWrap: true,
                maxLines: 3,
                TextSpan(
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                  children: [
                    TextSpan(
                      text: '$_totalUsers',
                      style: const TextStyle(color: Colors.blue),
                    ),
                    TextSpan(
                      text: ' ${l10n.adminPurchasesLabelTotal} · ',
                      style: TextStyle(color: context.textTertiary),
                    ),
                    TextSpan(
                      text: '$_netPayingUsers',
                      style: const TextStyle(color: Colors.green),
                    ),
                    TextSpan(
                      text: ' ${l10n.adminPurchasesLabelPaying} · ',
                      style: TextStyle(color: context.textTertiary),
                    ),
                    TextSpan(
                      text: '$_freeUsers',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    TextSpan(
                      text: ' ${l10n.adminPurchasesLabelFree} · ',
                      style: TextStyle(color: context.textTertiary),
                    ),
                    TextSpan(
                      text: 'A\$${_netRevenue.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.green),
                    ),
                    TextSpan(
                      text: ' ${l10n.adminPurchasesLabelRevenue}',
                      style: TextStyle(color: context.textTertiary),
                    ),
                    if (_hasExclusions) ...[
                      TextSpan(
                        text: ' · ',
                        style: TextStyle(color: context.textTertiary),
                      ),
                      TextSpan(
                        text: '$_excludedCount',
                        style: const TextStyle(color: Colors.red),
                      ),
                      TextSpan(
                        text: ' ${l10n.adminPurchasesLabelExcluded}',
                        style: TextStyle(color: context.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
      slivers: [
        // Stats — Row 1: User counts
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _buildStatRow([
              _StatCard(
                label: l10n.adminPurchasesStatTotalUsers,
                value: _totalUsers.toString(),
                icon: Icons.people,
                color: Colors.blue,
              ),
              _StatCard(
                label: l10n.adminPurchasesStatPaying,
                value: _hasExclusions
                    ? '$_netPayingUsers'
                    : '$_totalPayingUsers',
                icon: Icons.shopping_bag,
                color: Colors.green,
                subtitle: _hasExclusions
                    ? l10n.adminPurchasesStatExcludedCount(_excludedCount)
                    : null,
              ),
              _StatCard(
                label: l10n.adminPurchasesStatFree,
                value: '$_freeUsers',
                icon: Icons.person_outline,
                color: Colors.grey,
              ),
            ]),
          ),
        ),

        // Stats — Row 2: Conversion & ARPU
        SliverToBoxAdapter(
          child: _buildStatRow([
            _StatCard(
              label: l10n.adminPurchasesStatConversion,
              value: '${_conversionRate.toStringAsFixed(1)}%',
              icon: Icons.trending_up,
              color: Colors.purple,
            ),
            _StatCard(
              label: l10n.adminPurchasesStatArpu,
              value: 'A\$${_arpu.toStringAsFixed(2)}',
              icon: Icons.bar_chart,
              color: Colors.teal,
              tooltip: l10n.adminPurchasesStatArpuTooltip,
            ),
          ]),
        ),

        // Stats — Row 3: Revenue (always shown)
        SliverToBoxAdapter(
          child: _buildStatRow([
            _StatCard(
              label: l10n.adminPurchasesStatGross,
              value: 'A\$${_grossRevenue.toStringAsFixed(2)}',
              icon: Icons.account_balance_wallet,
              color: Colors.orange,
            ),
            if (_hasExclusions)
              _StatCard(
                label: l10n.adminPurchasesStatExcluded,
                value: '-A\$${_excludedRevenue.toStringAsFixed(2)}',
                icon: Icons.money_off,
                color: Colors.red,
              ),
            _StatCard(
              label: l10n.adminPurchasesStatNet,
              value: 'A\$${_netRevenue.toStringAsFixed(2)}',
              icon: Icons.attach_money,
              color: Colors.green,
            ),
          ]),
        ),

        // Stats — Row 4: Last 24 hours
        SliverToBoxAdapter(
          child: _buildStatRow([
            _StatCard(
              label: l10n.adminPurchasesStatNewUsers24h,
              value: _newUsersLast24h.toString(),
              icon: Icons.person_add,
              color: Colors.blue,
            ),
            _StatCard(
              label: l10n.adminPurchasesStatPurchases24h,
              value: _newPurchasesLast24h.toString(),
              icon: Icons.shopping_cart,
              color: Colors.deepPurple,
            ),
            _StatCard(
              label: l10n.adminPurchasesStatRevenue24h,
              value: 'A\$${_revenueLast24h.toStringAsFixed(2)}',
              icon: Icons.trending_up,
              color: Colors.green,
            ),
          ]),
        ),

        // Pinned search header with filter chips
        SliverPersistentHeader(
          pinned: true,
          delegate: SearchFilterHeaderDelegate(
            searchController: _searchController,
            searchQuery: _searchQuery,
            onSearchChanged: (value) => setState(() => _searchQuery = value),
            hintText: l10n.adminPurchasesSearchHint,
            textScaler: MediaQuery.textScalerOf(context),
            rebuildKey: Object.hashAll([
              _activeFilter,
              _users.length,
              _excludedUserIds.length,
            ]),
            filterChips: [
              StatusFilterChip(
                label: l10n.adminPurchasesFilterAll,
                count: _countForFilter(_UserFilter.all),
                isSelected: _activeFilter == _UserFilter.all,
                onTap: () => setState(() => _activeFilter = _UserFilter.all),
              ),
              StatusFilterChip(
                label: l10n.adminPurchasesFilterPaying,
                count: _countForFilter(_UserFilter.paying),
                isSelected: _activeFilter == _UserFilter.paying,
                color: AccentColors.green,
                onTap: () => setState(() => _activeFilter = _UserFilter.paying),
              ),
              StatusFilterChip(
                label: l10n.adminPurchasesFilterFree,
                count: _countForFilter(_UserFilter.free),
                isSelected: _activeFilter == _UserFilter.free,
                onTap: () => setState(() => _activeFilter = _UserFilter.free),
              ),
              if (_hasExclusions)
                StatusFilterChip(
                  label: l10n.adminPurchasesFilterExcluded,
                  count: _countForFilter(_UserFilter.excluded),
                  isSelected: _activeFilter == _UserFilter.excluded,
                  color: AppTheme.errorRed,
                  onTap: () =>
                      setState(() => _activeFilter = _UserFilter.excluded),
                ),
              StatusFilterChip(
                label: l10n.adminPurchasesFilterAnonymous,
                count: _countForFilter(_UserFilter.anonymous),
                isSelected: _activeFilter == _UserFilter.anonymous,
                onTap: () =>
                    setState(() => _activeFilter = _UserFilter.anonymous),
              ),
              if (_users.any((u) => u.isDeleted))
                StatusFilterChip(
                  label: l10n.adminPurchasesFilterDeleted,
                  count: _countForFilter(_UserFilter.deleted),
                  isSelected: _activeFilter == _UserFilter.deleted,
                  color: AppTheme.errorRed,
                  icon: Icons.delete_outline,
                  onTap: () =>
                      setState(() => _activeFilter = _UserFilter.deleted),
                ),
            ],
          ),
        ),

        // Info banner about data sources
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 8, 16, 0),
            child: StatusBanner.info(
              title: l10n.adminPurchasesBannerTitle,
              subtitle: l10n.adminPurchasesBannerSubtitle,
              borderRadius: 8,
            ),
          ),
        ),

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
                  const SizedBox(height: AppTheme.spacing16),
                  Text(
                    l10n.adminPurchasesErrorLoading,
                    style: TextStyle(color: context.textSecondary),
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  Text(
                    _error!,
                    style: TextStyle(color: context.textTertiary, fontSize: 12),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  ElevatedButton.icon(
                    onPressed: _loadUsers,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.adminPurchasesRetry),
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
                  const SizedBox(height: AppTheme.spacing16),
                  Text(
                    _searchQuery.isNotEmpty
                        ? l10n.adminPurchasesNoSearchResults
                        : l10n.adminPurchasesNoUsers,
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
                isDeleted: user.isDeleted,
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
                        _saveExcludedIds();
                      }
                    : null,
              );
            }, childCount: _filteredUsers.length),
          ),
      ],
    );
  }

  void _showUserDetail(_UserWithPurchases user) {
    AppBottomSheet.showRaw<void>(
      context: context,
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
  final String? tooltip;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: AppTheme.spacing6),
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
          const SizedBox(height: AppTheme.spacing4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppTheme.spacing2),
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

    if (tooltip != null) {
      card = Tooltip(message: tooltip!, preferBelow: false, child: card);
    }

    return card;
  }
}

class _UserTile extends StatelessWidget {
  final _UserWithPurchases user;
  final VoidCallback onTap;
  final bool isExcluded;
  final bool isDeleted;
  final VoidCallback? onToggleExclude;

  const _UserTile({
    required this.user,
    required this.onTap,
    this.isExcluded = false,
    this.isDeleted = false,
    this.onToggleExclude,
  });

  @override
  Widget build(BuildContext context) {
    final hasPurchases = user.purchases.isNotEmpty;

    return Opacity(
      opacity: isExcluded || isDeleted ? 0.35 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Material(
          color: context.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              child: Row(
                children: [
                  // Avatar
                  UserAvatar(
                    imageUrl: user.avatarUrl,
                    size: 44,
                    backgroundColor: hasPurchases
                        ? Colors.green.shade800
                        : context.card,
                    foregroundColor: hasPurchases
                        ? Colors.white
                        : context.textSecondary,
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  // User info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if (user.countryFlag != null) ...[
                              Text(
                                user.countryFlag!,
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(width: AppTheme.spacing6),
                            ],
                            Flexible(
                              child: Text(
                                user.displayName ??
                                    context.l10n.adminPurchasesUnknownUser,
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (user.countryCode != null) ...[
                              const SizedBox(width: AppTheme.spacing6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radius4,
                                  ),
                                ),
                                child: Text(
                                  user.countryCode!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: context.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            if (user.isAnonymous) ...[
                              const SizedBox(width: AppTheme.spacing6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radius4,
                                  ),
                                ),
                                child: Text(
                                  context.l10n.adminPurchasesAnonymousTag,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                            if (isDeleted) ...[
                              const SizedBox(width: AppTheme.spacing6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radius4,
                                  ),
                                ),
                                child: Text(
                                  context.l10n.adminPurchasesDeletedTag,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (user.email != null) ...[
                          const SizedBox(height: AppTheme.spacing2),
                          Text(
                            user.email!,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                        if (user.purchases.isNotEmpty) ...[
                          const SizedBox(height: AppTheme.spacing6),
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
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radius4,
                                  ),
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
                    const SizedBox(width: AppTheme.spacing8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
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
                    const SizedBox(width: AppTheme.spacing4),
                    GestureDetector(
                      onTap: onToggleExclude,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacing4),
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
                  const SizedBox(width: AppTheme.spacing4),
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
                    borderRadius: BorderRadius.circular(AppTheme.radius2),
                  ),
                ),

                // Content
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(AppTheme.spacing16),
                    children: [
                      // User header
                      Row(
                        children: [
                          UserAvatar(
                            imageUrl: user.avatarUrl,
                            size: 64,
                            backgroundColor: context.surface,
                            foregroundColor: context.textSecondary,
                          ),
                          const SizedBox(width: AppTheme.spacing16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        user.displayName ??
                                            context
                                                .l10n
                                                .adminPurchasesUnknownUser,
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: context.textPrimary,
                                        ),
                                      ),
                                    ),
                                    if (user.isAnonymous) ...[
                                      const SizedBox(width: AppTheme.spacing8),
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
                                          context
                                              .l10n
                                              .adminPurchasesAnonymousTag,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.orange.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (user.isDeleted) ...[
                                      const SizedBox(width: AppTheme.spacing8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          context.l10n.adminPurchasesDeletedTag,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.red.shade700,
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

                      const SizedBox(height: AppTheme.spacing24),

                      // IDs section
                      _SectionHeader(
                        title: context.l10n.adminPurchasesSectionIds,
                      ),
                      _InfoTile(
                        icon: Icons.fingerprint,
                        label: context.l10n.adminPurchasesFirebaseUid,
                        value: user.userId,
                        onCopy: () => _copyToClipboard(context, user.userId),
                      ),
                      if (user.revenueCatId != null)
                        _InfoTile(
                          icon: Icons.receipt_long,
                          label: context.l10n.adminPurchasesRevenueCatId,
                          value: user.revenueCatId!,
                          onCopy: () =>
                              _copyToClipboard(context, user.revenueCatId!),
                        ),
                      if (user.createdAt != null)
                        _InfoTile(
                          icon: Icons.calendar_today,
                          label: context.l10n.adminPurchasesMemberSince,
                          value: dateFormat.format(user.createdAt!),
                        ),

                      // Country / currency / pricing section
                      if (user.countryCode != null ||
                          user.currency != null) ...[
                        const SizedBox(height: AppTheme.spacing24),
                        _SectionHeader(
                          title:
                              context.l10n.adminPurchasesSectionRegionPricing,
                        ),
                        if (user.countryCode != null)
                          _InfoTile(
                            icon: Icons.public,
                            label: context.l10n.adminPurchasesCountry,
                            value:
                                '${user.countryFlag ?? ''} ${user.countryCode!}',
                          ),
                        if (user.currency != null)
                          _InfoTile(
                            icon: Icons.currency_exchange,
                            label: context.l10n.adminPurchasesCurrency,
                            value: user.currency!,
                          ),
                        if (user.priceLocal != null && user.currency != null)
                          _InfoTile(
                            icon: Icons.local_offer,
                            label: context.l10n.adminPurchasesPriceLocal,
                            value:
                                '${user.currency!} ${user.priceLocal!.toStringAsFixed(2)}',
                          ),
                        if (user.priceUsd != null)
                          _InfoTile(
                            icon: Icons.attach_money,
                            label: context.l10n.adminPurchasesPriceUsd,
                            value: context.l10n.adminPurchasesUsdValue(
                              user.priceUsd!.toStringAsFixed(2),
                            ),
                          ),
                        if (user.taxPercentage != null)
                          _InfoTile(
                            icon: Icons.receipt,
                            label: context.l10n.adminPurchasesTax,
                            value:
                                '${(user.taxPercentage! * 100).toStringAsFixed(1)}%',
                          ),
                        if (user.commissionPercentage != null)
                          _InfoTile(
                            icon: Icons.store,
                            label: context.l10n.adminPurchasesStoreCommission,
                            value:
                                '${(user.commissionPercentage! * 100).toStringAsFixed(1)}%',
                          ),
                        if (user.offerCode != null)
                          _InfoTile(
                            icon: Icons.discount,
                            label: context.l10n.adminPurchasesOfferCode,
                            value: user.offerCode!,
                            onCopy: () =>
                                _copyToClipboard(context, user.offerCode!),
                          ),
                        if (user.isFamilyShare)
                          _InfoTile(
                            icon: Icons.family_restroom,
                            label: context.l10n.adminPurchasesFamilyShare,
                            value: context.l10n.adminPurchasesYes,
                          ),
                      ],

                      const SizedBox(height: AppTheme.spacing24),

                      // Purchases section
                      _SectionHeader(
                        title: context.l10n.adminPurchasesSectionPurchases,
                        trailing: Text(
                          context.l10n.adminPurchasesItemCount(
                            user.purchases.length,
                          ),
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),

                      if (user.purchases.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(AppTheme.spacing24),
                          decoration: BoxDecoration(
                            color: context.surface,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius12,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 48,
                                  color: context.textTertiary,
                                ),
                                const SizedBox(height: AppTheme.spacing8),
                                Text(
                                  context.l10n.adminPurchasesNoPurchases,
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
    showSuccessSnackBar(context, context.l10n.adminPurchasesCopied);
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
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.textSecondary),
          const SizedBox(width: AppTheme.spacing12),
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
              tooltip: context.l10n.adminPurchasesCopyTooltip,
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
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                child: Icon(
                  _getProductIcon(purchase.productId),
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
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
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
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
          const SizedBox(height: AppTheme.spacing8),
          Row(
            children: [
              if (purchase.purchasedAt != null) ...[
                Icon(
                  Icons.calendar_today,
                  size: 12,
                  color: context.textTertiary,
                ),
                const SizedBox(width: AppTheme.spacing4),
                Text(
                  dateFormat.format(purchase.purchasedAt!),
                  style: context.captionStyle?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
              ],
              if (_productPricesAud.containsKey(purchase.productId)) ...[
                Icon(Icons.attach_money, size: 12, color: context.textTertiary),
                const SizedBox(width: AppTheme.spacing4),
                Text(
                  'A\$${_productPricesAud[purchase.productId]!.toStringAsFixed(2)}',
                  style: context.captionStyle?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
              ],
              Icon(Icons.store, size: 12, color: context.textTertiary),
              const SizedBox(width: AppTheme.spacing4),
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
  final bool isDeleted;
  final String? countryCode;
  final String? currency;
  final double? priceUsd;
  final double? priceLocal;
  final double? taxPercentage;
  final double? commissionPercentage;
  final String? offerCode;
  final bool isFamilyShare;

  _UserWithPurchases({
    required this.userId,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.revenueCatId,
    required this.purchases,
    this.createdAt,
    this.isAnonymous = false,
    this.isDeleted = false,
    this.countryCode,
    this.currency,
    this.priceUsd,
    this.priceLocal,
    this.taxPercentage,
    this.commissionPercentage,
    this.offerCode,
    this.isFamilyShare = false,
  });

  /// Country flag emoji from ISO 3166 country code.
  String? get countryFlag {
    if (countryCode == null || countryCode!.length != 2) return null;
    return String.fromCharCodes(
      countryCode!.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 65),
    );
  }
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
