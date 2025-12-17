import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_providers.dart';
import '../../providers/profile_providers.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../utils/snackbar.dart';
import '../navigation/main_shell.dart';

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

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        leading: const HamburgerMenuButton(),
        centerTitle: true,
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            onPressed: () => _showEditSheet(context),
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) => profile != null
            ? _ProfileView(
                profile: profile,
                user: authState.value,
                onEditTap: () => _showEditSheet(context),
              )
            : const Center(child: Text('No profile found')),
        loading: () => const Center(child: MeshLoadingIndicator(size: 48)),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: context.accentColor),
              const SizedBox(height: 16),
              Text('Error loading profile: $e'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    ref.read(userProfileProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => const _EditProfileSheet(),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Avatar section
          _AvatarSection(profile: profile),
          const SizedBox(height: 24),

          // Display name and status
          Text(
            profile.displayName,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
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

          // Bio
          if (profile.bio != null && profile.bio!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.darkBorder.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                profile.bio!,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.textSecondary,
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
              _InfoItem(
                icon: Icons.badge_outlined,
                label: 'Profile ID',
                value: profile.id.length > 20
                    ? '${profile.id.substring(0, 20)}...'
                    : profile.id,
              ),
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
  bool _isSyncing = false;

  bool get isSignedIn => widget.user != null;

  @override
  void initState() {
    super.initState();
    // Start expanded if not signed in or if anonymous (to prompt action)
    _isExpanded = !isSignedIn || (widget.user?.isAnonymous ?? false);
  }

  String _getBackupStatusText() {
    if (!isSignedIn) {
      return 'Not backed up';
    }
    if (widget.user!.isAnonymous) {
      return 'Device only • Link email to sync';
    }
    return 'Synced • ${widget.user!.email}';
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = context.accentColor;
    final isAnonymous = widget.user?.isAnonymous ?? false;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSignedIn
              ? (isAnonymous
                    ? AccentColors.orange.withValues(alpha: 0.3)
                    : AccentColors.green.withValues(alpha: 0.3))
              : AppTheme.darkBorder.withValues(alpha: 0.3),
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
                      color:
                          (isSignedIn
                                  ? (isAnonymous
                                        ? AccentColors.orange
                                        : AccentColors.green)
                                  : accentColor)
                              .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isSignedIn
                          ? (isAnonymous
                                ? Icons.cloud_outlined
                                : Icons.cloud_done)
                          : Icons.cloud_off_outlined,
                      size: 20,
                      color: isSignedIn
                          ? (isAnonymous
                                ? AccentColors.orange
                                : AccentColors.green)
                          : accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cloud Backup',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getBackupStatusText(),
                          style: TextStyle(
                            fontSize: 12,
                            color: isSignedIn
                                ? (widget.user!.isAnonymous
                                      ? AccentColors.orange
                                      : AccentColors.green)
                                : AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppTheme.textTertiary,
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
          const Divider(color: AppTheme.darkBorder),
          const SizedBox(height: 12),
          const Text(
            'Sign in to backup your profile to the cloud and sync across devices.',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Google Sign-In button
          _SocialSignInButton(
            onPressed: () => _signInWithGoogle(context),
            icon: _GoogleLogo(),
            label: 'Continue with Google',
            backgroundColor: Colors.white,
            textColor: Colors.black87,
          ),
          const SizedBox(height: 10),

          // Apple Sign-In button (iOS/macOS only)
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

          // Divider with "or"
          const SizedBox(height: 6),
          Row(
            children: [
              const Expanded(child: Divider(color: AppTheme.darkBorder)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or',
                  style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                ),
              ),
              const Expanded(child: Divider(color: AppTheme.darkBorder)),
            ],
          ),
          const SizedBox(height: 16),

          // Email sign-in
          OutlinedButton.icon(
            onPressed: () => _showSignInDialog(context),
            icon: const Icon(Icons.email_outlined, size: 18),
            label: const Text('Sign in with Email'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => _showCreateAccountDialog(context),
              child: const Text(
                'Create account with email',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignedInContent(BuildContext context) {
    final user = widget.user!;
    final isAnonymous = user.isAnonymous;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(color: AppTheme.darkBorder),
          const SizedBox(height: 12),

          // Anonymous upgrade prompt
          if (isAnonymous) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AccentColors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AccentColors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AccentColors.orange,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Link an email to keep your data across devices.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AccentColors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _linkEmailAccount(context),
              icon: const Icon(Icons.link, size: 18),
              label: const Text('Link Email'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Sync button
          OutlinedButton.icon(
            onPressed: _isSyncing ? null : () => _syncNow(context),
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync, size: 18),
            label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),

          // Account management for non-anonymous
          if (!isAnonymous) ...[
            const SizedBox(height: 16),
            const Divider(color: AppTheme.darkBorder),
            const SizedBox(height: 8),
            _AccountOptionTile(
              icon: Icons.lock_outline,
              label: 'Change Password',
              onTap: () => _sendPasswordReset(context),
            ),
          ],

          // Sign out
          const SizedBox(height: 8),
          _AccountOptionTile(
            icon: Icons.logout,
            label: 'Sign Out',
            onTap: () => _signOut(context),
          ),

          // Delete account (non-anonymous only)
          if (!isAnonymous) ...[
            const SizedBox(height: 8),
            _AccountOptionTile(
              icon: Icons.delete_outline,
              label: 'Delete Account',
              isDestructive: true,
              onTap: () => _deleteAccount(context),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showSignInDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const _EmailSignInDialog(isCreateAccount: false),
    );
    if (result == true && context.mounted) {
      showSuccessSnackBar(context, 'Signed in successfully!');
    }
  }

  Future<void> _showCreateAccountDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const _EmailSignInDialog(isCreateAccount: true),
    );
    if (result == true && context.mounted) {
      showSuccessSnackBar(context, 'Account created successfully!');
    }
  }

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithGoogle();
      if (context.mounted) {
        showSuccessSnackBar(context, 'Signed in with Google');
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
    }
  }

  Future<void> _signInWithApple(BuildContext context) async {
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithApple();
      if (context.mounted) {
        showSuccessSnackBar(context, 'Signed in with Apple');
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Error: ${e.message}');
      }
    } catch (e) {
      if (context.mounted) {
        // User cancelled
        debugPrint('Apple sign in: $e');
      }
    }
  }

  Future<void> _linkEmailAccount(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) =>
          const _EmailSignInDialog(isCreateAccount: true, isLinking: true),
    );
    if (result == true && context.mounted) {
      showSuccessSnackBar(context, 'Email linked successfully!');
    }
  }

  Future<void> _syncNow(BuildContext context) async {
    final uid = widget.user?.uid;
    if (uid == null) return;

    setState(() => _isSyncing = true);
    try {
      await ref.read(userProfileProvider.notifier).fullSync(uid);
      if (context.mounted) {
        showSuccessSnackBar(context, 'Profile synced!');
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Sync failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _sendPasswordReset(BuildContext context) async {
    final email = widget.user?.email;
    if (email == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Reset Password'),
        content: Text('Send password reset email to $email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final authService = ref.read(authServiceProvider);
        await authService.sendPasswordResetEmail(email);
        if (context.mounted) {
          showSuccessSnackBar(context, 'Password reset email sent');
        }
      } on FirebaseAuthException catch (e) {
        if (context.mounted) {
          showErrorSnackBar(context, 'Error: ${e.message}');
        }
      }
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final isAnonymous = widget.user?.isAnonymous ?? false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Sign Out'),
        content: Text(
          isAnonymous
              ? 'As a guest, signing out will lose any unsaved work. Continue?'
              : 'Are you sure you want to sign out?',
        ),
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
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
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

    if (confirmed == true && context.mounted) {
      try {
        final authService = ref.read(authServiceProvider);
        await authService.deleteAccount();
        if (context.mounted) {
          showInfoSnackBar(context, 'Account deleted');
        }
      } on FirebaseAuthException catch (e) {
        if (context.mounted) {
          showErrorSnackBar(context, 'Error: ${e.message}');
        }
      }
    }
  }
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
    final color = isDestructive ? AppTheme.errorRed : AppTheme.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 14, color: color)),
            const Spacer(),
            Icon(Icons.chevron_right, size: 18, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// Social sign-in button with custom styling
class _SocialSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
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
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 12),
              Text(
                label,
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

class _AvatarSection extends StatelessWidget {
  final UserProfile profile;

  const _AvatarSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final accentColor = context.accentColor;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.3),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accentColor.withValues(alpha: 0.5),
                  accentColor.withValues(alpha: 0.2),
                ],
              ),
            ),
          ),
          // Avatar
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.darkCard,
              border: Border.all(color: accentColor, width: 3),
            ),
            child: ClipOval(child: _buildAvatarContent(context)),
          ),
          // Verified badge
          if (profile.isVerified)
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AccentColors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.darkBackground, width: 2),
                ),
                child: const Icon(Icons.check, size: 16, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarContent(BuildContext context) {
    if (profile.avatarUrl != null) {
      // Check if it's a local file or URL
      if (profile.avatarUrl!.startsWith('http')) {
        return Image.network(
          profile.avatarUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildInitials(context),
        );
      } else {
        return Image.file(
          File(profile.avatarUrl!),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildInitials(context),
        );
      }
    }
    return _buildInitials(context);
  }

  Widget _buildInitials(BuildContext context) {
    return Center(
      child: Text(
        profile.initials,
        style: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.bold,
          color: context.accentColor,
        ),
      ),
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
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder.withValues(alpha: 0.3)),
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
          const Divider(height: 1, color: AppTheme.darkBorder),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(item.icon, size: 20, color: AppTheme.textTertiary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.value,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });
}

// Edit Profile Sheet
class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet();

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  late TextEditingController _callsignController;
  late TextEditingController _websiteController;
  late TextEditingController _twitterController;
  late TextEditingController _mastodonController;
  late TextEditingController _githubController;
  late TextEditingController _discordController;
  late TextEditingController _telegramController;

  bool _isLoading = false;
  bool _isUploadingAvatar = false;
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
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() => _isUploadingAvatar = true);
      try {
        final file = File(result.files.first.path!);
        await ref.read(userProfileProvider.notifier).saveAvatarFromFile(file);
        if (mounted) {
          setState(() => _hasChanges = true);
          showSuccessSnackBar(context, 'Avatar updated');
        }
      } catch (e) {
        if (mounted) {
          showErrorSnackBar(context, 'Failed to upload avatar: $e');
        }
      } finally {
        if (mounted) {
          setState(() => _isUploadingAvatar = false);
        }
      }
    }
  }

  Future<void> _removeAvatar() async {
    setState(() => _isUploadingAvatar = true);
    try {
      await ref.read(userProfileProvider.notifier).deleteAvatar();
      if (mounted) {
        setState(() => _hasChanges = true);
        showSuccessSnackBar(context, 'Avatar removed');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to remove avatar: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
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

      await ref
          .read(userProfileProvider.notifier)
          .updateProfile(
            displayName: _displayNameController.text.trim(),
            bio: _bioController.text.isEmpty
                ? null
                : _bioController.text.trim(),
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

      // Force refresh to ensure UI updates
      ref.invalidate(userProfileProvider);

      if (mounted) {
        Navigator.pop(context);
        showSuccessSnackBar(context, 'Profile updated');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to save profile: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final accentColor = context.accentColor;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.darkBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                  color: AppTheme.textTertiary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppTheme.darkBorder.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const Expanded(
                      child: Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar edit
                        Center(
                          child: GestureDetector(
                            onTap: _isUploadingAvatar ? null : _pickAvatar,
                            child: Stack(
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.darkCard,
                                    border: Border.all(
                                      color: accentColor,
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: _isUploadingAvatar
                                        ? Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: accentColor,
                                            ),
                                          )
                                        : profile?.avatarUrl != null
                                        ? (profile!.avatarUrl!.startsWith(
                                                'http',
                                              )
                                              ? Image.network(
                                                  profile.avatarUrl!,
                                                  fit: BoxFit.cover,
                                                )
                                              : Image.file(
                                                  File(profile.avatarUrl!),
                                                  fit: BoxFit.cover,
                                                ))
                                        : Center(
                                            child: Text(
                                              profile?.initials ?? '?',
                                              style: TextStyle(
                                                fontSize: 32,
                                                fontWeight: FontWeight.bold,
                                                color: accentColor,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: accentColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppTheme.darkBackground,
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
                        if (profile?.avatarUrl != null) ...[
                          const SizedBox(height: 8),
                          Center(
                            child: TextButton(
                              onPressed: _isUploadingAvatar
                                  ? null
                                  : _removeAvatar,
                              child: _isUploadingAvatar
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.errorRed,
                                      ),
                                    )
                                  : const Text(
                                      'Remove Avatar',
                                      style: TextStyle(
                                        color: AppTheme.errorRed,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),

                        // Basic info section
                        _buildSectionHeader('Basic Info'),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _displayNameController,
                          label: 'Display Name',
                          hint: 'How you want to be known',
                          icon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Display name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _callsignController,
                          label: 'Callsign',
                          hint: 'Amateur radio callsign or identifier',
                          icon: Icons.badge_outlined,
                          textCapitalization: TextCapitalization.characters,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _bioController,
                          label: 'Bio',
                          hint: 'Tell us about yourself',
                          icon: Icons.format_quote,
                          maxLines: 3,
                          maxLength: 200,
                        ),
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
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _mastodonController,
                          label: 'Mastodon',
                          hint: '@user@instance.social',
                          icon: Icons.tag,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _githubController,
                          label: 'GitHub',
                          hint: 'username',
                          icon: Icons.code,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _discordController,
                          label: 'Discord',
                          hint: 'username#0000',
                          icon: Icons.discord,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _telegramController,
                          label: 'Telegram',
                          hint: 'username',
                          icon: Icons.send,
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.textTertiary),
        prefixText: prefixText,
        filled: true,
        fillColor: AppTheme.darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppTheme.darkBorder.withValues(alpha: 0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppTheme.darkBorder.withValues(alpha: 0.3),
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
  }
}

/// Email sign in dialog
class _EmailSignInDialog extends ConsumerStatefulWidget {
  final bool isCreateAccount;
  final bool isLinking;

  const _EmailSignInDialog({
    required this.isCreateAccount,
    this.isLinking = false,
  });

  @override
  ConsumerState<_EmailSignInDialog> createState() => _EmailSignInDialogState();
}

class _EmailSignInDialogState extends ConsumerState<_EmailSignInDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String title;
    if (widget.isLinking) {
      title = 'Link Email';
    } else if (widget.isCreateAccount) {
      title = 'Create Account';
    } else {
      title = 'Sign In';
    }

    return AlertDialog(
      backgroundColor: AppTheme.darkCard,
      title: Text(title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppTheme.errorRed),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'you@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  if (widget.isCreateAccount && value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              if (widget.isCreateAccount) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: Icon(Icons.lock_outlined),
                  ),
                  obscureText: _obscurePassword,
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
              if (!widget.isCreateAccount && !widget.isLinking) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _forgotPassword,
                    child: const Text('Forgot password?'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: MeshLoadingIndicator(size: 20),
                )
              : Text(widget.isCreateAccount ? 'Create' : 'Sign In'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (widget.isLinking) {
        // Link email to anonymous account
        final credential = EmailAuthProvider.credential(
          email: email,
          password: password,
        );
        await FirebaseAuth.instance.currentUser?.linkWithCredential(credential);
      } else if (widget.isCreateAccount) {
        await authService.createAccount(email: email, password: password);
      } else {
        await authService.signInWithEmail(email: email, password: password);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e.code);
        _isLoading = false;
      });
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage = 'Please enter your email address first';
      });
      return;
    }

    try {
      final authService = ref.read(authServiceProvider);
      await authService.sendPasswordResetEmail(email);
      if (mounted) {
        showSuccessSnackBar(context, 'Password reset email sent to $email');
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e.code);
      });
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-credential':
        return 'Invalid email or password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'weak-password':
        return 'Password is too weak';
      case 'invalid-email':
        return 'Invalid email address';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'credential-already-in-use':
        return 'This email is already linked to another account';
      default:
        return 'An error occurred: $code';
    }
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
