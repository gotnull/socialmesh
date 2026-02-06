// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../../models/mesh_models.dart';
import '../../models/presence_confidence.dart';
import '../../providers/app_providers.dart';
import '../../providers/presence_providers.dart';
import '../../utils/presence_utils.dart';
import 'animations.dart';
import 'app_bottom_sheet.dart';
import 'node_avatar.dart';
import 'status_banner.dart';

/// Result from remote admin selector
class RemoteAdminSelection {
  final int? nodeNum; // null means local device
  final String? nodeName;
  final bool isLocal;

  const RemoteAdminSelection.local()
    : nodeNum = null,
      nodeName = null,
      isLocal = true;

  const RemoteAdminSelection.remote(this.nodeNum, this.nodeName)
    : isLocal = false;
}

/// Bottom sheet for selecting a node for remote administration
class RemoteAdminSelectorSheet extends ConsumerStatefulWidget {
  final int? currentTarget;

  const RemoteAdminSelectorSheet({super.key, this.currentTarget});

  /// Show the remote admin selector and return the selection
  static Future<RemoteAdminSelection?> show(
    BuildContext context, {
    int? currentTarget,
  }) {
    return AppBottomSheet.show<RemoteAdminSelection>(
      context: context,
      padding: EdgeInsets.zero,
      child: RemoteAdminSelectorSheet(currentTarget: currentTarget),
    );
  }

  @override
  ConsumerState<RemoteAdminSelectorSheet> createState() =>
      _RemoteAdminSelectorSheetState();
}

class _RemoteAdminSelectorSheetState
    extends ConsumerState<RemoteAdminSelectorSheet> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MeshNode> get _filteredNodes {
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final presenceMap = ref.watch(presenceMapProvider);

    // Filter to PKI-enabled nodes only, excluding our own node
    var nodeList =
        nodes.values.where((n) {
          if (n.nodeNum == myNodeNum) return false;
          return n.hasPublicKey;
        }).toList()..sort((a, b) {
          // Active nodes first, then by name
          final aActive = presenceConfidenceFor(presenceMap, a).isActive;
          final bActive = presenceConfidenceFor(presenceMap, b).isActive;
          if (aActive != bActive) return aActive ? -1 : 1;
          return a.displayName.compareTo(b.displayName);
        });

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      nodeList = nodeList.where((n) {
        final name = n.displayName.toLowerCase();
        final shortName = (n.shortName ?? '').toLowerCase();
        final nodeId = n.nodeNum.toRadixString(16).toLowerCase();
        return name.contains(query) ||
            shortName.contains(query) ||
            nodeId.contains(query);
      }).toList();
    }

    return nodeList;
  }

  @override
  Widget build(BuildContext context) {
    final nodes = _filteredNodes;
    final connectedDevice = ref.watch(connectedDeviceProvider);
    final accentColor = context.accentColor;
    final isLocalSelected = widget.currentTarget == null;
    final animationsEnabled = ref.watch(animationsEnabledProvider);
    final presenceMap = ref.watch(presenceMapProvider);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings, color: accentColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Remote Administration',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: context.textSecondary,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: context.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search nodes...',
                hintStyle: TextStyle(color: context.textTertiary, fontSize: 14),
                prefixIcon: Icon(
                  Icons.search,
                  color: context.textTertiary,
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: Icon(
                          Icons.clear,
                          color: context.textTertiary,
                          size: 18,
                        ),
                      )
                    : null,
                filled: true,
                fillColor: context.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          Divider(height: 1, color: context.border),

          // Local device option
          _DeviceTile(
            icon: Icons.bluetooth_connected,
            iconColor: isLocalSelected ? accentColor : context.textSecondary,
            title: connectedDevice?.name ?? 'Connected Device',
            subtitle: 'Local (via BLE/USB)',
            isSelected: isLocalSelected,
            onTap: () {
              Navigator.pop(context, const RemoteAdminSelection.local());
            },
          ),

          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.lock, size: 14, color: accentColor),
                const SizedBox(width: 6),
                Text(
                  'PKI-ENABLED NODES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  '${nodes.length} available',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: context.textTertiary),
                ),
              ],
            ),
          ),

          // Node list
          Flexible(
            child: nodes.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: nodes.length,
                    itemBuilder: (context, index) {
                      final node = nodes[index];
                      final isSelected = widget.currentTarget == node.nodeNum;
                      return Perspective3DSlide(
                        index: index,
                        direction: SlideDirection.left,
                        enabled: animationsEnabled,
                        child: _NodeAdminTile(
                          node: node,
                          isSelected: isSelected,
                          presence: presenceConfidenceFor(presenceMap, node),
                          lastHeardAge: lastHeardAgeFor(presenceMap, node),
                          onTap: () {
                            Navigator.pop(
                              context,
                              RemoteAdminSelection.remote(
                                node.nodeNum,
                                node.displayName,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),

          // Info banner
          Padding(
            padding: const EdgeInsets.all(16),
            child: StatusBanner.custom(
              color: Colors.orange,
              title:
                  'Remote admin requires the target node to have your public key in its Admin Keys.',
              borderRadius: 8,
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _searchQuery.isEmpty ? Icons.lock_open : Icons.search_off,
            size: 48,
            color: context.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isEmpty
                ? 'No PKI-enabled nodes available'
                : 'No nodes match "$_searchQuery"',
            style: TextStyle(color: context.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Nodes need PKI encryption enabled\nto accept remote admin commands',
                style: TextStyle(color: context.textTertiary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _DeviceTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = context.accentColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: isSelected
              ? accentColor.withValues(alpha: 0.08)
              : Colors.transparent,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Icon(icon, color: iconColor, size: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isSelected ? accentColor : context.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: accentColor, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _NodeAdminTile extends StatelessWidget {
  final MeshNode node;
  final bool isSelected;
  final PresenceConfidence presence;
  final Duration? lastHeardAge;
  final VoidCallback onTap;

  const _NodeAdminTile({
    required this.node,
    required this.isSelected,
    required this.presence,
    required this.lastHeardAge,
    required this.onTap,
  });

  Color _getAvatarColor() {
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

  @override
  Widget build(BuildContext context) {
    final accentColor = context.accentColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: isSelected
              ? accentColor.withValues(alpha: 0.08)
              : Colors.transparent,
          child: Row(
            children: [
              // Node avatar with PKI badge
              Stack(
                children: [
                  NodeAvatar(
                    text: node.avatarName,
                    color: _getAvatarColor(),
                    size: 44,
                  ),
                  // Active indicator
                  if (presence.isActive)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: accentColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: context.card, width: 2),
                        ),
                      ),
                    ),
                  // PKI lock badge
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: context.card,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Icon(Icons.lock, size: 10, color: accentColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.displayName,
                      style: TextStyle(
                        color: isSelected ? accentColor : context.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Tooltip(
                          message: kPresenceInferenceTooltip,
                          child: Text(
                            presenceStatusText(presence, lastHeardAge),
                            style: TextStyle(
                              color: presence.isActive
                                  ? accentColor.withValues(alpha: 0.8)
                                  : context.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• PKI enabled',
                          style: TextStyle(
                            color: context.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: accentColor, size: 22)
              else
                Icon(
                  Icons.chevron_right,
                  color: context.textTertiary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
