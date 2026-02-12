// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../utils/snackbar.dart';
import '../../../services/haptic_service.dart';

/// Screen for admins to send broadcast push notifications to all users.
///
/// Sends notifications via the FCM 'announcements' topic that all users
/// are subscribed to on app launch.
class AdminBroadcastScreen extends ConsumerStatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  ConsumerState<AdminBroadcastScreen> createState() =>
      _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends ConsumerState<AdminBroadcastScreen>
    with StatefulLifecycleSafeMixin<AdminBroadcastScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _deepLinkController = TextEditingController();

  bool _isSending = false;
  bool _isCountingDown = false;
  int _countdown = 0;
  Timer? _countdownTimer;

  static const int _maxTitleLength = 100;
  static const int _maxBodyLength = 500;
  static const int _maxDeepLinkLength = 200;
  static const int _countdownSeconds = 5;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _titleController.dispose();
    _bodyController.dispose();
    _deepLinkController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    if (!_formKey.currentState!.validate()) return;

    ref.read(hapticServiceProvider).trigger(HapticType.medium);

    safeSetState(() {
      _isCountingDown = true;
      _countdown = _countdownSeconds;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_countdown <= 1) {
        timer.cancel();
        _sendBroadcast();
      } else {
        safeSetState(() => _countdown--);
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    ref.read(hapticServiceProvider).trigger(HapticType.light);
    safeSetState(() {
      _isCountingDown = false;
      _countdown = 0;
    });
  }

  Future<void> _sendBroadcast() async {
    if (!_formKey.currentState!.validate()) return;

    // Show final confirmation dialog
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: 'Final Confirmation',
      message:
          'This will send a push notification to ALL users of Socialmesh. '
          'This action cannot be undone.\n\n'
          'Title: ${_titleController.text.trim()}\n'
          'Body: ${_bodyController.text.trim()}',
      confirmLabel: 'Send Now',
      isDestructive: true,
    );

    if (confirmed != true || !mounted) {
      safeSetState(() {
        _isCountingDown = false;
        _countdown = 0;
      });
      return;
    }

    safeSetState(() {
      _isCountingDown = false;
      _isSending = true;
    });
    ref.read(hapticServiceProvider).trigger(HapticType.heavy);

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'broadcastPushNotification',
      );

      final result = await callable.call<Map<String, dynamic>>({
        'title': _titleController.text.trim(),
        'body': _bodyController.text.trim(),
        if (_deepLinkController.text.trim().isNotEmpty)
          'deepLink': _deepLinkController.text.trim(),
      });

      if (!mounted) return;

      final success = result.data['success'] as bool? ?? false;
      final messageId = result.data['messageId'] as String?;

      if (success) {
        ref.read(hapticServiceProvider).success();
        showSuccessSnackBar(
          context,
          'Broadcast sent successfully${messageId != null ? ' (ID: ${messageId.substring(0, 20)}...)' : ''}',
        );

        // Clear form after successful send
        _titleController.clear();
        _bodyController.clear();
        _deepLinkController.clear();
      } else {
        showErrorSnackBar(context, 'Failed to send broadcast');
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ref.read(hapticServiceProvider).error();
      showErrorSnackBar(
        context,
        e.message ?? 'Failed to send broadcast: ${e.code}',
      );
    } catch (e) {
      if (!mounted) return;
      ref.read(hapticServiceProvider).error();
      showErrorSnackBar(context, 'Failed to send broadcast: $e');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canInteract = !_isSending && !_isCountingDown;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold(
        title: 'Broadcast Notification',
        actions: [
          if (_isCountingDown)
            TextButton(
              onPressed: _cancelCountdown,
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.red.shade400,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            TextButton(
              onPressed: canInteract ? _startCountdown : null,
              child: _isSending
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.accentColor,
                      ),
                    )
                  : Text(
                      'Send',
                      style: TextStyle(
                        color: context.accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
        ],
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Warning banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange.shade400,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This will send a push notification to every '
                              'Socialmesh user. Use sparingly for important '
                              'announcements only.',
                              style: TextStyle(
                                fontSize: 13,
                                color: context.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Countdown indicator
                    if (_isCountingDown) ...[
                      _CountdownIndicator(
                        countdown: _countdown,
                        onCancel: _cancelCountdown,
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Title field
                    Text(
                      'Title',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      maxLength: _maxTitleLength,
                      enabled: canInteract,
                      decoration: InputDecoration(
                        hintText: 'Notification title...',
                        filled: true,
                        fillColor: context.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: context.border.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: context.accentColor,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.red.shade400),
                        ),
                        counterStyle: TextStyle(
                          color: context.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                      style: TextStyle(color: context.textPrimary),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Title is required';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Body field
                    Text(
                      'Message',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _bodyController,
                      maxLength: _maxBodyLength,
                      maxLines: 4,
                      enabled: canInteract,
                      decoration: InputDecoration(
                        hintText: 'Notification message...',
                        filled: true,
                        fillColor: context.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: context.border.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: context.accentColor,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.red.shade400),
                        ),
                        counterStyle: TextStyle(
                          color: context.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                      style: TextStyle(color: context.textPrimary),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Message is required';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Deep link field (optional)
                    Text(
                      'Deep Link (Optional)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Route to open when notification is tapped (e.g., /nodedex, /signals)',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _deepLinkController,
                      maxLength: _maxDeepLinkLength,
                      enabled: canInteract,
                      decoration: InputDecoration(
                        hintText: '/route-path',
                        filled: true,
                        fillColor: context.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: context.border.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: context.accentColor,
                            width: 2,
                          ),
                        ),
                        counterStyle: TextStyle(
                          color: context.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                      style: TextStyle(color: context.textPrimary),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _sendBroadcast(),
                    ),

                    const SizedBox(height: 32),

                    // Preview section
                    Text(
                      'PREVIEW',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: context.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _NotificationPreview(
                      title: _titleController.text.isEmpty
                          ? 'Notification Title'
                          : _titleController.text,
                      body: _bodyController.text.isEmpty
                          ? 'Notification message will appear here...'
                          : _bodyController.text,
                    ),

                    // Bottom padding
                    SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Countdown indicator with cancel button
class _CountdownIndicator extends StatelessWidget {
  const _CountdownIndicator({required this.countdown, required this.onCancel});

  final int countdown;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.red.shade400,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Sending in $countdown...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.red.shade400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Tap Cancel in the app bar to stop',
            style: TextStyle(fontSize: 13, color: context.textSecondary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.close),
              label: const Text('Cancel Broadcast'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade400,
                side: BorderSide(color: Colors.red.shade400),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Preview widget showing how the notification will appear
class _NotificationPreview extends StatelessWidget {
  const _NotificationPreview({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.hub, color: context.accentColor, size: 22),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'SOCIALMESH',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: context.textTertiary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'now',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.textSecondary,
                    height: 1.3,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
