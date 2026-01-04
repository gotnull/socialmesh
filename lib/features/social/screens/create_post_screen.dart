import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

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

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _contentFocusNode = FocusNode();

  bool _isSubmitting = false;
  PostVisibility _visibility = PostVisibility.public;
  PostLocation? _location;
  String? _nodeId;
  final List<String> _imageUrls = [];

  @override
  void initState() {
    super.initState();
    // Focus content input when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  bool get _canPost =>
      _contentController.text.trim().isNotEmpty || _imageUrls.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create Post')),
        body: const Center(child: Text('Sign in to create posts')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          TextButton(
            onPressed: _canPost && !_isSubmitting ? _submitPost : null,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Post',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _canPost
                          ? theme.colorScheme.primary
                          : theme.disabledColor,
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
                    // Content input
                    TextField(
                      controller: _contentController,
                      focusNode: _contentFocusNode,
                      decoration: const InputDecoration(
                        hintText: 'What\'s happening on the mesh?',
                        border: InputBorder.none,
                      ),
                      maxLines: null,
                      minLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                    ),

                    // Image previews
                    if (_imageUrls.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildImagePreviews(),
                    ],

                    // Location tag
                    if (_location != null) ...[
                      const SizedBox(height: 16),
                      _buildLocationTag(),
                    ],

                    // Node tag
                    if (_nodeId != null) ...[
                      const SizedBox(height: 16),
                      _buildNodeTag(),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom toolbar
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Visibility selector
                    _buildVisibilitySelector(theme),

                    const Divider(height: 1),

                    // Action buttons
                    _buildActionButtons(theme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreviews() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _imageUrls.length,
        itemBuilder: (context, index) {
          return Padding(
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
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _imageUrls.removeAt(index);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
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
    );
  }

  Widget _buildLocationTag() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withAlpha(50),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            _location!.name ?? 'Location',
            style: TextStyle(color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _location = null),
            child: Icon(
              Icons.close,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeTag() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withAlpha(50),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.router, size: 16, color: theme.colorScheme.secondary),
          const SizedBox(width: 4),
          Text(
            'Node $_nodeId',
            style: TextStyle(color: theme.colorScheme.secondary),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _nodeId = null),
            child: Icon(
              Icons.close,
              size: 16,
              color: theme.colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilitySelector(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            _visibility == PostVisibility.public
                ? Icons.public
                : _visibility == PostVisibility.followersOnly
                ? Icons.people
                : Icons.lock,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          DropdownButton<PostVisibility>(
            value: _visibility,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(
                value: PostVisibility.public,
                child: Text('Public'),
              ),
              DropdownMenuItem(
                value: PostVisibility.followersOnly,
                child: Text('Followers only'),
              ),
              DropdownMenuItem(
                value: PostVisibility.private,
                child: Text('Only me'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _visibility = value);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Add image
          IconButton(
            icon: Icon(Icons.image_outlined, color: theme.colorScheme.primary),
            onPressed: _addImage,
            tooltip: 'Add image',
          ),

          // Add location
          IconButton(
            icon: Icon(
              Icons.location_on_outlined,
              color: _location != null
                  ? theme.colorScheme.primary
                  : theme.iconTheme.color,
            ),
            onPressed: _addLocation,
            tooltip: 'Add location',
          ),

          // Tag node
          IconButton(
            icon: Icon(
              Icons.router_outlined,
              color: _nodeId != null
                  ? theme.colorScheme.secondary
                  : theme.iconTheme.color,
            ),
            onPressed: _tagNode,
            tooltip: 'Tag node',
          ),

          const Spacer(),

          // Character count (optional)
          Text(
            '${_contentController.text.length}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withAlpha(100),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() => _isSubmitting = true);

      for (final file in result.files) {
        if (file.path == null) continue;

        final imageFile = File(file.path!);
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        final ref = FirebaseStorage.instance
            .ref()
            .child('post_images')
            .child(fileName);

        await ref.putFile(imageFile);
        final url = await ref.getDownloadURL();

        setState(() => _imageUrls.add(url));
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to upload image: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _addLocation() async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.my_location),
              title: const Text('Use Current Location'),
              onTap: () async {
                Navigator.pop(ctx);
                await _useCurrentLocation();
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_location),
              title: const Text('Enter Location Manually'),
              onTap: () {
                Navigator.pop(ctx);
                _enterLocationManually();
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(ctx),
            ),
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
          if (mounted) {
            showWarningSnackBar(context, 'Location permission denied');
          }
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition();
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

      setState(() {
        _location = PostLocation(
          name: locationName,
          latitude: position.latitude,
          longitude: position.longitude,
        );
      });
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to get location: $e');
      }
    }
  }

  void _enterLocationManually() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Location'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'e.g., San Francisco, CA',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
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

  void _tagNode() {
    final nodes = ref.read(nodesProvider);

    if (nodes.isEmpty) {
      showInfoSnackBar(context, 'No nodes available. Connect to a mesh first.');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Tag a Node',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: nodes.length,
                itemBuilder: (context, index) {
                  final node = nodes.values.elementAt(index);
                  final nodeNum = node.nodeNum.toRadixString(16).toUpperCase();
                  final longName = node.longName ?? '';
                  final shortName = node.shortName ?? '';
                  return ListTile(
                    leading: const Icon(Icons.router),
                    title: Text(longName.isNotEmpty ? longName : '!$nodeNum'),
                    subtitle: Text(shortName.isNotEmpty ? shortName : nodeNum),
                    onTap: () {
                      setState(() => _nodeId = nodeNum);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty && _imageUrls.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      // Use createPostProvider to get optimistic post count updates
      final post = await ref
          .read(createPostProvider.notifier)
          .createPost(
            content: content,
            mediaUrls: _imageUrls,
            location: _location,
            nodeId: _nodeId,
          );

      if (post != null && mounted) {
        // Refresh feed and explore providers
        ref.read(feedProvider.notifier).refresh();
        ref.read(exploreProvider.notifier).refresh();

        // Invalidate user posts stream for when profile is viewed
        // DON'T invalidate publicProfileStreamProvider here - let optimistic update show
        // Profile screen's initState will reset adjustment and fetch fresh data
        final currentUser = ref.read(currentUserProvider);
        if (currentUser != null) {
          ref.invalidate(userPostsStreamProvider(currentUser.uid));
        }

        Navigator.pop(context);
        showSuccessSnackBar(context, 'Post created!');
      } else if (mounted) {
        final createState = ref.read(createPostProvider);
        throw Exception(createState.error ?? 'Failed to create post');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to create post: $e');
        setState(() => _isSubmitting = false);
      }
    }
  }
}
