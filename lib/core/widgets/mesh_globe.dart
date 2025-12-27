import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_globe_3d/flutter_globe_3d.dart';
import '../../models/mesh_models.dart';
import '../../providers/splash_mesh_provider.dart';
import '../theme.dart';

/// 3D Interactive Globe widget showing mesh node positions
/// Uses flutter_globe_3d for GPU-accelerated rendering
class MeshGlobe extends StatefulWidget {
  /// List of nodes to display (must have position data)
  final List<MeshNode> nodes;

  /// Whether to show connection lines between nodes
  final bool showConnections;

  /// Called when a node is tapped
  final void Function(MeshNode node)? onNodeSelected;

  /// Auto-rotate speed (0 to disable)
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

  // Legacy parameters (kept for API compatibility, but not used)
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
  EarthController? _controller;
  bool _isInitialized = false;
  List<MeshNode> _currentNodes = [];
  bool _currentShowConnections = true;

  // Track node IDs for connections
  final Map<int, String> _nodeIdMap = {};

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _initializeController();
    }
  }

  void _initializeController() {
    _controller = EarthController();

    // Disable auto-rotation by default (too distracting)
    _controller!.enableAutoRotate = false;
    _controller!.rotateSpeed = 5.0; // Slow rotation if enabled
    _controller!.minZoom = 0.8;
    _controller!.maxZoom = 4.0;

    // Lock vertical rotation to prevent polar tilt
    _controller!.lockNorthSouth = false;

    // Set light mode to follow camera for consistent lighting
    _controller!.setLightMode(EarthLightMode.followCamera);

    // Focus on initial coordinates if provided
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _controller!.setCameraFocus(
        widget.initialLatitude!,
        widget.initialLongitude!,
      );
    }

    _currentNodes = List.from(widget.nodes);
    _currentShowConnections = widget.showConnections;

    // Add nodes
    _addNodes();

    setState(() => _isInitialized = true);
  }

  void _addNodes() {
    if (_controller == null) return;
    _nodeIdMap.clear();

    // Add markers for nodes with position data
    for (final node in _currentNodes) {
      if (node.hasPosition) {
        final nodeId = 'node_${node.nodeNum}';
        _nodeIdMap[node.nodeNum] = nodeId;

        final color = node.avatarColor != null
            ? Color(node.avatarColor!)
            : widget.markerColor;

        _controller!.addNode(
          EarthNode(
            id: nodeId,
            latitude: node.latitude!,
            longitude: node.longitude!,
            child: _buildNodeLabel(node, color),
          ),
        );
      }
    }

    // Add connections between all nodes with position
    if (_currentShowConnections) {
      final nodesWithPos = _currentNodes.where((n) => n.hasPosition).toList();
      for (int i = 0; i < nodesWithPos.length - 1; i++) {
        for (int j = i + 1; j < nodesWithPos.length; j++) {
          final fromId = _nodeIdMap[nodesWithPos[i].nodeNum];
          final toId = _nodeIdMap[nodesWithPos[j].nodeNum];
          if (fromId != null && toId != null) {
            _controller!.connect(
              EarthConnection(
                fromId: fromId,
                toId: toId,
                color: widget.connectionColor,
                width: 2.0,
                isDashed: true,
                showArrow: false,
              ),
            );
          }
        }
      }
    }
  }

  @override
  void didUpdateWidget(MeshGlobe oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled && !_isInitialized) {
        _initializeController();
      }
    }

    // Check if nodes or connections changed - need to rebuild controller
    final nodesChanged = !_listEquals(widget.nodes, _currentNodes);
    final connectionsChanged =
        widget.showConnections != _currentShowConnections;

    if (_isInitialized && (nodesChanged || connectionsChanged)) {
      // Rebuild controller with new data
      _controller?.dispose();
      _currentNodes = List.from(widget.nodes);
      _currentShowConnections = widget.showConnections;
      _initializeController();
    }

    // Update auto-rotation settings - keep disabled unless explicitly enabled
    if (widget.autoRotateSpeed != oldWidget.autoRotateSpeed &&
        _controller != null) {
      _controller!.enableAutoRotate = false;
    }
  }

  bool _listEquals(List<MeshNode> a, List<MeshNode> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].nodeNum != b[i].nodeNum) return false;
    }
    return true;
  }

  Widget _buildNodeLabel(MeshNode node, Color color) {
    final name =
        node.shortName ?? node.longName ?? '!${node.nodeNum.toRadixString(16)}';

    // The parent Earth3D has a GestureDetector with onScaleStart that captures
    // all gestures. To intercept taps on nodes, we need to use Listener which
    // receives raw pointer events BEFORE the gesture arena processes them.
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerUp: (event) {
        // Only trigger on short taps (not drags)
        debugPrint(
          '=== NODE POINTER UP: ${node.longName ?? node.shortName} ===',
        );
        HapticFeedback.selectionClick();
        widget.onNodeSelected?.call(node);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(200),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(100),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status indicator dot
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: node.isOnline ? Colors.greenAccent : color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (node.isOnline ? Colors.greenAccent : color)
                        .withAlpha(180),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Node name
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black, blurRadius: 3)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Rotate to focus on a specific location
  void rotateToLocation(
    double latitude,
    double longitude, {
    bool animate = true,
  }) {
    _controller?.setCameraFocus(latitude, longitude);
    // Disable auto-rotation when focusing on a location
    if (animate && _controller != null) {
      _controller!.enableAutoRotate = false;
    }
  }

  /// Rotate to focus on a specific node
  void rotateToNode(MeshNode node, {bool animate = true}) {
    if (node.hasPosition) {
      rotateToLocation(node.latitude!, node.longitude!, animate: animate);
    }
  }

  /// Reset rotation to default view
  void resetView() {
    _controller?.setCameraFocus(0, 0);
    if (_controller != null) {
      _controller!.enableAutoRotate = false;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return const SizedBox.shrink();
    }

    if (_controller == null || !_isInitialized) {
      return Container(
        color: context.background,
        child: const ScreenLoadingIndicator(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use the full available size for the globe
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return Container(
          color: context.background,
          child: Center(
            child: Earth3D(
              controller: _controller!,
              texture: const AssetImage('assets/globe/earth_texture.png'),
              initialScale: 4.0,
              size: size,
            ),
          ),
        );
      },
    );
  }
}
