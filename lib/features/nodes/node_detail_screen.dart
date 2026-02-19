// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

import '../device/device_config_screen.dart';
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

  final ScrollController _scrollController = ScrollController();
  bool _showAppBarIdentity = false;
  static const double _identityScrollThreshold = 80.0;

  MeshNode get _initialNode => widget.node;
  bool get isMyNode => widget.isMyNode;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final shouldShow =
        _scrollController.hasClients &&
        _scrollController.offset > _identityScrollThreshold;
    if (shouldShow != _showAppBarIdentity) {
      setState(() => _showAppBarIdentity = shouldShow);
    }
  }

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

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DeviceConfigScreen()),
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

  /// Whether a node was heard recently enough to be considered online.
  bool _isNodeOnline(MeshNode node) {
    final lastHeard = node.lastHeard;
    if (lastHeard == null) return false;
    return DateTime.now().difference(lastHeard).inMinutes < 30;
  }

  /// Human-friendly relative time string for last heard.
  String _relativeLastHeard(DateTime? lastHeard) {
    if (lastHeard == null) return 'Never';
    final diff = DateTime.now().difference(lastHeard);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(lastHeard);
  }

  /// Signal quality label from SNR value.
  String _signalLabel(int? snr) {
    if (snr == null) return 'Unknown';
    if (snr >= 10) return 'Excellent';
    if (snr >= 5) return 'Good';
    if (snr >= 0) return 'Fair';
    if (snr >= -5) return 'Weak';
    return 'Very Weak';
  }

  Color _signalColor(int? snr) {
    if (snr == null) return Colors.grey;
    if (snr >= 10) return AccentColors.green;
    if (snr >= 5) return AccentColors.green;
    if (snr >= 0) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }

  /// Build the hero header with avatar, name, status and stat chips.
  Widget _buildHeroSection(BuildContext context, MeshNode node) {
    final isOnline = _isNodeOnline(node);
    final avatarColor = isMyNode ? context.accentColor : _getAvatarColor(node);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.card, avatarColor.withValues(alpha: 0.04)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.border.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          // Avatar with online indicator
          Stack(
            alignment: Alignment.center,
            children: [
              NodeAvatar(text: node.avatarName, color: avatarColor, size: 80),
              if (isOnline)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AccentColors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.card, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AccentColors.green.withValues(alpha: 0.5),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Name
          AutoScrollText(
            node.displayName,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 4),

          // Hex ID
          Text(
            '!${node.nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.textTertiary,
              fontFamily: AppTheme.fontFamily,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),

          // Badges row
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              if (isMyNode)
                _BadgePill(
                  label: 'YOU',
                  color: context.accentColor,
                  filled: true,
                ),
              if (node.role != null && node.role!.isNotEmpty)
                _BadgePill(label: node.role!, color: context.textTertiary),
              _BadgePill(
                icon: node.hasPublicKey ? Icons.lock : Icons.lock_open,
                label: node.hasPublicKey ? 'PKI' : 'No PKI',
                color: node.hasPublicKey
                    ? AccentColors.green
                    : context.textTertiary,
              ),
              if (node.isIgnored)
                _BadgePill(
                  icon: Icons.volume_off,
                  label: 'Muted',
                  color: AppTheme.errorRed,
                ),
              if (node.isFavorite)
                _BadgePill(
                  icon: Icons.star,
                  label: 'Favorite',
                  color: AppTheme.warningYellow,
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Quick stat chips
          _buildStatChipsRow(context, node),
        ],
      ),
    );
  }

  /// Row of compact stat chips below the hero.
  Widget _buildStatChipsRow(BuildContext context, MeshNode node) {
    final chips = <Widget>[];

    // Last heard
    chips.add(
      _QuickStatChip(
        icon: Icons.access_time,
        value: _relativeLastHeard(node.lastHeard),
        color: _isNodeOnline(node) ? AccentColors.green : context.textTertiary,
      ),
    );

    // Battery
    if (node.batteryLevel != null) {
      chips.add(
        _QuickStatChip(
          icon: _getBatteryIcon(node.batteryLevel!),
          value: node.batteryLevel! > 100
              ? 'Charging'
              : '${node.batteryLevel}%',
          color: _getBatteryColor(node.batteryLevel!),
        ),
      );
    }

    // Signal
    if (node.snr != null) {
      chips.add(
        _QuickStatChip(
          icon: Icons.signal_cellular_alt,
          value: _signalLabel(node.snr),
          color: _signalColor(node.snr),
        ),
      );
    }

    // Distance
    if (node.distance != null) {
      chips.add(
        _QuickStatChip(
          icon: Icons.near_me,
          value: node.distance! < 1000
              ? '${node.distance!.toInt()} m'
              : '${(node.distance! / 1000).toStringAsFixed(1)} km',
          color: context.accentColor,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: chips,
    );
  }

  /// Build a section with a title header and an InfoTable.
  Widget _buildInfoSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<InfoTableRow> rows,
  }) {
    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          const SizedBox(height: 10),
          InfoTable(rows: rows),
        ],
      ),
    );
  }

  /// Identity section: user ID, hardware, firmware.
  Widget _buildIdentityCard(BuildContext context, MeshNode node) {
    return _buildInfoSection(
      context,
      title: 'Identity',
      icon: Icons.badge_outlined,
      rows: [
        if (node.userId != null)
          InfoTableRow(
            icon: Icons.person_outline,
            label: 'User ID',
            value: node.userId!,
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
        InfoTableRow(
          icon: node.hasPublicKey ? Icons.lock : Icons.lock_open,
          label: 'Encryption',
          value: node.hasPublicKey ? 'PKI Enabled' : 'No Public Key',
          iconColor: node.hasPublicKey
              ? AccentColors.green
              : context.textTertiary,
        ),
        if (node.nodeStatus != null && node.nodeStatus!.isNotEmpty)
          InfoTableRow(
            icon: Icons.info_outline,
            label: 'Status',
            value: node.nodeStatus!,
          ),
      ],
    );
  }

  /// Radio / signal section: RSSI, SNR, noise floor, position.
  Widget _buildRadioCard(BuildContext context, MeshNode node) {
    return _buildInfoSection(
      context,
      title: 'Radio',
      icon: Icons.cell_tower,
      rows: [
        if (node.rssi != null)
          InfoTableRow(
            icon: Icons.signal_cellular_alt,
            label: 'RSSI',
            value: '${node.rssi} dBm',
          ),
        if (node.snr != null)
          InfoTableRow(icon: Icons.wifi, label: 'SNR', value: '${node.snr} dB'),
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
            value: '${node.altitude} m',
          ),
      ],
    );
  }

  /// Device metrics section: battery, voltage, channel util, air util, uptime.
  Widget _buildDeviceMetricsCard(BuildContext context, MeshNode node) {
    return _buildInfoSection(
      context,
      title: 'Device Metrics',
      icon: Icons.developer_board,
      rows: [
        if (node.batteryLevel != null)
          InfoTableRow(
            icon: _getBatteryIcon(node.batteryLevel!),
            iconColor: _getBatteryColor(node.batteryLevel!),
            label: 'Battery',
            value: node.batteryLevel! > 100
                ? 'Charging'
                : '${node.batteryLevel}%',
          ),
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
            value: '${node.channelUtilization!.toStringAsFixed(1)}%',
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
    );
  }

  /// Network stats section: packets, node counts.
  Widget _buildNetworkStatsCard(BuildContext context, MeshNode node) {
    return _buildInfoSection(
      context,
      title: 'Network',
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
    );
  }

  /// Traffic management section.
  Widget _buildTrafficCard(BuildContext context, MeshNode node) {
    return _buildInfoSection(
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
    );
  }

  /// Bottom action bar buttons.
  Widget _buildActionButtons(BuildContext context, MeshNode node) {
    if (isMyNode) {
      return Row(
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
      );
    }

    return Row(
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
          iconColor: node.isIgnored ? AppTheme.errorRed : context.textSecondary,
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
    );
  }

  // ─────────────────────── build ───────────────────────

  @override
  Widget build(BuildContext context) {
    // Watch the nodes provider to get latest state
    final nodesMap = ref.watch(nodesProvider);
    final node = nodesMap[_initialNode.nodeNum] ?? _initialNode;

    return GlassScaffold(
      controller: _scrollController,
      titleWidget: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _showAppBarIdentity
            ? Row(
                key: const ValueKey('identity'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  NodeAvatar(
                    text: node.avatarName,
                    color: isMyNode
                        ? context.accentColor
                        : _getAvatarColor(node),
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      node.displayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            : Text(
                key: const ValueKey('title'),
                'Node Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: context.background,
            border: Border(
              top: BorderSide(color: context.border.withValues(alpha: 0.3)),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: _buildActionButtons(context, node),
        ),
      ),
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
                leading: Icon(Icons.qr_code, color: context.accentColor),
                title: const Text('QR Code'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            if (node.hasPosition)
              PopupMenuItem(
                value: 'map',
                child: ListTile(
                  leading: Icon(Icons.map, color: context.accentColor),
                  title: const Text('Show on Map'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            if (!isMyNode) ...[
              PopupMenuItem(
                value: 'traceroute_history',
                child: ListTile(
                  leading: Icon(Icons.timeline, color: context.accentColor),
                  title: const Text('Traceroute History'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'request_info',
                child: ListTile(
                  leading: Icon(Icons.refresh, color: context.accentColor),
                  title: const Text('Request User Info'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'exchange_positions',
                child: ListTile(
                  leading: Icon(Icons.swap_horiz, color: context.accentColor),
                  title: const Text('Exchange Positions'),
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
                      color: context.accentColor,
                    ),
                    title: const Text('Set as Fixed Position'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              if (node.hasPublicKey)
                PopupMenuItem(
                  value: 'admin_settings',
                  child: ListTile(
                    leading: Icon(
                      Icons.admin_panel_settings,
                      color: context.accentColor,
                    ),
                    title: const Text('Admin Settings'),
                    subtitle: Text(
                      'Configure this node remotely',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textTertiary,
                      ),
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              const PopupMenuDivider(),
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
            HapticFeedback.selectionClick();
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
              case 'admin_settings':
                _configureRemotely(context, node);
              case 'remove':
                _removeNode(context, node);
            }
          },
        ),
      ],
      slivers: [
        // ── Hero section ──
        SliverToBoxAdapter(child: _buildHeroSection(context, node)),

        // ── Identity card ──
        SliverToBoxAdapter(child: _buildIdentityCard(context, node)),

        // ── Radio card ──
        SliverToBoxAdapter(child: _buildRadioCard(context, node)),

        // ── Device metrics card ──
        SliverToBoxAdapter(child: _buildDeviceMetricsCard(context, node)),

        // ── Network stats card ──
        SliverToBoxAdapter(child: _buildNetworkStatsCard(context, node)),

        // ── Traffic management card ──
        SliverToBoxAdapter(child: _buildTrafficCard(context, node)),

        // Last heard timestamp at the bottom
        if (node.lastHeard != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.access_time,
                    size: 12,
                    color: context.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Last heard ${DateFormat('MMM d, yyyy HH:mm').format(node.lastHeard!)}',
                    style: TextStyle(fontSize: 11, color: context.textTertiary),
                  ),
                ],
              ),
            ),
          ),

        // Bottom padding so content isn't hidden behind the fixed bottom bar
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
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

/// Small pill badge for role, PKI status, favorite, muted, etc.
class _BadgePill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;

  const _BadgePill({
    required this.label,
    required this.color,
    this.icon,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: filled ? Colors.white : color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: filled ? Colors.white : color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact stat chip for the hero section quick-reference row.
class _QuickStatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _QuickStatChip({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
