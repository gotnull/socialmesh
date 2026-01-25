import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../models/mesh_models.dart';
import '../../models/presence_confidence.dart';
import '../theme.dart';
import '../logging.dart';

/// 3D Interactive Globe widget showing mesh node positions
/// Uses CesiumJS via WebView for Google Earth-style rendering with deep zoom
class MeshGlobe extends StatefulWidget {
  /// List of nodes to display (must have position data)
  final List<MeshNode> nodes;

  /// Whether to show connection lines between nodes
  final bool showConnections;

  /// Called when a node is tapped
  final void Function(MeshNode node)? onNodeSelected;

  /// Auto-rotate speed (0 to disable) - not currently used with CesiumJS
  final double autoRotateSpeed;

  /// Whether the globe is enabled/visible
  final bool enabled;

  /// Initial latitude for camera focus
  final double? initialLatitude;

  /// Initial longitude for camera focus
  final double? initialLongitude;

  /// Marker color (default if not specified per marker)
  final Color markerColor;

  /// Connection line color
  final Color connectionColor;

  /// Optional presence overrides keyed by nodeNum
  final Map<int, PresenceConfidence>? presenceMap;

  // Legacy parameters (kept for API compatibility)
  final double initialPhi;
  final double initialTheta;
  final Color baseColor;
  final Color dotColor;
  final bool showGlow;
  final int dotSamples;

  const MeshGlobe({
    super.key,
    this.nodes = const [],
    this.showConnections = true,
    this.onNodeSelected,
    this.autoRotateSpeed = 0.2,
    this.enabled = true,
    this.initialLatitude,
    this.initialLongitude,
    this.markerColor = const Color(0xFF42A5F5),
    this.connectionColor = const Color(0xFF42A5F5),
    this.presenceMap,
    // Legacy parameters for API compatibility
    this.initialPhi = 0.0,
    this.initialTheta = 0.3,
    this.baseColor = const Color(0xFF1a1a2e),
    this.dotColor = const Color(0xFF4a4a6a),
    this.showGlow = false,
    this.dotSamples = 8000,
  });

  @override
  State<MeshGlobe> createState() => MeshGlobeState();
}

class MeshGlobeState extends State<MeshGlobe> {
  InAppWebViewController? _webViewController;
  bool _isReady = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    AppLogging.map(
      '[MeshGlobe] initState - enabled=${widget.enabled}, nodes=${widget.nodes.length}',
    );
  }

  @override
  void didUpdateWidget(MeshGlobe oldWidget) {
    super.didUpdateWidget(oldWidget);
    AppLogging.map('[MeshGlobe] didUpdateWidget - isReady=$_isReady');

    // Check if nodes changed
    if (!_listEquals(widget.nodes, oldWidget.nodes) ||
        widget.showConnections != oldWidget.showConnections) {
      AppLogging.map('[MeshGlobe] Nodes or connections changed');
      if (_isReady) {
        _updateNodes();
      }
      // If not ready yet, _updateNodes will be called when globe is ready
    }
  }

  bool _listEquals(List<MeshNode> a, List<MeshNode> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].nodeNum != b[i].nodeNum) return false;
    }
    return true;
  }

  Future<void> _updateNodes() async {
    AppLogging.map(
      '[MeshGlobe] _updateNodes - controller=${_webViewController != null}, ready=$_isReady',
    );
    if (_webViewController == null || !_isReady) return;

    final nodesWithPos = widget.nodes.where((n) => n.hasPosition).toList();
    AppLogging.map(
      '[MeshGlobe] Sending ${nodesWithPos.length} nodes with position',
    );

    final presenceOverrides = widget.presenceMap ?? const {};
    final nodesJson = nodesWithPos
        .map(
          (n) => {
            'nodeNum': n.nodeNum,
            'shortName': n.shortName,
            'longName': n.longName,
            'latitude': n.latitude,
            'longitude': n.longitude,
            'presenceConfidence':
                (presenceOverrides[n.nodeNum] ?? n.presenceConfidence).name,
            'lastHeard': n.lastHeard?.millisecondsSinceEpoch,
            'avatarColor': n.avatarColor != null
                ? '#${n.avatarColor!.toRadixString(16).padLeft(8, '0').substring(2)}'
                : null,
          },
        )
        .toList();

    final js = 'setNodes(${jsonEncode(nodesJson)}, ${widget.showConnections});';
    AppLogging.map(
      '[MeshGlobe] Executing JS: setNodes with ${nodesJson.length} nodes',
    );
    await _webViewController?.evaluateJavascript(source: js);
  }

  /// Rotate to focus on a specific location
  void rotateToLocation(
    double latitude,
    double longitude, {
    bool animate = true,
    double height = 2.5, // Three.js globe uses normalized Earth radius (1.0)
  }) {
    if (_webViewController == null || !_isReady) return;
    final duration = animate ? 2000 : 0; // Duration in milliseconds
    _webViewController?.evaluateJavascript(
      source: 'flyTo($latitude, $longitude, $height, $duration);',
    );
  }

  /// Rotate to focus on a specific node
  void rotateToNode(MeshNode node, {bool animate = true}) {
    if (node.hasPosition) {
      // Fly closer for individual node view
      rotateToLocation(
        node.latitude!,
        node.longitude!,
        height: 1.8, // Close-up view
        animate: animate,
      );
    }
  }

  /// Reset rotation to default view
  void resetView() {
    if (_webViewController == null || !_isReady) return;
    _webViewController?.evaluateJavascript(source: 'resetView();');
  }

  /// Toggle connection lines visibility
  void setConnectionsVisible(bool visible) {
    if (_webViewController == null || !_isReady) return;
    _webViewController?.evaluateJavascript(
      source: 'setConnectionsVisible($visible);',
    );
  }

  void _onGlobeReady() {
    AppLogging.map('[MeshGlobe] _onGlobeReady called!');
    setState(() {
      _isReady = true;
      _isLoading = false;
    });

    // Set accent color
    final colorHex =
        '#${widget.markerColor.value.toRadixString(16).padLeft(8, '0').substring(2)}';
    AppLogging.map('[MeshGlobe] Setting accent color: $colorHex');
    _webViewController?.evaluateJavascript(
      source: 'setAccentColor("$colorHex");',
    );

    // Send pending nodes
    AppLogging.map('[MeshGlobe] Calling _updateNodes');
    _updateNodes();

    // Fly to initial location if provided
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      AppLogging.map(
        '[MeshGlobe] Flying to initial location: ${widget.initialLatitude}, ${widget.initialLongitude}',
      );
      Future.delayed(const Duration(milliseconds: 500), () {
        rotateToLocation(
          widget.initialLatitude!,
          widget.initialLongitude!,
          height: 5000000,
        );
      });
    }
  }

  void _onNodeSelected(String nodeJson) {
    try {
      final data = jsonDecode(nodeJson) as Map<String, dynamic>;
      final nodeNum = data['nodeNum'] as int;

      // Find the node in our list
      final node = widget.nodes.firstWhere(
        (n) => n.nodeNum == nodeNum,
        orElse: () => widget.nodes.first,
      );

      HapticFeedback.selectionClick();
      widget.onNodeSelected?.call(node);
    } catch (e) {
      AppLogging.map('Error parsing node selection: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // WebView with Three.js atmospheric globe
        InAppWebView(
          initialFile: 'assets/globe/mesh_globe.html',
          initialSettings: InAppWebViewSettings(
            mediaPlaybackRequiresUserGesture: false,
            allowsInlineMediaPlayback: true,
            javaScriptEnabled: true,
            transparentBackground: true,
            supportZoom: false,
            disableHorizontalScroll: false,
            disableVerticalScroll: false,
            useHybridComposition: true,
            allowFileAccessFromFileURLs: true,
            allowUniversalAccessFromFileURLs: true,
          ),
          onWebViewCreated: (controller) {
            AppLogging.map('[MeshGlobe] onWebViewCreated');
            _webViewController = controller;

            // Register handlers for communication from JS
            controller.addJavaScriptHandler(
              handlerName: 'onGlobeReady',
              callback: (args) {
                AppLogging.map('[MeshGlobe] JS handler onGlobeReady received');
                _onGlobeReady();
                return null;
              },
            );

            controller.addJavaScriptHandler(
              handlerName: 'onNodeSelected',
              callback: (args) {
                AppLogging.map('[MeshGlobe] JS handler onNodeSelected: $args');
                if (args.isNotEmpty) {
                  _onNodeSelected(args[0] as String);
                }
                return null;
              },
            );
          },
          onLoadStart: (controller, url) {
            AppLogging.map('[MeshGlobe] onLoadStart: $url');
          },
          onLoadStop: (controller, url) {
            AppLogging.map('[MeshGlobe] onLoadStop: $url');
            // Fallback if onGlobeReady not called
            Future.delayed(const Duration(seconds: 3), () {
              if (!_isReady && mounted) {
                AppLogging.map(
                  '[MeshGlobe] Fallback: calling _onGlobeReady after timeout',
                );
                _onGlobeReady();
              }
            });
          },
          onLoadError: (controller, url, code, message) {
            AppLogging.map(
              '[MeshGlobe] onLoadError: code=$code, message=$message, url=$url',
            );
          },
          onReceivedError: (controller, request, error) {
            AppLogging.map(
              '[MeshGlobe] onReceivedError: ${error.description} for ${request.url}',
            );
          },
          onConsoleMessage: (controller, message) {
            AppLogging.map('[MeshGlobe/JS] ${message.message}');
          },
        ),

        // Loading indicator
        if (_isLoading)
          Container(
            color: context.background,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(context.accentColor),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading Globe...',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
