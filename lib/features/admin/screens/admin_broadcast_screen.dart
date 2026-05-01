// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: haptic-feedback — most GestureDetectors are keyboard dismissal or conditional function refs

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../utils/snackbar.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/chip_selector.dart';
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

  bool _didSeedDefaults = false;
  bool _isSending = false;
  bool _isSendingTest = false;
  bool _isCountingDown = false;
  int _countdown = 0;
  Timer? _countdownTimer;

  // Selected icon for the notification
  _NotificationIcon _selectedIcon = _NotificationIcon.announcement;

  // Selected deep link (optional)
  _DeepLink? _selectedDeepLink;

  // Target platform for the broadcast
  _TargetPlatform _selectedPlatform = _TargetPlatform.all;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didSeedDefaults) {
      _didSeedDefaults = true;
      _titleController.text = _selectedIcon.defaultTitleL10n(context);
      _bodyController.text = _selectedIcon.defaultBodyL10n(context);
    }
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

    final l10n = context.l10n;

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
        safeShowSnackBar(
          l10n.adminBroadcastSignInRequired,
          type: SnackBarType.error,
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
        'targetPlatform': _selectedPlatform.fcmValue,
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
            const SizedBox(height: AppTheme.spacing16),
            Text(
              testOnly
                  ? l10n.adminBroadcastTestSentTitle
                  : l10n.adminBroadcastSentTitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              testOnly
                  ? l10n.adminBroadcastTestSentBody
                  : l10n.adminBroadcastSentBody,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: context.textSecondary),
            ),
            const SizedBox(height: AppTheme.spacing24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.adminBroadcastDone),
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
      safeShowSnackBar(
        l10n.adminBroadcastFailedDetailed(e.code, e.message ?? ''),
        type: SnackBarType.error,
      );
    } catch (e, stack) {
      AppLogging.app('[Broadcast] Unexpected error: $e');
      AppLogging.app('[Broadcast] Stack: $stack');
      if (!mounted) return;

      ref.read(hapticServiceProvider).trigger(HapticType.error);
      safeShowSnackBar(
        l10n.adminBroadcastFailed('$e'),
        type: SnackBarType.error,
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
    safeSetState(() {
      _selectedIcon = _NotificationIcon.announcement;
      _selectedDeepLink = null;
      _selectedPlatform = _TargetPlatform.all;
    });
    _titleController.text = _selectedIcon.defaultTitleL10n(context);
    _bodyController.text = _selectedIcon.defaultBodyL10n(context);
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
              padding: const EdgeInsets.fromLTRB(AppTheme.spacing24, 0, 24, 16),
              child: Text(
                context.l10n.adminBroadcastSelectDeepLink,
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
              padding: const EdgeInsets.fromLTRB(AppTheme.spacing24, 0, 24, 16),
              child: Text(
                context.l10n.adminBroadcastSelectIcon,
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
                        currentTitle == previous.defaultTitleL10n(context)) {
                      _titleController.text = icon.defaultTitleL10n(context);
                    }
                    if (currentBody.isEmpty ||
                        currentBody == previous.defaultBodyL10n(context)) {
                      _bodyController.text = icon.defaultBodyL10n(context);
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
        title: context.l10n.adminBroadcastTitle,
        actions: const [],
        slivers: [
          // Pinned preview header
          SliverPersistentHeader(
            pinned: true,
            delegate: _PreviewHeaderDelegate(
              title: _titleController.text.isEmpty
                  ? context.l10n.adminBroadcastPreviewTitlePlaceholder
                  : _titleController.text,
              body: _bodyController.text.isEmpty
                  ? context.l10n.adminBroadcastPreviewBodyPlaceholder
                  : _bodyController.text,
              icon: _selectedIcon,
            ),
          ),

          // Form content
          SliverPadding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            sliver: SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Warning banner
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacing12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
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
                          const SizedBox(width: AppTheme.spacing12),
                          Expanded(
                            child: Text(
                              context.l10n.adminBroadcastWarning,
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

                    const SizedBox(height: AppTheme.spacing24),

                    // Icon selector
                    Text(
                      context.l10n.adminBroadcastIconLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    GestureDetector(
                      onTap: canInteract ? _showIconPicker : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius12,
                          ),
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
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius8,
                                ),
                              ),
                              child: Icon(
                                _selectedIcon.icon,
                                color: _selectedIcon.color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacing12),
                            Expanded(
                              child: Text(
                                _selectedIcon.labelL10n(context),
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

                    const SizedBox(height: AppTheme.spacing16),

                    // Platform target selector
                    Text(
                      context.l10n.adminBroadcastPlatformLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing4),
                    Text(
                      context.l10n.adminBroadcastPlatformHelper,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    ChipSelector<_TargetPlatform>(
                      value: _selectedPlatform,
                      enabled: canInteract,
                      onChanged: (platform) {
                        ref
                            .read(hapticServiceProvider)
                            .trigger(HapticType.selection);
                        safeSetState(() => _selectedPlatform = platform);
                      },
                      options: [
                        for (final platform in _TargetPlatform.values)
                          ChipOption(
                            value: platform,
                            label: platform.labelL10n(context),
                            icon: platform.icon,
                            color: platform.chipColor,
                          ),
                      ],
                    ),

                    const SizedBox(height: AppTheme.spacing16),

                    // Clear form button
                    if (_titleController.text.isNotEmpty ||
                        _bodyController.text.isNotEmpty ||
                        _selectedDeepLink != null ||
                        _selectedPlatform != _TargetPlatform.all)
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
                            context.l10n.adminBroadcastClear,
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

                    const SizedBox(height: AppTheme.spacing8),

                    // Title field
                    Text(
                      context.l10n.adminBroadcastFieldTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    TextFormField(
                      controller: _titleController,
                      maxLength: _maxTitleLength,
                      enabled: canInteract,
                      decoration: InputDecoration(
                        hintText: context.l10n.adminBroadcastTitleHint,
                        filled: true,
                        fillColor: context.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius12,
                          ),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius12,
                          ),
                          borderSide: BorderSide(
                            color: context.border.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius12,
                          ),
                          borderSide: BorderSide(
                            color: context.accentColor,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius12,
                          ),
                          borderSide: BorderSide(color: Colors.red.shade400),
                        ),
                        counterStyle: TextStyle(
                          color: context.textTertiary,
                          fontSize: 12,
                        ),
                        counterText: '',
                      ),
                      style: TextStyle(color: context.textPrimary),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return context.l10n.adminBroadcastTitleRequired;
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: AppTheme.spacing16),

                    // Body field
                    Text(
                      context.l10n.adminBroadcastFieldMessage,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    TextFormField(
                      controller: _bodyController,
                      maxLength: _maxBodyLength,
                      maxLines: 4,
                      enabled: canInteract,
                      decoration: InputDecoration(
                        hintText: context.l10n.adminBroadcastMessageHint,
                        filled: true,
                        fillColor: context.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius12,
                          ),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius12,
                          ),
                          borderSide: BorderSide(
                            color: context.border.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius12,
                          ),
                          borderSide: BorderSide(
                            color: context.accentColor,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius12,
                          ),
                          borderSide: BorderSide(color: Colors.red.shade400),
                        ),
                        counterStyle: TextStyle(
                          color: context.textTertiary,
                          fontSize: 12,
                        ),
                        counterText: '',
                      ),
                      style: TextStyle(color: context.textPrimary),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return context.l10n.adminBroadcastMessageRequired;
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: AppTheme.spacing16),

                    // Deep link selector (optional)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.adminBroadcastDeepLinkLabel,
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
                    const SizedBox(height: AppTheme.spacing4),
                    Text(
                      context.l10n.adminBroadcastDeepLinkHelper,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    GestureDetector(
                      onTap: canInteract ? _showDeepLinkPicker : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius12,
                          ),
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
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius8,
                                ),
                              ),
                              child: Icon(
                                _selectedDeepLink?.icon ?? Icons.link_off,
                                color:
                                    _selectedDeepLink?.color ??
                                    context.textTertiary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacing12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedDeepLink?.labelL10n(context) ??
                                        context.l10n.adminBroadcastDeepLinkNone,
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

                    const SizedBox(height: AppTheme.spacing24),

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
                              ? context.l10n.adminBroadcastSendingTest
                              : context.l10n.adminBroadcastTestButton,
                          style: TextStyle(color: context.accentColor),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: context.accentColor.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    Text(
                      context.l10n.adminBroadcastTestHint,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: AppTheme.spacing24),

                    // Send to Everyone button (with countdown)
                    if (_isCountingDown)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _cancelCountdown,
                          icon: const Icon(Icons.cancel_outlined, size: 20),
                          label: Text(
                            context.l10n.adminBroadcastCountdownCancel(
                              _countdown,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius12,
                              ),
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
                            _isSending
                                ? context.l10n.adminBroadcastSending
                                : context.l10n.adminBroadcastSendAll,
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: AppTheme.spacing8),
                    Text(
                      context.l10n.adminBroadcastSendHint(_countdownSeconds),
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

/// Target platform for broadcast push notifications.
///
/// The selected value is sent as `targetPlatform` in the Cloud Function
/// payload. The CF should route to the corresponding FCM topic:
/// - [all]     → `announcements`          (all devices)
/// - [android] → `announcements_android`  (Android devices only)
/// - [ios]     → `announcements_ios`       (iOS devices only)
enum _TargetPlatform {
  all,
  android,
  ios;

  /// Value sent in the Cloud Function payload.
  String get fcmValue => name;

  String labelL10n(BuildContext context) {
    return switch (this) {
      all => context.l10n.adminBroadcastPlatformAll,
      android => context.l10n.adminBroadcastPlatformAndroid,
      ios => context.l10n.adminBroadcastPlatformIos,
    };
  }

  IconData get icon {
    return switch (this) {
      all => Icons.devices,
      android => Icons.android,
      ios => Icons.apple,
    };
  }

  Color get chipColor {
    return switch (this) {
      all => AppTheme.primaryBlue,
      android => AppTheme.successGreen,
      ios => AppTheme.primaryMagenta,
    };
  }
}

enum _NotificationIcon {
  // === GENERAL ===
  announcement(
    icon: Icons.campaign,
    color: Colors.orange,
    fcmValue: 'announcement',
    category: _NotificationIconCategory.general,
  ),
  update(
    icon: Icons.system_update,
    color: Colors.blue,
    fcmValue: 'update',
    category: _NotificationIconCategory.general,
  ),
  feature(
    icon: Icons.auto_awesome,
    color: Colors.purple,
    fcmValue: 'feature',
    category: _NotificationIconCategory.general,
  ),
  maintenance(
    icon: Icons.build,
    color: Colors.amber,
    fcmValue: 'maintenance',
    category: _NotificationIconCategory.general,
  ),
  alert(
    icon: Icons.warning_amber,
    color: Colors.red,
    fcmValue: 'alert',
    category: _NotificationIconCategory.general,
  ),
  celebration(
    icon: Icons.celebration,
    color: Colors.pink,
    fcmValue: 'celebration',
    category: _NotificationIconCategory.general,
  ),
  tip(
    icon: Icons.lightbulb,
    color: Colors.yellow,
    fcmValue: 'tip',
    category: _NotificationIconCategory.general,
  ),

  // === SOCIAL ===
  signals(
    icon: Icons.sensors,
    color: Colors.purple,
    fcmValue: 'signals',
    category: _NotificationIconCategory.social,
  ),
  nodedex(
    icon: Icons.auto_stories,
    color: Colors.amber,
    fcmValue: 'nodedex',
    category: _NotificationIconCategory.social,
  ),
  aether(
    icon: Icons.flight_takeoff,
    color: Colors.lightBlue,
    fcmValue: 'aether',
    category: _NotificationIconCategory.social,
  ),
  activity(
    icon: Icons.favorite,
    color: Colors.red,
    fcmValue: 'activity',
    category: _NotificationIconCategory.social,
  ),
  presence(
    icon: Icons.people_alt,
    color: Colors.green,
    fcmValue: 'presence',
    category: _NotificationIconCategory.social,
  ),
  community(
    icon: Icons.people,
    color: Colors.teal,
    fcmValue: 'community',
    category: _NotificationIconCategory.social,
  ),
  worldMap(
    icon: Icons.public,
    color: Colors.blue,
    fcmValue: 'world_map',
    category: _NotificationIconCategory.social,
  ),

  // === PREMIUM ===
  themes(
    icon: Icons.palette,
    color: Colors.purple,
    fcmValue: 'themes',
    category: _NotificationIconCategory.premium,
  ),
  ringtones(
    icon: Icons.music_note,
    color: Colors.pink,
    fcmValue: 'ringtones',
    category: _NotificationIconCategory.premium,
  ),
  widgets(
    icon: Icons.widgets,
    color: Colors.deepOrange,
    fcmValue: 'widgets',
    category: _NotificationIconCategory.premium,
  ),
  automations(
    icon: Icons.auto_awesome,
    color: Colors.yellow,
    fcmValue: 'automations',
    category: _NotificationIconCategory.premium,
  ),
  ifttt(
    icon: Icons.webhook,
    color: Colors.blue,
    fcmValue: 'ifttt',
    category: _NotificationIconCategory.premium,
  );

  const _NotificationIcon({
    required this.icon,
    required this.color,
    required this.fcmValue,
    required this.category,
  });

  final IconData icon;
  final Color color;
  final String fcmValue;
  final _NotificationIconCategory category;

  String labelL10n(BuildContext context) {
    return switch (this) {
      announcement => context.l10n.adminBroadcastIconAnnouncement,
      update => context.l10n.adminBroadcastIconUpdate,
      feature => context.l10n.adminBroadcastIconFeature,
      maintenance => context.l10n.adminBroadcastIconMaintenance,
      alert => context.l10n.adminBroadcastIconAlert,
      celebration => context.l10n.adminBroadcastIconCelebration,
      tip => context.l10n.adminBroadcastIconTip,
      signals => context.l10n.adminBroadcastIconSignals,
      nodedex => context.l10n.adminBroadcastIconNodedex,
      aether => context.l10n.adminBroadcastIconAether,
      activity => context.l10n.adminBroadcastIconActivity,
      presence => context.l10n.adminBroadcastIconPresence,
      community => context.l10n.adminBroadcastIconCommunity,
      worldMap => context.l10n.adminBroadcastIconWorldMap,
      themes => context.l10n.adminBroadcastIconThemes,
      ringtones => context.l10n.adminBroadcastIconRingtones,
      widgets => context.l10n.adminBroadcastIconWidgets,
      automations => context.l10n.adminBroadcastIconAutomations,
      ifttt => context.l10n.adminBroadcastIconIfttt,
    };
  }

  String defaultTitleL10n(BuildContext context) {
    return switch (this) {
      announcement => context.l10n.adminBroadcastDefTitleAnnouncement,
      update => context.l10n.adminBroadcastDefTitleUpdate,
      feature => context.l10n.adminBroadcastDefTitleFeature,
      maintenance => context.l10n.adminBroadcastDefTitleMaintenance,
      alert => context.l10n.adminBroadcastDefTitleAlert,
      celebration => context.l10n.adminBroadcastDefTitleCelebration,
      tip => context.l10n.adminBroadcastDefTitleTip,
      signals => context.l10n.adminBroadcastDefTitleSignals,
      nodedex => context.l10n.adminBroadcastDefTitleNodedex,
      aether => context.l10n.adminBroadcastDefTitleAether,
      activity => context.l10n.adminBroadcastDefTitleActivity,
      presence => context.l10n.adminBroadcastDefTitlePresence,
      community => context.l10n.adminBroadcastDefTitleCommunity,
      worldMap => context.l10n.adminBroadcastDefTitleWorldMap,
      themes => context.l10n.adminBroadcastDefTitleThemes,
      ringtones => context.l10n.adminBroadcastDefTitleRingtones,
      widgets => context.l10n.adminBroadcastDefTitleWidgets,
      automations => context.l10n.adminBroadcastDefTitleAutomations,
      ifttt => context.l10n.adminBroadcastDefTitleIfttt,
    };
  }

  String defaultBodyL10n(BuildContext context) {
    return switch (this) {
      announcement => context.l10n.adminBroadcastDefBodyAnnouncement,
      update => context.l10n.adminBroadcastDefBodyUpdate,
      feature => context.l10n.adminBroadcastDefBodyFeature,
      maintenance => context.l10n.adminBroadcastDefBodyMaintenance,
      alert => context.l10n.adminBroadcastDefBodyAlert,
      celebration => context.l10n.adminBroadcastDefBodyCelebration,
      tip => context.l10n.adminBroadcastDefBodyTip,
      signals => context.l10n.adminBroadcastDefBodySignals,
      nodedex => context.l10n.adminBroadcastDefBodyNodedex,
      aether => context.l10n.adminBroadcastDefBodyAether,
      activity => context.l10n.adminBroadcastDefBodyActivity,
      presence => context.l10n.adminBroadcastDefBodyPresence,
      community => context.l10n.adminBroadcastDefBodyCommunity,
      worldMap => context.l10n.adminBroadcastDefBodyWorldMap,
      themes => context.l10n.adminBroadcastDefBodyThemes,
      ringtones => context.l10n.adminBroadcastDefBodyRingtones,
      widgets => context.l10n.adminBroadcastDefBodyWidgets,
      automations => context.l10n.adminBroadcastDefBodyAutomations,
      ifttt => context.l10n.adminBroadcastDefBodyIfttt,
    };
  }

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
      padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.adminBroadcastPreviewLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: context.textTertiary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
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
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
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
              borderRadius: BorderRadius.circular(AppTheme.radius10),
            ),
            child: Icon(icon.icon, color: icon.color, size: 22),
          ),
          const SizedBox(width: AppTheme.spacing12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      context.l10n.adminBroadcastPreviewAppName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: context.textTertiary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      context.l10n.adminBroadcastPreviewNow,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing4),
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
                const SizedBox(height: AppTheme.spacing2),
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
          _buildSection(
            context,
            context.l10n.adminBroadcastIconCatGeneral,
            _NotificationIconCategory.general,
          ),
          const SizedBox(height: AppTheme.spacing12),
          _buildSection(
            context,
            context.l10n.adminBroadcastIconCatSocial,
            _NotificationIconCategory.social,
          ),
          const SizedBox(height: AppTheme.spacing12),
          _buildSection(
            context,
            context.l10n.adminBroadcastIconCatPremium,
            _NotificationIconCategory.premium,
          ),
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
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
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
                        borderRadius: BorderRadius.circular(AppTheme.radius10),
                      ),
                      child: Icon(icon.icon, color: icon.color, size: 22),
                    ),
                    const SizedBox(width: AppTheme.spacing12),
                    Expanded(
                      child: Text(
                        icon.labelL10n(context),
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
    icon: Icons.settings,
    color: Colors.blueGrey,
    category: _DeepLinkCategory.core,
  ),
  account(
    path: '/account',
    icon: Icons.account_circle,
    color: Colors.indigo,
    category: _DeepLinkCategory.core,
  ),
  scanner(
    path: '/scanner',
    icon: Icons.bluetooth_searching,
    color: Colors.blue,
    category: _DeepLinkCategory.core,
  ),
  messages(
    path: '/messages',
    icon: Icons.chat,
    color: Colors.green,
    category: _DeepLinkCategory.core,
  ),
  channels(
    path: '/channels',
    icon: Icons.forum,
    color: Colors.teal,
    category: _DeepLinkCategory.core,
  ),
  nodes(
    path: '/nodes',
    icon: Icons.router,
    color: Colors.orange,
    category: _DeepLinkCategory.core,
  ),
  map(
    path: '/map',
    icon: Icons.map,
    color: Colors.green,
    category: _DeepLinkCategory.core,
  ),

  // === SOCIAL ===
  signals(
    path: '/signals',
    icon: Icons.sensors,
    color: Colors.purple,
    category: _DeepLinkCategory.social,
  ),
  nodedex(
    path: '/nodedex',
    icon: Icons.auto_stories,
    color: Colors.amber,
    category: _DeepLinkCategory.social,
  ),
  aether(
    path: '/aether',
    icon: Icons.flight_takeoff,
    color: Colors.lightBlue,
    category: _DeepLinkCategory.social,
  ),
  activity(
    path: '/activity',
    icon: Icons.favorite,
    color: Colors.red,
    category: _DeepLinkCategory.social,
  ),
  presence(
    path: '/presence',
    icon: Icons.people_alt,
    color: Colors.green,
    category: _DeepLinkCategory.social,
  ),

  // === MESH ===
  timeline(
    path: '/timeline',
    icon: Icons.timeline,
    color: Colors.cyan,
    category: _DeepLinkCategory.mesh,
  ),
  worldMap(
    path: '/world-map',
    icon: Icons.public,
    color: Colors.blue,
    category: _DeepLinkCategory.mesh,
  ),
  globe(
    path: '/globe',
    icon: Icons.language,
    color: Colors.indigo,
    category: _DeepLinkCategory.mesh,
  ),
  reachability(
    path: '/reachability',
    icon: Icons.cell_tower,
    color: Colors.deepOrange,
    category: _DeepLinkCategory.mesh,
  ),

  // === PREMIUM ===
  themes(
    path: '/themes',
    icon: Icons.palette,
    color: Colors.purple,
    category: _DeepLinkCategory.premium,
  ),
  ringtones(
    path: '/ringtones',
    icon: Icons.music_note,
    color: Colors.pink,
    category: _DeepLinkCategory.premium,
  ),
  widgets(
    path: '/widgets',
    icon: Icons.widgets,
    color: Colors.deepOrange,
    category: _DeepLinkCategory.premium,
  ),
  automations(
    path: '/automations',
    icon: Icons.auto_awesome,
    color: Colors.yellow,
    category: _DeepLinkCategory.premium,
  ),
  ifttt(
    path: '/ifttt',
    icon: Icons.webhook,
    color: Colors.blue,
    category: _DeepLinkCategory.premium,
  );

  const _DeepLink({
    required this.path,
    required this.icon,
    required this.color,
    required this.category,
  });

  final String path;
  final IconData icon;
  final Color color;
  final _DeepLinkCategory category;

  String labelL10n(BuildContext context) {
    return switch (this) {
      settings => context.l10n.adminBroadcastLinkSettings,
      account => context.l10n.adminBroadcastLinkAccount,
      scanner => context.l10n.adminBroadcastLinkScanner,
      messages => context.l10n.adminBroadcastLinkMessages,
      channels => context.l10n.adminBroadcastLinkChannels,
      nodes => context.l10n.adminBroadcastLinkNodes,
      map => context.l10n.adminBroadcastLinkMap,
      signals => context.l10n.adminBroadcastLinkSignals,
      nodedex => context.l10n.adminBroadcastLinkNodedex,
      aether => context.l10n.adminBroadcastLinkAether,
      activity => context.l10n.adminBroadcastLinkActivity,
      presence => context.l10n.adminBroadcastLinkPresence,
      timeline => context.l10n.adminBroadcastLinkTimeline,
      worldMap => context.l10n.adminBroadcastLinkWorldMap,
      globe => context.l10n.adminBroadcastLinkGlobe,
      reachability => context.l10n.adminBroadcastLinkReachability,
      themes => context.l10n.adminBroadcastLinkThemes,
      ringtones => context.l10n.adminBroadcastLinkRingtones,
      widgets => context.l10n.adminBroadcastLinkWidgets,
      automations => context.l10n.adminBroadcastLinkAutomations,
      ifttt => context.l10n.adminBroadcastLinkIfttt,
    };
  }

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
          _buildSection(
            context,
            context.l10n.adminBroadcastDeepLinkCatCore,
            _DeepLinkCategory.core,
          ),
          const SizedBox(height: AppTheme.spacing12),
          _buildSection(
            context,
            context.l10n.adminBroadcastDeepLinkCatSocial,
            _DeepLinkCategory.social,
          ),
          const SizedBox(height: AppTheme.spacing12),
          _buildSection(
            context,
            context.l10n.adminBroadcastDeepLinkCatMesh,
            _DeepLinkCategory.mesh,
          ),
          const SizedBox(height: AppTheme.spacing12),
          _buildSection(
            context,
            context.l10n.adminBroadcastDeepLinkCatPremium,
            _DeepLinkCategory.premium,
          ),
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
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
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
                        borderRadius: BorderRadius.circular(AppTheme.radius10),
                      ),
                      child: Icon(link.icon, color: link.color, size: 22),
                    ),
                    const SizedBox(width: AppTheme.spacing12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            link.labelL10n(context),
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
