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

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants.dart';
import '../../../core/help/help_content.dart';
import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/ico_help_system.dart';
import '../../../models/mesh_models.dart';
import '../../../providers/app_providers.dart';

import '../models/nodedex_entry.dart';
import '../models/sigil_evolution.dart';
import '../providers/nodedex_providers.dart';
import '../services/patina_score.dart';

import '../services/trait_engine.dart';
import '../widgets/edge_detail_sheet.dart';
import '../widgets/animated_sigil_container.dart';
import '../widgets/field_note_widget.dart';
import '../widgets/identity_overlay_painter.dart';
import '../widgets/observation_timeline.dart';
import '../widgets/patina_stamp.dart';
import '../widgets/sigil_card_sheet.dart';
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
    AppLogging.nodeDex(
      'Detail screen opened for node ${widget.nodeNum} '
      '(!${widget.nodeNum.toRadixString(16).toUpperCase()})',
    );
  }

  @override
  void dispose() {
    AppLogging.nodeDex('Detail screen disposed for node ${widget.nodeNum}');
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = ref.watch(nodeDexEntryProvider(widget.nodeNum));
    final nodes = ref.watch(nodesProvider);
    final node = nodes[widget.nodeNum];
    final traitResult = ref.watch(nodeDexTraitProvider(widget.nodeNum));
    final disclosure = ref.watch(nodeDexDisclosureProvider(widget.nodeNum));
    final patinaResult = ref.watch(nodeDexPatinaProvider(widget.nodeNum));
    final scoredTraits = ref.watch(nodeDexScoredTraitsProvider(widget.nodeNum));

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

    final displayName =
        node?.displayName ?? entry.lastKnownName ?? 'Node ${entry.nodeNum}';
    final hexId =
        '!${entry.nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}';

    return HelpTourController(
      topicId: 'nodedex_detail',
      stepKeys: const {},
      child: GlassScaffold(
        title: displayName,
        actions: [
          IconButton(
            icon: Icon(
              Icons.style_outlined,
              size: 20,
              color: context.accentColor,
            ),
            tooltip: 'Share Sigil Card',
            onPressed: () {
              AppLogging.nodeDex(
                'Sigil card sheet opened for node ${widget.nodeNum}',
              );
              showSigilCardSheet(
                context: context,
                entry: entry,
                traitResult: traitResult,
                node: node,
              );
            },
          ),
          IcoHelpAppBarButton(topicId: 'nodedex_detail'),
        ],
        slivers: [
          // Sigil hero section with identity overlay
          SliverToBoxAdapter(
            child: IdentityOverlay(
              nodeNum: entry.nodeNum,
              density: disclosure.showOverlay ? disclosure.overlayDensity : 0,
              pointCount: 20,
              child: _SigilHeroSection(
                entry: entry,
                node: node,
                displayName: displayName,
                hexId: hexId,
                traitResult: traitResult,
                patinaResult: disclosure.showPatinaStamp ? patinaResult : null,
                evolution: SigilEvolution.fromPatina(
                  patinaResult.score,
                  trait: traitResult.primary,
                ),
              ),
            ),
          ),

          // Trait card
          if (disclosure.showPrimaryTrait)
            SliverToBoxAdapter(child: _TraitCard(traitResult: traitResult)),

          // Trait evidence bullets
          if (disclosure.showTraitEvidence && scoredTraits.isNotEmpty)
            SliverToBoxAdapter(
              child: TraitEvidenceList(
                observations: scoredTraits.first.evidence
                    .map((e) => e.observation)
                    .toList(),
                accentColor: entry.sigil?.primaryColor ?? context.accentColor,
                visible: disclosure.showTraitEvidence,
              ),
            ),

          // Field note (collapsible)
          if (disclosure.showFieldNote)
            SliverToBoxAdapter(
              child: CollapsibleFieldNote(
                entry: entry,
                trait: traitResult.primary,
                accentColor: entry.sigil?.primaryColor ?? context.accentColor,
                visible: disclosure.showFieldNote,
              ),
            ),

          // Observation timeline strip
          if (disclosure.showTimeline)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: ObservationTimeline(
                  entry: entry,
                  accentColor: entry.sigil?.primaryColor ?? context.accentColor,
                  showDensityMarkers: true,
                  showEncounterCount: true,
                ),
              ),
            ),

          // All scored traits list (progressive: only at Tier 3+)
          if (disclosure.showAllTraits && scoredTraits.length > 1)
            SliverToBoxAdapter(
              child: _ScoredTraitsList(
                scoredTraits: scoredTraits,
                showEvidence: disclosure.showTraitEvidence,
              ),
            ),

          // Discovery stats
          SliverToBoxAdapter(
            child: _DiscoveryStatsCard(entry: entry, node: node),
          ),

          // Signal records
          SliverToBoxAdapter(child: _SignalRecordsCard(entry: entry)),

          // Device info (from live MeshNode data) — placed near signal records
          if (node != null)
            SliverToBoxAdapter(child: _DeviceInfoCard(node: node)),

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
                AppLogging.nodeDex(
                  'Note editing started for node ${widget.nodeNum}',
                );
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

          // Encounter activity visualization
          if (entry.encounters.isNotEmpty)
            SliverToBoxAdapter(child: _EncounterActivityCard(entry: entry)),

          // Co-seen nodes — pinned header + body
          if (entry.coSeenNodes.isNotEmpty) ...[
            SliverPersistentHeader(
              pinned: true,
              delegate: _NodeDexStickyHeaderDelegate(
                title: 'Co-Seen Links',
                icon: Icons.auto_awesome,
                helpKey: 'coseen',
                trailing: '${entry.coSeenNodes.length} total',
              ),
            ),
            SliverToBoxAdapter(child: _CoSeenNodesBody(entry: entry)),
          ],

          // Bottom padding
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
          ),
        ],
      ),
    );
  }

  void _showTagSelector(BuildContext context, NodeDexEntry entry) {
    AppLogging.nodeDex(
      'Tag selector opened for node ${widget.nodeNum}, '
      'current tag: ${entry.socialTag?.name ?? 'none'}',
    );
    final notifier = ref.read(nodeDexProvider.notifier);
    final nodeNum = widget.nodeNum;
    final navigator = Navigator.of(context);

    AppBottomSheet.show<void>(
      context: context,
      child: SocialTagSelector(
        currentTag: entry.socialTag,
        onTagSelected: (tag) {
          AppLogging.nodeDex(
            'Tag selected for node $nodeNum: ${tag?.name ?? 'cleared'}',
          );
          // Update state BEFORE pop so the detail screen rebuilds immediately
          // while the sheet animates away.
          notifier.setSocialTag(nodeNum, tag);
          navigator.pop();
        },
      ),
    );
  }

  void _saveNote(NodeDexEntry entry) {
    final text = _noteController.text.trim();
    AppLogging.nodeDex(
      'Note saved for node ${widget.nodeNum}: '
      '${text.isEmpty ? '(cleared)' : '${text.length} chars'}',
    );
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

/// Displays the full ranked trait list with optional evidence.
///
/// Shown only at Tier 3+ disclosure. Each trait shows its name,
/// confidence, and (if enabled) the evidence bullets explaining
/// why the score was assigned.
class _ScoredTraitsList extends StatelessWidget {
  final List<ScoredTrait> scoredTraits;
  final bool showEvidence;

  const _ScoredTraitsList({
    required this.scoredTraits,
    required this.showEvidence,
  });

  @override
  Widget build(BuildContext context) {
    // Skip the first trait (already shown in the primary TraitCard).
    final remaining = scoredTraits.length > 1
        ? scoredTraits.sublist(1)
        : <ScoredTrait>[];

    if (remaining.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Additional Traits',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: remaining.map((scored) {
              final pct = (scored.confidence * 100).round();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: scored.trait.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: scored.trait.color.withValues(alpha: 0.15),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      scored.trait.displayLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scored.trait.color.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$pct%',
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: AppTheme.fontFamily,
                        color: scored.trait.color.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          if (showEvidence) ...[
            const SizedBox(height: 8),
            ...remaining
                .where((s) => s.evidence.isNotEmpty && s.confidence >= 0.2)
                .take(3)
                .expand(
                  (s) => s.evidence
                      .take(2)
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Container(
                                  width: 3,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: s.trait.color.withValues(alpha: 0.3),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${s.trait.displayLabel}: ${e.observation}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: context.textTertiary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ),
          ],
        ],
      ),
    );
  }
}

class _SigilHeroSection extends StatelessWidget {
  final NodeDexEntry entry;
  final MeshNode? node;
  final String displayName;
  final String hexId;
  final TraitResult traitResult;
  final PatinaResult? patinaResult;
  final SigilEvolution? evolution;

  const _SigilHeroSection({
    required this.entry,
    required this.node,
    required this.displayName,
    required this.hexId,
    required this.traitResult,
    this.patinaResult,
    this.evolution,
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
              AnimatedSigilContainer(
                sigil: entry.sigil,
                nodeNum: entry.nodeNum,
                size: 120,
                mode: isOnline
                    ? SigilAnimationMode.full
                    : SigilAnimationMode.ambientOnly,
                showGlow: isOnline,
                showTracer: isOnline,
                trait: traitResult.primary,
                evolution: evolution,
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

          // Patina stamp (shown when disclosure permits)
          if (patinaResult != null) ...[
            const SizedBox(height: 12),
            PatinaStamp(
              result: patinaResult!,
              accentColor: entry.sigil?.primaryColor ?? const Color(0xFF9CA3AF),
            ),
          ],

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
      helpKey: 'discovery',
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
      helpKey: 'signal',
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
      helpKey: 'social_tag',
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
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside the text field
        FocusScope.of(context).unfocus();
      },
      behavior: HitTestBehavior.translucent,
      child: _CardContainer(
        title: 'Note',
        icon: Icons.edit_note,
        helpKey: 'note',
        trailing: editing
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      onCancel();
                    },
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
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      onSave();
                    },
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
                  // Allow scroll to ensure field is visible above keyboard
                  scrollPadding: const EdgeInsets.all(80),
                  onTapOutside: (_) {
                    FocusScope.of(context).unfocus();
                  },
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
      helpKey: 'regions',
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
// Encounter Activity Card — visual encounter chart + compact recent list
// =============================================================================

/// Encounter activity visualization card.
///
/// Shows a bar chart of encounter frequency bucketed by day, with bars
/// colored by average signal quality. Below the chart, a paginated list
/// of recent encounters with signal metrics and optional calendar filter.
class _EncounterActivityCard extends StatefulWidget {
  final NodeDexEntry entry;

  const _EncounterActivityCard({required this.entry});

  @override
  State<_EncounterActivityCard> createState() => _EncounterActivityCardState();
}

class _EncounterActivityCardState extends State<_EncounterActivityCard> {
  int _currentPage = 0;
  DateTime? _selectedDate;

  @override
  void didUpdateWidget(covariant _EncounterActivityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset page if data changed and current page is out of range.
    final filtered = _filteredEncounters;
    final pageSize = NodeDexConfig.encounterPageSize;
    final totalPages = (filtered.length / pageSize).ceil();
    if (_currentPage >= totalPages && totalPages > 0) {
      _currentPage = totalPages - 1;
    }
  }

  List<EncounterRecord> get _filteredEncounters {
    final all = widget.entry.encounters.reversed.toList();
    if (_selectedDate == null) return all;
    return all.where((e) {
      return e.timestamp.year == _selectedDate!.year &&
          e.timestamp.month == _selectedDate!.month &&
          e.timestamp.day == _selectedDate!.day;
    }).toList();
  }

  Set<DateTime> get _encounterDates {
    final dates = <DateTime>{};
    for (final enc in widget.entry.encounters) {
      dates.add(
        DateTime(enc.timestamp.year, enc.timestamp.month, enc.timestamp.day),
      );
    }
    return dates;
  }

  Future<void> _showCalendarPicker() async {
    final encounters = widget.entry.encounters;
    if (encounters.isEmpty) return;

    final earliest = encounters
        .map((e) => e.timestamp)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final latest = encounters
        .map((e) => e.timestamp)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? latest,
      firstDate: DateTime(earliest.year, earliest.month, earliest.day),
      lastDate: DateTime(latest.year, latest.month, latest.day),
      helpText: 'Filter encounters by date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(surface: context.background),
          ),
          child: child!,
        );
      },
    );

    if (!mounted) return;

    if (picked != null) {
      // Check if any encounters exist on this date.
      final hasEncounters = _encounterDates.contains(picked);
      setState(() {
        _selectedDate = picked;
        _currentPage = 0;
        if (!hasEncounters) {
          // Keep the filter set — user will see "No encounters on this date"
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allEncounters = widget.entry.encounters.reversed.toList();
    final encounters = _filteredEncounters;
    final dateFormat = DateFormat('MMM d, HH:mm');
    final pageSize = NodeDexConfig.encounterPageSize;
    final totalPages = (encounters.length / pageSize).ceil();

    // Clamp current page to valid range.
    var page = _currentPage;
    if (page >= totalPages && totalPages > 0) {
      page = totalPages - 1;
    }

    final startIndex = page * pageSize;
    final endIndex = encounters.isEmpty
        ? 0
        : (startIndex + pageSize).clamp(0, encounters.length);
    final pageItems = encounters.isEmpty
        ? <EncounterRecord>[]
        : encounters.sublist(startIndex, endIndex);

    return _CardContainer(
      title: 'Encounter Activity',
      icon: Icons.insights,
      helpKey: 'encounters',
      trailing: Text(
        '${allEncounters.length} total',
        style: TextStyle(
          fontSize: 11,
          color: context.textTertiary,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Activity bar chart (always shows all encounters, not filtered)
          _EncounterBarChart(
            encounters: allEncounters,
            selectedDate: _selectedDate,
            onDayTapped: (day) {
              setState(() {
                if (_selectedDate == day) {
                  _selectedDate = null; // Toggle off
                } else {
                  _selectedDate = day;
                }
                _currentPage = 0;
              });
            },
          ),

          const SizedBox(height: 16),

          // Signal sparkline (if any encounters have SNR data)
          if (allEncounters.any((e) => e.snr != null)) ...[
            _SignalSparkline(encounters: allEncounters),
            const SizedBox(height: 16),
          ],

          // Recent encounters header with calendar action
          Row(
            children: [
              Icon(Icons.history, size: 12, color: context.textTertiary),
              const SizedBox(width: 4),
              Text(
                _selectedDate != null
                    ? DateFormat(
                        'MMM d, yyyy',
                      ).format(_selectedDate!).toUpperCase()
                    : 'RECENT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _selectedDate != null
                      ? context.accentColor
                      : context.textTertiary,
                  letterSpacing: 0.8,
                ),
              ),
              if (_selectedDate != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = null;
                      _currentPage = 0;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: context.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close, size: 10, color: context.accentColor),
                        const SizedBox(width: 2),
                        Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: context.accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (encounters.isNotEmpty)
                Text(
                  '${encounters.length} encounter${encounters.length == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 9, color: context.textTertiary),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _showCalendarPicker,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _selectedDate != null
                        ? context.accentColor.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.calendar_month,
                    size: 14,
                    color: _selectedDate != null
                        ? context.accentColor
                        : context.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Paginated encounter list
          if (pageItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  _selectedDate != null
                      ? 'No encounters on this date'
                      : 'No encounters recorded',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else
            ...pageItems.map(
              (enc) =>
                  _CompactEncounterRow(encounter: enc, dateFormat: dateFormat),
            ),

          // Pagination footer
          if (totalPages > 1) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PaginationButton(
                  icon: Icons.chevron_left,
                  enabled: page > 0,
                  onTap: () => setState(() => _currentPage = page - 1),
                ),
                const SizedBox(width: 12),
                Text(
                  '${page + 1} / $totalPages',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                const SizedBox(width: 12),
                _PaginationButton(
                  icon: Icons.chevron_right,
                  enabled: page < totalPages - 1,
                  onTap: () => setState(() => _currentPage = page + 1),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Bar chart showing encounter frequency bucketed by day.
///
/// Each bar represents one day. Bar height = number of encounters that day.
/// Bar color encodes average signal quality (SNR) for that day's encounters:
///   green = strong signal, amber = moderate, red = weak, accent = no data.
class _EncounterBarChart extends StatelessWidget {
  final List<EncounterRecord> encounters;
  final DateTime? selectedDate;
  final ValueChanged<DateTime>? onDayTapped;

  const _EncounterBarChart({
    required this.encounters,
    this.selectedDate,
    this.onDayTapped,
  });

  @override
  Widget build(BuildContext context) {
    if (encounters.isEmpty) return const SizedBox.shrink();

    // Bucket encounters by day.
    final buckets = <DateTime, List<EncounterRecord>>{};
    for (final enc in encounters) {
      final day = DateTime(
        enc.timestamp.year,
        enc.timestamp.month,
        enc.timestamp.day,
      );
      buckets.putIfAbsent(day, () => []).add(enc);
    }

    // Sort days chronologically.
    final sortedDays = buckets.keys.toList()..sort();

    // Single-day: show a summary bubble instead of a lonely bar.
    if (sortedDays.length == 1) {
      return _SingleDaySummary(
        day: sortedDays.first,
        encounters: buckets[sortedDays.first]!,
      );
    }

    // Fill gaps — include days with zero encounters so the chart shows
    // the full timeline without misleading compressed gaps.
    final allDays = <DateTime>[];
    var current = sortedDays.first;
    final last = sortedDays.last;
    while (!current.isAfter(last)) {
      allDays.add(current);
      current = current.add(const Duration(days: 1));
    }

    // Cap to last 60 days for readability.
    final displayDays = allDays.length > 60
        ? allDays.sublist(allDays.length - 60)
        : allDays;

    // Find max count for normalization.
    int maxCount = 1;
    for (final day in displayDays) {
      final count = buckets[day]?.length ?? 0;
      if (count > maxCount) maxCount = count;
    }

    final barChartHeight = 80.0;
    final dayFormat = DateFormat('MMM d');

    // Label positions — show first, last, and middle.
    final labelIndices = <int>{};
    labelIndices.addAll([0, displayDays.length - 1]);
    if (displayDays.length > 4) {
      labelIndices.add(displayDays.length ~/ 2);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chart
        SizedBox(
          height: barChartHeight,
          child: displayDays.length <= 7
              // Few days: center fixed-width bars so they don't stretch
              // into a solid wall of color.
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (int i = 0; i < displayDays.length; i++) ...[
                      GestureDetector(
                        onTap:
                            onDayTapped != null &&
                                (buckets[displayDays[i]]?.isNotEmpty ?? false)
                            ? () => onDayTapped!(displayDays[i])
                            : null,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 32,
                            minWidth: 16,
                          ),
                          child: _ActivityBar(
                            count: buckets[displayDays[i]]?.length ?? 0,
                            maxCount: maxCount,
                            maxHeight: barChartHeight,
                            color: _barColor(context, buckets[displayDays[i]]),
                            highlighted: selectedDate == displayDays[i],
                          ),
                        ),
                      ),
                      if (i < displayDays.length - 1) const SizedBox(width: 6),
                    ],
                  ],
                )
              // Many days: expand to fill width as before.
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (int i = 0; i < displayDays.length; i++) ...[
                      Expanded(
                        child: GestureDetector(
                          onTap:
                              onDayTapped != null &&
                                  (buckets[displayDays[i]]?.isNotEmpty ?? false)
                              ? () => onDayTapped!(displayDays[i])
                              : null,
                          child: _ActivityBar(
                            count: buckets[displayDays[i]]?.length ?? 0,
                            maxCount: maxCount,
                            maxHeight: barChartHeight,
                            color: _barColor(context, buckets[displayDays[i]]),
                            highlighted: selectedDate == displayDays[i],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),

        const SizedBox(height: 4),

        // Date labels
        SizedBox(
          height: 14,
          child: Stack(
            children: [
              for (final idx in labelIndices)
                Positioned(
                  left:
                      (idx / (displayDays.length - 1)) *
                      (MediaQuery.of(context).size.width - 100) *
                      0.85,
                  child: Text(
                    dayFormat.format(displayDays[idx]),
                    style: TextStyle(
                      fontSize: 9,
                      color: context.textTertiary,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Legend
        const SizedBox(height: 6),
        Row(
          children: [
            _LegendDot(color: _signalColor(context, 'good'), label: 'Strong'),
            const SizedBox(width: 10),
            _LegendDot(color: _signalColor(context, 'mid'), label: 'Fair'),
            const SizedBox(width: 10),
            _LegendDot(color: _signalColor(context, 'weak'), label: 'Weak'),
            const SizedBox(width: 10),
            _LegendDot(
              color: context.accentColor.withValues(alpha: 0.5),
              label: 'No data',
            ),
          ],
        ),
      ],
    );
  }

  Color _barColor(BuildContext context, List<EncounterRecord>? dayEncounters) {
    if (dayEncounters == null || dayEncounters.isEmpty) {
      return context.accentColor.withValues(alpha: 0.15);
    }

    // Average SNR for the day.
    final snrValues = dayEncounters
        .where((e) => e.snr != null)
        .map((e) => e.snr!)
        .toList();

    if (snrValues.isEmpty) {
      return context.accentColor.withValues(alpha: 0.5);
    }

    final avgSnr = snrValues.reduce((a, b) => a + b) / snrValues.length;

    if (avgSnr >= 5) return _signalColor(context, 'good');
    if (avgSnr >= -5) return _signalColor(context, 'mid');
    return _signalColor(context, 'weak');
  }

  static Color _signalColor(BuildContext context, String level) {
    switch (level) {
      case 'good':
        return const Color(0xFF4ADE80); // green
      case 'mid':
        return const Color(0xFFFBBF24); // amber
      case 'weak':
        return const Color(0xFFF87171); // red
      default:
        return context.accentColor;
    }
  }
}

/// Summary bubble shown when all encounters fall on a single day.
///
/// Replaces the lonely single-bar chart with a centered, informative
/// display showing the count, date, and signal quality breakdown.
class _SingleDaySummary extends StatelessWidget {
  final DateTime day;
  final List<EncounterRecord> encounters;

  const _SingleDaySummary({required this.day, required this.encounters});

  @override
  Widget build(BuildContext context) {
    final dayFormat = DateFormat('EEEE, MMM d');
    final count = encounters.length;

    // Signal quality breakdown.
    int strong = 0;
    int fair = 0;
    int weak = 0;
    int noData = 0;
    for (final enc in encounters) {
      if (enc.snr == null) {
        noData++;
      } else if (enc.snr! >= 5) {
        strong++;
      } else if (enc.snr! >= -5) {
        fair++;
      } else {
        weak++;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: context.accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.accentColor.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          // Large count
          Text(
            '$count',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: context.accentColor,
              fontFamily: AppTheme.fontFamily,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'encounter${count == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            dayFormat.format(day),
            style: TextStyle(
              fontSize: 11,
              color: context.textTertiary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          const SizedBox(height: 12),
          // Signal quality breakdown bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  if (strong > 0)
                    Expanded(
                      flex: strong,
                      child: Container(color: const Color(0xFF4ADE80)),
                    ),
                  if (fair > 0)
                    Expanded(
                      flex: fair,
                      child: Container(color: const Color(0xFFFBBF24)),
                    ),
                  if (weak > 0)
                    Expanded(
                      flex: weak,
                      child: Container(color: const Color(0xFFF87171)),
                    ),
                  if (noData > 0)
                    Expanded(
                      flex: noData,
                      child: Container(
                        color: context.accentColor.withValues(alpha: 0.3),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Legend row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (strong > 0) ...[
                _LegendDot(color: const Color(0xFF4ADE80), label: '$strong'),
                const SizedBox(width: 10),
              ],
              if (fair > 0) ...[
                _LegendDot(color: const Color(0xFFFBBF24), label: '$fair'),
                const SizedBox(width: 10),
              ],
              if (weak > 0) ...[
                _LegendDot(color: const Color(0xFFF87171), label: '$weak'),
                const SizedBox(width: 10),
              ],
              if (noData > 0)
                _LegendDot(
                  color: context.accentColor.withValues(alpha: 0.3),
                  label: '$noData',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Single bar in the activity chart.
class _ActivityBar extends StatelessWidget {
  final int count;
  final int maxCount;
  final double maxHeight;
  final Color color;
  final bool highlighted;

  const _ActivityBar({
    required this.count,
    required this.maxCount,
    required this.maxHeight,
    required this.color,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = count / maxCount;
    // Minimum visible height for non-zero days.
    final barHeight = count > 0
        ? math.max(3.0, fraction * (maxHeight - 4))
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.5),
      child: Tooltip(
        message: '$count encounter${count == 1 ? '' : 's'}',
        child: Container(
          height: barHeight,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
            border: highlighted
                ? Border.all(color: context.accentColor, width: 1.5)
                : null,
          ),
        ),
      ),
    );
  }
}

/// Legend dot + label for the bar chart.
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 9, color: context.textTertiary)),
      ],
    );
  }
}

/// Mini sparkline showing SNR trend over the most recent encounters.
class _SignalSparkline extends StatelessWidget {
  final List<EncounterRecord> encounters;

  const _SignalSparkline({required this.encounters});

  @override
  Widget build(BuildContext context) {
    // Take last 30 encounters with SNR, chronological order.
    final withSnr = encounters
        .where((e) => e.snr != null)
        .toList()
        .reversed
        .take(30)
        .toList();

    if (withSnr.length < 2) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.signal_cellular_alt,
              size: 12,
              color: context.textTertiary,
            ),
            const SizedBox(width: 4),
            Text(
              'SNR TREND',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: context.textTertiary,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            Text(
              'Last ${withSnr.length} readings',
              style: TextStyle(fontSize: 9, color: context.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: CustomPaint(
            size: const Size(double.infinity, 40),
            painter: _SparklinePainter(
              values: withSnr.map((e) => e.snr!.toDouble()).toList(),
              lineColor: context.accentColor,
              fillColor: context.accentColor.withValues(alpha: 0.1),
            ),
          ),
        ),
      ],
    );
  }
}

/// CustomPainter for the SNR sparkline.
class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;
  final Color fillColor;

  _SparklinePainter({
    required this.values,
    required this.lineColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minVal = values.reduce(math.min);
    final maxVal = values.reduce(math.max);
    final range = maxVal - minVal;
    final effectiveRange = range < 1 ? 1.0 : range;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final normalized = (values[i] - minVal) / effectiveRange;
      final y = size.height - (normalized * (size.height - 4)) - 2;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Close fill path along the bottom.
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // Draw dot on the most recent value (last point).
    final lastX = size.width;
    final lastNorm = (values.last - minVal) / effectiveRange;
    final lastY = size.height - (lastNorm * (size.height - 4)) - 2;
    canvas.drawCircle(Offset(lastX, lastY), 3, Paint()..color = lineColor);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return values != oldDelegate.values || lineColor != oldDelegate.lineColor;
  }
}

/// Compact row for a recent encounter — one line with date and metrics.
class _CompactEncounterRow extends StatelessWidget {
  final EncounterRecord encounter;
  final DateFormat dateFormat;

  const _CompactEncounterRow({
    required this.encounter,
    required this.dateFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          // Colored signal dot
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _dotColor(context),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          // Date
          Text(
            dateFormat.format(encounter.timestamp),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: context.textPrimary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          const Spacer(),
          // Metrics
          if (encounter.snr != null)
            _CompactMetric(
              label: 'SNR',
              value: '${encounter.snr}',
              context: context,
            ),
          if (encounter.rssi != null) ...[
            const SizedBox(width: 8),
            _CompactMetric(
              label: 'RSSI',
              value: '${encounter.rssi}',
              context: context,
            ),
          ],
          if (encounter.distanceMeters != null) ...[
            const SizedBox(width: 8),
            _CompactMetric(
              label: 'RNG',
              value: _shortDist(encounter.distanceMeters!),
              context: context,
            ),
          ],
        ],
      ),
    );
  }

  Color _dotColor(BuildContext context) {
    if (encounter.snr == null) {
      return context.textTertiary.withValues(alpha: 0.4);
    }
    if (encounter.snr! >= 5) return const Color(0xFF4ADE80);
    if (encounter.snr! >= -5) return const Color(0xFFFBBF24);
    return const Color(0xFFF87171);
  }

  String _shortDist(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)}km';
    return '${meters.round()}m';
  }
}

/// Tiny inline metric for compact encounter rows.
class _CompactMetric extends StatelessWidget {
  final String label;
  final String value;
  final BuildContext context;

  const _CompactMetric({
    required this.label,
    required this.value,
    required this.context,
  });

  @override
  Widget build(BuildContext _) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: TextStyle(fontSize: 9, color: context.textTertiary),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Co-seen Nodes Card
// =============================================================================

/// Body content for constellation links, used below the pinned header.
///
/// Pagination is self-contained — controls render at the bottom of the list.
class _CoSeenNodesBody extends ConsumerStatefulWidget {
  final NodeDexEntry entry;

  const _CoSeenNodesBody({required this.entry});

  @override
  ConsumerState<_CoSeenNodesBody> createState() => _CoSeenNodesBodyState();
}

class _CoSeenNodesBodyState extends ConsumerState<_CoSeenNodesBody> {
  int _currentPage = 0;

  @override
  void didUpdateWidget(covariant _CoSeenNodesBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset page if data changed and current page is out of range.
    final pageSize = NodeDexConfig.coSeenPageSize;
    final totalPages = (widget.entry.coSeenNodes.length / pageSize).ceil();
    if (_currentPage >= totalPages && totalPages > 0) {
      _currentPage = totalPages - 1;
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
    var page = _currentPage;
    if (page >= totalPages && totalPages > 0) {
      page = totalPages - 1;
    }

    final startIndex = page * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, totalCount);
    final pageItems = coSeenSorted.sublist(startIndex, endIndex);

    return _StickyCardBody(
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
                coSeenEntry?.lastKnownName ??
                'Node ${coSeen.key.toRadixString(16).toUpperCase()}';

            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    AppLogging.nodeDex(
                      'Constellation link tapped: '
                      '${widget.entry.nodeNum} → ${coSeen.key} '
                      '(co-seen ${relationship.count} times)',
                    );
                    HapticFeedback.selectionClick();
                    EdgeDetailSheet.show(
                      context: context,
                      fromNodeNum: widget.entry.nodeNum,
                      toNodeNum: coSeen.key,
                      onOpenNodeDetail: (nodeNum) {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                NodeDexDetailScreen(nodeNum: nodeNum),
                          ),
                        );
                      },
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
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
                        Tooltip(
                          message: 'Seen together ${relationship.count} times',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: context.accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.visibility_outlined,
                                  size: 10,
                                  color: context.accentColor,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${relationship.count}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: context.accentColor,
                                    fontFamily: AppTheme.fontFamily,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: context.textTertiary.withValues(alpha: 0.4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          // Pagination footer
          if (totalPages > 1) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PaginationButton(
                  icon: Icons.chevron_left,
                  enabled: page > 0,
                  onTap: () {
                    AppLogging.nodeDex(
                      'Constellation page changed to $page/$totalPages '
                      'for node ${widget.entry.nodeNum}',
                    );
                    setState(() => _currentPage = page - 1);
                  },
                ),
                const SizedBox(width: 12),
                Text(
                  '${page + 1} / $totalPages',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                const SizedBox(width: 12),
                _PaginationButton(
                  icon: Icons.chevron_right,
                  enabled: page < totalPages - 1,
                  onTap: () {
                    AppLogging.nodeDex(
                      'Constellation page changed to ${page + 2}/$totalPages '
                      'for node ${widget.entry.nodeNum}',
                    );
                    setState(() => _currentPage = page + 1);
                  },
                ),
              ],
            ),
          ],
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
      helpKey: 'device',
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
  final String? helpKey;
  final Widget child;

  const _CardContainer({
    required this.title,
    required this.icon,
    this.trailing,
    this.helpKey,
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
              if (helpKey != null) ...[
                const SizedBox(width: 4),
                _SectionInfoButton(helpKey: helpKey!),
              ],
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

// =============================================================================
// Section Info Button — inline contextual help
// =============================================================================

/// Small info icon that shows contextual help for a NodeDex detail section.
///
/// Tapping opens a bottom sheet with the section-specific help text
/// from [HelpContent.nodeDexSectionHelp]. This provides quick access
/// to section explanations without starting a full guided tour.
class _SectionInfoButton extends StatelessWidget {
  final String helpKey;

  const _SectionInfoButton({required this.helpKey});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showHelp(context),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.info_outline,
          size: 14,
          color: context.textTertiary.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  void _showHelp(BuildContext context) {
    final helpText = HelpContent.nodeDexSectionHelp[helpKey];
    if (helpText == null) return;

    HapticFeedback.selectionClick();
    AppBottomSheet.show<void>(
      context: context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 18,
                  color: context.accentColor,
                ),
                const SizedBox(width: 8),
                Text(
                  _titleForKey(helpKey),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              helpText,
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _titleForKey(String key) {
    switch (key) {
      case 'sigil':
        return 'Sigil';
      case 'trait':
        return 'Personality Trait';
      case 'discovery':
        return 'Discovery Stats';
      case 'signal':
        return 'Signal Records';
      case 'social_tag':
        return 'Classification';
      case 'note':
        return 'Note';
      case 'regions':
        return 'Region History';
      case 'encounters':
        return 'Recent Encounters';
      case 'constellation':
        return 'Constellation Links';
      case 'device':
        return 'Device Info';
      default:
        return 'Info';
    }
  }
}

// =============================================================================
// Sticky Card Header Delegate — pinned header for long scrollable sections
// =============================================================================

/// Persistent header delegate for NodeDex detail sections that can be long
/// (encounters, constellation links). Renders with the card styling and
/// pins at the top of the scroll view so the section context is never lost.
class _NodeDexStickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final IconData icon;
  final String helpKey;
  final String? trailing;

  _NodeDexStickyHeaderDelegate({
    required this.title,
    required this.icon,
    required this.helpKey,
    this.trailing,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final isPinned = shrinkOffset > 0 || overlapsContent;

    final borderRadius = BorderRadius.vertical(
      top: Radius.circular(isPinned ? 0 : 16),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: maxExtent,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isPinned
                  ? context.card.withValues(alpha: 0.95)
                  : context.card,
              borderRadius: borderRadius,
              border: Border(
                top: BorderSide(
                  color: context.border.withValues(alpha: 0.15),
                  width: 0.5,
                ),
                left: BorderSide(
                  color: context.border.withValues(alpha: 0.15),
                  width: 0.5,
                ),
                right: BorderSide(
                  color: context.border.withValues(alpha: 0.15),
                  width: 0.5,
                ),
              ),
              boxShadow: isPinned
                  ? [
                      BoxShadow(
                        color: context.background.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
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
                const SizedBox(width: 4),
                _SectionInfoButton(helpKey: helpKey),
                const Spacer(),
                if (trailing != null)
                  Text(
                    trailing!,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.textTertiary,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 44;

  @override
  double get minExtent => 44;

  @override
  bool shouldRebuild(covariant _NodeDexStickyHeaderDelegate oldDelegate) {
    return title != oldDelegate.title ||
        icon != oldDelegate.icon ||
        helpKey != oldDelegate.helpKey ||
        trailing != oldDelegate.trailing;
  }
}

// =============================================================================
// Sticky Card Body — content below a pinned header
// =============================================================================

/// Container for card body content that pairs with [_NodeDexStickyHeaderDelegate].
///
/// Provides the bottom half of the card styling (bottom rounded corners,
/// side and bottom borders, padding) to visually complete the card
/// started by the pinned header.
class _StickyCardBody extends StatelessWidget {
  final Widget child;

  const _StickyCardBody({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(
          bottom: BorderSide(
            color: context.border.withValues(alpha: 0.15),
            width: 0.5,
          ),
          left: BorderSide(
            color: context.border.withValues(alpha: 0.15),
            width: 0.5,
          ),
          right: BorderSide(
            color: context.border.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
      ),
      child: child,
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
