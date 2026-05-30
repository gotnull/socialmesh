// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Final onboarding page: permissions, handled gracefully.
//
// Each permission is its own card with a plain-language reason and its own
// Allow button. They are requested progressively - one tap, one OS prompt -
// rather than dumped as a single system checklist. Granted cards switch to a
// quiet "Allowed" state.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/safety/lifecycle_mixin.dart';
import '../../../../core/theme.dart';
import '../../../../services/haptic_service.dart';
import '../../../../utils/permissions.dart';

enum _Perm { bluetooth, notifications, location }

/// Progressive permissions page shown as the last onboarding step.
class HandshakePermissionsPage extends ConsumerStatefulWidget {
  const HandshakePermissionsPage({super.key, required this.accent});

  final Color accent;

  @override
  ConsumerState<HandshakePermissionsPage> createState() =>
      _HandshakePermissionsPageState();
}

class _HandshakePermissionsPageState
    extends ConsumerState<HandshakePermissionsPage>
    with LifecycleSafeMixin<HandshakePermissionsPage> {
  final Map<_Perm, bool> _granted = {
    _Perm.bluetooth: false,
    _Perm.notifications: false,
    _Perm.location: false,
  };
  final Set<int> _visible = {};

  @override
  void initState() {
    super.initState();
    _refreshStatuses();
    // Stagger the cards in one at a time.
    for (var i = 0; i < 3; i++) {
      safeTimer(Duration(milliseconds: 120 * (i + 1)), () {
        safeSetState(() => _visible.add(i));
      });
    }
  }

  Future<void> _refreshStatuses() async {
    final bt = await PermissionHelper().hasBluetoothPermissions();
    final notif = await PermissionHelper().hasNotificationPermission();
    final loc = await PermissionHelper().hasLocationPermission();
    safeSetState(() {
      _granted[_Perm.bluetooth] = bt;
      _granted[_Perm.notifications] = notif;
      _granted[_Perm.location] = loc;
    });
  }

  Future<void> _request(_Perm perm) async {
    final haptics = ref.read(hapticServiceProvider);
    bool granted;
    switch (perm) {
      case _Perm.bluetooth:
        granted = await PermissionHelper().requestBluetoothPermissions();
      case _Perm.notifications:
        granted = await PermissionHelper().requestNotificationPermission();
      case _Perm.location:
        granted = await PermissionHelper().requestLocationPermission();
    }
    if (!mounted) return;
    safeSetState(() => _granted[perm] = granted);
    if (granted) {
      haptics.success();
    } else {
      haptics.warning();
    }
    // Bluetooth request also covers location on this platform set; refresh so
    // the location card reflects any permissions granted as a side effect.
    await _refreshStatuses();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final specs = <_PermSpec>[
      _PermSpec(
        perm: _Perm.bluetooth,
        icon: Icons.bluetooth,
        title: l10n.handshakeOnboardingPermissionsBluetoothTitle,
        body: l10n.handshakeOnboardingPermissionsBluetoothBody,
      ),
      _PermSpec(
        perm: _Perm.notifications,
        icon: Icons.notifications_none,
        title: l10n.handshakeOnboardingPermissionsNotificationsTitle,
        body: l10n.handshakeOnboardingPermissionsNotificationsBody,
      ),
      _PermSpec(
        perm: _Perm.location,
        icon: Icons.location_on_outlined,
        title: l10n.handshakeOnboardingPermissionsLocationTitle,
        body: l10n.handshakeOnboardingPermissionsLocationBody,
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing24,
        vertical: AppTheme.spacing16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.handshakeOnboardingPermissionsHeadline,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),
          for (var i = 0; i < specs.length; i++) ...[
            AnimatedSlide(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              offset: _visible.contains(i)
                  ? Offset.zero
                  : const Offset(0, 0.15),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 320),
                opacity: _visible.contains(i) ? 1.0 : 0.0,
                child: _PermCard(
                  spec: specs[i],
                  accent: widget.accent,
                  granted: _granted[specs[i].perm] ?? false,
                  allowLabel: l10n.handshakeOnboardingPermissionsAllow,
                  grantedLabel: l10n.handshakeOnboardingPermissionsAllowed,
                  onAllow: () => _request(specs[i].perm),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacing12),
          ],
          const SizedBox(height: AppTheme.spacing8),
          Text(
            l10n.handshakeOnboardingPermissionsFooter,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.textTertiary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermSpec {
  const _PermSpec({
    required this.perm,
    required this.icon,
    required this.title,
    required this.body,
  });

  final _Perm perm;
  final IconData icon;
  final String title;
  final String body;
}

class _PermCard extends StatelessWidget {
  const _PermCard({
    required this.spec,
    required this.accent,
    required this.granted,
    required this.allowLabel,
    required this.grantedLabel,
    required this.onAllow,
  });

  final _PermSpec spec;
  final Color accent;
  final bool granted;
  final String allowLabel;
  final String grantedLabel;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(
          color: granted
              ? accent.withValues(alpha: 0.5)
              : context.border.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.14),
            ),
            child: Icon(spec.icon, size: 20, color: accent),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spec.title,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  spec.body,
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacing12),
          _trailing(context),
        ],
      ),
    );
  }

  Widget _trailing(BuildContext context) {
    if (granted) {
      return Padding(
        padding: const EdgeInsets.only(top: AppTheme.spacing4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 16, color: accent),
            const SizedBox(width: AppTheme.spacing4),
            Text(
              grantedLabel,
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: onAllow,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16,
          vertical: AppTheme.spacing8,
        ),
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(AppTheme.radius24),
        ),
        child: Text(
          allowLabel,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
