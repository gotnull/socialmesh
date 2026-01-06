import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/node_selector_sheet.dart';
import '../../../models/social.dart';
import '../../../models/story.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/story_providers.dart';
import '../../../utils/snackbar.dart';

/// Screen for creating a new story with Instagram-style media picker.
class CreateStoryScreen extends ConsumerStatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  ConsumerState<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends ConsumerState<CreateStoryScreen> {
  // Media selection state
  List<AssetEntity> _recentAssets = [];
  AssetEntity? _selectedAsset;
  File? _selectedMedia;
  StoryMediaType _mediaType = StoryMediaType.image;
  bool _isLoadingAssets = true;
  bool _isLoadingMedia = false;
  bool _hasPermission = false;

  // Story options
  bool _isUploading = false;
  PostLocation? _location;
  String? _nodeId;
  StoryVisibility _visibility = StoryVisibility.public;
  TextOverlay? _textOverlay;

  // Text editing
  bool _isEditingText = false;
  final TextEditingController _textController = TextEditingController();
  double _textX = 0.5;
  double _textY = 0.5;
  Color _textColor = Colors.white;
  double _textSize = 24;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadRecentAssets();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentAssets() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      setState(() {
        _isLoadingAssets = false;
        _hasPermission = false;
      });
      return;
    }

    setState(() => _hasPermission = true);

    // Get recent photos and videos
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common, // Both images and videos
      hasAll: true,
    );

    if (albums.isEmpty) {
      setState(() => _isLoadingAssets = false);
      return;
    }

    // Get "Recent" or "All" album
    final recentAlbum = albums.first;
    final assets = await recentAlbum.getAssetListRange(start: 0, end: 50);

    setState(() {
      _recentAssets = assets;
      _isLoadingAssets = false;
    });
  }

  Future<void> _selectAsset(AssetEntity asset) async {
    setState(() {
      _selectedAsset = asset;
      _isLoadingMedia = true;
    });

    final file = await asset.file;
    if (file != null && mounted) {
      setState(() {
        _selectedMedia = file;
        _mediaType = asset.type == AssetType.video
            ? StoryMediaType.video
            : StoryMediaType.image;
        _isLoadingMedia = false;
      });
    } else {
      setState(() => _isLoadingMedia = false);
    }
  }

  Future<void> _openCamera() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (pickedFile != null && mounted) {
      setState(() {
        _selectedMedia = File(pickedFile.path);
        _mediaType = StoryMediaType.image;
        _selectedAsset = null;
      });
    }
  }

  Future<void> _toggleLocation() async {
    if (_location != null) {
      setState(() => _location = null);
      return;
    }

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          if (mounted) {
            showErrorSnackBar(context, 'Location permission required');
          }
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );

      String? placeName;
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          placeName = [
            place.locality,
            place.administrativeArea,
            place.country,
          ].where((s) => s != null && s.isNotEmpty).join(', ');
        }
      } catch (_) {}

      setState(() {
        _location = PostLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          name: placeName,
        );
      });
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Could not get location');
      }
    }
  }

  Future<void> _selectNode() async {
    final selection = await NodeSelectorSheet.show(
      context,
      title: 'Link to Node',
      allowBroadcast: false,
    );

    if (selection != null && selection.nodeNum != null) {
      setState(() {
        _nodeId = '!${selection.nodeNum!.toRadixString(16).padLeft(8, '0')}';
      });
    }
  }

  void _startTextEditing() {
    setState(() => _isEditingText = true);
  }

  void _finishTextEditing() {
    if (_textController.text.isNotEmpty) {
      setState(() {
        _textOverlay = TextOverlay(
          text: _textController.text,
          x: _textX,
          y: _textY,
          fontSize: _textSize,
          color: '#${_textColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
        );
        _isEditingText = false;
      });
    } else {
      setState(() {
        _textOverlay = null;
        _isEditingText = false;
      });
    }
  }

  void _removeText() {
    setState(() {
      _textOverlay = null;
      _textController.clear();
    });
  }

  void _cycleVisibility() {
    setState(() {
      _visibility = StoryVisibility
          .values[(_visibility.index + 1) % StoryVisibility.values.length];
    });
  }

  Future<void> _createStory() async {
    if (_selectedMedia == null) return;

    setState(() => _isUploading = true);

    try {
      final story = await ref
          .read(createStoryProvider.notifier)
          .createStory(
            mediaFile: _selectedMedia!,
            mediaType: _mediaType,
            location: _location,
            nodeId: _nodeId,
            textOverlay: _textOverlay,
            visibility: _visibility,
          );

      if (story != null && mounted) {
        showSuccessSnackBar(context, 'Story shared!');
        Navigator.pop(context);
      } else if (mounted) {
        final error = ref.read(createStoryProvider).error;
        showErrorSnackBar(context, error ?? 'Failed to create story');
        setState(() => _isUploading = false);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to create story: $e');
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Text(
            'Sign in to create stories',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _selectedMedia == null ? _buildMediaPicker() : _buildEditor(),
      ),
    );
  }

  Widget _buildMediaPicker() {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const Expanded(
                child: Text(
                  'Add to Story',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _isLoadingAssets
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : !_hasPermission
              ? _buildPermissionRequest()
              : _buildMediaGrid(),
        ),
      ],
    );
  }

  Widget _buildPermissionRequest() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Allow access to your photos',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'To create stories, we need access to your photo library.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                await PhotoManager.openSetting();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: _recentAssets.length + 1, // +1 for camera button
      itemBuilder: (context, index) {
        // First item is camera
        if (index == 0) {
          return _CameraButton(onTap: _openCamera);
        }

        final asset = _recentAssets[index - 1];
        return _MediaThumbnail(
          asset: asset,
          isSelected: _selectedAsset?.id == asset.id,
          onTap: () => _selectAsset(asset),
        );
      },
    );
  }

  Widget _buildEditor() {
    return Column(
      children: [
        // Header with actions
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _selectedMedia = null;
                    _selectedAsset = null;
                  });
                },
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.text_fields,
                  color: _textOverlay != null
                      ? context.accentColor
                      : Colors.white,
                ),
                onPressed: _startTextEditing,
              ),
              IconButton(
                icon: Icon(
                  Icons.location_on_outlined,
                  color: _location != null ? context.accentColor : Colors.white,
                ),
                onPressed: _toggleLocation,
              ),
              IconButton(
                icon: Icon(
                  Icons.router_outlined,
                  color: _nodeId != null ? context.accentColor : Colors.white,
                ),
                onPressed: _selectNode,
              ),
            ],
          ),
        ),

        // Media preview
        Expanded(
          child: _isLoadingMedia
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : GestureDetector(
                  onTapUp: _isEditingText
                      ? (details) {
                          final size = context.size!;
                          setState(() {
                            _textX = details.localPosition.dx / size.width;
                            _textY = details.localPosition.dy / size.height;
                          });
                        }
                      : null,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(_selectedMedia!, fit: BoxFit.contain),
                      ),
                      if (_textOverlay != null && !_isEditingText)
                        _buildTextOverlay(),
                      if (_isEditingText) _buildTextEditor(),
                    ],
                  ),
                ),
        ),

        // Bottom bar
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildTextOverlay() {
    return Positioned(
      left: _textOverlay!.x * MediaQuery.of(context).size.width - 100,
      top: _textOverlay!.y * MediaQuery.of(context).size.height - 20,
      child: GestureDetector(
        onTap: _startTextEditing,
        onLongPress: _removeText,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _textOverlay!.text,
            style: TextStyle(
              color: _textColor,
              fontSize: _textOverlay!.fontSize,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildTextEditor() {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Column(
          children: [
            const Spacer(),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _textController,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textColor,
                      fontSize: _textSize,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Add text',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      border: InputBorder.none,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          [
                            Colors.white,
                            Colors.black,
                            Colors.red,
                            Colors.orange,
                            Colors.yellow,
                            Colors.green,
                            Colors.blue,
                            Colors.purple,
                            Colors.pink,
                          ].map((color) {
                            return GestureDetector(
                              onTap: () => setState(() => _textColor = color),
                              child: Container(
                                width: 32,
                                height: 32,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _textColor == color
                                        ? context.accentColor
                                        : Colors.white30,
                                    width: 2,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.text_fields,
                        color: Colors.white,
                        size: 16,
                      ),
                      Expanded(
                        child: Slider(
                          value: _textSize,
                          min: 16,
                          max: 48,
                          onChanged: (v) => setState(() => _textSize = v),
                          activeColor: context.accentColor,
                          inactiveColor: Colors.white30,
                        ),
                      ),
                      const Icon(
                        Icons.text_fields,
                        color: Colors.white,
                        size: 24,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isEditingText = false;
                            _textController.clear();
                          });
                        },
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      FilledButton(
                        onPressed: _finishTextEditing,
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_location != null || _nodeId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 8,
                children: [
                  if (_location != null)
                    Chip(
                      avatar: const Icon(Icons.location_on, size: 16),
                      label: Text(
                        _location!.name ?? 'Location',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onDeleted: () => setState(() => _location = null),
                      deleteIconColor: context.textSecondary,
                      backgroundColor: context.card,
                      side: BorderSide.none,
                    ),
                  if (_nodeId != null)
                    Chip(
                      avatar: const Icon(Icons.router, size: 16),
                      label: Text(
                        _nodeId!,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onDeleted: () => setState(() => _nodeId = null),
                      deleteIconColor: context.textSecondary,
                      backgroundColor: context.card,
                      side: BorderSide.none,
                    ),
                ],
              ),
            ),
          Row(
            children: [
              BouncyTap(
                onTap: _cycleVisibility,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_visibilityIcon, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _visibilityLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              BouncyTap(
                onTap: _isUploading ? null : _createStory,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: _isUploading
                        ? null
                        : AppTheme.brandGradientHorizontal,
                    color: _isUploading ? Colors.grey : null,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: _isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.send, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Share',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData get _visibilityIcon {
    switch (_visibility) {
      case StoryVisibility.public:
        return Icons.public;
      case StoryVisibility.followersOnly:
        return Icons.people_outline;
      case StoryVisibility.closeFriends:
        return Icons.star_outline;
    }
  }

  String get _visibilityLabel {
    switch (_visibility) {
      case StoryVisibility.public:
        return 'Public';
      case StoryVisibility.followersOnly:
        return 'Followers';
      case StoryVisibility.closeFriends:
        return 'Close Friends';
    }
  }
}

/// Camera button as first item in grid
class _CameraButton extends StatelessWidget {
  const _CameraButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt, color: Colors.white, size: 32),
            SizedBox(height: 4),
            Text(
              'Camera',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thumbnail for a media asset in the grid
class _MediaThumbnail extends StatefulWidget {
  const _MediaThumbnail({
    required this.asset,
    required this.isSelected,
    required this.onTap,
  });

  final AssetEntity asset;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_MediaThumbnail> createState() => _MediaThumbnailState();
}

class _MediaThumbnailState extends State<_MediaThumbnail> {
  Uint8List? _thumbnailData;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    final data = await widget.asset.thumbnailDataWithSize(
      const ThumbnailSize(200, 200),
      quality: 80,
    );
    if (mounted && data != null) {
      setState(() => _thumbnailData = data);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail
          if (_thumbnailData != null)
            Image.memory(_thumbnailData!, fit: BoxFit.cover)
          else
            Container(color: Colors.grey[900]),

          // Video indicator
          if (widget.asset.type == AssetType.video)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam, color: Colors.white, size: 12),
                    const SizedBox(width: 2),
                    Text(
                      _formatDuration(widget.asset.videoDuration),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),

          // Selection indicator
          if (widget.isSelected)
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: context.accentColor, width: 3),
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: context.accentColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 20),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
