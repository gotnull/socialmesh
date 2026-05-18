// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import '../../../core/meshcore_constants.dart';
import '../../../l10n/app_localizations.dart';

/// Resolve a [MeshCoreRegionPreset] to its localized display label.
///
/// Region preset labels are defined in `lib/core/meshcore_constants.dart`
/// as English strings on the const preset list. The picker UI calls
/// this resolver to swap in the translated label per the user's locale.
///
/// If a new preset id is added to the constants but not wired up in this
/// switch, the fall-through returns `preset.label` (the English value
/// on the preset itself). That keeps the picker functional during the
/// gap between adding a preset and adding its ARB keys.
String meshCoreRegionPresetLabel(
  AppLocalizations l10n,
  MeshCoreRegionPreset preset,
) {
  return switch (preset.id) {
    'au_default' => l10n.meshcoreRegionPresetAuDefault,
    'au_narrow' => l10n.meshcoreRegionPresetAuNarrow,
    'au_sa_wa_qld' => l10n.meshcoreRegionPresetAuSaWaQld,
    'cz' => l10n.meshcoreRegionPresetCz,
    'eu_433' => l10n.meshcoreRegionPresetEu433,
    'eu_uk_long_range' => l10n.meshcoreRegionPresetEuUkLongRange,
    'eu_uk_medium_range' => l10n.meshcoreRegionPresetEuUkMediumRange,
    'eu_uk_narrow' => l10n.meshcoreRegionPresetEuUkNarrow,
    'nz_default' => l10n.meshcoreRegionPresetNzDefault,
    'nz_narrow' => l10n.meshcoreRegionPresetNzNarrow,
    'pt_433' => l10n.meshcoreRegionPresetPt433,
    'pt_869' => l10n.meshcoreRegionPresetPt869,
    'ch' => l10n.meshcoreRegionPresetCh,
    'us_arizona' => l10n.meshcoreRegionPresetUsArizona,
    'us_canada' => l10n.meshcoreRegionPresetUsCanada,
    'vn' => l10n.meshcoreRegionPresetVn,
    'offgrid_433' => l10n.meshcoreRegionPresetOffgrid433,
    'offgrid_869' => l10n.meshcoreRegionPresetOffgrid869,
    'offgrid_918' => l10n.meshcoreRegionPresetOffgrid918,
    _ => preset.label,
  };
}
