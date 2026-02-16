// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/legal/legal_constants.dart';
import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/widgets/ico_help_system.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/content_moderation_warning.dart';
import '../../../core/widgets/gradient_border_container.dart';
import '../../../core/widgets/local_image_gallery.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../models/presence_confidence.dart';
import '../../../models/social.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/presence_providers.dart';
import '../../../providers/signal_providers.dart';
import '../../../providers/social_providers.dart';
import '../../../providers/connectivity_providers.dart';
import '../../../providers/review_providers.dart';
import '../../../utils/location_privacy.dart';

import '../../../services/signal_service.dart';
import '../../settings/account_subscriptions_screen.dart';
import '../../settings/signal_settings_screen.dart';
import '../../../core/widgets/legal_document_sheet.dart';
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

class _CreateSignalScreenState extends ConsumerState<CreateSignalScreen>
    with TickerProviderStateMixin, LifecycleSafeMixin<CreateSignalScreen> {
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _statusController = TextEditingController();
  final FocusNode _contentFocusNode = FocusNode();

  // Track if we've shown the cloud banner animation this session
  static bool _hasShownCloudBannerHint = false;

  static const int _maxLength = 140;
  bool _isSubmitting = false;
  bool _isLoadingLocation = false;
  bool _isValidatingImage = false;
  bool _cloudBannerHighlight = false;
  int _ttlMinutes = SignalTTL.defaultTTL;
  PostLocation? _location;
  final List<String> _imageLocalPaths = [];
  final Set<int> _removingImageIndices =
      {}; // Track which images are animating out
  bool _imageHiddenDueToOffline =
      false; // Track if image was hidden due to going offline

  // Presence fields for composer
  PresenceIntent _selectedIntent = PresenceIntent.unknown;
  bool _loadedPresenceDefaults = false;

  final ImagePicker _imagePicker = ImagePicker();
  late final AnimationController _bannerShakeController;
  late final Animation<double> _bannerShakeAnimation;
  late final AnimationController _entryAnimationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final AnimationController _imageAnimationController;
  late final Animation<double> _imageScaleAnimation;
  late final Animation<double> _imageFadeAnimation;
  late final AnimationController _locationLoadingController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentFocusNode.requestFocus();
    });
    _bannerShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _bannerShakeAnimation = CurvedAnimation(
      parent: _bannerShakeController,
      curve: Curves.easeInOut,
    );
    _bannerShakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) setState(() => _cloudBannerHighlight = false);
        _bannerShakeController.reset();
      }
    });

    // Entry animations
    _entryAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entryAnimationController,
      curve: Curves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entryAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _entryAnimationController.forward();

    // Show cloud banner hint animation once per session if not signed in
    _entryAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_hasShownCloudBannerHint) {
        _maybeShowCloudBannerHint();
      }
    });

    // Image add/remove animations
    _imageAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _imageScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _imageAnimationController,
        curve: Curves.easeOutBack,
      ),
    );
    _imageFadeAnimation = CurvedAnimation(
      parent: _imageAnimationController,
      curve: Curves.easeOut,
    );

    // Location loading card animation
    _locationLoadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Load presence defaults from service
    _loadPresenceDefaults();
  }

  Future<void> _loadPresenceDefaults() async {
    if (_loadedPresenceDefaults) return;
    try {
      final service = ref.read(extendedPresenceServiceProvider);
      await service.init();
      final info = await service.getMyPresenceInfo();
      if (mounted) {
        setState(() {
          _selectedIntent = info.intent;
          if (info.shortStatus != null && info.shortStatus!.isNotEmpty) {
            _statusController.text = info.shortStatus!;
          }
          _loadedPresenceDefaults = true;
        });
      }
    } catch (_) {
      // Ignore errors loading defaults
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _statusController.dispose();
    _contentFocusNode.dispose();
    _bannerShakeController.dispose();
    _entryAnimationController.dispose();
    _imageAnimationController.dispose();
    _locationLoadingController.dispose();
    super.dispose();
  }

  /// Show the cloud banner hint animation once per session if user isn't signed in
  void _maybeShowCloudBannerHint() {
    if (!mounted) return;
    final connectivity = ref.read(signalConnectivityProvider);
    final meshOnlyDebug = ref.read(meshOnlyDebugModeProvider);
    final canUseCloud = connectivity.canUseCloud && !meshOnlyDebug;

    // Only show if not signed in and has internet (can sign in)
    if (!canUseCloud && connectivity.hasInternet) {
      _hasShownCloudBannerHint = true;
      // Small delay so user can see the screen first
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          HapticFeedback.lightImpact();
          setState(() => _cloudBannerHighlight = true);
          _bannerShakeController.forward(from: 0);
        }
      });
    }
  }

  /// Check basic content requirements (text not empty, within length limit)
  bool get _hasValidContent =>
      _contentController.text.trim().isNotEmpty &&
      _contentController.text.length <= _maxLength &&
      !_isSubmitting;

  /// Get the reason why submission is blocked (for UI feedback)
  String? _submitBlockedReason(bool isDeviceConnected) {
    if (!isDeviceConnected) return 'Device not connected';
    if (_isValidatingImage) return 'Processing image...';
    return null;
  }

  int get _remainingChars => _maxLength - _contentController.text.length;

  Future<void> _handleClose() async {
    _dismissKeyboard();
    if (_contentController.text.trim().isNotEmpty ||
        _imageLocalPaths.isNotEmpty) {
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
    // Capture all providers before any await
    final connectivity = ref.read(signalConnectivityProvider);
    final meshOnlyDebug = ref.read(meshOnlyDebugModeProvider);
    final moderationService = ref.read(contentModerationServiceProvider);
    final feedNotifier = ref.read(signalFeedProvider.notifier);
    final navigator = Navigator.of(context);

    // Connection gating check
    if (!connectivity.isBleConnected) {
      AppLogging.social('🚫 Send blocked: device not connected');
      showErrorSnackBar(context, 'Connect to a device to send signals');
      return;
    }

    // If images are still attached but cloud features are not available,
    // remove all images and refuse to send with only images.
    if (_imageLocalPaths.isNotEmpty &&
        (!connectivity.canUseCloud || meshOnlyDebug)) {
      safeSetState(() => _imageLocalPaths.clear());
      showErrorSnackBar(context, 'Images require internet. Images removed.');
      return;
    }

    if (!_hasValidContent) return;

    _dismissKeyboard();
    safeSetState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    final content = _contentController.text.trim();

    // Pre-submission content moderation check - only when cloud features available
    final canUseCloudNow = connectivity.canUseCloud && !meshOnlyDebug;
    if (content.isNotEmpty && canUseCloudNow) {
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
          safeSetState(() => _isSubmitting = false);
          if (action == ContentModerationAction.edit) {
            // User wants to edit - focus on content field
            safePostFrame(() {
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
    } else if (!canUseCloudNow) {
      AppLogging.social('SEND: mesh-only - skipping server moderation');
    }

    try {
      final canUseCloudNow2 = connectivity.canUseCloud && !meshOnlyDebug;

      // If location is being fetched, wait briefly (2s) for it to finish
      if (_isLoadingLocation) {
        final start = DateTime.now();
        final timeout = Duration(seconds: 2);
        while (_isLoadingLocation &&
            DateTime.now().difference(start) < timeout) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        if (_isLoadingLocation) {
          // Timed out - show a global snackbar (uses navigatorKey internally)
          showGlobalErrorSnackBar(
            'Location unavailable, sent without location.',
          );
        }
      }

      final sw = Stopwatch()..start();
      AppLogging.social(
        'SEND_PATH: start validation -> location -> db -> broadcast',
      );

      // Inform user that broadcast is in progress for mesh sends
      showGlobalInfoSnackBar(
        !canUseCloudNow2 ? 'Broadcasting over mesh...' : 'Sending...',
        duration: const Duration(seconds: 2),
      );

      // Build presence info from selected intent/status to embed in signal
      final trimmedStatus = _statusController.text.trim();
      final presenceToEmbed = ExtendedPresenceInfo(
        intent: _selectedIntent,
        shortStatus: trimmedStatus.isEmpty ? null : trimmedStatus,
      );
      final presenceJson = presenceToEmbed.hasData
          ? presenceToEmbed.toJson()
          : null;

      final signal = await feedNotifier.createSignal(
        content: _contentController.text.trim(),
        ttlMinutes: _ttlMinutes,
        location: _location,
        imageLocalPaths: _imageLocalPaths,
        // decide cloud usage at time of send
        // note: if offline this will be false
        useCloud: canUseCloudNow2,
        presenceInfo: presenceJson,
      );

      sw.stop();
      AppLogging.social('SEND_PATH: completed in ${sw.elapsedMilliseconds}ms');

      if (signal != null && mounted) {
        // Update presence with selected intent/status
        await _updatePresenceOnSend();

        if (!mounted) return;
        showSuccessSnackBar(context, 'Signal sent');
        navigator.pop();

        // Maybe prompt for review after successful signal creation
        // Use a short delay to let the navigation complete
        safeTimer(const Duration(milliseconds: 500), () {
          ref.maybePromptForReview(
            context,
            surface: 'signal_created',
            minSessions: 3, // Signals users are engaged
            minSinceInstall: const Duration(days: 3),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to create signal');
      }
    } finally {
      safeSetState(() => _isSubmitting = false);
    }
  }

  Future<void> _updatePresenceOnSend() async {
    try {
      // Provider was already captured in calling scope or capture here before await
      final service = ref.read(extendedPresenceServiceProvider);
      final trimmedStatus = _statusController.text.trim();

      // Update local settings
      await service.setMyIntent(_selectedIntent);
      await service.setMyStatus(trimmedStatus.isEmpty ? null : trimmedStatus);

      AppLogging.social(
        'Updated presence: intent=${_selectedIntent.name}, '
        'status=${trimmedStatus.isEmpty ? "none" : trimmedStatus}',
      );
    } catch (e) {
      AppLogging.social('Failed to update presence: $e');
    }
  }

  void _showIntentPicker() {
    _dismissKeyboard();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Your Intent',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Let others know why you\'re active',
                  style: TextStyle(color: context.textTertiary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ...PresenceIntent.values
                    .where((i) => i != PresenceIntent.unknown)
                    .map(
                      (intent) => _IntentOption(
                        intent: intent,
                        isSelected: _selectedIntent == intent,
                        onTap: () {
                          setState(() => _selectedIntent = intent);
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
                const SizedBox(height: 8),
                // Clear option
                _IntentOption(
                  intent: PresenceIntent.unknown,
                  isSelected: _selectedIntent == PresenceIntent.unknown,
                  label: 'No intent',
                  onTap: () {
                    setState(() => _selectedIntent = PresenceIntent.unknown);
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    _dismissKeyboard();

    // Capture providers before any await
    final connectivity = ref.read(signalConnectivityProvider);
    final meshOnlyDebug = ref.read(meshOnlyDebugModeProvider);
    final settingsFuture = ref.read(settingsServiceProvider.future);

    // Image selection requires cloud features (auth + internet)
    if (!connectivity.canUseCloud || meshOnlyDebug) {
      showErrorSnackBar(
        context,
        meshOnlyDebug
            ? 'Mesh-only debug mode enabled. Cloud features disabled.'
            : (connectivity.cloudDisabledReason ??
                  'Cloud features unavailable.'),
      );
      return;
    }

    // Check admin-configured limit
    final settings = await settingsFuture;
    final maxImages = settings.maxSignalImages;
    final remainingSlots = maxImages - _imageLocalPaths.length;

    if (remainingSlots <= 0) {
      if (mounted) {
        showErrorSnackBar(context, 'Maximum of $maxImages images allowed');
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
      List<String> newImagePaths = [];

      if (result.isCamera) {
        // Use camera - single image
        if (!mounted) return;

        final pickedFile = await _imagePicker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
        if (pickedFile != null) {
          newImagePaths.add(pickedFile.path);
        }
      } else {
        // Use gallery
        if (!mounted) return;

        if (remainingSlots == 1) {
          // Single image picker for last slot
          final pickedFile = await _imagePicker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1920,
            maxHeight: 1920,
            imageQuality: 85,
          );
          if (pickedFile != null) {
            newImagePaths.add(pickedFile.path);
          }
        } else {
          // Multi-select up to remaining slots
          final pickedFiles = await _imagePicker.pickMultiImage(
            maxWidth: 1920,
            maxHeight: 1920,
            imageQuality: 85,
            limit: remainingSlots, // Respect admin-configured max
          );

          if (pickedFiles.isNotEmpty) {
            newImagePaths.addAll(pickedFiles.map((f) => f.path));
          }
        }
      }

      // Batch validate all new images in parallel
      if (newImagePaths.isNotEmpty && mounted) {
        if (newImagePaths.length > 1) {
          showInfoSnackBar(
            context,
            'Validating ${newImagePaths.length} images...',
          );
        }

        final results = await _validateImagesInBatch(newImagePaths);

        if (!mounted) return;

        final passedCount = results.where((r) => r).length;
        final failedCount = results.length - passedCount;

        // Add images that passed validation
        for (var i = 0; i < results.length; i++) {
          if (results[i]) {
            _imageLocalPaths.add(newImagePaths[i]);
          }
        }

        // Show feedback
        if (failedCount > 0 && passedCount > 0) {
          showErrorSnackBar(
            context,
            '$failedCount image(s) blocked, $passedCount added',
          );
        } else if (failedCount > 0) {
          showErrorSnackBar(
            context,
            failedCount == 1
                ? 'Image violates content guidelines and was blocked'
                : '$failedCount images blocked by content guidelines',
          );
        } else if (passedCount > 0) {
          // Only show success if no failures
          if (passedCount > 1) {
            showSuccessSnackBar(context, '$passedCount images added');
          }
        }

        if (passedCount > 0) {
          safeSetState(() {}); // Trigger rebuild to show new images
          _imageAnimationController.forward(from: 0);
        }
      }
    }
  }

  /// Validate multiple images in parallel through content moderation.
  /// Returns list of bools indicating which images passed validation.
  /// Much faster than sequential validation for multiple images.
  Future<List<bool>> _validateImagesInBatch(List<String> localPaths) async {
    if (localPaths.isEmpty) return [];

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Can't validate without auth - allow all images (will be validated on upload)
      AppLogging.social(
        '[CreateSignal] Skipping batch image validation: not authenticated',
      );
      return List.filled(localPaths.length, true);
    }

    safeSetState(() => _isValidatingImage = true);

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // PHASE 1: PARALLEL UPLOAD - all images upload simultaneously
      AppLogging.social(
        '[CreateSignal] Starting batch upload of ${localPaths.length} images',
      );

      final uploadFutures = localPaths.asMap().entries.map((entry) async {
        final index = entry.key;
        final path = entry.value;

        final imageFile = File(path);
        if (!await imageFile.exists()) {
          AppLogging.social('[CreateSignal] Image $index not found: $path');
          return null;
        }

        final fileName = 'temp_${timestamp}_${currentUser.uid}_$index.jpg';
        final ref = FirebaseStorage.instance
            .ref()
            .child('signal_images_temp')
            .child(fileName);

        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'authorId': currentUser.uid,
            'uploadedAt': DateTime.now().toIso8601String(),
            'purpose': 'signal_validation_batch',
            'batchIndex': index.toString(),
            'batchSize': localPaths.length.toString(),
          },
        );

        try {
          await ref.putFile(imageFile, metadata);
          AppLogging.social(
            '[CreateSignal] Uploaded image $index: signal_images_temp/$fileName',
          );
          return fileName;
        } on FirebaseException catch (e) {
          AppLogging.social(
            '[CreateSignal] Upload error for image $index: ${e.code} - ${e.message}',
          );
          return null;
        }
      });

      final fileNames = await Future.wait(uploadFutures);

      // PHASE 2: PARALLEL MODERATION - wait for all results simultaneously
      AppLogging.social(
        '[CreateSignal] Waiting for ${fileNames.where((f) => f != null).length} moderation results',
      );

      final moderationFutures = fileNames.map((fileName) async {
        if (fileName == null) return false; // Upload failed

        final moderationDocId = 'post_${fileName.replaceAll('.jpg', '')}';

        try {
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
            AppLogging.social(
              '[CreateSignal] No moderation data for $moderationDocId',
            );
            return false;
          }

          final result = moderationData['result'] as Map<String, dynamic>?;
          final action = result?['action'] as String?;
          final passed = result?['passed'] as bool? ?? false;

          AppLogging.social(
            '[CreateSignal] Moderation for $fileName: action=$action, passed=$passed',
          );

          // Cleanup moderation doc after reading result
          await FirebaseFirestore.instance
              .collection('content_moderation')
              .doc(moderationDocId)
              .delete();

          return passed && action != 'reject';
        } catch (e) {
          AppLogging.social(
            '[CreateSignal] Moderation error for $fileName: $e',
          );
          return false;
        }
      });

      final results = await Future.wait(moderationFutures);

      // PHASE 3: PARALLEL CLEANUP - delete temp files
      final cleanupFutures = fileNames
          .where((fileName) => fileName != null)
          .map((fileName) {
            return FirebaseStorage.instance
                .ref()
                .child('signal_images_temp')
                .child(fileName!)
                .delete()
                .catchError((_) {}); // Ignore errors
          });

      Future.wait(cleanupFutures).ignore();

      final passedCount = results.where((r) => r).length;
      final failedCount = results.length - passedCount;

      AppLogging.social(
        '[CreateSignal] Batch validation complete: $passedCount passed, $failedCount failed',
      );

      return results;
    } catch (e) {
      AppLogging.social('[CreateSignal] Batch validation error: $e');
      if (mounted) {
        showErrorSnackBar(context, 'Failed to validate images');
      }
      return List.filled(localPaths.length, false);
    } finally {
      safeSetState(() => _isValidatingImage = false);
    }
  }

  void _removeImage(int index) async {
    // Mark image as removing to trigger animation
    safeSetState(() {
      _removingImageIndices.add(index);
    });

    // Wait for animation to complete
    await Future.delayed(const Duration(milliseconds: 250));

    if (!mounted) return;
    safeSetState(() {
      _imageLocalPaths.removeAt(index);
      _removingImageIndices.clear(); // Clear all removal states
    });
  }

  Future<void> _getLocation() async {
    // Capture providers BEFORE await
    final myNodeNum = ref.read(myNodeNumProvider);
    final nodes = ref.read(nodesProvider);

    safeSetState(() => _isLoadingLocation = true);
    _locationLoadingController.forward();

    try {
      final settingsFuture = ref.read(settingsServiceProvider.future);
      final settings = await settingsFuture;
      if (!mounted) return;

      if (myNodeNum == null) {
        showErrorSnackBar(context, 'No connected device location available');
        return;
      }

      final myNode = nodes[myNodeNum];
      final nodeLat = myNode?.latitude;
      final nodeLon = myNode?.longitude;

      if (nodeLat == null || nodeLon == null) {
        showActionSnackBar(
          context,
          'Device has no location yet. Enable GPS or set a fixed position.',
          actionLabel: 'Settings',
          type: SnackBarType.warning,
          onAction: () {
            if (!context.mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SignalSettingsScreen()),
            );
          },
        );
        return;
      }

      final radiusMeters = settings.signalLocationRadiusMeters;
      final safeLocation = LocationPrivacy.coarseFromCoordinates(
        latitude: nodeLat,
        longitude: nodeLon,
        radiusMeters: radiusMeters,
        name: 'Approx. area (~${radiusMeters}m)',
      );

      safeSetState(() => _location = safeLocation);
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Failed to get location');
    } finally {
      if (mounted) {
        // Fade out the loading card, then update state
        await _locationLoadingController.reverse();
        safeSetState(() => _isLoadingLocation = false);
      }
    }
  }

  void _removeLocation() {
    safeSetState(() {
      _location = null;
    });
  }

  void _showImagePreview(int index) {
    if (index < 0 || index >= _imageLocalPaths.length) return;

    LocalImageGallery.show(
      context,
      imagePaths: _imageLocalPaths,
      initialIndex: index,
    );
  }

  Widget _buildImagesGrid() {
    final imageCount = _imageLocalPaths.length;

    // Single image - full width
    if (imageCount == 1) {
      return _buildSingleImageCard(0);
    }

    // Multiple images - grid layout
    return Column(
      children: [
        // First row - always present
        Row(
          children: [
            Expanded(child: _buildImageThumbnail(0)),
            if (imageCount >= 2) ...[
              const SizedBox(width: 8),
              Expanded(child: _buildImageThumbnail(1)),
            ],
          ],
        ),
        // Second row - if 3 or 4 images
        if (imageCount >= 3) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildImageThumbnail(2)),
              if (imageCount >= 4) ...[
                const SizedBox(width: 8),
                Expanded(child: _buildImageThumbnail(3)),
              ],
            ],
          ),
        ],
        // Location info below grid if present
        if (_location != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _InfoPill(
                  icon: Icons.location_on,
                  label: _location!.name ?? 'Current location',
                ),
              ),
              const SizedBox(width: 8),
              BouncyTap(
                onTap: _isSubmitting ? null : _removeLocation,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: context.card,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.border.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: context.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSingleImageCard(int index) {
    final isRemoving = _removingImageIndices.contains(index);

    return AnimatedScale(
      scale: isRemoving ? 0.8 : 1.0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        opacity: isRemoving ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: GestureDetector(
          onTap: _isSubmitting ? null : () => _showImagePreview(index),
          child: ClipPath(
            clipper: _SquircleClipper(radius: 48),
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // The image
                  Container(
                    constraints: const BoxConstraints(maxHeight: 400),
                    width: double.infinity,
                    child: Image.file(
                      File(_imageLocalPaths[index]),
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Gradient overlay at bottom for pills
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Info pills at bottom
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Row(
                      children: [
                        // TTL pill
                        _InfoPill(
                          icon: Icons.timer_outlined,
                          label: _getTTLDisplayText(),
                        ),
                        const SizedBox(width: 8),
                        // Location pill with fade animation
                        IgnorePointer(
                          ignoring: _location == null,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _location != null ? 1.0 : 0.0,
                            child: GestureDetector(
                              onTap: _isSubmitting ? null : _removeLocation,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Local storage indicator
                        _InfoPill(icon: Icons.phone_android, label: 'Local'),
                      ],
                    ),
                  ),
                  // Remove button at top right
                  if (!_isSubmitting)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: BouncyTap(
                        onTap: () => _removeImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageThumbnail(int index) {
    final isRemoving = _removingImageIndices.contains(index);

    return AnimatedScale(
      scale: isRemoving ? 0.8 : 1.0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        opacity: isRemoving ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: GestureDetector(
          onTap: _isSubmitting ? null : () => _showImagePreview(index),
          child: ClipPath(
            clipper: _SquircleClipper(radius: 32),
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(File(_imageLocalPaths[index]), fit: BoxFit.cover),
                  // Dark overlay
                  Container(color: Colors.black.withValues(alpha: 0.1)),
                  // Remove button
                  if (!_isSubmitting)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: BouncyTap(
                        onTap: () => _removeImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getTTLDisplayText() {
    if (_ttlMinutes < 60) return '${_ttlMinutes}m';
    final hours = _ttlMinutes ~/ 60;
    final mins = _ttlMinutes % 60;
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  String _getTTLShortText() {
    if (_ttlMinutes < 60) return '${_ttlMinutes}m';
    final hours = _ttlMinutes ~/ 60;
    return '${hours}h';
  }

  void _showTTLPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Signal Duration',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'How long until your signal fades',
                style: TextStyle(color: context.textTertiary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TTLSelector(
                selectedMinutes: _ttlMinutes,
                onChanged: (minutes) {
                  setState(() => _ttlMinutes = minutes);
                  Navigator.of(ctx).pop();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myNodeNum = ref.watch(myNodeNumProvider);
    final nodes = ref.watch(nodesProvider);
    final myNode = myNodeNum != null ? nodes[myNodeNum] : null;
    final hasNodeLocation =
        myNode?.latitude != null && myNode?.longitude != null;
    final connectivity = ref.watch(signalConnectivityProvider);
    final meshOnlyDebug = ref.watch(meshOnlyDebugModeProvider);
    final settings = ref.watch(settingsServiceProvider).value;
    final signalRadiusMeters =
        settings?.signalLocationRadiusMeters ??
        kDefaultSignalLocationRadiusMeters;
    final canUseCloud = connectivity.canUseCloud && !meshOnlyDebug;
    final isDeviceConnected = connectivity.isBleConnected;
    // Location is "acquiring" if device is connected but no position yet
    final isAcquiringLocation = isDeviceConnected && !hasNodeLocation;
    final canSubmit =
        _hasValidContent && isDeviceConnected && !_isValidatingImage;
    final submitBlockedReason = _submitBlockedReason(isDeviceConnected);

    // Listen for cloud availability changes - hide/show images accordingly
    ref.listen<SignalConnectivityState>(signalConnectivityProvider, (
      previous,
      next,
    ) {
      final wasOnline = previous?.canUseCloud ?? true;
      final isOnline = next.canUseCloud && !meshOnlyDebug;

      if (wasOnline && !isOnline && _imageLocalPaths.isNotEmpty) {
        // Going offline with images - mark as hidden but don't remove
        setState(() => _imageHiddenDueToOffline = true);
        if (mounted) {
          showInfoSnackBar(
            context,
            'Images hidden while offline. They will return when back online.',
          );
        }
      } else if (!wasOnline && isOnline && _imageHiddenDueToOffline) {
        // Coming back online - restore the images visibility
        setState(() => _imageHiddenDueToOffline = false);
        if (mounted && _imageLocalPaths.isNotEmpty) {
          showSuccessSnackBar(context, 'Images restored!');
        }
      }
    });

    // Determine if images should be shown (exist and not hidden due to offline)
    final showImages = _imageLocalPaths.isNotEmpty && !_imageHiddenDueToOffline;

    final gradientColors = AccentColors.gradientFor(context.accentColor);

    return HelpTourController(
      topicId: 'signal_creation',
      stepKeys: const {},
      child: Scaffold(
        backgroundColor: context.background,
        appBar: AppBar(
          backgroundColor: context.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.close,
              color: _isSubmitting ? context.textTertiary : context.textPrimary,
            ),
            onPressed: _isSubmitting ? null : _handleClose,
          ),
          centerTitle: true,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Go Active',
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              if (myNodeNum != null)
                Text(
                  '!${myNodeNum.toRadixString(16).toUpperCase()}',
                  style: TextStyle(
                    color: context.accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.security_rounded,
                color: context.textSecondary,
                size: 20,
              ),
              tooltip: 'Your Responsibility',
              onPressed: () => LegalDocumentSheet.showTermsSection(
                context,
                LegalConstants.anchorAcceptableUse,
              ),
            ),
            const IcoHelpAppBarButton(topicId: 'signal_creation'),
          ],
        ),
        body: GestureDetector(
          onTap: _dismissKeyboard,
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (myNodeNum == null &&
                          connectivity.isBleConnected &&
                          Platform.isIOS) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
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
                                Icons.warning_amber_rounded,
                                size: 18,
                                color: context.textTertiary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Connected to BLE but no mesh traffic detected. On iOS, Airplane Mode can block BLE traffic even when connected. Turn off Airplane Mode or toggle Bluetooth.',
                                  style: TextStyle(
                                    color: context.textTertiary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Modern floating input container with gradient accent border
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: GradientBorderContainer(
                            borderRadius: 24,
                            borderWidth: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Text input area
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    16,
                                    20,
                                    8,
                                  ),
                                  child: TextField(
                                    controller: _contentController,
                                    focusNode: _contentFocusNode,
                                    enabled: !_isSubmitting,
                                    maxLines: 8,
                                    minLines: 5,
                                    maxLength: _maxLength,
                                    maxLengthEnforcement:
                                        MaxLengthEnforcement.enforced,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    inputFormatters: [
                                      LengthLimitingTextInputFormatter(
                                        _maxLength,
                                      ),
                                    ],
                                    style: TextStyle(
                                      color: context.textPrimary,
                                      fontSize: 16,
                                      height: 1.4,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'What are you signaling?',
                                      hintStyle: TextStyle(
                                        color: context.textTertiary,
                                        fontSize: 16,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      focusedErrorBorder: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                      counterText: '',
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                // Bottom action bar
                                Container(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    0,
                                    12,
                                    10,
                                  ),
                                  child: Row(
                                    children: [
                                      // Image button
                                      if (canUseCloud)
                                        _InputActionButton(
                                          icon: Icons.image_outlined,
                                          isSelected:
                                              _imageLocalPaths.isNotEmpty,
                                          isLoading: _isValidatingImage,
                                          label: _imageLocalPaths.isNotEmpty
                                              ? '${_imageLocalPaths.length}'
                                              : null,
                                          onTap: () {
                                            if (canUseCloud &&
                                                !_isSubmitting &&
                                                !_isValidatingImage) {
                                              _pickImage();
                                              return;
                                            }
                                            if (!canUseCloud &&
                                                connectivity.hasInternet) {
                                              HapticFeedback.mediumImpact();
                                              setState(
                                                () => _cloudBannerHighlight =
                                                    true,
                                              );
                                              _bannerShakeController.forward(
                                                from: 0,
                                              );
                                            }
                                          },
                                        ),
                                      // Location button (toggle: tap to add or remove)
                                      _InputActionButton(
                                        icon: _location != null
                                            ? Icons.location_off_outlined
                                            : Icons.location_on_outlined,
                                        isSelected: _location != null,
                                        isLoading:
                                            _isLoadingLocation ||
                                            isAcquiringLocation,
                                        isEnabled: hasNodeLocation,
                                        tooltip: hasNodeLocation
                                            ? (_location != null
                                                  ? 'Remove location'
                                                  : 'Add location')
                                            : (isAcquiringLocation
                                                  ? 'Acquiring device location...'
                                                  : 'No device connected'),
                                        onTap:
                                            _isSubmitting || _isLoadingLocation
                                            ? null
                                            : () {
                                                if (_location != null) {
                                                  _removeLocation();
                                                } else {
                                                  _getLocation();
                                                }
                                              },
                                        onDisabledTap:
                                            !hasNodeLocation &&
                                                !isAcquiringLocation
                                            ? () {
                                                HapticFeedback.lightImpact();
                                                showInfoSnackBar(
                                                  context,
                                                  'Connect a device to add location to your signal.',
                                                );
                                              }
                                            : null,
                                      ),
                                      // TTL button (shows current selection)
                                      _InputActionButton(
                                        icon: Icons.timer_outlined,
                                        label: _getTTLShortText(),
                                        onTap: _isSubmitting
                                            ? null
                                            : () => _showTTLPicker(context),
                                      ),
                                      // Settings
                                      _InputActionButton(
                                        icon: Icons.tune,
                                        isEnabled: hasNodeLocation,
                                        onTap: _isSubmitting || !hasNodeLocation
                                            ? null
                                            : () {
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        const SignalSettingsScreen(),
                                                  ),
                                                );
                                              },
                                      ),
                                      const Spacer(),
                                      // Character count
                                      SizedBox(
                                        width: 36,
                                        height: 36,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            CircularProgressIndicator(
                                              value:
                                                  (_contentController
                                                              .text
                                                              .length /
                                                          _maxLength)
                                                      .clamp(0.0, 1.0),
                                              strokeWidth: 2.5,
                                              backgroundColor: context.border
                                                  .withValues(alpha: 0.2),
                                              color: _remainingChars < 0
                                                  ? Colors.red
                                                  : _remainingChars < 20
                                                  ? Colors.orange
                                                  : context.accentColor,
                                            ),
                                            Text(
                                              '$_remainingChars',
                                              style: TextStyle(
                                                color: _remainingChars < 0
                                                    ? Colors.red
                                                    : _remainingChars < 20
                                                    ? Colors.orange
                                                    : context.textTertiary,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Intent picker row
                      const SizedBox(height: 16),
                      _PresenceIntentRow(
                        intent: _selectedIntent,
                        onTap: _isSubmitting ? null : _showIntentPicker,
                      ),

                      // Short status field
                      const SizedBox(height: 12),
                      _ShortStatusField(
                        controller: _statusController,
                        enabled: !_isSubmitting,
                        onChanged: (_) => setState(() {}),
                      ),

                      // Images preview grid
                      if (showImages) ...[
                        const SizedBox(height: 16),
                        ScaleTransition(
                          scale: _imageScaleAnimation,
                          child: FadeTransition(
                            opacity: _imageFadeAnimation,
                            child: _buildImagesGrid(),
                          ),
                        ),
                      ],

                      // Location loading indicator
                      if (_isLoadingLocation && _location == null) ...[
                        const SizedBox(height: 12),
                        FadeTransition(
                          opacity: _locationLoadingController,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: context.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: context.border.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: context.accentColor,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Retrieving device location...',
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      // Location preview (only if no images - otherwise shown as pill on image)
                      if (_location != null && !showImages) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: context.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: context.border.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 18,
                                color: context.accentColor,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _location!.name ?? 'Current location',
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 14,
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

                      const SizedBox(height: 16),

                      // Privacy note
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 14,
                            color: context.textTertiary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Signal location uses mesh device position, rounded to ~${signalRadiusMeters}m.',
                              style: TextStyle(
                                color: context.textTertiary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Cloud availability banner
                      if (!canUseCloud)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Builder(
                            builder: (context) {
                              final canTapToSubscribe =
                                  !meshOnlyDebug && connectivity.hasInternet;
                              final banner = Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: context.accentColor.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: context.accentColor.withValues(
                                      alpha: 0.4,
                                    ),
                                    width: _cloudBannerHighlight ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.cloud_off,
                                      size: 18,
                                      color: context.accentColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        meshOnlyDebug
                                            ? 'Mesh-only debug mode enabled. Signals use local DB + mesh only.'
                                            : connectivity.hasInternet
                                            ? 'Sign in to enable images and cloud features.'
                                            : 'Offline: images and cloud features unavailable.',
                                        style: TextStyle(
                                          color: context.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    if (canTapToSubscribe) ...[
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.chevron_right,
                                        size: 20,
                                        color: context.accentColor,
                                      ),
                                    ],
                                  ],
                                ),
                              );

                              final animatedBanner = AnimatedBuilder(
                                animation: _bannerShakeAnimation,
                                builder: (ctx, child) {
                                  final t = _bannerShakeAnimation.value;
                                  final dx = sin(t * pi * 4) * 8; // shake
                                  return Transform.translate(
                                    offset: Offset(dx, 0),
                                    child: child,
                                  );
                                },
                                child: banner,
                              );

                              if (!canTapToSubscribe) {
                                return GestureDetector(
                                  onTap: _dismissKeyboard,
                                  child: animatedBanner,
                                );
                              }

                              return BouncyTap(
                                onTap: () {
                                  _dismissKeyboard();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const AccountSubscriptionsScreen(),
                                    ),
                                  );
                                },
                                child: animatedBanner,
                              );
                            },
                          ),
                        ),

                      if (Platform.isIOS &&
                          !connectivity.hasInternet &&
                          connectivity.isBleConnected)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
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
                                  Icons.airplanemode_active,
                                  size: 18,
                                  color: context.textTertiary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'iOS Airplane Mode can pause BLE mesh traffic even when connected. If signals stop, turn off Airplane Mode or toggle Bluetooth.',
                                    style: TextStyle(
                                      color: context.textTertiary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Info banner
                      StatusBanner(
                        type: StatusBannerType.custom,
                        color: context.textTertiary,
                        title:
                            'Signals are temporary. They fade automatically and exist only while active.',
                        borderRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom send button
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: _entryAnimationController,
                          curve: const Interval(
                            0.3,
                            1.0,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                      ),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      12 + MediaQuery.of(context).padding.bottom,
                    ),
                    decoration: BoxDecoration(
                      color: context.background,
                      border: Border(
                        top: BorderSide(
                          color: context.border.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    child: Tooltip(
                      message: submitBlockedReason ?? '',
                      child: BouncyTap(
                        onTap: canSubmit ? _submitSignal : null,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: canSubmit
                                ? LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      gradientColors[0],
                                      gradientColors[1],
                                    ],
                                  )
                                : null,
                            color: canSubmit
                                ? null
                                : context.border.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: canSubmit
                                ? [
                                    BoxShadow(
                                      color: gradientColors[0].withValues(
                                        alpha: 0.4,
                                      ),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: _isSubmitting
                              ? const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.sensors,
                                      size: 22,
                                      color: canSubmit
                                          ? Colors.white
                                          : context.textTertiary,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Send Signal',
                                      style: TextStyle(
                                        color: canSubmit
                                            ? Colors.white
                                            : context.textTertiary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Result from media picker
class _MediaPickerResult {
  final bool isCamera;

  _MediaPickerResult.camera() : isCamera = true;
  _MediaPickerResult.gallery() : isCamera = false;
}

/// Simple media picker bottom sheet with Camera/Gallery options
class _MediaPickerSheet extends StatelessWidget {
  const _MediaPickerSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              const Text(
                'Add Photos',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),

              // Camera option
              _PickerOption(
                icon: Icons.camera_alt,
                label: 'Take Photo',
                subtitle: 'Use camera',
                onTap: () =>
                    Navigator.pop(context, _MediaPickerResult.camera()),
              ),

              const SizedBox(height: 12),

              // Gallery option
              _PickerOption(
                icon: Icons.photo_library,
                label: 'Choose from Gallery',
                subtitle: 'Select up to 4 photos',
                onTap: () =>
                    Navigator.pop(context, _MediaPickerResult.gallery()),
              ),

              const SizedBox(height: 12),

              // Cancel button
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Option button for picker sheet
class _PickerOption extends StatelessWidget {
  const _PickerOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Info pill widget for image overlay
class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Input action button for the floating input bar
class _InputActionButton extends StatelessWidget {
  const _InputActionButton({
    required this.icon,
    this.label,
    this.onTap,
    this.onDisabledTap,
    this.isSelected = false,
    this.isLoading = false,
    this.isEnabled = true,
    this.tooltip,
  });

  final IconData icon;
  final String? label;
  final VoidCallback? onTap;
  final VoidCallback? onDisabledTap;
  final bool isSelected;
  final bool isLoading;
  final bool isEnabled;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? context.accentColor
        : (isEnabled ? context.textSecondary : context.textTertiary);

    Widget button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? onTap : onDisabledTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.accentColor,
                  ),
                )
              else
                Icon(icon, size: 20, color: color),
              if (label != null) ...[
                const SizedBox(width: 4),
                Text(
                  label!,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// Squircle clipper using ContinuousRectangleBorder for iOS-style rounded corners
class _SquircleClipper extends CustomClipper<Path> {
  _SquircleClipper({required this.radius});

  final double radius;

  @override
  Path getClip(Size size) {
    return ContinuousRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    ).getOuterPath(Rect.fromLTWH(0, 0, size.width, size.height));
  }

  @override
  bool shouldReclip(_SquircleClipper oldClipper) => oldClipper.radius != radius;
}

/// Tappable row for selecting presence intent
class _PresenceIntentRow extends StatelessWidget {
  const _PresenceIntentRow({required this.intent, this.onTap});

  final PresenceIntent intent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasIntent = intent != PresenceIntent.unknown;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasIntent
                ? context.accentColor.withValues(alpha: 0.4)
                : context.border.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              PresenceIntentIcons.iconFor(intent),
              size: 20,
              color: hasIntent ? context.accentColor : context.textTertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Intent',
                    style: TextStyle(
                      color: context.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasIntent ? intent.label : 'Tap to set',
                    style: TextStyle(
                      color: hasIntent
                          ? context.textPrimary
                          : context.textTertiary,
                      fontSize: 14,
                      fontWeight: hasIntent ? FontWeight.w500 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: context.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// Option row in the intent picker bottom sheet
class _IntentOption extends StatelessWidget {
  const _IntentOption({
    required this.intent,
    required this.isSelected,
    required this.onTap,
    this.label,
  });

  final PresenceIntent intent;
  final bool isSelected;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final displayLabel = label ?? intent.label;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? context.accentColor.withValues(alpha: 0.15)
              : context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? context.accentColor.withValues(alpha: 0.5)
                : context.border.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              PresenceIntentIcons.iconFor(intent),
              size: 22,
              color: isSelected ? context.accentColor : context.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                displayLabel,
                style: TextStyle(
                  color: isSelected ? context.accentColor : context.textPrimary,
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, size: 20, color: context.accentColor),
          ],
        ),
      ),
    );
  }
}

/// Short status text field with character counter
class _ShortStatusField extends StatelessWidget {
  const _ShortStatusField({
    required this.controller,
    required this.enabled,
    this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  static const int _maxLength = ExtendedPresenceInfo.maxStatusLength;

  @override
  Widget build(BuildContext context) {
    final remaining = _maxLength - controller.text.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.short_text,
              size: 20,
              color: context.textTertiary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Short Status (optional)',
                  style: TextStyle(
                    color: context.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: controller,
                  enabled: enabled,
                  maxLength: _maxLength,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(color: context.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. "On the trail near summit"',
                    hintStyle: TextStyle(
                      color: context.textTertiary,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    counterText: '',
                  ),
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              '$remaining',
              style: TextStyle(
                color: remaining < 10 ? Colors.orange : context.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
