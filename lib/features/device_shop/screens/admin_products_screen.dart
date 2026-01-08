import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../providers/auth_providers.dart';
import '../../../utils/snackbar.dart';
import '../models/shop_models.dart';
import '../providers/admin_shop_providers.dart';
import '../providers/device_shop_providers.dart';

/// Admin screen for managing products
class AdminProductsScreen extends ConsumerStatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  ConsumerState<AdminProductsScreen> createState() =>
      _AdminProductsScreenState();
}

class _AdminProductsScreenState extends ConsumerState<AdminProductsScreen> {
  String _searchQuery = '';
  DeviceCategory? _filterCategory;
  bool _showInactive = true;

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(adminAllProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Products'),
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
            icon: Icon(Icons.add),
            onPressed: () => _navigateToEdit(null),
            tooltip: 'Add Product',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search products...',
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
                const SizedBox(width: 12),
                PopupMenuButton<DeviceCategory?>(
                  icon: Icon(
                    Icons.filter_list,
                    color: _filterCategory != null ? context.accentColor : null,
                  ),
                  tooltip: 'Filter by category',
                  onSelected: (category) =>
                      setState(() => _filterCategory = category),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: null,
                      child: Text('All Categories'),
                    ),
                    ...DeviceCategory.values.map(
                      (cat) =>
                          PopupMenuItem(value: cat, child: Text(cat.label)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Products List
          Expanded(
            child: productsAsync.when(
              data: (products) {
                var filtered = products.where((p) {
                  if (!_showInactive && !p.isActive) return false;
                  if (_filterCategory != null &&
                      p.category != _filterCategory) {
                    return false;
                  }
                  if (_searchQuery.isNotEmpty) {
                    final query = _searchQuery.toLowerCase();
                    return p.name.toLowerCase().contains(query) ||
                        p.sellerName.toLowerCase().contains(query) ||
                        p.description.toLowerCase().contains(query);
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: context.textTertiary,
                        ),
                        const SizedBox(height: 16),
                        const Text('No products found'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final product = filtered[index];
                    return _ProductListItem(
                      product: product,
                      onEdit: () => _navigateToEdit(product),
                      onToggleActive: () => _toggleActive(product),
                      onDelete: () => _confirmDelete(product),
                    );
                  },
                );
              },
              loading: () => Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToEdit(null),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
        backgroundColor: context.accentColor,
      ),
    );
  }

  void _navigateToEdit(ShopProduct? product) {
    if (product != null) {
      ref.read(productFormProvider.notifier).loadProduct(product);
    } else {
      ref.read(productFormProvider.notifier).reset();
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminProductEditScreen(product: product),
      ),
    );
  }

  Future<void> _toggleActive(ShopProduct product) async {
    final service = ref.read(deviceShopServiceProvider);
    final user = ref.read(currentUserProvider);

    try {
      if (product.isActive) {
        await service.deactivateProduct(product.id, adminId: user?.uid);
      } else {
        await service.reactivateProduct(product.id, adminId: user?.uid);
      }
      ref.invalidate(adminAllProductsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _confirmDelete(ShopProduct product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text(
          'Are you sure you want to permanently delete "${product.name}"?\n\n'
          'This action cannot be undone.',
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
        await service.deleteProductPermanently(product.id);
        ref.invalidate(adminAllProductsProvider);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Product deleted')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}

class _ProductListItem extends StatelessWidget {
  final ShopProduct product;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const _ProductListItem({
    required this.product,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: product.isActive
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.red.withValues(alpha: 0.1),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Product Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: product.primaryImage != null
                    ? Image.network(
                        product.primaryImage!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _placeholderImage(),
                      )
                    : _placeholderImage(),
              ),
              SizedBox(width: 12),

              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!product.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'INACTIVE',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (product.isFeatured)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'FEATURED',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${product.category.label} • ${product.sellerName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          product.formattedPrice,
                          style: TextStyle(
                            color: context.accentColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.visibility,
                          size: 14,
                          color: context.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${product.viewCount}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.shopping_cart,
                          size: 14,
                          color: context.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${product.salesCount}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                      break;
                    case 'toggle':
                      onToggleActive();
                      break;
                    case 'delete':
                      onDelete();
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
                          product.isActive
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(product.isActive ? 'Deactivate' : 'Activate'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
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

  Widget _placeholderImage() {
    return Container(
      width: 60,
      height: 60,
      color: Colors.grey.withValues(alpha: 0.3),
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }
}

/// Screen for creating/editing a product
class AdminProductEditScreen extends ConsumerStatefulWidget {
  final ShopProduct? product;

  const AdminProductEditScreen({super.key, this.product});

  @override
  ConsumerState<AdminProductEditScreen> createState() =>
      _AdminProductEditScreenState();
}

class _AdminProductEditScreenState
    extends ConsumerState<AdminProductEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _shortDescriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _compareAtPriceController = TextEditingController();
  final _purchaseUrlController = TextEditingController();
  final _tagsController = TextEditingController();
  final _chipsetController = TextEditingController();
  final _loraChipController = TextEditingController();
  final _batteryCapacityController = TextEditingController();
  final _weightController = TextEditingController();
  final _dimensionsController = TextEditingController();
  final _stockQuantityController = TextEditingController();

  bool _isLoading = false;
  bool _isUploadingImage = false;
  List<String> _imageUrls = [];
  DeviceCategory _category = DeviceCategory.node;
  String? _sellerId;
  String? _sellerName;
  List<FrequencyBand> _frequencyBands = [];
  bool _hasGps = false;
  bool _hasWifi = false;
  bool _hasBluetooth = false;
  bool _hasDisplay = false;
  bool _isInStock = true;
  bool _isFeatured = false;
  bool _isActive = true;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _loadProduct(widget.product!);
    }
  }

  void _loadProduct(ShopProduct product) {
    _nameController.text = product.name;
    _descriptionController.text = product.description;
    _shortDescriptionController.text = product.shortDescription ?? '';
    _priceController.text = product.price.toString();
    _compareAtPriceController.text = product.compareAtPrice?.toString() ?? '';
    _purchaseUrlController.text = product.purchaseUrl ?? '';
    _tagsController.text = product.tags.join(', ');
    _chipsetController.text = product.chipset ?? '';
    _loraChipController.text = product.loraChip ?? '';
    _batteryCapacityController.text = product.batteryCapacity ?? '';
    _weightController.text = product.weight ?? '';
    _dimensionsController.text = product.dimensions ?? '';
    _stockQuantityController.text = product.stockQuantity.toString();

    _imageUrls = List.from(product.imageUrls);
    _category = product.category;
    _sellerId = product.sellerId;
    _sellerName = product.sellerName;
    _frequencyBands = List.from(product.frequencyBands);
    _hasGps = product.hasGps;
    _hasWifi = product.hasWifi;
    _hasBluetooth = product.hasBluetooth;
    _hasDisplay = product.hasDisplay;
    _isInStock = product.isInStock;
    _isFeatured = product.isFeatured;
    _isActive = product.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _shortDescriptionController.dispose();
    _priceController.dispose();
    _compareAtPriceController.dispose();
    _purchaseUrlController.dispose();
    _tagsController.dispose();
    _chipsetController.dispose();
    _loraChipController.dispose();
    _batteryCapacityController.dispose();
    _weightController.dispose();
    _dimensionsController.dispose();
    _stockQuantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sellersAsync = ref.watch(shopSellersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Product' : 'Add Product'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _confirmDelete,
              tooltip: 'Delete',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Images Section
            _buildSectionTitle('Product Images'),
            _buildImageSection(),
            const SizedBox(height: 24),

            // Basic Info
            _buildSectionTitle('Basic Information'),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Product Name *',
                hintText: 'e.g., T-Beam Supreme',
              ),
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _shortDescriptionController,
              decoration: const InputDecoration(
                labelText: 'Short Description',
                hintText: 'Brief summary (max 150 chars)',
              ),
              maxLength: 150,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Full Description *',
                hintText: 'Detailed product description',
              ),
              maxLines: 5,
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 24),

            // Category & Seller
            _buildSectionTitle('Category & Seller'),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Category *'),
              child: DropdownButton<DeviceCategory>(
                value: _category,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                items: DeviceCategory.values.map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat.label));
                }).toList(),
                onChanged: (cat) {
                  if (cat != null) setState(() => _category = cat);
                },
              ),
            ),
            const SizedBox(height: 16),

            sellersAsync.when(
              data: (sellers) => InputDecorator(
                decoration: const InputDecoration(labelText: 'Seller *'),
                child: DropdownButton<String>(
                  value: _sellerId,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  hint: const Text('Select seller'),
                  items: sellers.map((seller) {
                    return DropdownMenuItem(
                      value: seller.id,
                      child: Text(seller.name),
                    );
                  }).toList(),
                  onChanged: (id) {
                    if (id != null) {
                      final seller = sellers.firstWhere((s) => s.id == id);
                      setState(() {
                        _sellerId = id;
                        _sellerName = seller.name;
                      });
                    }
                  },
                ),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, s) => Text('Error loading sellers: $e'),
            ),
            const SizedBox(height: 24),

            // Pricing
            _buildSectionTitle('Pricing'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                      labelText: 'Price (USD) *',
                      prefixText: '\$ ',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v?.isEmpty == true) return 'Required';
                      if (double.tryParse(v!) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _compareAtPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Compare at Price',
                      prefixText: '\$ ',
                      hintText: 'Original price for sale',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // External URL
            _buildSectionTitle('Purchase Link'),
            TextFormField(
              controller: _purchaseUrlController,
              decoration: const InputDecoration(
                labelText: 'Purchase URL',
                hintText: 'https://...',
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 24),

            // Technical Specs
            _buildSectionTitle('Technical Specifications'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _chipsetController,
                    decoration: const InputDecoration(
                      labelText: 'Chipset',
                      hintText: 'e.g., ESP32-S3',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _loraChipController,
                    decoration: const InputDecoration(
                      labelText: 'LoRa Chip',
                      hintText: 'e.g., SX1262',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _batteryCapacityController,
                    decoration: const InputDecoration(
                      labelText: 'Battery Capacity',
                      hintText: 'e.g., 4000mAh',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _weightController,
                    decoration: const InputDecoration(
                      labelText: 'Weight',
                      hintText: 'e.g., 50g',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Features checkboxes
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('GPS'),
                  selected: _hasGps,
                  onSelected: (v) => setState(() => _hasGps = v),
                  selectedColor: context.accentColor.withValues(alpha: 0.3),
                  checkmarkColor: context.accentColor,
                ),
                FilterChip(
                  label: Text('WiFi'),
                  selected: _hasWifi,
                  onSelected: (v) => setState(() => _hasWifi = v),
                  selectedColor: context.accentColor.withValues(alpha: 0.3),
                  checkmarkColor: context.accentColor,
                ),
                FilterChip(
                  label: Text('Bluetooth'),
                  selected: _hasBluetooth,
                  onSelected: (v) => setState(() => _hasBluetooth = v),
                  selectedColor: context.accentColor.withValues(alpha: 0.3),
                  checkmarkColor: context.accentColor,
                ),
                FilterChip(
                  label: Text('Display'),
                  selected: _hasDisplay,
                  onSelected: (v) => setState(() => _hasDisplay = v),
                  selectedColor: context.accentColor.withValues(alpha: 0.3),
                  checkmarkColor: context.accentColor,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Frequency Bands
            _buildSectionTitle('Frequency Bands'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: FrequencyBand.values.map((band) {
                final selected = _frequencyBands.contains(band);
                return FilterChip(
                  label: Text(band.label),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _frequencyBands.add(band);
                      } else {
                        _frequencyBands.remove(band);
                      }
                    });
                  },
                  selectedColor: context.accentColor.withValues(alpha: 0.3),
                  checkmarkColor: context.accentColor,
                );
              }).toList(),
            ),
            SizedBox(height: 24),

            // Physical Specs
            _buildSectionTitle('Physical Specifications'),
            TextFormField(
              controller: _dimensionsController,
              decoration: const InputDecoration(
                labelText: 'Dimensions',
                hintText: 'e.g., 100x50x25mm',
              ),
            ),
            const SizedBox(height: 24),

            // Tags
            _buildSectionTitle('Tags'),
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags',
                hintText: 'meshtastic, lora, gps (comma separated)',
              ),
            ),
            const SizedBox(height: 24),

            // Stock & Status
            _buildSectionTitle('Stock & Status'),
            TextFormField(
              controller: _stockQuantityController,
              decoration: const InputDecoration(
                labelText: 'Stock Quantity',
                hintText: 'Leave empty for unlimited',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text('In Stock'),
              value: _isInStock,
              onChanged: (v) => setState(() => _isInStock = v),
              activeTrackColor: context.accentColor.withValues(alpha: 0.5),
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return context.accentColor;
                }
                return null;
              }),
            ),
            SwitchListTile(
              title: Text('Featured'),
              subtitle: const Text('Show in featured products section'),
              value: _isFeatured,
              onChanged: (v) => setState(() => _isFeatured = v),
              activeTrackColor: context.accentColor.withValues(alpha: 0.5),
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return context.accentColor;
                }
                return null;
              }),
            ),
            SwitchListTile(
              title: Text('Active'),
              subtitle: const Text('Product is visible in the shop'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              activeTrackColor: context.accentColor.withValues(alpha: 0.5),
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return context.accentColor;
                }
                return null;
              }),
            ),

            SizedBox(height: 32),

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
                    : Text(_isEditing ? 'Save Changes' : 'Create Product'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
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

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image grid
        if (_imageUrls.isNotEmpty)
          SizedBox(
            height: 100,
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _imageUrls.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _imageUrls.removeAt(oldIndex);
                  _imageUrls.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                return Padding(
                  key: ValueKey(_imageUrls[index]),
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _imageUrls[index],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: 100,
                                height: 100,
                                color: Colors.grey,
                                child: const Icon(Icons.broken_image),
                              ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _imageUrls.removeAt(index));
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      if (index == 0)
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.accentColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Main',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 12),

        // Add image button
        OutlinedButton.icon(
          onPressed: _isUploadingImage ? null : _pickAndUploadImage,
          icon: _isUploadingImage
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_photo_alternate),
          label: Text(_isUploadingImage ? 'Uploading...' : 'Add Image'),
        ),
        if (_imageUrls.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'At least one image is required',
              style: TextStyle(
                color: Colors.red.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickAndUploadImage() async {
    final service = ref.read(deviceShopServiceProvider);

    setState(() => _isUploadingImage = true);

    try {
      final image = await service.pickImage();
      if (image == null) {
        setState(() => _isUploadingImage = false);
        return;
      }

      final productId =
          widget.product?.id ?? 'new_${DateTime.now().millisecondsSinceEpoch}';
      final url = await service.uploadProductImage(
        productId: productId,
        imageFile: File(image.path),
      );

      setState(() {
        _imageUrls.add(url);
        _isUploadingImage = false;
      });
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) {
        showErrorSnackBar(context, 'Failed to upload image: $e');
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageUrls.isEmpty) {
      showWarningSnackBar(context, 'Please add at least one image');
      return;
    }
    if (_sellerId == null) {
      showWarningSnackBar(context, 'Please select a seller');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final service = ref.read(deviceShopServiceProvider);
      final user = ref.read(currentUserProvider);

      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final product = ShopProduct(
        id: widget.product?.id ?? '',
        name: _nameController.text,
        description: _descriptionController.text,
        shortDescription: _shortDescriptionController.text.isEmpty
            ? null
            : _shortDescriptionController.text,
        category: _category,
        price: double.parse(_priceController.text),
        compareAtPrice: _compareAtPriceController.text.isEmpty
            ? null
            : double.parse(_compareAtPriceController.text),
        currency: 'USD',
        sellerId: _sellerId!,
        sellerName: _sellerName!,
        imageUrls: _imageUrls,
        frequencyBands: _frequencyBands,
        chipset: _chipsetController.text.isEmpty
            ? null
            : _chipsetController.text,
        loraChip: _loraChipController.text.isEmpty
            ? null
            : _loraChipController.text,
        hasGps: _hasGps,
        hasWifi: _hasWifi,
        hasBluetooth: _hasBluetooth,
        hasDisplay: _hasDisplay,
        batteryCapacity: _batteryCapacityController.text.isEmpty
            ? null
            : _batteryCapacityController.text,
        weight: _weightController.text.isEmpty ? null : _weightController.text,
        dimensions: _dimensionsController.text.isEmpty
            ? null
            : _dimensionsController.text,
        stockQuantity: _stockQuantityController.text.isEmpty
            ? 0
            : int.parse(_stockQuantityController.text),
        purchaseUrl: _purchaseUrlController.text.isEmpty
            ? null
            : _purchaseUrlController.text,
        tags: tags,
        isFeatured: _isFeatured,
        isInStock: _isInStock,
        isActive: _isActive,
        viewCount: widget.product?.viewCount ?? 0,
        salesCount: widget.product?.salesCount ?? 0,
        favoriteCount: widget.product?.favoriteCount ?? 0,
        rating: widget.product?.rating ?? 0,
        reviewCount: widget.product?.reviewCount ?? 0,
        createdAt: widget.product?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (_isEditing) {
        await service.updateFullProduct(product, adminId: user?.uid);
      } else {
        await service.createProduct(product, adminId: user?.uid);
      }

      ref.invalidate(adminAllProductsProvider);

      if (mounted) {
        Navigator.pop(context);
        showSuccessSnackBar(
          context,
          _isEditing ? 'Product updated' : 'Product created',
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
    if (widget.product == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text(
          'Are you sure you want to permanently delete this product?',
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
        await service.deleteProductPermanently(widget.product!.id);
        ref.invalidate(adminAllProductsProvider);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Product deleted')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}
