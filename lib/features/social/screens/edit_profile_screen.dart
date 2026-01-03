import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/social.dart';
import '../../../providers/social_providers.dart';

/// Screen for editing the current user's profile.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, required this.profile});

  final PublicProfile profile;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;
  late final TextEditingController _callsignController;

  bool _isSubmitting = false;
  bool _isUploadingAvatar = false;
  String? _newAvatarUrl;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.profile.displayName,
    );
    _bioController = TextEditingController(text: widget.profile.bio ?? '');
    _callsignController = TextEditingController(
      text: widget.profile.callsign ?? '',
    );
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _callsignController.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    return _displayNameController.text != widget.profile.displayName ||
        _bioController.text != (widget.profile.bio ?? '') ||
        _callsignController.text != (widget.profile.callsign ?? '') ||
        _newAvatarUrl != null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentAvatarUrl = _newAvatarUrl ?? widget.profile.avatarUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _hasChanges && !_isSubmitting ? _saveProfile : null,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar
            Stack(
              children: [
                GestureDetector(
                  onTap: _isUploadingAvatar ? null : _changeAvatar,
                  child: CircleAvatar(
                    radius: 56,
                    backgroundImage: currentAvatarUrl != null
                        ? NetworkImage(currentAvatarUrl)
                        : null,
                    child: currentAvatarUrl == null
                        ? Text(
                            widget.profile.displayName[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: _isUploadingAvatar
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            size: 20,
                            color: Colors.white,
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isUploadingAvatar ? null : _changeAvatar,
              child: Text(
                'Change Photo',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ),

            const SizedBox(height: 24),

            // Display Name
            TextField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                hintText: 'Your public display name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 16),

            // Callsign
            TextField(
              controller: _callsignController,
              decoration: const InputDecoration(
                labelText: 'Callsign (optional)',
                hintText: 'e.g., KD6-3.7',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 16),

            // Bio
            TextField(
              controller: _bioController,
              decoration: const InputDecoration(
                labelText: 'Bio (optional)',
                hintText: 'Tell others about yourself...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              maxLength: 150,
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 24),

            // Info text
            Text(
              'Your profile is visible to other Socialmesh users. Your display name and avatar appear on your posts and comments.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withAlpha(150),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) return;

      setState(() => _isUploadingAvatar = true);

      final socialService = ref.read(socialServiceProvider);
      final url = await socialService.uploadProfileAvatar(file.path!);

      setState(() {
        _newAvatarUrl = url;
        _isUploadingAvatar = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Avatar updated!')));
      }
    } catch (e) {
      setState(() => _isUploadingAvatar = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to upload avatar: $e')));
      }
    }
  }

  Future<void> _saveProfile() async {
    final displayName = _displayNameController.text.trim();
    if (displayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name cannot be empty')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final socialService = ref.read(socialServiceProvider);
      await socialService.updateProfile(
        displayName: displayName,
        bio: _bioController.text.trim(),
        callsign: _callsignController.text.trim().isEmpty
            ? null
            : _callsignController.text.trim(),
      );

      // Invalidate profile to refresh
      ref.invalidate(publicProfileProvider(widget.profile.id));

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
