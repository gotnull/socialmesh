// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/social_providers.dart';
import '../../../utils/snackbar.dart';
import '../../settings/linked_devices_screen.dart';

/// A banner widget that suggests linking the current device to the user's profile.
/// Shows when connected to a device that isn't already linked.
class LinkDeviceBanner extends ConsumerStatefulWidget {
  const LinkDeviceBanner({super.key});

  @override
  ConsumerState<LinkDeviceBanner> createState() => _LinkDeviceBannerState();
}

class _LinkDeviceBannerState extends ConsumerState<LinkDeviceBanner>
    with SingleTickerProviderStateMixin, LifecycleSafeMixin {
  bool _isDismissed = false;
  bool _isLinking = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  int? _lastCheckedNodeNum;

  static const _dismissedKeyPrefix = 'link_device_banner_dismissed_';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Get the dismiss key for a specific node
  String _getDismissKey(int nodeNum) => '$_dismissedKeyPrefix$nodeNum';

  Future<void> _loadDismissedState(int nodeNum) async {
    // Only reload if node changed
    if (_lastCheckedNodeNum == nodeNum) return;
    _lastCheckedNodeNum = nodeNum;

    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_getDismissKey(nodeNum)) ?? false;
    safeSetState(() => _isDismissed = dismissed);
    if (!dismissed) {
      _animController.forward();
    }
  }

  Future<void> _dismiss(int nodeNum) async {
    await _animController.reverse();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_getDismissKey(nodeNum), true);
    safeSetState(() => _isDismissed = true);
  }

  Future<void> _linkDevice(int nodeNum) async {
    if (_isLinking) return;

    safeSetState(() => _isLinking = true);

    try {
      await linkNode(ref, nodeNum, setPrimary: true);
      if (mounted) {
        showSuccessSnackBar(context, 'Device linked to your profile!');
        _dismiss(nodeNum);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to link: $e');
        safeSetState(() => _isLinking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);

    // Don't show if not signed in or not connected
    if (currentUser == null || myNodeNum == null) {
      return const SizedBox.shrink();
    }

    // Load dismissed state for this specific node
    _loadDismissedState(myNodeNum);

    // Don't show if dismissed for this node
    if (_isDismissed) return const SizedBox.shrink();

    // Check if this node is already linked
    final isLinkedAsync = ref.watch(isNodeLinkedProvider(myNodeNum));

    return isLinkedAsync.when(
      data: (isLinked) {
        if (isLinked) return const SizedBox.shrink();

        return FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.accentColor.withValues(alpha: 0.15),
                  context.accentColor.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.accentColor.withValues(alpha: 0.3),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LinkedDevicesScreen(),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: context.accentColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.link,
                          color: context.accentColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Link this device to your profile',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Others can find and follow you',
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _isLinking
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.accentColor,
                              ),
                            )
                          : FilledButton(
                              onPressed: () => _linkDevice(myNodeNum),
                              style: FilledButton.styleFrom(
                                backgroundColor: context.accentColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Link',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => _dismiss(myNodeNum),
                        icon: Icon(
                          Icons.close,
                          color: context.textTertiary,
                          size: 18,
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// Resets the banner dismissal state for a specific node so it can be shown again.
/// Call this when user unlinks a device.
Future<void> resetLinkDeviceBannerDismissState({int? nodeId}) async {
  final prefs = await SharedPreferences.getInstance();
  if (nodeId != null) {
    // Clear dismissal for specific node
    await prefs.remove('link_device_banner_dismissed_$nodeId');
  } else {
    // Clear all dismissal keys (for backward compatibility)
    final keys = prefs.getKeys().where(
      (k) => k.startsWith('link_device_banner_dismissed'),
    );
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
