// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';

import '../../../core/logging.dart';
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

  bool _isSending = false;
  bool _isSendingTest = false;
  bool _isCountingDown = false;
  int _countdown = 0;
  Timer? _countdownTimer;

  // Selected icon for the notification
  _NotificationIcon _selectedIcon = _NotificationIcon.announcement;

  // Selected deep link (optional)
  _DeepLink? _selectedDeepLink;

  static const int _maxTitleLength = 100;
  static const int _maxBodyLength = 500;
  static const int _countdownSeconds = 5;

  @override
  void initState() {
    super.initState();
    // Add listeners to update preview live
    _titleController.addListener(_onTextChanged);
    _bodyController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _titleController.removeListener(_onTextChanged);
    _bodyController.removeListener(_onTextChanged);
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // Trigger rebuild to update preview
    safeSetState(() {});
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

  Future<void> _sendBroadcast({bool testOnly = false}) async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final deepLink = _selectedDeepLink?.path ?? '';

    safeSetState(() {
      if (testOnly) {
        _isSendingTest = true;
      } else {
        _isSending = true;
        _isCountingDown = false;
      }
    });

    try {
      // Force-refresh the auth token to avoid stale token errors
      final user = FirebaseAuth.instance.currentUser;
      AppLogging.app(
        '[Broadcast] Auth state: user=${user?.uid ?? 'NULL'}, '
        'email=${user?.email ?? 'none'}, '
        'isAnonymous=${user?.isAnonymous}, '
        'testOnly=$testOnly',
      );

      if (user == null) {
        AppLogging.app('[Broadcast] ABORT: No Firebase user');
        if (!mounted) return;
        ref.read(hapticServiceProvider).trigger(HapticType.error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('You must be signed in to send notifications'),
            backgroundColor: Colors.red.shade400,
          ),
        );
        return;
      }

      AppLogging.app('[Broadcast] Refreshing ID token...');
      final idToken = await user.getIdToken(true);
      AppLogging.app(
        '[Broadcast] Token refreshed: ${idToken != null ? '${idToken.length} chars' : 'NULL'}',
      );

      final payload = <String, dynamic>{
        'title': title,
        'body': body,
        if (deepLink.isNotEmpty) 'deepLink': deepLink,
        'icon': _selectedIcon.fcmValue,
        if (testOnly) 'testOnly': true,
      };
      AppLogging.app('[Broadcast] Payload: $payload');

      final callable = FirebaseFunctions.instance.httpsCallable(
        'broadcastPushNotification',
      );

      AppLogging.app('[Broadcast] Calling function...');
      await callable.call<dynamic>(payload);
      AppLogging.app('[Broadcast] Function call succeeded');

      if (!mounted) return;

      ref.read(hapticServiceProvider).trigger(HapticType.success);

      // Show success confirmation
      await AppBottomSheet.show(
        context: context,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade400, size: 48),
            const SizedBox(height: 16),
            Text(
              testOnly ? 'Test Sent' : 'Broadcast Sent',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              testOnly
                  ? 'Your test notification has been sent to all admins.'
                  : 'Your notification has been sent to all Socialmesh users.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: context.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      );

      if (!mounted) return;

      // Only clear form after full broadcast, not test
      if (!testOnly) {
        _titleController.clear();
        _bodyController.clear();
        safeSetState(() {
          _selectedIcon = _NotificationIcon.announcement;
          _selectedDeepLink = null;
        });
      }
    } on FirebaseFunctionsException catch (e, stack) {
      AppLogging.app(
        '[Broadcast] FirebaseFunctionsException: '
        'code=${e.code}, message=${e.message}, '
        'details=${e.details}',
      );
      AppLogging.app('[Broadcast] Stack: $stack');
      if (!mounted) return;

      ref.read(hapticServiceProvider).trigger(HapticType.error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send: ${e.code} - ${e.message}'),
          backgroundColor: Colors.red.shade400,
        ),
      );
    } catch (e, stack) {
      AppLogging.app('[Broadcast] Unexpected error: $e');
      AppLogging.app('[Broadcast] Stack: $stack');
      if (!mounted) return;

      ref.read(hapticServiceProvider).trigger(HapticType.error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send: $e'),
          backgroundColor: Colors.red.shade400,
        ),
      );
    } finally {
      if (mounted) {
        safeSetState(() {
          _isSending = false;
          _isSendingTest = false;
        });
      }
    }
  }

  Future<void> _sendTestToAdmins() async {
    ref.read(hapticServiceProvider).trigger(HapticType.medium);
    await _sendBroadcast(testOnly: true);
  }

  void _clearForm() {
    ref.read(hapticServiceProvider).trigger(HapticType.light);
    _titleController.clear();
    _bodyController.clear();
    safeSetState(() {
      _selectedIcon = _NotificationIcon.announcement;
      _selectedDeepLink = null;
    });
  }

  void _showDeepLinkPicker() {
    ref.read(hapticServiceProvider).trigger(HapticType.selection);
    AppBottomSheet.show(
      context: context,
      padding: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Text(
                'Select Deep Link',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: _DeepLinkPickerContent(
                  selectedDeepLink: _selectedDeepLink,
                  onDeepLinkSelected: (deepLink) {
                    safeSetState(() => _selectedDeepLink = deepLink);
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showIconPicker() {
    ref.read(hapticServiceProvider).trigger(HapticType.selection);
    AppBottomSheet.show(
      context: context,
      padding: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Text(
                'Select Icon',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: _IconPickerContent(
                  selectedIcon: _selectedIcon,
                  onIconSelected: (icon) {
                    final previous = _selectedIcon;
                    safeSetState(() => _selectedIcon = icon);
                    // Auto-fill title/body if empty or still matches previous defaults
                    final currentTitle = _titleController.text.trim();
                    final currentBody = _bodyController.text.trim();
                    if (currentTitle.isEmpty ||
                        currentTitle == previous.defaultTitle) {
                      _titleController.text = icon.defaultTitle;
                    }
                    if (currentBody.isEmpty ||
                        currentBody == previous.defaultBody) {
                      _bodyController.text = icon.defaultBody;
                    }
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canInteract = !_isSending && !_isCountingDown && !_isSendingTest;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold(
        title: 'Broadcast Notification',
        actions: const [],
        slivers: [
          // Pinned preview header
          SliverPersistentHeader(
            pinned: true,
            delegate: _PreviewHeaderDelegate(
              title: _titleController.text.isEmpty
                  ? 'Notification Title'
                  : _titleController.text,
              body: _bodyController.text.isEmpty
                  ? 'Notification message will appear here...'
                  : _bodyController.text,
              icon: _selectedIcon,
            ),
          ),

          // Form content
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

                    // Icon selector
                    Text(
                      'Icon',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: canInteract ? _showIconPicker : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
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
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _selectedIcon.color.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _selectedIcon.icon,
                                color: _selectedIcon.color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedIcon.label,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: context.textPrimary,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: context.textTertiary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Clear form button
                    if (_titleController.text.isNotEmpty ||
                        _bodyController.text.isNotEmpty ||
                        _selectedDeepLink != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: canInteract ? _clearForm : null,
                          icon: Icon(
                            Icons.clear_all,
                            size: 18,
                            color: context.textTertiary,
                          ),
                          label: Text(
                            'Clear',
                            style: TextStyle(
                              fontSize: 13,
                              color: context.textTertiary,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),

                    const SizedBox(height: 8),

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

                    // Deep link selector (optional)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Deep Link (Optional)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                          ),
                        ),
                        if (_selectedDeepLink != null)
                          GestureDetector(
                            onTap: canInteract
                                ? () {
                                    ref
                                        .read(hapticServiceProvider)
                                        .trigger(HapticType.light);
                                    safeSetState(
                                      () => _selectedDeepLink = null,
                                    );
                                  }
                                : null,
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: context.textTertiary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Screen to open when notification is tapped.',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: canInteract ? _showDeepLinkPicker : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
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
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color:
                                    (_selectedDeepLink?.color ??
                                            context.textTertiary)
                                        .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _selectedDeepLink?.icon ?? Icons.link_off,
                                color:
                                    _selectedDeepLink?.color ??
                                    context.textTertiary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedDeepLink?.label ?? 'None',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: _selectedDeepLink != null
                                          ? context.textPrimary
                                          : context.textTertiary,
                                    ),
                                  ),
                                  if (_selectedDeepLink != null)
                                    Text(
                                      _selectedDeepLink!.path,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.textTertiary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: context.textTertiary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Test to Admins button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: canInteract ? _sendTestToAdmins : null,
                        icon: _isSendingTest
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: context.accentColor,
                                ),
                              )
                            : Icon(
                                Icons.science_outlined,
                                color: context.accentColor,
                              ),
                        label: Text(
                          _isSendingTest
                              ? 'Sending Test...'
                              : 'Test to Admins Only',
                          style: TextStyle(color: context.accentColor),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: context.accentColor.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Send a test notification to admins before broadcasting to all users.',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 24),

                    // Send to Everyone button (with countdown)
                    if (_isCountingDown)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _cancelCountdown,
                          icon: const Icon(Icons.cancel_outlined, size: 20),
                          label: Text('Cancel — sending in $_countdown...'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: canInteract ? _startCountdown : null,
                          icon: _isSending
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 20),
                          label: Text(
                            _isSending ? 'Sending...' : 'Send to Everyone',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Sends a push notification to all Socialmesh users. '
                      'A ${_countdownSeconds}s countdown gives you time to cancel.',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                      ),
                      textAlign: TextAlign.center,
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

/// Available notification icons
enum _NotificationIconCategory { general, social, premium }

enum _NotificationIcon {
  // === GENERAL ===
  announcement(
    icon: Icons.campaign,
    label: 'Announcement',
    color: Colors.orange,
    fcmValue: 'announcement',
    category: _NotificationIconCategory.general,
    defaultTitle: 'Announcement',
    defaultBody:
        'We have an important announcement for the Socialmesh community.',
  ),
  update(
    icon: Icons.system_update,
    label: 'App Update',
    color: Colors.blue,
    fcmValue: 'update',
    category: _NotificationIconCategory.general,
    defaultTitle: 'App Update Available',
    defaultBody:
        'A new version of Socialmesh is available with improvements and bug fixes.',
  ),
  feature(
    icon: Icons.auto_awesome,
    label: 'New Feature',
    color: Colors.purple,
    fcmValue: 'feature',
    category: _NotificationIconCategory.general,
    defaultTitle: 'New Feature',
    defaultBody: 'We just launched a new feature in Socialmesh. Check it out!',
  ),
  maintenance(
    icon: Icons.build,
    label: 'Maintenance',
    color: Colors.amber,
    fcmValue: 'maintenance',
    category: _NotificationIconCategory.general,
    defaultTitle: 'Scheduled Maintenance',
    defaultBody:
        'Socialmesh services will be briefly unavailable for scheduled maintenance.',
  ),
  alert(
    icon: Icons.warning_amber,
    label: 'Alert',
    color: Colors.red,
    fcmValue: 'alert',
    category: _NotificationIconCategory.general,
    defaultTitle: 'Important Alert',
    defaultBody: 'Please be aware of an important issue affecting Socialmesh.',
  ),
  celebration(
    icon: Icons.celebration,
    label: 'Celebration',
    color: Colors.pink,
    fcmValue: 'celebration',
    category: _NotificationIconCategory.general,
    defaultTitle: 'Celebration',
    defaultBody:
        'We have something exciting to celebrate with the Socialmesh community!',
  ),
  tip(
    icon: Icons.lightbulb,
    label: 'Tip',
    color: Colors.yellow,
    fcmValue: 'tip',
    category: _NotificationIconCategory.general,
    defaultTitle: 'Pro Tip',
    defaultBody: 'Here is a helpful tip to get the most out of Socialmesh.',
  ),

  // === SOCIAL ===
  signals(
    icon: Icons.sensors,
    label: 'Signals',
    color: Colors.purple,
    fcmValue: 'signals',
    category: _NotificationIconCategory.social,
    defaultTitle: 'Signals Update',
    defaultBody: 'Check out what is new in Signals, your mesh presence feed.',
  ),
  nodedex(
    icon: Icons.auto_stories,
    label: 'NodeDex',
    color: Colors.amber,
    fcmValue: 'nodedex',
    category: _NotificationIconCategory.social,
    defaultTitle: 'NodeDex Update',
    defaultBody:
        'NodeDex has new features for discovering and tracking mesh nodes.',
  ),
  aether(
    icon: Icons.flight_takeoff,
    label: 'Aether',
    color: Colors.lightBlue,
    fcmValue: 'aether',
    category: _NotificationIconCategory.social,
    defaultTitle: 'Aether Update',
    defaultBody: 'New improvements to Aether flight sharing are now live.',
  ),
  activity(
    icon: Icons.favorite,
    label: 'Activity',
    color: Colors.red,
    fcmValue: 'activity',
    category: _NotificationIconCategory.social,
    defaultTitle: 'Activity Update',
    defaultBody: 'See what is happening in your Activity feed.',
  ),
  presence(
    icon: Icons.people_alt,
    label: 'Presence',
    color: Colors.green,
    fcmValue: 'presence',
    category: _NotificationIconCategory.social,
    defaultTitle: 'Presence Update',
    defaultBody:
        'Presence detection has been improved for better mesh awareness.',
  ),
  community(
    icon: Icons.people,
    label: 'Community',
    color: Colors.teal,
    fcmValue: 'community',
    category: _NotificationIconCategory.social,
    defaultTitle: 'Community Update',
    defaultBody: 'Join the latest Socialmesh community initiatives.',
  ),
  worldMap(
    icon: Icons.public,
    label: 'World Map',
    color: Colors.blue,
    fcmValue: 'world_map',
    category: _NotificationIconCategory.social,
    defaultTitle: 'World Map Update',
    defaultBody:
        'The World Mesh Map has new features for exploring global mesh coverage.',
  ),

  // === PREMIUM ===
  themes(
    icon: Icons.palette,
    label: 'Theme Pack',
    color: Colors.purple,
    fcmValue: 'themes',
    category: _NotificationIconCategory.premium,
    defaultTitle: 'New Theme Pack',
    defaultBody: 'A new theme pack is now available in the Socialmesh store.',
  ),
  ringtones(
    icon: Icons.music_note,
    label: 'Ringtone Pack',
    color: Colors.pink,
    fcmValue: 'ringtones',
    category: _NotificationIconCategory.premium,
    defaultTitle: 'New Ringtone Pack',
    defaultBody:
        'A new ringtone pack is now available for your mesh notifications.',
  ),
  widgets(
    icon: Icons.widgets,
    label: 'Widgets',
    color: Colors.deepOrange,
    fcmValue: 'widgets',
    category: _NotificationIconCategory.premium,
    defaultTitle: 'New Widgets',
    defaultBody: 'New home screen widgets are now available for Socialmesh.',
  ),
  automations(
    icon: Icons.auto_awesome,
    label: 'Automations',
    color: Colors.yellow,
    fcmValue: 'automations',
    category: _NotificationIconCategory.premium,
    defaultTitle: 'Automations Update',
    defaultBody: 'New automation triggers and actions are now available.',
  ),
  ifttt(
    icon: Icons.webhook,
    label: 'IFTTT Integration',
    color: Colors.blue,
    fcmValue: 'ifttt',
    category: _NotificationIconCategory.premium,
    defaultTitle: 'IFTTT Integration',
    defaultBody: 'Connect Socialmesh with your favourite services via IFTTT.',
  );

  const _NotificationIcon({
    required this.icon,
    required this.label,
    required this.color,
    required this.fcmValue,
    required this.category,
    required this.defaultTitle,
    required this.defaultBody,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String fcmValue;
  final _NotificationIconCategory category;
  final String defaultTitle;
  final String defaultBody;

  static List<_NotificationIcon> byCategory(_NotificationIconCategory cat) {
    return values.where((v) => v.category == cat).toList();
  }
}

/// Pinned header delegate for the notification preview
class _PreviewHeaderDelegate extends SliverPersistentHeaderDelegate {
  _PreviewHeaderDelegate({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final _NotificationIcon icon;

  @override
  double get minExtent => 140;

  @override
  double get maxExtent => 140;

  @override
  bool shouldRebuild(covariant _PreviewHeaderDelegate oldDelegate) {
    return title != oldDelegate.title ||
        body != oldDelegate.body ||
        icon != oldDelegate.icon;
  }

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: context.background,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'PREVIEW',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: context.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _NotificationPreview(title: title, body: body, icon: icon),
          ),
        ],
      ),
    );
  }
}

/// Visual preview of how the notification will appear
class _NotificationPreview extends StatelessWidget {
  const _NotificationPreview({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final _NotificationIcon icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
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
          // App icon with selected notification icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: icon.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon.icon, color: icon.color, size: 22),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                  maxLines: 2,
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

/// Icon picker bottom sheet content with categorised sections.
class _IconPickerContent extends StatelessWidget {
  const _IconPickerContent({
    required this.selectedIcon,
    required this.onIconSelected,
  });

  final _NotificationIcon selectedIcon;
  final void Function(_NotificationIcon) onIconSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSection(context, 'GENERAL', _NotificationIconCategory.general),
          const SizedBox(height: 12),
          _buildSection(context, 'SOCIAL', _NotificationIconCategory.social),
          const SizedBox(height: 12),
          _buildSection(context, 'PREMIUM', _NotificationIconCategory.premium),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    _NotificationIconCategory category,
  ) {
    final icons = _NotificationIcon.byCategory(category);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: context.textTertiary,
            ),
          ),
        ),
        ...icons.map((icon) {
          final isSelected = icon == selectedIcon;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              onTap: () => onIconSelected(icon),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? icon.color.withValues(alpha: 0.15)
                      : context.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? icon.color.withValues(alpha: 0.5)
                        : context.border.withValues(alpha: 0.3),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: icon.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon.icon, color: icon.color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        icon.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: icon.color, size: 22),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// Deep link categories for the picker
enum _DeepLinkCategory { core, social, mesh, premium }

/// Available deep link routes for broadcast notifications
enum _DeepLink {
  // === CORE ===
  settings(
    path: '/settings',
    label: 'Settings',
    icon: Icons.settings,
    color: Colors.blueGrey,
    category: _DeepLinkCategory.core,
  ),
  account(
    path: '/account',
    label: 'Account & Subscriptions',
    icon: Icons.account_circle,
    color: Colors.indigo,
    category: _DeepLinkCategory.core,
  ),
  scanner(
    path: '/scanner',
    label: 'Scanner',
    icon: Icons.bluetooth_searching,
    color: Colors.blue,
    category: _DeepLinkCategory.core,
  ),
  messages(
    path: '/messages',
    label: 'Messages',
    icon: Icons.chat,
    color: Colors.green,
    category: _DeepLinkCategory.core,
  ),
  channels(
    path: '/channels',
    label: 'Channels',
    icon: Icons.forum,
    color: Colors.teal,
    category: _DeepLinkCategory.core,
  ),
  nodes(
    path: '/nodes',
    label: 'Nodes',
    icon: Icons.router,
    color: Colors.orange,
    category: _DeepLinkCategory.core,
  ),
  map(
    path: '/map',
    label: 'Map',
    icon: Icons.map,
    color: Colors.green,
    category: _DeepLinkCategory.core,
  ),

  // === SOCIAL ===
  signals(
    path: '/signals',
    label: 'Signals',
    icon: Icons.sensors,
    color: Colors.purple,
    category: _DeepLinkCategory.social,
  ),
  nodedex(
    path: '/nodedex',
    label: 'NodeDex',
    icon: Icons.auto_stories,
    color: Colors.amber,
    category: _DeepLinkCategory.social,
  ),
  aether(
    path: '/aether',
    label: 'Aether',
    icon: Icons.flight_takeoff,
    color: Colors.lightBlue,
    category: _DeepLinkCategory.social,
  ),
  activity(
    path: '/activity',
    label: 'Activity',
    icon: Icons.favorite,
    color: Colors.red,
    category: _DeepLinkCategory.social,
  ),
  presence(
    path: '/presence',
    label: 'Presence',
    icon: Icons.people_alt,
    color: Colors.green,
    category: _DeepLinkCategory.social,
  ),

  // === MESH ===
  timeline(
    path: '/timeline',
    label: 'Timeline',
    icon: Icons.timeline,
    color: Colors.cyan,
    category: _DeepLinkCategory.mesh,
  ),
  worldMap(
    path: '/world-map',
    label: 'World Map',
    icon: Icons.public,
    color: Colors.blue,
    category: _DeepLinkCategory.mesh,
  ),
  globe(
    path: '/globe',
    label: '3D Globe',
    icon: Icons.language,
    color: Colors.indigo,
    category: _DeepLinkCategory.mesh,
  ),
  reachability(
    path: '/reachability',
    label: 'Reachability',
    icon: Icons.cell_tower,
    color: Colors.deepOrange,
    category: _DeepLinkCategory.mesh,
  ),

  // === PREMIUM ===
  themes(
    path: '/themes',
    label: 'Theme Pack',
    icon: Icons.palette,
    color: Colors.purple,
    category: _DeepLinkCategory.premium,
  ),
  ringtones(
    path: '/ringtones',
    label: 'Ringtone Pack',
    icon: Icons.music_note,
    color: Colors.pink,
    category: _DeepLinkCategory.premium,
  ),
  widgets(
    path: '/widgets',
    label: 'Widgets',
    icon: Icons.widgets,
    color: Colors.deepOrange,
    category: _DeepLinkCategory.premium,
  ),
  automations(
    path: '/automations',
    label: 'Automations',
    icon: Icons.auto_awesome,
    color: Colors.yellow,
    category: _DeepLinkCategory.premium,
  ),
  ifttt(
    path: '/ifttt',
    label: 'IFTTT Integration',
    icon: Icons.webhook,
    color: Colors.blue,
    category: _DeepLinkCategory.premium,
  );

  const _DeepLink({
    required this.path,
    required this.label,
    required this.icon,
    required this.color,
    required this.category,
  });

  final String path;
  final String label;
  final IconData icon;
  final Color color;
  final _DeepLinkCategory category;

  static List<_DeepLink> byCategory(_DeepLinkCategory cat) {
    return values.where((v) => v.category == cat).toList();
  }
}

/// Deep link picker bottom sheet content with categorised sections.
class _DeepLinkPickerContent extends StatelessWidget {
  const _DeepLinkPickerContent({
    required this.selectedDeepLink,
    required this.onDeepLinkSelected,
  });

  final _DeepLink? selectedDeepLink;
  final void Function(_DeepLink) onDeepLinkSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSection(context, 'CORE', _DeepLinkCategory.core),
          const SizedBox(height: 12),
          _buildSection(context, 'SOCIAL', _DeepLinkCategory.social),
          const SizedBox(height: 12),
          _buildSection(context, 'MESH', _DeepLinkCategory.mesh),
          const SizedBox(height: 12),
          _buildSection(context, 'PREMIUM', _DeepLinkCategory.premium),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    _DeepLinkCategory category,
  ) {
    final links = _DeepLink.byCategory(category);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: context.textTertiary,
            ),
          ),
        ),
        ...links.map((link) {
          final isSelected = link == selectedDeepLink;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              onTap: () => onDeepLinkSelected(link),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? link.color.withValues(alpha: 0.15)
                      : context.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? link.color.withValues(alpha: 0.5)
                        : context.border.withValues(alpha: 0.3),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: link.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(link.icon, color: link.color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            link.label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: context.textPrimary,
                            ),
                          ),
                          Text(
                            link.path,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: link.color, size: 22),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
