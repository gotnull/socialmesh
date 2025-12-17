import 'dart:io';

import 'package:file_picker/file_picker.dart';
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
import '../settings/account_screen.dart';

/// Screen for viewing and editing user profile
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
                isSignedIn: authState.value != null,
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
  final bool isSignedIn;
  final VoidCallback onEditTap;

  const _ProfileView({
    required this.profile,
    required this.isSignedIn,
    required this.onEditTap,
  });

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
          const SizedBox(height: 8),

          // Sync status
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSignedIn ? Icons.cloud_done : Icons.cloud_off,
                size: 16,
                color: isSignedIn ? AccentColors.green : AppTheme.textTertiary,
              ),
              const SizedBox(width: 6),
              Text(
                isSignedIn ? 'Synced to cloud' : 'Local only',
                style: TextStyle(
                  fontSize: 12,
                  color: isSignedIn
                      ? AppTheme.textSecondary
                      : AppTheme.textTertiary,
                ),
              ),
            ],
          ),
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

          // Action buttons
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEditTap,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Profile'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AccountScreen()),
                  ),
                  icon: Icon(
                    isSignedIn ? Icons.cloud_sync : Icons.cloud_upload,
                  ),
                  label: Text(isSignedIn ? 'Cloud Sync' : 'Sign In'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
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
                              onPressed: _isUploadingAvatar ? null : _removeAvatar,
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
                                      style: TextStyle(color: AppTheme.errorRed),
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
