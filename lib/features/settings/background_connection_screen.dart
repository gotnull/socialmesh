// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/animations.dart';
import '../../providers/connection_providers.dart';
import '../../services/transport/background_ble_service.dart';

/// SharedPreferences keys for background notification settings.
///
/// These are separate from the global notification keys so users can
/// independently control which notifications fire while the app is
/// backgrounded.
const String kBgNotifyMessages = 'bg_notify_messages';
const String kBgNotifyChannels = 'bg_notify_channels';
const String kBgNotifyNodes = 'bg_notify_nodes';
const String kBgNotifStyle = 'bg_notif_style';

/// Notification style for the persistent Android foreground notification.
enum NotificationStyle {
  /// "Connected to [device name]"
  minimal(0),

  /// "Connected to [device name] -- 12 nodes heard, last message 3m ago"
  detailed(1);

  const NotificationStyle(this.value);
  final int value;

  static NotificationStyle fromValue(int value) =>
      values.firstWhere((e) => e.value == value, orElse: () => minimal);
}

/// Settings screen for controlling background BLE connection and notification
/// behaviour (Sprint 002 -- W3.1).
class BackgroundConnectionScreen extends ConsumerStatefulWidget {
  const BackgroundConnectionScreen({super.key});

  @override
  ConsumerState<BackgroundConnectionScreen> createState() =>
      _BackgroundConnectionScreenState();
}

class _BackgroundConnectionScreenState
    extends ConsumerState<BackgroundConnectionScreen>
    with LifecycleSafeMixin {
  bool _bgBleEnabled = true;
  bool _bgNotifyMessages = true;
  bool _bgNotifyChannels = true;
  bool _bgNotifyNodes = false;
  NotificationStyle _notifStyle = NotificationStyle.minimal;

  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    safeSetState(() {
      _bgBleEnabled = prefs.getBool(kBgBleEnabled) ?? true;
      _bgNotifyMessages = prefs.getBool(kBgNotifyMessages) ?? true;
      _bgNotifyChannels = prefs.getBool(kBgNotifyChannels) ?? true;
      _bgNotifyNodes = prefs.getBool(kBgNotifyNodes) ?? false;
      _notifStyle = NotificationStyle.fromValue(
        prefs.getInt(kBgNotifStyle) ?? 0,
      );
      _loaded = true;
    });
  }

  // ---------------------------------------------------------------------------
  // Persistence helpers
  // ---------------------------------------------------------------------------

  Future<void> _setBgBleEnabled(bool value) async {
    HapticFeedback.selectionClick();

    if (!value) {
      // Confirm before disabling background connection.
      final confirmed = await AppBottomSheet.showConfirm(
        context: context,
        title: 'Disable Background Connection?',
        message:
            'The mesh connection may be lost when the app is in the '
            'background. You will not receive notifications for new messages.',
        confirmLabel: 'Disable',
        isDestructive: true,
      );
      if (confirmed != true || !mounted) return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    await prefs.setBool(kBgBleEnabled, value);

    safeSetState(() => _bgBleEnabled = value);

    if (!value) {
      // Stop the foreground service immediately.
      await BackgroundBleService.instance.stop();
      AppLogging.ble('BackgroundConnectionScreen: foreground service stopped');
    } else {
      // Re-start the foreground service if currently connected.
      final isRunning = ref.read(isBackgroundServiceRunningProvider);
      if (!isRunning) {
        // The service will auto-start on next connection. If already
        // connected, kick-start it now. We don't have direct access to the
        // transport here, so the service will pick it up on the next BLE
        // state change.
        AppLogging.ble(
          'BackgroundConnectionScreen: enabled -- '
          'service will start on next connection',
        );
      }
    }
  }

  Future<void> _setBgNotifyMessages(bool value) async {
    HapticFeedback.selectionClick();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    await prefs.setBool(kBgNotifyMessages, value);
    safeSetState(() => _bgNotifyMessages = value);
  }

  Future<void> _setBgNotifyChannels(bool value) async {
    HapticFeedback.selectionClick();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    await prefs.setBool(kBgNotifyChannels, value);
    safeSetState(() => _bgNotifyChannels = value);
  }

  Future<void> _setBgNotifyNodes(bool value) async {
    HapticFeedback.selectionClick();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    await prefs.setBool(kBgNotifyNodes, value);
    safeSetState(() => _bgNotifyNodes = value);
  }

  Future<void> _setNotifStyle(NotificationStyle style) async {
    HapticFeedback.selectionClick();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    await prefs.setInt(kBgNotifStyle, style.value);
    safeSetState(() => _notifStyle = style);

    // Update the visible notification immediately if the service is running.
    if (Platform.isAndroid && _bgBleEnabled) {
      // Refresh notification content to reflect the new style. The actual
      // device name is managed by BackgroundBleService, but we can trigger
      // a refresh by re-reading the current state.
      AppLogging.ble(
        'BackgroundConnectionScreen: notification style → ${style.name}',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Background Connection',
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 16),

              // -- Connection toggle ----------------------------------------
              _SectionHeader(title: 'CONNECTION'),
              _SettingTile(
                icon: Icons.bluetooth_connected,
                title: 'Background connection',
                subtitle:
                    'Keep mesh radio connected when the app is '
                    'in the background',
                trailing: _loaded
                    ? ThemedSwitch(
                        value: _bgBleEnabled,
                        onChanged: _setBgBleEnabled,
                      )
                    : const SizedBox(
                        width: 48,
                        height: 24,
                        child: Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
              ),

              const SizedBox(height: 24),

              // -- Notification toggles -------------------------------------
              _SectionHeader(title: 'BACKGROUND NOTIFICATIONS'),
              _SettingTile(
                icon: Icons.chat_bubble_outline,
                title: 'Direct messages',
                subtitle: 'Notify for DMs received while backgrounded',
                trailing: ThemedSwitch(
                  value: _bgNotifyMessages && _bgBleEnabled,
                  onChanged: _bgBleEnabled ? _setBgNotifyMessages : null,
                ),
              ),
              _SettingTile(
                icon: Icons.forum_outlined,
                title: 'Channel messages',
                subtitle: 'Notify for channel messages while backgrounded',
                trailing: ThemedSwitch(
                  value: _bgNotifyChannels && _bgBleEnabled,
                  onChanged: _bgBleEnabled ? _setBgNotifyChannels : null,
                ),
              ),
              _SettingTile(
                icon: Icons.cell_tower,
                title: 'Node discovery',
                subtitle: 'Notify when new nodes are heard',
                trailing: ThemedSwitch(
                  value: _bgNotifyNodes && _bgBleEnabled,
                  onChanged: _bgBleEnabled ? _setBgNotifyNodes : null,
                ),
              ),

              // -- Notification style (Android only) ------------------------
              if (Platform.isAndroid) ...[
                const SizedBox(height: 24),
                _SectionHeader(title: 'PERSISTENT NOTIFICATION'),
                _NotifStyleSelector(
                  style: _notifStyle,
                  enabled: _bgBleEnabled,
                  onChanged: _bgBleEnabled ? _setNotifStyle : null,
                ),
              ],

              SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
            ]),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Private widgets
// =============================================================================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: context.textTertiary,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: context.textSecondary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: context.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.textTertiary),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented control for choosing the persistent notification style (Android).
class _NotifStyleSelector extends StatelessWidget {
  const _NotifStyleSelector({
    required this.style,
    required this.enabled,
    this.onChanged,
  });

  final NotificationStyle style;
  final bool enabled;
  final ValueChanged<NotificationStyle>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notification style',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<NotificationStyle>(
                segments: const [
                  ButtonSegment(
                    value: NotificationStyle.minimal,
                    label: Text('Minimal'),
                  ),
                  ButtonSegment(
                    value: NotificationStyle.detailed,
                    label: Text('Detailed'),
                  ),
                ],
                selected: {style},
                onSelectionChanged: enabled
                    ? (selection) {
                        if (selection.isNotEmpty) {
                          onChanged?.call(selection.first);
                        }
                      }
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              style == NotificationStyle.minimal
                  ? 'Shows "Connected to [device]"'
                  : 'Shows connection status with node count and last message time',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
