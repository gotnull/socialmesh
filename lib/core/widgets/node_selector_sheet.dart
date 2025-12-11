import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import 'app_bottom_sheet.dart';

/// Result from node selector - either a specific node or broadcast
class NodeSelection {
  final int? nodeNum; // null means broadcast to all
  final bool isBroadcast;

  const NodeSelection.broadcast() : nodeNum = null, isBroadcast = true;

  const NodeSelection.node(this.nodeNum) : isBroadcast = false;
}

/// Generic reusable node selector bottom sheet
class NodeSelectorSheet extends ConsumerStatefulWidget {
  final String title;
  final bool allowBroadcast;
  final int? initialSelection;
  final String? broadcastLabel;
  final String? broadcastSubtitle;

  const NodeSelectorSheet({
    super.key,
    this.title = 'Select Node',
    this.allowBroadcast = true,
    this.initialSelection,
    this.broadcastLabel,
    this.broadcastSubtitle,
  });

  /// Show the node selector and return the selection
  static Future<NodeSelection?> show(
    BuildContext context, {
    String title = 'Select Node',
    bool allowBroadcast = true,
    int? initialSelection,
    String? broadcastLabel,
    String? broadcastSubtitle,
  }) {
    return AppBottomSheet.show<NodeSelection>(
      context: context,
      padding: EdgeInsets.zero,
      child: NodeSelectorSheet(
        title: title,
        allowBroadcast: allowBroadcast,
        initialSelection: initialSelection,
        broadcastLabel: broadcastLabel,
        broadcastSubtitle: broadcastSubtitle,
      ),
    );
  }

  @override
  ConsumerState<NodeSelectorSheet> createState() => _NodeSelectorSheetState();
}

class _NodeSelectorSheetState extends ConsumerState<NodeSelectorSheet> {
  late int? _selectedNodeNum;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedNodeNum = widget.initialSelection;
  }

  List<MeshNode> get _filteredNodes {
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);

    var nodeList = nodes.values.where((n) => n.nodeNum != myNodeNum).toList()
      ..sort((a, b) {
        // Online nodes first, then by name
        if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
        final aName = a.longName ?? a.shortName ?? '';
        final bName = b.longName ?? b.shortName ?? '';
        return aName.compareTo(bName);
      });

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      nodeList = nodeList.where((n) {
        final name = (n.longName ?? n.shortName ?? '').toLowerCase();
        final shortName = (n.shortName ?? '').toLowerCase();
        return name.contains(query) || shortName.contains(query);
      }).toList();
    }

    return nodeList;
  }

  @override
  Widget build(BuildContext context) {
    final nodes = _filteredNodes;
    final isBroadcastSelected =
        widget.allowBroadcast && _selectedNodeNum == null;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    final selection =
                        _selectedNodeNum == null && widget.allowBroadcast
                        ? const NodeSelection.broadcast()
                        : _selectedNodeNum != null
                        ? NodeSelection.node(_selectedNodeNum)
                        : null;
                    Navigator.pop(context, selection);
                  },
                  child: Text(
                    'Done',
                    style: TextStyle(
                      color: context.accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search nodes...',
                hintStyle: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppTheme.textTertiary,
                  size: 20,
                ),
                filled: true,
                fillColor: AppTheme.darkBackground,
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

          const Divider(height: 1, color: AppTheme.darkBorder),

          // Broadcast option
          if (widget.allowBroadcast) ...[
            _NodeTile(
              icon: Icons.broadcast_on_personal,
              iconColor: context.accentColor,
              title: widget.broadcastLabel ?? 'All Nodes',
              subtitle: widget.broadcastSubtitle ?? 'Broadcast to everyone',
              isSelected: isBroadcastSelected,
              onTap: () {
                setState(() => _selectedNodeNum = null);
                Navigator.pop(context, const NodeSelection.broadcast());
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'DIRECT MESSAGE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textTertiary,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${nodes.length} nodes',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Node list
          Flexible(
            child: nodes.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: nodes.length,
                    itemBuilder: (context, index) {
                      final node = nodes[index];
                      final displayName =
                          node.longName ??
                          node.shortName ??
                          '!${node.nodeNum.toRadixString(16)}';
                      return _NodeTile(
                        icon: Icons.person,
                        iconColor: node.isOnline
                            ? context.accentColor
                            : AppTheme.textTertiary,
                        title: displayName,
                        subtitle: node.shortName ?? 'Unknown',
                        isSelected: _selectedNodeNum == node.nodeNum,
                        isOnline: node.isOnline,
                        onTap: () {
                          setState(() => _selectedNodeNum = node.nodeNum);
                          Navigator.pop(
                            context,
                            NodeSelection.node(node.nodeNum),
                          );
                        },
                      );
                    },
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
          Icon(Icons.search_off, size: 48, color: AppTheme.textTertiary),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isEmpty
                ? 'No nodes available'
                : 'No nodes match "$_searchQuery"',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NodeTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isSelected;
  final bool isOnline;
  final VoidCallback onTap;

  const _NodeTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    this.isOnline = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: isSelected
              ? context.accentColor.withValues(alpha: 0.08)
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
                child: Stack(
                  children: [
                    Center(child: Icon(icon, color: iconColor, size: 22)),
                    if (isOnline)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: context.accentColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.darkSurface,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isSelected ? context.accentColor : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: context.accentColor, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
