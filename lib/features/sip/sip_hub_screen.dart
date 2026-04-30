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
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/gradient_border_container.dart';
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
import '../../providers/age_eligibility_provider.dart';
import '../../providers/help_providers.dart';
import '../../providers/peer_safety_providers.dart';
import '../../providers/sip_providers.dart';
import '../../services/haptic_service.dart';
import '../../services/protocol/sip/sip_codec.dart';
import '../../services/protocol/sip/sip_types.dart';
import '../../services/protocol/sip/sip_discovery.dart';
import '../../services/protocol/sip/sip_dm.dart';
import '../../services/protocol/sip/sip_handshake.dart';
import '../../services/protocol/sip/signal/sip_signal_constants.dart';
import '../../utils/snackbar.dart';
import '../../core/widgets/animated_empty_state.dart';
import '../../core/widgets/ico_help_system.dart';
import '../mrrp_harness/mrrp_harness_home_screen.dart';
import 'sip_dm_screen.dart';
import 'sip_peer_detail_sheet.dart';
import 'widgets/peer_service_preview_row.dart';
import 'widgets/sip_hub_your_services_section.dart';

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

  // Rotates while a scan is in flight (manual or auto-scan tick).
  // Idle between ticks even when auto-scan is on — green tint signals "armed".
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
        // Screen-restore scan: NOT user-initiated (the user is just
        // navigating back into the hub with auto-scan already on).
        // force=false so the resume-suppression window — which fires
        // for ~10s after the app/screen comes to foreground —
        // actually does its job. The periodic timer will pick up
        // within 60s.
        _performScan(force: false);
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
    if (nowEnabled) {
      // Turning ON → fire an immediate user-initiated scan and arm
      // the periodic timer. Subsequent timer ticks use force=false.
      _performScan(force: true);
      _startAutoScanTimer();
      showSuccessSnackBar(context, l10n.sipAutoScanEnabled);
    } else {
      _autoScanTimer?.cancel();
      _autoScanTimer = null;
      showInfoSnackBar(context, l10n.sipAutoScanDisabled);
    }
  }

  void _startAutoScanTimer() {
    _autoScanTimer?.cancel();
    _autoScanTimer = Timer.periodic(_kAutoScanInterval, (_) {
      // Periodic background ticks must NOT use `force: true`. That
      // flag is for explicit user taps and bypasses the resume-
      // suppression window + the cooldown jitter — both of which
      // exist precisely to keep automatic emissions airtime-clean.
      // Letting the periodic tick honour the soft gates means it
      // skips ticks during congestion / the 10s post-resume window
      // and picks up the 0–5s anti-thundering-herd jitter so a
      // populated mesh of auto-scanning devices doesn't fire all
      // their ROLLCALL_REQs on the same instant.
      if (mounted) _performScan(force: false);
    });
  }

  void _onScan() {
    ref.read(hapticServiceProvider).trigger(HapticType.light);
    // User-initiated taps are explicit intent — bypass the cooldown
    // / resume-suppression so the request goes out promptly. The
    // hard byte budget still gates this.
    _performScan(force: true);
  }

  void _performScan({required bool force}) {
    final discovery = ref.read(sipDiscoveryProvider);
    AppLogging.sip(
      'SIP_HUB: scan triggered, discovery=${discovery != null} force=$force',
    );
    if (discovery == null) return;

    final outbound = discovery.buildRollcallReq(force: force);
    if (outbound == null) return;

    final protocol = ref.read(protocolServiceProvider);
    protocol.sendSipPacket(outbound.encoded);
    AppLogging.sip(
      'SIP_HUB: ROLLCALL_REQ dispatched ${outbound.encoded.length}B',
    );
    setState(() => _scanning = true);
    _radarController.repeat();
    // Record epoch at scan start; stop scanning when it bumps (peers arrive).
    _scanStartEpoch = ref.read(sipPeerCacheEpochProvider);
    // Poll the discovery engine's scan window state instead of using a fixed
    // timeout. The engine tracks the real expiry; we add a grace period after
    // the window closes for the last response to propagate back over the mesh.
    _scanTimeoutTimer?.cancel();
    _scanTimeoutTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final d = ref.read(sipDiscoveryProvider);
      if (d == null || !d.isInScanWindow) {
        _scanTimeoutTimer?.cancel();
        // Grace period: responses sent just before the window closed are
        // still in flight. Wait for mesh propagation before giving up.
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && _scanning) _stopScan();
        });
      }
    });
  }

  void _stopScan() {
    if (!_scanning) return;
    setState(() => _scanning = false);
    _radarController.stop();
    _radarController.reset();
  }

  /// Called from build — checks if peers arrived since scan started.
  void _checkScanComplete(int currentEpoch) {
    if (_scanning && currentEpoch > _scanStartEpoch) {
      // Peers have arrived — cancel the scan window poll and stop scanning
      // after a brief delay for perceived smoothness.
      _scanTimeoutTimer?.cancel();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _stopScan();
      });
    }
  }

  /// Initiate handshake directly with a peer (no detail sheet).
  void _initiateHandshake(SipPeerCapability peer) {
    final localContext = context;
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
      // No snackbar — the per-peer chip is the single source of truth for
      // handshake state. A redundant "Could not connect" overlay on top of
      // the same red chip just adds noise.
      return;
    }

    // Already handshaking — let the chip show progress, don't interrupt.
    //
    // pendingApproval is NOT a tile-tap shortcut: the dedicated
    // `_IncomingRequestTile` above the peer list owns Accept / Decline
    // as explicit, deliberate buttons. Tapping the peer tile must not
    // stand in for consent — the mandatory ACCEPT / REJECT rule
    // requires a direct user action on the consent UI.
    final currentState = handshake.getState(peer.nodeId);
    if (currentState == SipHandshakeState.pendingApproval) {
      return;
    }
    // Accepted but no DM session yet — open the peer detail sheet so
    // the user can review capabilities / advertised services and start
    // a conversation on their own terms.
    if (currentState == SipHandshakeState.accepted) {
      SipPeerDetailSheet.show(localContext, peer);
      return;
    }
    if (currentState != SipHandshakeState.idle &&
        currentState != SipHandshakeState.declined &&
        currentState != SipHandshakeState.failed &&
        currentState != SipHandshakeState.timedOut) {
      // In-progress states — don't interrupt. Show detail sheet so the
      // user can see what's happening and the status chip in context.
      SipPeerDetailSheet.show(localContext, peer);
      return;
    }

    // Explicit user retry from a terminal state — override the
    // 120s post-failure cooldown so the tap actually does something.
    // The cooldown exists to throttle automatic retransmits, not to
    // lock the user out for two minutes when they deliberately tap
    // a "Could not connect" tile.
    final isUserRetry =
        currentState == SipHandshakeState.failed ||
        currentState == SipHandshakeState.timedOut ||
        currentState == SipHandshakeState.declined;

    final frame = handshake.initiateHandshake(
      peer.nodeId,
      overrideCooldown: isUserRetry,
    );
    if (frame == null) {
      // Defence-in-depth: even with the override the manager can still
      // refuse (DM not available, lingering session entry). The chip
      // remains in its current state — a snackbar layered on top would
      // duplicate that signal and was reported as "extremely annoying"
      // during the simultaneous-open retry flow.
      return;
    }

    final encoded = SipCodec.encode(frame);
    if (encoded == null) {
      return;
    }

    final protocol = ref.read(protocolServiceProvider);
    protocol.sendSipGated(encoded, SipMessageType.hsHello);
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
    final pendingRequestNodeIds = ref.watch(sipPendingHandshakeProvider);

    // Stop scanning indicator when peers arrive (epoch bumps).
    if (_scanning) _checkScanComplete(peerEpoch);

    // Deduplicate identical log lines across rebuilds.
    final sig =
        '$sipEnabled|$peerCount|${sessions.length}|${pendingRequestNodeIds.length}'; // lint-allow: hardcoded-string
    if (sig != _lastLogSignature) {
      _lastLogSignature = sig;
      AppLogging.sip(
        'SIP_HUB: build — enabled=$sipEnabled, peers=$peerCount, '
        'sessions=${sessions.length}, '
        'pendingRequests=${pendingRequestNodeIds.length}', // lint-allow: hardcoded-string
      );
      if (pendingRequestNodeIds.isNotEmpty) {
        AppLogging.sip(
          'SIP_HUB: pending request nodeIds='
          '${pendingRequestNodeIds.map((id) => '0x${id.toRadixString(16)}').join(', ')}', // lint-allow: hardcoded-string
        );
      }
    }

    // Filter out peers that already have an active DM session —
    // those appear under Conversations only (issue 3).
    final sessionNodeIds = sessions.map((s) => s.peerNodeId).toSet();

    // Trust + Safety render-layer filter: blocked peers are hidden
    // from every active list (Incoming requests, Conversations,
    // Discovered peers). They surface only inside the collapsed
    // Blocked section, which exposes an explicit Unblock affordance.
    //
    // This is a pure render filter — no protocol or session state
    // is mutated here. The protocol layer already silently drops
    // future inbound HELLO / DM / MRRP frames from blocked peers
    // (Phase 6/7), so blocked entries shouldn't normally appear in
    // these lists at steady state. The filter is defense-in-depth
    // for in-flight frames + sessions opened before the block.
    final blockedNodeIds = ref.watch(blockedPeerNodeIdsProvider);
    final blockedSet = blockedNodeIds.toSet();
    final filteredPendingRequests = pendingRequestNodeIds
        .where((id) => !blockedSet.contains(id))
        .toList(growable: false);
    final filteredSessions = sessions
        .where((s) => !blockedSet.contains(s.peerNodeId))
        .toList(growable: false);
    final unconnectedPeers = peers
        .where(
          (p) =>
              !sessionNodeIds.contains(p.nodeId) &&
              !blockedSet.contains(p.nodeId),
        )
        .toList();

    final hasPeers = unconnectedPeers.isNotEmpty;
    final hasSessions = filteredSessions.isNotEmpty;
    final hasPendingRequests = filteredPendingRequests.isNotEmpty;
    final hasBlocked = blockedNodeIds.isNotEmpty;
    final isEmpty =
        !hasPeers &&
        !hasSessions &&
        !_scanning &&
        !hasPendingRequests &&
        !hasBlocked;

    // lint-allow: haptic-feedback — keyboard dismissal, not interactive action
    return HelpTourController(
      topicId: 'sip_hub_overview',
      stepKeys: const {},
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: GlassScaffold(
          title: l10n.sipHubTitle,
          actions: [
            // Radar — single primary action: tap toggles auto-discovery.
            // Always visible. Color tracks auto-scan state; rotation tracks
            // an in-flight scan (manual or auto-scan tick).
            IconButton(
              icon: AnimatedBuilder(
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
              tooltip: l10n.sipAutoScanToggle,
              onPressed: _toggleAutoScan,
            ),
            // Overflow menu
            AppBarOverflowMenu<String>(
              onSelected: (value) {
                if (value == 'scannow') {
                  _onScan(); // lint-allow: hardcoded-string
                }
                if (value == 'autoscan') {
                  _toggleAutoScan(); // lint-allow: hardcoded-string
                }
                if (value == 'counters') {
                  _showCounters(); // lint-allow: hardcoded-string
                }
                if (value == 'harness') {
                  _openHarness(); // lint-allow: hardcoded-string
                }
                if (value == 'help') {
                  ref
                      .read(helpProvider.notifier)
                      .startTour(
                        'sip_hub_overview',
                      ); // lint-allow: hardcoded-string
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'scannow', // lint-allow: hardcoded-string
                  enabled: !_scanning,
                  child: ListTile(
                    leading: const Icon(Icons.radar),
                    title: Text(l10n.sipScanNow),
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
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
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'help', // lint-allow: hardcoded-string
                  child: Row(
                    children: [
                      Icon(
                        Icons.help_outline,
                        size: 18,
                        color: context.textSecondary,
                      ),
                      SizedBox(width: AppTheme.spacing8),
                      Text(l10n.sipHubHelp),
                    ],
                  ),
                ),
              ],
            ),
          ],
          slivers: isEmpty
              ? _buildEmptySlivers(context)
              : _buildContentSlivers(
                  context,
                  unconnectedPeers,
                  filteredSessions,
                  filteredPendingRequests,
                  blockedNodeIds,
                ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty state — icon + headline + description + scan button
  // ---------------------------------------------------------------------------

  List<Widget> _buildEmptySlivers(BuildContext context) {
    final l10n = context.l10n;
    final taglines = [
      l10n.sipHubScanningTagline1,
      l10n.sipHubScanningTagline2,
      l10n.sipHubScanningTagline3,
      l10n.sipHubScanningTagline4,
    ];

    return [
      SliverFillRemaining(
        hasScrollBody: false,
        child: AnimatedEmptyState(
          config: AnimatedEmptyStateConfig(
            icons: const [
              Icons.sensors,
              Icons.wifi_find,
              Icons.radar,
              Icons.people_outline,
              Icons.explore_outlined,
              Icons.person_search,
              Icons.network_check,
              Icons.cell_tower,
            ],
            taglines: taglines,
            titlePrefix: l10n.sipHubScanningTitlePrefix,
            titleKeyword: l10n.sipHubScanningTitleKeyword,
            titleSuffix: l10n.sipHubScanningTitleSuffix,
            actionLabel: l10n.sipDiscoveryScanButton,
            actionIcon: Icons.sensors,
            onAction: _scanning ? null : _onScan,
            actionEnabled: !_scanning,
            actionDisabledReason: _scanning ? l10n.sipScanningIndicator : null,
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
    List<int> pendingRequestNodeIds,
    List<int> blockedPeerNodeIds,
  ) {
    final shouldRestrict = ref
        .read(ageSafetyPolicyProvider)
        .shouldRestrictUnsolicitedContact;
    return [
      const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacing8)),

      // Incoming handshake requests — shown first, require user action.
      // Hidden when user is a confirmed minor (contact restriction).
      if (pendingRequestNodeIds.isNotEmpty && !shouldRestrict) ...[
        SliverPersistentHeader(
          pinned: true,
          delegate: SectionHeaderDelegate(
            title: context.l10n.sipHubSectionIncomingRequests,
            count: pendingRequestNodeIds.length,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _IncomingRequestTile(
                peerNodeId: pendingRequestNodeIds[index],
              ),
              childCount: pendingRequestNodeIds.length,
            ),
          ),
        ),
      ],

      // Your Services — local service instances + Create CTA. Always
      // rendered so the Create affordance is discoverable even when the
      // user has no services yet.
      ...buildYourServicesSlivers(context, ref),

      // Active conversations (shown after pending requests)
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
                ? SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: context.textTertiary,
                    ),
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

      // Blocked section — collapsed by default, last in the list.
      // Render-layer only: tapping rows here only exposes Unblock,
      // never re-opens a session or sends a wire frame.
      if (blockedPeerNodeIds.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            AppTheme.spacing12,
            AppTheme.spacing16,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: _BlockedPeersSection(blockedPeerNodeIds: blockedPeerNodeIds),
          ),
        ),

      // Bottom safe area
      SliverToBoxAdapter(
        child: SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
      ),
    ];
  }
}

// =============================================================================
// Incoming Request Tile — Accept / Decline card for pending handshake requests
// =============================================================================

class _IncomingRequestTile extends ConsumerWidget {
  final int peerNodeId;

  const _IncomingRequestTile({required this.peerNodeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final accent = context.accentColor;
    final entry = ref.watch(nodeDexEntryProvider(peerNodeId));
    final nodes = ref.watch(nodesProvider);
    final node = nodes[peerNodeId];
    final patinaResult = ref.watch(nodeDexPatinaProvider(peerNodeId));
    final traitResult = ref.watch(nodeDexTraitProvider(peerNodeId));
    final displayName =
        entry?.localNickname ??
        entry?.sipDisplayName ??
        node?.displayName ??
        entry?.lastKnownName ??
        NodeDisplayNameResolver.defaultName(peerNodeId);
    final hexId =
        '!${peerNodeId.toRadixString(16).toUpperCase().padLeft(4, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
      child: GradientBorderContainer(
        borderRadius: AppTheme.radius12,
        borderWidth: 2,
        accentOpacity: 0.3,
        backgroundColor: context.card,
        padding: const EdgeInsets.all(AppTheme.spacing14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live header strip — pulsing dot + uppercase label
            Row(
              children: [
                _LivePulseDot(color: accent),
                const SizedBox(width: AppTheme.spacing8),
                Text(
                  l10n.sipHubIncomingRequestLiveLabel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accent,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing12),

            // Identity row — sigil avatar + name/hex/subtitle stack
            Row(
              children: [
                _buildAvatar(context, entry, patinaResult, traitResult),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      const SizedBox(height: AppTheme.spacing4),
                      Text(
                        l10n.sipHubIncomingRequestWantsToConnect,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing12),

            // Consent body — explains what tapping Accept enables. The
            // user must understand this is a privacy-bearing decision,
            // not a "friend request."
            Text(
              l10n.sipHubConsentBody,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: context.textTertiary,
              ),
            ),

            const SizedBox(height: AppTheme.spacing12),

            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      AppLogging.sip(
                        'SIP_HUB: Accept tapped for '
                        'peer=0x${peerNodeId.toRadixString(16)}',
                      );
                      ref
                          .read(hapticServiceProvider)
                          .trigger(HapticType.medium);
                      ref
                          .read(protocolServiceProvider)
                          .acceptSipHandshake(peerNodeId);
                      // T+S: mark first-contact ONLY when the local
                      // user explicitly taps Accept. NOT on inbound
                      // HELLO / DECLINE / ACCEPT alone — those don't
                      // carry consent. The mark gates the
                      // first-contact warning banner so it doesn't
                      // re-pop on subsequent re-handshakes.
                      ref
                          .read(peerSafetyManagerProvider.notifier)
                          .markFirstHandshake(
                            peerNodeId,
                            DateTime.now().millisecondsSinceEpoch,
                          );
                    },
                    icon: const Icon(Icons.check, size: 16),
                    label: Text(l10n.sipHubAccept),
                    style: FilledButton.styleFrom(
                      backgroundColor: AccentColors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(36),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing6),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ref.read(hapticServiceProvider).trigger(HapticType.light);
                      ref
                          .read(protocolServiceProvider)
                          .declineSipHandshake(peerNodeId);
                    },
                    icon: const Icon(Icons.close, size: 16),
                    label: Text(l10n.sipHubDecline),
                    // Decline = mild "not this time" (handshake state
                    // resets, peer can retry later). Orange to read
                    // as "caution" rather than "danger" so it doesn't
                    // collide visually with Block. The three buttons
                    // form a green → orange → red severity ladder.
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AccentColors.orange,
                      side: BorderSide(
                        color: AccentColors.orange.withValues(alpha: 0.6),
                      ),
                      minimumSize: const Size.fromHeight(36),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing6),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _onBlock(context, ref),
                    icon: const Icon(Icons.block, size: 16),
                    label: Text(l10n.sipHubBlock),
                    // Block = hard "never again" (T+S locks outbound,
                    // suppresses future inbound consent). Keeps red
                    // as the strongest severity signal in the trio.
                    // Was previously SemanticColors.error which is
                    // the same hex as AccentColors.red — same colour
                    // as Decline, indistinguishable.
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AccentColors.red,
                      side: BorderSide(
                        color: AccentColors.red.withValues(alpha: 0.6),
                      ),
                      minimumSize: const Size.fromHeight(36),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
    // Always render a sigil — `SigilAvatar` falls back to
    // `SigilGenerator.generate(nodeNum)` when `sigil` is null, so a
    // peer with no stored NodeDex entry yet (brand-new install, just-
    // discovered peer) still gets the constellation pattern. Matches
    // every other call site in the codebase.
    return SigilAvatar(
      sigil: entry?.sigil,
      nodeNum: peerNodeId,
      size: 48,
      evolution: SigilEvolution.fromPatina(
        patinaResult.score,
        trait: traitResult.primary,
      ),
    );
  }

  Future<void> _onBlock(BuildContext context, WidgetRef ref) async {
    // Capture every ref-derived reference before the first await.
    // This avoids any "ref used after await without mounted check"
    // class of bug — ref is a long-lived ConsumerWidget handle, but
    // the lint rule is mechanical and flags any post-await read.
    ref.read(hapticServiceProvider).trigger(HapticType.heavy);
    final manager = ref.read(peerSafetyManagerProvider.notifier);
    final protocol = ref.read(protocolServiceProvider);
    final l10n = context.l10n;
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: l10n.sipHubBlockConfirmTitle,
      message: l10n.sipHubBlockConfirmBody,
      confirmLabel: l10n.sipHubBlockConfirmAction,
      cancelLabel: l10n.sipHubBlockConfirmCancel,
      isDestructive: true,
    );
    if (confirmed != true) return;

    AppLogging.sip(
      'SIP_HUB: Block confirmed for '
      'peer=0x${peerNodeId.toRadixString(16)} — silent drop, '
      'no HS_DECLINE',
    );
    // Persist the block first so any in-flight or retransmitted
    // HELLO from this peer hits the protocol-layer safety gate
    // and is silently dropped before reaching consent UI again.
    await manager.block(peerNodeId, reasonCode: 'consent_block');
    // Silently clear the pending consent prompt without sending
    // HS_DECLINE — the peer must see no wire-level confirmation
    // that we exist or saw the request.
    protocol.cancelSipHandshake(peerNodeId);
  }
}

/// Pulsing dot indicator used on the incoming-request card to convey that
/// the request is live and time-sensitive (matches the Signals banner).
class _LivePulseDot extends StatefulWidget {
  final Color color;

  const _LivePulseDot({required this.color});

  @override
  State<_LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends State<_LivePulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _animation.value * 0.6),
                blurRadius: 8 * _animation.value,
                spreadRadius: 2 * _animation.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// Peer tile — card container + BouncyTap with shake animation on decline
// =============================================================================

class _PeerTile extends ConsumerStatefulWidget {
  final SipPeerCapability peer;
  final VoidCallback onHandshake;

  const _PeerTile({required this.peer, required this.onHandshake});

  @override
  ConsumerState<_PeerTile> createState() => _PeerTileState();
}

class _PeerTileState extends ConsumerState<_PeerTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;
  SipHandshakeState? _prevHsState;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    // Shake: rapid horizontal oscillation that decays.
    _shakeAnimation = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 0, end: 8), weight: 1),
        TweenSequenceItem(tween: Tween(begin: 8, end: -8), weight: 2),
        TweenSequenceItem(tween: Tween(begin: -8, end: 6), weight: 2),
        TweenSequenceItem(tween: Tween(begin: 6, end: -4), weight: 2),
        TweenSequenceItem(tween: Tween(begin: -4, end: 2), weight: 2),
        TweenSequenceItem(tween: Tween(begin: 2, end: 0), weight: 1),
      ],
    ).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  /// Trigger shake when state transitions to declined/failed/timedOut.
  void _onHandshakeStateChanged(SipHandshakeState newState) {
    if (_prevHsState != null &&
        _prevHsState != newState &&
        _isNegative(newState)) {
      _shakeController.forward(from: 0);
      ref.read(hapticServiceProvider).trigger(HapticType.heavy);
    }
    _prevHsState = newState;
  }

  static bool _isNegative(SipHandshakeState s) =>
      s == SipHandshakeState.declined ||
      s == SipHandshakeState.failed ||
      s == SipHandshakeState.timedOut;

  static bool _isHandshaking(SipHandshakeState state) => switch (state) {
    SipHandshakeState.helloSent ||
    SipHandshakeState.challengeReceived ||
    SipHandshakeState.responseSent ||
    SipHandshakeState.challengeSent ||
    SipHandshakeState.responseReceived => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final entry = ref.watch(nodeDexEntryProvider(widget.peer.nodeId));
    final nodes = ref.watch(nodesProvider);
    final node = nodes[widget.peer.nodeId];
    final hsState = ref.watch(sipHandshakeStateProvider(widget.peer.nodeId));
    final patinaResult = ref.watch(nodeDexPatinaProvider(widget.peer.nodeId));
    final traitResult = ref.watch(nodeDexTraitProvider(widget.peer.nodeId));
    final cooldownSeconds = ref.watch(
      sipHandshakeCooldownSecondsProvider(widget.peer.nodeId),
    );

    // Detect transitions to negative states.
    _onHandshakeStateChanged(hsState);

    // Check if a DM session already exists for this peer.
    ref.watch(sipDmEpochProvider); // rebuild when DM sessions change
    final dm = ref.watch(sipDmManagerProvider);
    final hasDmSession =
        dm?.activeSessions.any((s) => s.peerNodeId == widget.peer.nodeId) ??
        false;

    final displayName = _resolveDisplayName(entry, node, widget.peer.nodeId);
    final hexId =
        '!${widget.peer.nodeId.toRadixString(16).toUpperCase().padLeft(4, '0')}';

    // Block taps while handshake is in-progress (not pendingApproval —
    // that requires user action so the card stays tappable) AND while
    // the per-peer fail cooldown is active. Tapping during cooldown
    // would silently no-op at the manager (`SIP_HS: ... blocked by
    // cooldown`), so we surface the gate at the UI layer instead.
    final isBusy = _isHandshaking(hsState);
    final isCoolingDown = cooldownSeconds > 0 && !hasDmSession;
    final isDeclined = _isNegative(hsState);

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) => Transform.translate(
        offset: Offset(_shakeAnimation.value, 0),
        child: child,
      ),
      child: BouncyTap(
        onTap: (isBusy || isCoolingDown) ? null : widget.onHandshake,
        onLongPress: (isBusy || isCoolingDown) ? null : widget.onHandshake,
        enabled: !isBusy && !isCoolingDown,
        scaleFactor: 0.98,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            border: Border.all(
              color: isDeclined
                  ? AccentColors.red.withValues(alpha: 0.6)
                  : context.border,
            ),
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

                      // Status row: handshake state + last seen.
                      // Wrap so long labels (e.g. "Could not connect")
                      // can flow to a second line on narrow screens
                      // instead of overflowing the row.
                      Wrap(
                        spacing: AppTheme.spacing8,
                        runSpacing: AppTheme.spacing4,
                        children: [
                          _HandshakeChip(
                            state: hsState,
                            hasDmSession: hasDmSession,
                            cooldownSeconds: cooldownSeconds,
                          ),
                          _LastSeenChip(lastSeenMs: widget.peer.lastSeenMs),
                        ],
                      ),
                      // Advertised services preview — empty-collapses
                      // when the peer has no public MRRP adverts yet.
                      PeerServicePreviewRow(peerNodeId: widget.peer.nodeId),
                    ],
                  ),
                ),

                // Chevron — chat icon when DM session exists
                const SizedBox(width: AppTheme.spacing4),
                Icon(
                  hasDmSession
                      ? Icons.chat_bubble_outline
                      : Icons.chevron_right,
                  size: 20,
                  color: hasDmSession
                      ? AccentColors.green.withValues(alpha: 0.7)
                      : context.textTertiary.withValues(alpha: 0.5),
                ),
              ],
            ),
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
    // Always render a sigil — `SigilAvatar` falls back to
    // `SigilGenerator.generate(nodeNum)` when `sigil` is null, so a
    // peer with no stored NodeDex entry yet (brand-new install, just-
    // discovered peer) still gets the constellation pattern. Matches
    // every other call site in the codebase.
    return SigilAvatar(
      sigil: entry?.sigil,
      nodeNum: widget.peer.nodeId,
      size: 48,
      evolution: SigilEvolution.fromPatina(
        patinaResult.score,
        trait: traitResult.primary,
      ),
    );
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
// Handshake chip — styled container badge with pulse animation for in-progress
// =============================================================================

class _HandshakeChip extends StatefulWidget {
  final SipHandshakeState state;
  final bool hasDmSession;

  /// Live per-peer fail-cooldown countdown in seconds, or 0 when no
  /// cooldown is active. When > 0 (and the peer has no DM session
  /// yet), the chip switches to a disabled cooldown variant — the
  /// `_PeerTile` also gates taps to match.
  final int cooldownSeconds;

  const _HandshakeChip({
    required this.state,
    this.hasDmSession = false,
    this.cooldownSeconds = 0,
  });

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
    if (old.state != widget.state ||
        old.hasDmSession != widget.hasDmSession ||
        old.cooldownSeconds != widget.cooldownSeconds) {
      _syncAnimation();
    }
  }

  bool get _isCoolingDown => !widget.hasDmSession && widget.cooldownSeconds > 0;

  void _syncAnimation() {
    // Cooldown chip is intentionally static — the gate is by design,
    // not an in-flight error. Pulse only for in-progress / negative
    // states without a DM session.
    if (!widget.hasDmSession &&
        !_isCoolingDown &&
        (_isInProgress(widget.state) || _isNegative(widget.state))) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.value = 1.0;
    }
  }

  static bool _isNegative(SipHandshakeState s) =>
      s == SipHandshakeState.declined ||
      s == SipHandshakeState.failed ||
      s == SipHandshakeState.timedOut;

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  static bool _isInProgress(SipHandshakeState state) => switch (state) {
    SipHandshakeState.helloSent ||
    SipHandshakeState.challengeReceived ||
    SipHandshakeState.responseSent ||
    SipHandshakeState.challengeSent ||
    SipHandshakeState.responseReceived => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    AppLogging.sip(
      'SIP_HUB_CHIP: state=${widget.state.name}, '
      'hasDm=${widget.hasDmSession}, '
      'inProgress=${_isInProgress(widget.state)}, '
      'cooldown=${widget.cooldownSeconds}s', // lint-allow: hardcoded-string
    );

    // If a DM session exists, show "Connected" regardless of handshake state.
    // Cooldown takes precedence over the failed/declined chip when there's
    // no DM session yet — the user wants to see how long until retry, not
    // a stale "Could not connect" badge that they can't act on.
    final (label, color, icon) = widget.hasDmSession
        ? (l10n.sipHubConnected, AccentColors.green, Icons.chat_bubble_outline)
        : _isCoolingDown
        ? (
            l10n.sipHandshakeCooldown(_formatCooldown(widget.cooldownSeconds)),
            context.textTertiary,
            Icons.timer_outlined,
          )
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
            SipHandshakeState.pendingApproval => (
              l10n.sipHandshakePendingLabel,
              AccentColors.orange,
              Icons.schedule_outlined,
            ),
            SipHandshakeState.declined => (
              l10n.sipHandshakeFailed,
              AccentColors.red,
              Icons.cancel_outlined,
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

    if (!widget.hasDmSession &&
        !_isCoolingDown &&
        (_isInProgress(widget.state) || _isNegative(widget.state))) {
      chip = FadeTransition(opacity: _pulseAnimation, child: chip);
    }

    return chip;
  }

  /// Compact "1m 50s" / "50s" formatter for the cooldown chip. Kept
  /// here rather than in a global util because the SIP fail cooldown
  /// is the only place this exact format is needed (the traceroute
  /// cooldown chip uses bare seconds — a 30 s window doesn't need the
  /// minute split). Output is plain digits + 'm'/'s' so it's
  /// understood without translation; surrounding ARB copy is the
  /// translatable surface.
  static String _formatCooldown(int seconds) {
    if (seconds <= 0) return '0s';
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (s == 0) return '${m}m';
    return '${m}m ${s}s';
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
          padding: const EdgeInsets.all(AppTheme.spacing12),
          child: Row(
            // Avatar top-aligned with the first text row, matching
            // Nodes screen + NodeDex card convention. Default Row
            // alignment is `center`, which floats the sigil halfway
            // down the card and made the layout feel airy.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with evolution
              _buildAvatar(context, entry, patinaResult, traitResult),
              const SizedBox(width: AppTheme.spacing12),

              // Name + last message + badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
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
                    // Last message preview — only when there IS a
                    // message. The italic "No messages yet" line was
                    // adding a near-invisible row of vertical space
                    // that made empty conversations look bloated;
                    // dropping it tightens the card without losing
                    // information (the Connected badge below already
                    // signals the conversation exists).
                    if (lastMessage != null) ...[
                      const SizedBox(height: AppTheme.spacing4),
                      Text(
                        _previewForLastMessage(context, lastMessage),
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppTheme.spacing6),

                    // Session badges row
                    Wrap(
                      spacing: AppTheme.spacing8,
                      runSpacing: AppTheme.spacing4,
                      children: [
                        _buildConnectedBadge(context, l10n),
                        _buildSessionBadge(context, l10n),
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
    // Always render a sigil — `SigilAvatar` falls back to
    // `SigilGenerator.generate(nodeNum)` when `sigil` is null, so a
    // peer with no stored NodeDex entry yet (brand-new install, just-
    // discovered peer) still gets the constellation pattern. Matches
    // every other call site in the codebase.
    return SigilAvatar(
      sigil: entry?.sigil,
      nodeNum: session.peerNodeId,
      size: 48,
      evolution: SigilEvolution.fromPatina(
        patinaResult.score,
        trait: traitResult.primary,
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

  // Conversation card preview line. Text entries render their body
  // verbatim; non-text entries (sketches, signal envelopes, play
  // envelopes) carry no plaintext, so the bare `entry.text` was
  // empty and produced a hollow row beneath the peer name. Substitute
  // a localised emoji label per content type. For signal we peek the
  // envelope's `signalKind` byte directly (offset 1) rather than
  // running the full codec — the preview only needs a coarse label
  // and we want to stay safe on truncated/malformed payloads.
  static String _previewForLastMessage(
    BuildContext context,
    SipDmHistoryEntry entry,
  ) {
    final l10n = context.l10n;
    switch (entry.contentType) {
      case SipDmContentType.text:
        return entry.text;
      case SipDmContentType.ink:
        return l10n.sipDmInkReplyPlaceholder;
      case SipDmContentType.signal:
        final payload = entry.payload;
        if (payload != null && payload.length > 1) {
          final kind = SipSignalKind.fromCode(payload[1]);
          if (kind == SipSignalKind.phrase) {
            return l10n.sipDmConversationPreviewPhrase;
          }
          if (kind == SipSignalKind.morse) {
            return l10n.sipDmConversationPreviewMorse;
          }
        }
        return l10n.sipDmSignalReplyPlaceholder;
      case SipDmContentType.play:
        return l10n.sipDmConversationPreviewGame;
    }
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

// =============================================================================
// Blocked peers section — collapsed by default, exposes Unblock only.
//
// Hard rules (Phase 10):
//   - Render-layer only: building this section MUST NOT mutate any
//     protocol or session state. The tiles read from
//     blockedPeerNodeIdsProvider + nodeDexEntryProvider, nothing else.
//   - Unblock is gated by an AppBottomSheet.showConfirm sheet so the
//     user has a chance to review the consequence before the safety
//     gate re-opens.
//   - The section auto-hides when blockedPeerNodeIds is empty, so a
//     freshly-installed app or a cleared block list never shows the
//     header.
// =============================================================================

class _BlockedPeersSection extends ConsumerWidget {
  final List<int> blockedPeerNodeIds;

  const _BlockedPeersSection({required this.blockedPeerNodeIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
        ),
        child: ExpansionTile(
          // initiallyExpanded false per spec — section is collapsed
          // by default to avoid drawing attention to blocked peers
          // every time the user opens SIP Hub.
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing4,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppTheme.spacing12,
            0,
            AppTheme.spacing12,
            AppTheme.spacing12,
          ),
          iconColor: context.textSecondary,
          collapsedIconColor: context.textSecondary,
          leading: Icon(
            Icons.block,
            color: SemanticColors.error.withValues(alpha: 0.7),
            size: 20,
          ),
          title: Row(
            children: [
              Text(
                l10n.sipHubSectionBlocked,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(width: AppTheme.spacing6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing6,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: context.background,
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                child: Text(
                  '${blockedPeerNodeIds.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.textTertiary,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: AppTheme.spacing2),
            child: Text(
              l10n.sipHubBlockedEmptySubtitle,
              style: TextStyle(fontSize: 12, color: context.textTertiary),
            ),
          ),
          children: [
            for (final nodeId in blockedPeerNodeIds)
              _BlockedPeerTile(peerNodeId: nodeId),
          ],
        ),
      ),
    );
  }
}

class _BlockedPeerTile extends ConsumerWidget {
  final int peerNodeId;

  const _BlockedPeerTile({required this.peerNodeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final entry = ref.watch(nodeDexEntryProvider(peerNodeId));
    final nodes = ref.watch(nodesProvider);
    final node = nodes[peerNodeId];
    final displayName =
        entry?.localNickname ??
        entry?.sipDisplayName ??
        node?.displayName ??
        entry?.lastKnownName ??
        NodeDisplayNameResolver.defaultName(peerNodeId);
    final hexId =
        '!${peerNodeId.toRadixString(16).toUpperCase().padLeft(4, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: SemanticColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radius8),
            ),
            child: Icon(
              Icons.block,
              color: SemanticColors.error.withValues(alpha: 0.7),
              size: 18,
            ),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
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
                        fontSize: 10,
                        color: context.textTertiary,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing2),
                Text(
                  l10n.sipHubBlockedPeerSubtitle,
                  style: TextStyle(fontSize: 11, color: context.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          OutlinedButton(
            onPressed: () => _onUnblock(context, ref),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing12,
              ),
              foregroundColor: AccentColors.green,
              side: BorderSide(
                color: AccentColors.green.withValues(alpha: 0.6),
              ),
            ),
            child: Text(
              l10n.sipHubUnblockAction,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onUnblock(BuildContext context, WidgetRef ref) async {
    // Capture every ref-derived reference before the first await —
    // satisfies the async-safety lint and keeps the unblock path
    // robust against widget unmount mid-confirm.
    ref.read(hapticServiceProvider).trigger(HapticType.medium);
    final manager = ref.read(peerSafetyManagerProvider.notifier);
    final l10n = context.l10n;
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: l10n.sipHubUnblockConfirmTitle,
      message: l10n.sipHubUnblockConfirmBody,
      confirmLabel: l10n.sipHubUnblockConfirmAction,
      cancelLabel: l10n.sipHubUnblockConfirmCancel,
      // Unblocking is non-destructive — it re-opens the safety gate
      // and restores the peer's ability to reach the user. The
      // confirm sheet exists for review, not warning.
      isDestructive: false,
    );
    if (confirmed != true) return;
    AppLogging.sip(
      'SIP_HUB: Unblock confirmed for '
      'peer=0x${peerNodeId.toRadixString(16)}',
    );
    await manager.unblock(peerNodeId);
  }
}
