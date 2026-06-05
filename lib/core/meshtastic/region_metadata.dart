// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Centralized RegionCode metadata. One row per Meshtastic
// `Config_LoRaConfig_RegionCode`. Pickers (radio_config_screen,
// region_selection_screen) and helpers (mqtt_config_screen
// duty-cycle math, settings_screen subtitle) all read from
// [kRegionMetadata]. Adding a new region to the picker is a single
// entry in this list and one ARB key per locale — no per-screen
// edits, no drift between screens. Mirrors the Apple iOS app's
// `enum RegionCodes: CaseIterable` pattern from
// `meshtastic-ios/Meshtastic/Enums/LoraConfigEnums.swift`.

import '../../generated/meshtastic/config.pbenum.dart' as config_pbenum;
import '../../l10n/app_localizations.dart';

typedef LocalizedStringFn = String Function(AppLocalizations l);

class RegionMetadata {
  const RegionMetadata({
    required this.code,
    required this.frequency,
    required this.dutyCycle,
    required this.isCountry,
    required this.radioConfigLabel,
    required this.regionSelectionName,
    required this.regionSelectionFrequency,
    required this.regionSelectionDescription,
  });

  final config_pbenum.Config_LoRaConfig_RegionCode code;

  // Compact frequency suffix shown in the radio_config_screen
  // dropdown after the label, e.g. "915MHz". Empty for UNSET.
  final String frequency;

  // Regulatory duty-cycle ceiling as a percentage. 10 for EU/UA SRD
  // bands, 100 for unrestricted, 0 for UNSET.
  final int dutyCycle;

  // True when the region maps to a single country (used by iOS to
  // show a country flag — currently unused in SocialMesh, kept for
  // parity).
  final bool isCountry;

  final LocalizedStringFn radioConfigLabel;
  final LocalizedStringFn regionSelectionName;
  final LocalizedStringFn regionSelectionFrequency;
  final LocalizedStringFn regionSelectionDescription;
}

// Ordered by protobuf numeric value. UNSET sits at index 0 so the
// radio_config_screen dropdown renders it first as the "not yet
// configured" placeholder.
final List<RegionMetadata> kRegionMetadata = <RegionMetadata>[
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.UNSET,
    frequency: '',
    dutyCycle: 0,
    isCountry: false,
    radioConfigLabel: (l) => l.radioConfigRegionUnset,
    regionSelectionName: (l) => l.radioConfigRegionUnset,
    regionSelectionFrequency: (l) => '',
    regionSelectionDescription: (l) => l.radioConfigRegionNotConfigured,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.US,
    frequency: '915MHz',
    dutyCycle: 100,
    isCountry: true,
    radioConfigLabel: (l) => l.radioConfigRegionUs,
    regionSelectionName: (l) => l.regionSelectionRegionUs,
    regionSelectionFrequency: (l) => l.regionSelectionRegionUsFreq,
    regionSelectionDescription: (l) => l.regionSelectionRegionUsDesc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.EU_433,
    frequency: '433MHz',
    dutyCycle: 10,
    isCountry: false,
    radioConfigLabel: (l) => l.radioConfigRegionEu433,
    regionSelectionName: (l) => l.regionSelectionRegionEu433,
    regionSelectionFrequency: (l) => l.regionSelectionRegionEu433Freq,
    regionSelectionDescription: (l) => l.regionSelectionRegionEu433Desc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.EU_868,
    frequency: '868MHz',
    dutyCycle: 10,
    isCountry: false,
    radioConfigLabel: (l) => l.radioConfigRegionEu868,
    regionSelectionName: (l) => l.regionSelectionRegionEu868,
    regionSelectionFrequency: (l) => l.regionSelectionRegionEu868Freq,
    regionSelectionDescription: (l) => l.regionSelectionRegionEu868Desc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.CN,
    frequency: '470MHz',
    dutyCycle: 100,
    isCountry: true,
    radioConfigLabel: (l) => l.regionSelectionRegionCn,
    regionSelectionName: (l) => l.regionSelectionRegionCn,
    regionSelectionFrequency: (l) => l.regionSelectionRegionCnFreq,
    regionSelectionDescription: (l) => l.regionSelectionRegionCnDesc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.JP,
    frequency: '920MHz',
    dutyCycle: 100,
    isCountry: true,
    radioConfigLabel: (l) => l.regionSelectionRegionJp,
    regionSelectionName: (l) => l.regionSelectionRegionJp,
    regionSelectionFrequency: (l) => l.regionSelectionRegionJpFreq,
    regionSelectionDescription: (l) => l.regionSelectionRegionJpDesc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.ANZ,
    frequency: '915MHz',
    dutyCycle: 100,
    isCountry: false,
    radioConfigLabel: (l) => l.radioConfigRegionAnz,
    regionSelectionName: (l) => l.regionSelectionRegionAnz,
    regionSelectionFrequency: (l) => l.regionSelectionRegionAnzFreq,
    regionSelectionDescription: (l) => l.regionSelectionRegionAnzDesc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.KR,
    frequency: '920MHz',
    dutyCycle: 100,
    isCountry: true,
    radioConfigLabel: (l) => l.regionSelectionRegionKr,
    regionSelectionName: (l) => l.regionSelectionRegionKr,
    regionSelectionFrequency: (l) => l.regionSelectionRegionKrFreq,
    regionSelectionDescription: (l) => l.regionSelectionRegionKrDesc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.TW,
    frequency: '920MHz',
    dutyCycle: 100,
    isCountry: true,
    radioConfigLabel: (l) => l.regionSelectionRegionTw,
    regionSelectionName: (l) => l.regionSelectionRegionTw,
    regionSelectionFrequency: (l) => l.regionSelectionRegionTwFreq,
    regionSelectionDescription: (l) => l.regionSelectionRegionTwDesc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.RU,
    frequency: '868MHz',
    dutyCycle: 100,
    isCountry: true,
    radioConfigLabel: (l) => l.regionSelectionRegionRu,
    regionSelectionName: (l) => l.regionSelectionRegionRu,
    regionSelectionFrequency: (l) => l.regionSelectionRegionRuFreq,
    regionSelectionDescription: (l) => l.regionSelectionRegionRuDesc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.IN,
    frequency: '865MHz',
    dutyCycle: 100,
    isCountry: true,
    radioConfigLabel: (l) => l.regionSelectionRegionIn,
    regionSelectionName: (l) => l.regionSelectionRegionIn,
    regionSelectionFrequency: (l) => l.regionSelectionRegionInFreq,
    regionSelectionDescription: (l) => l.regionSelectionRegionInDesc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.NZ_865,
    frequency: '865MHz',
    dutyCycle: 100,
    isCountry: true,
    radioConfigLabel: (l) => l.radioConfigRegionNz865,
    regionSelectionName: (l) => l.regionSelectionRegionNz865,
    regionSelectionFrequency: (l) => l.regionSelectionRegionNz865Freq,
    regionSelectionDescription: (l) => l.regionSelectionRegionNz865Desc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.TH,
    frequency: '920MHz',
    dutyCycle: 100,
    isCountry: true,
    radioConfigLabel: (l) => l.regionSelectionRegionTh,
    regionSelectionName: (l) => l.regionSelectionRegionTh,
    regionSelectionFrequency: (l) => l.regionSelectionRegionThFreq,
    regionSelectionDescription: (l) => l.regionSelectionRegionThDesc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.LORA_24,
    frequency: '2.4GHz',
    dutyCycle: 100,
    isCountry: false,
    radioConfigLabel: (l) => l.radioConfigRegionLora24,
    regionSelectionName: (l) => l.regionSelectionRegionLora24,
    regionSelectionFrequency: (l) => l.regionSelectionRegionLora24Freq,
    regionSelectionDescription: (l) => l.regionSelectionRegionLora24Desc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.UA_433,
    frequency: '433MHz',
    dutyCycle: 10,
    isCountry: true,
    radioConfigLabel: (l) => l.regionSelectionRegionUa433,
    regionSelectionName: (l) => l.regionSelectionRegionUa433,
    regionSelectionFrequency: (l) => l.regionSelectionRegionUa433Freq,
    regionSelectionDescription: (l) => l.regionSelectionRegionUa433Desc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.UA_868,
    frequency: '868MHz',
    dutyCycle: 10,
    isCountry: true,
    radioConfigLabel: (l) => l.regionSelectionRegionUa868,
    regionSelectionName: (l) => l.regionSelectionRegionUa868,
    regionSelectionFrequency: (l) => l.regionSelectionRegionUa868Freq,
    regionSelectionDescription: (l) => l.regionSelectionRegionUa868Desc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.MY_433,
    frequency: '433MHz',
    dutyCycle: 100,
    isCountry: true,
    radioConfigLabel: (l) => l.radioConfigRegionMalaysia433,
    regionSelectionName: (l) => l.regionSelectionRegionMy433,
    regionSelectionFrequency: (l) => l.regionSelectionRegionMy433Freq,
    regionSelectionDescription: (l) => l.regionSelectionRegionMy433Desc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.MY_919,
    frequency: '919MHz',
    dutyCycle: 100,
    isCountry: true,
    radioConfigLabel: (l) => l.radioConfigRegionMalaysia919,
    regionSelectionName: (l) => l.regionSelectionRegionMy919,
    regionSelectionFrequency: (l) => l.regionSelectionRegionMy919Freq,
    regionSelectionDescription: (l) => l.regionSelectionRegionMy919Desc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.SG_923,
    frequency: '923MHz',
    dutyCycle: 100,
    isCountry: true,
    radioConfigLabel: (l) => l.regionSelectionRegionSg923,
    regionSelectionName: (l) => l.regionSelectionRegionSg923,
    regionSelectionFrequency: (l) => l.regionSelectionRegionSg923Freq,
    regionSelectionDescription: (l) => l.regionSelectionRegionSg923Desc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.PH_433,
    frequency: '433MHz',
    dutyCycle: 100,
    isCountry: true,
    radioConfigLabel: (l) => l.regionSelectionRegionPh433,
    regionSelectionName: (l) => l.regionSelectionRegionPh433,
    regionSelectionFrequency: (l) => l.regionSelectionRegionPh433Freq,
    regionSelectionDescription: (l) => l.regionSelectionRegionPh433Desc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.PH_868,
    frequency: '868MHz',
    dutyCycle: 100,
    isCountry: true,
    radioConfigLabel: (l) => l.regionSelectionRegionPh868,
    regionSelectionName: (l) => l.regionSelectionRegionPh868,
    regionSelectionFrequency: (l) => l.regionSelectionRegionPh868Freq,
    regionSelectionDescription: (l) => l.regionSelectionRegionPh868Desc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.PH_915,
    frequency: '915MHz',
    dutyCycle: 100,
    isCountry: true,
    radioConfigLabel: (l) => l.regionSelectionRegionPh915,
    regionSelectionName: (l) => l.regionSelectionRegionPh915,
    regionSelectionFrequency: (l) => l.regionSelectionRegionPh915Freq,
    regionSelectionDescription: (l) => l.regionSelectionRegionPh915Desc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.ANZ_433,
    frequency: '433MHz',
    dutyCycle: 100,
    isCountry: false,
    radioConfigLabel: (l) => l.regionSelectionRegionAnz433,
    regionSelectionName: (l) => l.regionSelectionRegionAnz433,
    regionSelectionFrequency: (l) => l.regionSelectionRegionAnz433Freq,
    regionSelectionDescription: (l) => l.regionSelectionRegionAnz433Desc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.KZ_433,
    frequency: '433MHz',
    dutyCycle: 100,
    isCountry: true,
    radioConfigLabel: (l) => l.regionSelectionRegionKz433,
    regionSelectionName: (l) => l.regionSelectionRegionKz433,
    regionSelectionFrequency: (l) => l.regionSelectionRegionKz433Freq,
    regionSelectionDescription: (l) => l.regionSelectionRegionKz433Desc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.KZ_863,
    frequency: '863MHz',
    dutyCycle: 100,
    isCountry: true,
    radioConfigLabel: (l) => l.regionSelectionRegionKz863,
    regionSelectionName: (l) => l.regionSelectionRegionKz863,
    regionSelectionFrequency: (l) => l.regionSelectionRegionKz863Freq,
    regionSelectionDescription: (l) => l.regionSelectionRegionKz863Desc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.NP_865,
    frequency: '865MHz',
    dutyCycle: 100,
    isCountry: true,
    radioConfigLabel: (l) => l.regionSelectionRegionNp865,
    regionSelectionName: (l) => l.regionSelectionRegionNp865,
    regionSelectionFrequency: (l) => l.regionSelectionRegionNp865Freq,
    regionSelectionDescription: (l) => l.regionSelectionRegionNp865Desc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.BR_902,
    frequency: '902MHz',
    dutyCycle: 100,
    isCountry: true,
    radioConfigLabel: (l) => l.regionSelectionRegionBr902,
    regionSelectionName: (l) => l.regionSelectionRegionBr902,
    regionSelectionFrequency: (l) => l.regionSelectionRegionBr902Freq,
    regionSelectionDescription: (l) => l.regionSelectionRegionBr902Desc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.ITU1_2M,
    frequency: '144-146MHz',
    dutyCycle: 100,
    isCountry: false,
    radioConfigLabel: (l) => l.regionSelectionRegionItu1_2m,
    regionSelectionName: (l) => l.regionSelectionRegionItu1_2m,
    regionSelectionFrequency: (l) => l.regionSelectionRegionItu1_2mFreq,
    regionSelectionDescription: (l) => l.regionSelectionRegionItu1_2mDesc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.ITU2_2M,
    frequency: '144-148MHz',
    dutyCycle: 100,
    isCountry: false,
    radioConfigLabel: (l) => l.regionSelectionRegionItu2_2m,
    regionSelectionName: (l) => l.regionSelectionRegionItu2_2m,
    regionSelectionFrequency: (l) => l.regionSelectionRegionItu2_2mFreq,
    regionSelectionDescription: (l) => l.regionSelectionRegionItu2_2mDesc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.EU_866,
    frequency: '866MHz',
    dutyCycle: 10,
    isCountry: false,
    radioConfigLabel: (l) => l.regionSelectionRegionEu866,
    regionSelectionName: (l) => l.regionSelectionRegionEu866,
    regionSelectionFrequency: (l) => l.regionSelectionRegionEu866Freq,
    regionSelectionDescription: (l) => l.regionSelectionRegionEu866Desc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.EU_874,
    frequency: '874MHz',
    dutyCycle: 10,
    isCountry: false,
    radioConfigLabel: (l) => l.regionSelectionRegionEu874,
    regionSelectionName: (l) => l.regionSelectionRegionEu874,
    regionSelectionFrequency: (l) => l.regionSelectionRegionEu874Freq,
    regionSelectionDescription: (l) => l.regionSelectionRegionEu874Desc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.EU_917,
    frequency: '917MHz',
    dutyCycle: 10,
    isCountry: false,
    radioConfigLabel: (l) => l.regionSelectionRegionEu917,
    regionSelectionName: (l) => l.regionSelectionRegionEu917,
    regionSelectionFrequency: (l) => l.regionSelectionRegionEu917Freq,
    regionSelectionDescription: (l) => l.regionSelectionRegionEu917Desc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.EU_N_868,
    frequency: '868MHz',
    dutyCycle: 10,
    isCountry: false,
    radioConfigLabel: (l) => l.regionSelectionRegionEuN868,
    regionSelectionName: (l) => l.regionSelectionRegionEuN868,
    regionSelectionFrequency: (l) => l.regionSelectionRegionEuN868Freq,
    regionSelectionDescription: (l) => l.regionSelectionRegionEuN868Desc,
  ),
  RegionMetadata(
    code: config_pbenum.Config_LoRaConfig_RegionCode.ITU3_2M,
    frequency: '144-148MHz',
    dutyCycle: 100,
    isCountry: false,
    radioConfigLabel: (l) => l.regionSelectionRegionItu3_2m,
    regionSelectionName: (l) => l.regionSelectionRegionItu3_2m,
    regionSelectionFrequency: (l) => l.regionSelectionRegionItu3_2mFreq,
    regionSelectionDescription: (l) => l.regionSelectionRegionItu3_2mDesc,
  ),
];

// Index for O(1) lookup. Built once at first access.
final Map<config_pbenum.Config_LoRaConfig_RegionCode, RegionMetadata>
_regionByCode = {for (final r in kRegionMetadata) r.code: r};

RegionMetadata? regionMetadataFor(
  config_pbenum.Config_LoRaConfig_RegionCode code,
) => _regionByCode[code];

// EU and UA SRD bands enforce a 10% duty cycle. ITU amateur-radio
// bands and all other regions are unrestricted (100%). UNSET → 0
// (degenerate).
int dutyCycleForRegion(config_pbenum.Config_LoRaConfig_RegionCode code) =>
    _regionByCode[code]?.dutyCycle ?? 100;
