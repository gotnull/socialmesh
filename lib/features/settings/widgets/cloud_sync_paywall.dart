// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../providers/cloud_sync_entitlement_providers.dart';
import '../../../providers/subscription_providers.dart';
import '../../../services/subscription/cloud_sync_entitlement_service.dart';
import '../../../utils/snackbar.dart';

/// Soft paywall for cloud sync feature
/// Shows subscription options when user doesn't have access
class CloudSyncPaywall extends ConsumerStatefulWidget {
  final VoidCallback? onSubscribed;
  final VoidCallback? onDismiss;

  const CloudSyncPaywall({super.key, this.onSubscribed, this.onDismiss});

  @override
  ConsumerState<CloudSyncPaywall> createState() => _CloudSyncPaywallState();
}

class _CloudSyncPaywallState extends ConsumerState<CloudSyncPaywall>
    with LifecycleSafeMixin<CloudSyncPaywall> {
  bool _isLoading = false;
  List<StoreProduct> _products = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    safeSetState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final products = await Purchases.getProducts([
        'cloud_monthly',
        'cloud_yearly',
      ], productCategory: ProductCategory.subscription);
      if (!mounted) return;
      safeSetState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      AppLogging.subscriptions('☁️ Error loading products: $e');
      safeSetState(() {
        _errorMessage = 'Unable to load subscription options';
        _isLoading = false;
      });
    }
  }

  Future<void> _purchase(StoreProduct product) async {
    safeSetState(() => _isLoading = true);

    try {
      await Purchases.purchase(PurchaseParams.storeProduct(product));
      if (!mounted) return;
      widget.onSubscribed?.call();
    } catch (e) {
      AppLogging.subscriptions('☁️ Purchase error: $e');
      if (!mounted) return;
      showErrorSnackBar(context, 'Purchase failed. Please try again.');
    } finally {
      safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _restore() async {
    safeSetState(() => _isLoading = true);

    try {
      AppLogging.subscriptions('☁️ Cloud Sync: Starting restore purchases');

      // Use the same restore flow as packs for consistency
      final success = await restorePurchases(ref);

      if (!mounted) return;

      // Refresh cloud sync entitlement after restore
      final service = ref.read(cloudSyncEntitlementServiceProvider);
      await service.refreshEntitlement();

      if (!mounted) return;

      if (service.currentEntitlement.hasFullAccess) {
        AppLogging.subscriptions(
          '☁️ Cloud Sync: Restore successful - full access granted',
        );
        // Dismiss sheet first, then show snackbar
        widget.onSubscribed?.call();
        if (!mounted) return;
        showSuccessSnackBar(context, 'Subscription restored');
      } else if (success) {
        // User has purchases but no cloud sync entitlement
        AppLogging.subscriptions(
          '☁️ Cloud Sync: Restore found purchases but no cloud sync entitlement',
        );
        // Dismiss sheet first so snackbar is visible
        widget.onDismiss?.call();
        // Small delay to allow sheet to close before showing snackbar
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
        showInfoSnackBar(context, 'No Cloud Sync subscription found');
      } else {
        AppLogging.subscriptions('☁️ Cloud Sync: Restore found no purchases');
        // Dismiss sheet first so snackbar is visible
        widget.onDismiss?.call();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
        showInfoSnackBar(context, 'No purchases found to restore');
      }
    } catch (e) {
      AppLogging.subscriptions('☁️ Cloud Sync: Restore error: $e');
      if (!mounted) return;
      showErrorSnackBar(context, 'Restore failed. Please try again.');
    } finally {
      safeSetState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cloud_sync,
              size: 48,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            'Unlock Cloud Sync',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            'Sync your mesh data across devices. Your local data always stays free and accessible.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),

          // Features — list actual premium sync types
          _buildFeatureItem(
            Icons.hexagon_outlined,
            'NodeDex — encounters, tags, notes',
          ),
          _buildFeatureItem(
            Icons.auto_awesome,
            'Automations — rules and triggers',
          ),
          _buildFeatureItem(
            Icons.widgets_outlined,
            'Custom Widgets — layouts and data',
          ),
          _buildFeatureItem(
            Icons.offline_bolt,
            'Works fully offline without it',
          ),

          const SizedBox(height: 24),

          // Loading or error state
          if (_isLoading)
            const CircularProgressIndicator()
          else if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: TextStyle(color: theme.colorScheme.error),
            )
          else ...[
            // Product buttons
            for (final product in _products) _buildProductButton(product),

            const SizedBox(height: 16),

            // Restore button
            TextButton(
              onPressed: _restore,
              child: const Text('Restore Purchases'),
            ),
          ],

          const SizedBox(height: 8),

          // Terms
          Text(
            'Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Text(text, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildProductButton(StoreProduct product) {
    final theme = Theme.of(context);
    final isYearly = product.identifier.contains('yearly');
    final foregroundColor = isYearly
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isLoading ? null : () => _purchase(product),
          style: ElevatedButton.styleFrom(
            backgroundColor: isYearly
                ? theme.colorScheme.primary
                : theme.colorScheme.surface,
            foregroundColor: foregroundColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: isYearly
                ? null
                : BorderSide(color: theme.colorScheme.primary),
          ),
          child: Column(
            children: [
              Text(
                isYearly ? 'Yearly (Save 44%)' : 'Monthly',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                product.priceString,
                style: TextStyle(
                  color: foregroundColor.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the cloud sync paywall as a bottom sheet
Future<void> showCloudSyncPaywall(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => CloudSyncPaywall(
      onSubscribed: () => Navigator.of(context).pop(),
      onDismiss: () => Navigator.of(context).pop(),
    ),
  );
}

/// Widget to gate content behind cloud sync entitlement
class CloudSyncGate extends ConsumerWidget {
  final Widget child;
  final Widget? placeholder;
  final bool allowReadOnly;

  const CloudSyncGate({
    super.key,
    required this.child,
    this.placeholder,
    this.allowReadOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.watch(cloudSyncEntitlementProvider);

    return entitlement.when(
      data: (e) {
        if (e.hasFullAccess) {
          return child;
        }
        if (allowReadOnly && e.hasReadOnlyAccess) {
          return child;
        }
        return placeholder ?? _buildLockedPlaceholder(context);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => placeholder ?? _buildLockedPlaceholder(context),
    );
  }

  Widget _buildLockedPlaceholder(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text('Cloud Sync Required', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => showCloudSyncPaywall(context),
            child: const Text('Unlock Cloud Sync'),
          ),
        ],
      ),
    );
  }
}

/// Banner to show when user has expired subscription
class CloudSyncExpiredBanner extends ConsumerWidget {
  const CloudSyncExpiredBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cloudSyncStateProvider);

    if (state != CloudSyncEntitlementState.expired) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: theme.colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your Cloud Sync subscription has expired. Your data is read-only.',
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
          TextButton(
            onPressed: () => showCloudSyncPaywall(context),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onErrorContainer,
            ),
            child: const Text('Renew'),
          ),
        ],
      ),
    );
  }
}

/// Banner to show grace period warning
class CloudSyncGracePeriodBanner extends ConsumerWidget {
  const CloudSyncGracePeriodBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cloudSyncStateProvider);

    if (state != CloudSyncEntitlementState.gracePeriod) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: theme.colorScheme.tertiaryContainer,
      child: Row(
        children: [
          Icon(Icons.payment, color: theme.colorScheme.onTertiaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'There\'s an issue with your payment. Please update your payment method.',
              style: TextStyle(color: theme.colorScheme.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
