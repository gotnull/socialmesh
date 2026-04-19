// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'atmosphere_data_adapter.dart';

final atmosphereEnabledProvider = Provider<bool>((ref) => false);

final atmosphereEffectivelyEnabledProvider = Provider<bool>((ref) => false);

final atmosphereMetricsProvider = Provider<MeshAtmosphereMetrics>(
  (ref) => MeshAtmosphereMetrics.empty,
);

final atmosphereIntensitiesProvider = Provider<AtmosphereIntensities>(
  (ref) => AtmosphereIntensities.zero,
);

final atmosphereRainIntensityProvider = Provider<double>((ref) => 0.0);

final atmosphereEmberIntensityProvider = Provider<double>((ref) => 0.0);

final atmosphereMistIntensityProvider = Provider<double>((ref) => 0.0);

final atmosphereStarlightIntensityProvider = Provider<double>((ref) => 0.0);
