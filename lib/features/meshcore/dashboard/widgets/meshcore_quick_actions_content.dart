// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/logging.dart';
import '../../../../core/meshcore_constants.dart';
import '../../../../core/safety/lifecycle_mixin.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../providers/meshcore_providers.dart';
import '../../../../utils/snackbar.dart';

/// MeshCore-flavoured equivalent of `QuickActionsContent`. Three
/// useful one-tap radio actions sized to the dashboard card surface:
/// Send Advert, Refresh Contacts, Sync Time. Each action gates on
/// `session != null` and surfaces success / failure via a snackbar.
class MeshCoreQuickActionsContent extends ConsumerStatefulWidget {
  const MeshCoreQuickActionsContent({super.key});

  @override
  ConsumerState<MeshCoreQuickActionsContent> createState() =>
      _MeshCoreQuickActionsContentState();
}

class _MeshCoreQuickActionsContentState
    extends ConsumerState<MeshCoreQuickActionsContent>
    with LifecycleSafeMixin {
  String? _busy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing8,
      ),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: Icons.broadcast_on_personal_rounded,
              label: l10n.meshcoreQuickActionSendAdvert,
              busy: _busy == 'advert',
              onTap: _busy != null ? null : _sendAdvert,
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: _ActionButton(
              icon: Icons.people_outline,
              label: l10n.meshcoreQuickActionRefreshContacts,
              busy: _busy == 'contacts',
              onTap: _busy != null ? null : _refreshContacts,
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: _ActionButton(
              icon: Icons.schedule_rounded,
              label: l10n.meshcoreQuickActionSyncTime,
              busy: _busy == 'time',
              onTap: _busy != null ? null : _syncTime,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendAdvert() async {
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      showErrorSnackBar(context, context.l10n.meshcoreNotConnectedTools);
      return;
    }
    setState(() => _busy = 'advert');
    try {
      await session.sendCommand(MeshCoreCommands.sendSelfAdvert);
      if (!mounted) return;
      showSuccessSnackBar(context, context.l10n.meshcoreAdvertisementSentTools);
    } catch (e) {
      AppLogging.meshcore(
        'event=dashboard.quick_action.failed action=advert reason=${e.runtimeType}',
      );
      if (!mounted) return;
      showErrorSnackBar(context, context.l10n.meshcoreFailedToSendAdTools);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _refreshContacts() async {
    setState(() => _busy = 'contacts');
    try {
      await ref.read(meshCoreContactsProvider.notifier).refresh();
    } catch (e) {
      AppLogging.meshcore(
        'event=dashboard.quick_action.failed action=refresh reason=${e.runtimeType}',
      );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _syncTime() async {
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      showErrorSnackBar(context, context.l10n.meshcoreNotConnectedTools);
      return;
    }
    setState(() => _busy = 'time');
    try {
      final ok = await session.setDeviceTime();
      if (!mounted) return;
      if (ok) {
        showSuccessSnackBar(context, context.l10n.meshcoreTimeSynchronized);
      } else {
        showErrorSnackBar(context, context.l10n.meshcoreSyncTimeRejected);
      }
    } catch (e) {
      AppLogging.meshcore(
        'event=dashboard.quick_action.failed action=time reason=${e.runtimeType}',
      );
      if (!mounted) return;
      showErrorSnackBar(context, context.l10n.meshcoreFailedToSyncTime);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = enabled ? context.accentColor : context.textTertiary;
    return BouncyTap(
      onTap: onTap,
      scaleFactor: 0.95,
      enabled: enabled,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        decoration: BoxDecoration(
          color: enabled
              ? context.accentColor.withValues(alpha: 0.08)
              : context.background,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(
            color: enabled
                ? context.accentColor.withValues(alpha: 0.2)
                : context.border,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: color,
                ),
              )
            else
              Icon(icon, size: 18, color: color),
            const SizedBox(height: AppTheme.spacing2),
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.1,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
