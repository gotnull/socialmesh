import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/auto_scroll_text.dart';
import '../models/shop_models.dart';
import '../providers/device_shop_providers.dart';
import 'device_shop_screen.dart';

/// Seller profile screen showing seller info and their products
class SellerProfileScreen extends ConsumerStatefulWidget {
  final String sellerId;

  const SellerProfileScreen({super.key, required this.sellerId});

  @override
  ConsumerState<SellerProfileScreen> createState() =>
      _SellerProfileScreenState();
}

class _SellerProfileScreenState extends ConsumerState<SellerProfileScreen> {
  late ScrollController _scrollController;
  bool _showTitle = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Show title when scrolled past header (200px expandedHeight)
    final shouldShowTitle =
        _scrollController.hasClients && _scrollController.offset > 150;
    if (shouldShowTitle != _showTitle) {
      setState(() => _showTitle = shouldShowTitle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sellerAsync = ref.watch(singleSellerProvider(widget.sellerId));
    final productsAsync = ref.watch(sellerProductsProvider(widget.sellerId));

    return Scaffold(
      backgroundColor: context.background,
      body: sellerAsync.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: AppTheme.errorRed, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error loading seller',
                style: TextStyle(color: context.textPrimary),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Go Back'),
              ),
            ],
          ),
        ),
        data: (seller) {
          if (seller == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.store_outlined,
                    color: context.textTertiary,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Seller not found',
                    style: TextStyle(color: context.textPrimary),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              // App Bar with seller header
              _buildHeader(context, seller),

              // Search bar - pinned below app bar
              SliverPersistentHeader(
                pinned: true,
                delegate: _SearchBarDelegate(
                  searchController: _searchController,
                  searchQuery: _searchQuery,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  onClear: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  hintText: 'Search products...',
                  backgroundColor: context.background,
                  cardColor: context.card,
                  textPrimary: context.textPrimary,
                  textTertiary: context.textTertiary,
                ),
              ),

              // Seller stats
              SliverToBoxAdapter(child: _SellerStats(seller: seller)),

              // Seller description
              if (seller.description != null)
                SliverToBoxAdapter(
                  child: _SellerDescription(description: seller.description!),
                ),

              // Contact section
              SliverToBoxAdapter(child: _ContactSection(seller: seller)),

              // Products section header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Text(
                    'Products (${seller.productCount})',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Products grid
              productsAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
                error: (error, stack) => SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Unable to load products',
                        style: TextStyle(color: context.textSecondary),
                      ),
                    ),
                  ),
                ),
                data: (products) {
                  if (products.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                color: context.textTertiary,
                                size: 48,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No products listed yet',
                                style: TextStyle(color: context.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  // Filter products by search query
                  final filteredProducts = _searchQuery.isEmpty
                      ? products
                      : products.where((p) {
                          final query = _searchQuery.toLowerCase();
                          return p.name.toLowerCase().contains(query) ||
                              (p.description.toLowerCase().contains(query)) ||
                              (p.shortDescription?.toLowerCase().contains(
                                    query,
                                  ) ??
                                  false) ||
                              p.category.label.toLowerCase().contains(query);
                        }).toList();

                  if (filteredProducts.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.search_off,
                                color: context.textTertiary,
                                size: 48,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No products match "$_searchQuery"',
                                style: TextStyle(color: context.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.all(12),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.7,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        return ProductCard(product: filteredProducts[index]);
                      }, childCount: filteredProducts.length),
                    ),
                  );
                },
              ),

              // Bottom padding
              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
            ],
          );
        },
      ),
    );
  }

  SliverAppBar _buildHeader(BuildContext context, ShopSeller seller) {
    return SliverAppBar(
      backgroundColor: context.card,
      expandedHeight: 200,
      pinned: true,
      title: _showTitle
          ? AutoScrollText(
              seller.name,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              velocity: 30.0,
              fadeWidth: 20.0,
            )
          : null,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                context.accentColor.withValues(alpha: 0.3),
                context.card,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 40),
                // Logo
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.background,
                    border: Border.all(color: context.accentColor, width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: ClipOval(
                      child: seller.logoUrl != null
                          ? Image.network(
                              seller.logoUrl!,
                              width: 76,
                              height: 76,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                    Icons.store,
                                    color: context.accentColor,
                                    size: 40,
                                  ),
                            )
                          : Icon(
                              Icons.store,
                              color: context.accentColor,
                              size: 40,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Name with badges
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      seller.name,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (seller.isVerified) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.verified, color: Colors.blue, size: 20),
                    ],
                    if (seller.isOfficialPartner) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Official Partner',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SellerStats extends StatelessWidget {
  final ShopSeller seller;

  const _SellerStats({required this.seller});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            icon: Icons.star,
            iconColor: Colors.amber,
            value: seller.rating.toStringAsFixed(1),
            label: '${seller.reviewCount} reviews',
          ),
          _StatDivider(),
          _StatItem(
            icon: Icons.inventory_2,
            iconColor: context.accentColor,
            value: '${seller.productCount}',
            label: 'Products',
          ),
          _StatDivider(),
          _StatItem(
            icon: Icons.shopping_bag,
            iconColor: Colors.green,
            value: '${seller.salesCount}',
            label: 'Sales',
          ),
          _StatDivider(),
          _StatItem(
            icon: Icons.calendar_today,
            iconColor: context.textSecondary,
            value: _formatJoinDate(seller.joinedAt),
            label: 'Joined',
          ),
        ],
      ),
    );
  }

  String _formatJoinDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return "${months[date.month - 1]} '${date.year % 100}";
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 20),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: context.textTertiary, fontSize: 11),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 40, color: context.border);
  }
}

class _SellerDescription extends StatelessWidget {
  final String description;

  const _SellerDescription({required this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(color: context.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ContactSection extends StatelessWidget {
  final ShopSeller seller;

  const _ContactSection({required this.seller});

  @override
  Widget build(BuildContext context) {
    final hasWebsite = seller.websiteUrl != null;
    final hasEmail = seller.contactEmail != null;
    final hasShipping = seller.countries.isNotEmpty;

    if (!hasWebsite && !hasEmail && !hasShipping) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact & Shipping',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          if (hasWebsite)
            _ContactRow(
              icon: Icons.language,
              label: 'Website',
              value: _formatUrl(seller.websiteUrl!),
              onTap: () => _launchUrl(seller.websiteUrl!),
            ),

          if (hasEmail)
            _ContactRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: seller.contactEmail!,
              onTap: () => _launchUrl('mailto:${seller.contactEmail}'),
            ),

          if (hasShipping)
            _ContactRow(
              icon: Icons.local_shipping_outlined,
              label: 'Ships to',
              value: seller.countries.length > 3
                  ? '${seller.countries.take(3).join(", ")} +${seller.countries.length - 3} more'
                  : seller.countries.join(', '),
            ),
        ],
      ),
    );
  }

  String _formatUrl(String url) {
    return url
        .replaceAll('https://', '')
        .replaceAll('http://', '')
        .replaceAll('www.', '');
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Icon(icon, color: context.accentColor, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: context.textTertiary, fontSize: 12),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      color: onTap != null
                          ? context.accentColor
                          : context.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.open_in_new, color: context.textTertiary, size: 16),
          ],
        ),
      ),
    );
  }
}

/// Search bar persistent header delegate
class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  final TextEditingController searchController;
  final String searchQuery;
  final Function(String) onChanged;
  final VoidCallback onClear;
  final String hintText;
  final Color backgroundColor;
  final Color cardColor;
  final Color textPrimary;
  final Color textTertiary;

  _SearchBarDelegate({
    required this.searchController,
    required this.searchQuery,
    required this.onChanged,
    required this.onClear,
    required this.hintText,
    required this.backgroundColor,
    required this.cardColor,
    required this.textPrimary,
    required this.textTertiary,
  });

  @override
  double get minExtent => 72.0;

  @override
  double get maxExtent => 72.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: searchController,
          onChanged: onChanged,
          style: TextStyle(color: textPrimary),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: textTertiary),
            prefixIcon: Icon(Icons.search, color: textTertiary),
            suffixIcon: searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: textTertiary),
                    onPressed: onClear,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_SearchBarDelegate oldDelegate) {
    return searchQuery != oldDelegate.searchQuery;
  }
}
