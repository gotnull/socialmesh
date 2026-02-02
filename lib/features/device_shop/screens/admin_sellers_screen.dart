// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/app_bar_overflow_menu.dart';
import '../../../providers/auth_providers.dart';
import '../../../utils/snackbar.dart';
import '../models/shop_models.dart';
import '../providers/admin_shop_providers.dart';
import '../providers/device_shop_providers.dart';

/// Admin screen for managing sellers
class AdminSellersScreen extends ConsumerStatefulWidget {
  const AdminSellersScreen({super.key});

  @override
  ConsumerState<AdminSellersScreen> createState() => _AdminSellersScreenState();
}

class _AdminSellersScreenState extends ConsumerState<AdminSellersScreen> {
  String _searchQuery = '';
  bool _showInactive = true;

  @override
  Widget build(BuildContext context) {
    final sellersAsync = ref.watch(adminAllSellersProvider);

    return GlassScaffold(
      title: 'Manage Sellers',
      actions: [
        IconButton(
          icon: Icon(
            _showInactive ? Icons.visibility : Icons.visibility_off,
            color: _showInactive ? context.accentColor : null,
          ),
          onPressed: () => setState(() => _showInactive = !_showInactive),
          tooltip: _showInactive ? 'Hide inactive' : 'Show inactive',
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => _navigateToEdit(null),
          tooltip: 'Add Seller',
        ),
      ],
      slivers: [
        // Search Bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search sellers...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ),

        // Sellers List
        sellersAsync.when(
          data: (sellers) {
            var filtered = sellers.where((s) {
              if (!_showInactive && !s.isActive) return false;
              if (_searchQuery.isNotEmpty) {
                final query = _searchQuery.toLowerCase();
                return s.name.toLowerCase().contains(query) ||
                    (s.description?.toLowerCase().contains(query) ?? false);
              }
              return true;
            }).toList();

            if (filtered.isEmpty) {
              return SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.store_outlined,
                        size: 64,
                        color: context.textTertiary,
                      ),
                      const SizedBox(height: 16),
                      const Text('No sellers found'),
                    ],
                  ),
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final seller = filtered[index];
                  return _SellerListItem(
                    seller: seller,
                    onEdit: () => _navigateToEdit(seller),
                    onToggleActive: () => _toggleActive(seller),
                  );
                }, childCount: filtered.length),
              ),
            );
          },
          loading: () => SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) =>
              SliverFillRemaining(child: Center(child: Text('Error: $e'))),
        ),
      ],
    );
  }

  void _navigateToEdit(ShopSeller? seller) {
    if (seller != null) {
      ref.read(sellerFormProvider.notifier).loadSeller(seller);
    } else {
      ref.read(sellerFormProvider.notifier).reset();
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AdminSellerEditScreen(seller: seller)),
    );
  }

  Future<void> _toggleActive(ShopSeller seller) async {
    final service = ref.read(deviceShopServiceProvider);
    final user = ref.read(currentUserProvider);

    try {
      await service.updateSeller(seller.id, {
        'isActive': !seller.isActive,
      }, adminId: user?.uid);
      ref.invalidate(adminAllSellersProvider);
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Error: $e');
      }
    }
  }
}

class _SellerListItem extends StatelessWidget {
  final ShopSeller seller;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  const _SellerListItem({
    required this.seller,
    required this.onEdit,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: seller.isActive
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.red.withValues(alpha: 0.1),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Seller Logo
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: seller.logoUrl != null
                    ? Image.network(
                        seller.logoUrl!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _placeholderLogo(),
                      )
                    : _placeholderLogo(),
              ),
              const SizedBox(width: 16),

              // Seller Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seller.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Status badges
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (!seller.isActive)
                          _buildBadge('INACTIVE', Colors.red),
                        if (seller.isOfficialPartner)
                          _buildBadge('PARTNER', Colors.green),
                        if (seller.isVerified)
                          _buildBadge('VERIFIED', Colors.blue),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (seller.description != null)
                      Text(
                        seller.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildStat(
                          context,
                          Icons.inventory_2,
                          '${seller.productCount}',
                        ),
                        const SizedBox(width: 16),
                        _buildStat(
                          context,
                          Icons.shopping_cart,
                          '${seller.salesCount}',
                        ),
                        const SizedBox(width: 16),
                        _buildStat(
                          context,
                          Icons.star,
                          seller.rating.toStringAsFixed(1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              AppBarOverflowMenu<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                      break;
                    case 'toggle':
                      onToggleActive();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          seller.isActive
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(seller.isActive ? 'Deactivate' : 'Activate'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderLogo() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.store, color: Colors.grey),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStat(BuildContext context, IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: context.textTertiary),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(fontSize: 12, color: context.textTertiary),
        ),
      ],
    );
  }
}

/// Screen for creating/editing a seller
class AdminSellerEditScreen extends ConsumerStatefulWidget {
  final ShopSeller? seller;

  const AdminSellerEditScreen({super.key, this.seller});

  @override
  ConsumerState<AdminSellerEditScreen> createState() =>
      _AdminSellerEditScreenState();
}

class _AdminSellerEditScreenState extends ConsumerState<AdminSellerEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _websiteUrlController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _countriesController = TextEditingController();

  // Discount code controllers
  final _discountCodeController = TextEditingController();
  final _discountLabelController = TextEditingController();
  final _discountTermsController = TextEditingController();

  bool _isLoading = false;
  bool _isUploadingLogo = false;
  String? _logoUrl;
  bool _isVerified = false;
  bool _isOfficialPartner = false;
  bool _isActive = true;
  DateTime? _discountCodeExpiry;

  bool get _isEditing => widget.seller != null;

  @override
  void initState() {
    super.initState();
    if (widget.seller != null) {
      _loadSeller(widget.seller!);
    }
  }

  void _loadSeller(ShopSeller seller) {
    _nameController.text = seller.name;
    _descriptionController.text = seller.description ?? '';
    _websiteUrlController.text = seller.websiteUrl ?? '';
    _contactEmailController.text = seller.contactEmail ?? '';
    _countriesController.text = seller.countries.join(', ');
    _logoUrl = seller.logoUrl;
    _isVerified = seller.isVerified;
    _isOfficialPartner = seller.isOfficialPartner;
    _isActive = seller.isActive;

    // Discount code fields
    _discountCodeController.text = seller.discountCode ?? '';
    _discountLabelController.text = seller.discountCodeLabel ?? '';
    _discountTermsController.text = seller.discountCodeTerms ?? '';
    _discountCodeExpiry = seller.discountCodeExpiry;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _websiteUrlController.dispose();
    _contactEmailController.dispose();
    _countriesController.dispose();
    _discountCodeController.dispose();
    _discountLabelController.dispose();
    _discountTermsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: _isEditing ? 'Edit Seller' : 'Add Seller',
      actions: [
        if (_isEditing)
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _confirmDelete,
            tooltip: 'Delete Seller',
          ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Form(
            key: _formKey,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo Section
                  _buildSectionTitle('Seller Logo'),
                  _buildLogoSection(),
                  const SizedBox(height: 24),

                  // Basic Info
                  _buildSectionTitle('Basic Information'),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Seller Name *',
                      hintText: 'e.g., LilyGO, RAK Wireless',
                    ),
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Brief description of the seller',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),

                  // Contact Info
                  _buildSectionTitle('Contact Information'),
                  TextFormField(
                    controller: _websiteUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Website URL *',
                      hintText: 'https://...',
                      prefixIcon: Icon(Icons.link),
                    ),
                    keyboardType: TextInputType.url,
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _contactEmailController,
                    decoration: const InputDecoration(
                      labelText: 'Contact Email',
                      hintText: 'support@example.com',
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 24),

                  // Shipping Countries
                  _buildSectionTitle('Shipping Countries'),
                  TextFormField(
                    controller: _countriesController,
                    decoration: const InputDecoration(
                      labelText: 'Countries',
                      hintText: 'US, CA, UK, DE (comma separated)',
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Discount Code Section
                  _buildSectionTitle('Partner Discount Code'),
                  _buildDiscountCodeSection(),
                  const SizedBox(height: 24),

                  // Status Toggles
                  _buildSectionTitle('Status & Verification'),
                  SwitchListTile(
                    title: const Text('Verified'),
                    subtitle: const Text('Seller identity has been verified'),
                    value: _isVerified,
                    onChanged: (v) => setState(() => _isVerified = v),
                    activeTrackColor: context.accentColor.withValues(
                      alpha: 0.5,
                    ),
                    thumbColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return context.accentColor;
                      }
                      return null;
                    }),
                  ),
                  SwitchListTile(
                    title: const Text('Official Partner'),
                    subtitle: const Text(
                      'Display as official Meshtastic partner',
                    ),
                    value: _isOfficialPartner,
                    onChanged: (v) => setState(() => _isOfficialPartner = v),
                    activeTrackColor: context.accentColor.withValues(
                      alpha: 0.5,
                    ),
                    thumbColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return context.accentColor;
                      }
                      return null;
                    }),
                  ),
                  SwitchListTile(
                    title: const Text('Active'),
                    subtitle: const Text('Seller is visible in the shop'),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                    activeTrackColor: context.accentColor.withValues(
                      alpha: 0.5,
                    ),
                    thumbColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return context.accentColor;
                      }
                      return null;
                    }),
                  ),

                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.accentColor,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(_isEditing ? 'Save Changes' : 'Create Seller'),
                    ),
                  ),

                  // Delete Section for existing sellers
                  if (_isEditing) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildSectionTitle('Danger Zone'),
                    Card(
                      color: Colors.red.withValues(alpha: 0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.warning, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Delete Seller',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Permanently delete this seller and deactivate all their products. '
                              'This action cannot be undone.',
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: _confirmDelete,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
                              child: const Text('Delete Seller Permanently'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: context.accentColor,
        ),
      ),
    );
  }

  Widget _buildDiscountCodeSection() {
    final hasDiscount = _discountCodeController.text.isNotEmpty;
    final isExpired =
        _discountCodeExpiry != null &&
        DateTime.now().isAfter(_discountCodeExpiry!);

    return Card(
      color: hasDiscount
          ? (isExpired
                ? Colors.orange.withValues(alpha: 0.1)
                : Colors.green.withValues(alpha: 0.1))
          : Colors.white.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasDiscount && isExpired)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Discount code has expired',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ],
                ),
              ),
            TextFormField(
              controller: _discountCodeController,
              decoration: const InputDecoration(
                labelText: 'Discount Code',
                hintText: 'e.g., MESH10',
                prefixIcon: Icon(Icons.local_offer),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _discountLabelController,
              decoration: const InputDecoration(
                labelText: 'Display Label',
                hintText: 'e.g., 10% off for Socialmesh users',
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectExpiryDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Expiry Date (optional)',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _discountCodeExpiry != null
                          ? '${_discountCodeExpiry!.day}/${_discountCodeExpiry!.month}/${_discountCodeExpiry!.year}'
                          : 'No expiry',
                      style: TextStyle(
                        color: _discountCodeExpiry != null
                            ? context.textPrimary
                            : context.textSecondary,
                      ),
                    ),
                    if (_discountCodeExpiry != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () =>
                            setState(() => _discountCodeExpiry = null),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _discountTermsController,
              decoration: const InputDecoration(
                labelText: 'Terms & Conditions',
                hintText: 'e.g., Cannot be combined with other offers',
              ),
              maxLines: 2,
            ),
            if (hasDiscount) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _clearDiscountCode,
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('Clear Discount Code'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _selectExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _discountCodeExpiry ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _discountCodeExpiry = picked);
    }
  }

  void _clearDiscountCode() {
    setState(() {
      _discountCodeController.clear();
      _discountLabelController.clear();
      _discountTermsController.clear();
      _discountCodeExpiry = null;
    });
  }

  Widget _buildLogoSection() {
    return Row(
      children: [
        // Logo preview
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _logoUrl != null
              ? Image.network(
                  _logoUrl!,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _placeholderLogo(),
                )
              : _placeholderLogo(),
        ),
        const SizedBox(width: 16),

        // Upload button
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              onPressed: _isUploadingLogo ? null : _pickAndUploadLogo,
              icon: _isUploadingLogo
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload),
              label: Text(_isUploadingLogo ? 'Uploading...' : 'Upload Logo'),
            ),
            if (_logoUrl != null)
              TextButton(
                onPressed: () => setState(() => _logoUrl = null),
                child: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _placeholderLogo() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.store, color: Colors.grey, size: 32),
    );
  }

  Future<void> _pickAndUploadLogo() async {
    final service = ref.read(deviceShopServiceProvider);

    setState(() => _isUploadingLogo = true);

    try {
      final image = await service.pickImage();
      if (image == null) {
        setState(() => _isUploadingLogo = false);
        return;
      }

      final sellerId =
          widget.seller?.id ?? 'new_${DateTime.now().millisecondsSinceEpoch}';
      final url = await service.uploadSellerLogo(
        sellerId: sellerId,
        imageFile: File(image.path),
      );

      setState(() {
        _logoUrl = url;
        _isUploadingLogo = false;
      });
    } catch (e) {
      setState(() => _isUploadingLogo = false);
      if (mounted) {
        showErrorSnackBar(context, 'Failed to upload logo: $e');
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final service = ref.read(deviceShopServiceProvider);
      final user = ref.read(currentUserProvider);

      final countries = _countriesController.text
          .split(',')
          .map((c) => c.trim().toUpperCase())
          .where((c) => c.isNotEmpty)
          .toList();

      final seller = ShopSeller(
        id: widget.seller?.id ?? '',
        name: _nameController.text,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        logoUrl: _logoUrl,
        websiteUrl: _websiteUrlController.text,
        contactEmail: _contactEmailController.text.isEmpty
            ? null
            : _contactEmailController.text,
        isVerified: _isVerified,
        isOfficialPartner: _isOfficialPartner,
        isActive: _isActive,
        rating: widget.seller?.rating ?? 0,
        reviewCount: widget.seller?.reviewCount ?? 0,
        productCount: widget.seller?.productCount ?? 0,
        salesCount: widget.seller?.salesCount ?? 0,
        joinedAt: widget.seller?.joinedAt ?? DateTime.now(),
        countries: countries,
        // Discount code fields
        discountCode: _discountCodeController.text.isEmpty
            ? null
            : _discountCodeController.text.toUpperCase(),
        discountCodeLabel: _discountLabelController.text.isEmpty
            ? null
            : _discountLabelController.text,
        discountCodeExpiry: _discountCodeExpiry,
        discountCodeTerms: _discountTermsController.text.isEmpty
            ? null
            : _discountTermsController.text,
      );

      if (_isEditing) {
        await service.updateFullSeller(seller, adminId: user?.uid);
      } else {
        await service.createSeller(seller, adminId: user?.uid);
      }

      ref.invalidate(adminAllSellersProvider);
      ref.invalidate(shopSellersProvider);

      if (mounted) {
        Navigator.pop(context);
        showSuccessSnackBar(
          context,
          _isEditing ? 'Seller updated' : 'Seller created',
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showErrorSnackBar(context, 'Error: $e');
      }
    }
  }

  Future<void> _confirmDelete() async {
    if (widget.seller == null) return;

    final productCount = widget.seller!.productCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Seller'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete "${widget.seller!.name}"?',
            ),
            if (productCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$productCount product(s) will be deactivated.',
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final service = ref.read(deviceShopServiceProvider);
        await service.deleteSellerPermanently(widget.seller!.id);
        ref.invalidate(adminAllSellersProvider);
        ref.invalidate(shopSellersProvider);
        if (mounted) {
          Navigator.pop(context);
          showSuccessSnackBar(context, 'Seller deleted');
        }
      } catch (e) {
        if (mounted) {
          showErrorSnackBar(context, 'Error: $e');
        }
      }
    }
  }
}
