// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D49-B: repeater CLI help sheet.
//
// Curated 15-entry list of the most-used CLI commands. The full
// upstream reference table (~60 entries spanning region / gps /
// bridge / logging) defers to D49-D; for D49-B we surface the
// commands a typical admin reaches for first.
//
// Renders inside `AppBottomSheet.showScrollable` per the
// content-heavy sheet rule. Tapping a row closes the sheet and
// returns the command template to the caller.

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/section_header.dart';

Future<String?> showMeshCoreRepeaterCliHelpSheet(BuildContext context) {
  final l10n = context.l10n;
  return AppBottomSheet.showScrollable<String>(
    context: context,
    title: l10n.meshcoreRepeaterCliHelpTitle,
    initialChildSize: 0.85,
    minChildSize: 0.5,
    maxChildSize: 0.95,
    builder: (controller) => _CliHelpBody(scrollController: controller),
  );
}

class _CliHelpBody extends StatelessWidget {
  final ScrollController scrollController;
  const _CliHelpBody({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sections = <_HelpSection>[
      _HelpSection(
        title: l10n.meshcoreRepeaterCliHelpGeneralHeader,
        entries: const [
          _HelpEntry('advert', _HelpDescKey.advert),
          _HelpEntry('reboot', _HelpDescKey.reboot),
          _HelpEntry('clock', _HelpDescKey.clock),
          _HelpEntry('ver', _HelpDescKey.version),
          _HelpEntry('clear stats', _HelpDescKey.clearStats),
        ],
      ),
      _HelpSection(
        title: l10n.meshcoreRepeaterCliHelpSettingsHeader,
        entries: const [
          _HelpEntry('set name <name>', _HelpDescKey.setName),
          _HelpEntry('set tx <power>', _HelpDescKey.setTx),
          _HelpEntry('set radio <freq>,<bw>,<sf>,<cr>', _HelpDescKey.setRadio),
          _HelpEntry('set repeat <on|off>', _HelpDescKey.setRepeat),
          _HelpEntry('set af <factor>', _HelpDescKey.setAf),
          _HelpEntry(
            'set advert.interval <minutes>',
            _HelpDescKey.setAdvertInterval,
          ),
        ],
      ),
      _HelpSection(
        title: l10n.meshcoreRepeaterCliHelpNeighborsHeader,
        entries: const [
          _HelpEntry('neighbors', _HelpDescKey.neighbors),
          _HelpEntry('neighbor.remove <prefix>', _HelpDescKey.neighborRemove),
        ],
      ),
    ];

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing8,
      ),
      itemCount: sections.length,
      itemBuilder: (_, i) => _SectionView(section: sections[i]),
    );
  }
}

class _SectionView extends StatelessWidget {
  final _HelpSection section;
  const _SectionView({required this.section});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title: section.title),
        ...section.entries.map((e) => _HelpRow(entry: e)),
        const SizedBox(height: AppTheme.spacing16),
      ],
    );
  }
}

class _HelpRow extends StatelessWidget {
  final _HelpEntry entry;
  const _HelpRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final description = _resolve(context, entry.descKey);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
      child: Material(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          onTap: () {
            Navigator.of(context).pop(entry.command);
          },
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.command,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  description,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _resolve(BuildContext context, _HelpDescKey key) {
    final l10n = context.l10n;
    switch (key) {
      case _HelpDescKey.advert:
        return l10n.meshcoreRepeaterCliHelpAdvert;
      case _HelpDescKey.reboot:
        return l10n.meshcoreRepeaterCliHelpReboot;
      case _HelpDescKey.clock:
        return l10n.meshcoreRepeaterCliHelpClock;
      case _HelpDescKey.version:
        return l10n.meshcoreRepeaterCliHelpVersion;
      case _HelpDescKey.clearStats:
        return l10n.meshcoreRepeaterCliHelpClearStats;
      case _HelpDescKey.setName:
        return l10n.meshcoreRepeaterCliHelpSetName;
      case _HelpDescKey.setTx:
        return l10n.meshcoreRepeaterCliHelpSetTx;
      case _HelpDescKey.setRadio:
        return l10n.meshcoreRepeaterCliHelpSetRadio;
      case _HelpDescKey.setRepeat:
        return l10n.meshcoreRepeaterCliHelpSetRepeat;
      case _HelpDescKey.setAf:
        return l10n.meshcoreRepeaterCliHelpSetAf;
      case _HelpDescKey.setAdvertInterval:
        return l10n.meshcoreRepeaterCliHelpSetAdvertInterval;
      case _HelpDescKey.neighbors:
        return l10n.meshcoreRepeaterCliHelpNeighbors;
      case _HelpDescKey.neighborRemove:
        return l10n.meshcoreRepeaterCliHelpNeighborRemove;
    }
  }
}

class _HelpSection {
  final String title;
  final List<_HelpEntry> entries;
  const _HelpSection({required this.title, required this.entries});
}

class _HelpEntry {
  final String command;
  final _HelpDescKey descKey;
  const _HelpEntry(this.command, this.descKey);
}

enum _HelpDescKey {
  advert,
  reboot,
  clock,
  version,
  clearStats,
  setName,
  setTx,
  setRadio,
  setRepeat,
  setAf,
  setAdvertInterval,
  neighbors,
  neighborRemove,
}
