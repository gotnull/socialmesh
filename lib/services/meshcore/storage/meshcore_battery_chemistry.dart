// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q11: pure battery-chemistry types + voltage→percent helper.
//
// The companion-radio firmware reports raw millivolts; the percent
// rendering assumes a chemistry-specific (empty, full) voltage
// curve. Default is LiPo 3.0–4.2V which matches the firmware's own
// linear estimate. Users with LiFePO4 / Li-Ion / NiMH cells can
// pick the correct profile via a settings chip so the percent
// readout reflects actual state-of-charge.
//
// Per-pubkey: stored keyed by the self radio's pubkey so a user
// with multiple radios (different field deployments) gets the
// right chemistry for each.

/// Supported cell chemistries plus an "auto" fallback that uses
/// the LiPo curve (matches the firmware default).
enum MeshCoreBatteryChemistry { auto, lipo, lifepo4, liion, nimh }

/// (emptyMv, fullMv) end-points for each chemistry. Numbers are
/// the conservative single-cell ranges that match field guides.
const Map<MeshCoreBatteryChemistry, (int empty, int full)>
kMeshCoreBatteryRange = {
  // 3.0V cutoff is the conservative LiPo low-voltage cliff;
  // 4.2V is the standard fully-charged terminal voltage.
  MeshCoreBatteryChemistry.auto: (3000, 4200),
  MeshCoreBatteryChemistry.lipo: (3000, 4200),
  // LiFePO4 sits on a much flatter discharge curve. 2.5V is the
  // hard cutoff; 3.6V is the fully-charged terminal. Outside this
  // range the % shown to the user is meaningless.
  MeshCoreBatteryChemistry.lifepo4: (2500, 3600),
  // Cylindrical Li-Ion (e.g. 18650). 2.75V cutoff is the typical
  // protected-cell shutdown; 4.2V terminal.
  MeshCoreBatteryChemistry.liion: (2750, 4200),
  // NiMH (e.g. AAA × N). 0.9V × cell count is the discharged
  // threshold; 1.4V × cell count fully charged. Stored values
  // here are single-cell so callers running multi-cell packs
  // need to scale (out of D-Q11 scope).
  MeshCoreBatteryChemistry.nimh: (900, 1400),
};

/// Pure voltage → percent estimator. Returns 0-100 clamped, or
/// null when [voltageMv] is non-positive (treated as "unknown"
/// rather than 0% so the UI can render a `--` placeholder).
int? estimateMeshCoreBatteryPercent({
  required int voltageMv,
  MeshCoreBatteryChemistry chemistry = MeshCoreBatteryChemistry.lipo,
}) {
  if (voltageMv <= 0) return null;
  final range = kMeshCoreBatteryRange[chemistry]!;
  final empty = range.$1;
  final full = range.$2;
  if (voltageMv <= empty) return 0;
  if (voltageMv >= full) return 100;
  final span = full - empty;
  return ((voltageMv - empty) * 100 / span).round();
}
