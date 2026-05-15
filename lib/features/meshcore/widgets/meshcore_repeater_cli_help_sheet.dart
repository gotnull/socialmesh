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
      // D49-B + D49-D4: full upstream 54-entry list across 7 categories.
      _HelpSection(
        title: l10n.meshcoreRepeaterCliHelpGeneralHeader,
        entries: const [
          _HelpEntry('advert', _HelpDescKey.advert),
          _HelpEntry('reboot', _HelpDescKey.reboot),
          _HelpEntry('clock', _HelpDescKey.clock),
          _HelpEntry('password <new-password>', _HelpDescKey.password),
          _HelpEntry('ver', _HelpDescKey.version),
          _HelpEntry('clear stats', _HelpDescKey.clearStats),
        ],
      ),
      _HelpSection(
        title: l10n.meshcoreRepeaterCliHelpSettingsHeader,
        entries: const [
          _HelpEntry('set af <factor>', _HelpDescKey.setAf),
          _HelpEntry('set tx <power>', _HelpDescKey.setTx),
          _HelpEntry('set repeat <on|off>', _HelpDescKey.setRepeat),
          _HelpEntry(
            'set allow.read.only <on|off>',
            _HelpDescKey.setAllowReadOnly,
          ),
          _HelpEntry('set flood.max <hops>', _HelpDescKey.setFloodMax),
          _HelpEntry('set int.thresh <db>', _HelpDescKey.setIntThresh),
          _HelpEntry(
            'set agc.reset.interval <s>',
            _HelpDescKey.setAgcResetInterval,
          ),
          _HelpEntry('set multi.acks <0|1>', _HelpDescKey.setMultiAcks),
          _HelpEntry(
            'set advert.interval <minutes>',
            _HelpDescKey.setAdvertInterval,
          ),
          _HelpEntry(
            'set flood.advert.interval <h>',
            _HelpDescKey.setFloodAdvertInterval,
          ),
          _HelpEntry('set guest.password <new>', _HelpDescKey.setGuestPassword),
          _HelpEntry('set name <name>', _HelpDescKey.setName),
          _HelpEntry('set lat <lat>', _HelpDescKey.setLat),
          _HelpEntry('set lon <lon>', _HelpDescKey.setLon),
          _HelpEntry('set radio <freq>,<bw>,<sf>,<cr>', _HelpDescKey.setRadio),
          _HelpEntry('set rxdelay <base>', _HelpDescKey.setRxDelay),
          _HelpEntry('set txdelay <factor>', _HelpDescKey.setTxDelay),
          _HelpEntry(
            'set direct.txdelay <factor>',
            _HelpDescKey.setDirectTxDelay,
          ),
          _HelpEntry(
            'set bridge.enabled <on|off>',
            _HelpDescKey.setBridgeEnabled,
          ),
          _HelpEntry('set bridge.delay <ms>', _HelpDescKey.setBridgeDelay),
          _HelpEntry('set bridge.source <rx|tx>', _HelpDescKey.setBridgeSource),
          _HelpEntry('set bridge.baud <speed>', _HelpDescKey.setBridgeBaud),
          _HelpEntry(
            'set bridge.secret <secret>',
            _HelpDescKey.setBridgeSecret,
          ),
          _HelpEntry(
            'set adc.multiplier <factor>',
            _HelpDescKey.setAdcMultiplier,
          ),
          _HelpEntry(
            'tempradio <freq>,<bw>,<sf>,<cr>,<minutes>',
            _HelpDescKey.tempRadio,
          ),
          _HelpEntry(
            'setperm <pubkey-hex> <permissions>',
            _HelpDescKey.setPerm,
          ),
        ],
      ),
      _HelpSection(
        title: l10n.meshcoreRepeaterCliHelpBridgeHeader,
        entries: const [
          _HelpEntry('get bridge.type', _HelpDescKey.getBridgeType),
        ],
      ),
      _HelpSection(
        title: l10n.meshcoreRepeaterCliHelpLoggingHeader,
        entries: const [
          _HelpEntry('log start', _HelpDescKey.logStart),
          _HelpEntry('log stop', _HelpDescKey.logStop),
          _HelpEntry('log erase', _HelpDescKey.logErase),
        ],
      ),
      _HelpSection(
        title: l10n.meshcoreRepeaterCliHelpNeighborsHeader,
        entries: const [
          _HelpEntry('neighbors', _HelpDescKey.neighbors),
          _HelpEntry('neighbor.remove <prefix>', _HelpDescKey.neighborRemove),
        ],
      ),
      _HelpSection(
        title: l10n.meshcoreRepeaterCliHelpRegionHeader,
        entries: const [
          _HelpEntry('region', _HelpDescKey.region),
          _HelpEntry('region load', _HelpDescKey.regionLoad),
          _HelpEntry('region get <* | name-prefix>', _HelpDescKey.regionGet),
          _HelpEntry('region put <name> <* | parent>', _HelpDescKey.regionPut),
          _HelpEntry('region remove <name>', _HelpDescKey.regionRemove),
          _HelpEntry(
            'region allowf <* | name-prefix>',
            _HelpDescKey.regionAllowf,
          ),
          _HelpEntry(
            'region denyf <* | name-prefix>',
            _HelpDescKey.regionDenyf,
          ),
          _HelpEntry('region home', _HelpDescKey.regionHome),
          _HelpEntry(
            'region home <* | name-prefix>',
            _HelpDescKey.regionHomeSet,
          ),
          _HelpEntry('region save', _HelpDescKey.regionSave),
        ],
      ),
      _HelpSection(
        title: l10n.meshcoreRepeaterCliHelpGpsHeader,
        entries: const [
          _HelpEntry('gps', _HelpDescKey.gps),
          _HelpEntry('gps <on|off>', _HelpDescKey.gpsOnOff),
          _HelpEntry('gps sync', _HelpDescKey.gpsSync),
          _HelpEntry('gps setloc', _HelpDescKey.gpsSetLoc),
          _HelpEntry('gps advert', _HelpDescKey.gpsAdvert),
          _HelpEntry(
            'gps advert <none|share|prefs>',
            _HelpDescKey.gpsAdvertSet,
          ),
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
      case _HelpDescKey.password:
        return l10n.meshcoreRepeaterCliHelpPassword;
      case _HelpDescKey.version:
        return l10n.meshcoreRepeaterCliHelpVersion;
      case _HelpDescKey.clearStats:
        return l10n.meshcoreRepeaterCliHelpClearStats;
      case _HelpDescKey.setAf:
        return l10n.meshcoreRepeaterCliHelpSetAf;
      case _HelpDescKey.setTx:
        return l10n.meshcoreRepeaterCliHelpSetTx;
      case _HelpDescKey.setRepeat:
        return l10n.meshcoreRepeaterCliHelpSetRepeat;
      case _HelpDescKey.setAllowReadOnly:
        return l10n.meshcoreRepeaterCliHelpSetAllowReadOnly;
      case _HelpDescKey.setFloodMax:
        return l10n.meshcoreRepeaterCliHelpSetFloodMax;
      case _HelpDescKey.setIntThresh:
        return l10n.meshcoreRepeaterCliHelpSetIntThresh;
      case _HelpDescKey.setAgcResetInterval:
        return l10n.meshcoreRepeaterCliHelpSetAgcResetInterval;
      case _HelpDescKey.setMultiAcks:
        return l10n.meshcoreRepeaterCliHelpSetMultiAcks;
      case _HelpDescKey.setAdvertInterval:
        return l10n.meshcoreRepeaterCliHelpSetAdvertInterval;
      case _HelpDescKey.setFloodAdvertInterval:
        return l10n.meshcoreRepeaterCliHelpSetFloodAdvertInterval;
      case _HelpDescKey.setGuestPassword:
        return l10n.meshcoreRepeaterCliHelpSetGuestPassword;
      case _HelpDescKey.setName:
        return l10n.meshcoreRepeaterCliHelpSetName;
      case _HelpDescKey.setLat:
        return l10n.meshcoreRepeaterCliHelpSetLat;
      case _HelpDescKey.setLon:
        return l10n.meshcoreRepeaterCliHelpSetLon;
      case _HelpDescKey.setRadio:
        return l10n.meshcoreRepeaterCliHelpSetRadio;
      case _HelpDescKey.setRxDelay:
        return l10n.meshcoreRepeaterCliHelpSetRxDelay;
      case _HelpDescKey.setTxDelay:
        return l10n.meshcoreRepeaterCliHelpSetTxDelay;
      case _HelpDescKey.setDirectTxDelay:
        return l10n.meshcoreRepeaterCliHelpSetDirectTxDelay;
      case _HelpDescKey.setBridgeEnabled:
        return l10n.meshcoreRepeaterCliHelpSetBridgeEnabled;
      case _HelpDescKey.setBridgeDelay:
        return l10n.meshcoreRepeaterCliHelpSetBridgeDelay;
      case _HelpDescKey.setBridgeSource:
        return l10n.meshcoreRepeaterCliHelpSetBridgeSource;
      case _HelpDescKey.setBridgeBaud:
        return l10n.meshcoreRepeaterCliHelpSetBridgeBaud;
      case _HelpDescKey.setBridgeSecret:
        return l10n.meshcoreRepeaterCliHelpSetBridgeSecret;
      case _HelpDescKey.setAdcMultiplier:
        return l10n.meshcoreRepeaterCliHelpSetAdcMultiplier;
      case _HelpDescKey.tempRadio:
        return l10n.meshcoreRepeaterCliHelpTempRadio;
      case _HelpDescKey.setPerm:
        return l10n.meshcoreRepeaterCliHelpSetPerm;
      case _HelpDescKey.getBridgeType:
        return l10n.meshcoreRepeaterCliHelpGetBridgeType;
      case _HelpDescKey.logStart:
        return l10n.meshcoreRepeaterCliHelpLogStart;
      case _HelpDescKey.logStop:
        return l10n.meshcoreRepeaterCliHelpLogStop;
      case _HelpDescKey.logErase:
        return l10n.meshcoreRepeaterCliHelpLogErase;
      case _HelpDescKey.neighbors:
        return l10n.meshcoreRepeaterCliHelpNeighbors;
      case _HelpDescKey.neighborRemove:
        return l10n.meshcoreRepeaterCliHelpNeighborRemove;
      case _HelpDescKey.region:
        return l10n.meshcoreRepeaterCliHelpRegion;
      case _HelpDescKey.regionLoad:
        return l10n.meshcoreRepeaterCliHelpRegionLoad;
      case _HelpDescKey.regionGet:
        return l10n.meshcoreRepeaterCliHelpRegionGet;
      case _HelpDescKey.regionPut:
        return l10n.meshcoreRepeaterCliHelpRegionPut;
      case _HelpDescKey.regionRemove:
        return l10n.meshcoreRepeaterCliHelpRegionRemove;
      case _HelpDescKey.regionAllowf:
        return l10n.meshcoreRepeaterCliHelpRegionAllowf;
      case _HelpDescKey.regionDenyf:
        return l10n.meshcoreRepeaterCliHelpRegionDenyf;
      case _HelpDescKey.regionHome:
        return l10n.meshcoreRepeaterCliHelpRegionHome;
      case _HelpDescKey.regionHomeSet:
        return l10n.meshcoreRepeaterCliHelpRegionHomeSet;
      case _HelpDescKey.regionSave:
        return l10n.meshcoreRepeaterCliHelpRegionSave;
      case _HelpDescKey.gps:
        return l10n.meshcoreRepeaterCliHelpGps;
      case _HelpDescKey.gpsOnOff:
        return l10n.meshcoreRepeaterCliHelpGpsOnOff;
      case _HelpDescKey.gpsSync:
        return l10n.meshcoreRepeaterCliHelpGpsSync;
      case _HelpDescKey.gpsSetLoc:
        return l10n.meshcoreRepeaterCliHelpGpsSetLoc;
      case _HelpDescKey.gpsAdvert:
        return l10n.meshcoreRepeaterCliHelpGpsAdvert;
      case _HelpDescKey.gpsAdvertSet:
        return l10n.meshcoreRepeaterCliHelpGpsAdvertSet;
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
  // General
  advert,
  reboot,
  clock,
  password,
  version,
  clearStats,
  // Settings
  setAf,
  setTx,
  setRepeat,
  setAllowReadOnly,
  setFloodMax,
  setIntThresh,
  setAgcResetInterval,
  setMultiAcks,
  setAdvertInterval,
  setFloodAdvertInterval,
  setGuestPassword,
  setName,
  setLat,
  setLon,
  setRadio,
  setRxDelay,
  setTxDelay,
  setDirectTxDelay,
  setBridgeEnabled,
  setBridgeDelay,
  setBridgeSource,
  setBridgeBaud,
  setBridgeSecret,
  setAdcMultiplier,
  tempRadio,
  setPerm,
  // Bridge
  getBridgeType,
  // Logging
  logStart,
  logStop,
  logErase,
  // Neighbours
  neighbors,
  neighborRemove,
  // Region
  region,
  regionLoad,
  regionGet,
  regionPut,
  regionRemove,
  regionAllowf,
  regionDenyf,
  regionHome,
  regionHomeSet,
  regionSave,
  // GPS
  gps,
  gpsOnOff,
  gpsSync,
  gpsSetLoc,
  gpsAdvert,
  gpsAdvertSet,
}
