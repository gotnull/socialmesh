// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../core/logging.dart';
import '../../../core/los_analysis.dart';
import '../../../core/theme.dart';
import '../../../services/terrain/elevation_service.dart';

/// 3D interactive terrain profile rendered via Three.js in a WebView.
///
/// Accepts the same [samples] and [losResult] as [TerrainProfileChart] and
/// passes the data to the JavaScript scene via `setTerrainData()`.
///
/// Interaction: single-finger drag rotates, pinch zooms, two-finger pan.
class TerrainProfile3DView extends StatefulWidget {
  /// Ordered elevation samples from [ElevationService].
  final List<ElevationSample> samples;

  /// Pre-computed terrain LOS result. Pass null for terrain-only display.
  final TerrainLosResult? losResult;

  /// Display label for endpoint A (e.g. node name).
  final String labelA;

  /// Display label for endpoint B (e.g. node name).
  final String labelB;

  const TerrainProfile3DView({
    super.key,
    required this.samples,
    this.losResult,
    this.labelA = 'A',
    this.labelB = 'B',
  });

  @override
  State<TerrainProfile3DView> createState() => _TerrainProfile3DViewState();
}

class _TerrainProfile3DViewState extends State<TerrainProfile3DView> {
  InAppWebViewController? _controller;
  bool _isReady = false;

  void _markReady() {
    if (!_isReady && mounted) {
      setState(() => _isReady = true);
      _sendData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.samples.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 280,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: Stack(
          children: [
            InAppWebView(
              initialFile: 'assets/terrain/terrain_3d.html',
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                ),
              },
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                transparentBackground: true,
                supportZoom: false,
                disableHorizontalScroll: false,
                disableVerticalScroll: false,
                useHybridComposition: true,
                allowFileAccessFromFileURLs: true,
                allowUniversalAccessFromFileURLs: true,
                mediaPlaybackRequiresUserGesture: false,
              ),
              onWebViewCreated: (controller) {
                _controller = controller;
                controller.addJavaScriptHandler(
                  handlerName: 'onTerrainReady',
                  callback: (args) {
                    AppLogging.map('[Terrain3D] JS ready');
                    _markReady();
                    return null;
                  },
                );
              },
              onLoadStop: (controller, url) {
                AppLogging.map('[Terrain3D] onLoadStop: $url');
                // Fallback if JS handler not called.
                if (!_isReady) {
                  Future.delayed(const Duration(milliseconds: 500), () {
                    _markReady();
                  });
                }
              },
            ),
            // Loading overlay — visible until Three.js signals ready.
            if (!_isReady)
              const Positioned.fill(
                child: Center(child: CircularProgressIndicator.adaptive()),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(TerrainProfile3DView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.samples != oldWidget.samples ||
        widget.losResult != oldWidget.losResult) {
      _sendData();
    }
  }

  void _sendData() {
    if (!_isReady || _controller == null) return;

    final samples = widget.samples;
    final los = widget.losResult;
    final totalDistKm = samples.isNotEmpty
        ? samples.last.distanceMeters / 1000
        : 0.0;

    final sampleData = samples
        .map(
          (s) => {
            'dist': s.distanceMeters,
            'elev': s.elevationMeters ?? 0.0,
            'lat': s.latitude,
            'lng': s.longitude,
          },
        )
        .toList();

    final Map<String, dynamic> data = {
      'samples': sampleData,
      'totalDistKm': totalDistKm,
      'labelA': widget.labelA,
      'labelB': widget.labelB,
    };

    if (los != null && los.hasAltitudeData) {
      data['los'] = {
        'verdict': switch (los.verdict) {
          LosVerdict.clear => 'clear',
          LosVerdict.marginal => 'marginal',
          LosVerdict.obstructed => 'obstructed',
          LosVerdict.unknown => 'unknown',
        },
        'losLine': los.losLineHeightsMeters,
        'fresnelTop': List.generate(
          los.perSampleFresnelRadiusMeters.length,
          (i) =>
              los.losLineHeightsMeters[i] + los.perSampleFresnelRadiusMeters[i],
        ),
        'fresnelBot': List.generate(
          los.perSampleFresnelRadiusMeters.length,
          (i) =>
              los.losLineHeightsMeters[i] - los.perSampleFresnelRadiusMeters[i],
        ),
      };
    }

    final jsonStr = jsonEncode(data);
    // lint-allow: hardcoded-string
    final js = 'setTerrainData($jsonStr);';
    AppLogging.map('[Terrain3D] Sending ${samples.length} samples to JS');
    _controller?.evaluateJavascript(source: js);
  }
}
