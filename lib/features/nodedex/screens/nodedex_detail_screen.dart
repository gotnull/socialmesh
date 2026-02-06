// SPDX-License-Identifier: GPL-3.0-or-later

// NodeDex Detail Screen — full node profile view.
//
// Displays the complete NodeDex profile for a single discovered node:
// - Large sigil display with procedural identity
// - Inferred personality trait with confidence
// - Discovery statistics (first seen, last seen, encounters, range)
// - Encounter history timeline
// - Region map (regions where this node has been observed)
// - Social tag selector
// - User note editor
// - Co-seen nodes (constellation connections)
//
// This screen is read-only for derived data (sigil, trait, stats)
// and editable for user-owned data (social tag, note).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../models/mesh_models.dart';
import '../../../providers/app_providers.dart';
import '../../../utils/snackbar.dart';
import '../models/nodedex_entry.dart';
import '../providers/nodedex_providers.dart';
import '../services/trait_engine.dart';
import '../widgets/sigil_painter.dart';
import '../widgets/trait_badge.dart';

/// Detail screen for a single NodeDex entry.
///
/// Shows the complete profile of a discovered node including its
/// procedural identity, inferred trait, encounter history, and
/// user-assigned metadata.
class NodeDexDetailScreen extends ConsumerStatefulWidget {
  /// The node number to display.
  final int nodeNum;

  const NodeDexDetailScreen({super.key, required this.nodeNum});

  @override
  ConsumerState<NodeDexDetailScreen> createState() =>
      _NodeDexDetailScreenState();
}

class _NodeDexDetailScreenState extends ConsumerState<NodeDexDetailScreen>
    with LifecycleSafeMixin<NodeDexDetailScreen> {
  late final TextEditingController _noteController;
  bool _editingNote = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = ref.watch(nodeDexEntryProvider(widget.nodeNum));
    final nodes = ref.watch(nodesProvider);
    final node = nodes[widget.nodeNum];
    final traitResult = ref.watch(nodeDexTraitProvider(widget.nodeNum));

    if (entry == null) {
      return GlassScaffold.body(
        title: 'NodeDex',
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.hexagon_outlined,
                size: 56,
                color: context.textTertiary.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'Node not found in NodeDex',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This node has not been discovered yet.',
                style: TextStyle(fontSize: 13, color: context.textTertiary),
              ),
            ],
          ),
        ),
      );
    }

    final displayName = node?.displayName ?? 'Node ${entry.nodeNum}';
    final hexId =
        '!${entry.nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}';

    return GlassScaffold(
      title: displayName,
      actions: [
        IconButton(
          icon: const Icon(Icons.copy_outlined, size: 20),
          tooltip: 'Copy Node ID',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: hexId));
            showSuccessSnackBar(context, 'Node ID copied');
          },
        ),
      ],
      slivers: [
        // Sigil hero section
        SliverToBoxAdapter(
          child: _SigilHeroSection(
            entry: entry,
            node: node,
            displayName: displayName,
            hexId: hexId,
            traitResult: traitResult,
          ),
        ),

        // Trait card
        SliverToBoxAdapter(child: _TraitCard(traitResult: traitResult)),

        // Discovery stats
        SliverToBoxAdapter(
          child: _DiscoveryStatsCard(entry: entry, node: node),
        ),

        // Signal records
        SliverToBoxAdapter(child: _SignalRecordsCard(entry: entry)),

        // Social tag
        SliverToBoxAdapter(
          child: _SocialTagCard(
            entry: entry,
            onEditTag: () => _showTagSelector(context, entry),
          ),
        ),

        // User note
        SliverToBoxAdapter(
          child: _UserNoteCard(
            entry: entry,
            editing: _editingNote,
            controller: _noteController,
            onStartEditing: () {
              setState(() {
                _editingNote = true;
                _noteController.text = entry.userNote ?? '';
              });
            },
            onSave: () => _saveNote(entry),
            onCancel: () {
              setState(() {
                _editingNote = false;
              });
            },
          ),
        ),

        // Region history
        if (entry.seenRegions.isNotEmpty)
          SliverToBoxAdapter(child: _RegionHistoryCard(entry: entry)),

        // Encounter timeline
        if (entry.encounters.isNotEmpty)
          SliverToBoxAdapter(child: _EncounterTimelineCard(entry: entry)),

        // Co-seen nodes
        if (entry.coSeenNodes.isNotEmpty)
          SliverToBoxAdapter(child: _CoSeenNodesCard(entry: entry)),

        // Device info (from live MeshNode data)
        if (node != null)
          SliverToBoxAdapter(child: _DeviceInfoCard(node: node)),

        // Bottom padding
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
        ),
      ],
    );
  }

  void _showTagSelector(BuildContext context, NodeDexEntry entry) {
    AppBottomSheet.show<void>(
      context: context,
      child: SocialTagSelector(
        currentTag: entry.socialTag,
        onTagSelected: (tag) {
          ref.read(nodeDexProvider.notifier).setSocialTag(widget.nodeNum, tag);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _saveNote(NodeDexEntry entry) {
    final text = _noteController.text.trim();
    ref
        .read(nodeDexProvider.notifier)
        .setUserNote(widget.nodeNum, text.isEmpty ? null : text);
    setState(() {
      _editingNote = false;
    });
  }
}

// =============================================================================
// Sigil Hero Section
// =============================================================================

class _SigilHeroSection extends StatelessWidget {
  final NodeDexEntry entry;
  final MeshNode? node;
  final String displayName;
  final String hexId;
  final TraitResult traitResult;

  const _SigilHeroSection({
    required this.entry,
    required this.node,
    required this.displayName,
    required this.hexId,
    required this.traitResult,
  });

  @override
  Widget build(BuildContext context) {
    final isOnline = _isOnline(node);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.card,
            (entry.sigil?.primaryColor ?? context.accentColor).withValues(
              alpha: 0.04,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.border.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          // Sigil display
          Stack(
            alignment: Alignment.center,
            children: [
              SigilDisplay(
                sigil: entry.sigil,
                nodeNum: entry.nodeNum,
                size: 120,
                showGlow: isOnline,
                trait: traitResult.primary,
              ),
              if (isOnline)
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AccentColors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.card, width: 2.5),
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
          const SizedBox(height: 16),

          // Name
          Text(
            displayName,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          // Hex ID
          Text(
            hexId,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.textTertiary,
              fontFamily: AppTheme.fontFamily,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),

          // Role badge (if known)
          if (node?.role != null && node!.role!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.textTertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                node!.role!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ),

          // Color palette
          const SizedBox(height: 16),
          _ColorPalette(entry: entry),
        ],
      ),
    );
  }

  bool _isOnline(MeshNode? node) {
    if (node == null) return false;
    final lastHeard = node.lastHeard;
    if (lastHeard == null) return false;
    return DateTime.now().difference(lastHeard).inMinutes < 30;
  }
}

/// Displays the sigil's 3-color palette as small circles.
class _ColorPalette extends StatelessWidget {
  final NodeDexEntry entry;

  const _ColorPalette({required this.entry});

  @override
  Widget build(BuildContext context) {
    final sigil = entry.sigil;
    if (sigil == null) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PaletteDot(color: sigil.primaryColor, label: 'Primary'),
        const SizedBox(width: 12),
        _PaletteDot(color: sigil.secondaryColor, label: 'Secondary'),
        const SizedBox(width: 12),
        _PaletteDot(color: sigil.tertiaryColor, label: 'Tertiary'),
      ],
    );
  }
}

class _PaletteDot extends StatelessWidget {
  final Color color;
  final String label;

  const _PaletteDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: context.background, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Trait Card
// =============================================================================

class _TraitCard extends StatelessWidget {
  final TraitResult traitResult;

  const _TraitCard({required this.traitResult});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TraitBadge.fromResult(
        result: traitResult,
        size: TraitBadgeSize.expanded,
        showConfidence: true,
      ),
    );
  }
}

// =============================================================================
// Discovery Stats Card
// =============================================================================

class _DiscoveryStatsCard extends StatelessWidget {
  final NodeDexEntry entry;
  final MeshNode? node;

  const _DiscoveryStatsCard({required this.entry, required this.node});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('HH:mm');
    final firstSeen = dateFormat.format(entry.firstSeen);
    final lastSeen = dateFormat.format(entry.lastSeen);
    final lastSeenTime = timeFormat.format(entry.lastSeen);
    final ageDays = entry.age.inDays;
    final ageLabel = ageDays == 0
        ? '${entry.age.inHours}h ago'
        : ageDays == 1
        ? '1 day ago'
        : '$ageDays days ago';

    return _CardContainer(
      title: 'Discovery',
      icon: Icons.explore_outlined,
      child: Column(
        children: [
          _InfoRow(
            label: 'First Discovered',
            value: firstSeen,
            icon: Icons.calendar_today_outlined,
          ),
          _InfoRow(
            label: 'Last Seen',
            value: '$lastSeen at $lastSeenTime',
            icon: Icons.schedule,
          ),
          _InfoRow(
            label: 'Known For',
            value: ageLabel,
            icon: Icons.timelapse_outlined,
          ),
          _InfoRow(
            label: 'Encounters',
            value: entry.encounterCount.toString(),
            icon: Icons.repeat,
          ),
          if (entry.maxDistanceSeen != null)
            _InfoRow(
              label: 'Max Range',
              value: _formatDistance(entry.maxDistanceSeen!),
              icon: Icons.straighten,
            ),
          _InfoRow(
            label: 'Messages',
            value: entry.messageCount.toString(),
            icon: Icons.chat_bubble_outline,
          ),
          _InfoRow(
            label: 'Regions',
            value: entry.regionCount.toString(),
            icon: Icons.public_outlined,
          ),
          _InfoRow(
            label: 'Positions',
            value: entry.distinctPositionCount.toString(),
            icon: Icons.pin_drop_outlined,
          ),
        ],
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
    return '${meters.round()} m';
  }
}

// =============================================================================
// Signal Records Card
// =============================================================================

class _SignalRecordsCard extends StatelessWidget {
  final NodeDexEntry entry;

  const _SignalRecordsCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final hasSignalData = entry.bestSnr != null || entry.bestRssi != null;
    if (!hasSignalData) return const SizedBox.shrink();

    return _CardContainer(
      title: 'Signal Records',
      icon: Icons.signal_cellular_alt,
      child: Column(
        children: [
          if (entry.bestSnr != null)
            _InfoRow(
              label: 'Best SNR',
              value: '${entry.bestSnr} dB',
              icon: Icons.trending_up,
              valueColor: _snrColor(entry.bestSnr!),
            ),
          if (entry.bestRssi != null)
            _InfoRow(
              label: 'Best RSSI',
              value: '${entry.bestRssi} dBm',
              icon: Icons.cell_tower,
              valueColor: _rssiColor(entry.bestRssi!),
            ),
        ],
      ),
    );
  }

  Color _snrColor(int snr) {
    if (snr >= 10) return AccentColors.green;
    if (snr >= 0) return AccentColors.yellow;
    if (snr >= -10) return AccentColors.orange;
    return AccentColors.red;
  }

  Color _rssiColor(int rssi) {
    if (rssi >= -80) return AccentColors.green;
    if (rssi >= -100) return AccentColors.yellow;
    if (rssi >= -115) return AccentColors.orange;
    return AccentColors.red;
  }
}

// =============================================================================
// Social Tag Card
// =============================================================================

class _SocialTagCard extends StatelessWidget {
  final NodeDexEntry entry;
  final VoidCallback onEditTag;

  const _SocialTagCard({required this.entry, required this.onEditTag});

  @override
  Widget build(BuildContext context) {
    return _CardContainer(
      title: 'Classification',
      icon: Icons.label_outline,
      trailing: GestureDetector(
        onTap: onEditTag,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: context.accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            entry.socialTag != null ? 'Change' : 'Classify',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.accentColor,
            ),
          ),
        ),
      ),
      child: entry.socialTag != null
          ? Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SocialTagBadge(tag: entry.socialTag!, onTap: onEditTag),
            )
          : Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'No classification assigned. Tap "Classify" to add one.',
                style: TextStyle(
                  fontSize: 13,
                  color: context.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
    );
  }
}

// =============================================================================
// User Note Card
// =============================================================================

class _UserNoteCard extends StatelessWidget {
  final NodeDexEntry entry;
  final bool editing;
  final TextEditingController controller;
  final VoidCallback onStartEditing;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _UserNoteCard({
    required this.entry,
    required this.editing,
    required this.controller,
    required this.onStartEditing,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return _CardContainer(
      title: 'Note',
      icon: Icons.edit_note,
      trailing: editing
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onCancel,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: context.textTertiary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: context.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onSave,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: context.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.accentColor,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : GestureDetector(
              onTap: onStartEditing,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: context.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  entry.userNote != null ? 'Edit' : 'Add Note',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.accentColor,
                  ),
                ),
              ),
            ),
      child: editing
          ? Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                controller: controller,
                maxLines: 4,
                maxLength: 280,
                autofocus: true,
                style: TextStyle(fontSize: 14, color: context.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Write a note about this node...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: context.textTertiary,
                  ),
                  filled: true,
                  fillColor: context.background,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: context.border.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: context.border.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: context.accentColor.withValues(alpha: 0.5),
                      width: 1.0,
                    ),
                  ),
                  counterStyle: TextStyle(
                    fontSize: 10,
                    color: context.textTertiary,
                  ),
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.only(top: 4),
              child: entry.userNote != null
                  ? Text(
                      entry.userNote!,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.textPrimary,
                        height: 1.5,
                      ),
                    )
                  : Text(
                      'No note yet. Tap "Add Note" to write one.',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textTertiary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
            ),
    );
  }
}

// =============================================================================
// Region History Card
// =============================================================================

class _RegionHistoryCard extends StatelessWidget {
  final NodeDexEntry entry;

  const _RegionHistoryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final regions = List<SeenRegion>.from(entry.seenRegions)
      ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));

    return _CardContainer(
      title: 'Regions',
      icon: Icons.public_outlined,
      child: Column(
        children: regions.map((region) {
          final dateFormat = DateFormat('MMM d');
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: context.accentColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.pin_drop_outlined,
                    size: 15,
                    color: context.accentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        region.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${region.encounterCount} encounter${region.encounterCount == 1 ? '' : 's'} '
                        '\u00B7 ${dateFormat.format(region.firstSeen)} \u2013 ${dateFormat.format(region.lastSeen)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// =============================================================================
// Encounter Timeline Card
// =============================================================================

class _EncounterTimelineCard extends StatelessWidget {
  final NodeDexEntry entry;

  const _EncounterTimelineCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    // Show most recent encounters (up to 10).
    final encounters = entry.encounters.reversed.take(10).toList();
    final dateFormat = DateFormat('MMM d, HH:mm');

    return _CardContainer(
      title: 'Recent Encounters',
      icon: Icons.timeline,
      child: Column(
        children: [
          for (int i = 0; i < encounters.length; i++)
            _EncounterTimelineRow(
              encounter: encounters[i],
              dateFormat: dateFormat,
              isFirst: i == 0,
              isLast: i == encounters.length - 1,
            ),
          if (entry.encounters.length > 10)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${entry.encounters.length - 10} more encounters not shown',
                style: TextStyle(
                  fontSize: 11,
                  color: context.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EncounterTimelineRow extends StatelessWidget {
  final EncounterRecord encounter;
  final DateFormat dateFormat;
  final bool isFirst;
  final bool isLast;

  const _EncounterTimelineRow({
    required this.encounter,
    required this.dateFormat,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final hasPosition =
        encounter.latitude != null && encounter.longitude != null;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Timeline line and dot
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  if (!isFirst)
                    Expanded(
                      child: Container(
                        width: 1.5,
                        color: context.accentColor.withValues(alpha: 0.2),
                      ),
                    ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isFirst
                          ? context.accentColor
                          : context.accentColor.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 1.5,
                        color: context.accentColor.withValues(alpha: 0.2),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Encounter details
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: context.border.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            dateFormat.format(encounter.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (encounter.snr != null)
                                _MiniMetric(
                                  label: 'SNR',
                                  value: '${encounter.snr}',
                                ),
                              if (encounter.snr != null &&
                                  encounter.rssi != null)
                                const SizedBox(width: 8),
                              if (encounter.rssi != null)
                                _MiniMetric(
                                  label: 'RSSI',
                                  value: '${encounter.rssi}',
                                ),
                              if (encounter.distanceMeters != null) ...[
                                const SizedBox(width: 8),
                                _MiniMetric(
                                  label: 'Range',
                                  value: _shortDist(encounter.distanceMeters!),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (hasPosition)
                      Icon(
                        Icons.pin_drop_outlined,
                        size: 14,
                        color: context.textTertiary.withValues(alpha: 0.5),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortDist(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
    return '${meters.round()}m';
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;

  const _MiniMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(fontSize: 10, color: context.textTertiary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: context.textSecondary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Co-seen Nodes Card
// =============================================================================

class _CoSeenNodesCard extends ConsumerStatefulWidget {
  final NodeDexEntry entry;

  const _CoSeenNodesCard({required this.entry});

  @override
  ConsumerState<_CoSeenNodesCard> createState() => _CoSeenNodesCardState();
}

class _CoSeenNodesCardState extends ConsumerState<_CoSeenNodesCard> {
  int _currentPage = 0;

  @override
  void didUpdateWidget(covariant _CoSeenNodesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.nodeNum != widget.entry.nodeNum) {
      _currentPage = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final nodes = ref.watch(nodesProvider);
    final pageSize = NodeDexConfig.coSeenPageSize;
    final dateFormat = DateFormat('d MMM yyyy');

    // Sort by co-seen count descending.
    final coSeenSorted = widget.entry.coSeenNodes.entries.toList()
      ..sort((a, b) => b.value.count.compareTo(a.value.count));

    final totalCount = coSeenSorted.length;
    final totalPages = (totalCount / pageSize).ceil();

    // Clamp current page to valid range.
    if (_currentPage >= totalPages && totalPages > 0) {
      _currentPage = totalPages - 1;
    }

    final startIndex = _currentPage * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, totalCount);
    final pageItems = coSeenSorted.sublist(startIndex, endIndex);

    return _CardContainer(
      title: 'Constellation Links',
      icon: Icons.auto_awesome,
      trailing: totalCount > 0
          ? Text(
              '$totalCount total',
              style: TextStyle(
                fontSize: 11,
                color: context.textTertiary,
                fontFamily: AppTheme.fontFamily,
              ),
            )
          : null,
      child: Column(
        children: [
          Text(
            'Nodes frequently seen in the same session',
            style: TextStyle(fontSize: 12, color: context.textTertiary),
          ),
          const SizedBox(height: 8),
          ...pageItems.map((coSeen) {
            final relationship = coSeen.value;
            final coSeenNode = nodes[coSeen.key];
            final coSeenEntry = ref.watch(nodeDexEntryProvider(coSeen.key));
            final name =
                coSeenNode?.displayName ??
                'Node ${coSeen.key.toRadixString(16).toUpperCase()}';

            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  SigilAvatar(
                    sigil: coSeenEntry?.sigil,
                    nodeNum: coSeen.key,
                    size: 32,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: context.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 10,
                              color: context.textTertiary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              dateFormat.format(relationship.lastSeen),
                              style: TextStyle(
                                fontSize: 10,
                                color: context.textTertiary,
                              ),
                            ),
                            if (relationship.messageCount > 0) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 10,
                                color: context.textTertiary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${relationship.messageCount}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: context.textTertiary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: context.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${relationship.count}x',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.accentColor,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Pagination footer
          if (totalPages > 1)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Previous button
                  _PaginationButton(
                    icon: Icons.chevron_left,
                    enabled: _currentPage > 0,
                    onTap: () => setState(() => _currentPage--),
                  ),
                  const SizedBox(width: 12),
                  // Page indicator
                  Text(
                    '${_currentPage + 1} / $totalPages',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Next button
                  _PaginationButton(
                    icon: Icons.chevron_right,
                    enabled: _currentPage < totalPages - 1,
                    onTap: () => setState(() => _currentPage++),
                  ),
                ],
              ),
            )
          // Single-page "show more" hint when exactly one page but more exist
          else if (totalCount > pageSize)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${totalCount - pageSize} more connections',
                style: TextStyle(
                  fontSize: 11,
                  color: context.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PaginationButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _PaginationButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled
              ? context.accentColor.withValues(alpha: 0.1)
              : context.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? context.accentColor.withValues(alpha: 0.3)
                : context.border.withValues(alpha: 0.2),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? context.accentColor : context.textTertiary,
        ),
      ),
    );
  }
}

// =============================================================================
// Device Info Card
// =============================================================================

class _DeviceInfoCard extends StatelessWidget {
  final MeshNode node;

  const _DeviceInfoCard({required this.node});

  @override
  Widget build(BuildContext context) {
    final hasDeviceInfo =
        node.hardwareModel != null ||
        node.firmwareVersion != null ||
        node.batteryLevel != null;

    if (!hasDeviceInfo) return const SizedBox.shrink();

    return _CardContainer(
      title: 'Device',
      icon: Icons.developer_board_outlined,
      child: Column(
        children: [
          if (node.hardwareModel != null)
            _InfoRow(
              label: 'Hardware',
              value: node.hardwareModel!,
              icon: Icons.memory,
            ),
          if (node.firmwareVersion != null)
            _InfoRow(
              label: 'Firmware',
              value: node.firmwareVersion!,
              icon: Icons.system_update_outlined,
            ),
          if (node.batteryLevel != null)
            _InfoRow(
              label: 'Battery',
              value: '${node.batteryLevel}%',
              icon: Icons.battery_std,
              valueColor: _batteryColor(node.batteryLevel!),
            ),
          if (node.uptimeSeconds != null)
            _InfoRow(
              label: 'Uptime',
              value: _formatUptime(node.uptimeSeconds!),
              icon: Icons.timer_outlined,
            ),
          if (node.channelUtilization != null)
            _InfoRow(
              label: 'Channel Util',
              value: '${node.channelUtilization!.toStringAsFixed(1)}%',
              icon: Icons.bar_chart,
            ),
          if (node.airUtilTx != null)
            _InfoRow(
              label: 'Air Util TX',
              value: '${node.airUtilTx!.toStringAsFixed(1)}%',
              icon: Icons.cell_tower,
            ),
        ],
      ),
    );
  }

  Color _batteryColor(int level) {
    if (level > 50) return AccentColors.green;
    if (level > 20) return AccentColors.orange;
    return AccentColors.red;
  }

  String _formatUptime(int seconds) {
    if (seconds >= 86400) {
      final days = seconds ~/ 86400;
      final hours = (seconds % 86400) ~/ 3600;
      return '${days}d ${hours}h';
    }
    if (seconds >= 3600) {
      final hours = seconds ~/ 3600;
      final mins = (seconds % 3600) ~/ 60;
      return '${hours}h ${mins}m';
    }
    final mins = seconds ~/ 60;
    return '${mins}m';
  }
}

// =============================================================================
// Shared Card Widgets
// =============================================================================

/// Standard card container used across all detail cards.
///
/// Provides a consistent header with icon + title + optional trailing
/// widget, and wraps the child content in a styled container.
class _CardContainer extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  final Widget child;

  const _CardContainer({
    required this.title,
    required this.icon,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.border.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(icon, size: 16, color: context.textTertiary),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.textTertiary,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// An info row used in stat cards.
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: context.textTertiary.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: context.textSecondary),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? context.textPrimary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}
