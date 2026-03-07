// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// SIP Hub Screen — Socialmesh peer discovery and ephemeral DM hub.
//
// Design patterns used (matching the rest of the app):
// - GlassScaffold with slivers and SectionHeaderDelegates
// - BouncyTap card containers (like Channels, Signals)
// - Card styling: context.card + border + radius12 (like _FlightTile)
// - SigilAvatar with SigilEvolution (like NodeDex)
// - Timestamps on conversation tiles (like Channels)
// - AppBarOverflowMenu for secondary actions
// - Debug counters behind overflow menu, not inline

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/section_header.dart';
import '../../features/nodedex/models/nodedex_entry.dart';
import '../../features/nodedex/models/sigil_evolution.dart';
import '../../features/nodedex/providers/nodedex_providers.dart';
import '../../features/nodedex/services/patina_score.dart';
import '../../features/nodedex/services/trait_engine.dart';
import '../../features/nodedex/widgets/sigil_painter.dart';
import '../../features/nodes/node_display_name_resolver.dart';
import '../../models/mesh_models.dart';
import '../../core/constants.dart';
import '../../providers/app_providers.dart';
import '../../providers/sip_providers.dart';
import '../../services/haptic_service.dart';
import '../../services/protocol/sip/sip_codec.dart';
import '../../services/protocol/sip/sip_discovery.dart';
import '../../services/protocol/sip/sip_dm.dart';
import '../../services/protocol/sip/sip_handshake.dart';
import '../../utils/snackbar.dart';
import '../mrrp_harness/mrrp_harness_home_screen.dart';
import 'sip_dm_screen.dart';

/// SIP Hub — discover nearby Socialmesh peers, handshake, and chat.
///
/// Entry point for all SIP UI. Gated behind SIP_ENABLED feature flag
/// at the drawer level — this screen assumes SIP is enabled.
class SipHubScreen extends ConsumerStatefulWidget {
  const SipHubScreen({super.key});

  @override
  ConsumerState<SipHubScreen> createState() => _SipHubScreenState();
}

/// Auto-scan interval for background peer discovery.
const Duration _kAutoScanInterval = Duration(seconds: 60);

class _SipHubScreenState extends ConsumerState<SipHubScreen>
    with SingleTickerProviderStateMixin {
  bool _scanning = false;
  Timer? _autoScanTimer;
  Timer? _scanTimeoutTimer;
  int _scanStartEpoch = -1;
  String _lastLogSignature = '';

  /// Continuous rotation controller for the radar icon when auto-scan is on.
  late final AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // Restore persisted auto-scan state after the first frame so that
    // providers are available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final autoScan = ref.read(sipAutoScanProvider);
      if (autoScan) {
        _startAutoScanTimer();
        _radarController.repeat();
        _performScan();
      }
    });
  }

  @override
  void dispose() {
    _radarController.dispose();
    _autoScanTimer?.cancel();
    _scanTimeoutTimer?.cancel();
    super.dispose();
  }

  void _toggleAutoScan() {
    final l10n = context.l10n;
    ref.read(hapticServiceProvider).trigger(HapticType.light);
    final wasEnabled = ref.read(sipAutoScanProvider);
    final nowEnabled = !wasEnabled;
    ref.read(sipAutoScanProvider.notifier).setEnabled(nowEnabled);
    setState(() {
      if (nowEnabled) {
        _performScan();
        _startAutoScanTimer();
        _radarController.repeat();
        showSuccessSnackBar(context, l10n.sipAutoScanEnabled);
      } else {
        _autoScanTimer?.cancel();
        _autoScanTimer = null;
        _radarController.stop();
        _radarController.reset();
        showInfoSnackBar(context, l10n.sipAutoScanDisabled);
      }
    });
  }

  void _startAutoScanTimer() {
    _autoScanTimer?.cancel();
    _autoScanTimer = Timer.periodic(_kAutoScanInterval, (_) {
      if (mounted) _performScan();
    });
  }

  void _onScan() {
    ref.read(hapticServiceProvider).trigger(HapticType.light);
    _performScan();
  }

  void _performScan() {
    final discovery = ref.read(sipDiscoveryProvider);
    AppLogging.sip('SIP_HUB: scan tapped, discovery=${discovery != null}');
    if (discovery == null) return;

    final outbound = discovery.buildRollcallReq();
    if (outbound != null) {
      final protocol = ref.read(protocolServiceProvider);
      protocol.sendSipPacket(outbound.encoded);
      AppLogging.sip(
        'SIP_HUB: ROLLCALL_REQ dispatched ${outbound.encoded.length}B',
      );
      setState(() => _scanning = true);
      // Record epoch at scan start; stop scanning when it bumps (peers arrive).
      _scanStartEpoch = ref.read(sipPeerCacheEpochProvider);
      // Safety timeout: stop scanning after 10s regardless.
      _scanTimeoutTimer?.cancel();
      _scanTimeoutTimer = Timer(const Duration(seconds: 10), () {
        if (mounted) setState(() => _scanning = false);
      });
    }
  }

  /// Called from build — checks if peers arrived since scan started.
  void _checkScanComplete(int currentEpoch) {
    if (_scanning && currentEpoch > _scanStartEpoch) {
      // Peers have arrived — keep indicator briefly for perceived smoothness.
      _scanTimeoutTimer?.cancel();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _scanning = false);
      });
    }
  }

  /// Initiate handshake directly with a peer (no detail sheet).
  void _initiateHandshake(SipPeerCapability peer) {
    final localContext = context;
    final localL10n = localContext.l10n;
    final haptics = ref.read(hapticServiceProvider);
    haptics.trigger(HapticType.medium);

    // Check for existing DM session with this peer first.
    final dm = ref.read(sipDmManagerProvider);
    final sessions = dm?.activeSessions ?? [];
    final existing = sessions.where((s) => s.peerNodeId == peer.nodeId);
    if (existing.isNotEmpty) {
      // Already have a conversation — open it directly.
      Navigator.of(localContext).push(
        MaterialPageRoute<void>(
          builder: (_) => SipDmScreen(sessionTag: existing.first.sessionTag),
        ),
      );
      return;
    }

    final handshake = ref.read(sipHandshakeProvider);
    if (handshake == null) {
      showErrorSnackBar(localContext, localL10n.sipHandshakeFailed);
      return;
    }

    // Already handshaking — let the chip show progress, don't interrupt.
    final currentState = handshake.getState(peer.nodeId);
    if (currentState != SipHandshakeState.idle &&
        currentState != SipHandshakeState.failed &&
        currentState != SipHandshakeState.timedOut) {
      return;
    }

    final frame = handshake.initiateHandshake(peer.nodeId);
    if (frame == null) return;

    final encoded = SipCodec.encode(frame);
    if (encoded == null) {
      showErrorSnackBar(localContext, localL10n.sipHandshakeFailed);
      return;
    }

    final protocol = ref.read(protocolServiceProvider);
    protocol.sendSipPacket(encoded);
    ref.read(sipCountersProvider).recordHandshakeInitiated();
    // No snackbar — the handshake chip updates in real-time via epoch.
  }

  void _showCounters() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radius16),
        ),
      ),
      builder: (ctx) => const _SipCountersSheet(),
    );
  }

  void _openHarness() {
    ref.read(hapticServiceProvider).trigger(HapticType.light);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MrrpHarnessHomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sipEnabled = ref.watch(sipEnabledProvider);
    final peers = ref.watch(sipDiscoveredPeersProvider);
    final sessions = ref.watch(sipActiveSessionsProvider);
    final peerCount = ref.watch(sipPeerCountProvider);
    final peerEpoch = ref.watch(sipPeerCacheEpochProvider);
    final autoScanEnabled = ref.watch(sipAutoScanProvider);

    // Stop scanning indicator when peers arrive (epoch bumps).
    if (_scanning) _checkScanComplete(peerEpoch);

    // Deduplicate identical log lines across rebuilds.
    final sig =
        '$sipEnabled|$peerCount|${sessions.length}'; // lint-allow: hardcoded-string
    if (sig != _lastLogSignature) {
      _lastLogSignature = sig;
      AppLogging.sip(
        'SIP_HUB: build — enabled=$sipEnabled, peers=$peerCount, '
        'sessions=${sessions.length}', // lint-allow: hardcoded-string
      );
    }

    // Filter out peers that already have an active DM session —
    // those appear under Conversations only (issue 3).
    final sessionNodeIds = sessions.map((s) => s.peerNodeId).toSet();
    final unconnectedPeers = peers
        .where((p) => !sessionNodeIds.contains(p.nodeId))
        .toList();

    final hasPeers = unconnectedPeers.isNotEmpty;
    final hasSessions = sessions.isNotEmpty;
    final isEmpty = !hasPeers && !hasSessions && !_scanning;

    // lint-allow: haptic-feedback — keyboard dismissal, not interactive action
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold(
        title: l10n.sipHubTitle,
        actions: [
          // Scan button — rotates continuously when auto-scan is enabled
          IconButton(
            icon: _scanning
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.textSecondary,
                    ),
                  )
                : AnimatedBuilder(
                    animation: _radarController,
                    builder: (context, child) => Transform.rotate(
                      angle: _radarController.value * 2 * 3.14159265,
                      child: child,
                    ),
                    child: Icon(
                      Icons.radar,
                      size: 22,
                      color: autoScanEnabled ? AccentColors.green : null,
                    ),
                  ),
            tooltip: l10n.sipDiscoveryScanButton,
            onPressed: _scanning
                ? null
                : autoScanEnabled
                ? _toggleAutoScan
                : _onScan,
          ),
          // Overflow menu
          AppBarOverflowMenu<String>(
            onSelected: (value) {
              if (value == 'autoscan') {
                _toggleAutoScan(); // lint-allow: hardcoded-string
              }
              if (value == 'counters') {
                _showCounters(); // lint-allow: hardcoded-string
              }
              if (value == 'harness') {
                _openHarness(); // lint-allow: hardcoded-string
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'autoscan', // lint-allow: hardcoded-string
                child: ListTile(
                  leading: Icon(
                    autoScanEnabled ? Icons.sync_disabled : Icons.sync,
                  ),
                  title: Text(l10n.sipAutoScanToggle),
                  trailing: autoScanEnabled
                      ? Icon(Icons.check, size: 18, color: AccentColors.green)
                      : null,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              PopupMenuItem(
                value: 'counters', // lint-allow: hardcoded-string
                child: ListTile(
                  leading: const Icon(Icons.analytics_outlined),
                  title: Text(l10n.sipCountersTitle),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              if (AppFeatureFlags.isMrrpHarnessEnabled)
                PopupMenuItem(
                  value: 'harness', // lint-allow: hardcoded-string
                  child: ListTile(
                    leading: const Icon(Icons.hub),
                    title: Text(l10n.mrrpHarnessDrawerLabel),
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ],
        slivers: isEmpty
            ? _buildEmptySlivers(context)
            : _buildContentSlivers(context, unconnectedPeers, sessions),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty state — icon + headline + description + scan button
  // ---------------------------------------------------------------------------

  List<Widget> _buildEmptySlivers(BuildContext context) {
    final l10n = context.l10n;

    return [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi_tethering,
                  size: 56,
                  color: context.textTertiary.withValues(alpha: 0.4),
                ),
                const SizedBox(height: AppTheme.spacing16),
                Text(
                  l10n.sipHubEmptyTitle,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing8),
                Text(
                  l10n.sipHubEmptyDescription,
                  style: TextStyle(fontSize: 13, color: context.textTertiary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacing24),
                if (_scanning)
                  Padding(
                    padding: const EdgeInsets.only(top: AppTheme.spacing8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.accentColor,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing8),
                        Text(
                          l10n.sipScanningIndicator,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  FilledButton.icon(
                    onPressed: _onScan,
                    icon: const Icon(Icons.radar, size: 18),
                    label: Text(l10n.sipDiscoveryScanButton),
                  ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Content slivers: conversations + peers (with horizontal padding)
  // ---------------------------------------------------------------------------

  List<Widget> _buildContentSlivers(
    BuildContext context,
    List<SipPeerCapability> peers,
    List<SipDmSession> sessions,
  ) {
    return [
      const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacing8)),

      // Active conversations (shown first — most important)
      if (sessions.isNotEmpty) ...[
        SliverPersistentHeader(
          pinned: true,
          delegate: SectionHeaderDelegate(
            title: context.l10n.sipHubSectionConversations,
            count: sessions.length,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _ConversationTile(session: sessions[index]),
              childCount: sessions.length,
            ),
          ),
        ),
      ],

      // Discovered peers (excluding those already in Conversations)
      if (peers.isNotEmpty || _scanning) ...[
        SliverPersistentHeader(
          pinned: true,
          delegate: SectionHeaderDelegate(
            title: context.l10n.sipHubSectionPeers,
            count: peers.length,
            trailing: _scanning
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: context.textTertiary,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacing6),
                      Text(
                        context.l10n.sipScanningIndicator,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                  )
                : null,
          ),
        ),
        if (peers.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _PeerTile(
                  peer: peers[index],
                  onHandshake: () => _initiateHandshake(peers[index]),
                ),
                childCount: peers.length,
              ),
            ),
          ),

        // Scanning shimmer placeholders (shown while scanning, no peers yet)
        if (_scanning && peers.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => const _ShimmerPeerPlaceholder(),
                childCount: 3,
              ),
            ),
          ),
      ],

      // Bottom safe area
      SliverToBoxAdapter(
        child: SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
      ),
    ];
  }
}

// =============================================================================
// Peer tile — card container + BouncyTap (matches Channels pattern)
// =============================================================================

class _PeerTile extends ConsumerWidget {
  final SipPeerCapability peer;
  final VoidCallback onHandshake;

  const _PeerTile({required this.peer, required this.onHandshake});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(nodeDexEntryProvider(peer.nodeId));
    final nodes = ref.watch(nodesProvider);
    final node = nodes[peer.nodeId];
    final hsState = ref.watch(sipHandshakeStateProvider(peer.nodeId));
    final patinaResult = ref.watch(nodeDexPatinaProvider(peer.nodeId));
    final traitResult = ref.watch(nodeDexTraitProvider(peer.nodeId));

    // Check if a DM session already exists for this peer.
    ref.watch(sipDmEpochProvider); // rebuild when DM sessions change
    final dm = ref.watch(sipDmManagerProvider);
    final hasDmSession =
        dm?.activeSessions.any((s) => s.peerNodeId == peer.nodeId) ?? false;

    final displayName = _resolveDisplayName(entry, node, peer.nodeId);
    final hexId =
        '!${peer.nodeId.toRadixString(16).toUpperCase().padLeft(4, '0')}';

    // Block taps while handshake is in-progress.
    final isBusy = _isHandshaking(hsState);

    return BouncyTap(
      onTap: isBusy ? null : onHandshake,
      onLongPress: isBusy ? null : onHandshake,
      enabled: !isBusy,
      scaleFactor: 0.98,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(color: context.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing14),
          child: Row(
            children: [
              // Sigil avatar with evolution
              _buildAvatar(context, entry, patinaResult, traitResult),
              const SizedBox(width: AppTheme.spacing14),

              // Name, hex ID, and status badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name row
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing6),
                        Text(
                          hexId,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: context.textTertiary,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing6),

                    // Status row: handshake state + last seen
                    Row(
                      children: [
                        _HandshakeChip(
                          state: hsState,
                          hasDmSession: hasDmSession,
                        ),
                        const SizedBox(width: AppTheme.spacing8),
                        _LastSeenChip(lastSeenMs: peer.lastSeenMs),
                      ],
                    ),
                  ],
                ),
              ),

              // Chevron — chat icon when DM session exists
              const SizedBox(width: AppTheme.spacing4),
              Icon(
                hasDmSession ? Icons.chat_bubble_outline : Icons.chevron_right,
                size: 20,
                color: hasDmSession
                    ? AccentColors.green.withValues(alpha: 0.7)
                    : context.textTertiary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(
    BuildContext context,
    NodeDexEntry? entry,
    PatinaResult patinaResult,
    TraitResult traitResult,
  ) {
    if (entry?.sigil != null) {
      return SigilAvatar(
        sigil: entry!.sigil,
        nodeNum: peer.nodeId,
        size: 48,
        evolution: SigilEvolution.fromPatina(
          patinaResult.score,
          trait: traitResult.primary,
        ),
      );
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: context.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Icon(
        Icons.sensors,
        size: 24,
        color: context.accentColor.withValues(alpha: 0.7),
      ),
    );
  }

  static bool _isHandshaking(SipHandshakeState state) => switch (state) {
    SipHandshakeState.helloSent ||
    SipHandshakeState.challengeReceived ||
    SipHandshakeState.responseSent ||
    SipHandshakeState.helloReceived ||
    SipHandshakeState.challengeSent ||
    SipHandshakeState.responseReceived => true,
    _ => false,
  };

  static String _resolveDisplayName(
    NodeDexEntry? entry,
    MeshNode? node,
    int nodeId,
  ) {
    return entry?.localNickname ??
        entry?.sipDisplayName ??
        node?.displayName ??
        entry?.lastKnownName ??
        NodeDisplayNameResolver.defaultName(nodeId);
  }
}

// =============================================================================
// Handshake chip — styled container badge with pulse animation for in-progress
// =============================================================================

class _HandshakeChip extends StatefulWidget {
  final SipHandshakeState state;
  final bool hasDmSession;

  const _HandshakeChip({required this.state, this.hasDmSession = false});

  @override
  State<_HandshakeChip> createState() => _HandshakeChipState();
}

class _HandshakeChipState extends State<_HandshakeChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(_HandshakeChip old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state || old.hasDmSession != widget.hasDmSession) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (!widget.hasDmSession && _isInProgress(widget.state)) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  static bool _isInProgress(SipHandshakeState state) => switch (state) {
    SipHandshakeState.helloSent ||
    SipHandshakeState.challengeReceived ||
    SipHandshakeState.responseSent ||
    SipHandshakeState.helloReceived ||
    SipHandshakeState.challengeSent ||
    SipHandshakeState.responseReceived => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // If a DM session exists, show "Connected" regardless of handshake state.
    final (label, color, icon) = widget.hasDmSession
        ? (l10n.sipHubConnected, AccentColors.green, Icons.chat_bubble_outline)
        : switch (widget.state) {
            SipHandshakeState.idle => (
              l10n.sipHandshakeAction,
              context.textTertiary,
              Icons.handshake_outlined,
            ),
            SipHandshakeState.accepted => (
              l10n.sipHubReady,
              AccentColors.green,
              Icons.check_circle_outline,
            ),
            SipHandshakeState.failed || SipHandshakeState.timedOut => (
              l10n.sipHandshakeFailed,
              AccentColors.red,
              Icons.error_outline,
            ),
            _ => (
              l10n.sipHubHandshaking,
              AccentColors.yellow,
              Icons.hourglass_top,
            ),
          };

    Widget chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing6,
        vertical: AppTheme.spacing2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: AppTheme.spacing4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );

    if (!widget.hasDmSession && _isInProgress(widget.state)) {
      chip = FadeTransition(opacity: _pulseAnimation, child: chip);
    }

    return chip;
  }
}

// =============================================================================
// Last seen chip — styled like handshake chip
// =============================================================================

class _LastSeenChip extends StatelessWidget {
  final int lastSeenMs;

  const _LastSeenChip({required this.lastSeenMs});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final diffMs = nowMs - lastSeenMs;
    final diffMinutes = diffMs ~/ 60000;

    final String timeText;
    if (diffMinutes < 1) {
      timeText = l10n.sipPeerDetailJustNow;
    } else if (diffMinutes < 60) {
      timeText = l10n.sipPeerDetailMinutesAgo(diffMinutes);
    } else {
      timeText = l10n.sipPeerDetailHoursAgo(diffMinutes ~/ 60);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing6,
        vertical: AppTheme.spacing2,
      ),
      decoration: BoxDecoration(
        color: context.textTertiary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 11, color: context.textTertiary),
          const SizedBox(width: AppTheme.spacing4),
          Text(
            timeText,
            style: TextStyle(fontSize: 11, color: context.textTertiary),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Conversation tile — card container with last message + timestamp
// =============================================================================

class _ConversationTile extends ConsumerWidget {
  final SipDmSession session;

  const _ConversationTile({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final entry = ref.watch(nodeDexEntryProvider(session.peerNodeId));
    final nodes = ref.watch(nodesProvider);
    final node = nodes[session.peerNodeId];
    final dm = ref.watch(sipDmManagerProvider);
    final patinaResult = ref.watch(nodeDexPatinaProvider(session.peerNodeId));
    final traitResult = ref.watch(nodeDexTraitProvider(session.peerNodeId));
    ref.watch(sipDmEpochProvider); // Rebuild on new messages

    final displayName = _resolveDisplayName(entry, node, session.peerNodeId);
    final history = dm?.getHistory(session.sessionTag) ?? [];
    final lastMessage = history.isNotEmpty ? history.last : null;

    return BouncyTap(
      onTap: () {
        AppLogging.sip('SIP_HUB: Opening DM session ${session.sessionTag}');
        ref.read(hapticServiceProvider).trigger(HapticType.light);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SipDmScreen(sessionTag: session.sessionTag),
          ),
        );
      },
      onLongPress: () {
        ref.read(hapticServiceProvider).trigger(HapticType.medium);
        // Long press also opens the DM
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SipDmScreen(sessionTag: session.sessionTag),
          ),
        );
      },
      scaleFactor: 0.98,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(color: context.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing14),
          child: Row(
            children: [
              // Avatar with evolution
              _buildAvatar(context, entry, patinaResult, traitResult),
              const SizedBox(width: AppTheme.spacing14),

              // Name + last message + badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name row with timestamp
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing8),
                        // Timestamp of last message
                        if (lastMessage != null)
                          Text(
                            _formatTimestamp(lastMessage.timestampMs),
                            style: TextStyle(
                              fontSize: 11,
                              color: context.textTertiary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing4),

                    // Last message preview or empty hint
                    Text(
                      lastMessage != null
                          ? lastMessage.text
                          : l10n.sipHubNoMessages,
                      style: TextStyle(
                        fontSize: 13,
                        color: lastMessage != null
                            ? context.textSecondary
                            : context.textTertiary,
                        fontStyle: lastMessage != null
                            ? FontStyle.normal
                            : FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppTheme.spacing6),

                    // Session badges row
                    Wrap(
                      spacing: AppTheme.spacing8,
                      runSpacing: AppTheme.spacing4,
                      children: [
                        _buildConnectedBadge(context, l10n),
                        _buildSessionBadge(context, l10n),
                        if (session.isPinned) _buildPinnedBadge(context, l10n),
                      ],
                    ),
                  ],
                ),
              ),

              // Green chat icon (connected indicator)
              const SizedBox(width: AppTheme.spacing4),
              Icon(
                Icons.chat_bubble_outline,
                size: 20,
                color: AccentColors.green.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(
    BuildContext context,
    NodeDexEntry? entry,
    PatinaResult patinaResult,
    TraitResult traitResult,
  ) {
    if (entry?.sigil != null) {
      return SigilAvatar(
        sigil: entry!.sigil,
        nodeNum: session.peerNodeId,
        size: 48,
        evolution: SigilEvolution.fromPatina(
          patinaResult.score,
          trait: traitResult.primary,
        ),
      );
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: context.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Icon(
        Icons.chat_bubble_outline,
        size: 22,
        color: context.accentColor.withValues(alpha: 0.7),
      ),
    );
  }

  Widget _buildSessionBadge(BuildContext context, dynamic l10n) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final expiresAtMs = session.createdAtMs + (session.ttlS * 1000);
    final remainingS = ((expiresAtMs - nowMs) / 1000).clamp(0, double.infinity);
    final timeText = remainingS > 3600
        ? '${(remainingS / 3600).floor()}h'
        : remainingS > 60
        ? '${(remainingS / 60).floor()}m'
        : '${remainingS.floor()}s';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing6,
        vertical: AppTheme.spacing2,
      ),
      decoration: BoxDecoration(
        color: context.textTertiary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 11, color: context.textTertiary),
          const SizedBox(width: AppTheme.spacing4),
          Text(
            timeText,
            style: TextStyle(fontSize: 10, color: context.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedBadge(BuildContext context, dynamic l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing6,
        vertical: AppTheme.spacing2,
      ),
      decoration: BoxDecoration(
        color: context.accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.push_pin, size: 11, color: context.accentColor),
          const SizedBox(width: AppTheme.spacing4),
          Text(
            l10n.sipHubSessionPinned,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: context.accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedBadge(BuildContext context, dynamic l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing6,
        vertical: AppTheme.spacing2,
      ),
      decoration: BoxDecoration(
        color: AccentColors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 11, color: AccentColors.green),
          const SizedBox(width: AppTheme.spacing4),
          Text(
            l10n.sipHubConnected,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AccentColors.green,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTimestamp(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inHours < 24 && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}'; // lint-allow: hardcoded-string
  }

  static String _resolveDisplayName(
    NodeDexEntry? entry,
    MeshNode? node,
    int nodeId,
  ) {
    return entry?.localNickname ??
        entry?.sipDisplayName ??
        node?.displayName ??
        entry?.lastKnownName ??
        NodeDisplayNameResolver.defaultName(nodeId);
  }
}

// =============================================================================
// Debug counters — shown in a modal bottom sheet (not inline)
// =============================================================================

class _SipCountersSheet extends ConsumerWidget {
  const _SipCountersSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final counters = ref.watch(sipCountersProvider);
    final entries = counters.toDisplayEntries();
    final nonZero = entries.where((e) => e.value > 0).toList();

    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.spacing16,
        right: AppTheme.spacing16,
        top: AppTheme.spacing16,
        bottom: MediaQuery.of(context).padding.bottom + AppTheme.spacing16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: context.accentColor),
              const SizedBox(width: AppTheme.spacing8),
              Text(
                l10n.sipCountersTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing16),

          // Counter rows
          if (nonZero.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing24),
                child: Text(
                  l10n.sipHubNoMessages,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else
            ...nonZero.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        e.label,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textSecondary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing8,
                        vertical: AppTheme.spacing2,
                      ),
                      decoration: BoxDecoration(
                        color: context.accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppTheme.radius6),
                      ),
                      child: Text(
                        '${e.value}', // lint-allow: hardcoded-string
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Shimmer placeholder — shown while scanning / waiting for peers
// =============================================================================

class _ShimmerPeerPlaceholder extends StatefulWidget {
  const _ShimmerPeerPlaceholder();

  @override
  State<_ShimmerPeerPlaceholder> createState() =>
      _ShimmerPeerPlaceholderState();
}

class _ShimmerPeerPlaceholderState extends State<_ShimmerPeerPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            border: Border.all(color: context.border),
          ),
          child: ShaderMask(
            shaderCallback: (bounds) {
              final shimmerPos = _controller.value;
              return LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.0),
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.0),
                ],
                stops: [
                  (shimmerPos - 0.3).clamp(0.0, 1.0),
                  shimmerPos,
                  (shimmerPos + 0.3).clamp(0.0, 1.0),
                ],
              ).createShader(bounds);
            },
            blendMode: BlendMode.srcATop,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing14),
              child: Row(
                children: [
                  // Avatar placeholder
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: context.textTertiary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing14),
                  // Text placeholder lines
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 140,
                          height: 14,
                          decoration: BoxDecoration(
                            color: context.textTertiary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius4,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing8),
                        Container(
                          width: 90,
                          height: 10,
                          decoration: BoxDecoration(
                            color: context.textTertiary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
