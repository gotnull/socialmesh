import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../core/widgets/legal_document_sheet.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/subscription_models.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_providers.dart';
import '../../providers/cloud_sync_entitlement_providers.dart';
import '../../providers/profile_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../services/subscription/cloud_sync_entitlement_service.dart';
import '../../utils/snackbar.dart';
import '../profile/profile_screen.dart';
import 'subscription_screen.dart';

/// Unified Account & Subscriptions screen
/// Combines: Profile preview, Account management, Cloud Sync, and Premium features
/// Following best practices from Spotify, Discord, etc.
class AccountSubscriptionsScreen extends ConsumerStatefulWidget {
  const AccountSubscriptionsScreen({super.key});

  @override
  ConsumerState<AccountSubscriptionsScreen> createState() =>
      _AccountSubscriptionsScreenState();
}

class _AccountSubscriptionsScreenState
    extends ConsumerState<AccountSubscriptionsScreen> {
  bool _isSigningIn = false;
  bool _isPurchasing = false;

  @override
  Widget build(BuildContext context) {
    final accentColor = context.accentColor;
    final authState = ref.watch(authStateProvider);
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        centerTitle: true,
        title: Text(
          'Account',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ═══════════════════════════════════════════════════════════════
          // PROFILE CARD - Quick access to edit profile
          // ═══════════════════════════════════════════════════════════════
          _buildProfileCard(profileAsync, accentColor),

          const SizedBox(height: 24),

          // ═══════════════════════════════════════════════════════════════
          // ACCOUNT SECTION - Sign in/out, linked accounts
          // ═══════════════════════════════════════════════════════════════
          _buildSectionHeader('ACCOUNT'),
          const SizedBox(height: 8),
          authState.when(
            data: (user) => user != null
                ? _buildSignedInAccountCard(user)
                : _buildSignedOutAccountCard(),
            loading: () => const _LoadingCard(),
            error: (e, _) => _buildSignedOutAccountCard(),
          ),

          const SizedBox(height: 24),

          // ═══════════════════════════════════════════════════════════════
          // SUBSCRIPTIONS SECTION - Cloud Sync + Premium
          // ═══════════════════════════════════════════════════════════════
          _buildSectionHeader('SUBSCRIPTIONS'),
          const SizedBox(height: 8),

          // Cloud Sync subscription card
          _buildCloudSyncCard(),

          const SizedBox(height: 12),

          // Premium features card
          _buildPremiumFeaturesCard(),

          const SizedBox(height: 24),

          // ═══════════════════════════════════════════════════════════════
          // MANAGE SECTION - Restore, Terms, Privacy
          // ═══════════════════════════════════════════════════════════════
          _buildSectionHeader('MANAGE'),
          const SizedBox(height: 8),
          _buildManageCard(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PROFILE CARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildProfileCard(
    AsyncValue<UserProfile?> profileAsync,
    Color accentColor,
  ) {
    AppLogging.subscriptions('');
    AppLogging.subscriptions(
      '╔══════════════════════════════════════════════════════════════',
    );
    AppLogging.subscriptions('║ 🏗️ _buildProfileCard() called');
    AppLogging.subscriptions('║ 📦 profileAsync state:');
    AppLogging.subscriptions('║    - isLoading: ${profileAsync.isLoading}');
    AppLogging.subscriptions('║    - hasValue: ${profileAsync.hasValue}');
    AppLogging.subscriptions('║    - hasError: ${profileAsync.hasError}');
    if (profileAsync.hasValue && !profileAsync.hasError) {
      AppLogging.subscriptions(
        '║    - value: ${profileAsync.value?.displayName ?? "NULL"}',
      );
    }
    AppLogging.subscriptions(
      '╚══════════════════════════════════════════════════════════════',
    );

    return profileAsync.when(
      data: (profile) {
        AppLogging.subscriptions(
          '║ 📤 profileAsync.when -> data: ${profile?.displayName ?? "NULL"}',
        );
        return _ProfilePreviewCard(
          profile: profile,
          onEditTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ),
        );
      },
      loading: () {
        AppLogging.subscriptions('║ ⏳ profileAsync.when -> loading');
        return const _LoadingCard();
      },
      error: (e, _) {
        AppLogging.subscriptions('║ ❌ profileAsync.when -> error: $e');
        return _ProfilePreviewCard(
          profile: null,
          onEditTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCOUNT CARDS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSignedInAccountCard(User user) {
    final syncStatus = ref.watch(syncStatusProvider);
    final isAnonymous = user.isAnonymous;

    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AccentColors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Status header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AccentColors.green.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AccentColors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    syncStatus == SyncStatus.syncing
                        ? Icons.cloud_sync
                        : Icons.cloud_done,
                    color: AccentColors.green,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAnonymous ? 'Guest Account' : 'Signed In',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                      if (user.email != null)
                        Text(
                          user.email!,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                _SyncStatusBadge(status: syncStatus),
              ],
            ),
          ),

          // Linked providers (if any)
          if (user.providerData.isNotEmpty && !isAnonymous) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Text(
                    'Linked accounts',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                  ),
                  SizedBox(width: 12),
                  ...user.providerData.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _ProviderIcon(providerId: p.providerId),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (isAnonymous) ...[
                  // Upgrade prompt for guest accounts
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: context.accentColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: context.accentColor,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Link an email to keep your data across devices',
                            style: TextStyle(
                              fontSize: 13,
                              color: context.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _showLinkAccountSheet(context),
                      icon: const Icon(Icons.link, size: 18),
                      label: const Text('Link Account'),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _signOut(context),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sign Out'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignedOutAccountCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.account_circle_outlined,
            size: 48,
            color: context.textSecondary,
          ),
          SizedBox(height: 12),
          Text(
            'Sign in to sync across devices',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your local data is always available',
            style: TextStyle(fontSize: 13, color: context.textSecondary),
          ),
          const SizedBox(height: 20),

          // Sign in buttons
          if (_isSigningIn)
            Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )
          else ...[
            // Google
            _SocialSignInButton(
              onPressed: () => _signInWithGoogle(context),
              icon: _GoogleLogo(),
              label: 'Continue with Google',
              backgroundColor: Colors.white,
              textColor: Colors.black87,
            ),
            const SizedBox(height: 10),

            // Apple (iOS/macOS only)
            if (Platform.isIOS || Platform.isMacOS) ...[
              _SocialSignInButton(
                onPressed: () => _signInWithApple(context),
                icon: const Icon(Icons.apple, color: Colors.white, size: 22),
                label: 'Continue with Apple',
                backgroundColor: Colors.black,
                textColor: Colors.white,
              ),
              const SizedBox(height: 10),
            ],

            // GitHub
            _SocialSignInButton(
              onPressed: () => _signInWithGitHub(context),
              icon: _GitHubLogo(),
              label: 'Continue with GitHub',
              backgroundColor: const Color(0xFF24292F),
              textColor: Colors.white,
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CLOUD SYNC CARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCloudSyncCard() {
    final entitlementAsync = ref.watch(cloudSyncEntitlementProvider);
    final accentColor = context.accentColor;

    return entitlementAsync.when(
      data: (entitlement) {
        final hasAccess = entitlement.hasFullAccess;
        final isGracePeriod =
            entitlement.state == CloudSyncEntitlementState.gracePeriod;
        final isExpired =
            entitlement.state == CloudSyncEntitlementState.expired;

        return Container(
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasAccess
                  ? AccentColors.green.withValues(alpha: 0.3)
                  : isExpired
                  ? AppTheme.errorRed.withValues(alpha: 0.3)
                  : context.border,
            ),
          ),
          child: Column(
            children: [
              // Header
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (hasAccess ? AccentColors.green : accentColor)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    hasAccess ? Icons.cloud_done : Icons.cloud_outlined,
                    color: hasAccess ? AccentColors.green : accentColor,
                    size: 24,
                  ),
                ),
                title: Text(
                  'Cloud Sync',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                subtitle: Text(
                  hasAccess
                      ? (isGracePeriod
                            ? 'Payment issue - please update'
                            : 'Active subscription')
                      : (isExpired ? 'Subscription expired' : 'Not subscribed'),
                  style: TextStyle(
                    fontSize: 12,
                    color: hasAccess
                        ? (isGracePeriod
                              ? Colors.orange
                              : context.textSecondary)
                        : (isExpired
                              ? AppTheme.errorRed
                              : context.textSecondary),
                  ),
                ),
                trailing: hasAccess
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AccentColors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'ACTIVE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AccentColors.green,
                          ),
                        ),
                      )
                    : null,
              ),

              // Features list (collapsed when active)
              if (!hasAccess) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Column(
                    children: [
                      _FeatureRow(
                        icon: Icons.devices,
                        text: 'Sync across all devices',
                      ),
                      _FeatureRow(
                        icon: Icons.backup,
                        text: 'Automatic cloud backup',
                      ),
                      _FeatureRow(icon: Icons.share, text: 'Share profiles'),
                    ],
                  ),
                ),
              ],

              // Subscribe/Manage button
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: hasAccess
                      ? OutlinedButton(
                          onPressed: _manageSubscription,
                          child: const Text('Manage Subscription'),
                        )
                      : FilledButton.icon(
                          onPressed: _isPurchasing
                              ? null
                              : _showCloudSyncPaywall,
                          icon: _isPurchasing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.cloud_sync, size: 18),
                          label: Text(isExpired ? 'Renew' : 'Subscribe'),
                        ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const _LoadingCard(),
      error: (e, _) => _buildErrorCard('Could not load subscription status'),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PREMIUM FEATURES CARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPremiumFeaturesCard() {
    final purchaseState = ref.watch(purchaseStateProvider);
    final storeProductsAsync = ref.watch(storeProductsProvider);
    final storeProducts = storeProductsAsync.when(
      data: (data) => data,
      loading: () => <String, StoreProductInfo>{},
      error: (e, s) => <String, StoreProductInfo>{},
    );
    final accentColor = context.accentColor;

    // Count owned features
    final ownedCount = OneTimePurchases.allPurchases
        .where((p) => purchaseState.hasPurchased(p.productId))
        .length;
    final totalCount = OneTimePurchases.allPurchases.length;
    final allUnlocked = ownedCount == totalCount;

    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: allUnlocked
              ? accentColor.withValues(alpha: 0.3)
              : context.border,
        ),
      ),
      child: Column(
        children: [
          // Header
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                allUnlocked ? Icons.verified : Icons.rocket_launch_rounded,
                color: accentColor,
                size: 24,
              ),
            ),
            title: Text(
              'Premium Features',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            subtitle: Text(
              allUnlocked
                  ? 'All features unlocked!'
                  : '$ownedCount of $totalCount unlocked',
              style: TextStyle(fontSize: 12, color: context.textSecondary),
            ),
            trailing: allUnlocked
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'COMPLETE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                  )
                : null,
          ),

          // Features preview (collapsed when all unlocked)
          if (!allUnlocked) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                children: OneTimePurchases.allPurchases.map((purchase) {
                  return _FeatureRow(
                    icon: _getIconForFeature(purchase.unlocksFeature),
                    text:
                        storeProducts[purchase.productId]?.title ??
                        purchase.name,
                    isUnlocked: purchaseState.hasFeature(
                      purchase.unlocksFeature,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // View all button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: allUnlocked
                  ? OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SubscriptionScreen(),
                        ),
                      ),
                      child: const Text('View Features'),
                    )
                  : FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SubscriptionScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                      label: const Text('View & Purchase'),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MANAGE CARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildManageCard() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _ManageListTile(
            icon: Icons.restore,
            title: 'Restore Purchases',
            subtitle: 'Restore previously purchased items',
            onTap: _restorePurchases,
            isFirst: true,
          ),
          Divider(height: 1, color: context.border),
          _ManageListTile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            onTap: () => LegalDocumentSheet.showTerms(context),
          ),
          Divider(height: 1, color: context.border),
          _ManageListTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () => LegalDocumentSheet.showPrivacy(context),
            isLast: true,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  IconData _getIconForFeature(PremiumFeature feature) {
    return switch (feature) {
      PremiumFeature.customRingtones => Icons.music_note,
      PremiumFeature.premiumThemes => Icons.palette,
      PremiumFeature.automations => Icons.auto_awesome,
      PremiumFeature.homeWidgets => Icons.widgets,
      PremiumFeature.iftttIntegration => Icons.webhook,
    };
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: context.textTertiary,
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppTheme.errorRed),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: TextStyle(color: AppTheme.errorRed)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _signInWithGoogle(BuildContext _) async {
    if (_isSigningIn) return;
    setState(() => _isSigningIn = true);
    AppLogging.subscriptions('');
    AppLogging.subscriptions(
      '╔══════════════════════════════════════════════════════════════',
    );
    AppLogging.subscriptions('║ 🔐 SIGN IN WITH GOOGLE STARTED');
    AppLogging.subscriptions(
      '╚══════════════════════════════════════════════════════════════',
    );

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithGoogle();
      AppLogging.subscriptions(
        '╔══════════════════════════════════════════════════════════════',
      );
      AppLogging.subscriptions('║ ✅ Google sign-in SUCCESS');
      AppLogging.subscriptions('║ 🔄 Invalidating userProfileProvider...');
      AppLogging.subscriptions(
        '╚══════════════════════════════════════════════════════════════',
      );
      // Force profile to reload with new auth state
      ref.invalidate(userProfileProvider);
    } catch (e) {
      AppLogging.subscriptions(
        '╔══════════════════════════════════════════════════════════════',
      );
      AppLogging.subscriptions('║ ❌ Google sign-in FAILED: $e');
      AppLogging.subscriptions(
        '╚══════════════════════════════════════════════════════════════',
      );
      AppLogging.app('Google sign-in error: $e');
      if (mounted) {
        showErrorSnackBar(context, 'Sign in failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Future<void> _signInWithApple(BuildContext _) async {
    if (_isSigningIn) return;
    setState(() => _isSigningIn = true);
    AppLogging.subscriptions('');
    AppLogging.subscriptions(
      '╔══════════════════════════════════════════════════════════════',
    );
    AppLogging.subscriptions('║ 🔐 SIGN IN WITH APPLE STARTED');
    AppLogging.subscriptions(
      '╚══════════════════════════════════════════════════════════════',
    );

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithApple();
      AppLogging.subscriptions(
        '╔══════════════════════════════════════════════════════════════',
      );
      AppLogging.subscriptions('║ ✅ Apple sign-in SUCCESS');
      AppLogging.subscriptions('║ 🔄 Invalidating userProfileProvider...');
      AppLogging.subscriptions(
        '╚══════════════════════════════════════════════════════════════',
      );
      // Force profile to reload with new auth state
      ref.invalidate(userProfileProvider);
    } catch (e) {
      AppLogging.subscriptions(
        '╔══════════════════════════════════════════════════════════════',
      );
      AppLogging.subscriptions('║ ❌ Apple sign-in FAILED: $e');
      AppLogging.subscriptions(
        '╚══════════════════════════════════════════════════════════════',
      );
      AppLogging.app('Apple sign-in error: $e');
      if (mounted) {
        showErrorSnackBar(context, 'Sign in failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Future<void> _signInWithGitHub(BuildContext _) async {
    if (_isSigningIn) return;
    setState(() => _isSigningIn = true);
    AppLogging.subscriptions('');
    AppLogging.subscriptions(
      '╔══════════════════════════════════════════════════════════════',
    );
    AppLogging.subscriptions('║ 🔐 SIGN IN WITH GITHUB STARTED');
    AppLogging.subscriptions(
      '╚══════════════════════════════════════════════════════════════',
    );

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithGitHub();
      AppLogging.subscriptions(
        '╔══════════════════════════════════════════════════════════════',
      );
      AppLogging.subscriptions('║ ✅ GitHub sign-in SUCCESS');
      AppLogging.subscriptions('║ 🔄 Invalidating userProfileProvider...');
      AppLogging.subscriptions(
        '╚══════════════════════════════════════════════════════════════',
      );
      // Force profile to reload with new auth state
      ref.invalidate(userProfileProvider);
    } catch (e) {
      AppLogging.subscriptions(
        '╔══════════════════════════════════════════════════════════════',
      );
      AppLogging.subscriptions('║ ❌ GitHub sign-in FAILED: $e');
      AppLogging.subscriptions(
        '╚══════════════════════════════════════════════════════════════',
      );
      AppLogging.app('GitHub sign-in error: $e');
      if (mounted) {
        showErrorSnackBar(context, 'Sign in failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Future<void> _signOut(BuildContext _) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        AppLogging.subscriptions('');
        AppLogging.subscriptions(
          '╔══════════════════════════════════════════════════════════════',
        );
        AppLogging.subscriptions('║ 🚪 SIGN OUT INITIATED');
        AppLogging.subscriptions(
          '╚══════════════════════════════════════════════════════════════',
        );
        final authService = ref.read(authServiceProvider);
        await authService.signOut();
        AppLogging.subscriptions(
          '╔══════════════════════════════════════════════════════════════',
        );
        AppLogging.subscriptions('║ ✅ Auth signOut() completed');
        AppLogging.subscriptions('║ 🔄 Invalidating userProfileProvider...');
        AppLogging.subscriptions(
          '╚══════════════════════════════════════════════════════════════',
        );
        // Force the provider to rebuild with new auth state
        ref.invalidate(userProfileProvider);
        if (mounted) {
          showSuccessSnackBar(context, 'Signed out');
        }
      } catch (e) {
        AppLogging.subscriptions(
          '╔══════════════════════════════════════════════════════════════',
        );
        AppLogging.subscriptions('║ ❌ Sign out ERROR: $e');
        AppLogging.subscriptions(
          '╚══════════════════════════════════════════════════════════════',
        );
        if (mounted) {
          showErrorSnackBar(context, 'Error: $e');
        }
      }
    }
  }

  void _showLinkAccountSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Link Account',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Link a sign-in method to keep your data',
              style: TextStyle(color: context.textSecondary),
            ),
            const SizedBox(height: 24),
            _SocialSignInButton(
              onPressed: () {
                Navigator.pop(context);
                _signInWithGoogle(context);
              },
              icon: _GoogleLogo(),
              label: 'Link with Google',
              backgroundColor: Colors.white,
              textColor: Colors.black87,
            ),
            if (Platform.isIOS || Platform.isMacOS) ...[
              const SizedBox(height: 10),
              _SocialSignInButton(
                onPressed: () {
                  Navigator.pop(context);
                  _signInWithApple(context);
                },
                icon: const Icon(Icons.apple, color: Colors.white, size: 22),
                label: 'Link with Apple',
                backgroundColor: Colors.black,
                textColor: Colors.white,
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showCloudSyncPaywall() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CloudSyncPaywallSheet(
        onPurchaseStart: () {
          if (mounted) setState(() => _isPurchasing = true);
        },
        onPurchaseEnd: () {
          if (mounted) setState(() => _isPurchasing = false);
        },
      ),
    );
  }

  Future<void> _manageSubscription() async {
    // Open app store subscription management
    // Note: There's no direct API to open subscription management in RevenueCat
    // Users need to manage through their respective app stores
    if (mounted) {
      showInfoSnackBar(
        context,
        Platform.isIOS
            ? 'Go to Settings > Apple ID > Subscriptions to manage'
            : 'Go to Play Store > Payments & Subscriptions to manage',
        duration: const Duration(seconds: 4),
      );
    }
  }

  Future<void> _restorePurchases() async {
    AppLogging.subscriptions(
      '═══════════════════════════════════════════════════════════',
    );
    AppLogging.subscriptions('🔄 [RESTORE] Starting restore purchases flow...');
    AppLogging.subscriptions(
      '═══════════════════════════════════════════════════════════',
    );

    try {
      // Use the same provider function as SubscriptionScreen
      // This handles: Firebase UID sync, RevenueCat restore, Riverpod state refresh
      AppLogging.subscriptions(
        '🔄 [RESTORE] Calling restorePurchases(ref) provider...',
      );
      final success = await restorePurchases(ref);
      AppLogging.subscriptions('🔄 [RESTORE] Provider returned: $success');

      // Also refresh cloud sync entitlement service for cloud sync status
      AppLogging.subscriptions(
        '🔄 [RESTORE] Refreshing CloudSyncEntitlementService...',
      );
      final cloudService = ref.read(cloudSyncEntitlementServiceProvider);
      await cloudService.refreshEntitlement();
      AppLogging.subscriptions(
        '✅ [RESTORE] CloudSyncEntitlementService refreshed',
      );

      // Invalidate the stream provider to force UI rebuild with latest state
      // This ensures the UI picks up the refreshed entitlement immediately
      ref.invalidate(cloudSyncEntitlementProvider);
      AppLogging.subscriptions(
        '✅ [RESTORE] Invalidated cloudSyncEntitlementProvider',
      );

      // Log final state
      final purchaseState = ref.read(purchaseStateProvider);
      AppLogging.subscriptions(
        '📊 [RESTORE] Final purchasedProductIds: ${purchaseState.purchasedProductIds}',
      );

      final cloudEntitlement = cloudService.currentEntitlement;
      AppLogging.subscriptions(
        '📊 [RESTORE] Final cloud sync state: ${cloudEntitlement.state}',
      );
      AppLogging.subscriptions(
        '📊 [RESTORE] Final cloud sync hasFullAccess: ${cloudEntitlement.hasFullAccess}',
      );

      AppLogging.subscriptions(
        '═══════════════════════════════════════════════════════════',
      );
      AppLogging.subscriptions('✅ [RESTORE] Restore purchases flow completed!');
      AppLogging.subscriptions(
        '═══════════════════════════════════════════════════════════',
      );

      if (mounted) {
        if (success) {
          showSuccessSnackBar(context, 'Purchases restored successfully');
        } else {
          showInfoSnackBar(context, 'No active purchases found to restore');
        }
      }
    } catch (e, stack) {
      AppLogging.subscriptions('');
      AppLogging.subscriptions(
        '═══════════════════════════════════════════════════════════',
      );
      AppLogging.subscriptions('❌ [RESTORE] ERROR during restore purchases!');
      AppLogging.subscriptions('❌ [RESTORE] Error: $e');
      AppLogging.subscriptions('❌ [RESTORE] Stack: $stack');
      AppLogging.subscriptions(
        '═══════════════════════════════════════════════════════════',
      );

      if (mounted) {
        showErrorSnackBar(context, 'Could not restore purchases: $e');
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _ProfilePreviewCard extends StatelessWidget {
  final UserProfile? profile;
  final VoidCallback onEditTap;

  const _ProfilePreviewCard({required this.profile, required this.onEditTap});

  @override
  Widget build(BuildContext context) {
    AppLogging.subscriptions('');
    AppLogging.subscriptions(
      '╔══════════════════════════════════════════════════════════════',
    );
    AppLogging.subscriptions('║ 🎨 _ProfilePreviewCard.build()');
    AppLogging.subscriptions('║ 📋 Profile received:');
    AppLogging.subscriptions('║    - profile is null: ${profile == null}');
    AppLogging.subscriptions(
      '║    - displayName: ${profile?.displayName ?? "NULL"}',
    );
    AppLogging.subscriptions('║    - callsign: ${profile?.callsign ?? "NULL"}');
    AppLogging.subscriptions('║    - id: ${profile?.id ?? "NULL"}');
    AppLogging.subscriptions('║    - isSynced: ${profile?.isSynced ?? "NULL"}');
    AppLogging.subscriptions(
      '╚══════════════════════════════════════════════════════════════',
    );

    final accentColor = context.accentColor;
    final displayName = profile?.displayName ?? 'MeshUser';
    final avatarUrl = profile?.avatarUrl;
    final initials = profile?.initials ?? '?';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.15),
            accentColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onEditTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                UserAvatar(
                  imageUrl: avatarUrl,
                  initials: initials,
                  size: 56,
                  borderWidth: 2,
                  borderColor: accentColor.withValues(alpha: 0.5),
                  foregroundColor: accentColor,
                  backgroundColor: accentColor.withValues(alpha: 0.2),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                      if (profile?.callsign != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          profile!.callsign!,
                          style: TextStyle(
                            fontSize: 13,
                            color: accentColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ] else
                        Text(
                          'Tap to edit profile',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: accentColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _SyncStatusBadge extends StatelessWidget {
  final SyncStatus status;

  const _SyncStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, text) = switch (status) {
      SyncStatus.syncing => (Colors.blue, 'Syncing'),
      SyncStatus.synced => (AccentColors.green, 'Synced'),
      SyncStatus.error => (AppTheme.errorRed, 'Error'),
      SyncStatus.idle => (context.textTertiary, 'Idle'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isUnlocked;

  const _FeatureRow({
    required this.icon,
    required this.text,
    this.isUnlocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isUnlocked ? AccentColors.green : context.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: color)),
          ),
          if (isUnlocked)
            Icon(Icons.check_circle, size: 16, color: AccentColors.green),
        ],
      ),
    );
  }
}

class _ProviderIcon extends StatelessWidget {
  final String providerId;

  const _ProviderIcon({required this.providerId});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: context.background,
        shape: BoxShape.circle,
        border: Border.all(color: context.border),
      ),
      child: Center(child: _getIcon(context)),
    );
  }

  Widget _getIcon(BuildContext context) {
    return switch (providerId) {
      'google.com' => SizedBox(
        width: 14,
        height: 14,
        child: CustomPaint(painter: _GoogleLogoSmallPainter()),
      ),
      'apple.com' => Icon(Icons.apple, size: 16, color: Colors.white),
      'github.com' => SizedBox(
        width: 14,
        height: 14,
        child: CustomPaint(painter: _GitHubLogoSmallPainter()),
      ),
      'password' => const Icon(Icons.email, size: 14, color: Colors.blue),
      _ => Icon(Icons.link, size: 14, color: context.textSecondary),
    };
  }
}

/// Custom painter for Google's 4-color "G" logo (small version)
class _GoogleLogoSmallPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.scale(scale, scale);

    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final bluePath = Path()
      ..moveTo(22.56, 12.25)
      ..cubicTo(22.56, 11.47, 22.49, 10.72, 22.36, 10)
      ..lineTo(12, 10)
      ..lineTo(12, 14.26)
      ..lineTo(17.92, 14.26)
      ..cubicTo(17.66, 15.63, 16.88, 16.79, 15.71, 17.57)
      ..lineTo(15.71, 20.34)
      ..lineTo(19.28, 20.34)
      ..cubicTo(21.36, 18.42, 22.56, 15.6, 22.56, 12.25)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;
    final greenPath = Path()
      ..moveTo(12, 23)
      ..cubicTo(14.97, 23, 17.46, 22.02, 19.28, 20.34)
      ..lineTo(15.71, 17.57)
      ..cubicTo(14.73, 18.23, 13.48, 18.63, 12, 18.63)
      ..cubicTo(9.14, 18.63, 6.71, 16.7, 5.84, 14.1)
      ..lineTo(2.18, 14.1)
      ..lineTo(2.18, 16.94)
      ..cubicTo(3.99, 20.53, 7.7, 23, 12, 23)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;
    final yellowPath = Path()
      ..moveTo(5.84, 14.09)
      ..cubicTo(5.62, 13.43, 5.49, 12.73, 5.49, 12)
      ..cubicTo(5.49, 11.27, 5.62, 10.57, 5.84, 9.91)
      ..lineTo(5.84, 7.07)
      ..lineTo(2.18, 7.07)
      ..cubicTo(1.43, 8.55, 1, 10.22, 1, 12)
      ..cubicTo(1, 13.78, 1.43, 15.45, 2.18, 16.93)
      ..lineTo(5.84, 14.09)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;
    final redPath = Path()
      ..moveTo(12, 5.38)
      ..cubicTo(13.62, 5.38, 15.06, 5.94, 16.21, 7.02)
      ..lineTo(19.36, 3.87)
      ..cubicTo(17.45, 2.09, 14.97, 1, 12, 1)
      ..cubicTo(7.7, 1, 3.99, 3.47, 2.18, 7.07)
      ..lineTo(5.84, 9.91)
      ..cubicTo(6.71, 7.31, 9.14, 5.38, 12, 5.38)
      ..close();
    canvas.drawPath(redPath, redPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for GitHub's octocat logo (small version)
class _GitHubLogoSmallPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.scale(scale, scale);

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(12, 0.297)
      ..cubicTo(5.37, 0.297, 0, 5.67, 0, 12.297)
      ..cubicTo(0, 17.6, 3.438, 22.097, 8.205, 23.682)
      ..cubicTo(8.805, 23.795, 9.025, 23.424, 9.025, 23.105)
      ..cubicTo(9.025, 22.82, 9.015, 22.065, 9.01, 21.065)
      ..cubicTo(5.672, 21.789, 4.968, 19.455, 4.968, 19.455)
      ..cubicTo(4.422, 18.07, 3.633, 17.7, 3.633, 17.7)
      ..cubicTo(2.546, 16.956, 3.717, 16.971, 3.717, 16.971)
      ..cubicTo(4.922, 17.055, 5.555, 18.207, 5.555, 18.207)
      ..cubicTo(6.625, 20.042, 8.364, 19.512, 9.05, 19.205)
      ..cubicTo(9.158, 18.429, 9.467, 17.9, 9.81, 17.6)
      ..cubicTo(7.145, 17.3, 4.344, 16.268, 4.344, 11.67)
      ..cubicTo(4.344, 10.36, 4.809, 9.29, 5.579, 8.45)
      ..cubicTo(5.444, 8.147, 5.039, 6.927, 5.684, 5.274)
      ..cubicTo(5.684, 5.274, 6.689, 4.952, 8.984, 6.504)
      ..cubicTo(9.944, 6.237, 10.964, 6.105, 11.984, 6.099)
      ..cubicTo(13.004, 6.105, 14.024, 6.237, 14.984, 6.504)
      ..cubicTo(17.264, 4.952, 18.269, 5.274, 18.269, 5.274)
      ..cubicTo(18.914, 6.927, 18.509, 8.147, 18.389, 8.45)
      ..cubicTo(19.154, 9.29, 19.619, 10.36, 19.619, 11.67)
      ..cubicTo(19.619, 16.28, 16.814, 17.295, 14.144, 17.59)
      ..cubicTo(14.564, 17.95, 14.954, 18.686, 14.954, 19.81)
      ..cubicTo(14.954, 21.416, 14.939, 22.706, 14.939, 23.096)
      ..cubicTo(14.939, 23.411, 15.149, 23.786, 15.764, 23.666)
      ..cubicTo(20.565, 22.092, 24, 17.592, 24, 12.297)
      ..cubicTo(24, 5.67, 18.627, 0.297, 12, 0.297)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SocialSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const _SocialSignInButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.scale(scale, scale);

    // Blue
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final bluePath = Path()
      ..moveTo(22.56, 12.25)
      ..cubicTo(22.56, 11.47, 22.49, 10.72, 22.36, 10)
      ..lineTo(12, 10)
      ..lineTo(12, 14.26)
      ..lineTo(17.92, 14.26)
      ..cubicTo(17.66, 15.63, 16.88, 16.79, 15.71, 17.57)
      ..lineTo(15.71, 20.34)
      ..lineTo(19.28, 20.34)
      ..cubicTo(21.36, 18.42, 22.56, 15.6, 22.56, 12.25)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    // Green
    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;
    final greenPath = Path()
      ..moveTo(12, 23)
      ..cubicTo(14.97, 23, 17.46, 22.02, 19.28, 20.34)
      ..lineTo(15.71, 17.57)
      ..cubicTo(14.73, 18.23, 13.48, 18.63, 12, 18.63)
      ..cubicTo(9.14, 18.63, 6.71, 16.7, 5.84, 14.1)
      ..lineTo(2.18, 14.1)
      ..lineTo(2.18, 16.94)
      ..cubicTo(3.99, 20.53, 7.7, 23, 12, 23)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    // Yellow
    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;
    final yellowPath = Path()
      ..moveTo(5.84, 14.09)
      ..cubicTo(5.62, 13.43, 5.49, 12.73, 5.49, 12)
      ..cubicTo(5.49, 11.27, 5.62, 10.57, 5.84, 9.91)
      ..lineTo(5.84, 7.07)
      ..lineTo(2.18, 7.07)
      ..cubicTo(1.43, 8.55, 1, 10.22, 1, 12)
      ..cubicTo(1, 13.78, 1.43, 15.45, 2.18, 16.93)
      ..lineTo(5.03, 14.71)
      ..lineTo(5.84, 14.09)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    // Red
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;
    final redPath = Path()
      ..moveTo(12, 5.38)
      ..cubicTo(13.62, 5.38, 15.06, 5.94, 16.21, 7.02)
      ..lineTo(19.36, 3.87)
      ..cubicTo(17.45, 2.09, 14.97, 1, 12, 1)
      ..cubicTo(7.7, 1, 3.99, 3.47, 2.18, 7.07)
      ..lineTo(5.84, 9.91)
      ..cubicTo(6.71, 7.31, 9.14, 5.38, 12, 5.38)
      ..close();
    canvas.drawPath(redPath, redPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom GitHub logo widget
class _GitHubLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GitHubLogoPainter()),
    );
  }
}

class _GitHubLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.scale(scale, scale);

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // GitHub Octocat logo path
    final path = Path()
      ..moveTo(12, 0.297)
      ..cubicTo(5.37, 0.297, 0, 5.67, 0, 12.297)
      ..cubicTo(0, 17.6, 3.438, 22.097, 8.205, 23.682)
      ..cubicTo(8.805, 23.795, 9.025, 23.424, 9.025, 23.105)
      ..cubicTo(9.025, 22.82, 9.015, 22.065, 9.01, 21.065)
      ..cubicTo(5.672, 21.789, 4.968, 19.455, 4.968, 19.455)
      ..cubicTo(4.422, 18.07, 3.633, 17.7, 3.633, 17.7)
      ..cubicTo(2.546, 16.956, 3.717, 16.971, 3.717, 16.971)
      ..cubicTo(4.922, 17.055, 5.555, 18.207, 5.555, 18.207)
      ..cubicTo(6.625, 20.042, 8.364, 19.512, 9.05, 19.205)
      ..cubicTo(9.158, 18.429, 9.467, 17.9, 9.81, 17.6)
      ..cubicTo(7.145, 17.3, 4.344, 16.268, 4.344, 11.67)
      ..cubicTo(4.344, 10.36, 4.809, 9.29, 5.579, 8.45)
      ..cubicTo(5.444, 8.147, 5.039, 6.927, 5.684, 5.274)
      ..cubicTo(5.684, 5.274, 6.689, 4.952, 8.984, 6.504)
      ..cubicTo(9.944, 6.237, 10.964, 6.105, 11.984, 6.099)
      ..cubicTo(13.004, 6.105, 14.024, 6.237, 14.984, 6.504)
      ..cubicTo(17.264, 4.952, 18.269, 5.274, 18.269, 5.274)
      ..cubicTo(18.914, 6.927, 18.509, 8.147, 18.389, 8.45)
      ..cubicTo(19.154, 9.29, 19.619, 10.36, 19.619, 11.67)
      ..cubicTo(19.619, 16.28, 16.814, 17.295, 14.144, 17.59)
      ..cubicTo(14.564, 17.95, 14.954, 18.686, 14.954, 19.81)
      ..cubicTo(14.954, 21.416, 14.939, 22.706, 14.939, 23.096)
      ..cubicTo(14.939, 23.411, 15.149, 23.786, 15.764, 23.666)
      ..cubicTo(20.565, 22.092, 24, 17.592, 24, 12.297)
      ..cubicTo(24, 5.67, 18.627, 0.297, 12, 0.297)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLOUD SYNC PAYWALL SHEET
// ═══════════════════════════════════════════════════════════════════════════════

class _CloudSyncPaywallSheet extends ConsumerStatefulWidget {
  final VoidCallback onPurchaseStart;
  final VoidCallback onPurchaseEnd;

  const _CloudSyncPaywallSheet({
    required this.onPurchaseStart,
    required this.onPurchaseEnd,
  });

  @override
  ConsumerState<_CloudSyncPaywallSheet> createState() =>
      _CloudSyncPaywallSheetState();
}

class _CloudSyncPaywallSheetState
    extends ConsumerState<_CloudSyncPaywallSheet> {
  bool _isLoading = true;
  List<StoreProduct> _products = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await Purchases.getProducts([
        'cloud_monthly',
        'cloud_yearly',
      ], productCategory: ProductCategory.subscription);
      if (mounted) {
        setState(() {
          _products = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load prices';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _purchase(StoreProduct product) async {
    if (!mounted) return;
    widget.onPurchaseStart();
    try {
      await Purchases.purchase(PurchaseParams.storeProduct(product));
      if (mounted) {
        Navigator.of(context).pop();
        showSuccessSnackBar(context, 'Subscription activated!');
      }
    } catch (e) {
      AppLogging.subscriptions('Purchase error: $e');
      if (mounted) {
        showErrorSnackBar(context, 'Purchase failed');
      }
    } finally {
      if (mounted) {
        widget.onPurchaseEnd();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = context.accentColor;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 24),

          // Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cloud_sync, size: 40, color: accentColor),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            'Unlock Cloud Sync',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'Sync your mesh data across all your devices',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textSecondary),
          ),
          SizedBox(height: 24),

          // Features
          _FeatureRow(icon: Icons.devices, text: 'Sync across all devices'),
          _FeatureRow(icon: Icons.backup, text: 'Automatic cloud backup'),
          _FeatureRow(icon: Icons.share, text: 'Share profiles & settings'),
          _FeatureRow(icon: Icons.offline_bolt, text: 'Local mode always free'),

          const SizedBox(height: 24),

          // Products
          if (_isLoading)
            const CircularProgressIndicator()
          else if (_error != null)
            Text(_error!, style: TextStyle(color: AppTheme.errorRed))
          else
            ..._products.map((p) => _buildProductButton(p)),

          const SizedBox(height: 16),

          // Restore
          TextButton(
            onPressed: () => _restorePurchases(),
            child: Text('Restore Purchases'),
          ),

          const SizedBox(height: 8),

          // Terms
          Text(
            'Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: context.textTertiary),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _restorePurchases() async {
    try {
      await Purchases.restorePurchases();
      final service = ref.read(cloudSyncEntitlementServiceProvider);
      await service.refreshEntitlement();
      if (service.currentEntitlement.hasFullAccess && mounted) {
        Navigator.pop(context);
        showSuccessSnackBar(context, 'Subscription restored!');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Restore failed');
      }
    }
  }

  Widget _buildProductButton(StoreProduct product) {
    final isYearly = product.identifier.contains('yearly');
    final accentColor = context.accentColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _purchase(product),
          style: ElevatedButton.styleFrom(
            backgroundColor: isYearly ? accentColor : context.card,
            foregroundColor: isYearly ? Colors.white : accentColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: isYearly ? null : BorderSide(color: accentColor),
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
                  fontSize: 13,
                  color: isYearly
                      ? Colors.white.withValues(alpha: 0.8)
                      : accentColor.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom list tile for Manage section with proper InkWell clipping
class _ManageListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  const _ManageListTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: context.textSecondary, size: 24),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        color: context.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textTertiary,
                        ),
                      ),
                    ],
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
