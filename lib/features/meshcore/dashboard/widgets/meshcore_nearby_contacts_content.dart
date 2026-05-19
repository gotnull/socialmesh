// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme.dart';
import '../../../../models/meshcore_contact.dart';
import '../../../../providers/meshcore_providers.dart';

/// MeshCore-flavoured equivalent of `NearbyNodesContent` from the
/// Meshtastic dashboard. Top 5 contacts sorted by most-recently-heard,
/// with SNR badge when available and a relative-time subtitle.
class MeshCoreNearbyContactsContent extends ConsumerWidget {
  const MeshCoreNearbyContactsContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final contactsState = ref.watch(meshCoreContactsProvider);
    final now = DateTime.now();

    final sorted = [...contactsState.contacts]
      ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    final top = sorted.take(5).toList();

    if (top.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        child: Column(
          children: [
            Icon(Icons.near_me_outlined, size: 32, color: context.textTertiary),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              l10n.meshcoreContactsEmptyTagline1,
              style: TextStyle(color: context.textTertiary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: top.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        color: context.border.withValues(alpha: 0.5),
        indent: 56,
      ),
      itemBuilder: (context, i) => _ContactTile(contact: top[i], now: now),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final MeshCoreContact contact;
  final DateTime now;

  const _ContactTile({required this.contact, required this.now});

  @override
  Widget build(BuildContext context) {
    final age = now.difference(contact.lastSeen);
    final isFresh = age.inHours < 24;
    final color = isFresh ? context.accentColor : context.textTertiary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                contact.name.isNotEmpty
                    ? contact.name.characters.first.toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacing10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.displayName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _ageLabel(age, context),
                  style: TextStyle(fontSize: 11, color: context.textTertiary),
                ),
              ],
            ),
          ),
          if (contact.snrDb != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: context.background,
                borderRadius: BorderRadius.circular(AppTheme.radius12),
              ),
              child: Text(
                '${contact.snrDb!.toStringAsFixed(1)} dB',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _ageLabel(Duration age, BuildContext context) {
    final l10n = context.l10n;
    if (age.inMinutes < 1) return l10n.meshcoreContactJustHeard;
    if (age.inMinutes < 60) {
      return l10n.meshcoreContactHeardMinutesAgo('${age.inMinutes}');
    }
    if (age.inHours < 24) {
      return l10n.meshcoreContactHeardHoursAgo('${age.inHours}');
    }
    return l10n.meshcoreContactHeardDaysAgo('${age.inDays}');
  }
}
