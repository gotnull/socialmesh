// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/los_analysis.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/status_banner.dart';
import '../../l10n/app_localizations.dart';
import '../../models/mesh_models.dart';
import '../../services/terrain/elevation_service.dart';
import 'widgets/terrain_profile_chart.dart';

/// Full-screen view for a terrain elevation profile between two map points.
///
/// Fetches elevation data once during [initState] / [didChangeDependencies],
/// renders a [TerrainProfileChart], and shows a terrain-aware LOS verdict
/// when endpoint altitude data is available.
///
/// Constructor args only — does not re-read map state from providers.
class TerrainProfileScreen extends ConsumerStatefulWidget {
  /// Start point of the measurement path.
  final LatLng start;

  /// End point of the measurement path.
  final LatLng end;

  /// Optional start node — used for altitude and display name.
  final MeshNode? nodeA;

  /// Optional end node — used for altitude and display name.
  final MeshNode? nodeB;

  const TerrainProfileScreen({
    super.key,
    required this.start,
    required this.end,
    this.nodeA,
    this.nodeB,
  });

  @override
  ConsumerState<TerrainProfileScreen> createState() =>
      _TerrainProfileScreenState();
}

/// State for [TerrainProfileScreen].
///
/// Fetch lifecycle:
///   - [_fetchOnce] is called from [initState]; it sets [_fetching] = true,
///     awaits the service, then calls [safeSetState] so the UI only rebuilds
///     when still mounted.
///   - Subsequent rebuilds (e.g. theme change) never re-trigger the fetch
///     because [_fetchTriggered] guards the call.
class _TerrainProfileScreenState extends ConsumerState<TerrainProfileScreen>
    with LifecycleSafeMixin {
  // Service instance — created once, not in build().
  late final ElevationService _service;

  // Fetch state flags (never reset after first fetch without explicit retry).
  bool _fetching = false;
  bool _fetchTriggered = false;

  List<ElevationSample>? _samples;
  TerrainLosResult? _losResult;
  bool _offline = false;
  String? _errorMessage;

  /// True when terrain elevation was used as a fallback altitude for one or
  /// both endpoints because no GPS altitude was available on the node.
  bool _usingTerrainFallback = false;

  /// User-entered antenna height above ground level (meters) for each endpoint.
  /// Only used when GPS altitude is missing for that endpoint.
  final _heightAglControllerA = TextEditingController();
  final _heightAglControllerB = TextEditingController();

  /// Terrain elevation at endpoints (cached after fetch for AGL calculations).
  int? _terrainAltA;
  int? _terrainAltB;

  @override
  void initState() {
    super.initState();
    _service = ElevationService();
    _heightAglControllerA.addListener(_onAntennaHeightChanged);
    _heightAglControllerB.addListener(_onAntennaHeightChanged);
    _fetchOnce();
  }

  @override
  void dispose() {
    _heightAglControllerA.dispose();
    _heightAglControllerB.dispose();
    super.dispose();
  }

  /// Starts the elevation fetch exactly once.
  void _fetchOnce() {
    if (_fetchTriggered) return;
    _fetchTriggered = true;
    _doFetch();
  }

  Future<void> _doFetch() async {
    safeSetState(() {
      _fetching = true;
      _offline = false;
      _errorMessage = null;
      _samples = null;
      _losResult = null;
    });

    // Capture constructor params before await.
    final start = widget.start;
    final end = widget.end;
    final gpsAltA = widget.nodeA?.altitude;
    final gpsAltB = widget.nodeB?.altitude;

    final result = await _service.fetchProfile(start, end);

    // Guard: widget may have been popped while the request was in flight.
    if (!mounted) return;

    switch (result) {
      case ElevationProfileSuccess(:final samples):
        // When GPS altitude is missing for a point, fall back to the terrain
        // elevation at that endpoint (first / last sample). This allows LOS
        // analysis to run for arbitrary map points where no node altitude is
        // known — treating ground level as the antenna height.
        final terrainAltA = samples.isNotEmpty
            ? samples.first.elevationMeters?.round()
            : null;
        final terrainAltB = samples.isNotEmpty
            ? samples.last.elevationMeters?.round()
            : null;

        final effectiveAltA = gpsAltA ?? terrainAltA;
        final effectiveAltB = gpsAltB ?? terrainAltB;
        final usingFallback =
            (gpsAltA == null && terrainAltA != null) ||
            (gpsAltB == null && terrainAltB != null);

        final losResult = _computeLos(
          samples: samples,
          effectiveAltA: effectiveAltA,
          effectiveAltB: effectiveAltB,
        );
        safeSetState(() {
          _samples = samples;
          _losResult = losResult;
          _usingTerrainFallback = usingFallback;
          _terrainAltA = terrainAltA;
          _terrainAltB = terrainAltB;
          _fetching = false;
        });
      case ElevationProfileOffline():
        safeSetState(() {
          _offline = true;
          _fetching = false;
        });
      case ElevationProfileFailure(:final reason):
        safeSetState(() {
          _errorMessage = reason;
          _fetching = false;
        });
    }
  }

  void _retry() {
    _fetchTriggered = false;
    _fetchOnce();
  }

  /// Compute LOS from profile samples and effective endpoint altitudes.
  TerrainLosResult _computeLos({
    required List<ElevationSample> samples,
    required int? effectiveAltA,
    required int? effectiveAltB,
  }) {
    return evaluateLosFromProfile(
      samples: samples
          .map(
            (s) => (
              distanceMeters: s.distanceMeters,
              latitude: s.latitude,
              longitude: s.longitude,
              elevationMeters: s.elevationMeters,
            ),
          )
          .toList(),
      altAMeters: effectiveAltA,
      altBMeters: effectiveAltB,
    );
  }

  /// Recalculate LOS when the user changes antenna height above ground.
  void _onAntennaHeightChanged() {
    final samples = _samples;
    if (samples == null) return;

    final gpsAltA = widget.nodeA?.altitude;
    final gpsAltB = widget.nodeB?.altitude;
    final aglA = int.tryParse(_heightAglControllerA.text) ?? 0;
    final aglB = int.tryParse(_heightAglControllerB.text) ?? 0;

    // For endpoints with GPS altitude, use GPS. Otherwise use terrain + AGL.
    final effectiveAltA =
        gpsAltA ?? (_terrainAltA != null ? _terrainAltA! + aglA : null);
    final effectiveAltB =
        gpsAltB ?? (_terrainAltB != null ? _terrainAltB! + aglB : null);

    final losResult = _computeLos(
      samples: samples,
      effectiveAltA: effectiveAltA,
      effectiveAltB: effectiveAltB,
    );

    safeSetState(() {
      _losResult = losResult;
      _usingTerrainFallback =
          (gpsAltA == null && _terrainAltA != null) ||
          (gpsAltB == null && _terrainAltB != null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final altA = widget.nodeA?.altitude;
    final altB = widget.nodeB?.altitude;
    // GPS altitude is absent for one or both endpoints.
    final missingGpsAltitude = altA == null || altB == null;
    // After fetching, terrain elevation may be available as a fallback.
    final showTerrainFallbackNote = missingGpsAltitude && _usingTerrainFallback;
    // Show the "LOS unavailable" warning only when terrain fallback also failed.
    final showNoAltitudeWarning = missingGpsAltitude && !_usingTerrainFallback;

    return GestureDetector(
      onTap: () =>
          FocusScope.of(context).unfocus(), // lint-allow: haptic-feedback
      child: GlassScaffold(
        title: l10n.mapTerrainProfileTitle,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Endpoint summary ──────────────────────────────────────────
                _EndpointRow(
                  start: widget.start,
                  end: widget.end,
                  nodeA: widget.nodeA,
                  nodeB: widget.nodeB,
                ),
                const SizedBox(height: AppTheme.spacing12),

                // ── Terrain elevation used as altitude fallback ────────────────
                if (showTerrainFallbackNote) ...[
                  StatusBanner.info(
                    title: l10n.mapTerrainProfileUsingTerrainAltitude,
                    subtitle:
                        l10n.mapTerrainProfileUsingTerrainAltitudeSubtitle,
                  ),
                  const SizedBox(height: AppTheme.spacing12),
                  _AntennaHeightInputs(
                    needsA: altA == null && _terrainAltA != null,
                    needsB: altB == null && _terrainAltB != null,
                    terrainAltA: _terrainAltA,
                    terrainAltB: _terrainAltB,
                    controllerA: _heightAglControllerA,
                    controllerB: _heightAglControllerB,
                    nodeA: widget.nodeA,
                    nodeB: widget.nodeB,
                  ),
                  const SizedBox(height: AppTheme.spacing12),
                ],

                // ── Altitude unavailable note ─────────────────────────────────
                if (showNoAltitudeWarning) ...[
                  StatusBanner.warning(
                    title: l10n.mapTerrainProfileNeedsAltitude,
                    subtitle: l10n.mapTerrainProfileNeedsAltitudeSubtitle,
                  ),
                  const SizedBox(height: AppTheme.spacing12),
                ],

                // ── Loading ───────────────────────────────────────────────────
                if (_fetching)
                  StatusBanner.info(
                    title: l10n.mapTerrainProfileLoading,
                    isLoading: true,
                  ),

                // ── Offline ───────────────────────────────────────────────────
                if (!_fetching && _offline)
                  StatusBanner.warning(
                    title: l10n.mapTerrainProfileOffline,
                    subtitle: l10n.mapTerrainProfileOfflineSubtitle,
                    trailing: TextButton(
                      onPressed: _retry,
                      child: Text(l10n.mapTerrainRetry),
                    ),
                  ),

                // ── Error ─────────────────────────────────────────────────────
                if (!_fetching && _errorMessage != null)
                  StatusBanner.error(
                    title: l10n.mapTerrainProfileError,
                    subtitle: l10n.mapTerrainProfileErrorSubtitle,
                    trailing: TextButton(
                      onPressed: _retry,
                      child: Text(l10n.mapTerrainRetry),
                    ),
                  ),

                // ── Chart + verdict ───────────────────────────────────────────
                if (!_fetching && _samples != null) ...[
                  TerrainProfileChart(
                    samples: _samples!,
                    losResult: (_losResult?.hasAltitudeData ?? false)
                        ? _losResult
                        : null,
                  ),
                  const SizedBox(height: AppTheme.spacing12),

                  // Sample count label
                  Text(
                    l10n.mapTerrainProfileSampleCount(_samples!.length),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing12),

                  // LOS verdict (only when altitude data is present)
                  if (_losResult != null && _losResult!.hasAltitudeData)
                    _TerrainVerdictPanel(result: _losResult!),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Compact row showing the start and end point labels.
class _EndpointRow extends StatelessWidget {
  final LatLng start;
  final LatLng end;
  final MeshNode? nodeA;
  final MeshNode? nodeB;

  const _EndpointRow({
    required this.start,
    required this.end,
    this.nodeA,
    this.nodeB,
  });

  String _label(
    AppLocalizations l10n,
    LatLng point,
    MeshNode? node,
    String prefix,
  ) {
    if (node != null) {
      final name = node.altitude != null
          ? '${node.displayName} ${l10n.mapTerrainNodeAltitude(node.altitude!.toString())}'
          : node.displayName;
      return l10n.mapTerrainEndpointLabel(prefix, name);
    }
    return l10n.mapTerrainEndpointCoords(
      prefix,
      point.latitude.toStringAsFixed(4),
      point.longitude.toStringAsFixed(4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _label(l10n, start, nodeA, 'A'),
          style: TextStyle(fontSize: 12, color: AppTheme.warningYellow),
        ),
        const SizedBox(height: AppTheme.spacing2),
        Text(
          _label(l10n, end, nodeB, 'B'),
          style: TextStyle(fontSize: 12, color: AppTheme.warningYellow),
        ),
      ],
    );
  }
}

/// Editable antenna height above ground fields for endpoints missing GPS altitude.
class _AntennaHeightInputs extends StatelessWidget {
  final bool needsA;
  final bool needsB;
  final int? terrainAltA;
  final int? terrainAltB;
  final TextEditingController controllerA;
  final TextEditingController controllerB;
  final MeshNode? nodeA;
  final MeshNode? nodeB;

  const _AntennaHeightInputs({
    required this.needsA,
    required this.needsB,
    required this.terrainAltA,
    required this.terrainAltB,
    required this.controllerA,
    required this.controllerB,
    this.nodeA,
    this.nodeB,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.mapTerrainAntennaHeightTitle,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            l10n.mapTerrainAntennaHeightSubtitle,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          if (needsA)
            _AntennaHeightField(
              label: l10n.mapTerrainAntennaHeightPointLabel(
                'A',
                nodeA?.displayName ?? 'A',
              ),
              terrainAlt: terrainAltA,
              controller: controllerA,
            ),
          if (needsA && needsB) const SizedBox(height: AppTheme.spacing8),
          if (needsB)
            _AntennaHeightField(
              label: l10n.mapTerrainAntennaHeightPointLabel(
                'B',
                nodeB?.displayName ?? 'B',
              ),
              terrainAlt: terrainAltB,
              controller: controllerB,
            ),
        ],
      ),
    );
  }
}

/// Single antenna height input row with terrain elevation context.
class _AntennaHeightField extends StatelessWidget {
  final String label;
  final int? terrainAlt;
  final TextEditingController controller;

  const _AntennaHeightField({
    required this.label,
    required this.terrainAlt,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              if (terrainAlt != null)
                Text(
                  l10n.mapTerrainAntennaHeightGroundLevel(terrainAlt!),
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(
                      context,
                    ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppTheme.spacing8),
        SizedBox(
          width: 80,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '0', // lint-allow: hardcoded-string
              hintStyle: TextStyle(
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withValues(alpha: 0.4),
              ),
              suffixText: l10n.unitM,
              suffixStyle: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing8,
                vertical: AppTheme.spacing8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                borderSide: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact verdict panel reusing the same color logic as _LosResultPanel.
class _TerrainVerdictPanel extends StatelessWidget {
  final TerrainLosResult result;

  const _TerrainVerdictPanel({required this.result});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    Color verdictColor;
    IconData verdictIcon;
    switch (result.verdict) {
      case LosVerdict.clear:
        verdictColor = AppTheme.successGreen;
        verdictIcon = Icons.check_circle;
      case LosVerdict.marginal:
        verdictColor = AppTheme.warningYellow;
        verdictIcon = Icons.warning;
      case LosVerdict.obstructed:
        verdictColor = AppTheme.errorRed;
        verdictIcon = Icons.cancel;
      case LosVerdict.unknown:
        verdictColor = Theme.of(context).disabledColor;
        verdictIcon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing8),
      decoration: BoxDecoration(
        color: verdictColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(verdictIcon, size: 16, color: verdictColor),
              const SizedBox(width: AppTheme.spacing4),
              Text(
                l10n.mapTerrainLosVerdict(switch (result.verdict) {
                  LosVerdict.clear => l10n.losVerdictClear,
                  LosVerdict.marginal => l10n.losVerdictMarginal,
                  LosVerdict.obstructed => l10n.losVerdictObstructed,
                  LosVerdict.unknown => l10n.losVerdictUnknown,
                }),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: verdictColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            switch (result.verdict) {
              LosVerdict.obstructed => l10n.terrainLosExplanationObstructed(
                (-result.worstClearanceMeters!).toStringAsFixed(0),
              ),
              LosVerdict.marginal => l10n.terrainLosExplanationMarginal,
              LosVerdict.clear => l10n.terrainLosExplanationClear,
              LosVerdict.unknown => '',
            },
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          if (result.additionalClearanceNeededMeters > 0) ...[
            const SizedBox(height: AppTheme.spacing4),
            Text(
              l10n.mapTerrainAdditionalClearance(
                result.additionalClearanceNeededMeters.toStringAsFixed(0),
              ),
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.errorRed,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
