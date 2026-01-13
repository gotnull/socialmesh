import 'dart:io';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/content_moderation_warning.dart';
import '../../../models/social.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/connection_providers.dart';
import '../../../providers/signal_providers.dart';
import '../../../providers/social_providers.dart';
import '../../../services/signal_service.dart';
import '../../../utils/snackbar.dart';
import '../widgets/ttl_selector.dart';

/// Screen for creating a new signal.
///
/// Signals are mesh-first ephemeral content with:
/// - Text (required, max 280 chars)
/// - Optional image (deferred upload)
/// - TTL selector
/// - Optional location
class CreateSignalScreen extends ConsumerStatefulWidget {
  const CreateSignalScreen({super.key});

  @override
  ConsumerState<CreateSignalScreen> createState() => _CreateSignalScreenState();
}

class _CreateSignalScreenState extends ConsumerState<CreateSignalScreen> {
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _contentFocusNode = FocusNode();

  static const int _maxLength = 280;
  bool _isSubmitting = false;
  bool _isLoadingLocation = false;
  bool _isValidatingImage = false;
  int _ttlMinutes = SignalTTL.defaultTTL;
  PostLocation? _location;
  String? _imageLocalPath;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
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

  /// Check basic content requirements (text not empty, within length limit)
  bool get _hasValidContent =>
      _contentController.text.trim().isNotEmpty &&
      _contentController.text.length <= _maxLength &&
      !_isSubmitting;

  /// Check if device is connected to mesh
  bool get _isDeviceConnected => ref.read(isDeviceConnectedProvider);

  /// Check if user is authenticated
  bool get _isAuthenticated => ref.read(isSignedInProvider);

  /// Combined check for whether signal can be submitted
  bool get _canSubmit =>
      _hasValidContent &&
      _isDeviceConnected &&
      _isAuthenticated &&
      !_isValidatingImage;

  /// Get the reason why submission is blocked (for UI feedback)
  String? get _submitBlockedReason {
    if (!_isAuthenticated) return 'Sign in required';
    if (!_isDeviceConnected) return 'Device not connected';
    if (_isValidatingImage) return 'Processing image...';
    return null;
  }

  int get _remainingChars => _maxLength - _contentController.text.length;

  Future<void> _handleClose() async {
    _dismissKeyboard();
    if (_contentController.text.trim().isNotEmpty || _imageLocalPath != null) {
      final shouldDiscard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.card,
          title: Text(
            'Discard signal?',
            style: TextStyle(color: context.textPrimary),
          ),
          content: Text(
            'Your draft will be lost.',
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

    if (mounted) Navigator.pop(context);
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  Future<void> _submitSignal() async {
    // Auth gating check
    if (!_isAuthenticated) {
      AppLogging.signals('🔒 Send blocked: user not authenticated');
      showErrorSnackBar(context, 'Sign in required to send signals');
      return;
    }

    // Connection gating check
    if (!_isDeviceConnected) {
      AppLogging.signals('🚫 Send blocked: device not connected');
      showErrorSnackBar(context, 'Connect to a device to send signals');
      return;
    }

    if (!_hasValidContent) return;

    _dismissKeyboard();
    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    final content = _contentController.text.trim();

    // Pre-submission content moderation check
    if (content.isNotEmpty) {
      final moderationService = ref.read(contentModerationServiceProvider);
      final checkResult = await moderationService.checkText(
        content,
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
          setState(() => _isSubmitting = false);
          if (action == ContentModerationAction.edit) {
            // User wants to edit - focus on content field
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _contentFocusNode.requestFocus();
            });
          }
        }
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
          if (action == ContentModerationAction.cancel) {
            setState(() => _isSubmitting = false);
            return;
          }
          if (action == ContentModerationAction.edit) {
            // User wants to edit - focus on content field
            setState(() => _isSubmitting = false);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _contentFocusNode.requestFocus();
            });
            return;
          }
          // If action is proceed, continue with submission
        }
      }
    }

    try {
      final signal = await ref
          .read(signalFeedProvider.notifier)
          .createSignal(
            content: _contentController.text.trim(),
            ttlMinutes: _ttlMinutes,
            location: _location,
            imageLocalPath: _imageLocalPath,
          );

      if (signal != null && mounted) {
        showSuccessSnackBar(context, 'Signal sent');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to create signal');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _pickImage() async {
    _dismissKeyboard();

    // Request photo library permission
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      if (mounted) {
        final openSettings = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: context.card,
            title: Text(
              'Photo Access Required',
              style: TextStyle(color: context.textPrimary),
            ),
            content: Text(
              'To select photos, we need access to your photo library.',
              style: TextStyle(color: context.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
        if (openSettings == true) {
          await PhotoManager.openSetting();
        }
      }
      return;
    }

    // Show media picker bottom sheet
    if (!mounted) return;
    final result = await showModalBottomSheet<_MediaPickerResult?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _MediaPickerSheet(),
    );

    if (result != null && mounted) {
      if (result.isCamera) {
        // Use camera
        if (!mounted) return;
        final pickedFile = await _imagePicker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
        if (pickedFile != null && mounted) {
          final validated = await _validateImage(pickedFile.path);
          if (validated && mounted) {
            setState(() => _imageLocalPath = pickedFile.path);
          }
        }
      } else if (result.asset != null) {
        // Use selected asset from gallery
        final file = await result.asset!.file;
        if (file != null && mounted) {
          final validated = await _validateImage(file.path);
          if (validated && mounted) {
            setState(() => _imageLocalPath = file.path);
          }
        }
      }
    }
  }

  /// Validate image through content moderation before accepting it.
  /// Returns true if image passes validation, false otherwise.
  Future<bool> _validateImage(String localPath) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Can't validate without auth - allow image (will be validated on upload)
      AppLogging.signals(
        '[CreateSignal] Skipping image validation: not authenticated',
      );
      return true;
    }

    setState(() => _isValidatingImage = true);

    try {
      final imageFile = File(localPath);
      if (!await imageFile.exists()) {
        AppLogging.signals('[CreateSignal] Image file not found: $localPath');
        return false;
      }

      // Upload to temp location for moderation
      final fileName =
          'temp_${DateTime.now().millisecondsSinceEpoch}_${currentUser.uid}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('signal_images_temp')
          .child(fileName);

      // Add metadata with authorId for content moderation
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'authorId': currentUser.uid,
          'uploadedAt': DateTime.now().toIso8601String(),
          'purpose': 'signal_validation',
        },
      );

      AppLogging.signals(
        '[CreateSignal] Uploading for validation: signal_images_temp/$fileName',
      );
      await ref.putFile(imageFile, metadata);

      // Listen for moderation result from Firestore
      final moderationDocId = 'post_${fileName.replaceAll('.jpg', '')}';
      AppLogging.signals(
        '[CreateSignal] Waiting for moderation result: content_moderation/$moderationDocId',
      );

      // Wait for moderation result with 10s timeout
      final moderationSnapshot = await FirebaseFirestore.instance
          .collection('content_moderation')
          .doc(moderationDocId)
          .snapshots()
          .firstWhere(
            (snapshot) => snapshot.exists && snapshot.data() != null,
            orElse: () => throw TimeoutException('Moderation timeout'),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Moderation timeout'),
          );

      final moderationData = moderationSnapshot.data();
      if (moderationData == null) {
        throw Exception('No moderation result');
      }

      final result = moderationData['result'] as Map<String, dynamic>?;
      final action = result?['action'] as String?;
      final passed = result?['passed'] as bool? ?? false;

      AppLogging.signals(
        '[CreateSignal] Moderation result: action=$action, passed=$passed',
      );

      // Clean up moderation doc
      try {
        await FirebaseFirestore.instance
            .collection('content_moderation')
            .doc(moderationDocId)
            .delete();
      } catch (_) {
        // Ignore cleanup errors
      }

      if (!passed || action == 'reject') {
        // Image was rejected by moderation
        AppLogging.signals(
          '[CreateSignal] Image blocked by content moderation: ${result?['details']}',
        );

        // Delete temp file if it still exists
        try {
          await ref.delete();
        } catch (_) {
          // Already deleted by function
        }

        if (mounted) {
          showErrorSnackBar(
            context,
            'Image violates content guidelines and was blocked.',
          );
        }
        return false;
      }

      // Image passed - clean up temp file
      AppLogging.signals('[CreateSignal] Image passed moderation');
      try {
        await ref.delete();
      } catch (_) {
        // Ignore cleanup errors
      }
      return true;
    } catch (e) {
      AppLogging.signals('[CreateSignal] Image validation error: $e');

      // Check for specific error types
      if (e is TimeoutException) {
        if (mounted) {
          showErrorSnackBar(
            context,
            'Image validation timed out. Please try again.',
          );
        }
        return false;
      }

      if (e is FirebaseException && e.code == 'object-not-found') {
        if (mounted) {
          showErrorSnackBar(
            context,
            'Image violates content guidelines and was blocked.',
          );
        }
        return false;
      }

      // Other errors - show generic error
      if (mounted) {
        showErrorSnackBar(context, 'Failed to validate image');
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isValidatingImage = false);
      }
    }
  }

  void _removeImage() {
    setState(() {
      _imageLocalPath = null;
    });
  }

  Future<void> _getLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          if (mounted) {
            showErrorSnackBar(context, 'Location permission denied');
          }
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition();
      String? locationName;

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
          ].where((e) => e != null && e.isNotEmpty).join(', ');
        }
      } catch (_) {
        // Geocoding failed, use coordinates
      }

      if (mounted) {
        setState(() {
          _location = PostLocation(
            latitude: position.latitude,
            longitude: position.longitude,
            name: locationName,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to get location');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  void _removeLocation() {
    setState(() {
      _location = null;
    });
  }

  void _showImagePreview() {
    if (_imageLocalPath == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text('Preview', style: TextStyle(color: Colors.white)),
            centerTitle: true,
          ),
          extendBodyBehindAppBar: true,
          body: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.file(File(_imageLocalPath!), fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myNodeNum = ref.watch(myNodeNumProvider);

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: _isSubmitting ? context.textTertiary : context.textPrimary,
          ),
          onPressed: _isSubmitting ? null : _handleClose,
        ),
        title: Text(
          'Go Active',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Tooltip(
              message: _submitBlockedReason ?? '',
              child: BouncyTap(
                onTap: _canSubmit ? _submitSignal : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: _canSubmit
                        ? AppTheme.brandGradientHorizontal
                        : null,
                    color: _canSubmit
                        ? null
                        : context.border.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.sensors,
                              size: 18,
                              color: _canSubmit
                                  ? Colors.white
                                  : context.textTertiary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Send signal',
                              style: TextStyle(
                                color: _canSubmit
                                    ? Colors.white
                                    : context.textTertiary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: _dismissKeyboard,
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mesh node indicator
              if (myNodeNum != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: context.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: context.accentColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.router, size: 16, color: context.accentColor),
                      const SizedBox(width: 8),
                      Text(
                        'Emitting from !${myNodeNum.toRadixString(16)}',
                        style: TextStyle(
                          color: context.accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Content input
              Container(
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.border.withValues(alpha: 0.5),
                  ),
                ),
                child: TextField(
                  controller: _contentController,
                  focusNode: _contentFocusNode,
                  enabled: !_isSubmitting,
                  maxLines: 5,
                  maxLength: _maxLength,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(_maxLength),
                  ],
                  style: TextStyle(color: context.textPrimary, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'What are you signaling?',
                    hintStyle: TextStyle(color: context.textTertiary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                    counterText: '',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),

              // Character count
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '$_remainingChars',
                      style: TextStyle(
                        color: _remainingChars < 0
                            ? Colors.red
                            : _remainingChars < 20
                            ? Colors.orange
                            : context.textTertiary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Image preview
              if (_imageLocalPath != null) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _showImagePreview(),
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
                          child: Image.file(
                            File(_imageLocalPath!),
                            width: double.infinity,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: BouncyTap(
                          onTap: _isSubmitting ? null : _removeImage,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      // Local indicator
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.phone_android,
                                color: Colors.white,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Attached locally',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Location preview
              if (_location != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: context.border.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 18,
                        color: context.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _location!.name ?? 'Current location',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      BouncyTap(
                        onTap: _isSubmitting ? null : _removeLocation,
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // TTL Selector
              Text(
                'Fades in',
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              TTLSelector(
                selectedMinutes: _ttlMinutes,
                onChanged: _isSubmitting
                    ? null
                    : (minutes) {
                        setState(() => _ttlMinutes = minutes);
                      },
              ),

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  _ActionButton(
                    icon: Icons.image_outlined,
                    label: 'Image',
                    onTap: _isSubmitting || _isValidatingImage
                        ? null
                        : _pickImage,
                    isSelected: _imageLocalPath != null,
                    isLoading: _isValidatingImage,
                  ),
                  const SizedBox(width: 12),
                  _ActionButton(
                    icon: Icons.location_on_outlined,
                    label: 'Location',
                    onTap: _isSubmitting || _isLoadingLocation
                        ? null
                        : _getLocation,
                    isSelected: _location != null,
                    isLoading: _isLoadingLocation,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Info banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: context.border.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: context.textTertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Signals are temporary. They fade automatically and exist only while active.',
                        style: TextStyle(
                          color: context.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isSelected = false,
    this.isLoading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? context.accentColor.withValues(alpha: 0.15)
              : context.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? context.accentColor.withValues(alpha: 0.5)
                : context.border.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.accentColor,
                ),
              )
            else
              Icon(
                icon,
                size: 18,
                color: isSelected ? context.accentColor : context.textSecondary,
              ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? context.accentColor : context.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Album filter type for signal media picker (images only)
enum _AlbumFilterType { recents, favorites, allAlbums }

extension _AlbumFilterTypeExtension on _AlbumFilterType {
  String get label {
    switch (this) {
      case _AlbumFilterType.recents:
        return 'Recents';
      case _AlbumFilterType.favorites:
        return 'Favorites';
      case _AlbumFilterType.allAlbums:
        return 'All Albums';
    }
  }

  IconData get icon {
    switch (this) {
      case _AlbumFilterType.recents:
        return Icons.photo_library_outlined;
      case _AlbumFilterType.favorites:
        return Icons.favorite_outline;
      case _AlbumFilterType.allAlbums:
        return Icons.grid_view_outlined;
    }
  }
}

/// Result from media picker
class _MediaPickerResult {
  final bool isCamera;
  final AssetEntity? asset;

  _MediaPickerResult.camera() : isCamera = true, asset = null;
  _MediaPickerResult.asset(this.asset) : isCamera = false;
}

/// Media picker bottom sheet
class _MediaPickerSheet extends StatefulWidget {
  const _MediaPickerSheet();

  @override
  State<_MediaPickerSheet> createState() => _MediaPickerSheetState();
}

class _MediaPickerSheetState extends State<_MediaPickerSheet> {
  List<AssetEntity> _recentAssets = [];
  bool _isLoadingAssets = true;
  _AlbumFilterType _selectedFilter = _AlbumFilterType.recents;
  List<AssetPathEntity> _allAlbums = [];
  AssetPathEntity? _selectedAlbum;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    setState(() => _isLoadingAssets = true);

    // Load all albums
    final allAlbums = await PhotoManager.getAssetPathList(
      type: RequestType.image, // Images only for signals
      hasAll: true,
    );
    _allAlbums = allAlbums;

    // Load assets based on filter
    await _loadAssetsForFilter(_selectedFilter);
  }

  Future<void> _loadAssetsForFilter(_AlbumFilterType filter) async {
    setState(() => _isLoadingAssets = true);

    List<AssetEntity> assets = [];

    switch (filter) {
      case _AlbumFilterType.recents:
        if (_allAlbums.isNotEmpty) {
          assets = await _allAlbums.first.getAssetListRange(start: 0, end: 100);
        }
        break;

      case _AlbumFilterType.favorites:
        AssetPathEntity? favAlbum;
        for (final album in _allAlbums) {
          if (album.name.toLowerCase().contains('favorite') ||
              album.name.toLowerCase().contains('favourite')) {
            favAlbum = album;
            break;
          }
        }
        if (favAlbum != null) {
          assets = await favAlbum.getAssetListRange(start: 0, end: 100);
        } else if (_allAlbums.isNotEmpty) {
          assets = await _allAlbums.first.getAssetListRange(start: 0, end: 100);
        }
        break;

      case _AlbumFilterType.allAlbums:
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

  void _changeFilter(_AlbumFilterType filter) {
    if (filter == _selectedFilter) return;
    setState(() {
      _selectedFilter = filter;
      _selectedAlbum = null;
    });
    _loadAssetsForFilter(filter);
  }

  void _selectAlbum(AssetPathEntity album) {
    setState(() {
      _selectedAlbum = album;
      _selectedFilter = _AlbumFilterType.allAlbums;
    });
    _loadAssetsForFilter(_AlbumFilterType.allAlbums);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
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
                      'Select Photo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // Album filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [_buildAlbumDropdown(), const Spacer()]),
            ),

            // Content
            Expanded(
              child: _isLoadingAssets
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : _selectedFilter == _AlbumFilterType.allAlbums &&
                        _selectedAlbum == null
                  ? _buildAlbumsList()
                  : _buildMediaGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumDropdown() {
    return PopupMenuButton<_AlbumFilterType>(
      offset: const Offset(0, 40),
      color: context.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: _changeFilter,
      itemBuilder: (context) => _AlbumFilterType.values.map((filter) {
        return PopupMenuItem<_AlbumFilterType>(
          value: filter,
          child: Row(
            children: [
              Icon(
                filter.icon,
                color: filter == _selectedFilter
                    ? context.accentColor
                    : context.textPrimary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                filter.label,
                style: TextStyle(
                  color: filter == _selectedFilter
                      ? context.accentColor
                      : context.textPrimary,
                  fontWeight: filter == _selectedFilter
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              if (filter == _selectedFilter) ...[
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
              _selectedAlbum?.name ?? _selectedFilter.label,
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
          return _CameraButton(
            onTap: () => Navigator.pop(context, _MediaPickerResult.camera()),
          );
        }

        final asset = _recentAssets[index - 1];
        return _MediaThumbnail(
          asset: asset,
          onTap: () => Navigator.pop(context, _MediaPickerResult.asset(asset)),
        );
      },
    );
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
  const _MediaThumbnail({required this.asset, required this.onTap});

  final AssetEntity asset;
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
          if (_thumbnailData != null)
            Image.memory(_thumbnailData!, fit: BoxFit.cover)
          else
            Container(color: Colors.grey[900]),
        ],
      ),
    );
  }
}

/// Album list tile for "All Albums" view
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
    _assetCount = await widget.album.assetCountAsync;

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
