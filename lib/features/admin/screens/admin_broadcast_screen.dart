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
  bool _isSendingTest = false;
  bool _isCountingDown = false;
  int _countdown = 0;
  Timer? _countdownTimer;

  // Selected icon for the notification
  _NotificationIcon _selectedIcon = _NotificationIcon.announcement;

  static const int _maxTitleLength = 100;
  static const int _maxBodyLength = 500;
  static const int _maxDeepLinkLength = 200;
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
    _deepLinkController.dispose();
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
    final deepLink = _deepLinkController.text.trim();

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
      if (user == null) {
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
      await user.getIdToken(true);

      final callable = FirebaseFunctions.instance.httpsCallable(
        'broadcastPushNotification',
      );

      await callable.call<dynamic>({
        'title': title,
        'body': body,
        if (deepLink.isNotEmpty) 'deepLink': deepLink,
        'icon': _selectedIcon.fcmValue,
        if (testOnly) 'testOnly': true,
      });

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
        _deepLinkController.clear();
        safeSetState(() {
          _selectedIcon = _NotificationIcon.announcement;
        });
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      ref.read(hapticServiceProvider).trigger(HapticType.error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send: ${e.message}'),
          backgroundColor: Colors.red.shade400,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ref.read(hapticServiceProvider).trigger(HapticType.error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to send broadcast'),
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
                    safeSetState(() => _selectedIcon = icon);
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

                    // Countdown indicator
                    if (_isCountingDown) ...[
                      _CountdownIndicator(
                        countdown: _countdown,
                        onCancel: _cancelCountdown,
                      ),
                      const SizedBox(height: 24),
                    ],

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
                      onFieldSubmitted: (_) => _startCountdown(),
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
  ),
  update(
    icon: Icons.system_update,
    label: 'App Update',
    color: Colors.blue,
    fcmValue: 'update',
    category: _NotificationIconCategory.general,
  ),
  feature(
    icon: Icons.auto_awesome,
    label: 'New Feature',
    color: Colors.purple,
    fcmValue: 'feature',
    category: _NotificationIconCategory.general,
  ),
  maintenance(
    icon: Icons.build,
    label: 'Maintenance',
    color: Colors.amber,
    fcmValue: 'maintenance',
    category: _NotificationIconCategory.general,
  ),
  alert(
    icon: Icons.warning_amber,
    label: 'Alert',
    color: Colors.red,
    fcmValue: 'alert',
    category: _NotificationIconCategory.general,
  ),
  celebration(
    icon: Icons.celebration,
    label: 'Celebration',
    color: Colors.pink,
    fcmValue: 'celebration',
    category: _NotificationIconCategory.general,
  ),
  tip(
    icon: Icons.lightbulb,
    label: 'Tip',
    color: Colors.yellow,
    fcmValue: 'tip',
    category: _NotificationIconCategory.general,
  ),

  // === SOCIAL ===
  signals(
    icon: Icons.sensors,
    label: 'Signals',
    color: Colors.purple,
    fcmValue: 'signals',
    category: _NotificationIconCategory.social,
  ),
  nodedex(
    icon: Icons.auto_stories,
    label: 'NodeDex',
    color: Colors.amber,
    fcmValue: 'nodedex',
    category: _NotificationIconCategory.social,
  ),
  aether(
    icon: Icons.flight_takeoff,
    label: 'Aether',
    color: Colors.lightBlue,
    fcmValue: 'aether',
    category: _NotificationIconCategory.social,
  ),
  activity(
    icon: Icons.favorite,
    label: 'Activity',
    color: Colors.red,
    fcmValue: 'activity',
    category: _NotificationIconCategory.social,
  ),
  presence(
    icon: Icons.people_alt,
    label: 'Presence',
    color: Colors.green,
    fcmValue: 'presence',
    category: _NotificationIconCategory.social,
  ),
  community(
    icon: Icons.people,
    label: 'Community',
    color: Colors.teal,
    fcmValue: 'community',
    category: _NotificationIconCategory.social,
  ),
  worldMap(
    icon: Icons.public,
    label: 'World Map',
    color: Colors.blue,
    fcmValue: 'world_map',
    category: _NotificationIconCategory.social,
  ),

  // === PREMIUM ===
  themes(
    icon: Icons.palette,
    label: 'Theme Pack',
    color: Colors.purple,
    fcmValue: 'themes',
    category: _NotificationIconCategory.premium,
  ),
  ringtones(
    icon: Icons.music_note,
    label: 'Ringtone Pack',
    color: Colors.pink,
    fcmValue: 'ringtones',
    category: _NotificationIconCategory.premium,
  ),
  widgets(
    icon: Icons.widgets,
    label: 'Widgets',
    color: Colors.deepOrange,
    fcmValue: 'widgets',
    category: _NotificationIconCategory.premium,
  ),
  automations(
    icon: Icons.auto_awesome,
    label: 'Automations',
    color: Colors.yellow,
    fcmValue: 'automations',
    category: _NotificationIconCategory.premium,
  ),
  ifttt(
    icon: Icons.webhook,
    label: 'IFTTT Integration',
    color: Colors.blue,
    fcmValue: 'ifttt',
    category: _NotificationIconCategory.premium,
  );

  const _NotificationIcon({
    required this.icon,
    required this.label,
    required this.color,
    required this.fcmValue,
    required this.category,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String fcmValue;
  final _NotificationIconCategory category;

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

/// Countdown indicator shown before sending
class _CountdownIndicator extends StatelessWidget {
  const _CountdownIndicator({required this.countdown, required this.onCancel});

  final int countdown;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: countdown / 5,
                  strokeWidth: 3,
                  backgroundColor: Colors.red.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.red.shade400,
                  ),
                ),
                Text(
                  '$countdown',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sending in $countdown second${countdown == 1 ? '' : 's'}...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap Cancel to abort',
                  style: TextStyle(fontSize: 13, color: context.textSecondary),
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
