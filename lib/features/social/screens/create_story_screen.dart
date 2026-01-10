import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/content_moderation_warning.dart';
import '../../../core/widgets/node_selector_sheet.dart';
import '../../../models/social.dart';
import '../../../models/story.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/social_providers.dart';
import '../../../providers/story_providers.dart';
import '../../../utils/snackbar.dart';

/// Album filter type for story media picker
enum AlbumFilterType { recents, videos, favorites, allAlbums }

extension AlbumFilterTypeExtension on AlbumFilterType {
  String get label {
    switch (this) {
      case AlbumFilterType.recents:
        return 'Recents';
      case AlbumFilterType.videos:
        return 'Videos';
      case AlbumFilterType.favorites:
        return 'Favorites';
      case AlbumFilterType.allAlbums:
        return 'All Albums';
    }
  }

  IconData get icon {
    switch (this) {
      case AlbumFilterType.recents:
        return Icons.photo_library_outlined;
      case AlbumFilterType.videos:
        return Icons.play_circle_outline;
      case AlbumFilterType.favorites:
        return Icons.favorite_outline;
      case AlbumFilterType.allAlbums:
        return Icons.grid_view_outlined;
    }
  }
}

/// Screen for creating a new story with media picker.
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

  // Album selection
  AlbumFilterType _selectedAlbumFilter = AlbumFilterType.recents;
  List<AssetPathEntity> _allAlbums = [];
  AssetPathEntity? _selectedAlbum; // For "All Albums" view

  // Story options
  bool _isUploading = false;
  PostLocation? _location;
  String? _nodeId;
  StoryVisibility _visibility = StoryVisibility.public;
  TextOverlay? _textOverlay;

  // Text editing - enhanced with drag/pinch support
  bool _isEditingText = false;
  bool _isTextInputMode = false; // Whether keyboard is open for input
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  Offset _textPosition = const Offset(0.5, 0.4); // Normalized position (0-1)
  double _textScale = 1.0; // Scale factor for pinch-to-resize
  double _textRotation = 0.0; // Rotation angle in radians
  Color _textColor = Colors.white;
  double _textSize = 28;
  bool _hasTextBackground = true;

  // Gesture tracking
  double _baseScale = 1.0;
  double _baseRotation = 0.0;

  // Fixed preview size - captured once before keyboard opens
  Size? _fixedPreviewSize;

  // Key for capturing the story preview as an image
  final GlobalKey _storyPreviewKey = GlobalKey();

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadRecentAssets();
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
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

    // Load all albums for the "All Albums" option
    final allAlbums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      hasAll: true,
    );
    _allAlbums = allAlbums;

    // Load assets based on filter type
    await _loadAssetsForFilter(_selectedAlbumFilter);
  }

  Future<void> _loadAssetsForFilter(AlbumFilterType filter) async {
    setState(() => _isLoadingAssets = true);

    List<AssetEntity> assets = [];

    switch (filter) {
      case AlbumFilterType.recents:
        // Get "Recent" or "All" album (first album is usually all/recents)
        final albums = await PhotoManager.getAssetPathList(
          type: RequestType.common,
          hasAll: true,
        );
        if (albums.isNotEmpty) {
          assets = await albums.first.getAssetListRange(start: 0, end: 100);
        }
        break;

      case AlbumFilterType.videos:
        // Get only videos
        final videoAlbums = await PhotoManager.getAssetPathList(
          type: RequestType.video,
          hasAll: true,
        );
        if (videoAlbums.isNotEmpty) {
          assets = await videoAlbums.first.getAssetListRange(
            start: 0,
            end: 100,
          );
        }
        break;

      case AlbumFilterType.favorites:
        // Get favorites - filter from all albums or use iOS favorites
        final favAlbums = await PhotoManager.getAssetPathList(
          type: RequestType.common,
          hasAll: true,
        );
        // Try to find "Favorites" album by name
        AssetPathEntity? favAlbum;
        for (final album in favAlbums) {
          if (album.name.toLowerCase().contains('favorite') ||
              album.name.toLowerCase().contains('favourite')) {
            favAlbum = album;
            break;
          }
        }
        if (favAlbum != null) {
          assets = await favAlbum.getAssetListRange(start: 0, end: 100);
        } else if (favAlbums.isNotEmpty) {
          // Fall back to recents if no favorites album
          assets = await favAlbums.first.getAssetListRange(start: 0, end: 100);
        }
        break;

      case AlbumFilterType.allAlbums:
        // Show specific album if selected, otherwise show first album
        if (_selectedAlbum != null) {
          assets = await _selectedAlbum!.getAssetListRange(start: 0, end: 100);
        } else if (_allAlbums.isNotEmpty) {
          assets = await _allAlbums.first.getAssetListRange(start: 0, end: 100);
        }
        break;
    }

    if (mounted) {
      setState(() {
        _recentAssets = assets;
        _isLoadingAssets = false;
      });
    }
  }

  void _changeAlbumFilter(AlbumFilterType filter) {
    if (filter == _selectedAlbumFilter) return;
    setState(() {
      _selectedAlbumFilter = filter;
      _selectedAlbum = null;
    });
    _loadAssetsForFilter(filter);
  }

  void _selectAlbum(AssetPathEntity album) {
    setState(() {
      _selectedAlbum = album;
      _selectedAlbumFilter = AlbumFilterType.allAlbums;
    });
    _loadAssetsForFilter(AlbumFilterType.allAlbums);
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
    setState(() {
      _isEditingText = true;
      _isTextInputMode = true;
      if (_textOverlay != null) {
        _textController.text = _textOverlay!.text;
      }
    });
  }

  void _finishTextInput() {
    // Close keyboard but keep text on screen for positioning
    FocusScope.of(context).unfocus();
    if (_textController.text.isNotEmpty) {
      setState(() {
        _isTextInputMode = false;
        _isEditingText = true; // Keep in edit mode for repositioning
        _updateTextOverlay();
      });
    } else {
      setState(() {
        _isTextInputMode = false;
        _isEditingText = false;
        _textOverlay = null;
      });
    }
  }

  void _confirmText() {
    // Finalize text and exit edit mode
    if (_textController.text.isNotEmpty) {
      _updateTextOverlay();
    }
    setState(() {
      _isEditingText = false;
      _isTextInputMode = false;
    });
  }

  void _updateTextOverlay() {
    _textOverlay = TextOverlay(
      text: _textController.text,
      x: _textPosition.dx,
      y: _textPosition.dy,
      fontSize: _textSize * _textScale,
      color: '#${_textColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
    );
  }

  void _removeText() {
    setState(() {
      _textOverlay = null;
      _textController.clear();
      _isEditingText = false;
      _isTextInputMode = false;
      _textScale = 1.0;
      _textRotation = 0.0;
      _textPosition = const Offset(0.5, 0.4);
    });
  }

  void _onTextScaleStart(ScaleStartDetails details) {
    _baseScale = _textScale;
    _baseRotation = _textRotation;
    _startFocalPoint = details.focalPoint;
    _basePosition = _textPosition;
    HapticFeedback.selectionClick();
  }

  void _onTextScaleEnd() {
    HapticFeedback.lightImpact();
  }

  /// Captures the story preview (image + text overlay) as a single composited image
  Future<File?> _captureCompositeImage() async {
    try {
      final boundary =
          _storyPreviewKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;

      // Capture at 3x resolution for high quality
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/story_composite_$timestamp.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      return file;
    } catch (e) {
      debugPrint('Failed to capture composite image: $e');
      return null;
    }
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
      // Pre-submission content moderation check for text overlay
      if (_textOverlay != null && _textOverlay!.text.isNotEmpty) {
        final moderationService = ref.read(contentModerationServiceProvider);
        final checkResult = await moderationService.checkText(
          _textOverlay!.text,
          useServerCheck: true,
        );

        if (!checkResult.passed || checkResult.action == 'reject') {
          // Content blocked - show warning and don't proceed
          if (mounted) {
            final action = await ContentModerationWarning.show(
              context,
              result: ContentModerationCheckResult(
                passed: false,
                action: 'reject',
                categories: checkResult.categories.map((c) => c.name).toList(),
                details: checkResult.details,
              ),
            );
            if (action == ContentModerationAction.edit) {
              // User wants to edit - focus on text field
              setState(() {
                _isTextInputMode = true;
                _isEditingText = true;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _textFocusNode.requestFocus();
              });
            }
          }
          setState(() => _isUploading = false);
          return;
        } else if (checkResult.action == 'review' ||
            checkResult.action == 'flag') {
          // Content flagged - show warning but allow to proceed
          if (mounted) {
            final action = await ContentModerationWarning.show(
              context,
              result: ContentModerationCheckResult(
                passed: true,
                action: checkResult.action,
                categories: checkResult.categories.map((c) => c.name).toList(),
                details: checkResult.details,
              ),
            );
            if (action == ContentModerationAction.edit) {
              // User wants to edit - focus on text field
              setState(() {
                _isTextInputMode = true;
                _isEditingText = true;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _textFocusNode.requestFocus();
              });
              setState(() => _isUploading = false);
              return;
            } else if (action == ContentModerationAction.cancel) {
              setState(() => _isUploading = false);
              return;
            }
          }
        }
      }

      // If there's a text overlay, capture the composited image
      File mediaToUpload = _selectedMedia!;
      if (_textOverlay != null && _textOverlay!.text.isNotEmpty) {
        final compositedFile = await _captureCompositeImage();
        if (compositedFile != null) {
          mediaToUpload = compositedFile;
        }
      }

      final story = await ref
          .read(createStoryProvider.notifier)
          .createStory(
            mediaFile: mediaToUpload,
            mediaType: _mediaType,
            location: _location,
            nodeId: _nodeId,
            textOverlay: null, // Text is now baked into the image
            visibility: _visibility,
          );

      if (story != null && mounted) {
        showSuccessSnackBar(context, 'Story shared!');
        Navigator.pop(context);
      } else if (mounted) {
        final error = ref.read(createStoryProvider).error;
        if (error != null && error.contains('Content policy violation')) {
          setState(() => _isUploading = false);
          await ContentModerationWarning.show(
            context,
            result: ContentModerationCheckResult(
              passed: false,
              action: 'reject',
              categories: ['Inappropriate Content'],
            ),
          );
        } else {
          showErrorSnackBar(context, error ?? 'Failed to create story');
          setState(() => _isUploading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('Content policy violation')) {
          setState(() => _isUploading = false);
          await ContentModerationWarning.show(
            context,
            result: ContentModerationCheckResult(
              passed: false,
              action: 'reject',
              categories: ['Inappropriate Content'],
            ),
          );
        } else {
          showErrorSnackBar(context, 'Failed to create story: $e');
          setState(() => _isUploading = false);
        }
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
              // Settings icon
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),
        ),

        // Album filter dropdown
        if (_hasPermission)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildAlbumDropdown(),
                const Spacer(),
                // Multi-select button (future feature placeholder)
                IconButton(
                  icon: const Icon(
                    Icons.library_add_check_outlined,
                    color: Colors.white70,
                    size: 22,
                  ),
                  onPressed: () {},
                  tooltip: 'Select multiple',
                ),
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
              : _selectedAlbumFilter == AlbumFilterType.allAlbums &&
                    _selectedAlbum == null
              ? _buildAlbumsList()
              : _buildMediaGrid(),
        ),
      ],
    );
  }

  Widget _buildAlbumDropdown() {
    return PopupMenuButton<AlbumFilterType>(
      offset: const Offset(0, 40),
      color: context.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: _changeAlbumFilter,
      itemBuilder: (context) => AlbumFilterType.values.map((filter) {
        return PopupMenuItem<AlbumFilterType>(
          value: filter,
          child: Row(
            children: [
              Icon(
                filter.icon,
                color: filter == _selectedAlbumFilter
                    ? context.accentColor
                    : context.textPrimary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                filter.label,
                style: TextStyle(
                  color: filter == _selectedAlbumFilter
                      ? context.accentColor
                      : context.textPrimary,
                  fontWeight: filter == _selectedAlbumFilter
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              if (filter == _selectedAlbumFilter) ...[
                const Spacer(),
                Icon(Icons.check, color: context.accentColor, size: 20),
              ],
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedAlbum?.name ?? _selectedAlbumFilter.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumsList() {
    if (_allAlbums.isEmpty) {
      return Center(
        child: Text(
          'No albums found',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _allAlbums.length,
      itemBuilder: (context, index) {
        final album = _allAlbums[index];
        return _AlbumListTile(album: album, onTap: () => _selectAlbum(album));
      },
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
    return Stack(
      children: [
        // Main editor content
        Column(
          children: [
            // Header with actions
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  if (_isTextInputMode)
                    TextButton(
                      onPressed: _isUploading
                          ? null
                          : () {
                              if (_textOverlay == null) {
                                _textController.clear();
                              }
                              _finishTextInput();
                            },
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: _isUploading ? Colors.white38 : Colors.white,
                          fontSize: 17,
                        ),
                      ),
                    )
                  else
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: _isUploading ? Colors.white38 : Colors.white,
                      ),
                      onPressed: _isUploading
                          ? null
                          : _isEditingText
                          ? _confirmText
                          : () {
                              setState(() {
                                _selectedMedia = null;
                                _selectedAsset = null;
                                _textOverlay = null;
                                _textController.clear();
                                _textScale = 1.0;
                                _textRotation = 0.0;
                                _fixedPreviewSize = null;
                              });
                            },
                    ),
                  const Spacer(),
                  if (_isTextInputMode) ...[
                    // Font icon for text style
                    IconButton(
                      icon: const Icon(Icons.text_format, color: Colors.white),
                      onPressed: () {
                        // Cycle through font sizes
                        setState(() {
                          if (_textSize <= 22) {
                            _textSize = 28;
                          } else if (_textSize <= 34) {
                            _textSize = 42;
                          } else {
                            _textSize = 18;
                          }
                        });
                      },
                    ),
                    // Location icon
                    IconButton(
                      icon: Icon(
                        Icons.location_on_outlined,
                        color: _location != null
                            ? context.accentColor
                            : Colors.white,
                      ),
                      onPressed: _toggleLocation,
                    ),
                    // Done button
                    TextButton(
                      onPressed: _finishTextInput,
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ] else if (_isEditingText && !_isTextInputMode) ...[
                    TextButton(
                      onPressed: _isUploading ? null : _confirmText,
                      child: Text(
                        'Done',
                        style: TextStyle(
                          color: _isUploading
                              ? context.accentColor.withValues(alpha: 0.4)
                              : context.accentColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ] else ...[
                    IconButton(
                      icon: Icon(
                        Icons.text_fields,
                        color: _isUploading
                            ? Colors.white38
                            : _textOverlay != null || _isEditingText
                            ? context.accentColor
                            : Colors.white,
                      ),
                      onPressed: _isUploading ? null : _startTextEditing,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.location_on_outlined,
                        color: _isUploading
                            ? Colors.white38
                            : _location != null
                            ? context.accentColor
                            : Colors.white,
                      ),
                      onPressed: _isUploading ? null : _toggleLocation,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.router_outlined,
                        color: _isUploading
                            ? Colors.white38
                            : _nodeId != null
                            ? context.accentColor
                            : Colors.white,
                      ),
                      onPressed: _isUploading ? null : _selectNode,
                    ),
                  ],
                ],
              ),
            ),

            // Media preview with text overlay
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _isLoadingMedia
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          // Capture the size once before keyboard opens
                          _fixedPreviewSize ??= Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );
                          // Always use the fixed size for text positioning
                          final containerSize = _fixedPreviewSize!;
                          return RepaintBoundary(
                            key: _storyPreviewKey,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Background image
                                  GestureDetector(
                                    onTap: _isEditingText && !_isTextInputMode
                                        ? _confirmText
                                        : null,
                                    child: Image.file(
                                      _selectedMedia!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  // Draggable text overlay (also show when typing)
                                  if (_isTextInputMode ||
                                      _textController.text.isNotEmpty ||
                                      _textOverlay != null)
                                    _buildDraggableText(containerSize),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),

            // Bottom area - hide when keyboard is up for text input
            if (!_isTextInputMode)
              SizedBox(
                height: 100,
                child: ClipRect(
                  child: _isEditingText
                      ? _buildTextEditingToolbar()
                      : _buildBottomBar(),
                ),
              ),
          ],
        ),

        // Text input controls (color picker above keyboard)
        if (_isTextInputMode) _buildTextInputOverlay(),
      ],
    );
  }

  Widget _buildDraggableText(Size containerSize) {
    final displayText = _textController.text.isNotEmpty
        ? _textController.text
        : _textOverlay?.text ?? '';

    // Show placeholder when in text input mode with empty text
    final showPlaceholder = _isTextInputMode && displayText.isEmpty;
    final textToShow = showPlaceholder ? 'Type something...' : displayText;

    if (textToShow.isEmpty) return const SizedBox.shrink();

    // Calculate pixel position from normalized values
    final pixelX = _textPosition.dx * containerSize.width;
    final pixelY = _textPosition.dy * containerSize.height;

    return Positioned(
      left: 0,
      top: 0,
      right: 0,
      bottom: 0,
      child: Stack(
        children: [
          Positioned(
            left: pixelX - 140, // Center the text (max width 280 / 2)
            top: pixelY - 30, // Approximate center vertically
            child: GestureDetector(
              // Always enable gestures for drag/pinch/rotate
              onScaleStart: _onTextScaleStart,
              onScaleUpdate: (details) =>
                  _onTextScaleUpdate(details, containerSize),
              onScaleEnd: (_) => _onTextScaleEnd(),
              // Tap to enter edit mode or edit text
              onTap: _isEditingText
                  ? _startTextEditing
                  : () => setState(() => _isEditingText = true),
              // Double tap to edit text content
              onDoubleTap: _startTextEditing,
              // Long press to delete
              onLongPress: () {
                HapticFeedback.heavyImpact();
                _removeText();
              },
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..scaleByVector3(Vector3(_textScale, _textScale, 1.0))
                  ..rotateZ(_textRotation),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 280),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _hasTextBackground
                        ? Colors.black54
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: _isEditingText || _isTextInputMode
                        ? Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 1.5,
                          )
                        : null,
                  ),
                  child: Text(
                    textToShow,
                    style: TextStyle(
                      color: showPlaceholder
                          ? _textColor.withValues(alpha: 0.5)
                          : _textColor,
                      fontSize: _textSize,
                      fontWeight: FontWeight.w600,
                      shadows: _hasTextBackground
                          ? null
                          : [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.8),
                                blurRadius: 4,
                                offset: const Offset(1, 1),
                              ),
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Gesture tracking state
  Offset _startFocalPoint = Offset.zero;
  Offset _basePosition = const Offset(0.5, 0.4);

  void _onTextScaleUpdate(ScaleUpdateDetails details, Size containerSize) {
    setState(() {
      // Update scale and rotation when pinching (scale != 1.0 means pinch gesture)
      if (details.scale != 1.0 || details.rotation != 0.0) {
        _textScale = (_baseScale * details.scale).clamp(0.5, 3.0);
        _textRotation = _baseRotation + details.rotation;
      }

      // Update position based on drag
      final delta = details.focalPoint - _startFocalPoint;
      _textPosition = Offset(
        (_basePosition.dx + delta.dx / containerSize.width).clamp(0.05, 0.95),
        (_basePosition.dy + delta.dy / containerSize.height).clamp(0.05, 0.95),
      );
    });
  }

  Widget _buildTextInputOverlay() {
    // Show controls below the preview, text stays in-place on preview
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Material(
        color: Colors.black,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Color picker row
              SizedBox(
                height: 56,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _availableColors.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return GestureDetector(
                        onTap: () => setState(
                          () => _hasTextBackground = !_hasTextBackground,
                        ),
                        child: Container(
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _hasTextBackground
                                ? Colors.white
                                : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            Icons.format_color_fill,
                            color: _hasTextBackground
                                ? Colors.black
                                : Colors.white,
                            size: 18,
                          ),
                        ),
                      );
                    }
                    final color = _availableColors[index - 1];
                    final isSelected = _textColor == color;
                    return GestureDetector(
                      onTap: () => setState(() => _textColor = color),
                      child: Container(
                        width: 36,
                        height: 36,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Hidden text field to capture keyboard input
              SizedBox(
                height: 1,
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _textController,
                    focusNode: _textFocusNode,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _finishTextInput(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const List<Color> _availableColors = [
    Colors.white,
    Colors.black,
    Color(0xFFFF3B30),
    Color(0xFFFF9500),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF00C7BE),
    Color(0xFF007AFF),
    Color(0xFF5856D6),
    Color(0xFFFF2D55),
    Color(0xFFAF52DE),
    Color(0xFF8E8E93),
  ];

  Widget _buildTextEditingToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Instructions
          Text(
            'Drag to move • Pinch to resize • Long press to delete',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildToolbarButton(
                icon: Icons.edit,
                label: 'Edit',
                onTap: _startTextEditing,
              ),
              const SizedBox(width: 16),
              _buildToolbarButton(
                icon: Icons.check,
                label: 'Done',
                onTap: _confirmText,
              ),
              const SizedBox(width: 16),
              _buildToolbarButton(
                icon: Icons.delete_outline,
                label: 'Delete',
                onTap: _removeText,
                isDestructive: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.red : Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isDestructive ? Colors.red : Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_location != null || _nodeId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
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
                      onDeleted: _isUploading
                          ? null
                          : () => setState(() => _location = null),
                      deleteIconColor: _isUploading
                          ? context.textTertiary
                          : context.textSecondary,
                      backgroundColor: context.card,
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                    ),
                  if (_nodeId != null)
                    Chip(
                      avatar: const Icon(Icons.router, size: 16),
                      label: Text(
                        _nodeId!,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onDeleted: _isUploading
                          ? null
                          : () => setState(() => _nodeId = null),
                      deleteIconColor: _isUploading
                          ? context.textTertiary
                          : context.textSecondary,
                      backgroundColor: context.card,
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          Row(
            children: [
              BouncyTap(
                onTap: _isUploading ? null : _cycleVisibility,
                child: Opacity(
                  opacity: _isUploading ? 0.5 : 1.0,
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

/// List tile for album selection in "All Albums" view
class _AlbumListTile extends StatefulWidget {
  const _AlbumListTile({required this.album, required this.onTap});

  final AssetPathEntity album;
  final VoidCallback onTap;

  @override
  State<_AlbumListTile> createState() => _AlbumListTileState();
}

class _AlbumListTileState extends State<_AlbumListTile> {
  Uint8List? _thumbnailData;
  int _assetCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAlbumInfo();
  }

  Future<void> _loadAlbumInfo() async {
    // Get asset count
    _assetCount = await widget.album.assetCountAsync;

    // Get first asset for thumbnail
    if (_assetCount > 0) {
      final assets = await widget.album.getAssetListRange(start: 0, end: 1);
      if (assets.isNotEmpty) {
        final data = await assets.first.thumbnailDataWithSize(
          const ThumbnailSize(200, 200),
          quality: 80,
        );
        if (mounted && data != null) {
          setState(() => _thumbnailData = data);
        }
      }
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: widget.onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 56,
          height: 56,
          child: _thumbnailData != null
              ? Image.memory(_thumbnailData!, fit: BoxFit.cover)
              : Container(
                  color: Colors.grey[800],
                  child: const Icon(Icons.photo_album, color: Colors.white54),
                ),
        ),
      ),
      title: Text(
        widget.album.name.isEmpty ? 'Untitled Album' : widget.album.name,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '$_assetCount items',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 13,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.white54),
    );
  }
}
