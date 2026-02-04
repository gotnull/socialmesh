// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../utils/snackbar.dart';

/// Admin screen to view Firebase users and their RevenueCat purchases
class UserPurchasesAdminScreen extends ConsumerStatefulWidget {
  const UserPurchasesAdminScreen({super.key});

  @override
  ConsumerState<UserPurchasesAdminScreen> createState() =>
      _UserPurchasesAdminScreenState();
}

class _UserPurchasesAdminScreenState
    extends ConsumerState<UserPurchasesAdminScreen> {
  final _searchController = TextEditingController();
  bool _isLoading = false;
  List<_UserWithPurchases> _users = [];
  String? _error;

  // Stats
  int _totalUsers = 0;
  int _usersWithPurchases = 0;
  double _totalRevenue = 0;

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
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch all users with entitlements from Firestore
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      final users = <_UserWithPurchases>[];
      double totalRevenue = 0;
      int usersWithPurchases = 0;

      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        final userData = userDoc.data();

        // Get profile data
        final profileDoc = await FirebaseFirestore.instance
            .collection('profiles')
            .doc(userId)
            .get();
        final profileData = profileDoc.data();

        final purchases = <_Purchase>[];
        String? revenueCatId;

        // Check top-level user_entitlements collection (RevenueCat webhook data)
        final userEntitlementDoc = await FirebaseFirestore.instance
            .collection('user_entitlements')
            .doc(userId)
            .get();

        if (userEntitlementDoc.exists) {
          final entData = userEntitlementDoc.data()!;

          // Check for cloud_sync entitlement
          final cloudSync = entData['cloud_sync'] as String?;
          if (cloudSync != null && cloudSync.isNotEmpty) {
            purchases.add(
              _Purchase(
                productId: 'Cloud Sync',
                status: cloudSync,
                purchasedAt: (entData['created_at'] as Timestamp?)?.toDate(),
                expiresAt: (entData['expires_at'] as Timestamp?)?.toDate(),
                source: entData['source'] as String? ?? 'revenuecat',
              ),
            );
          }

          revenueCatId = entData['revenuecat_app_user_id'] as String?;
        }

        // Also check for entitlements subcollection (legacy)
        final entitlementsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('entitlements')
            .get();

        for (final entDoc in entitlementsSnapshot.docs) {
          final entData = entDoc.data();
          final productId = entData['product_id'] as String?;
          final status =
              entData['cloud_sync'] as String? ?? entData['status'] as String?;
          revenueCatId ??= entData['revenuecat_app_user_id'] as String?;

          if (productId != null) {
            purchases.add(
              _Purchase(
                productId: productId,
                status: status ?? 'unknown',
                purchasedAt:
                    (entData['created_at'] as Timestamp?)?.toDate() ??
                    (entData['purchased_at'] as Timestamp?)?.toDate(),
                expiresAt: (entData['expires_at'] as Timestamp?)?.toDate(),
                source:
                    entData['source'] as String? ??
                    entData['store'] as String? ??
                    'unknown',
              ),
            );
          }
        }

        // Also check for one-time purchases in a purchases subcollection
        final purchasesSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('purchases')
            .get();

        for (final purchaseDoc in purchasesSnapshot.docs) {
          final purchaseData = purchaseDoc.data();
          final productId = purchaseData['product_id'] as String?;

          if (productId != null) {
            final price = (purchaseData['price'] as num?)?.toDouble() ?? 0;
            totalRevenue += price;

            purchases.add(
              _Purchase(
                productId: productId,
                status: 'owned',
                purchasedAt: (purchaseData['purchased_at'] as Timestamp?)
                    ?.toDate(),
                price: price,
                currency: purchaseData['currency'] as String?,
                source: purchaseData['store'] as String? ?? 'unknown',
              ),
            );
          }
        }

        if (purchases.isNotEmpty) {
          usersWithPurchases++;
        }

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

      // Sort by purchase count (most purchases first)
      users.sort((a, b) => b.purchases.length.compareTo(a.purchases.length));

      setState(() {
        _users = users;
        _totalUsers = users.length;
        _usersWithPurchases = usersWithPurchases;
        _totalRevenue = totalRevenue;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<_UserWithPurchases> get _filteredUsers {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) return _users;

    return _users.where((user) {
      return (user.displayName?.toLowerCase().contains(query) ?? false) ||
          (user.email?.toLowerCase().contains(query) ?? false) ||
          user.userId.toLowerCase().contains(query) ||
          (user.revenueCatId?.toLowerCase().contains(query) ?? false) ||
          user.purchases.any((p) => p.productId.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'User Purchases',
      slivers: [
        // Stats cards
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
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
                    label: 'With Purchases',
                    value: _usersWithPurchases.toString(),
                    icon: Icons.shopping_bag,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Revenue',
                    value: '\$${_totalRevenue.toStringAsFixed(2)}',
                    icon: Icons.attach_money,
                    color: Colors.orange,
                  ),
                ),
              ],
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
              return _UserTile(user: user, onTap: () => _showUserDetail(user));
            }, childCount: _filteredUsers.length),
          ),
      ],
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

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
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
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: context.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final _UserWithPurchases user;
  final VoidCallback onTap;

  const _UserTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasPurchases = user.purchases.isNotEmpty;

    return Padding(
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
                      Text(
                        user.displayName ?? 'Unknown User',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
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
                              Text(
                                user.displayName ?? 'Unknown User',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: context.textPrimary,
                                ),
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
                                style: TextStyle(color: context.textSecondary),
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
                  style: TextStyle(fontSize: 11, color: context.textTertiary),
                ),
                Text(
                  value,
                  style: TextStyle(color: context.textPrimary, fontSize: 13),
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
                  style: TextStyle(fontSize: 11, color: context.textSecondary),
                ),
                const SizedBox(width: 12),
              ],
              if (purchase.price != null && purchase.price! > 0) ...[
                Icon(Icons.attach_money, size: 12, color: context.textTertiary),
                const SizedBox(width: 4),
                Text(
                  '${purchase.currency ?? '\$'}${purchase.price!.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 11, color: context.textSecondary),
                ),
                const SizedBox(width: 12),
              ],
              Icon(Icons.store, size: 12, color: context.textTertiary),
              const SizedBox(width: 4),
              Text(
                purchase.source,
                style: TextStyle(fontSize: 11, color: context.textSecondary),
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
        return Colors.green;
      case 'expired':
        return Colors.red;
      case 'grace_period':
        return Colors.orange;
      case 'grandfathered':
        return Colors.blue;
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

  _UserWithPurchases({
    required this.userId,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.revenueCatId,
    required this.purchases,
    this.createdAt,
  });
}

class _Purchase {
  final String productId;
  final String status;
  final DateTime? purchasedAt;
  final DateTime? expiresAt;
  final double? price;
  final String? currency;
  final String source;

  _Purchase({
    required this.productId,
    required this.status,
    this.purchasedAt,
    this.expiresAt,
    this.price,
    this.currency,
    required this.source,
  });
}
