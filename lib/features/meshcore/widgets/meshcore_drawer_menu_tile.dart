// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';

/// Drawer menu tile for the MeshCore shell drawer.
///
/// Counterpart to `DrawerMenuTile` in
/// `lib/features/navigation/widgets/drawer_menu_tile.dart`. Visual
/// alignment between the two is the goal; see the parity audit's
/// Launch-readiness LR-1 entry for the structural deltas still to close.
class MeshCoreDrawerMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  // When `true`, renders a small lock badge on the trailing edge
  // mirroring `DrawerMenuTile.isLocked` on the Meshtastic side. The
  // tile still taps through so the press can route to the paywall;
  // entitlement enforcement lives in the destination screen.
  final bool isLocked;

  const MeshCoreDrawerMenuTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BouncyTap(
      onTap: onTap,
      scaleFactor: 0.98,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radius16),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(AppTheme.spacing10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radius12),
              ),
              child: Icon(
                icon,
                size: 22,
                color:
                    iconColor ??
                    theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: AppTheme.spacing14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  fontFamily: AppTheme.fontFamily,
                  color: theme.colorScheme.onSurface.withValues(
                    alpha: isLocked ? 0.55 : 0.8,
                  ),
                ),
              ),
            ),
            if (isLocked)
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing6),
                decoration: BoxDecoration(
                  color: AppTheme.warningYellow.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 14,
                  color: AppTheme.warningYellow,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
