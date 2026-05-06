// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCore Radio Settings edit sheet.
//
// Minimal but correct UI for configuring the LoRa radio params on a
// connected MeshCore companion radio. Wraps two protocol commands:
//   - cmdSetRadioParams (0x0B): freq + bw + sf + cr
//   - cmdSetRadioTxPower (0x0C): tx_power
//
// Uses canonical inner-settings primitives (SettingsSectionHeader,
// FieldGroupCard, ChipSelector, OutlineInputBorder TextFormField). Pulls
// SF / CR / TX power from SelfInfo to pre-populate. Frequency and
// bandwidth aren't parsed from SelfInfo, so those fields rely on the
// caller's last-saved values (passed in via the constructor) or the
// firmware-default-aware placeholders.
//
// This is the "minimal but correct" shape per the slice; a full canonical
// settings screen is queued as follow-up.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/chip_selector.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../../../core/widgets/settings_primitives.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../services/meshcore/protocol/meshcore_messages.dart';
import '../../../services/meshcore/storage/meshcore_radio_params_store.dart';
import '../../../utils/snackbar.dart';

/// Supported MeshCore LoRa bandwidth values, in kHz.
///
/// Mirrors the dropdown on meshcore.co.uk/configurator. Values are stored
/// as kHz here for display and converted to Hz when sent on the wire.
const List<double> _supportedBandwidthsKhz = [
  7.8,
  10.4,
  15.6,
  20.8,
  31.25,
  41.7,
  62.5,
  125.0,
  250.0,
  500.0,
];

/// Build a tidy chip label for a bandwidth value, e.g. `7.8` not `7.80`.
String _bwLabel(double khz) {
  // Drop trailing .0 for whole numbers (125, 250, 500).
  if (khz == khz.roundToDouble()) return khz.toStringAsFixed(0);
  return khz.toString();
}

/// Open the MeshCore Radio Settings sheet.
///
/// `currentSelfInfo` pre-populates SF/CR/TX from the most recent
/// identify response. Frequency and bandwidth default to MeshCore EU868
/// defaults (869.525 / 250) since SelfInfo doesn't carry them.
Future<void> showMeshCoreRadioSettingsSheet({
  required BuildContext context,
  required MeshCoreSelfInfo? currentSelfInfo,
}) {
  return AppBottomSheet.showScrollable<void>(
    context: context,
    initialChildSize: 0.85,
    minChildSize: 0.5,
    maxChildSize: 0.95,
    builder: (controller) => _MeshCoreRadioSettingsSheet(
      scrollController: controller,
      currentSelfInfo: currentSelfInfo,
    ),
  );
}

class _MeshCoreRadioSettingsSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final MeshCoreSelfInfo? currentSelfInfo;

  const _MeshCoreRadioSettingsSheet({
    required this.scrollController,
    required this.currentSelfInfo,
  });

  @override
  ConsumerState<_MeshCoreRadioSettingsSheet> createState() =>
      _MeshCoreRadioSettingsSheetState();
}

class _MeshCoreRadioSettingsSheetState
    extends ConsumerState<_MeshCoreRadioSettingsSheet>
    with LifecycleSafeMixin {
  final _formKey = GlobalKey<FormState>();
  final MeshCoreRadioParamsStore _store = MeshCoreRadioParamsStore();
  late final TextEditingController _freqController;
  late final TextEditingController _txController;

  // Mutable picks for the chip selectors.
  late double _bandwidthKhz;
  late int _spreadingFactor;
  late int _codingRate;

  bool _saving = false;
  bool _hydrating = true;

  /// Stable per-device storage key.
  ///
  /// Uses ONLY the coordinator's `deviceInfo.nodeId` (4-byte hex prefix
  /// of the device public key, set synchronously in `identify()`).
  /// Critical: SelfInfo lags behind the connection (its `pubKey` is
  /// empty for a window after connect), so a key derived from
  /// `currentSelfInfo.pubKey` would collide with a *different-length*
  /// key for the same physical node when the user rapidly opens the
  /// sheet during the lag. Single source = save/load always agree.
  String? _nodeKey() {
    final nodeId = ref.read(connectionCoordinatorProvider).deviceInfo?.nodeId;
    if (nodeId == null || nodeId.isEmpty) return null;
    return nodeId.toLowerCase();
  }

  @override
  void initState() {
    super.initState();
    AppLogging.meshcore('event=screen.opened name=radio_settings');

    final info = widget.currentSelfInfo;

    // D16: SELF_INFO carries freq/bw/sf/cr/tx_power. The parser used to
    // drop freq+bw, which forced this sheet to keep its own client-side
    // cache (D11) as the only display source. With the parser fixed,
    // live firmware values are the ground truth, the local store is a
    // fallback for when SelfInfo hasn't loaded yet (cold-start, post-
    // disconnect window), and the firmware-default constants are the
    // final fallback.
    final liveFreqKhz = info?.freqKhz;
    final liveBandwidthHz = info?.bandwidthHz;
    _freqController = TextEditingController(
      text: liveFreqKhz != null ? (liveFreqKhz / 1000).toStringAsFixed(3) : '',
    );
    _bandwidthKhz = liveBandwidthHz != null
        ? liveBandwidthHz / 1000
        : 250.0; // firmware default LORA_BW (overridden by store hydrate)
    _spreadingFactor = info?.spreadingFactor ?? 11;
    _codingRate = info?.codingRate ?? 5;
    _txController = TextEditingController(
      text: (info?.txPowerDbm ?? 22).toString(),
    );

    if (info != null && liveFreqKhz != null && liveBandwidthHz != null) {
      AppLogging.meshcore(
        'event=radio.hydrate.live '
        'freq=${liveFreqKhz}kHz bw=${liveBandwidthHz}Hz '
        'sf=${info.spreadingFactor} cr=${info.codingRate} '
        'tx=${info.txPowerDbm}dBm',
      );
    }

    _hydrateFromStore();
  }

  Future<void> _hydrateFromStore() async {
    final key = _nodeKey();
    if (key == null) {
      AppLogging.meshcore('event=radio.hydrate.skipped reason=no_node_key');
      if (mounted) safeSetState(() => _hydrating = false);
      return;
    }
    final saved = await _store.load(key);
    if (!mounted) {
      return;
    }
    if (saved == null) {
      AppLogging.meshcore('event=radio.hydrate.miss key_len=${key.length}');
      safeSetState(() => _hydrating = false);
      return;
    }
    // D16: live SelfInfo (set in initState) wins over the store. The
    // store is now a cold-start / post-disconnect fallback only, not
    // the display source-of-truth. This eliminates the false
    // "applied" appearance the store created when firmware silently
    // didn't accept a previous apply (D16 root concern).
    final info = widget.currentSelfInfo;
    final haveLive = info?.freqKhz != null && info?.bandwidthHz != null;
    if (haveLive) {
      AppLogging.meshcore(
        'event=radio.hydrate.store_skipped reason=live_present',
      );
      safeSetState(() => _hydrating = false);
      return;
    }
    AppLogging.meshcore(
      'event=radio.hydrate.hit '
      'freq=${saved.freqKhz}kHz bw=${saved.bandwidthHz}Hz '
      'sf=${saved.spreadingFactor} cr=${saved.codingRate} '
      'tx=${saved.txPowerDbm}dBm',
    );
    safeSetState(() {
      _freqController.text = (saved.freqKhz / 1000).toString();
      _bandwidthKhz = saved.bandwidthHz / 1000;
      _spreadingFactor = saved.spreadingFactor;
      _codingRate = saved.codingRate;
      _txController.text = saved.txPowerDbm.toString();
      _hydrating = false;
    });
  }

  @override
  void dispose() {
    _freqController.dispose();
    _txController.dispose();
    super.dispose();
  }

  String? _validateFreq(String? value, AppLocalizations l10n) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return l10n.meshcoreRadioSettingsValidationFreqRequired;
    final mhz = double.tryParse(raw);
    if (mhz == null) return l10n.meshcoreRadioSettingsValidationFreqRange;
    if (mhz < 150 || mhz > 2500) {
      return l10n.meshcoreRadioSettingsValidationFreqRange;
    }
    return null;
  }

  String? _validateTx(String? value, AppLocalizations l10n) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return l10n.meshcoreRadioSettingsValidationTxRange;
    final dbm = int.tryParse(raw);
    if (dbm == null) return l10n.meshcoreRadioSettingsValidationTxRange;
    if (dbm < -9 || dbm > 30) {
      return l10n.meshcoreRadioSettingsValidationTxRange;
    }
    return null;
  }

  Future<void> _apply() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final session = ref.read(meshCoreSessionProvider);
    final l10n = context.l10n;
    if (session == null) {
      showErrorSnackBar(context, l10n.meshcoreNotConnectedToDevice);
      return;
    }

    final freqMhz = double.parse(_freqController.text.trim());
    // Wire format expects kHz as u32 LE.
    final freqKhz = (freqMhz * 1000).round();
    // Bandwidth wire format expects Hz as u32 LE.
    final bwHz = (_bandwidthKhz * 1000).round();
    final txDbm = int.parse(_txController.text.trim());

    setState(() => _saving = true);
    AppLogging.meshcore(
      'event=radio.apply.attempted freq=${freqKhz}kHz bw=${bwHz}Hz '
      'sf=$_spreadingFactor cr=$_codingRate tx=${txDbm}dBm',
    );

    try {
      final paramsOk = await session.setRadioParams(
        freqKhz: freqKhz,
        bandwidthHz: bwHz,
        spreadingFactor: _spreadingFactor,
        codingRate: _codingRate,
      );
      if (!paramsOk) {
        AppLogging.meshcore(
          'event=radio.apply.failed stage=params reason=device_rejected',
          error: true,
        );
        if (!mounted) return;
        showErrorSnackBar(context, l10n.meshcoreRadioSettingsAppliedFailed);
        safeSetState(() => _saving = false);
        return;
      }

      final powerOk = await session.setRadioTxPower(powerDbm: txDbm);
      if (!powerOk) {
        AppLogging.meshcore(
          'event=radio.apply.failed stage=tx_power reason=device_rejected',
          error: true,
        );
        if (!mounted) return;
        showErrorSnackBar(context, l10n.meshcoreRadioSettingsAppliedFailed);
        safeSetState(() => _saving = false);
        return;
      }

      // D16 read-back verification: refresh SelfInfo and compare live
      // firmware values against what we just sent. Pre-D16 the sheet
      // claimed success purely on RESP_CODE_OK from set_radio_params,
      // and the parser dropped freq+bw so we couldn't have verified
      // even if we wanted to. Now SELF_INFO carries the live state, so
      // we treat any mismatch as a serious diagnostic event (still
      // non-fatal: firmware says it accepted, but the user should know
      // if the live read disagrees).
      try {
        await ref.read(meshCoreSelfInfoProvider.notifier).refresh();
        if (!mounted) return;
        final live = ref.read(meshCoreSelfInfoProvider).selfInfo;
        if (live != null) {
          final liveFreq = live.freqKhz;
          final liveBw = live.bandwidthHz;
          final liveSf = live.spreadingFactor;
          final liveCr = live.codingRate;
          final liveTx = live.txPowerDbm;
          final freqMatch = liveFreq == null || liveFreq == freqKhz;
          final bwMatch = liveBw == null || liveBw == bwHz;
          final sfMatch = liveSf == null || liveSf == _spreadingFactor;
          final crMatch = liveCr == null || liveCr == _codingRate;
          final txMatch = liveTx == txDbm;
          final allMatch =
              freqMatch && bwMatch && sfMatch && crMatch && txMatch;
          if (allMatch) {
            AppLogging.meshcore(
              'event=radio.readback.match '
              'freq=${liveFreq}kHz bw=${liveBw}Hz '
              'sf=$liveSf cr=$liveCr tx=${liveTx}dBm',
            );
          } else {
            AppLogging.meshcore(
              'event=radio.readback.mismatch '
              'desired=[freq=${freqKhz}kHz bw=${bwHz}Hz '
              'sf=$_spreadingFactor cr=$_codingRate tx=${txDbm}dBm] '
              'live=[freq=${liveFreq ?? "-"}kHz bw=${liveBw ?? "-"}Hz '
              'sf=${liveSf ?? "-"} cr=${liveCr ?? "-"} tx=${liveTx}dBm]',
              error: true,
            );
          }
        } else {
          AppLogging.meshcore(
            'event=radio.readback.unavailable reason=no_self_info',
          );
        }
      } catch (e) {
        // Refresh failure is non-fatal: firmware acked the apply
        // command, we just couldn't independently verify. Log so the
        // lapse is visible in the diag bundle.
        AppLogging.meshcore(
          'event=radio.readback.failed reason=${e.runtimeType}',
          error: true,
        );
      }

      // Persist client-side as a cold-start / disconnected fallback.
      // Post-D16 this is no longer the display source-of-truth (live
      // SelfInfo is); it's just what the sheet shows when SelfInfo
      // hasn't loaded yet on reopen.
      final nodeKey = _nodeKey();
      if (nodeKey != null) {
        try {
          await _store.save(
            nodeKey,
            MeshCoreRadioParams(
              freqKhz: freqKhz,
              bandwidthHz: bwHz,
              spreadingFactor: _spreadingFactor,
              codingRate: _codingRate,
              txPowerDbm: txDbm,
            ),
          );
          AppLogging.meshcore(
            'event=radio.persist.saved key_len=${nodeKey.length}',
          );
        } catch (e) {
          // Storage failure is non-fatal: the radio still has the new
          // params. Log so the lapse is visible in the diag bundle.
          AppLogging.meshcore(
            'event=radio.persist.failed reason=${e.runtimeType}',
            error: true,
          );
        }
      } else {
        AppLogging.meshcore('event=radio.persist.skipped reason=no_node_key');
      }

      AppLogging.meshcore('event=radio.apply.succeeded');
      if (!mounted) return;
      Navigator.of(context).pop();
      showSuccessSnackBar(context, l10n.meshcoreRadioSettingsAppliedSuccess);
    } catch (e) {
      AppLogging.meshcore(
        'event=radio.apply.failed stage=exception reason=${e.runtimeType}',
        error: true,
      );
      if (!mounted) return;
      showErrorSnackBar(context, l10n.meshcoreRadioSettingsAppliedFailed);
      safeSetState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Keyboard dismissal is handled per-field via TextFormField.onTapOutside
    // (canonical Socialmesh pattern; see mqtt_config_screen.dart). Avoid
    // a top-level GestureDetector here so we don't trip the haptic-feedback
    // lint, and so taps on chip rows / outlined buttons still bubble
    // through to their own handlers without an extra interception.
    return Form(
      key: _formKey,
      child: ListView(
        controller: widget.scrollController,
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              AppTheme.spacing8,
              AppTheme.spacing16,
              AppTheme.spacing8,
            ),
            child: Text(
              l10n.meshcoreRadioSettingsTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              0,
              AppTheme.spacing16,
              AppTheme.spacing16,
            ),
            child: Text(
              l10n.meshcoreRadioSettingsHint,
              style: TextStyle(fontSize: 13, color: context.textTertiary),
            ),
          ),

          SettingsSectionHeader(
            title: l10n.meshcoreRadioSettingsFreqSectionHeader,
          ),
          FieldGroupCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _freqController,
                  maxLength: 12,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  // Canonical Socialmesh keyboard-dismissal pattern.
                  // tapping anywhere off the input drops focus. Mirrors
                  // the per-field behaviour used by mqtt_config_screen
                  // and the existing _editNodeName sheet.
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  style: TextStyle(color: context.textPrimary),
                  validator: (v) => _validateFreq(v, l10n),
                  decoration: InputDecoration(
                    labelText: l10n.meshcoreRadioSettingsFrequencyLabel,
                    labelStyle: TextStyle(color: context.textSecondary),
                    hintText: l10n.meshcoreRadioSettingsFrequencyHint,
                    hintStyle: TextStyle(color: SemanticColors.muted),
                    filled: true,
                    fillColor: context.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                      borderSide: BorderSide(color: context.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                      borderSide: BorderSide(color: context.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                      borderSide: BorderSide(color: context.accentColor),
                    ),
                    prefixIcon: Icon(
                      Icons.broadcast_on_personal_outlined,
                      color: context.textSecondary,
                    ),
                    counterText: '',
                  ),
                ),
                SizedBox(height: AppTheme.spacing16),
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
                  child: Text(
                    l10n.meshcoreRadioSettingsBandwidthLabel,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                ChipSelector<double>(
                  value: _bandwidthKhz,
                  onChanged: _saving
                      ? null
                      : (v) => safeSetState(() => _bandwidthKhz = v),
                  options: [
                    for (final khz in _supportedBandwidthsKhz)
                      ChipOption(
                        value: khz,
                        label: _bwLabel(khz),
                        icon: Icons.tune_rounded,
                        color: context.accentColor,
                      ),
                  ],
                ),
              ],
            ),
          ),

          SettingsSectionHeader(
            title: l10n.meshcoreRadioSettingsModulationHeader,
          ),
          FieldGroupCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.meshcoreRadioSettingsSpreadingFactorLabel,
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                ),
                SizedBox(height: AppTheme.spacing8),
                ChipSelector<int>(
                  value: _spreadingFactor,
                  onChanged: _saving
                      ? null
                      : (v) => safeSetState(() => _spreadingFactor = v),
                  options: [
                    for (var sf = 5; sf <= 12; sf++)
                      ChipOption(
                        value: sf,
                        // Technical SF index, not a translatable string.
                        label: '$sf', // lint-allow: hardcoded-string
                        icon: Icons.signal_cellular_alt_rounded,
                        color: context.accentColor,
                      ),
                  ],
                ),
                SizedBox(height: AppTheme.spacing16),
                Text(
                  l10n.meshcoreRadioSettingsCodingRateLabel,
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                ),
                SizedBox(height: AppTheme.spacing8),
                ChipSelector<int>(
                  value: _codingRate,
                  onChanged: _saving
                      ? null
                      : (v) => safeSetState(() => _codingRate = v),
                  options: [
                    for (var cr = 5; cr <= 8; cr++)
                      ChipOption(
                        value: cr,
                        // Coding rate fraction (4/5, 4/6, …) is a
                        // protocol-level numeric label, not translatable.
                        label: '4/$cr', // lint-allow: hardcoded-string
                        icon: Icons.alt_route_rounded,
                        color: context.accentColor,
                      ),
                  ],
                ),
              ],
            ),
          ),

          SettingsSectionHeader(title: l10n.meshcoreRadioSettingsPowerHeader),
          FieldGroupCard(
            child: TextFormField(
              controller: _txController,
              maxLength: 4,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\-0-9]')),
              ],
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              style: TextStyle(color: context.textPrimary),
              validator: (v) => _validateTx(v, l10n),
              decoration: InputDecoration(
                labelText: l10n.meshcoreRadioSettingsTxPowerLabel,
                labelStyle: TextStyle(color: context.textSecondary),
                hintText: l10n.meshcoreRadioSettingsTxPowerHint,
                hintStyle: TextStyle(color: SemanticColors.muted),
                filled: true,
                fillColor: context.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                  borderSide: BorderSide(color: context.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                  borderSide: BorderSide(color: context.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                  borderSide: BorderSide(color: context.accentColor),
                ),
                prefixIcon: Icon(
                  Icons.flash_on_rounded,
                  color: context.textSecondary,
                ),
                counterText: '',
              ),
            ),
          ),

          SizedBox(height: AppTheme.spacing24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: Text(l10n.meshcoreCancel),
                  ),
                ),
                SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: PrimaryGradientButton(
                    label: _saving
                        ? l10n.meshcoreRadioSettingsApplying
                        : l10n.meshcoreRadioSettingsApply,
                    icon: Icons.check_rounded,
                    // Disable Apply while loading persisted values (brief)
                    // so the user doesn't dispatch with stale defaults if
                    // they're a quick tapper.
                    onPressed: (_saving || _hydrating) ? null : _apply,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppTheme.spacing16),
        ],
      ),
    );
  }
}
