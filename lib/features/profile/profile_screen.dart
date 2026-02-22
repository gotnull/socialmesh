// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/safety/lifecycle_mixin.dart';
import '../../core/safety/error_handler.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/content_moderation_warning.dart';
import '../../core/widgets/default_banner.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/verified_badge.dart';
import '../../providers/help_providers.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_providers.dart';
import '../../providers/profile_providers.dart';
import '../../providers/social_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../providers/subscription_providers.dart';
import '../../services/content_moderation/profanity_checker.dart';
import '../../services/profile/profile_cloud_sync_service.dart';
import '../../core/logging.dart';
import '../../core/navigation.dart';
import '../../providers/app_providers.dart';
import '../../providers/connectivity_providers.dart';
import '../../providers/connection_providers.dart';
import '../../providers/database_lifecycle.dart';
import '../../utils/snackbar.dart';
import '../../core/widgets/status_banner.dart';
import '../../utils/validation.dart';
import '../navigation/main_shell.dart';
import '../settings/widgets/cloud_sync_paywall.dart';

/// Screen for viewing and editing user profile with integrated cloud backup
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final authState = ref.watch(authStateProvider);

    // If this screen was pushed (can pop), show back button
    // If it's a root drawer screen, show hamburger menu.
    // Use route.isFirst to avoid drawer local-history entries flipping this.
    final route = ModalRoute.of(context);
    final canPop = route != null ? !route.isFirst : Navigator.canPop(context);

    return HelpTourController(
      topicId: 'profile_overview',
      stepKeys: const {},
      child: GlassScaffold(
        title: 'Profile',
        leading: canPop ? const BackButton() : const HamburgerMenuButton(),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            onPressed: () => _showEditSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Help',
            onPressed: () =>
                ref.read(helpProvider.notifier).startTour('profile_overview'),
          ),
        ],
        slivers: [
          // Cloud sync status banners
          SliverToBoxAdapter(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CloudSyncExpiredBanner(),
                CloudSyncGracePeriodBanner(),
              ],
            ),
          ),
          // Main content
          SliverFillRemaining(
            hasScrollBody: true,
            child: profileAsync.when(
              data: (profile) => profile != null
                  ? _ProfileView(
                      profile: profile,
                      user: authState.value,
                      onEditTap: () => _showEditSheet(context),
                    )
                  : _EmptyProfileView(onEditTap: () => _showEditSheet(context)),
              loading: () => const ScreenLoadingIndicator(),
              error: (e, _) {
                // Try to show cached/previous data with an error banner
                final cachedProfile = profileAsync.value;
                if (cachedProfile != null) {
                  return _ProfileView(
                    profile: cachedProfile,
                    user: authState.value,
                    onEditTap: () => _showEditSheet(context),
                  );
                }
                // No cached data - show empty profile with setup prompt
                return _EmptyProfileView(
                  onEditTap: () => _showEditSheet(context),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditSheet(BuildContext context) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => const _EditProfileSheet(),
    );

    // Force refresh after sheet closes - always refresh to be safe
    if (!mounted) return;
    ref.invalidate(userProfileProvider);
    // Wait for the provider to reload so any errors surface here.
    await ref.read(userProfileProvider.future);
  }
}

/// Empty profile view for new users or when no profile exists
class _EmptyProfileView extends ConsumerWidget {
  final VoidCallback onEditTap;

  const _EmptyProfileView({required this.onEditTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accentColor = context.accentColor;
    // Watch sync error from provider (clears when retry succeeds)
    final syncError = ref.watch(syncErrorProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Sync error banner (if any)
          if (syncError != null) ...[
            _SyncErrorBanner(error: syncError),
            SizedBox(height: 16),
          ],

          const SizedBox(height: 40),

          // Empty avatar placeholder
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: 0.1),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.person_outline,
              size: 56,
              color: accentColor.withValues(alpha: 0.5),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Set up your profile',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Add your name, photo, and bio to personalize your mesh presence.',
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          FilledButton.icon(
            onPressed: onEditTap,
            icon: const Icon(Icons.edit),
            label: const Text('Create Profile'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _ProfileView extends ConsumerWidget {
  final UserProfile profile;
  final User? user;
  final VoidCallback onEditTap;

  const _ProfileView({
    required this.profile,
    required this.user,
    required this.onEditTap,
  });

  bool get isSignedIn => user != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accentColor = context.accentColor;
    // Watch sync error from provider (clears when retry succeeds)
    final syncError = ref.watch(syncErrorProvider);
    // Check if user has all premium features for gold badge
    // Only show badge for SIGNED IN users with all premium features
    final hasAllPremium =
        isSignedIn && ref.watch(hasAllPremiumFeaturesProvider);

    return SingleChildScrollView(
      child: Column(
        children: [
          // Sync error banner (if any)
          if (syncError != null) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: _SyncErrorBanner(error: syncError),
            ),
          ],

          // Banner and Avatar section
          _BannerAvatarSection(profile: profile, accentColor: accentColor),
          const SizedBox(height: 16),

          // Display name and verified badge
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    profile.displayName,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasAllPremium) ...[const SimpleVerifiedBadge(size: 24)],
              ],
            ),
          ),
          if (profile.callsign != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentColor.withValues(alpha: 0.5)),
              ),
              child: Text(
                profile.callsign!,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Padded content section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Bio
                if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.border.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      profile.bio!,
                      style: TextStyle(
                        fontSize: 15,
                        color: context.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Info cards
                _ProfileInfoCard(
                  title: 'Details',
                  items: [
                    if (profile.email != null)
                      _InfoItem(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: profile.email!,
                      ),
                    if (user != null)
                      _InfoItem(
                        icon: Icons.fingerprint,
                        label: 'UID',
                        value: user!.uid,
                        copyable: true,
                      ),
                    // Only show "Member since" for signed in users
                    if (isSignedIn)
                      _InfoItem(
                        icon: Icons.calendar_today_outlined,
                        label: 'Member since',
                        value: _formatDate(profile.createdAt),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (profile.website != null ||
                    profile.socialLinks?.isEmpty == false) ...[
                  _ProfileInfoCard(
                    title: 'Links',
                    items: [
                      if (profile.website != null)
                        _InfoItem(
                          icon: Icons.link,
                          label: 'Website',
                          value: profile.website!,
                        ),
                      if (profile.socialLinks?.twitter != null)
                        _InfoItem(
                          icon: Icons.alternate_email,
                          label: 'Twitter',
                          value: '@${profile.socialLinks!.twitter}',
                        ),
                      if (profile.socialLinks?.mastodon != null)
                        _InfoItem(
                          icon: Icons.tag,
                          label: 'Mastodon',
                          value: profile.socialLinks!.mastodon!,
                        ),
                      if (profile.socialLinks?.github != null)
                        _InfoItem(
                          icon: Icons.code,
                          label: 'GitHub',
                          value: profile.socialLinks!.github!,
                        ),
                      if (profile.socialLinks?.discord != null)
                        _InfoItem(
                          icon: Icons.discord,
                          label: 'Discord',
                          value: profile.socialLinks!.discord!,
                        ),
                      if (profile.socialLinks?.telegram != null)
                        _InfoItem(
                          icon: Icons.send,
                          label: 'Telegram',
                          value: profile.socialLinks!.telegram!,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Edit profile button
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onEditTap,
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Profile'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                // Cloud Backup Section (collapsible)
                const SizedBox(height: 24),
                _CloudBackupSection(user: user),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
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
    return '${months[date.month - 1]} ${date.year}';
  }
}

/// Collapsible Cloud Backup Section - integrates sign in/out and sync
class _CloudBackupSection extends ConsumerStatefulWidget {
  final User? user;

  const _CloudBackupSection({required this.user});

  @override
  ConsumerState<_CloudBackupSection> createState() =>
      _CloudBackupSectionState();
}

class _CloudBackupSectionState extends ConsumerState<_CloudBackupSection> {
  bool _isExpanded = false;
  bool _isSigningIn = false;

  bool get isSignedIn => widget.user != null;

  @override
  void initState() {
    super.initState();
    // Start expanded if not signed in (to prompt action)
    _isExpanded = !isSignedIn;
  }

  String _getBackupStatusText() {
    if (!isSignedIn) {
      return 'Not backed up';
    }
    final syncStatus = ref.watch(syncStatusProvider);
    return switch (syncStatus) {
      SyncStatus.syncing => 'Syncing...',
      SyncStatus.error => 'Sync error • Tap to retry',
      SyncStatus.synced ||
      SyncStatus.idle => 'Synced • ${widget.user!.email ?? 'Connected'}',
    };
  }

  Color _getStatusColor() {
    if (!isSignedIn) return context.textTertiary;
    final syncStatus = ref.watch(syncStatusProvider);
    return switch (syncStatus) {
      SyncStatus.syncing => context.textTertiary,
      SyncStatus.error => AppTheme.errorRed,
      SyncStatus.synced || SyncStatus.idle => AccentColors.green,
    };
  }

  IconData _getStatusIcon() {
    if (!isSignedIn) return Icons.cloud_off_outlined;
    final syncStatus = ref.watch(syncStatusProvider);
    return switch (syncStatus) {
      SyncStatus.syncing => Icons.cloud_sync_outlined,
      SyncStatus.error => Icons.cloud_off_outlined,
      SyncStatus.synced || SyncStatus.idle => Icons.cloud_done,
    };
  }

  Widget _buildLinkedProvidersRow() {
    final providers = widget.user!.providerData;
    if (providers.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        Text(
          'Linked accounts',
          style: context.bodySmallStyle?.copyWith(color: context.textSecondary),
        ),
        const SizedBox(width: 12),
        ...providers.map(
          (provider) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _ProviderIcon(providerId: provider.providerId),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSignedIn
              ? AccentColors.green.withValues(alpha: 0.3)
              : context.border.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          // Header - always visible
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(12),
              bottom: Radius.circular(_isExpanded ? 0 : 12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ref.watch(syncStatusProvider) == SyncStatus.syncing
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _getStatusColor(),
                            ),
                          )
                        : Icon(
                            _getStatusIcon(),
                            size: 20,
                            color: _getStatusColor(),
                          ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cloud Backup',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getBackupStatusText(),
                          style: TextStyle(
                            fontSize: 12,
                            color: _getStatusColor(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: context.textTertiary,
                  ),
                ],
              ),
            ),
          ),

          // Expandable content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpandedContent(context),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(BuildContext context) {
    if (isSignedIn) {
      return _buildSignedInContent(context);
    }
    return _buildSignedOutContent(context);
  }

  Widget _buildSignedOutContent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(color: context.border),
          SizedBox(height: 12),
          Text(
            'Sign in to backup your profile to the cloud and sync across devices.',
            style: TextStyle(
              fontSize: 13,
              color: context.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Google Sign-In button
          _SocialSignInButton(
            onPressed: _isSigningIn ? null : () => _signInWithGoogle(context),
            icon: _GoogleLogo(),
            label: 'Continue with Google',
            backgroundColor: Colors.white,
            textColor: Colors.black87,
            isLoading: _isSigningIn,
          ),
          const SizedBox(height: 10),

          // Apple Sign-In button (iOS/macOS only)
          if (Platform.isIOS || Platform.isMacOS) ...[
            _SocialSignInButton(
              onPressed: _isSigningIn ? null : () => _signInWithApple(context),
              icon: const Icon(Icons.apple, color: Colors.white, size: 22),
              label: 'Continue with Apple',
              backgroundColor: Colors.black,
              textColor: Colors.white,
              isLoading: _isSigningIn,
            ),
            const SizedBox(height: 10),
          ],

          // GitHub Sign-In button
          _SocialSignInButton(
            onPressed: _isSigningIn ? null : () => _signInWithGitHub(context),
            icon: _GitHubLogo(),
            label: 'Continue with GitHub',
            backgroundColor: const Color(0xFF24292F),
            textColor: Colors.white,
            isLoading: _isSigningIn,
          ),
        ],
      ),
    );
  }

  Widget _buildSignedInContent(BuildContext context) {
    final syncStatus = ref.watch(syncStatusProvider);
    final syncError = ref.watch(syncErrorProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(color: context.border),
          const SizedBox(height: 12),

          // Linked providers chips
          if (widget.user != null) ...[
            _buildLinkedProvidersRow(),
            const SizedBox(height: 12),
          ],

          // Sync error with retry option (only shown when there's an error)
          if (syncStatus == SyncStatus.error) ...[
            StatusBanner.error(
              title: _friendlySyncError(syncError),
              trailing: TextButton(
                onPressed: () => _retrySyncNow(context),
                child: const Text('Retry'),
              ),
              margin: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),
          ],

          // Sign out
          _AccountOptionTile(
            icon: Icons.logout,
            label: 'Sign Out',
            onTap: () => _signOut(context),
          ),

          // Delete account
          const SizedBox(height: 8),
          _AccountOptionTile(
            icon: Icons.delete_outline,
            label: 'Delete Account',
            isDestructive: true,
            onTap: () => _deleteAccount(context),
          ),
        ],
      ),
    );
  }

  /// Returns the [AuthService] if Firebase is ready, or `null` when
  /// Firebase has not finished initializing or failed.
  AuthService? _guardedAuthService(BuildContext context) {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      AppLogging.auth('[ProfileScreen] Sign-in blocked — offline');
      showErrorSnackBar(context, 'Sign-in requires an internet connection.');
      return null;
    }
    final isReady =
        ref.read(firebaseReadyProvider).whenOrNull(data: (v) => v) ?? false;
    if (!isReady) {
      AppLogging.auth('Firebase not ready — sign-in blocked');
      showErrorSnackBar(
        context,
        'Unable to connect to sign-in services. '
        'Check your internet connection and try again.',
      );
      return null;
    }
    return ref.read(authServiceProvider);
  }

  Future<void> _signInWithGoogle(BuildContext context) async {
    if (_isSigningIn) return;
    setState(() => _isSigningIn = true);
    try {
      final authService = _guardedAuthService(context);
      if (authService == null) return;
      final credential = await authService.signInWithGoogle();
      if (context.mounted && credential.user != null) {
        showSuccessSnackBar(context, 'Signed in with Google');
        // Trigger auto-sync after sign-in
        await triggerManualSync(ref);
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        if (e.code != 'sign-in-cancelled') {
          showErrorSnackBar(context, 'Error: ${e.message}');
        }
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Sign in failed');
      }
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Future<void> _signInWithApple(BuildContext context) async {
    if (_isSigningIn) return;
    setState(() => _isSigningIn = true);
    try {
      final authService = _guardedAuthService(context);
      if (authService == null) return;
      final credential = await authService.signInWithApple();
      if (context.mounted && credential.user != null) {
        showSuccessSnackBar(context, 'Signed in with Apple');
        // Trigger auto-sync after sign-in
        await triggerManualSync(ref);
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Error: ${e.message}');
      }
    } catch (e) {
      if (context.mounted) {
        // User cancelled
        AppLogging.auth('Apple sign in: $e');
      }
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Future<void> _signInWithGitHub(BuildContext context) async {
    if (_isSigningIn) return;
    setState(() => _isSigningIn = true);
    try {
      final authService = _guardedAuthService(context);
      if (authService == null) return;
      final credential = await authService.signInWithGitHub();
      if (context.mounted && credential.user != null) {
        showSuccessSnackBar(context, 'Signed in with GitHub');
        // Trigger auto-sync after sign-in
        await triggerManualSync(ref);
      }
    } on AccountLinkingRequiredException catch (e) {
      if (context.mounted) {
        // Show dialog to link accounts
        await _showAccountLinkingDialog(context, e);
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        if (e.code != 'web-context-cancelled') {
          showErrorSnackBar(context, 'Error: ${e.message}');
        }
      }
    } catch (e) {
      if (context.mounted) {
        // User cancelled or other error
        AppLogging.auth('GitHub sign in: $e');
      }
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Future<void> _showAccountLinkingDialog(
    BuildContext context,
    AccountLinkingRequiredException e,
  ) async {
    final providerName = e.existingProviders.contains('google.com')
        ? 'Google'
        : e.existingProviders.contains('apple.com')
        ? 'Apple'
        : e.existingProviders.first;

    final shouldLink = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.card,
        title: const Text('Link GitHub Account'),
        content: Text(
          'An account with ${e.email} already exists using $providerName.\n\n'
          'Sign in with $providerName to link your GitHub account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sign in with $providerName'),
          ),
        ],
      ),
    );

    if (shouldLink == true && context.mounted) {
      try {
        final authService = ref.read(authServiceProvider);

        // Sign in with the existing provider
        if (e.existingProviders.contains('google.com')) {
          await authService.signInWithGoogle();
        } else if (e.existingProviders.contains('apple.com')) {
          await authService.signInWithApple();
        }

        // Now link the GitHub credential
        await authService.linkPendingCredential(e.pendingCredential);

        if (context.mounted) {
          showSuccessSnackBar(context, 'GitHub account linked successfully!');
          await triggerManualSync(ref);
        }
      } catch (linkError) {
        if (context.mounted) {
          showErrorSnackBar(context, 'Failed to link accounts');
          AppLogging.auth('Account linking error: $linkError');
        }
      }
    }
  }

  /// Convert raw sync error strings into user-friendly messages.
  /// Never expose internal error class names or field names to users.
  String _friendlySyncError(String? error) {
    if (error == null) return 'Sync failed';
    if (error.contains('LateInitializationError') ||
        error.contains('has not been initialized')) {
      return 'Cloud services starting up — try again shortly';
    }
    if (error.contains('unavailable') || error.contains('UNAVAILABLE')) {
      return 'Cloud sync temporarily unavailable';
    }
    if (error.contains('permission') || error.contains('PERMISSION')) {
      return 'Sync permission denied';
    }
    if (error.contains('network') ||
        error.contains('connection') ||
        error.contains('SocketException')) {
      return 'No internet connection';
    }
    if (error.contains('timeout') || error.contains('TimeoutException')) {
      return 'Sync timed out — try again';
    }
    return 'Sync temporarily unavailable';
  }

  Future<void> _retrySyncNow(BuildContext context) async {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      AppLogging.auth('[ProfileScreen] Retry sync blocked — offline');
      showErrorSnackBar(context, 'Syncing requires an internet connection.');
      return;
    }
    try {
      await triggerManualSync(ref);
      if (context.mounted) {
        showSuccessSnackBar(context, 'Profile synced!');
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Sync failed');
      }
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      AppLogging.auth('[ProfileScreen] Sign out blocked — offline');
      showErrorSnackBar(
        context,
        'Signing out requires an internet connection.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.card,
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final authService = ref.read(authServiceProvider);
      await authService.signOut();

      // Pop back from the profile screen — the signed-out user should not
      // remain on a screen that renders a stale Guest profile with avatar
      // and "Edit Profile". The drawer's Account screen is the correct
      // entry point for unauthenticated users.
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      AppLogging.auth('[ProfileScreen] Delete account blocked — offline');
      showErrorSnackBar(
        context,
        'Deleting your account requires an internet connection.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.card,
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and all associated data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Show a non-dismissable loading indicator while deletion runs.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: context.card,
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  'Deleting account...',
                  style: TextStyle(color: context.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final authService = ref.read(authServiceProvider);
      // Capture notifiers and services BEFORE the async gap — the widget's
      // ref may become invalid if the widget is disposed while awaiting.
      final appInitNotifier = ref.read(appInitProvider.notifier);
      final deviceConnection = ref.read(deviceConnectionProvider.notifier);

      // ── Step 0: Disconnect BLE FIRST ──
      // This MUST happen before closing/deleting databases. While BLE is
      // connected, the device continuously streams telemetry, positions,
      // node updates, etc. If we close and delete database files while
      // data is still flowing, the in-flight writes hit stale/deleted
      // file handles → "disk I/O error" (error 6922) storm.
      //
      // DeviceConnectionNotifier.disconnect() sets _userDisconnected=true
      // BEFORE the transport disconnect fires, so the state listener sees
      // "user-initiated" and suppresses auto-reconnect. It also clears
      // connectedDeviceProvider and autoReconnectState for us.
      AppLogging.auth('deleteAccount - Disconnecting BLE before database wipe');
      try {
        await deviceConnection.disconnect();
      } catch (e) {
        AppLogging.auth('deleteAccount - BLE disconnect error (non-fatal): $e');
      }

      // ── Step 1: Delete account (CF + local wipe + auth) ──
      await authService.deleteAccount(
        closeLocalDatabases: () => closeAllDatabases(ref),
      );

      // ── Step 2: Invalidate database providers AFTER files are deleted ──
      // This must happen after deleteAccount (which closes handles, deletes
      // files). Invalidation triggers dependent providers to rebuild, which
      // re-opens database files via openDatabase(). If we invalidated
      // BEFORE deletion (as closeAllDatabases used to do), the rebuilt
      // providers would re-open the same files → then deletion unlinks them
      // → "vnode unlinked while in use" + "disk I/O error" storm.
      invalidateAllDatabaseProviders(ref);

      // ── Account is irrevocably deleted. Everything below is cleanup. ──

      if (context.mounted) {
        Navigator.pop(context); // dismiss progress dialog
      }

      // Navigate to _AppRouter which renders based on appInitProvider.
      final navState = navigatorKey.currentState;
      AppLogging.auth(
        'deleteAccount - navigatorKey.currentState: '
        '${navState != null ? "EXISTS" : "NULL"}',
      );

      if (navState != null) {
        navState.pushNamedAndRemoveUntil('/app', (route) => false);
        AppLogging.auth('deleteAccount - pushNamedAndRemoveUntil dispatched');
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final fallback = navigatorKey.currentState;
          fallback?.pushNamedAndRemoveUntil('/app', (route) => false);
        });
      }

      // Re-run initialization from scratch. SharedPreferences was cleared,
      // so initialize() will detect !onboardingComplete and route through
      // the full fresh-install flow: onboarding → terms → scanner → main.
      AppLogging.auth('deleteAccount - Re-initializing app state');
      appInitNotifier.initialize();
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // dismiss progress dialog
        showErrorSnackBar(context, 'Error: ${e.message}');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // dismiss progress dialog
        showErrorSnackBar(
          context,
          'Deletion failed. Please try again or contact support.',
        );
      }
    }
  }
}

/// Small icon showing a linked authentication provider
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
      _ => Icon(Icons.link, size: 14, color: context.textSecondary),
    };
  }
}

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

/// Small tile for account options within cloud backup section
class _AccountOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _AccountOptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppTheme.errorRed : context.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            SizedBox(width: 12),
            Text(
              label,
              style: context.bodySecondaryStyle?.copyWith(color: color),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, size: 18, color: context.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// Social sign-in button with custom styling
class _SocialSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final bool isLoading;

  const _SocialSignInButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;

    return Opacity(
      opacity: isDisabled ? 0.6 : 1.0,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: isDisabled ? null : onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: textColor,
                    ),
                  )
                else
                  icon,
                const SizedBox(width: 12),
                Text(
                  isLoading ? 'Signing in...' : label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Subtle banner for sync errors - doesn't block the UI
class _SyncErrorBanner extends ConsumerWidget {
  final String error;

  const _SyncErrorBanner({required this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Parse error to show user-friendly message
    String message = 'Sync temporarily unavailable';
    if (error.contains('unavailable')) {
      message = 'Cloud sync temporarily unavailable';
    } else if (error.contains('permission')) {
      message = 'Sync permission denied';
    } else if (error.contains('network') || error.contains('connection')) {
      message = 'No internet connection';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AccentColors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AccentColors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, size: 18, color: AccentColors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: context.bodySmallStyle?.copyWith(
                color: AccentColors.orange,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              AppLogging.auth(
                'SyncErrorBanner: Retry tapped — calling refresh() '
                'which clears errors and re-runs cloud sync',
              );
              ref.read(userProfileProvider.notifier).refresh();
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Retry',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AccentColors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom Google logo widget
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

/// Combined banner and avatar section for profile view
class _BannerAvatarSection extends StatelessWidget {
  final UserProfile profile;
  final Color accentColor;

  const _BannerAvatarSection({
    required this.profile,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    // Use a SizedBox to give the Stack a fixed height (banner + avatar overflow)
    return SizedBox(
      height: 230, // 140 banner + 50 avatar overflow
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Banner with gradient overlay for blending into background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 180,
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.2, 0.6, 1.0],
                  colors: [
                    Colors.white.withValues(alpha: 0.4),
                    Colors.white,
                    Colors.white,
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: Container(
                decoration: BoxDecoration(color: context.card),
                child: _buildBannerContent(context),
              ),
            ),
          ),
          // Avatar positioned at bottom of banner, overlapping
          Positioned(
            top: 130, // 140 - 50 (half of avatar)
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: context.background, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.3),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: _buildAvatar(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerContent(BuildContext context) {
    if (profile.bannerUrl == null) {
      return DefaultBanner(accentColor: accentColor);
    }

    if (profile.bannerUrl!.startsWith('http')) {
      return Image.network(
        profile.bannerUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: accentColor,
            ),
          );
        },
        errorBuilder: (ctx, err, stack) =>
            DefaultBanner(accentColor: accentColor),
      );
    } else {
      return Image.file(
        File(profile.bannerUrl!),
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (ctx, err, stack) =>
            DefaultBanner(accentColor: accentColor),
      );
    }
  }

  Widget _buildAvatar(BuildContext context) {
    return UserAvatar(
      imageUrl: profile.avatarUrl,
      initials: profile.initials,
      size: 100,
      borderWidth: 3,
      borderColor: accentColor,
      foregroundColor: accentColor,
      backgroundColor: context.card,
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  final String title;
  final List<_InfoItem> items;

  const _ProfileInfoCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.accentColor,
                letterSpacing: 1,
              ),
            ),
          ),
          Divider(height: 1, color: context.border),
          ...items.map((item) => _buildInfoRow(context, item)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, _InfoItem item) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(item.icon, size: 20, color: context.textTertiary),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: context.bodySmallStyle?.copyWith(
                    color: context.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.value,
                  style: context.bodySecondaryStyle?.copyWith(
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (item.copyable)
            Icon(Icons.copy, size: 16, color: context.textTertiary),
        ],
      ),
    );

    if (item.copyable) {
      return InkWell(
        onTap: () {
          Clipboard.setData(ClipboardData(text: item.value));
          showInfoSnackBar(
            context,
            '${item.label} copied to clipboard',
            duration: const Duration(seconds: 2),
          );
        },
        child: content,
      );
    }

    return content;
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;
  final bool copyable;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.copyable = false,
  });
}

// Edit Profile Sheet
class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet();

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet>
    with LifecycleSafeMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  final FocusNode _bioFocusNode = FocusNode();
  late TextEditingController _callsignController;
  late TextEditingController _websiteController;
  late TextEditingController _twitterController;
  late TextEditingController _mastodonController;
  late TextEditingController _githubController;
  late TextEditingController _discordController;
  late TextEditingController _telegramController;

  bool _isLoading = false;
  bool _isUploadingAvatar = false;
  bool _isUploadingBanner = false;
  bool _isRemovingAvatar = false;
  bool _isRemovingBanner = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider).value;
    _displayNameController = TextEditingController(
      text: profile?.displayName ?? '',
    );
    _bioController = TextEditingController(text: profile?.bio ?? '');
    _callsignController = TextEditingController(text: profile?.callsign ?? '');
    _websiteController = TextEditingController(text: profile?.website ?? '');
    _twitterController = TextEditingController(
      text: profile?.socialLinks?.twitter ?? '',
    );
    _mastodonController = TextEditingController(
      text: profile?.socialLinks?.mastodon ?? '',
    );
    _githubController = TextEditingController(
      text: profile?.socialLinks?.github ?? '',
    );
    _discordController = TextEditingController(
      text: profile?.socialLinks?.discord ?? '',
    );
    _telegramController = TextEditingController(
      text: profile?.socialLinks?.telegram ?? '',
    );

    // Listen for changes
    for (final controller in [
      _displayNameController,
      _bioController,
      _callsignController,
      _websiteController,
      _twitterController,
      _mastodonController,
      _githubController,
      _discordController,
      _telegramController,
    ]) {
      controller.addListener(_onFieldChanged);
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _bioFocusNode.dispose();
    _callsignController.dispose();
    _websiteController.dispose();
    _twitterController.dispose();
    _mastodonController.dispose();
    _githubController.dispose();
    _discordController.dispose();
    _telegramController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      safeSetState(() => _hasChanges = true);
    }
  }

  Future<void> _pickAvatar() async {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      safeShowSnackBar(
        'Uploading avatars requires an internet connection.',
        backgroundColor: Colors.red,
      );
      return;
    }

    // Capture notifier before any async operation
    final notifier = ref.read(userProfileProvider.notifier);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      safeSetState(() => _isUploadingAvatar = true);
      try {
        final file = File(result.files.first.path!);
        await notifier.saveAvatarFromFile(file);
        // Force refresh - safe because invalidate works even after dispose
        if (mounted) {
          ref.invalidate(userProfileProvider);
          safeSetState(() => _hasChanges = true);
          safeShowSnackBar('Avatar updated');
        }
      } catch (e) {
        if (e.toString().contains('Content policy violation') ||
            e.toString().contains('violates content policy')) {
          if (mounted) {
            await ContentModerationWarning.show(
              context,
              result: ContentModerationCheckResult(
                passed: false,
                action: 'reject',
                categories: ['Inappropriate Content'],
              ),
            );
          }
        } else {
          safeShowSnackBar(
            'Failed to upload avatar: $e',
            backgroundColor: Colors.red,
          );
        }
      } finally {
        safeSetState(() => _isUploadingAvatar = false);
      }
    }
  }

  Future<void> _removeAvatar() async {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      safeShowSnackBar(
        'Removing avatars requires an internet connection.',
        backgroundColor: Colors.red,
      );
      return;
    }

    // Capture notifier before async operation
    final notifier = ref.read(userProfileProvider.notifier);

    safeSetState(() => _isRemovingAvatar = true);
    try {
      await notifier.deleteAvatar();
      if (mounted) {
        ref.invalidate(userProfileProvider);
        safeSetState(() => _hasChanges = true);
        safeShowSnackBar('Avatar removed');
      }
    } catch (e) {
      safeShowSnackBar(
        'Failed to remove avatar: $e',
        backgroundColor: Colors.red,
      );
    } finally {
      safeSetState(() => _isRemovingAvatar = false);
    }
  }

  Future<void> _pickBanner() async {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      safeShowSnackBar(
        'Uploading banners requires an internet connection.',
        backgroundColor: Colors.red,
      );
      return;
    }

    // Capture notifier before async operation
    final notifier = ref.read(userProfileProvider.notifier);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      safeSetState(() => _isUploadingBanner = true);
      try {
        final file = File(result.files.first.path!);
        await notifier.saveBannerFromFile(file);
        if (mounted) {
          ref.invalidate(userProfileProvider);
          safeSetState(() => _hasChanges = true);
          safeShowSnackBar('Banner updated');
        }
      } catch (e) {
        if (e.toString().contains('Content policy violation') ||
            e.toString().contains('violates content policy')) {
          if (mounted) {
            await ContentModerationWarning.show(
              context,
              result: ContentModerationCheckResult(
                passed: false,
                action: 'reject',
                categories: ['Inappropriate Content'],
              ),
            );
          }
        } else {
          safeShowSnackBar(
            'Failed to upload banner: $e',
            backgroundColor: Colors.red,
          );
        }
      } finally {
        safeSetState(() => _isUploadingBanner = false);
      }
    }
  }

  Future<void> _removeBanner() async {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      safeShowSnackBar(
        'Removing banners requires an internet connection.',
        backgroundColor: Colors.red,
      );
      return;
    }

    // Capture notifier before async operation
    final notifier = ref.read(userProfileProvider.notifier);

    safeSetState(() => _isRemovingBanner = true);
    try {
      await notifier.deleteBanner();
      if (mounted) {
        ref.invalidate(userProfileProvider);
        safeSetState(() => _hasChanges = true);
        safeShowSnackBar('Banner removed');
      }
    } catch (e) {
      safeShowSnackBar(
        'Failed to remove banner: $e',
        backgroundColor: Colors.red,
      );
    } finally {
      safeSetState(() => _isRemovingBanner = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      safeShowSnackBar(
        'Saving your profile requires an internet connection.',
        backgroundColor: Colors.red,
      );
      return;
    }

    // Show loading immediately when save is tapped
    safeSetState(() => _isLoading = true);

    // Add breadcrumb for crash context
    AppErrorHandler.addBreadcrumb('Profile save started');

    // CRITICAL: Capture ALL provider dependencies BEFORE any await
    // This prevents accessing ref after widget disposal
    final moderationService = ref.read(contentModerationServiceProvider);
    final currentUser = ref.read(currentUserProvider);
    final cloudSyncService = ref.read(
      profileCloudSyncServiceProvider,
    ); // nullable
    final profileNotifier = ref.read(userProfileProvider.notifier);

    try {
      // 1. Check Display Name - REJECT immediately if violates (no "post anyway")
      final displayName = _displayNameController.text.trim();
      if (displayName.isNotEmpty) {
        final displayNameCheck = await moderationService.checkText(
          displayName,
          useServerCheck: true,
        );

        if (!displayNameCheck.passed ||
            displayNameCheck.action == 'reject' ||
            displayNameCheck.action == 'review' ||
            displayNameCheck.action == 'flag') {
          // Display name violations are NOT allowed - reject outright
          if (!mounted) return;
          await ContentModerationWarning.show(
            context,
            result: ContentModerationCheckResult(
              passed: false,
              action: 'reject',
              categories: displayNameCheck.categories
                  .map((c) => c.name)
                  .toList(),
              details:
                  'Display names cannot contain inappropriate content. Please choose a different name.',
            ),
          );
          return;
        }

        // 1b. Check display name uniqueness - using pre-captured cloudSyncService
        if (currentUser != null && cloudSyncService != null) {
          final isTaken = await cloudSyncService.isDisplayNameTaken(
            displayName,
            currentUser.uid,
          );
          if (isTaken) {
            if (!mounted) return;
            showErrorSnackBar(
              context,
              'This display name is already taken. Please choose a different one.',
            );
            return;
          }
        }
      }

      // 2. Check Callsign - REJECT immediately if violates (no "post anyway")
      final callsign = _callsignController.text.trim();
      if (callsign.isNotEmpty) {
        final callsignCheck = await moderationService.checkText(
          callsign,
          useServerCheck: true,
        );

        if (!callsignCheck.passed ||
            callsignCheck.action == 'reject' ||
            callsignCheck.action == 'review' ||
            callsignCheck.action == 'flag') {
          // Callsign violations are NOT allowed - reject outright
          if (!mounted) return;
          await ContentModerationWarning.show(
            context,
            result: ContentModerationCheckResult(
              passed: false,
              action: 'reject',
              categories: callsignCheck.categories.map((c) => c.name).toList(),
              details:
                  'Callsigns cannot contain inappropriate content. Please use a valid callsign.',
            ),
          );
          return;
        }
      }

      // 3. Check Bio - REJECT immediately if violates (no "post anyway")
      final bio = _bioController.text.trim();
      if (bio.isNotEmpty) {
        final bioCheck = await moderationService.checkText(
          bio,
          useServerCheck: true,
        );

        if (!bioCheck.passed || bioCheck.action == 'reject') {
          // Bio content blocked - show error and stop
          if (!mounted) return;
          await ContentModerationWarning.show(
            context,
            result: ContentModerationCheckResult(
              passed: false,
              action: 'reject',
              categories: bioCheck.categories.map((c) => c.name).toList(),
              details: bioCheck.details,
            ),
          );
          return;
        }
      }

      // 4. Check Website - REJECT immediately if violates
      final website = _websiteController.text.trim();
      if (website.isNotEmpty) {
        final websiteCheck = await moderationService.checkText(
          website,
          useServerCheck: true,
        );

        if (!websiteCheck.passed || websiteCheck.action == 'reject') {
          if (!mounted) return;
          await ContentModerationWarning.show(
            context,
            result: ContentModerationCheckResult(
              passed: false,
              action: 'reject',
              categories: websiteCheck.categories.map((c) => c.name).toList(),
              details: 'Website URL contains inappropriate content.',
            ),
          );
          return;
        }
      }

      // 5. Check Twitter - REJECT immediately if violates
      final twitter = _twitterController.text.trim();
      if (twitter.isNotEmpty) {
        final twitterCheck = await moderationService.checkText(
          twitter,
          useServerCheck: true,
        );

        if (!twitterCheck.passed || twitterCheck.action == 'reject') {
          if (!mounted) return;
          await ContentModerationWarning.show(
            context,
            result: ContentModerationCheckResult(
              passed: false,
              action: 'reject',
              categories: twitterCheck.categories.map((c) => c.name).toList(),
              details: 'Twitter username contains inappropriate content.',
            ),
          );
          return;
        }
      }

      // 6. Check Mastodon - REJECT immediately if violates
      final mastodon = _mastodonController.text.trim();
      if (mastodon.isNotEmpty) {
        final mastodonCheck = await moderationService.checkText(
          mastodon,
          useServerCheck: true,
        );

        if (!mastodonCheck.passed || mastodonCheck.action == 'reject') {
          if (!mounted) return;
          await ContentModerationWarning.show(
            context,
            result: ContentModerationCheckResult(
              passed: false,
              action: 'reject',
              categories: mastodonCheck.categories.map((c) => c.name).toList(),
              details: 'Mastodon handle contains inappropriate content.',
            ),
          );
          return;
        }
      }

      // 7. Check GitHub - REJECT immediately if violates
      final github = _githubController.text.trim();
      if (github.isNotEmpty) {
        final githubCheck = await moderationService.checkText(
          github,
          useServerCheck: true,
        );

        if (!githubCheck.passed || githubCheck.action == 'reject') {
          if (!mounted) return;
          await ContentModerationWarning.show(
            context,
            result: ContentModerationCheckResult(
              passed: false,
              action: 'reject',
              categories: githubCheck.categories.map((c) => c.name).toList(),
              details: 'GitHub username contains inappropriate content.',
            ),
          );
          return;
        }
      }

      // 8. Check Discord - REJECT immediately if violates
      final discord = _discordController.text.trim();
      if (discord.isNotEmpty) {
        final discordCheck = await moderationService.checkText(
          discord,
          useServerCheck: true,
        );

        if (!discordCheck.passed || discordCheck.action == 'reject') {
          if (!mounted) return;
          await ContentModerationWarning.show(
            context,
            result: ContentModerationCheckResult(
              passed: false,
              action: 'reject',
              categories: discordCheck.categories.map((c) => c.name).toList(),
              details: 'Discord username contains inappropriate content.',
            ),
          );
          return;
        }
      }

      // 9. Check Telegram - REJECT immediately if violates
      final telegram = _telegramController.text.trim();
      if (telegram.isNotEmpty) {
        final telegramCheck = await moderationService.checkText(
          telegram,
          useServerCheck: true,
        );

        if (!telegramCheck.passed || telegramCheck.action == 'reject') {
          if (!mounted) return;
          await ContentModerationWarning.show(
            context,
            result: ContentModerationCheckResult(
              passed: false,
              action: 'reject',
              categories: telegramCheck.categories.map((c) => c.name).toList(),
              details: 'Telegram username contains inappropriate content.',
            ),
          );
          return;
        }
      }

      // All validation passed - now save the profile
      final socialLinks = ProfileSocialLinks(
        twitter: _twitterController.text.isEmpty
            ? null
            : _twitterController.text.replaceAll('@', ''),
        mastodon: _mastodonController.text.isEmpty
            ? null
            : _mastodonController.text,
        github: _githubController.text.isEmpty ? null : _githubController.text,
        discord: _discordController.text.isEmpty
            ? null
            : _discordController.text,
        telegram: _telegramController.text.isEmpty
            ? null
            : _telegramController.text,
      );

      // Use pre-captured profileNotifier instead of ref.read after await
      await profileNotifier.updateProfile(
        displayName: _displayNameController.text.trim(),
        bio: _bioController.text.isEmpty ? null : _bioController.text.trim(),
        callsign: _callsignController.text.isEmpty
            ? null
            : _callsignController.text.trim().toUpperCase(),
        website: _websiteController.text.isEmpty
            ? null
            : _websiteController.text.trim(),
        socialLinks: socialLinks.isEmpty ? null : socialLinks,
        clearBio: _bioController.text.isEmpty,
        clearCallsign: _callsignController.text.isEmpty,
        clearWebsite: _websiteController.text.isEmpty,
        clearSocialLinks: socialLinks.isEmpty,
      );

      AppErrorHandler.addBreadcrumb('Profile save completed');

      // Use safe navigation methods from LifecycleSafeMixin
      safeNavigatorPop(true);
      safeShowSnackBar('Profile updated', backgroundColor: Colors.green);
    } on DisplayNameTakenException catch (e) {
      safeShowSnackBar(e.toString(), backgroundColor: Colors.red);
    } catch (e) {
      AppErrorHandler.addBreadcrumb('Profile save failed: $e');
      safeShowSnackBar(
        'Failed to save profile: $e',
        backgroundColor: Colors.red,
      );
    } finally {
      safeSetState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final accentColor = context.accentColor;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: context.background,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                // Drag pill
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: context.textTertiary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: context.border.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel'),
                      ),
                      Expanded(
                        child: Text(
                          'Edit Profile',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      FilledButton(
                        onPressed: _hasChanges && !_isLoading
                            ? _saveProfile
                            : null,
                        child: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save'),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    behavior: HitTestBehavior.opaque,
                    child: SingleChildScrollView(
                      controller: scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        16,
                        16,
                        16,
                        16 + MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Banner + Avatar header
                            SizedBox(
                              height: 180,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // Banner
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: _isUploadingBanner
                                          ? null
                                          : _pickBanner,
                                      child: Container(
                                        height: 120,
                                        decoration: BoxDecoration(
                                          color: context.card,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              if (_isUploadingBanner)
                                                Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: accentColor,
                                                      ),
                                                )
                                              else if (profile?.bannerUrl !=
                                                  null)
                                                profile!.bannerUrl!.startsWith(
                                                      'http',
                                                    )
                                                    ? Image.network(
                                                        profile.bannerUrl!,
                                                        fit: BoxFit.cover,
                                                        loadingBuilder:
                                                            (
                                                              context,
                                                              child,
                                                              loadingProgress,
                                                            ) {
                                                              if (loadingProgress ==
                                                                  null) {
                                                                return child;
                                                              }
                                                              return Center(
                                                                child: CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2,
                                                                  color:
                                                                      accentColor,
                                                                ),
                                                              );
                                                            },
                                                        errorBuilder:
                                                            (
                                                              ctx,
                                                              err,
                                                              stack,
                                                            ) => DefaultBanner(
                                                              accentColor:
                                                                  accentColor,
                                                            ),
                                                      )
                                                    : Image.file(
                                                        File(
                                                          profile.bannerUrl!,
                                                        ),
                                                        fit: BoxFit.cover,
                                                      )
                                              else
                                                DefaultBanner(
                                                  accentColor: accentColor,
                                                ),
                                              // Camera button overlay
                                              Positioned(
                                                right: 8,
                                                bottom: 8,
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.6),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.camera_alt,
                                                    size: 18,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Avatar overlapping banner
                                  Positioned(
                                    left: 16,
                                    bottom: 0,
                                    child: GestureDetector(
                                      onTap: _isUploadingAvatar
                                          ? null
                                          : _pickAvatar,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: context.background,
                                            width: 4,
                                          ),
                                        ),
                                        child: Stack(
                                          children: [
                                            _isUploadingAvatar
                                                ? Container(
                                                    width: 100,
                                                    height: 100,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: context.card,
                                                      border: Border.all(
                                                        color: accentColor,
                                                        width: 2,
                                                      ),
                                                    ),
                                                    child: Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: accentColor,
                                                          ),
                                                    ),
                                                  )
                                                : UserAvatar(
                                                    imageUrl:
                                                        profile?.avatarUrl,
                                                    initials: profile?.initials,
                                                    size: 100,
                                                    borderWidth: 2,
                                                    borderColor: accentColor,
                                                    foregroundColor:
                                                        accentColor,
                                                    backgroundColor:
                                                        context.card,
                                                  ),
                                            Positioned(
                                              right: 0,
                                              bottom: 0,
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: accentColor,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: context.background,
                                                    width: 2,
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.camera_alt,
                                                  size: 16,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Remove buttons row
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Row(
                                children: [
                                  if (profile?.avatarUrl != null &&
                                      !_isRemovingAvatar)
                                    TextButton(
                                      onPressed:
                                          _isUploadingAvatar ||
                                              _isRemovingAvatar
                                          ? null
                                          : _removeAvatar,
                                      child: Text(
                                        'Remove Avatar',
                                        style: TextStyle(
                                          color: _isUploadingAvatar
                                              ? AppTheme.errorRed.withValues(
                                                  alpha: 0.4,
                                                )
                                              : AppTheme.errorRed,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  const Spacer(),
                                  if (profile?.bannerUrl != null &&
                                      !_isRemovingBanner)
                                    TextButton(
                                      onPressed:
                                          _isUploadingBanner ||
                                              _isRemovingBanner
                                          ? null
                                          : _removeBanner,
                                      child: Text(
                                        'Remove Banner',
                                        style: TextStyle(
                                          color: _isUploadingBanner
                                              ? AppTheme.errorRed.withValues(
                                                  alpha: 0.4,
                                                )
                                              : AppTheme.errorRed,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Basic Info section
                            _buildSectionHeader('Basic Info'),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _displayNameController,
                              label: 'Display Name',
                              hint: 'How you want to be known',
                              icon: Icons.person_outline,
                              maxLength: 50,
                              validator: (value) {
                                final currentUser = ref.read(
                                  currentUserProvider,
                                );
                                return validateDisplayName(
                                  value ?? '',
                                  userId: currentUser?.uid,
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _callsignController,
                              label: 'Callsign',
                              hint: 'Amateur radio callsign or identifier',
                              icon: Icons.badge_outlined,
                              textCapitalization: TextCapitalization.characters,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return null; // Callsign is optional
                                }
                                if (value.trim().length > 10) {
                                  return 'Max 10 characters';
                                }
                                // Use proper profanity checker
                                final error = ProfanityChecker.instance.check(
                                  value.trim(),
                                );
                                if (error != null) {
                                  return 'Callsign cannot contain inappropriate content';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            // Bio field - no prefix icon for multiline
                            _buildBioField(),
                            const SizedBox(height: 24),

                            // Links section
                            _buildSectionHeader('Links'),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _websiteController,
                              label: 'Website',
                              hint: 'https://example.com',
                              icon: Icons.link,
                              keyboardType: TextInputType.url,
                              maxLength: 100,
                              validator: (value) {
                                if (value == null || value.isEmpty) return null;
                                final url = value.trim().toLowerCase();
                                if (!url.startsWith('http://') &&
                                    !url.startsWith('https://')) {
                                  return 'URL must start with http:// or https://';
                                }
                                final urlPattern = RegExp(
                                  r'^https?:\/\/[a-zA-Z0-9][a-zA-Z0-9-]*(\.[a-zA-Z0-9][a-zA-Z0-9-]*)+([\/\?#].*)?$',
                                );
                                if (!urlPattern.hasMatch(url)) {
                                  return 'Please enter a valid URL';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // Social links section
                            _buildSectionHeader('Social'),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _twitterController,
                              label: 'Twitter / X',
                              hint: 'username',
                              icon: Icons.alternate_email,
                              prefixText: '@',
                              maxLength: 30,
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _mastodonController,
                              label: 'Mastodon',
                              hint: '@user@instance.social',
                              icon: Icons.tag,
                              maxLength: 100,
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _githubController,
                              label: 'GitHub',
                              hint: 'username',
                              icon: Icons.code,
                              maxLength: 39,
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _discordController,
                              label: 'Discord',
                              hint: 'username#0000',
                              icon: Icons.discord,
                              maxLength: 37,
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _telegramController,
                              label: 'Telegram',
                              hint: 'username',
                              icon: Icons.send,
                              maxLength: 32,
                            ),
                            SizedBox(
                              height:
                                  MediaQuery.of(context).padding.bottom + 32,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: context.accentColor,
        letterSpacing: 1,
      ),
    );
  }

  /// Build bio field with decorative quote icon outside the input
  Widget _buildBioField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.format_quote, size: 18, color: context.textTertiary),
            SizedBox(width: 8),
            Text(
              'Bio',
              style: context.bodySmallStyle?.copyWith(
                color: context.textTertiary,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: _bioController,
          focusNode: _bioFocusNode,
          decoration: InputDecoration(
            hintText: 'Tell us about yourself',
            filled: true,
            fillColor: context.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: context.border.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: context.border.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.accentColor),
            ),
          ),
          maxLines: 3,
          maxLength: 200,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? prefixText,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon, color: context.textTertiary),
            prefixText: prefixText,
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      size: 18,
                      color: context.textTertiary,
                    ),
                    onPressed: () {
                      controller.clear();
                    },
                  )
                : null,
            filled: true,
            fillColor: context.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: context.border.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: context.border.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.accentColor),
            ),
            counterText: maxLength != null ? null : '',
          ),
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          validator: validator,
          inputFormatters: textCapitalization == TextCapitalization.characters
              ? [UpperCaseTextFormatter()]
              : null,
        );
      },
    );
  }
}

/// Text formatter for uppercase input
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
