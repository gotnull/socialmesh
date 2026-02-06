// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/content_moderation_warning.dart';
import '../../../core/widgets/edge_fade.dart';
import '../../../core/widgets/gradient_border_container.dart';
import '../../../core/widgets/node_selector_sheet.dart';
import '../../../models/social.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/social_providers.dart';
import '../../../utils/snackbar.dart';

/// Screen for creating a new post.
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen>
    with LifecycleSafeMixin<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _contentFocusNode = FocusNode();

  static const int _maxImages = 10;
  bool _isSubmitting = false;
  bool _postSubmitted = false;
  PostVisibility _visibility = PostVisibility.public;
  PostLocation? _location;
  String? _nodeId;
  final List<String> _imageUrls = [];
  final Set<String> _failedImageUrls = {};

  @override
  void initState() {
    super.initState();
    // Focus content input when screen opens
    safePostFrame(() {
      _contentFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    _contentFocusNode.dispose();
    // Clean up uploaded images if post was not submitted
    if (!_postSubmitted && _imageUrls.isNotEmpty) {
      _deleteOrphanedImages();
    }
    super.dispose();
  }

  /// Deletes uploaded images that were not used in a post
  Future<void> _deleteOrphanedImages() async {
    for (final url in _imageUrls) {
      try {
        final ref = FirebaseStorage.instance.refFromURL(url);
        await ref.delete();
        AppLogging.social('Deleted orphaned image: $url');
      } catch (e) {
        AppLogging.social('Failed to delete orphaned image: $e');
      }
    }
  }

  bool get _canPost =>
      _contentController.text.trim().isNotEmpty || _imageUrls.isNotEmpty;

  Future<void> _handleClose() async {
    // If there are uploaded images or content, confirm before closing
    if (_imageUrls.isNotEmpty || _contentController.text.trim().isNotEmpty) {
      final shouldDiscard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.card,
          title: Text(
            'Discard post?',
            style: TextStyle(color: context.textPrimary),
          ),
          content: Text(
            _imageUrls.isNotEmpty
                ? 'Your uploaded images will be deleted.'
                : 'Your draft will be lost.',
            style: TextStyle(color: context.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Keep editing',
                style: TextStyle(color: context.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Discard'),
            ),
          ],
        ),
      );

      if (shouldDiscard != true) return;
    }

    safeNavigatorPop();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(
      publicProfileStreamProvider(currentUser?.uid ?? ''),
    );
    final profile = profileAsync.value;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: context.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(
            'Create Post',
            style: TextStyle(color: context.textPrimary),
          ),
        ),
        body: Center(
          child: Text(
            'Sign in to create posts',
            style: TextStyle(color: context.textSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: _isSubmitting ? context.textTertiary : context.textPrimary,
          ),
          onPressed: _isSubmitting ? null : _handleClose,
        ),
        title: Text(
          'Create Post',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: BouncyTap(
              onTap: _canPost && !_isSubmitting ? _submitPost : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: _canPost && !_isSubmitting
                      ? AppTheme.brandGradientHorizontal
                      : null,
                  color: _canPost && !_isSubmitting
                      ? null
                      : context.border.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _isSubmitting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Post',
                        style: TextStyle(
                          color: _canPost ? Colors.white : context.textTertiary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User info row
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: context.accentColor.withValues(
                            alpha: 0.2,
                          ),
                          backgroundImage: profile?.avatarUrl != null
                              ? NetworkImage(profile!.avatarUrl!)
                              : null,
                          child: profile?.avatarUrl == null
                              ? Text(
                                  (profile?.displayName ?? 'U')[0]
                                      .toUpperCase(),
                                  style: TextStyle(
                                    color: context.accentColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile?.displayName ?? 'Anonymous',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              _buildVisibilityChip(),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Content input
                    TextField(
                      controller: _contentController,
                      focusNode: _contentFocusNode,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 16,
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        hintText: 'What\'s happening on the mesh?',
                        hintStyle: TextStyle(
                          color: context.textTertiary,
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      minLines: 6,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                    ),

                    // Image previews
                    if (_imageUrls.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildImagePreviews(),
                    ],

                    // Tags section
                    if (_location != null || _nodeId != null) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_location != null) _buildLocationTag(),
                          if (_nodeId != null) _buildNodeTag(),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom toolbar
            Container(
              decoration: BoxDecoration(
                color: context.card,
                border: Border(
                  top: BorderSide(color: context.border.withValues(alpha: 0.3)),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      _buildToolbarButton(
                        icon: Icons.image_outlined,
                        isActive: _imageUrls.isNotEmpty,
                        onTap: _isSubmitting || _imageUrls.length >= _maxImages
                            ? null
                            : () => _addImage(),
                        tooltip: _imageUrls.isEmpty
                            ? 'Add image'
                            : '${_imageUrls.length}/$_maxImages images',
                      ),
                      const SizedBox(width: 4),
                      _buildToolbarButton(
                        icon: Icons.location_on_outlined,
                        isActive: _location != null,
                        onTap: _isSubmitting ? null : _addLocation,
                        tooltip: 'Add location',
                      ),
                      const SizedBox(width: 4),
                      _buildToolbarButton(
                        icon: Icons.router_outlined,
                        isActive: _nodeId != null,
                        onTap: _isSubmitting ? null : _tagNode,
                        tooltip: 'Tag node',
                      ),
                      const Spacer(),
                      // Character count
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_contentController.text.length}',
                          style: TextStyle(
                            color: context.textTertiary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
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
    );
  }

  Widget _buildVisibilityChip() {
    final IconData icon;
    final String label;

    switch (_visibility) {
      case PostVisibility.public:
        icon = Icons.public;
        label = 'Public';
      case PostVisibility.followersOnly:
        icon = Icons.people;
        label = 'Followers';
      case PostVisibility.private:
        icon = Icons.lock;
        label = 'Only me';
    }

    return BouncyTap(
      onTap: _isSubmitting ? null : _showVisibilityPicker,
      child: Opacity(
        opacity: _isSubmitting ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: context.accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: context.accentColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: context.accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: context.accentColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVisibilityPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Who can see this?',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _buildVisibilityOption(
              ctx,
              PostVisibility.public,
              Icons.public,
              'Public',
              'Anyone can see this post',
            ),
            _buildVisibilityOption(
              ctx,
              PostVisibility.followersOnly,
              Icons.people,
              'Followers',
              'Only your followers can see this',
            ),
            _buildVisibilityOption(
              ctx,
              PostVisibility.private,
              Icons.lock,
              'Only me',
              'Only you can see this post',
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilityOption(
    BuildContext ctx,
    PostVisibility visibility,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final isSelected = _visibility == visibility;

    return BouncyTap(
      onTap: () {
        setState(() => _visibility = visibility);
        Navigator.pop(ctx);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? context.accentColor.withValues(alpha: 0.1)
              : context.background,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: context.accentColor.withValues(alpha: 0.5))
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? context.accentColor.withValues(alpha: 0.2)
                    : context.border.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? context.accentColor : context.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: context.textTertiary, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: context.accentColor, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required bool isActive,
    VoidCallback? onTap,
    required String tooltip,
  }) {
    final isDisabled = onTap == null;
    return Tooltip(
      message: tooltip,
      child: BouncyTap(
        onTap: onTap,
        child: Opacity(
          opacity: isDisabled ? 0.5 : 1.0,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive
                  ? context.accentColor.withValues(alpha: 0.15)
                  : context.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 22,
              color: isActive ? context.accentColor : context.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreviews() {
    return SizedBox(
      height: 120,
      child: EdgeFade.end(
        fadeSize: 16,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _imageUrls.length,
          itemBuilder: (context, index) {
            final imageUrl = _imageUrls[index];
            return Padding(
              padding: EdgeInsets.only(
                right: index < _imageUrls.length - 1 ? 8 : 0,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.border.withValues(alpha: 0.3),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: context.card,
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          final scaffoldContext = this.context;
                          final shouldHandle = _failedImageUrls.add(imageUrl);
                          if (shouldHandle) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) return;
                              final removalIndex = _imageUrls.indexOf(imageUrl);
                              if (removalIndex != -1) {
                                setState(() {
                                  _imageUrls.removeAt(removalIndex);
                                  _failedImageUrls.remove(imageUrl);
                                });
                                showErrorSnackBar(
                                  scaffoldContext,
                                  'Image was blocked or removed. Please pick another photo.',
                                );
                              }
                            });
                          }

                          return Container(
                            width: 120,
                            height: 120,
                            color: context.card,
                            child: const Center(
                              child: Icon(Icons.broken_image),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: BouncyTap(
                      onTap: () {
                        setState(() {
                          _failedImageUrls.remove(imageUrl);
                          _imageUrls.removeAt(index);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
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
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLocationTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.successGreen.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, size: 16, color: AppTheme.successGreen),
          const SizedBox(width: 6),
          Text(
            _location!.name ?? 'Location',
            style: TextStyle(
              color: AppTheme.successGreen,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          BouncyTap(
            onTap: () => setState(() => _location = null),
            child: Icon(Icons.close, size: 16, color: AppTheme.successGreen),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeTag() {
    return GradientBorderContainer(
      borderRadius: 20,
      borderWidth: 2,
      accentColor: AccentColors.cyan,
      accentOpacity: 0.3,
      backgroundColor: AccentColors.cyan.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.router, size: 16, color: AccentColors.cyan),
          const SizedBox(width: 6),
          Text(
            'Node $_nodeId',
            style: TextStyle(
              color: AccentColors.cyan,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          BouncyTap(
            onTap: () => setState(() => _nodeId = null),
            child: Icon(Icons.close, size: 16, color: AccentColors.cyan),
          ),
        ],
      ),
    );
  }

  Future<void> _addImage() async {
    if (_imageUrls.length >= _maxImages) {
      showErrorSnackBar(context, 'Maximum $_maxImages images allowed');
      return;
    }

    // Get current user for metadata
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      showSignInRequiredSnackBar(context, 'Sign in to upload images');
      return;
    }

    try {
      final remainingSlots = _maxImages - _imageUrls.length;

      // Only allow multiple selection if more than 1 slot remains
      // This prevents selecting more than available slots
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: remainingSlots > 1,
      );

      if (result == null || result.files.isEmpty || !mounted) return;

      // Take only up to remaining slots (safety check)
      final filesToUpload = result.files.take(remainingSlots).toList();

      safeSetState(() => _isSubmitting = true);

      for (final file in filesToUpload) {
        if (file.path == null) {
          AppLogging.social('[CreatePost] Skipping file with null path');
          continue;
        }

        AppLogging.social('[CreatePost] Uploading image: ${file.name}');
        final imageFile = File(file.path!);
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        final ref = FirebaseStorage.instance
            .ref()
            .child('post_images')
            .child(fileName);

        // Add metadata with authorId for content moderation
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'authorId': currentUser.uid,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        );

        AppLogging.social('[CreatePost] Uploading to: post_images/$fileName');
        await ref.putFile(imageFile, metadata);

        // Small delay to allow moderation trigger to process
        await Future.delayed(const Duration(milliseconds: 500));

        // Try to get download URL - if file was moderated, it won't exist
        try {
          final url = await ref.getDownloadURL();
          AppLogging.social('[CreatePost] Upload complete, URL: $url');
          safeSetState(() => _imageUrls.add(url));
        } on FirebaseException catch (e) {
          if (e.code == 'object-not-found') {
            // Image was deleted by content moderation
            AppLogging.social(
              '[CreatePost] Image blocked by content moderation',
            );
            if (!mounted) return;
            showErrorSnackBar(
              context,
              'Image violates content guidelines and was blocked.',
            );
            return;
          }
          rethrow;
        }
      }
    } catch (e, stackTrace) {
      AppLogging.social('[CreatePost] Image upload error: $e');
      AppLogging.social('[CreatePost] Stack trace: $stackTrace');
      if (!mounted) return;
      // Check for object-not-found which indicates moderation
      final errorStr = e.toString();
      if (errorStr.contains('object-not-found')) {
        showErrorSnackBar(
          context,
          'Image violates content guidelines and was blocked.',
        );
      } else {
        showErrorSnackBar(context, 'Failed to upload image: $e');
      }
    } finally {
      safeSetState(() => _isSubmitting = false);
    }
  }

  Future<void> _addLocation() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Add Location',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            BouncyTap(
              onTap: () async {
                Navigator.pop(ctx);
                await _useCurrentLocation();
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.my_location,
                        size: 20,
                        color: AppTheme.successGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Use Current Location',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'Share your GPS coordinates',
                            style: TextStyle(
                              color: context.textTertiary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: context.textTertiary),
                  ],
                ),
              ),
            ),
            BouncyTap(
              onTap: () {
                Navigator.pop(ctx);
                _enterLocationManually();
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AccentColors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.edit_location_alt,
                        size: 20,
                        color: AccentColors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enter Location Manually',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'Type in a place name',
                            style: TextStyle(
                              color: context.textTertiary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: context.textTertiary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _useCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          if (!mounted) return;
          showWarningSnackBar(context, 'Location permission denied');
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      String locationName = 'Current Location';

      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          locationName = [
            place.locality,
            place.administrativeArea,
            place.country,
          ].where((s) => s != null && s.isNotEmpty).join(', ');
        }
      } catch (_) {}

      safeSetState(() {
        _location = PostLocation(
          name: locationName,
          latitude: position.latitude,
          longitude: position.longitude,
        );
      });
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Failed to get location: $e');
    }
  }

  void _enterLocationManually() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Enter Location',
          style: TextStyle(color: context.textPrimary),
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(color: context.textPrimary),
          decoration: InputDecoration(
            hintText: 'e.g., San Francisco, CA',
            hintStyle: TextStyle(color: context.textTertiary),
            filled: true,
            fillColor: context.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.accentColor, width: 2),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  _location = PostLocation(
                    name: name,
                    latitude: 0,
                    longitude: 0,
                  );
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _tagNode() async {
    final nodes = ref.read(nodesProvider);

    if (nodes.isEmpty) {
      showInfoSnackBar(context, 'No nodes available. Connect to a mesh first.');
      return;
    }

    final selection = await NodeSelectorSheet.show(
      context,
      title: 'Tag a Node',
      allowBroadcast: false,
    );

    if (!mounted) return;
    if (selection != null && selection.nodeNum != null) {
      safeSetState(
        () => _nodeId = selection.nodeNum!.toRadixString(16).toUpperCase(),
      );
    }
  }

  Future<void> _submitPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty && _imageUrls.isEmpty) return;

    // Prevent double-tap by setting loading state immediately
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    // Dismiss keyboard immediately using multiple methods for reliability
    _contentFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    // Pre-submission content moderation check
    if (content.isNotEmpty) {
      final moderationService = ref.read(contentModerationServiceProvider);
      final checkResult = await moderationService.checkText(
        content,
        useServerCheck: true,
      );

      if (!checkResult.passed || checkResult.action == 'reject') {
        // Content blocked - show warning and don't proceed
        if (!mounted) return;
        final action = await ContentModerationWarning.show(
          context,
          result: ContentModerationCheckResult(
            passed: false,
            action: 'reject',
            categories: checkResult.categories.map((c) => c.name).toList(),
            details: checkResult.details,
          ),
        );
        if (!mounted) return;
        safeSetState(() => _isSubmitting = false);
        if (action == ContentModerationAction.edit) {
          // User wants to edit - focus on content field
          safePostFrame(() {
            _contentFocusNode.requestFocus();
          });
        }
        return;
      } else if (checkResult.action == 'review' ||
          checkResult.action == 'flag') {
        // Content flagged - show warning but allow to proceed
        if (!mounted) return;
        final action = await ContentModerationWarning.show(
          context,
          result: ContentModerationCheckResult(
            passed: true,
            action: checkResult.action,
            categories: checkResult.categories.map((c) => c.name).toList(),
            details: checkResult.details,
          ),
        );
        if (!mounted) return;
        if (action == ContentModerationAction.cancel) {
          safeSetState(() => _isSubmitting = false);
          return;
        }
        if (action == ContentModerationAction.edit) {
          // User wants to edit - focus on content field
          safeSetState(() => _isSubmitting = false);
          safePostFrame(() {
            _contentFocusNode.requestFocus();
          });
          return;
        }
        // If action is proceed, continue with submission
      }
    }

    try {
      // CRITICAL: Validate images with Cloud Function (synchronous check)
      if (_imageUrls.isNotEmpty) {
        AppLogging.social(
          '[CreatePost] Validating ${_imageUrls.length} images with Cloud Function',
        );
        try {
          final functions = FirebaseFunctions.instance;
          final result = await functions.httpsCallable('validateImages').call({
            'imageUrls': _imageUrls,
          });
          AppLogging.social(
            '[CreatePost] validateImages response: ${result.data}',
          );

          final validationResult = result.data as Map<String, dynamic>;
          if (validationResult['passed'] == false) {
            AppLogging.social(
              '[CreatePost] Image validation failed: ${validationResult['message']}',
            );
            if (!mounted) return;
            safeSetState(() => _isSubmitting = false);
            showErrorSnackBar(
              context,
              validationResult['message'] ?? 'Image validation failed',
            );
            return;
          }
          AppLogging.social('[CreatePost] All images passed validation');
        } catch (e, stackTrace) {
          AppLogging.social('[CreatePost] validateImages error: $e');
          AppLogging.social('[CreatePost] Stack trace: $stackTrace');
          // If validation fails, check if images still exist
          final validUrls = <String>[];
          for (final url in _imageUrls) {
            try {
              final ref = FirebaseStorage.instance.refFromURL(url);
              await ref.getMetadata();
              validUrls.add(url);
            } catch (e) {
              AppLogging.social('[CreatePost] Image was removed: $url');
            }
          }

          if (validUrls.length != _imageUrls.length) {
            AppLogging.social(
              '[CreatePost] ${_imageUrls.length - validUrls.length} images were removed',
            );
            if (!mounted) return;
            safeSetState(() => _isSubmitting = false);
            showErrorSnackBar(
              context,
              'One or more images violated content policy.',
            );
            return;
          }
        }
      }

      if (!mounted) return;
      // Use createPostProvider to get optimistic post count updates
      final post = await ref
          .read(createPostProvider.notifier)
          .createPost(
            content: content,
            mediaUrls: _imageUrls,
            location: _location,
            nodeId: _nodeId,
          );

      if (!mounted) return;
      if (post != null) {
        // Mark as submitted so images don't get deleted on dispose
        _postSubmitted = true;

        // Refresh feed and explore providers
        ref.read(feedProvider.notifier).refresh();
        ref.read(exploreProvider.notifier).refresh();

        // Refresh user posts for when profile is viewed
        // DON'T invalidate publicProfileStreamProvider here - let optimistic update show
        // Profile screen's initState will reset adjustment and fetch fresh data
        final currentUser = ref.read(currentUserProvider);
        if (currentUser != null) {
          ref.read(userPostsNotifierProvider.notifier).refresh(currentUser.uid);
        }

        Navigator.pop(context);
        showSuccessSnackBar(context, 'Post created!');
      } else {
        final createState = ref.read(createPostProvider);
        throw Exception(createState.error ?? 'Failed to create post');
      }
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Failed to create post: $e');
      safeSetState(() => _isSubmitting = false);
    }
  }
}
