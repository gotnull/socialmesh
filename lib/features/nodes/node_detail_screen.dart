// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/auto_scroll_text.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/info_table.dart';
import '../../core/widgets/node_avatar.dart';
import '../../core/widgets/qr_share_sheet.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/countdown_providers.dart';
import '../../utils/snackbar.dart';

import '../map/map_screen.dart';
import '../messaging/messaging_screen.dart';
import '../nodedex/models/nodedex_entry.dart';
import '../nodedex/providers/nodedex_providers.dart';
import '../nodedex/services/sigil_generator.dart';
import '../nodedex/services/trait_engine.dart';
import '../nodedex/widgets/sigil_card_sheet.dart';
import '../telemetry/traceroute_log_screen.dart';

/// Navigates to the node detail screen. Can be called from any screen.
void showNodeDetails(BuildContext context, MeshNode node, bool isMyNode) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => NodeDetailScreen(node: node, isMyNode: isMyNode),
    ),
  );
}

/// Full-screen node detail view with glass scaffold.
///
/// Replaces the old bottom sheet approach, providing proper scrolling,
/// app bar actions, and room for all data sections.
class NodeDetailScreen extends ConsumerStatefulWidget {
  final MeshNode node;
  final bool isMyNode;

  const NodeDetailScreen({
    super.key,
    required this.node,
    required this.isMyNode,
  });

  @override
  ConsumerState<NodeDetailScreen> createState() => _NodeDetailScreenState();
}

class _NodeDetailScreenState extends ConsumerState<NodeDetailScreen>
    with LifecycleSafeMixin<NodeDetailScreen> {
  bool _isTogglingFavorite = false;
  bool _isTogglingMute = false;
  bool _isSendingTraceroute = false;

  MeshNode get _initialNode => widget.node;
  bool get isMyNode => widget.isMyNode;

  // ─────────────────────── helpers ───────────────────────

  Color _getAvatarColor(MeshNode node) {
    if (node.avatarColor != null) {
      return Color(node.avatarColor!);
    }
    final colors = [
      const Color(0xFF5B4FCE),
      const Color(0xFFD946A6),
      const Color(0xFF3B82F6),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF10B981),
    ];
    return colors[node.nodeNum % colors.length];
  }

  IconData _getBatteryIcon(int level) {
    if (level > 100) return Icons.battery_charging_full;
    if (level >= 95) return Icons.battery_full;
    if (level >= 80) return Icons.battery_6_bar;
    if (level >= 60) return Icons.battery_5_bar;
    if (level >= 40) return Icons.battery_4_bar;
    if (level >= 20) return Icons.battery_2_bar;
    if (level >= 10) return Icons.battery_1_bar;
    return Icons.battery_alert;
  }

  Color _getBatteryColor(int level) {
    if (level > 100) return AccentColors.green;
    if (level >= 50) return AccentColors.green;
    if (level >= 20) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }

  String _formatUptime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m';
    if (seconds < 86400) {
      final h = seconds ~/ 3600;
      final m = (seconds % 3600) ~/ 60;
      return '${h}h ${m}m';
    }
    final d = seconds ~/ 86400;
    final h = (seconds % 86400) ~/ 3600;
    return '${d}d ${h}h';
  }

  // ─────────────────────── actions ───────────────────────

  void _shareSigilCard(BuildContext context, MeshNode node) {
    final entries = ref.read(nodeDexProvider);
    final entry =
        entries[node.nodeNum] ??
        NodeDexEntry.discovered(
          nodeNum: node.nodeNum,
          sigil: SigilGenerator.generate(node.nodeNum),
        );

    final traitResult = TraitEngine.infer(entry: entry);

    showSigilCardSheet(
      context: context,
      entry: entry,
      traitResult: traitResult,
      node: node,
    );
  }

  void _showNodeQrCode(BuildContext context, MeshNode node) {
    final nodeInfo = {
      'nodeNum': node.nodeNum,
      'longName': node.longName ?? node.displayName,
      'shortName': node.avatarName,
      if (node.userId != null) 'userId': node.userId,
      if (node.hasPosition) 'lat': node.latitude,
      if (node.hasPosition) 'lon': node.longitude,
    };
    final nodeJson = jsonEncode(nodeInfo);
    final nodeUrl = 'socialmesh://node/${base64Encode(utf8.encode(nodeJson))}';

    QrShareSheet.show(
      context: context,
      title: node.displayName,
      subtitle: 'Scan to add this node',
      qrData: nodeUrl,
      infoText: 'Node ID: ${node.nodeNum.toRadixString(16).toUpperCase()}',
    );
  }

  void _sendDirectMessage(BuildContext context, MeshNode node) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          type: ConversationType.directMessage,
          nodeNum: node.nodeNum,
          title: node.displayName,
          avatarColor: node.avatarColor,
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(BuildContext context, MeshNode node) async {
    if (_isTogglingFavorite) return;

    safeSetState(() => _isTogglingFavorite = true);

    final protocol = ref.read(protocolServiceProvider);
    final nodesNotifier = ref.read(nodesProvider.notifier);
    final deviceFavorites = ref.read(deviceFavoritesProvider).value;

    try {
      if (node.isFavorite) {
        await protocol.removeFavoriteNode(node.nodeNum);
        await deviceFavorites?.removeFavorite(node.nodeNum);
        if (!mounted) return;
        nodesNotifier.addOrUpdateNode(node.copyWith(isFavorite: false));
        if (context.mounted) {
          showSuccessSnackBar(
            context,
            '${node.displayName} removed from favorites',
          );
        }
      } else {
        await protocol.setFavoriteNode(node.nodeNum);
        await deviceFavorites?.addFavorite(node.nodeNum);
        if (!mounted) return;
        nodesNotifier.addOrUpdateNode(node.copyWith(isFavorite: true));
        if (context.mounted) {
          showSuccessSnackBar(
            context,
            '${node.displayName} added to favorites',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to update favorite: $e');
      }
    } finally {
      safeSetState(() => _isTogglingFavorite = false);
    }
  }

  Future<void> _toggleIgnored(BuildContext context, MeshNode node) async {
    if (_isTogglingMute) return;

    final connectionState = ref.read(connectionStateProvider);
    final isConnected = connectionState.maybeWhen(
      data: (state) => state == DeviceConnectionState.connected,
      orElse: () => false,
    );

    if (!isConnected) {
      showErrorSnackBar(
        context,
        'Cannot change mute status: Device not connected',
      );
      return;
    }

    safeSetState(() => _isTogglingMute = true);

    final protocol = ref.read(protocolServiceProvider);
    final nodesNotifier = ref.read(nodesProvider.notifier);
    final deviceFavorites = ref.read(deviceFavoritesProvider).value;

    try {
      if (node.isIgnored) {
        await protocol.removeIgnoredNode(node.nodeNum);
        await deviceFavorites?.removeIgnored(node.nodeNum);
        if (!mounted) return;
        nodesNotifier.addOrUpdateNode(node.copyWith(isIgnored: false));
        if (context.mounted) {
          showSuccessSnackBar(context, '${node.displayName} unmuted');
        }
      } else {
        await protocol.setIgnoredNode(node.nodeNum);
        await deviceFavorites?.addIgnored(node.nodeNum);
        if (!mounted) return;
        nodesNotifier.addOrUpdateNode(node.copyWith(isIgnored: true));
        if (context.mounted) {
          showSuccessSnackBar(context, '${node.displayName} muted');
        }
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to update mute status: $e');
      }
    } finally {
      safeSetState(() => _isTogglingMute = false);
    }
  }

  Future<void> _sendTraceroute(BuildContext context, MeshNode node) async {
    final cooldownRemaining = ref
        .read(countdownProvider.notifier)
        .tracerouteRemaining(node.nodeNum);
    if (_isSendingTraceroute || cooldownRemaining > 0) return;

    final connectionState = ref.read(connectionStateProvider);
    final isConnected = connectionState.maybeWhen(
      data: (state) => state == DeviceConnectionState.connected,
      orElse: () => false,
    );

    if (!isConnected) {
      showErrorSnackBar(
        context,
        'Cannot send traceroute: Device not connected',
      );
      return;
    }

    safeSetState(() => _isSendingTraceroute = true);

    final protocol = ref.read(protocolServiceProvider);
    final displayName = node.displayName;

    try {
      await protocol.sendTraceroute(node.nodeNum);

      if (!mounted) return;

      safeSetState(() => _isSendingTraceroute = false);

      ref
          .read(countdownProvider.notifier)
          .startTracerouteCountdown(node.nodeNum);

      if (context.mounted) {
        showSuccessSnackBar(
          context,
          'Traceroute sent to $displayName -- check Traceroute History for results',
        );
      }
    } catch (e) {
      if (!mounted) return;
      safeSetState(() => _isSendingTraceroute = false);
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to send traceroute: $e');
      }
    }
  }

  void _showTracerouteHistory(BuildContext context, MeshNode node) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TraceRouteLogScreen(nodeNum: node.nodeNum),
      ),
    );
  }

  Future<void> _showRebootConfirmation(
    BuildContext context,
    MeshNode node,
  ) async {
    final connectionState = ref.read(connectionStateProvider);
    final isConnected = connectionState.maybeWhen(
      data: (state) => state == DeviceConnectionState.connected,
      orElse: () => false,
    );

    if (!isConnected) {
      showErrorSnackBar(context, 'Cannot reboot: Device not connected');
      return;
    }

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: 'Reboot Device',
      message:
          'This will reboot your Meshtastic device. The app will automatically reconnect once the device restarts.',
      confirmLabel: 'Reboot',
      isDestructive: true,
    );

    if (confirmed != true || !mounted) return;

    final protocol = ref.read(protocolServiceProvider);

    try {
      await protocol.reboot();
      if (!mounted) return;
      if (context.mounted) {
        Navigator.pop(context);
        showInfoSnackBar(context, 'Device is rebooting...');
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to reboot: $e');
      }
    }
  }

  Future<void> _showShutdownConfirmation(
    BuildContext context,
    MeshNode node,
  ) async {
    final connectionState = ref.read(connectionStateProvider);
    final isConnected = connectionState.maybeWhen(
      data: (state) => state == DeviceConnectionState.connected,
      orElse: () => false,
    );

    if (!isConnected) {
      showErrorSnackBar(context, 'Cannot shutdown: Device not connected');
      return;
    }

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: 'Shutdown Device',
      message:
          'This will turn off your Meshtastic device. You will need to physically power it back on to reconnect.',
      confirmLabel: 'Shutdown',
      isDestructive: true,
    );

    if (confirmed != true || !mounted) return;

    final protocol = ref.read(protocolServiceProvider);

    try {
      await protocol.shutdown();
      if (!mounted) return;
      if (context.mounted) {
        Navigator.pop(context);
        showInfoSnackBar(context, 'Device is shutting down...');
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to shutdown: $e');
      }
    }
  }

  Future<void> _removeNode(BuildContext context, MeshNode node) async {
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: 'Remove Node',
      message:
          'Remove ${node.displayName} from the node database? This will remove the node from your local device.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );

    if (confirmed != true || !mounted) return;

    final protocol = ref.read(protocolServiceProvider);
    final nodesNotifier = ref.read(nodesProvider.notifier);

    try {
      await protocol.removeNode(node.nodeNum);
      if (!mounted) return;
      nodesNotifier.removeNode(node.nodeNum);
      if (context.mounted) {
        Navigator.pop(context);
        showSuccessSnackBar(context, '${node.displayName} removed');
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to remove node: $e');
      }
    }
  }

  Future<void> _setFixedPosition(BuildContext context, MeshNode node) async {
    if (!node.hasPosition) {
      showInfoSnackBar(context, 'Node has no position data');
      return;
    }

    final protocol = ref.read(protocolServiceProvider);

    try {
      await protocol.setFixedPosition(
        latitude: node.latitude!,
        longitude: node.longitude!,
        altitude: node.altitude ?? 0,
      );
      if (!mounted) return;
      if (context.mounted) {
        showSuccessSnackBar(
          context,
          'Fixed position set to ${node.displayName}\'s location',
        );
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to set fixed position: $e');
      }
    }
  }

  Future<void> _requestUserInfo(BuildContext context, MeshNode node) async {
    final protocol = ref.read(protocolServiceProvider);

    try {
      await protocol.requestNodeInfo(node.nodeNum);
      if (!mounted) return;
      if (context.mounted) {
        showInfoSnackBar(
          context,
          'User info requested from ${node.displayName}',
        );
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to request user info: $e');
      }
    }
  }

  void _configureRemotely(BuildContext context, MeshNode node) {
    ref
        .read(remoteAdminProvider.notifier)
        .setTarget(node.nodeNum, node.displayName);

    Navigator.pushNamed(context, '/settings');

    showInfoSnackBar(
      context,
      'Remote admin enabled for ${node.displayName}. Device settings will now configure this node.',
    );
  }

  Future<void> _exchangePositions(BuildContext context, MeshNode node) async {
    final protocol = ref.read(protocolServiceProvider);

    try {
      await protocol.requestPosition(node.nodeNum);
      if (!mounted) return;
      if (context.mounted) {
        showInfoSnackBar(
          context,
          'Position requested from ${node.displayName}',
        );
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to request position: $e');
      }
    }
  }

  // ─────────────────────── build helpers ───────────────────────

  Widget _buildMetricsSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<InfoTableRow> rows,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: context.accentColor),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: context.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InfoTable(rows: rows),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, MeshNode node) {
    if (isMyNode) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showRebootConfirmation(context, node),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.warningYellow,
                  side: BorderSide(
                    color: AppTheme.warningYellow.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.restart_alt, size: 20),
                label: const Text(
                  'Reboot',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showShutdownConfirmation(context, node),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorRed,
                  side: BorderSide(
                    color: AppTheme.errorRed.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.power_settings_new, size: 20),
                label: const Text(
                  'Shutdown',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Remote admin button (only for PKI nodes)
          if (node.hasPublicKey)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _configureRemotely(context, node),
                  icon: const Icon(Icons.admin_panel_settings, size: 20),
                  label: const Text('Configure Remotely'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.accentColor,
                    side: BorderSide(color: context.accentColor),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          // Primary action row
          Row(
            children: [
              // Favorite
              _ActionIconButton(
                isLoading: _isTogglingFavorite,
                loadingColor: AppTheme.warningYellow,
                onPressed: () => _toggleFavorite(context, node),
                icon: node.isFavorite ? Icons.star : Icons.star_border,
                iconColor: node.isFavorite
                    ? AppTheme.warningYellow
                    : context.textSecondary,
                tooltip: node.isFavorite
                    ? 'Remove from favorites'
                    : 'Add to favorites',
              ),
              const SizedBox(width: 8),
              // Mute
              _ActionIconButton(
                isLoading: _isTogglingMute,
                loadingColor: AppTheme.errorRed,
                onPressed: () => _toggleIgnored(context, node),
                icon: node.isIgnored ? Icons.volume_off : Icons.volume_up,
                iconColor: node.isIgnored
                    ? AppTheme.errorRed
                    : context.textSecondary,
                tooltip: node.isIgnored ? 'Unmute node' : 'Mute node',
              ),
              const SizedBox(width: 8),
              // Traceroute
              _TracerouteButton(
                node: node,
                isSending: _isSendingTraceroute,
                onPressed: () => _sendTraceroute(context, node),
              ),
              const SizedBox(width: 8),
              // Message button
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _sendDirectMessage(context, node),
                  icon: const Icon(Icons.message, size: 20),
                  label: const Text('Message'),
                  style: FilledButton.styleFrom(
                    backgroundColor: context.accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────── build ───────────────────────

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy HH:mm');

    // Watch the nodes provider to get latest state
    final nodesMap = ref.watch(nodesProvider);
    final node = nodesMap[_initialNode.nodeNum] ?? _initialNode;

    return GlassScaffold(
      title: node.displayName,
      actions: [
        // Sigil card button
        IconButton(
          onPressed: () => _shareSigilCard(context, node),
          icon: Icon(Icons.auto_awesome_outlined, color: context.textSecondary),
          tooltip: 'Sigil Card',
        ),
        // Overflow menu
        AppBarOverflowMenu<String>(
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'qr',
              child: ListTile(
                leading: Icon(Icons.qr_code, color: context.textSecondary),
                title: Text('QR Code'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            if (node.hasPosition)
              PopupMenuItem(
                value: 'map',
                child: ListTile(
                  leading: Icon(Icons.map, color: context.accentColor),
                  title: Text('Show on Map'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            if (!isMyNode) ...[
              PopupMenuItem(
                value: 'traceroute_history',
                child: ListTile(
                  leading: Icon(Icons.timeline, color: context.accentColor),
                  title: Text('Traceroute History'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'request_info',
                child: ListTile(
                  leading: Icon(Icons.refresh, color: context.accentColor),
                  title: Text('Request User Info'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'exchange_positions',
                child: ListTile(
                  leading: Icon(Icons.swap_horiz, color: context.accentColor),
                  title: Text('Exchange Positions'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (node.hasPosition)
                PopupMenuItem(
                  value: 'fixed_position',
                  child: ListTile(
                    leading: Icon(
                      Icons.location_on,
                      color: context.textSecondary,
                    ),
                    title: Text('Set as Fixed Position'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              PopupMenuItem(
                value: 'remove',
                child: ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: AppTheme.errorRed,
                  ),
                  title: const Text(
                    'Remove Node',
                    style: TextStyle(color: AppTheme.errorRed),
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ],
          onSelected: (value) {
            switch (value) {
              case 'qr':
                _showNodeQrCode(context, node);
              case 'map':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MapScreen(initialNodeNum: node.nodeNum),
                  ),
                );
              case 'traceroute_history':
                _showTracerouteHistory(context, node);
              case 'request_info':
                _requestUserInfo(context, node);
              case 'exchange_positions':
                _exchangePositions(context, node);
              case 'fixed_position':
                _setFixedPosition(context, node);
              case 'remove':
                _removeNode(context, node);
            }
          },
        ),
      ],
      slivers: [
        // ── Hero header ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                NodeAvatar(
                  text: node.avatarName,
                  color: isMyNode ? context.accentColor : _getAvatarColor(node),
                  size: 64,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AutoScrollText(
                        node.displayName,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '!${node.nodeNum.toRadixString(16)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: context.textSecondary,
                              fontFamily: AppTheme.fontFamily,
                            ),
                          ),
                          if (isMyNode) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: context.accentColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'YOU',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Divider ──
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            height: 1,
            color: context.border.withValues(alpha: 0.3),
          ),
        ),

        // ── Info sections ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InfoTable(
                  rows: [
                    InfoTableRow(
                      icon: Icons.badge,
                      label: 'User ID',
                      value: node.userId ?? 'Unknown',
                    ),
                    if (node.role != null)
                      InfoTableRow(
                        icon: Icons.smartphone,
                        label: 'Role',
                        value: node.role!,
                      ),
                    if (node.hardwareModel != null)
                      InfoTableRow(
                        icon: Icons.memory,
                        label: 'Hardware',
                        value: node.hardwareModel!,
                      ),
                    if (node.firmwareVersion != null)
                      InfoTableRow(
                        icon: Icons.system_update,
                        label: 'Firmware',
                        value: node.firmwareVersion!,
                      ),
                    if (node.nodeStatus != null && node.nodeStatus!.isNotEmpty)
                      InfoTableRow(
                        icon: Icons.info_outline,
                        label: 'Status',
                        value: node.nodeStatus!,
                      ),
                    if (node.batteryLevel != null)
                      InfoTableRow(
                        icon: _getBatteryIcon(node.batteryLevel!),
                        iconColor: _getBatteryColor(node.batteryLevel!),
                        label: 'Battery',
                        value: node.batteryLevel! > 100
                            ? 'Charging'
                            : '${node.batteryLevel}%',
                      ),
                    if (node.rssi != null)
                      InfoTableRow(
                        icon: Icons.signal_cellular_alt,
                        label: 'RSSI',
                        value: '${node.rssi} dBm',
                      ),
                    if (node.snr != null)
                      InfoTableRow(
                        icon: Icons.wifi,
                        label: 'SNR',
                        value: '${node.snr} dB',
                      ),
                    if (node.noiseFloor != null)
                      InfoTableRow(
                        icon: Icons.graphic_eq,
                        label: 'Noise Floor',
                        value: '${node.noiseFloor} dBm',
                      ),
                    if (node.distance != null)
                      InfoTableRow(
                        icon: Icons.near_me,
                        label: 'Distance',
                        value: node.distance! < 1000
                            ? '${node.distance!.toInt()} m'
                            : '${(node.distance! / 1000).toStringAsFixed(1)} km',
                      ),
                    if (node.hasPosition)
                      InfoTableRow(
                        icon: Icons.location_on,
                        label: 'Position',
                        value:
                            '${node.latitude!.toStringAsFixed(5)}, ${node.longitude!.toStringAsFixed(5)}',
                      ),
                    if (node.altitude != null)
                      InfoTableRow(
                        icon: Icons.height,
                        label: 'Altitude',
                        value: '${node.altitude}m',
                      ),
                    if (node.lastHeard != null)
                      InfoTableRow(
                        icon: Icons.access_time,
                        label: 'Last Heard',
                        value: dateFormat.format(node.lastHeard!),
                      ),
                    InfoTableRow(
                      icon: node.hasPublicKey ? Icons.lock : Icons.lock_open,
                      iconColor: node.hasPublicKey
                          ? context.accentColor
                          : context.textTertiary,
                      label: 'Encryption',
                      value: node.hasPublicKey
                          ? 'PKI Enabled'
                          : 'No Public Key',
                    ),
                    if (node.isMuted)
                      InfoTableRow(
                        icon: Icons.volume_off,
                        iconColor: context.textTertiary,
                        label: 'Muted',
                        value: 'Device-side mute enabled',
                      ),
                  ],
                ),
                // Device Metrics
                if (node.voltage != null ||
                    node.channelUtilization != null ||
                    node.airUtilTx != null ||
                    node.uptimeSeconds != null)
                  _buildMetricsSection(
                    context,
                    title: 'Device Metrics',
                    icon: Icons.developer_board,
                    rows: [
                      if (node.voltage != null)
                        InfoTableRow(
                          icon: Icons.battery_charging_full,
                          label: 'Voltage',
                          value: '${node.voltage!.toStringAsFixed(2)} V',
                        ),
                      if (node.channelUtilization != null)
                        InfoTableRow(
                          icon: Icons.wifi_tethering,
                          label: 'Channel Util',
                          value:
                              '${node.channelUtilization!.toStringAsFixed(1)}%',
                        ),
                      if (node.airUtilTx != null)
                        InfoTableRow(
                          icon: Icons.cell_tower,
                          label: 'Air Util TX',
                          value: '${node.airUtilTx!.toStringAsFixed(1)}%',
                        ),
                      if (node.uptimeSeconds != null)
                        InfoTableRow(
                          icon: Icons.timer,
                          label: 'Uptime',
                          value: _formatUptime(node.uptimeSeconds!),
                        ),
                    ],
                  ),
                // Local Stats
                if (node.numPacketsTx != null ||
                    node.numPacketsRx != null ||
                    node.numOnlineNodes != null)
                  _buildMetricsSection(
                    context,
                    title: 'Local Stats',
                    icon: Icons.bar_chart,
                    rows: [
                      if (node.numPacketsTx != null)
                        InfoTableRow(
                          icon: Icons.upload,
                          label: 'Packets TX',
                          value: '${node.numPacketsTx}',
                        ),
                      if (node.numPacketsRx != null)
                        InfoTableRow(
                          icon: Icons.download,
                          label: 'Packets RX',
                          value: '${node.numPacketsRx}',
                        ),
                      if (node.numPacketsRxBad != null)
                        InfoTableRow(
                          icon: Icons.error_outline,
                          label: 'Bad Packets',
                          value: '${node.numPacketsRxBad}',
                        ),
                      if (node.numOnlineNodes != null)
                        InfoTableRow(
                          icon: Icons.people,
                          label: 'Online Nodes',
                          value: '${node.numOnlineNodes}',
                        ),
                      if (node.numTotalNodes != null)
                        InfoTableRow(
                          icon: Icons.groups,
                          label: 'Total Nodes',
                          value: '${node.numTotalNodes}',
                        ),
                      if (node.numTxDropped != null)
                        InfoTableRow(
                          icon: Icons.block,
                          label: 'TX Dropped',
                          value: '${node.numTxDropped}',
                        ),
                    ],
                  ),
                // Traffic Management
                if (node.tmPacketsInspected != null ||
                    node.tmPositionDedupDrops != null ||
                    node.tmRateLimitDrops != null)
                  _buildMetricsSection(
                    context,
                    title: 'Traffic Management',
                    icon: Icons.traffic,
                    rows: [
                      if (node.tmPacketsInspected != null)
                        InfoTableRow(
                          icon: Icons.search,
                          label: 'Inspected',
                          value: '${node.tmPacketsInspected}',
                        ),
                      if (node.tmPositionDedupDrops != null)
                        InfoTableRow(
                          icon: Icons.filter_alt,
                          label: 'Position Dedup',
                          value: '${node.tmPositionDedupDrops}',
                        ),
                      if (node.tmNodeinfoCacheHits != null)
                        InfoTableRow(
                          icon: Icons.cached,
                          label: 'Cache Hits',
                          value: '${node.tmNodeinfoCacheHits}',
                        ),
                      if (node.tmRateLimitDrops != null)
                        InfoTableRow(
                          icon: Icons.speed,
                          label: 'Rate Limit Drops',
                          value: '${node.tmRateLimitDrops}',
                        ),
                      if (node.tmUnknownPacketDrops != null)
                        InfoTableRow(
                          icon: Icons.help_outline,
                          label: 'Unknown Drops',
                          value: '${node.tmUnknownPacketDrops}',
                        ),
                      if (node.tmHopExhaustedPackets != null)
                        InfoTableRow(
                          icon: Icons.do_not_disturb,
                          label: 'Hop Exhausted',
                          value: '${node.tmHopExhaustedPackets}',
                        ),
                      if (node.tmRouterHopsPreserved != null)
                        InfoTableRow(
                          icon: Icons.route,
                          label: 'Hops Preserved',
                          value: '${node.tmRouterHopsPreserved}',
                        ),
                    ],
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // ── Action buttons ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _buildActionButtons(context, node),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────── small widgets ───────────────────────

class _ActionIconButton extends StatelessWidget {
  final bool isLoading;
  final Color loadingColor;
  final VoidCallback onPressed;
  final IconData icon;
  final Color iconColor;
  final String tooltip;

  const _ActionIconButton({
    required this.isLoading,
    required this.loadingColor,
    required this.onPressed,
    required this.icon,
    required this.iconColor,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: isLoading
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: loadingColor,
                ),
              ),
            )
          : IconButton(
              onPressed: onPressed,
              icon: Icon(icon, color: iconColor, size: 22),
              tooltip: tooltip,
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(),
            ),
    );
  }
}

class _TracerouteButton extends ConsumerWidget {
  final MeshNode node;
  final bool isSending;
  final VoidCallback onPressed;

  const _TracerouteButton({
    required this.node,
    required this.isSending,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countdowns = ref.watch(countdownProvider);
    final traceId = CountdownNotifier.tracerouteId(node.nodeNum);
    final cooldownTask = countdowns[traceId];
    final cooldownRemaining = cooldownTask?.remainingSeconds ?? 0;
    final cooldownTotal =
        cooldownTask?.totalSeconds ??
        CountdownNotifier.tracerouteCooldownSeconds;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: isSending
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.accentColor,
                ),
              ),
            )
          : cooldownRemaining > 0
          ? Tooltip(
              message: 'Traceroute cooldown: ${cooldownRemaining}s',
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          value: cooldownTotal > 0
                              ? cooldownRemaining / cooldownTotal
                              : 0,
                          strokeWidth: 2,
                          color: context.accentColor.withValues(alpha: 0.4),
                          backgroundColor: context.textTertiary.withValues(
                            alpha: 0.15,
                          ),
                        ),
                      ),
                      Text(
                        '$cooldownRemaining',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : IconButton(
              onPressed: onPressed,
              icon: Icon(Icons.route, color: context.textSecondary, size: 22),
              tooltip: 'Traceroute',
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(),
            ),
    );
  }
}
