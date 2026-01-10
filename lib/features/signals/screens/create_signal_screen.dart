import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

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
  int _ttlMinutes = SignalTTL.defaultTTL;
  PostLocation? _location;
  String? _imageLocalPath;

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
      _hasValidContent && _isDeviceConnected && _isAuthenticated;

  /// Get the reason why submission is blocked (for UI feedback)
  String? get _submitBlockedReason {
    if (!_isAuthenticated) return 'Sign in required';
    if (!_isDeviceConnected) return 'Device not connected';
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
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _imageLocalPath = result.files.first.path;
        });
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to pick image');
      }
    }
  }

  void _removeImage() {
    setState(() {
      _imageLocalPath = null;
    });
  }

  Future<void> _getLocation() async {
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

      setState(() {
        _location = PostLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          name: locationName,
        );
      });
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to get location');
      }
    }
  }

  void _removeLocation() {
    setState(() {
      _location = null;
    });
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
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_imageLocalPath!),
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
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
                    onTap: _isSubmitting ? null : _pickImage,
                    isSelected: _imageLocalPath != null,
                  ),
                  const SizedBox(width: 12),
                  _ActionButton(
                    icon: Icons.location_on_outlined,
                    label: 'Location',
                    onTap: _isSubmitting ? null : _getLocation,
                    isSelected: _location != null,
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
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isSelected;

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
