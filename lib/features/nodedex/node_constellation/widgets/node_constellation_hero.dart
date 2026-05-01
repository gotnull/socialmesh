// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Hero centre identity tile inside the NodeDex Constellation bento.
//
// References:
//   * Trending-events / NFT-profile cards: tall card with vivid
//     visual subject, gradient veil at the bottom for legibility,
//     a big headline, and a corner "peek" of related items (here:
//     co-seen peers' sigils) angled out of the top-right corner.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme.dart';
import '../../widgets/sigil_painter.dart';
import '../node_constellation_models.dart';

class NodeConstellationHero extends StatelessWidget {
  final NodeDexGraphNode node;
  final int centerNodeNum;
  final Color accent;
  final String hexId;
  final String? lastSeen;
  final String? socialTag;
  final bool viaMqtt;

  /// Up to ~3 co-seen peer node numbers, shown as a fanned stack
  /// peeking out of the top-right corner. Empty list hides the peek.
  final List<int> peerNodeNums;

  /// Total co-seen count (used for the "+N" indicator at the corner).
  final int peerTotal;

  final VoidCallback? onPeerTap;
  final void Function(NodeDexGraphNode node)? onTap;

  const NodeConstellationHero({
    super.key,
    required this.node,
    required this.centerNodeNum,
    required this.accent,
    required this.hexId,
    this.lastSeen,
    this.socialTag,
    this.viaMqtt = false,
    this.peerNodeNums = const [],
    this.peerTotal = 0,
    this.onPeerTap,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hero = ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radius20),
      child: Container(
        height: 300,
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius20),
          border: Border.all(color: accent.withValues(alpha: 0.4)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Centre sigil rendered as the card's "photo" subject.
            Positioned(
              top: -50,
              left: -30,
              child: Opacity(
                opacity: 0.9,
                child: SigilDisplay(nodeNum: centerNodeNum, size: 360),
              ),
            ),
            // Soft top-left accent veil to ground the sigil.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: 0.18),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.65),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
            // Corner peer-peek: up to 3 co-seen sigils fanning out
            // of the top-right corner — mirrors the NFT-profile
            // "View Collection" effect.
            if (peerNodeNums.isNotEmpty)
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onPeerTap?.call();
                  },
                  child: _PeerPeek(
                    peerNodeNums: peerNodeNums,
                    peerTotal: peerTotal,
                  ),
                ),
              ),
            // Top-row badges: hex id pill + RF/MQTT pill.
            Positioned(
              top: AppTheme.spacing14,
              left: AppTheme.spacing14,
              child: Row(
                children: [
                  _HeroPill(
                    icon: Icons.hexagon_outlined,
                    label: hexId,
                    accent: Colors.white,
                    background: Colors.black.withValues(alpha: 0.45),
                  ),
                  const SizedBox(width: AppTheme.spacing6),
                  if (viaMqtt)
                    _HeroPill(
                      label: 'MQTT',
                      accent: const Color(0xFFFFA875),
                      background: Colors.black.withValues(alpha: 0.45),
                    )
                  else
                    _HeroPill(
                      label: l10n.nodedexConstellationCardRouteRf,
                      accent: const Color(0xFF59E0B7),
                      background: Colors.black.withValues(alpha: 0.45),
                    ),
                ],
              ),
            ),
            // Bottom title block.
            Positioned(
              left: AppTheme.spacing16,
              right: AppTheme.spacing16,
              bottom: AppTheme.spacing16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (socialTag != null && socialTag!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _HeroPill(
                        label: socialTag!.toUpperCase(),
                        accent: accent,
                        background: accent.withValues(alpha: 0.22),
                        bordered: true,
                      ),
                    ),
                  Text(
                    node.label,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: AppTheme.fontFamily,
                      height: 1.15,
                    ),
                    softWrap: true,
                  ),
                  if (lastSeen != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          lastSeen!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.85),
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap == null) return hero;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap!(node);
      },
      child: hero,
    );
  }
}

/// Three small sigil thumbnails peeking out of the top-right corner,
/// rotated slightly so they look like a stack pulled from inside the
/// card. A "+N" tag sits on top when there are more peers.
class _PeerPeek extends StatelessWidget {
  final List<int> peerNodeNums;
  final int peerTotal;

  const _PeerPeek({required this.peerNodeNums, required this.peerTotal});

  @override
  Widget build(BuildContext context) {
    final shown = peerNodeNums.take(3).toList();
    final remaining = peerTotal - shown.length;
    return SizedBox(
      width: 120,
      height: 110,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              top: -20.0 + i * 8,
              right: -20.0 + i * 18,
              child: Transform.rotate(
                angle: (i - 1) * 0.18,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 12,
                        offset: const Offset(-4, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.85),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: SigilDisplay(
                            nodeNum: shown[i],
                            size: 48,
                            showGlow: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (remaining > 0)
            Positioned(
              top: 56,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(AppTheme.radius20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  '+$remaining',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.4,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color accent;
  final Color background;
  final bool bordered;

  const _HeroPill({
    required this.label,
    required this.accent,
    required this.background,
    this.icon,
    this.bordered = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radius20),
        border: bordered
            ? Border.all(color: accent.withValues(alpha: 0.55))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: accent),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: accent,
              letterSpacing: 0.6,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}
