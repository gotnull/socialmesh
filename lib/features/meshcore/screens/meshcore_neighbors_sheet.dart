// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D36-A: MeshCore neighbours / repeater query sheet.
//
// Opens from the Neighbours tile on a repeater contact detail screen.
// Sends a single binary RPC (`CMD_SEND_BINARY_REQ` 0x32 with
// req_type=0x06) via `meshCoreNeighborsProvider`, waits for the
// async push response, and renders the parsed 7-byte neighbour
// records.
//
// Privacy: the sheet NEVER renders pubkeys, MMFs, channel names, raw
// payloads, message plaintext, or envelope content. Only the 4-byte
// neighbour pubkey prefix (matched to local contacts when possible)
// + last-heard duration + SNR badge.
//
// Airtime safety: manual refresh only, 10 s per-repeater cooldown
// enforced inside the provider. No automatic polling, no fan-out.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/section_header.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/meshcore_contact.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../services/meshcore/protocol/meshcore_messages.dart';

Future<void> showMeshCoreNeighborsSheet(
  BuildContext context, {
  required MeshCoreContact repeater,
}) {
  return AppBottomSheet.showScrollable<void>(
    context: context,
    initialChildSize: 0.85,
    minChildSize: 0.5,
    maxChildSize: 0.95,
    builder: (controller) =>
        _NeighborsSheet(repeater: repeater, scrollController: controller),
  );
}

class _NeighborsSheet extends ConsumerStatefulWidget {
  final MeshCoreContact repeater;
  final ScrollController scrollController;

  const _NeighborsSheet({
    required this.repeater,
    required this.scrollController,
  });

  @override
  ConsumerState<_NeighborsSheet> createState() => _NeighborsSheetState();
}

class _NeighborsSheetState extends ConsumerState<_NeighborsSheet>
    with LifecycleSafeMixin {
  @override
  void initState() {
    super.initState();
    // Kick off the first request after the first frame so the sheet
    // can render its loading state before the provider's state flips.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(
            meshCoreNeighborsProvider(widget.repeater.publicKeyHex).notifier,
          )
          .requestRefresh();
    });
  }

  Future<void> _refresh() async {
    await ref
        .read(meshCoreNeighborsProvider(widget.repeater.publicKeyHex).notifier)
        .requestRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(
      meshCoreNeighborsProvider(widget.repeater.publicKeyHex),
    );
    final notifier = ref.read(
      meshCoreNeighborsProvider(widget.repeater.publicKeyHex).notifier,
    );
    final now = DateTime.now();
    final visibleStatus = notifier.visibleStatus(now);
    final name = widget.repeater.displayName.isNotEmpty
        ? widget.repeater.displayName
        : l10n.meshcoreContactUnknownName;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            AppTheme.spacing8,
            AppTheme.spacing16,
            AppTheme.spacing8,
          ),
          child: Row(
            children: [
              Expanded(
                child: SectionTitle(
                  title: l10n.meshcoreNeighborsSheetTitle(name),
                  leadingIcon: Icons.hub_rounded,
                ),
              ),
              _RefreshChip(
                key: const ValueKey('meshcore-neighbors-refresh'),
                enabled:
                    visibleStatus != MeshCoreNeighborsStatus.loading &&
                    visibleStatus != MeshCoreNeighborsStatus.cooling,
                onTap: _refresh,
              ),
            ],
          ),
        ),
        Expanded(
          child: _Body(
            state: state,
            visibleStatus: visibleStatus,
            scrollController: widget.scrollController,
            now: now,
            contacts: ref.watch(meshCoreContactsProvider).contacts,
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  final MeshCoreNeighborsState state;
  final MeshCoreNeighborsStatus visibleStatus;
  final ScrollController scrollController;
  final DateTime now;
  final List<MeshCoreContact> contacts;

  const _Body({
    required this.state,
    required this.visibleStatus,
    required this.scrollController,
    required this.now,
    required this.contacts,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    switch (visibleStatus) {
      case MeshCoreNeighborsStatus.idle:
      case MeshCoreNeighborsStatus.loading:
        return _Placeholder(
          key: const ValueKey('meshcore-neighbors-loading'),
          icon: Icons.hourglass_empty_rounded,
          text: visibleStatus == MeshCoreNeighborsStatus.loading
              ? l10n.meshcoreNeighborsLoading
              : l10n.meshcoreNeighborsNoData,
        );
      case MeshCoreNeighborsStatus.failure:
        return _Placeholder(
          key: const ValueKey('meshcore-neighbors-failure'),
          icon: Icons.error_outline_rounded,
          text: _failureCopy(l10n, state.lastError),
        );
      case MeshCoreNeighborsStatus.cooling:
        final until = state.cooldownUntil;
        final secs = until == null
            ? 0
            : ((until.difference(now).inMilliseconds + 999) ~/ 1000).clamp(
                1,
                30,
              );
        return _Placeholder(
          key: const ValueKey('meshcore-neighbors-cooling'),
          icon: Icons.timer_outlined,
          text: l10n.meshcoreNeighborsCooling(secs),
        );
      case MeshCoreNeighborsStatus.success:
        final response = state.lastResponse;
        if (response == null || response.results.isEmpty) {
          return _Placeholder(
            key: const ValueKey('meshcore-neighbors-empty'),
            icon: Icons.podcasts_rounded,
            text: l10n.meshcoreNeighborsNoData,
          );
        }
        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing8,
          ),
          itemCount: response.results.length + 1, // +1 for the footer
          itemBuilder: (context, index) {
            if (index == response.results.length) {
              return _Footer(response: response);
            }
            final neighbor = response.results[index];
            return _NeighborRow(
              key: ValueKey(
                'meshcore-neighbors-row-${_hex(neighbor.pubKeyPrefix)}',
              ),
              neighbor: neighbor,
              contacts: contacts,
              now: now,
            );
          },
        );
    }
  }

  static String _failureCopy(AppLocalizations l10n, String? code) {
    switch (code) {
      case 'no_session':
        return l10n.meshcoreNeighborsNoSession;
      case 'parse_failed':
      case 'contact_missing':
        return l10n.meshcoreNeighborsParseFailed;
      case 'timeout':
      default:
        return l10n.meshcoreNeighborsTimeout;
    }
  }

  static String _hex(List<int> bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toLowerCase())
        .join();
  }
}

class _NeighborRow extends StatelessWidget {
  final MeshCoreNeighbor neighbor;
  final List<MeshCoreContact> contacts;
  final DateTime now;

  const _NeighborRow({
    super.key,
    required this.neighbor,
    required this.contacts,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = _resolveName(l10n);
    final heard = _formatDuration(neighbor.lastHeard);
    final snrColour = _snrColour(neighbor.snrDb, context);
    final accent = context.accentColor;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing12,
      ),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.person_pin_rounded, color: accent),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing2),
                Text(
                  l10n.meshcoreNeighborsHeardAgo(heard),
                  style: TextStyle(
                    color: context.textTertiary,
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          _SnrBadge(
            label: l10n.meshcoreNeighborsSnrDb(
              neighbor.snrDb.toStringAsFixed(1),
            ),
            accent: snrColour,
          ),
        ],
      ),
    );
  }

  String _resolveName(AppLocalizations l10n) {
    if (neighbor.pubKeyPrefix.isEmpty) {
      return l10n.meshcoreNeighborsUnknown;
    }
    final prefixHex = _hexOf(neighbor.pubKeyPrefix);
    for (final c in contacts) {
      if (c.publicKey.length < 4) continue;
      final contactPrefix = _hexOf(c.publicKey.sublist(0, 4));
      if (contactPrefix == prefixHex) {
        return c.displayName.isNotEmpty ? c.displayName : '<$prefixHex>';
      }
    }
    return '<$prefixHex>';
  }

  static String _hexOf(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String _formatDuration(Duration d) {
    final s = d.inSeconds;
    if (s < 60) return '$s s';
    if (s < 3600) {
      final m = s ~/ 60;
      final r = s % 60;
      return '$m m $r s';
    }
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    return '$h h $m m';
  }

  static Color _snrColour(double snrDb, BuildContext context) {
    if (snrDb >= 0) return AccentColors.green;
    if (snrDb >= -5) return AccentColors.orange;
    return AppTheme.errorRed;
  }
}

class _SnrBadge extends StatelessWidget {
  final String label;
  final Color accent;

  const _SnrBadge({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontFamily: AppTheme.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final MeshCoreNeighborsResponse response;
  const _Footer({required this.response});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing4,
        vertical: AppTheme.spacing12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.meshcoreNeighborsShowing(
              response.results.length,
              response.reportedCount,
            ),
            style: TextStyle(
              color: context.textTertiary,
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            l10n.meshcoreNeighborsLastRefreshed(
              _formatTime(response.fetchedAt),
            ),
            style: TextStyle(
              color: context.textTertiary,
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}

class _Placeholder extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Placeholder({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing24,
          vertical: AppTheme.spacing24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: context.textTertiary),
            const SizedBox(height: AppTheme.spacing12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textSecondary,
                fontFamily: AppTheme.fontFamily,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RefreshChip extends StatelessWidget {
  final bool enabled;
  final Future<void> Function() onTap;

  const _RefreshChip({super.key, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = enabled ? context.accentColor : context.textTertiary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing8,
            vertical: 6,
          ),
          child: Row(
            children: [
              Icon(Icons.refresh_rounded, size: 16, color: accent),
              const SizedBox(width: AppTheme.spacing4),
              Text(
                l10n.meshcoreNeighborsRefresh,
                style: TextStyle(
                  color: accent,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
