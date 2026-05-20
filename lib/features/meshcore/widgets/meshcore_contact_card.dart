// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Shared tile for rendering a single MeshCore contact in a list.
//
// Used by both `MeshCoreMessagingScreen` (Messages -> Contacts
// sub-tab, conversations only) and `MeshCoreNodesScreen` (standalone
// full roster). Mirrors `_DmInfo`/`_NodeCard` shape on the Meshtastic
// side where a single tile widget is the unit between MessagingScreen
// and NodesScreen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../models/meshcore_contact.dart';
import '../../../providers/meshcore_message_providers.dart';
import '../contact_l10n.dart';
import 'meshcore_sigil_avatar.dart';

class MeshCoreContactCard extends ConsumerWidget {
  final MeshCoreContact contact;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const MeshCoreContactCard({
    super.key,
    required this.contact,
    required this.onTap,
    required this.onLongPress,
  });

  // Stable color picked from the public-key hash so a contact's tile
  // colour is deterministic across rebuilds. Only used as a fallback
  // when the pubkey is too short to render a sigil avatar.
  Color _fallbackAvatarColor() {
    const palette = [
      AccentColors.cyan,
      AccentColors.purple,
      AccentColors.pink,
      AccentColors.green,
      AccentColors.orange,
      AccentColors.blue,
    ];
    final hash = contact.publicKeyHex.hashCode;
    return palette[hash.abs() % palette.length];
  }

  IconData _typeIcon() {
    switch (contact.type) {
      case 1:
        return Icons.person_rounded;
      case 2:
        return Icons.cell_tower_rounded;
      case 3:
        return Icons.meeting_room_rounded;
      case 4:
        return Icons.sensors_rounded;
      default:
        return Icons.device_unknown_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarColor = _fallbackAvatarColor();
    final conversationsState = ref.watch(meshCoreConversationsProvider);
    final conversation = conversationsState.conversations
        .where((c) => c.id == contact.publicKeyHex)
        .cast<MeshCoreConversation?>()
        .firstWhere((_) => true, orElse: () => null);
    final lastMessageText = conversation?.lastMessageText;
    // Prefer the contact-store-hydrated count; fall back to the live
    // count from the conversations notifier for inbound that has not
    // been re-read into the contacts state yet.
    final unreadCount = contact.unreadCount > 0
        ? contact.unreadCount
        : (conversation?.unreadCount ?? 0);

    return BouncyTap(
      onTap: onTap,
      onLongPress: onLongPress,
      scaleFactor: 0.98,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(color: context.border, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing12),
          child: Row(
            children: [
              if (contact.publicKey.length >= 4)
                MeshCoreSigilAvatar(pubKey: contact.publicKey, size: 48)
              else
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: avatarColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                  child: Center(
                    child: Text(
                      contact.name.isNotEmpty
                          ? contact.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: avatarColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.displayName.isNotEmpty
                          ? contact.displayName
                          : context.l10n.meshcoreContactUnknownName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (lastMessageText != null &&
                        lastMessageText.isNotEmpty) ...[
                      const SizedBox(height: AppTheme.spacing2),
                      Text(
                        lastMessageText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: unreadCount > 0
                              ? context.textPrimary
                              : context.textSecondary,
                          fontSize: 13,
                          fontWeight: unreadCount > 0
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppTheme.spacing4),
                    Row(
                      children: [
                        Icon(
                          _typeIcon(),
                          size: 14,
                          color: context.textTertiary,
                        ),
                        const SizedBox(width: AppTheme.spacing4),
                        Text(
                          contact.localizedTypeLabel(context.l10n),
                          style: TextStyle(
                            color: context.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing12),
                        Icon(
                          Icons.route_rounded,
                          size: 14,
                          color: context.textTertiary,
                        ),
                        const SizedBox(width: AppTheme.spacing4),
                        Text(
                          contact.localizedPathLabel(context.l10n),
                          style: TextStyle(
                            color: context.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                        if (contact.snrDb != null) ...[
                          const SizedBox(width: AppTheme.spacing12),
                          _SnrBadge(snrDb: contact.snrDb!),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (contact.isFavorite)
                const Padding(
                  padding: EdgeInsets.only(right: AppTheme.spacing8),
                  child: Icon(Icons.star, color: AccentColors.yellow, size: 20),
                ),
              if (unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing8,
                    vertical: AppTheme.spacing4,
                  ),
                  decoration: BoxDecoration(
                    color: AccentColors.cyan,
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                Icon(Icons.chevron_right_rounded, color: context.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

// Per-contact SNR badge. Three signal bars colour-graded against the
// underlying dB plus a numeric label so the precise value is never
// hidden behind a qualitative bucket. Hidden by the caller when SNR
// is unknown. Thresholds match LoRa SNR bands typical for MeshCore:
// `>= 0 dB` excellent (3), `>= -7 dB` good (2), `>= -12 dB` weak (1),
// below -12 dB very poor (0).
class _SnrBadge extends StatelessWidget {
  final double snrDb;
  const _SnrBadge({required this.snrDb});

  int get _activeBars {
    if (snrDb >= 0) return 3;
    if (snrDb >= -7) return 2;
    if (snrDb >= -12) return 1;
    return 0;
  }

  Color _accent(BuildContext context) {
    final bars = _activeBars;
    if (bars >= 3) return AccentColors.green;
    if (bars >= 2) return AccentColors.cyan;
    if (bars >= 1) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent(context);
    final active = _activeBars;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++) ...[
          Container(
            width: 3,
            height: 4 + i * 3.0,
            margin: EdgeInsets.only(
              right: i == 2 ? AppTheme.spacing6 : AppTheme.spacing2,
            ),
            decoration: BoxDecoration(
              color: i < active
                  ? accent
                  : context.textTertiary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppTheme.spacing2 / 2),
            ),
          ),
        ],
        Text(
          context.l10n.meshcoreSnrLabel(snrDb.toStringAsFixed(1)),
          style: TextStyle(
            color: accent,
            fontSize: 12,
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
